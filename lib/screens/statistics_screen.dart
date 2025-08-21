import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final _sentenceController = TextEditingController();
  final _meaningController = TextEditingController();
  final _accentNotesController = TextEditingController();
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  bool _isRecording = false;
  String? _audioPath;
  String? _userId;
  final Map<String, TextEditingController> _commentControllers = {};
  final Map<String, bool> _isCommentRecording = {};
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

@override
  void initState() {
    super.initState();
    _initializeAudio();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    if (_userId == null) {
      print('Error: No user logged in');
    }
  }

  Future<void> _initializeAudio() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('마이크 권한이 필요합니다.')),
      );
      return;
    }
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();
    await _recorder!.openRecorder();
    await _player!.openPlayer();
  }

  @override
  void dispose() {
    _sentenceController.dispose();
    _meaningController.dispose();
    _accentNotesController.dispose();
    _recordingTimer?.cancel();
    _recorder?.closeRecorder();
    _player?.closePlayer();
    _commentControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_recorder?.isRecording ?? false) return;
    final dir = await getTemporaryDirectory();
    _audioPath = '${dir.path}/study_audio_${DateTime.now().millisecondsSinceEpoch}.aac';
    try {
      await _recorder!.startRecorder(
        toFile: _audioPath,
        codec: Codec.aacADTS,
      );
      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
      });
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingSeconds++;
          if (_recordingSeconds >= 30) {
            _stopRecording();
          }
        });
      });
    } catch (e) {
      print('Recording start error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('녹음 시작 실패')),
      );
    }
  }

  Future<void> _stopRecording() async {
    if (!_recorder!.isRecording) return;
    try {
      await _recorder!.stopRecorder();
      _recordingTimer?.cancel();
      setState(() {
        _isRecording = false;
        _recordingSeconds = 0;
      });
    } catch (e) {
      print('Recording stop error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('녹음 중지 실패')),
      );
    }
  }

  Future<String?> _uploadFile(String filePath, String storagePath) async {
    int retries = 3;
    while (retries > 0) {
      try {
        var ref = FirebaseStorage.instance.ref(storagePath);
        await ref.putFile(
          File(filePath),
          SettableMetadata(customMetadata: {'userId': _userId ?? ''}),
        );
        return await ref.getDownloadURL();
      } catch (e) {
        print('Storage upload error: $e');
        retries--;
        if (retries == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('음성 업로드 실패')),
          );
          return null;
        }
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    return null;
  }

  Future<void> _savePost() async {
    if (_sentenceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문장을 입력하세요')),
      );
      return;
    }
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다')),
      );
      return;
    }
    String? audioUrl;
    if (_audioPath != null && File(_audioPath!).existsSync()) {
      audioUrl = await _uploadFile(
        _audioPath!,
        'study_audio/$_userId/${DateTime.now().millisecondsSinceEpoch}.aac',
      );
      if (audioUrl == null) return;
    }
    try {
      await FirebaseFirestore.instance.collection('study_posts').add({
        'userId': _userId,
        'sentence': _sentenceController.text,
        'meaning': _meaningController.text,
        'accentNotes': _accentNotesController.text,
        'audioUrl': audioUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장되었습니다')),
      );
      _sentenceController.clear();
      _meaningController.clear();
      _accentNotesController.clear();
      _audioPath = null;
    } catch (e) {
      print('Firestore save error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장 실패')),
      );
    }
  }

  Future<void> _playAudio(String url) async {
    try {
      await _player!.startPlayer(fromURI: url);
    } catch (e) {
      print('Playback error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('음성 재생 실패')),
      );
    }
  }

  Future<void> _startCommentRecording(String postId) async {
    if (_recorder?.isRecording ?? false) return;
    final dir = await getTemporaryDirectory();
    _audioPath = '${dir.path}/comment_audio_${DateTime.now().millisecondsSinceEpoch}.aac';
    try {
      await _recorder!.startRecorder(
        toFile: _audioPath,
        codec: Codec.aacADTS,
      );
      setState(() {
        _isCommentRecording[postId] = true;
        _recordingSeconds = 0;
      });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingSeconds++;
          if (_recordingSeconds >= 30) {
            _stopCommentRecording(postId);
          }
        });
      });
    } catch (e) {
      print('Comment recording start error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('코멘트 녹음 시작 실패')),
      );
    }
  }

  Future<void> _stopCommentRecording(String postId) async {
    if (!_recorder!.isRecording) return;
    try {
      await _recorder!.stopRecorder();
      _recordingTimer?.cancel();
      setState(() {
        _isCommentRecording[postId] = false;
        _recordingSeconds = 0;
      });
    } catch (e) {
      print('Comment recording stop error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('코멘트 녹음 중지 실패')),
      );
    }
  }

  Future<void> _addComment(String postId) async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다')),
      );
      return;
    }
    String text = _commentControllers[postId]?.text ?? '';
    String? commentAudioUrl;
    if (_audioPath != null && File(_audioPath!).existsSync()) {
      commentAudioUrl = await _uploadFile(
        _audioPath!,
        'study_comment_audio/$_userId/${DateTime.now().millisecondsSinceEpoch}.aac',
      );
      if (commentAudioUrl == null) return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('study_posts')
          .doc(postId)
          .collection('comments')
          .add({
        'userId': _userId,
        'text': text,
        'commentAudioUrl': commentAudioUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('코멘트 추가되었습니다')),
      );
      _commentControllers[postId]?.clear();
      _audioPath = null;
    } catch (e) {
      print('Comment Firestore save error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('코멘트 저장 실패')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            '공부',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: Colors.brown[700],
        ),
        body: const Center(child: Text('로그인이 필요합니다.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '공부',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.brown[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _sentenceController,
              decoration: const InputDecoration(labelText: '문장'),
            ),
            TextField(
              controller: _meaningController,
              decoration: const InputDecoration(labelText: '뜻'),
            ),
            TextField(
              controller: _accentNotesController,
              decoration: const InputDecoration(labelText: '악센트 주의점'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isRecording ? _stopRecording : _startRecording,
                  child: Text(_isRecording
                      ? '녹음 중지 (${_recordingSeconds}s)'
                      : '녹음 시작'),
                ),
                ElevatedButton(
                  onPressed: _savePost,
                  child: const Text('저장'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '최근 기록',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('study_posts')
                    .where('userId', isEqualTo: _userId)
                    .orderBy('createdAt', descending: true)
                    .limit(5)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    print('Firestore error: ${snapshot.error}');
                    return Center(child: Text('오류: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('기록이 없습니다.'));
                  }
                  final posts = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      final postData = post.data() as Map<String, dynamic>;
                      _commentControllers[post.id] ??= TextEditingController();
                      _isCommentRecording[post.id] ??= false;
                      return ExpansionTile(
                        title: Text(postData['sentence'] ?? '문장 없음'),
                        subtitle: Text(
                          postData['createdAt'] != null
                              ? DateFormat('yyyy-MM-dd HH:mm').format(
                                  (postData['createdAt'] as Timestamp).toDate(),
                                )
                              : '날짜 없음',
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('뜻: ${postData['meaning'] ?? '없음'}'),
                                Text('악센트 주의점: ${postData['accentNotes'] ?? '없음'}'),
                                if (postData['audioUrl'] != null)
                                  ElevatedButton(
                                    onPressed: () => _playAudio(postData['audioUrl']),
                                    child: const Text('음성 재생'),
                                  ),
                                const SizedBox(height: 8),
                                const Text(
                                  '코멘트',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('study_posts')
                                      .doc(post.id)
                                      .collection('comments')
                                      .orderBy('createdAt', descending: true)
                                      .snapshots(),
                                  builder: (context, commentSnapshot) {
                                    if (!commentSnapshot.hasData) {
                                      return const CircularProgressIndicator();
                                    }
                                    final comments = commentSnapshot.data!.docs;
                                    return ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: comments.length,
                                      itemBuilder: (context, commentIndex) {
                                        final commentData = comments[commentIndex].data() as Map<String, dynamic>;
                                        return ListTile(
                                          title: Text(commentData['text']?.isNotEmpty ?? false
                                              ? commentData['text']
                                              : '코멘트 없음'),
                                          subtitle: Text(
                                            commentData['createdAt'] != null
                                                ? DateFormat('yyyy-MM-dd HH:mm').format(
                                                    (commentData['createdAt'] as Timestamp).toDate(),
                                                  )
                                                : '날짜 없음',
                                          ),
                                          trailing: commentData['commentAudioUrl'] != null
                                              ? IconButton(
                                                  icon: const Icon(Icons.play_arrow),
                                                  onPressed: () => _playAudio(commentData['commentAudioUrl']),
                                                )
                                              : null,
                                        );
                                      },
                                    );
                                  },
                                ),
                                TextField(
                                  controller: _commentControllers[post.id],
                                  decoration: const InputDecoration(labelText: '코멘트 텍스트 (옵션)'),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton(
                                      onPressed: _isCommentRecording[post.id]!
                                          ? () => _stopCommentRecording(post.id)
                                          : () => _startCommentRecording(post.id),
                                      child: Text(_isCommentRecording[post.id]!
                                          ? '녹음 중지 (${_recordingSeconds}s)'
                                          : '코멘트 녹음 시작'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => _addComment(post.id),
                                      child: const Text('코멘트 추가'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}