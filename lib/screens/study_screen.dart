import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/study_model.dart';
import '../services/study_service.dart';

// 공통 유틸리티: 닉네임 가져오기
class FirestoreUtils {
  static final Map<String, String> _nicknameCache = {};

  static Future<String> getNickname(String userId) async {
    if (_nicknameCache.containsKey(userId)) {
      print('Nickname from cache for UID $userId: ${_nicknameCache[userId]}');
      return _nicknameCache[userId]!;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (!userDoc.exists) {
        print('No user document found for UID: $userId');
        _nicknameCache[userId] = '알 수 없음';
        return '알 수 없음';
      }
      final data = userDoc.data()!;
      final nickname = data['nickname'] ?? '알 수 없음';
      print('Nickname for UID $userId: $nickname, Full data: $data');
      _nicknameCache[userId] = nickname;
      return nickname;
    } catch (e) {
      print('Error fetching nickname for UID $userId: $e');
      _nicknameCache[userId] = '알 수 없음';
      return '알 수 없음';
    }
  }
}

class StudyScreen extends StatefulWidget {
  const StudyScreen({Key? key}) : super(key: key);

  @override
  _StudyScreenState createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  final StudyService _studyService = StudyService();
  User? _currentUser;
  bool _showMyPostsOnly = false;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
  }

  void _showCreatePostModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const CreatePostForm(),
      ),
    );
  }

  void _showPostDetailModal(BuildContext context, StudyPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: PostDetailView(post: post),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Center(child: Text('로그인이 필요합니다.'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('회화 공부 탭',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.brown[700],
        actions: [
          IconButton(
            icon: Icon(_showMyPostsOnly ? Icons.public : Icons.person,
                color: Colors.white),
            onPressed: () =>
                setState(() => _showMyPostsOnly = !_showMyPostsOnly),
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder<List<StudyPost>>(
        stream: _showMyPostsOnly
            ? _studyService.getStudyPosts(_currentUser!.uid)
            : _studyService.getAllStudyPosts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('게시글 로드 오류: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('아직 게시글이 없습니다.'));
          }

          final posts = snapshot.data!;
          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(post.recordedSentence),
                  subtitle: FutureBuilder<String>(
                    future: FirestoreUtils.getNickname(post.userId),
                    builder: (context, nicknameSnapshot) {
                      if (nicknameSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return Text('${post.meaning} (로딩 중...)');
                      }
                      if (nicknameSnapshot.hasError) {
                        print(
                            'Nickname error for post ${post.id}: ${nicknameSnapshot.error}');
                        return Text('${post.meaning} (By: 알 수 없음)');
                      }
                      final nickname = nicknameSnapshot.data ?? '알 수 없음';
                      final byText =
                          post.userId == _currentUser!.uid ? '나' : nickname;
                      return Text('${post.meaning} (By: $byText)');
                    },
                  ),
                  trailing: Text(
                    '${post.createdAt.toDate().toLocal().month}/${post.createdAt.toDate().toLocal().day}',
                  ),
                  onTap: () => _showPostDetailModal(context, post),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreatePostModal(context),
        backgroundColor: Colors.orange,
        child: const Icon(Icons.mic, color: Colors.white),
      ),
    );
  }
}

class CreatePostForm extends StatefulWidget {
  const CreatePostForm({Key? key}) : super(key: key);

  @override
  _CreatePostFormState createState() => _CreatePostFormState();
}

class _CreatePostFormState extends State<CreatePostForm> {
  final StudyService _studyService = StudyService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  final TextEditingController _sentenceController = TextEditingController();
  final TextEditingController _meaningController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String? _localAudioPath;
  bool _isRecording = false;
  bool _isPlayerActive = false;
  bool _isUploading = false;
  bool _isPlayerReady = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();

    _audioPlayer.playerStateStream.listen((playerState) {
      if (!mounted) return;
      setState(() {
        final processing = playerState.processingState;
        _isPlayerActive =
            playerState.playing || processing == ProcessingState.buffering;
        if (processing == ProcessingState.completed) {
          _isPlayerActive = false;
          _audioPlayer.seek(Duration.zero);
        }
      });
    });
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
  }

  Future<void> _startRecording() async {
    if (!await Permission.microphone.isGranted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('마이크 권한이 필요합니다.')));
      return;
    }
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: filePath);
      setState(() {
        _isRecording = true;
        _localAudioPath = filePath;
        _isPlayerReady = false;
      });
    } catch (e) {
      print('녹음 시작 오류: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('녹음 시작 오류: $e')));
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _isPlayerReady = true;
      });
      await _audioPlayer.setFilePath(_localAudioPath!);
    } catch (e) {
      print('녹음 중지 오류: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('녹음 중지 오류: $e')));
    }
  }

  Future<void> _togglePlayStop() async {
    try {
      if (_isPlayerActive) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play();
      }
    } catch (e) {
      print('재생/일시정지 오류: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('재생 오류: $e')));
    }
  }

  Future<void> _savePost() async {
    if (_sentenceController.text.isEmpty ||
        _meaningController.text.isEmpty ||
        _localAudioPath == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('모든 필드를 채워주세요.')));
      return;
    }
    setState(() {
      _isUploading = true;
    });
    try {
      await _studyService.addStudyPost(
        recordedSentence: _sentenceController.text,
        meaning: _meaningController.text,
        notes: _notesController.text,
        localAudioFilePath: _localAudioPath!,
      );
      Navigator.pop(context);
    } catch (e) {
      print('게시글 저장 오류: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('게시글 저장 오류: $e')));
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _sentenceController.dispose();
    _meaningController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('게시글 작성', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 10),
            TextField(
              controller: _sentenceController,
              decoration: const InputDecoration(
                labelText: '일본어 문장',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _meaningController,
              decoration: const InputDecoration(
                labelText: '한국어 뜻',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: '발음 주의점',
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(_isRecording ? Icons.stop_circle : Icons.mic),
                  color: _isRecording ? Colors.red : Colors.grey[600],
                  iconSize: 40,
                  onPressed: _isRecording ? _stopRecording : _startRecording,
                ),
                if (_isPlayerReady)
                  IconButton(
                    icon: Icon(_isPlayerActive
                        ? Icons.pause_circle
                        : Icons.play_circle),
                    color: Colors.blue,
                    iconSize: 40,
                    onPressed: _togglePlayStop,
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _isUploading ? null : _savePost,
                child: _isUploading
                    ? const CircularProgressIndicator()
                    : const Text('게시글 저장'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class PostDetailView extends StatefulWidget {
  final StudyPost post;
  const PostDetailView({Key? key, required this.post}) : super(key: key);

  @override
  _PostDetailViewState createState() => _PostDetailViewState();
}

class _PostDetailViewState extends State<PostDetailView> {
  final StudyService _studyService = StudyService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Map<String, AudioPlayer> _commentPlayers = {};
  final TextEditingController _commentTextController = TextEditingController();

  String? _commentAudioPath;
  bool _isRecordingComment = false;
  bool _isUploadingComment = false;
  bool _isPlayerReady = false;
  bool _isPlayerBuffering = false;
  bool _isPlaying = false;

  String? _currentPlayingCommentId;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _requestPermissions();

    _audioPlayer.playerStateStream.listen((playerState) {
      if (!mounted) return;
      setState(() {
        _isPlaying = playerState.playing;
        _isPlayerBuffering =
            playerState.processingState == ProcessingState.buffering ||
                playerState.processingState == ProcessingState.loading;
        if (playerState.processingState == ProcessingState.completed) {
          _isPlaying = false;
          _audioPlayer.seek(Duration.zero);
        }
      });
    });
  }

  Future<void> _initPlayer() async {
    try {
      await _audioPlayer.setUrl(widget.post.recordedAudioUrl);
      if (mounted) {
        setState(() => _isPlayerReady = true);
      }
    } catch (e) {
      print('오디오 로드 오류: $e');
    }
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
  }

  Future<void> _togglePostPlayStop() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  Future<void> _toggleCommentPlayStop(Comment comment) async {
    final player = _commentPlayers.putIfAbsent(comment.id, () => AudioPlayer());

    if (_currentPlayingCommentId == comment.id) {
      await player.pause();
      setState(() => _currentPlayingCommentId = null);
      return;
    }

    if (_currentPlayingCommentId != null) {
      final currentPlayer = _commentPlayers[_currentPlayingCommentId];
      await currentPlayer?.stop();
    }

    setState(() => _currentPlayingCommentId = comment.id);

    try {
      await player.setUrl(comment.audioUrl!);
      await player.play();
    } catch (e) {
      print('댓글 오디오 재생 오류: $e');
      setState(() => _currentPlayingCommentId = null);
    }
  }

  Future<void> _startRecordingComment() async {
    if (!await Permission.microphone.isGranted) return;
    final tempDir = await getTemporaryDirectory();
    final filePath =
        '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _audioRecorder.start(const RecordConfig(), path: filePath);
    setState(() {
      _isRecordingComment = true;
      _commentAudioPath = filePath;
    });
  }

  Future<void> _stopRecordingComment() async {
    await _audioRecorder.stop();
    setState(() => _isRecordingComment = false);
  }

  Future<void> _sendComment() async {
    if (_commentTextController.text.isEmpty && _commentAudioPath == null)
      return;

    setState(() => _isUploadingComment = true);

    await _studyService.addComment(
      postId: widget.post.id,
      localAudioFilePath: _commentAudioPath,
      text: _commentTextController.text.isNotEmpty
          ? _commentTextController.text
          : null,
    );

    setState(() {
      _commentAudioPath = null;
      _commentTextController.clear();
      _isUploadingComment = false;
    });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    for (final p in _commentPlayers.values) {
      p.dispose();
    }
    _commentTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // ✅ 네비게이션 바, 상단 노치 영역 고려
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          // ✅ 키보드 + 네비게이션 바 영역을 반영
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('게시글 상세', style: Theme.of(context).textTheme.headlineMedium),
              const Divider(),
              Text('문장: ${widget.post.recordedSentence}'),
              Text('뜻: ${widget.post.meaning}'),
              const SizedBox(height: 10),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isPlayerBuffering || !_isPlayerReady
                        ? null
                        : _togglePostPlayStop,
                    icon: _isPlayerBuffering
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    label: Text(_isPlaying ? '일시정지' : '재생'),
                  ),
                ],
              ),
              const Divider(),
              Text('댓글', style: Theme.of(context).textTheme.headlineSmall),
              StreamBuilder<List<Comment>>(
                stream: _studyService.getComments(widget.post.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Text('댓글 없음');
                  final comments = snapshot.data!;
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: comments.length,
                    itemBuilder: (context, i) {
                      final c = comments[i];
                      final isPlaying = _currentPlayingCommentId == c.id;
                      return CommentTile(
                        comment: c,
                        isPlaying: isPlaying,
                        onToggle: () => _toggleCommentPlayStop(c),
                      );
                    },
                  );
                },
              ),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: TextField(controller: _commentTextController),
                  ),
                  IconButton(
                    icon: Icon(
                        _isRecordingComment ? Icons.stop_circle : Icons.mic),
                    onPressed: _isRecordingComment
                        ? _stopRecordingComment
                        : _startRecordingComment,
                  ),
                  IconButton(
                    icon: Icon(Icons.send),
                    onPressed: _isUploadingComment ? null : _sendComment,
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class CommentTile extends StatelessWidget {
  final Comment comment;
  final bool isPlaying;
  final VoidCallback onToggle;

  const CommentTile({
    Key? key,
    required this.comment,
    required this.isPlaying,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(comment.text ?? '오디오 댓글'),
      subtitle:
          Text(comment.createdAt.toDate().toLocal().toString().split('.')[0]),
      trailing: comment.audioUrl != null
          ? IconButton(
              icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle),
              color: Colors.blue,
              onPressed: onToggle,
            )
          : null,
    );
  }
}
