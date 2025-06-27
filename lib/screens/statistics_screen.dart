import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('레시피 통계'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('recipes').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print('Firestore Error: ${snapshot.error}'); // 디버깅 로그
            return Center(child: Text('오류: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('레시피가 없습니다.'));
          }

          final recipes = snapshot.data!.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();
          print('Recipes loaded: ${recipes.length}'); // 디버깅 로그

          // 별점 분포 계산
          final ratingDistribution = <double, int>{};
          for (var recipe in recipes) {
            final rating = (recipe['wifeRating'] as num?)?.toDouble() ?? 0.0;
            ratingDistribution.update(rating, (value) => value + 1,
                ifAbsent: () => 1);
          }
          print('Rating distribution: $ratingDistribution'); // 디버깅 로그

          // 카테고리 비율 계산
          final categoryDistribution = {'coffee': 0, 'cooking': 0};
          for (var recipe in recipes) {
            final category = recipe['category'] as String? ?? 'unknown';
            categoryDistribution.update(category, (value) => value + 1,
                ifAbsent: () => 1);
          }
          print('Category distribution: $categoryDistribution'); // 디버깅 로그

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  '별점 분포',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown[800],
                  ),
                ),
                const SizedBox(height: 16),
                ratingDistribution.isEmpty
                    ? const Center(child: Text('별점 데이터 없음'))
                    : SizedBox(
                        height: 200,
                        child: PieChart(
                          PieChartData(
                            sections: ratingDistribution.entries.map((e) {
                              return PieChartSectionData(
                                value: e.value.toDouble(),
                                title:
                                    '${e.key.toStringAsFixed(1)} (${e.value})',
                                color: Colors.primaries[
                                    e.key.toInt() % Colors.primaries.length],
                              );
                            }).toList(),
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                          ),
                        ),
                      ),
                const SizedBox(height: 24),
                Text(
                  '카테고리 비율',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown[800],
                  ),
                ),
                const SizedBox(height: 16),
                categoryDistribution.values.every((v) => v == 0)
                    ? const Center(child: Text('카테고리 데이터 없음'))
                    : SizedBox(
                        height: 200,
                        child: PieChart(
                          PieChartData(
                            sections: categoryDistribution.entries.map((e) {
                              return PieChartSectionData(
                                value: e.value.toDouble(),
                                title:
                                    '${e.key == 'coffee' ? '커피' : e.key == 'cooking' ? '요리' : '기타'}: ${e.value}',
                                color: e.key == 'coffee'
                                    ? Colors.brown[400]
                                    : Colors.green[400],
                              );
                            }).toList(),
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                          ),
                        ),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}
