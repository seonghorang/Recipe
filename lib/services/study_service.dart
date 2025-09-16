import 'package:cloud_firestore/cloud_firestore.dart'; // <<< 이 import 추가
import 'package:firebase_storage/firebase_storage.dart'; // <<< 이 import 추가
import 'package:firebase_auth/firebase_auth.dart'; // <<< 이 import 추가
import 'dart:io';
import '../models/study_model.dart';

class StudyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 게시글 추가
  Future<void> addStudyPost({
    required String recordedSentence,
    required String meaning,
    required String notes,
    required String localAudioFilePath,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      // print('Error: User not logged in for adding post.');
      return;
    }

    String? audioUrl =
        await _uploadAudioFile(localAudioFilePath, user.uid, 'study_posts');
    if (audioUrl == null) {
      // print('Error: Audio file upload failed.');
      return;
    }

    StudyPost newPost = StudyPost(
      id: '', // Firestore에서 자동 생성
      userId: user.uid,
      recordedAudioUrl: audioUrl,
      recordedSentence: recordedSentence,
      meaning: meaning,
      notes: notes,
      createdAt: Timestamp.now(),
    );

    await _firestore.collection('study_posts').add(newPost.toFirestore());
  }

  // 특정 사용자의 게시글 스트림
  Stream<List<StudyPost>> getStudyPosts(String userId) {
    return _firestore
        .collection('study_posts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => StudyPost.fromFirestore(doc)).toList());
  }

  // 모든 게시글 스트림
  Stream<List<StudyPost>> getAllStudyPosts() {
    return _firestore
        .collection('study_posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => StudyPost.fromFirestore(doc)).toList());
  }

  // 댓글 추가
  Future<void> addComment({
    required String postId,
    String? localAudioFilePath, // 선택 사항
    String? text, // <<< 추가: 텍스트 댓글 (선택 사항)
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      // print('Error: User not logged in for adding comment.');
      throw Exception('User not logged in'); // 오류 throw
    }

    if (localAudioFilePath == null && text == null) {
      // print('Error: Comment must have either audio or text.');
      throw Exception('댓글 내용이 없습니다.'); // 오류 throw
    }

    String? audioUrl;
    if (localAudioFilePath != null) {
      audioUrl =
          await _uploadAudioFile(localAudioFilePath, user.uid, 'comments');
      if (audioUrl == null) {
        // print('Error: Audio file upload failed.');
        throw Exception('음성 파일 업로드 실패');
      }
    }

    Comment newComment = Comment(
      id: '', // Firestore에서 자동 생성
      userId: user.uid,
      audioUrl: audioUrl,
      text: text, // <<< 텍스트 필드 할당
      createdAt: Timestamp.now(),
    );

    await _firestore
        .collection('study_posts')
        .doc(postId)
        .collection('comments')
        .add(newComment.toFirestore());
  }

  // 특정 게시글의 댓글 스트림
  Stream<List<Comment>> getComments(String postId) {
    return _firestore
        .collection('study_posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Comment.fromFirestore(doc)).toList());
  }

  // 오디오 파일 업로드
  Future<String?> _uploadAudioFile(
      String filePath, String userId, String type) async {
    try {
      final file = File(filePath);
      final storageRef = _storage
          .ref()
          .child('users')
          .child(userId)
          .child(type)
          .child('${DateTime.now().millisecondsSinceEpoch}.m4a');

      // print('Firebase Storage 업로드 시작: ${storageRef.fullPath}');
      final uploadTask =
          storageRef.putFile(file, SettableMetadata(contentType: 'audio/m4a'));
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // print('Firebase Storage 업로드 성공. URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      // print('Firebase Storage 업로드 오류: $e');
      return null;
    }
  }
}
