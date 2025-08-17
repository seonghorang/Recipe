import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'screens/recipe_detail_screen.dart';
import 'screens/recipe_setup_screen.dart';
import 'screens/recipe_list_screen.dart';
import 'screens/statistics_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    await FirebaseAuth.instance.signInAnonymously();
    print('Signed in user: ${FirebaseAuth.instance.currentUser?.uid}');
  } catch (e) {
    print('Anonymous sign-in failed: $e');
    if (e.toString().contains('GoogleApiManager')) {
      print('googleApoManager error datected: $e');
    }
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '레시피 관리',
      theme: ThemeData(
        primarySwatch: Colors.orange,
      ),
      home: const MainScreen(),
      routes: {
        '/recipe_detail': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return RecipeDetailScreen(
            recipeId: args['recipeId'] as String,
            category: args['category'] as String,
            );
        },
        '/recipe_setup': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return RecipeSetupScreen(
            category: args['category'] as String,
            recipeId: args['recipeId'] as String?,
            isEditing: args['isEditing'] as bool,
            );
        },
        '/recipe_list': (context) => const RecipeListScreen(),
        '/statistics': (context) => const StatisticsScreen(),
      },
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
        onTap: _onItemTapped,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
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
  String? userId;

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser?.uid;
  }

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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCoffeeSelected ? Colors.brown[700] : Colors.grey[300],
                    foregroundColor: isCoffeeSelected ? Colors.white : Colors.black,
                  ),
                  child: const Text('☕ 커피 레시피'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      isCoffeeSelected = false;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCoffeeSelected ? Colors.grey[300] : Colors.brown[700],
                    foregroundColor: isCoffeeSelected ? Colors.black : Colors.white,
                  ),
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
                        title: isCoffeeSelected
                            ? FutureBuilder<QuerySnapshot>(
                                future: FirebaseFirestore.instance.collection
                                ('beans').get(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) return const Text('로딩 중...');
                                  var beansMap = {for (var doc in snapshot.data!.docs) doc.id: doc['name']};
                                  var beans = recipeData?['beans'] as List<dynamic>? ?? [];
                                  return Text(
                                    beans.isNotEmpty
                                        ? beans
                                            .map((bean) =>
                                                '${bean['beanId'] != null ? beansMap
                                                [bean['beanId']] ?? bean['name'] ?? '알 수 없음' : bean['name'] ?? '알 수 없음'}')
                                            .join(', ')
                                        : '원두 없음',
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
                            )
                          : Text(recipeData?['recipeName'] ?? '요리 이름 없음'), // 요리 이름이 없을 경우
                        subtitle: Text(
                          recipeData != null && recipeData['createdAt'] != null
                              ? DateFormat('yyyy년 MM월 dd일')
                                  .format((recipeData['createdAt'] as Timestamp).toDate())
                              : '날짜 없음',
                        ),
                        trailing: Text(
                          '평점: ${recipeData?['wifeRating']?.toStringAsFixed(1) ?? '0.0'}',
                        ),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/recipe_detail',
                            arguments: {
                              'recipeId': recipe.id,
                              'category': isCoffeeSelected ? 'coffee' : 'cooking',
                            },
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/recipe_setup',
            arguments: {
              'category': isCoffeeSelected ? 'coffee' : 'cooking',
              'isEditing': false,
            },
          );
        },
      backgroundColor: Colors.brown[700],
      foregroundColor: Colors.white,
      tooltip: '레시피 추가',
      child: const Icon(Icons.add),
      ),
    );
  }
}
