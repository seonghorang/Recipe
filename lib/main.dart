import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'screens/recipe_detail_screen.dart';
import 'screens/recipe_setup_screen.dart';
import 'screens/recipe_list_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/login_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData) {
            print('Signed in user: ${snapshot.data?.uid}');
            return const MainScreen();
          }
          print('No user signed in, showing LoginScreen');
          return const LoginScreen();
        },
      ),
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
        '/login': (contexet) => const LoginScreen(),
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
          BottomNavigationBarItem(icon: Icon(Icons.book), label: '회화'),
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
      appBar: AppBar(title: const Text('레시피 상자',
      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      ),
      backgroundColor: Colors.brown[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 16),
            const Text(
              '원두별 평균 별점',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('recipes')
                    .where('category',
                        isEqualTo: isCoffeeSelected ? 'coffee' : 'cooking')
                    .where('userId', isEqualTo: userId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('오류 발생: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('데이터가 없습니다.'));
                  }

                  final recipes = snapshot.data!.docs;
                  Map<String, int> beanUsage = {};
                  Map<String, double> beanRatingSum = {};
                  Map<String, int> beanRatingCount = {};
                  Map<String, String> beanNames = {};
return FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance.collection('beans').get(),
                    builder: (context, beanSnapshot) {
                      if (!beanSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // 원두 이름 매핑
                      for (var doc in beanSnapshot.data!.docs) {
                        beanNames[doc.id] = doc['name'] as String;
                      }

                      // 레시피별 원두 사용 및 평점 집계
                      for (var recipe in recipes) {
                        var data = recipe.data() as Map<String, dynamic>;
                        if (isCoffeeSelected && data['beans'] != null) {
                          var beans = data['beans'] as List<dynamic>;
                          for (var bean in beans) {
                            String beanId = bean['beanId'] ?? bean['name'] ?? '알 수 없음';
                            beanUsage[beanId] = (beanUsage[beanId] ?? 0) + 1;
                            if (data['wifeRating'] != null) {
                              beanRatingSum[beanId] =
                                  (beanRatingSum[beanId] ?? 0) + (data['wifeRating'] as num).toDouble();
                              beanRatingCount[beanId] = (beanRatingCount[beanId] ?? 0) + 1;
                            }
                          }
                        }
                      }

                      if (beanUsage.isEmpty) {
                        return const Center(child: Text('사용된 원두가 없습니다.'));
                      }

                      List<Map<String, dynamic>> sortedBeans = beanRatingCount.keys.map((beanId)
                      {
                        double avgRating = beanRatingCount[beanId]! > 0
                        ? beanRatingSum[beanId]! / beanRatingCount[beanId]!
                        : 0.0;
                        return {
                          'beanId': beanId,
                          'avgRating': avgRating,
                          'usageCount': beanUsage[beanId] ?? 0,
                        };
                      }).toList();
                      sortedBeans.sort((a,b) {
                        if (b['avgRating'] == a['avgRating']) {
                          return b['usageCount'].compareTo(a['usageCount']);
                        }
                        return b['avgRating'].compareTo(a['avgRating']);
                      });

                      // 차트 데이터 준비
                      List<BarChartGroupData> barGroups = [];
                      List<String> beanLabels = [];
                      int index = 0;
                      for (var entry in sortedBeans) {
                        if (index < 5) { // 최대 5개 원두 표시
                          String fullName = beanNames[entry['beanId']] ?? entry['beanId'];
                          String shortName = fullName.length > 5
                          ? '${fullName.substring(0,5)}...'
                          : fullName;
                          beanLabels.add(shortName);
                          barGroups.add(
                            BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: entry['avgRating'],
                                  color: Colors.brown[700],
                                  width: 20,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                  backDrawRodData: BackgroundBarChartRodData(
                                    show: true,
                                    toY: 5.0,
                                    color: Colors.brown[100],
                                  ),
                                ),
                              ],
                            ),
                          );
                          index++;
                        }
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 200,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: 5.0,
                                minY: 0.0,
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        int idx = value.toInt();
                                        return idx < beanLabels.length
                                            ? Text(
                                                beanLabels[idx],
                                                style: const TextStyle(fontSize: 11),
                                                overflow: TextOverflow.ellipsis,
                                              )
                                            : const Text('');
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: true,
                                    reservedSize: 40,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        value.toStringAsFixed(1),
                                        style: const TextStyle(fontSize: 12),
                                      );
                                    },
                                    ),
                                  ),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(show: false),
                                barGroups: barGroups,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '원두별 평균 별점 (높은 순)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: sortedBeans.length,
                              itemBuilder: (context, index) {
                                var entry = sortedBeans[index];
                                var beanId = entry['beanId'];
                                return ListTile(
                                  title: Text(beanNames[beanId] ?? beanId),
                                  subtitle: Text('사용 횟수: ${entry['usageCount']}'),
                                  trailing: Text('평균 별점: ${entry['avgRating'].toStringAsFixed(1)}'),
                                  onTap: (){
                                    Navigator.pushNamed(
                                      context,
                                      '/recipe_list',
                                      arguments: {'beanId': beanId},
                                    );
                                  },
                                );
                              },
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