import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'screens/recipe_detail_screen.dart';
import 'screens/recipe_setup_screen.dart';
import 'screens/recipe_list_screen.dart';
import 'screens/study_screen.dart';
import 'screens/login_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // runApp(const MaterialApp(home: AudioRecorderPlayer()));
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
            print(
                'MyApp StreamBuilder: ConnectionState.waiting. Showing CircularProgressIndicator.');
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print(
                'MyApp StreamBuilder: Error: ${snapshot.error}. Showing error screen.');
            return Center(child: Text('Error: ${snapshot.error}')); // 에러 메시지 표시
          }
          if (snapshot.hasData) {
            print(
                'MyApp StreamBuilder: Signed in user: ${snapshot.data?.uid}. Returning MainScreen.');
            // 여기서 MainScreen이 잘 로드되는지 확인이 필요
            return const MainScreen();
          }
          print(
              'MyApp StreamBuilder: No user signed in. Returning LoginScreen.');
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
        '/study': (context) => const StudyScreen(),
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
    StudyScreen(),
  ];

  @override
  void initState() {
    // MainScreen의 initState 추가
    super.initState();
    print('MainScreen: initState called.');
  }

  @override
  void didChangeDependencies() {
    // MainScreen의 didChangeDependencies 추가
    super.didChangeDependencies();
    print('MainScreen: didChangeDependencies called.');
  }

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
    print('HomeScreen: initState called.');
    userId = FirebaseAuth.instance.currentUser?.uid;
    print('HomeScreen: userId in initState: $userId');
  }

  @override
  Widget build(BuildContext context) {
    print('HomeScreen: build method called.');
    if (userId == null) {
      print('HomeScreen: userId is null, showing CircularProgressIndicator.');
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '레시피 상자',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.brown[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    backgroundColor:
                        isCoffeeSelected ? Colors.brown[700] : Colors.grey[300],
                    foregroundColor:
                        isCoffeeSelected ? Colors.white : Colors.black,
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
                    backgroundColor:
                        isCoffeeSelected ? Colors.grey[300] : Colors.brown[700],
                    foregroundColor:
                        isCoffeeSelected ? Colors.black : Colors.white,
                  ),
                  child: const Text('🍽 요리 레시피'),
                ),
              ],
            ),
            const SizedBox(height: 20),
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
                    // .where('userId', isEqualTo: userId)
                    .snapshots(),
                builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    print("StreamBuilder: 데이터 로딩 중...");
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    print("StreamBuilder: 오류 발생 - ${snapshot.error}");
                    return Center(child: Text('오류 발생: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('데이터가 없습니다.'));
                  }

                  final recipes = snapshot.data!.docs;
                  if (recipes.isEmpty) {
                    print(
                        "StreamBuilder: 데이터 없음 - 현재 필터링된 카테고리: ${isCoffeeSelected ? 'coffee' : 'cooking'}");
                    return const Center(child: Text('데이터 없음'));
                  }
                  print(
                      "StreamBuilder: 데이터 ${recipes.length}개 로드됨. 현재 필터링된 카테고리: ${isCoffeeSelected ? 'coffee' : 'cooking'}");
                  Map<String, int> beanUsage = {};
                  Map<String, double> beanRatingSum = {};
                  Map<String, int> beanRatingCount = {};
                  Map<String, String> beanNames = {};
                  return FutureBuilder<QuerySnapshot>(
                    future:
                        FirebaseFirestore.instance.collection('beans').get(),
                    builder: (context, beanSnapshot) {
                      if (beanSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        print("FutureBuilder (beans): 원두 이름 로딩 중...");
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (beanSnapshot.hasError) {
                        print(
                            "FutureBuilder (beans): 오류 발생 - ${beanSnapshot.error}");
                        return Center(
                            child: Text('원두 이름 로드 오류: ${beanSnapshot.error}'));
                      }
                      if (!beanSnapshot.hasData ||
                          beanSnapshot.data!.docs.isEmpty) {
                        print("FutureBuilder (beans): beans 컬렉션 데이터 없음.");
                        return const Center(child: Text('원두 데이터가 없습니다.'));
                      }

                      // 원두 이름 매핑
                      print("FutureBuilder (beans): 원두 이름 매핑 시작.");
                      for (var doc in beanSnapshot.data!.docs) {
                        beanNames[doc.id] = doc['name'] as String;
                      }
                      print(
                          "\n--- 로드된 레시피 데이터 상세 (디버깅용, 이 로그가 안찍혔으므로 ListView.builder 내 문제) ---");
                      // 레시피별 원두 사용 및 평점 집계
                      for (var recipe in recipes) {
                        var data = recipe.data() as Map<String, dynamic>?;
                        if (data == null) {
                          print(
                              "  Skipped recipe (data is null): ${recipe.id}");
                          continue;
                        }
                        print("  Processing recipe: ${recipe.id}");
                        //   if (isCoffeeSelected && data['beans'] != null) {
                        //     var beans = data['beans'] as List<dynamic>;
                        //     for (var bean in beans) {
                        //       String beanId =
                        //           bean['beanId'] ?? bean['name'] ?? '알 수 없음';
                        //       beanUsage[beanId] = (beanUsage[beanId] ?? 0) + 1;
                        //       if (data['wifeRating'] != null) {
                        //         beanRatingSum[beanId] =
                        //             (beanRatingSum[beanId] ?? 0) +
                        //                 (data['wifeRating'] as num).toDouble();
                        //         beanRatingCount[beanId] =
                        //             (beanRatingCount[beanId] ?? 0) + 1;
                        //       }
                        //     }
                        //   }
                        // }
                        if (data.containsKey('beans') &&
                            data['beans'] is List) {
                          var beans = data['beans'] as List<dynamic>;
                          var wifeRating = (data['wifeRating'] as num?)
                              ?.toDouble(); // num 타입에서 double로 변환, null 허용

                          print("    Beans list: ${beans.length} items.");
                          for (var bean in beans) {
                            if (bean is Map<String, dynamic>) {
                              // 각 bean 요소가 Map인지 확인
                              // beanId, name 필드가 없을 경우 '알 수 없음' 사용
                              String beanId = (bean['beanId'] as String?) ??
                                  (bean['name'] as String?) ??
                                  '알 수 없음';

                              // 유효한 beanId만 집계 (알 수 없음은 건너뛸 수도 있음)
                              if (beanId == '알 수 없음') {
                                print(
                                    "      Skipped bean (no beanId or name): $bean");
                                continue;
                              }

                              beanUsage[beanId] = (beanUsage[beanId] ?? 0) + 1;
                              print(
                                  "      Bean '$beanId' usage count: ${beanUsage[beanId]}");

                              if (wifeRating != null) {
                                beanRatingSum[beanId] =
                                    (beanRatingSum[beanId] ?? 0.0) + wifeRating;
                                beanRatingCount[beanId] =
                                    (beanRatingCount[beanId] ?? 0) + 1;
                                print(
                                    "      Bean '$beanId' rating sum: ${beanRatingSum[beanId]}, count: ${beanRatingCount[beanId]}");
                              }
                            } else {
                              print("      Skipped bean (not a Map): $bean");
                            }
                          }
                        } else {
                          print(
                              "    Recipe '${recipe.id}': 'beans' 필드가 없거나 List가 아닙니다. type: ${data['beans']?.runtimeType}");
                        }
                      }
                      print("통계 집계 완료.");

                      if (beanUsage.isEmpty) {
                        return const Center(child: Text('사용된 원두가 없습니다.'));
                      }

                      List<Map<String, dynamic>> sortedBeans =
                          beanRatingCount.keys.map((beanId) {
                        double avgRating = beanRatingCount
                                    .containsKey(beanId) &&
                                beanRatingCount[beanId]! > 0
                            ? beanRatingSum[beanId]! / beanRatingCount[beanId]!
                            : 0.0;
                        return {
                          'beanId': beanId,
                          'avgRating': avgRating,
                          'usageCount': beanUsage[beanId] ?? 0,
                        };
                      }).toList();
                      sortedBeans.sort((a, b) {
                        if (b['avgRating'] == a['avgRating']) {
                          return (b['usageCount'] as int)
                              .compareTo(a['usageCount'] as int);
                        }
                        return (b['avgRating'] as double)
                            .compareTo(a['avgRating'] as double);
                      });
                      print("정렬된 원두 리스트 준비 완료. 상위 5개:");
                      sortedBeans.take(5).forEach((entry) {
                        print(
                            "  - ${beanNames[entry['beanId']]} (Avg: ${entry['avgRating']!.toStringAsFixed(1)}, Usage: ${entry['usageCount']})");
                      });

                      // 차트 데이터 준비
                      List<BarChartGroupData> barGroups = [];
                      List<String> beanLabels = [];
                      int index = 0;
                      for (var entry in sortedBeans) {
                        if (index < 5) {
                          // 최대 5개 원두 표시
                          String beanId = entry['beanId'];
                          // beanNames 맵에서 이름 찾기, 없으면 beanId 그대로 사용
                          String fullName = beanNames[beanId] ?? beanId;
                          String shortName = fullName.length > 5
                              ? '${fullName.substring(0, 5)}...'
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
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4)),
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
                          const Text(
                            '원두별 평균 별점 (높은 순)',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(
                            height: 200, // 차트 높이
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
                                                style: const TextStyle(
                                                    fontSize: 11),
                                                overflow: TextOverflow.ellipsis,
                                              )
                                            : const Text('');
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          value.toStringAsFixed(1),
                                          style: const TextStyle(fontSize: 12),
                                        );
                                      },
                                    ),
                                  ),
                                  topTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(show: false),
                                barGroups: barGroups,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '원두별 평균 별점 (높은 순)',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: sortedBeans.length,
                              itemBuilder: (context, index) {
                                var entry = sortedBeans[index];
                                var beanId = entry['beanId'];
                                String displayBeanName =
                                    beanNames[beanId] ?? beanId;
                                return ListTile(
                                  title: Text(displayBeanName),
                                  subtitle:
                                      Text('사용 횟수: ${entry['usageCount']}'),
                                  trailing: Text(
                                      '평균 별점: ${entry['avgRating'].toStringAsFixed(1) ?? 'N/A'}'),
                                  onTap: () {
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
