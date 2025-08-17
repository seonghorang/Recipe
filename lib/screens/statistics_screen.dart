import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
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
      appBar: AppBar(
        title: const Text(
          '레시피 통계',
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
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                  child: const Text('커피'),
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
                  child: const Text('요리'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '원두별 레시피 통계',
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
                    return Center(child: Text('오류: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('레시피가 없습니다.'));
                  }

                  //원두 통계 계산
                  final recipes = snapshot.data!.docs;
                  Map<String, int> beanUsage = {};
                  Map<String, double> beanRatingSum = {};
                  Map<String, int> beanRatingCount = {};
                  Map<String, String> beanNames = {};

                  return FutureBuilder<QuerySnapshot>(
                    future:
                        FirebaseFirestore.instance.collection('beans').get(),
                    builder: (context, beanSnapshot) {
                      if (!beanSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      //원두 이름 매핑
                      for (var doc in beanSnapshot.data!.docs) {
                        beanNames[doc.id] = doc['name'] as String;
                      }

                      //레시피별 원두 사용 및 평점 집계
                      for (var recipe in recipes) {
                        var data = recipe.data() as Map<String, dynamic>;
                        if (isCoffeeSelected && data['beans'] != null) {
                          var beans = data['beans'] as List<dynamic>;
                          for (var bean in beans) {
                            String beanId =
                                bean['beanId'] ?? bean['name'] ?? '알 수 없음';
                            beanUsage[beanId] = (beanUsage[beanId] ?? 0) + 1;
                            if (data['wifeRating'] != null) {
                              beanRatingSum[beanId] =
                                  (beanRatingSum[beanId] ?? 0) +
                                      (data['wifeRating'] as num).toDouble();
                              beanRatingCount[beanId] =
                                  (beanRatingCount[beanId] ?? 0) + 1;
                            }
                          }
                        }
                      }

                      //차트 데이터 준비
                      List<BarChartGroupData> barGroups = [];
                      List<String> beanLabels = [];
                      int index = 0;
                      beanUsage.forEach((beanId, count) {
                        if (index < 5) {
                          //최대 원두 5개 표시
                          beanLabels.add(beanNames[beanId] ?? beanId);
                          barGroups.add(
                            BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: count.toDouble(),
                                  color: Colors.brown[700],
                                  width: 20,
                                ),
                              ],
                            ),
                          );
                          index++;
                        }
                      });

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 200,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
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
                                                    fontSize: 12),
                                                overflow: TextOverflow.ellipsis,
                                              )
                                            : const Text('');
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: true),
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
                            '원두별 평균 평점',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Expanded(
                            child: ListView(
                              children: beanUsage.keys.map((beanId) {
                                double avgRating =
                                    beanRatingCount[beanId] != null &&
                                            beanRatingCount[beanId]! > 0
                                        ? beanRatingSum[beanId]! /
                                            beanRatingCount[beanId]!
                                        : 0.0;
                                return ListTile(
                                  title: Text(beanNames[beanId] ?? beanId),
                                  subtitle: Text('사용 횟수: ${beanUsage[beanId]}'),
                                  trailing: Text(
                                      '평균 평점: ${avgRating.toStringAsFixed(1)}'),
                                );
                              }).toList(),
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
