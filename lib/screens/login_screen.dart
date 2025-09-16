import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  bool _isLoading = false;
  bool _showNicknameField = false;

  Future<void> _saveUserProfile(User user,
      {String? nickname, String? email}) async {
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    // 닉네임이 제공되지 않았으면 임시로 '사용자UID'로 설정
    final String displayNickname = nickname?.trim().isNotEmpty == true
        ? nickname!
        : '사용자_${user.uid.substring(0, 5)}';

    await userRef.set({
      'nickname': displayNickname,
      'email': email ?? user.email ?? 'no_email@example.com', // 이메일이 없을 경우 기본값
      'createdAt': FieldValue.serverTimestamp(), // Firestore에 최초 생성될 때만 유효
      // 'updatedAt': FieldValue.serverTimestamp(), // 마지막 업데이트 시간 (선택 사항)
    }, SetOptions(merge: true)); // merge:true는 기존 필드를 덮어쓰지 않고 추가/업데이트
    // print(
    //'User profile saved/updated for UID: ${user.uid} with nickname: $displayNickname');
  }

  Future<void> _saveFCMToken(String userId) async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(userId).set(
            {'fcmToken': token},
            SetOptions(merge: true)); // 기존 프로필에 토큰 추가 (merge: true)
        // print('FCM Token saved: $token');
      }
    } catch (e) {
      // print('Error saving FCM token: $e');
    }
  }

  Future<void> _signInWithEmail() async {
    setState(() {
      _isLoading = true;
      _showNicknameField = false;
    });
    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        // 기존 닉네임 필드를 업데이트하거나, 첫 로그인 시 기본값으로 저장
        await _saveUserProfile(userCredential.user!,
            email: _emailController.text.trim());
        await _saveFCMToken(userCredential.user!.uid);
      }

      // Navigator.pushReplacement로 화면 전환 제거 (main.dart의 StreamBuilder가 처리)
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found') {
        message = '사용자를 찾을 수 없습니다.';
      } else if (e.code == 'wrong-password') {
        message = '비밀번호가 일치하지 않습니다.';
      } else {
        message = '로그인 실패: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 실패: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signUpWithEmail() async {
    setState(() {
      _isLoading = true;
    });
    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (userCredential.user != null) {
        await _saveUserProfile(
          userCredential.user!,
          nickname: _nicknameController.text.trim(), // 회원가입 시 입력받은 닉네임 사용
          email: _emailController.text.trim(),
        );
        await _saveFCMToken(userCredential.user!.uid);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입 성공!')),
      );
      // Navigator.pushReplacement로 화면 전환 제거
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'weak-password') {
        message = '비밀번호가 너무 약합니다.';
      } else if (e.code == 'email-already-in-use') {
        message = '이미 사용 중인 이메일입니다.';
      } else {
        message = '회원가입 실패: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('회원가입 실패: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInAnonymously() async {
    setState(() {
      _isLoading = true;
    });
    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.signInAnonymously();
      // <<< 익명 로그인 성공 시 사용자 프로필 저장 >>>
      if (userCredential.user != null) {
        await _saveUserProfile(userCredential.user!); // 익명 사용자는 닉네임 기본값 사용
        await _saveFCMToken(userCredential.user!.uid);
      }
      // Navigator.pushReplacement로 화면 전환 제거
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'operation-not-allowed') {
        message = '익명 로그인이 허용되지 않습니다.';
      } else {
        message = '익명 로그인 실패: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('익명 로그인 실패: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose(); // <<< 닉네임 컨트롤러 dispose 추가
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(
          '로그인',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.brown[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: '이메일'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: '비밀번호'),
              obscureText: true,
            ),
            if (_showNicknameField)
              Column(
                children: [
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nicknameController,
                    decoration:
                        const InputDecoration(labelText: '닉네임 (회원가입 시 사용)'),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            _isLoading
                ? const CircularProgressIndicator()
                : Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          // 로그인 버튼 누르면 닉네임 필드 숨기고 로그인 시도
                          setState(() {
                            _showNicknameField = false;
                          });
                          _signInWithEmail();
                        },
                        child: const Text('로그인'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // 회원가입 버튼 누르면 닉네임 필드 보여주고, 회원가입 시도
                          // (회원가입은 닉네임 필드가 보이게 한 상태에서 다시 누르면 실제 회원가입 진행)
                          if (!_showNicknameField) {
                            setState(() {
                              _showNicknameField = true; // 닉네임 필드를 보여줌
                            });
                          } else {
                            // 닉네임 필드가 이미 보여져 있다면 실제 회원가입 로직 실행
                            _signUpWithEmail();
                          }
                        },
                        child: const Text('회원가입'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // 익명 로그인 버튼 누르면 닉네임 필드 숨기고 익명 로그인 시도
                          setState(() {
                            _showNicknameField = false;
                          });
                          _signInAnonymously();
                        },
                        child: const Text('익명 로그인'),
                      ),
                    ],
                  ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
