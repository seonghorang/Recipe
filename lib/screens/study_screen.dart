import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:record/record.dart'; // AudioRecorder 사용
import 'package:just_audio/just_audio.dart'; // AudioPlayer 사용
import 'package:path_provider/path_provider.dart'; // 임시 파일 경로
import 'package:permission_handler/permission_handler.dart'; // 권한 관리
import 'dart:io';
import '../models/study_model.dart';
import '../services/study_service.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({Key? key}) : super(key: key);

  @override
  _StudyScreenState createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  final StudyService _studyService = StudyService();
  User? _currentUser;
  bool _showMyPostsOnly = false; // 내 게시글만 볼지 여부

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
  }

  // 게시글 작성 모달 표시
  void _showCreatePostModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: CreatePostForm(),
      ),
    );
  }

  // 게시글 상세 모달 표시
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
            onPressed: () {
              setState(() {
                _showMyPostsOnly = !_showMyPostsOnly;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // 로그아웃 후 로그인 화면으로 이동 또는 앱 종료
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
            print("Error loading posts: ${snapshot.error}");
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
                  subtitle: Text(
                      '${post.meaning} (By: ${post.userId == _currentUser!.uid ? '나' : '상대방'})'),
                  trailing: Text(
                      '${post.createdAt.toDate().toLocal().month}/${post.createdAt.toDate().toLocal().day}'),
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

// =========================================================================
// CreatePostForm (게시글 작성 및 녹음 UI)
// =========================================================================

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
  bool _isUploading = false; // 업로드 중인지 여부

  @override
  void initState() {
    super.initState();
    _requestPermissions(); // 권한 요청
    _audioPlayer.playerStateStream.listen((playerState) {
      final processingState = playerState.processingState;
      final playing = playerState.playing;
      setState(() {
        _isPlayerActive =
            playing || processingState == ProcessingState.buffering;
        if (processingState == ProcessingState.completed) {
          _isPlayerActive = false;
          _audioPlayer.seek(Duration.zero);
          _audioPlayer.stop();
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
    if (await _audioRecorder.isRecording()) return;

    final appDocDir = await getApplicationDocumentsDirectory();
    _localAudioPath =
        '${appDocDir.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
      path: _localAudioPath!,
    );
    setState(() {
      _isRecording = true;
    });
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _localAudioPath = path;
    });
  }

  Future<void> _togglePlayStop() async {
    if (_localAudioPath == null) return;
    final playerState = _audioPlayer.playerState;

    if (playerState.playing) {
      await _audioPlayer.pause();
    } else if (playerState.processingState == ProcessingState.ready) {
      await _audioPlayer.play();
    } else {
      try {
        await _audioPlayer.setFilePath(_localAudioPath!); // 로컬 파일 재생
        await _audioPlayer.play();
      } catch (e) {
        print("오디오 파일 로드 또는 재생 실패: $e");
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('오디오 재생 실패: ${e.toString()}')));
        _localAudioPath = null;
        setState(() {});
      }
    }
  }

  Future<void> _savePost() async {
    if (_localAudioPath == null ||
        _sentenceController.text.isEmpty ||
        _meaningController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('문장, 뜻, 녹음 파일은 필수입니다.')));
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('게시글이 성공적으로 등록되었습니다!')));
      Navigator.pop(context); // 모달 닫기
    } catch (e) {
      print('게시글 저장 실패: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('게시글 저장 실패: $e')));
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
          children: [
            Text('게시글 작성', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            TextField(
              controller: _sentenceController,
              decoration: const InputDecoration(
                labelText: '녹음할 문장 (필수)',
                border: OutlineInputBorder(),
              ),
              maxLines: null,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _meaningController,
              decoration: const InputDecoration(
                labelText: '뜻 (필수)',
                border: OutlineInputBorder(),
              ),
              maxLines: null,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: '악센트나 주의점 (선택)',
                border: OutlineInputBorder(),
              ),
              maxLines: null,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _isRecording ? _stopRecording : _startRecording,
                  icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                  label: Text(_isRecording ? '녹음 중지' : '녹음 시작'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isRecording ? Colors.red : Colors.green),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _localAudioPath == null ? null : _togglePlayStop,
                  icon: Icon(
                    _isPlayerActive
                        ? (_audioPlayer.playerState.playing
                            ? Icons.pause
                            : Icons.play_arrow)
                        : Icons.play_arrow,
                  ),
                  label: Text(_isPlayerActive
                      ? (_audioPlayer.playerState.playing ? '일시정지' : '재생')
                      : '재생'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_localAudioPath != null)
              Text('녹음 파일 준비됨: ${_localAudioPath!.split('/').last}'),
            if (_isUploading) const LinearProgressIndicator(),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isUploading ? null : _savePost,
              child: const Text('게시글 등록'),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.brown[700],
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// PostDetailView (게시글 상세 및 댓글 목록/작성 UI)
// =========================================================================

class PostDetailView extends StatefulWidget {
  final StudyPost post;

  const PostDetailView({Key? key, required this.post}) : super(key: key);

  @override
  _PostDetailViewState createState() => _PostDetailViewState();
}

class _PostDetailViewState extends State<PostDetailView> {
  final StudyService _studyService = StudyService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer(); // 게시글 본문 오디오용
  final Map<String, AudioPlayer> _commentPlayers = {}; // 댓글 오디오용
  final TextEditingController _commentTextController = TextEditingController();

  String? _commentAudioPath;
  bool _isRecordingComment = false;
  bool _isPlayingPost = false;
  bool _isUploadingComment = false;
  String? _currentPlayingCommentId; // 현재 재생 중인 댓글 ID

  @override
  void initState() {
    super.initState();
    _requestPermissions(); // 권한 요청
    // 게시글 오디오 플레이어 상태 리스너
    _audioPlayer.playerStateStream.listen((playerState) {
      final processingState = playerState.processingState;
      final playing = playerState.playing;
      setState(() {
        _isPlayingPost =
            playing || processingState == ProcessingState.buffering;
        if (processingState == ProcessingState.completed) {
          _isPlayingPost = false;
          _audioPlayer.seek(Duration.zero);
          _audioPlayer.stop();
        }
      });
    });
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
  }

  // 게시글 오디오 재생/일시정지
  Future<void> _togglePostPlayStop() async {
    if (widget.post.recordedAudioUrl.isEmpty) return;
    final playerState = _audioPlayer.playerState;

    if (playerState.playing) {
      await _audioPlayer.pause();
    } else if (playerState.processingState == ProcessingState.ready) {
      await _audioPlayer.play();
    } else {
      try {
        await _audioPlayer.setUrl(widget.post.recordedAudioUrl); // URL 사용
        await _audioPlayer.play();
      } catch (e) {
        print("게시글 오디오 재생 실패: $e");
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('게시글 오디오 재생 실패: ${e.toString()}')));
      }
    }
  }

  // 댓글 오디오 재생/일시정지
  Future<void> _toggleCommentPlayStop(Comment comment) async {
    // 이미 재생 중인 댓글이 있다면 중지
    if (_currentPlayingCommentId != null &&
        _commentPlayers.containsKey(_currentPlayingCommentId)) {
      await _commentPlayers[_currentPlayingCommentId]!.stop();
      _currentPlayingCommentId = null;
    }

    // 현재 재생하려는 댓글 플레이어 가져오기 (없으면 새로 생성)
    AudioPlayer player = _commentPlayers.putIfAbsent(comment.id, () {
      final newPlayer = AudioPlayer();
      newPlayer.playerStateStream.listen((playerState) {
        if (playerState.processingState == ProcessingState.completed) {
          setState(() {
            if (_currentPlayingCommentId == comment.id) {
              _currentPlayingCommentId = null; // 완료되면 현재 재생 ID 초기화
            }
            newPlayer.stop(); // 완료 후 플레이어 정리
            newPlayer.seek(Duration.zero);
          });
        }
      });
      return newPlayer;
    });

    if (player.playerState.playing) {
      await player.pause();
      setState(() {
        _currentPlayingCommentId = null;
      });
    } else {
      try {
        // 현재 댓글만 재생되도록 설정
        if (comment.audioUrl != null) {
          // <<< null 체크 추가
          await player.setUrl(comment
              .audioUrl!); // <<< ! (null-assertion operator) 추가하여 String?에서 String으로 변환
        } else {
          // audioUrl이 null인 경우 (텍스트 댓글)
          print("댓글에 오디오 URL이 없습니다. 재생할 수 없습니다.");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('오디오가 없는 댓글입니다.')),
          );
          return; // 오디오가 없으므로 재생 로직 중단
        }
        await player.play();
        setState(() {
          _currentPlayingCommentId = comment.id;
        });
      } catch (e) {
        print("댓글 오디오 재생 실패: $e");
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('댓글 오디오 재생 실패: ${e.toString()}')));
        setState(() {
          _currentPlayingCommentId = null;
        });
      }
    }
  }

  // 댓글 녹음 시작
  Future<void> _startRecordingComment() async {
    if (!await Permission.microphone.isGranted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('마이크 권한이 필요합니다.')));
      return;
    }
    if (await _audioRecorder.isRecording()) return;

    final appDocDir = await getApplicationDocumentsDirectory();
    _commentAudioPath =
        '${appDocDir.path}/temp_comment_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
      path: _commentAudioPath!,
    );
    setState(() {
      _isRecordingComment = true;
    });
  }

  // 댓글 녹음 중지
  Future<void> _stopRecordingComment() async {
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecordingComment = false;
      _commentAudioPath = path;
      // 녹음 중지 시 텍스트 입력 필드도 비움
      _commentTextController.clear(); // <<< 추가: 녹음 시작하면 텍스트는 지우도록 (카톡처럼)
    });
  }

  // 댓글 전송 (음성/텍스트 통합)
  Future<void> _sendComment() async {
    final String commentText = _commentTextController.text.trim();

    // 조건: 텍스트가 비어있고, 녹음된 파일도 없는 경우
    if (commentText.isEmpty && _commentAudioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('댓글 내용을 입력하거나 음성을 녹음해주세요.')));
      return;
    }

    // 이미 업로드 중이거나 녹음 중이라면 방지
    if (_isUploadingComment || _isRecordingComment) return;

    setState(() {
      _isUploadingComment = true;
    });

    try {
      await _studyService.addComment(
        postId: widget.post.id,
        localAudioFilePath: _commentAudioPath, // null일 수 있음 (텍스트만 있는 경우)
        text: commentText, // null일 수 있음 (음성만 있는 경우)
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('댓글이 성공적으로 등록되었습니다!')));

      // 전송 성공 후 필드 초기화
      _commentAudioPath = null;
      _commentTextController.clear();
    } catch (e) {
      print('댓글 전송 실패: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('댓글 전송 실패: ${e.toString()}')));
    } finally {
      setState(() {
        _isUploadingComment = false;
      });
    }
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _commentPlayers.values.forEach((player) => player.dispose());
    _commentTextController.dispose(); // <<< dispose 추가
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
            Text('게시글 상세', style: Theme.of(context).textTheme.headlineMedium),
            const Divider(),
            Text('문장: ${widget.post.recordedSentence}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('뜻: ${widget.post.meaning}'),
            if (widget.post.notes.isNotEmpty) Text('주의점: ${widget.post.notes}'),
            Text(
                '작성자: ${widget.post.userId == FirebaseAuth.instance.currentUser?.uid ? '나' : '상대방'}'),
            Text(
                '작성일: ${widget.post.createdAt.toDate().toLocal().toString().split('.')[0]}'),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _togglePostPlayStop,
              icon: Icon(_isPlayingPost ? Icons.pause : Icons.play_arrow),
              label: Text(_isPlayingPost ? '본문 일시정지' : '본문 재생'),
            ),
            const Divider(),
            Text('댓글', style: Theme.of(context).textTheme.headlineSmall),
            StreamBuilder<List<Comment>>(
              stream: _studyService.getComments(widget.post.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('댓글 로드 오류: ${snapshot.error}');
                }
                final comments = snapshot.data ?? [];
                if (comments.isEmpty) {
                  return const Text('아직 댓글이 없습니다.');
                }
                return ListView.builder(
                  shrinkWrap: true, // ListView가 부모 크기에 맞춰 줄어들도록
                  physics: const NeverScrollableScrollPhysics(), // 스크롤 안 되도록
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return ListTile(
                      title: Text(comment.userId ==
                              FirebaseAuth.instance.currentUser?.uid
                          ? '내 댓글'
                          : '상대방 댓글'),
                      subtitle: Text(comment.createdAt
                          .toDate()
                          .toLocal()
                          .toString()
                          .split('.')[0]),
                      trailing: IconButton(
                        icon: Icon(
                          _currentPlayingCommentId == comment.id
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                          color: Colors.blue,
                        ),
                        onPressed: () => _toggleCommentPlayStop(comment),
                      ),
                    );
                  },
                );
              },
            ),
            const Divider(),
            // 댓글 작성 UI 재구성
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentTextController,
                    decoration: InputDecoration(
                      hintText: '댓글을 입력하세요.',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    minLines: 1,
                    maxLines: 5,
                    onChanged: (text) {
                      setState(() {});
                      // 텍스트가 입력되면 녹음 상태를 초기화할 필요는 없음
                      // 단, 카카오톡처럼 녹음 시작하면 텍스트는 지우는 로직은 _startRecordingComment()에 추가.
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // 마이크 버튼
                IconButton(
                  icon:
                      Icon(_isRecordingComment ? Icons.stop_circle : Icons.mic),
                  color: _isRecordingComment ? Colors.red : Colors.grey[600],
                  iconSize: 32,
                  onPressed: _isRecordingComment
                      ? _stopRecordingComment
                      : () {
                          // 녹음 시작 시 텍스트 필드를 비움 (카톡처럼)
                          _commentTextController.clear();
                          _startRecordingComment();
                        },
                ),
                // 전송/댓글 등록 버튼
                IconButton(
                  icon: Icon(
                      _isUploadingComment ? Icons.upload_file : Icons.send),
                  color: _commentTextController.text.isNotEmpty ||
                          _commentAudioPath != null
                      ? Colors.blue // 텍스트나 오디오가 있으면 활성화
                      : Colors.grey, // 없으면 비활성화
                  iconSize: 32,
                  onPressed: _isUploadingComment ||
                          (_commentTextController.text.isEmpty &&
                              _commentAudioPath == null)
                      ? null // 업로드 중이거나 내용 없으면 비활성화
                      : _sendComment,
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 하단 여백
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
