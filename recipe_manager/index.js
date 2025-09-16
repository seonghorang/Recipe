// functions/index.js
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const admin = require("firebase-admin");

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

// 공통 알림 전송 함수
async function sendNotification(title, body, data, senderUid) {
  const allUsersSnapshot = await db.collection("users").get();
  const tokenMap = {};
  const tokens = [];

  console.log(`Found ${allUsersSnapshot.size} users in collection`);

  allUsersSnapshot.forEach((doc) => {
    const uid = doc.id;
    const userData = doc.data();
    console.log(`User ${uid}:`, JSON.stringify(userData, null, 2));
    if (!userData) return;

    if (typeof userData.fcmToken === "string" && userData.fcmToken) {
      if (senderUid && uid === senderUid) {
        console.log(`Skipping sender UID: ${uid}`);
        return;
      }
      tokens.push(userData.fcmToken);
      tokenMap[userData.fcmToken] = uid;
    } else {
      console.log(`Invalid or missing fcmToken for UID ${uid}`);
    }
  });

  console.log(`Collected ${tokens.length} tokens:`, tokens);
  if (tokens.length === 0) {
    console.log("알림을 보낼 토큰 없음");
    return null;
  }

  try {
    const CHUNK = 450;
    for (let i = 0; i < tokens.length; i += CHUNK) {
      const slice = tokens.slice(i, i + CHUNK);
      console.log(`Sending to ${slice.length} tokens:`, slice);
      const response = await messaging.sendEachForMulticast({
        tokens: slice,
        notification: { title, body },
        data: data || {},
      });

      console.log(
        `sendEachForMulticast result: success ${response.successCount}, failure ${response.failureCount}`
      );

      response.responses.forEach((r, idx) => {
        if (!r.success) {
          const failedToken = slice[idx];
          const err = r.error;
          console.warn(
            `FCM error for token ${failedToken}:`,
            JSON.stringify(err, null, 2)
          );

          if (
            err &&
            (err.code === "messaging/registration-token-not-registered" ||
              err.code === "messaging/invalid-registration-token")
          ) {
            const uid = tokenMap[failedToken];
            if (uid) {
              db.collection("users")
                .doc(uid)
                .update({
                  fcmToken: FieldValue.delete(), // 단일 필드 삭제
                })
                .then(() => console.log(`Removed invalid token for ${uid}`))
                .catch(console.error);
            }
          }
        } else {
          console.log(`Successfully sent to token ${slice[idx]}`);
        }
      });
    }
    return true;
  } catch (err) {
    console.error("FCM send error:", err);
    return null;
  }
}

// 1. 새 레시피 추가 시 알림
exports.onNewRecipeCreated = onDocumentCreated(
  "recipes/{recipeId}",
  async (event) => {
    const newRecipe = event.data.data();
    const recipeId = event.params.recipeId;
    const senderUid = newRecipe.userId || null;

    const title = "커피 리뷰 쓰라잉!";
    const body = `${(newRecipe.title || "제목 없는 레시피").substring(
      0,
      50
    )} 추가했으니 리뷰 빨리 쓰쇼!`;

    const data = {
      type: "recipe_created",
      recipeId,
      category: newRecipe.category || "unknown",
    };

    return sendNotification(title, body, data, senderUid);
  }
);

// 2. 새 회화 게시글 추가 시 알림
exports.onNewStudyPostCreated = onDocumentCreated(
  "study_posts/{postId}",
  async (event) => {
    const newPost = event.data.data();
    const postId = event.params.postId;
    const senderUid = newPost.userId || null;

    const title = "회화 등록! 공부하쟈";
    const body = `${(newPost.recordedSentence || "내용 없는 게시글").substring(
      0,
      50
    )} 등록, 벤교오 스루 이키마스!`;

    const data = { type: "study_post_created", postId };

    return sendNotification(title, body, data, senderUid);
  }
);

// 3. 새 댓글 추가 시 알림
exports.onNewCommentAdded = onDocumentCreated(
  "study_posts/{postId}/comments/{commentId}",
  async (event) => {
    const newComment = event.data.data();
    const postId = event.params.postId;
    const commentId = event.params.commentId;
    const commenterUid = newComment.userId || null;

    const postDoc = await db.collection("study_posts").doc(postId).get();
    if (!postDoc.exists) return null;

    const postAuthorUid = postDoc.data().userId || null;

    if (postAuthorUid && postAuthorUid !== commenterUid) {
      const commenterUserDoc = await db
        .collection("users")
        .doc(commenterUid)
        .get();
      const commenterNickname =
        commenterUserDoc.exists && commenterUserDoc.data().nickname
          ? commenterUserDoc.data().nickname
          : "새로운 사용자";

      const title = `누군가가 댓글을 달았다 !`;
      const body = `${commenterNickname}사마가 댓글을 달아주셨다!`;

      const data = { type: "comment_added", postId, commentId };

      return sendNotification(title, body, data, commenterUid);
    }
    return null;
  }
);
