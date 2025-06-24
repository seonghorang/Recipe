import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/recipe_list_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/recipe_detail_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // ✅ Firebase 초기화 전에 호출해야 함
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform); // ✅ Firebase 초기화
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
  final List<Widget> _screens = [
    const HomeScreen(),
    const RecipeListScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
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
                        subtitle: Text(recipe['title']), // 레시피 제목
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
