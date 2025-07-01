import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/recipe_detail_screen.dart';
import 'screens/recipe_list_screen.dart';
import 'screens/statistics_screen.dart';
import 'package:intl/intl.dart';
import 'firebase_options.dart';

// 푸시 알림을 위한 로컬 알림 플러그인 초기화
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// messaging 알림 설정
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    print('Background message received: ${message.messageId}');
    print('Message data: ${message.data}');
    if (message.notification != null) {
      print(
          'Notification: ${message.notification!.title} - ${message.notification!.body}');
      // 백그라운드에서도 로컬 알림 표시
      await flutterLocalNotificationsPlugin.show(
        message.hashCode,
        message.notification!.title,
        message.notification!.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'recipe_manager_channel',
            'Recipe Manager Notifications',
            channelDescription: 'Notifications for recipe updates',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  } catch (e) {
    print('Background notification error: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // ✅ Firebase 초기화 전에 호출해야 함
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform); // ✅ Firebase 초기화
  // 푸시 알림 권한 요청
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  try {
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    print('User granted permission: ${settings.authorizationStatus}');

// FCM 토큰 획득 및 Firestore에 저장
    String? fcmToken = await messaging.getToken();
    if (settings.authorizationStatus == AuthorizationStatus.authorized &&
        fcmToken != null) {
      print('FCM Token: $fcmToken');
      // Firestore에 토큰 저장 (레시피 알림 전송용)
      await FirebaseFirestore.instance
          .collection('users')
          .doc('device_tokens')
          .set(
        {'token': fcmToken, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } else {
      print('FCM Token or permission not granted');
    }
  } catch (e) {
    print('Error in Firebase Messaging setup: $e');
  }

// 포그라운드 알림 처리
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    try {
      print('Foreground message: ${message.messageId}, Data: ${message.data}');
      if (message.notification != null) {
        print(
            'Notification: ${message.notification!.title} - ${message.notification!.body}');
        await flutterLocalNotificationsPlugin.show(
          message.hashCode,
          message.notification!.title,
          message.notification!.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'recipe_manager_channel',
              'Recipe Manager Notifications',
              channelDescription: 'Notifications for recipe updates',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      }
    } catch (e) {
      print('Foreground notification error: $e');
    }
  });

// 백그라운드 알림 핸들러 설정
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

// 로컬 알림 초기화
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  try {
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  } catch (e) {
    print('Local notifications initialization error: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Recipe Manager',
      theme: ThemeData(
        primarySwatch: Colors.brown,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  static const List<Widget> _screens = [
    HomeScreen(),
    RecipeListScreen(),
    StatisticsScreen(),
  ];

  void _onItemTapped(int index) {
    print('Tapped index: $index'); // 디버깅 로그
    setState(() {
      _selectedIndex = index.clamp(0, _screens.length - 1); // 인덱스 범위 제한
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: '레시피'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '통계'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.brown[700],
        onTap: _onItemTapped,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<QueryDocumentSnapshot> recipes = [];
  bool isCoffeeSelected = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('레시피 상자')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: '레시피 검색...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      isCoffeeSelected = true;
                    });
                  },
                  child: const Text('☕ 커피 레시피'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      isCoffeeSelected = false;
                    });
                  },
                  child: const Text('🍽 요리 레시피'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              '최신 레시피',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('recipes')
                    .where('category',
                        isEqualTo: isCoffeeSelected ? 'coffee' : 'cooking')
                    .orderBy('createdAt', descending: true)
                    .limit(5)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('오류 발생: ${snapshot.error}'));
                  }

                  final recipes = snapshot.data?.docs ?? [];
                  return ListView.builder(
                    itemCount: recipes.length,
                    itemBuilder: (context, index) {
                      var recipe = recipes[index];
                      var recipeData = recipe.data() as Map<String, dynamic>?;
                      return ListTile(
                        title: Text(
                          // 커피 레시피일 경우 beans 필드를 표시
                          isCoffeeSelected
                              ? (recipeData != null &&
                                      recipeData.containsKey('beans')
                                  ? (recipeData['beans'] as List<dynamic>)
                                          ?.map((bean) => bean['name'])
                                          .join(', ') ??
                                      '원두 없음'
                                  : '원두 없음') // beans 필드가 없을 경우
                              : (recipeData != null &&
                                      recipeData.containsKey('recipeName')
                                  ? recipeData['recipeName'] // 요리 이름으로 설정
                                  : '요리 이름 없음'), // 요리 이름이 없을 경우
                        ),
                        subtitle: Text(
                          recipe['createdAt'] != null
                              ? DateFormat('yyyy년 MM월 dd일')
                                  .format(recipe['createdAt'].toDate())
                              : '날짜 없음',
                        ), // 레시피 제목
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  RecipeDetailScreen(recipeId: recipe.id),
                            ),
                          );
                        },
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
