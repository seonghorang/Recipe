import 'package:cloud_firestore/cloud_firestore.dart';

class StudyPost {
  final String id;
  final String userId;
  final String recordedAudioUrl;
  final String recordedSentence;
  final String meaning;
  final String notes;
  final Timestamp createdAt;

  StudyPost({
    required this.id,
    required this.userId,
    required this.recordedAudioUrl,
    required this.recordedSentence,
    required this.meaning,
    required this.notes,
    required this.createdAt,
  });

  factory StudyPost.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return StudyPost(
      id: doc.id,
      userId: data['userId'] ?? '',
      recordedAudioUrl: data['recordedAudioUrl'] ?? '',
      recordedSentence: data['recordedSentence'] ?? '',
      meaning: data['meaning'] ?? '',
      notes: data['notes'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'recordedAudioUrl': recordedAudioUrl,
      'recordedSentence': recordedSentence,
      'meaning': meaning,
      'notes': notes,
      'createdAt': createdAt,
    };
  }
}

class Comment {
  final String id;
  final String userId;
  final String? audioUrl;
  final String? text;
  final Timestamp createdAt;

  Comment({
    required this.id,
    required this.userId,
    this.audioUrl, // audioUrl도 선택적
    this.text, // text도 선택적
    required this.createdAt,
  });

  factory Comment.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Comment(
      id: doc.id,
      userId: data['userId'] ?? '',
      audioUrl: data['audioUrl'], // null이 될 수 있음
      text: data['text'], // null이 될 수 있음
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'audioUrl': audioUrl,
      'text': text, // <<< toFirestore에도 text 필드 추가
      'createdAt': createdAt,
    };
  }
}
