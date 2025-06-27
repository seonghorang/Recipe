import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:fl_chart/fl_chart.dart';
import 'recipe_setup_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final String recipeId;
  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  _RecipeDetailScreenState createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final _reviewController = TextEditingController();
  double _currentRating = 0.0;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  void _updateRatingAndReview(String recipeId, double rating, String review) {
    if (rating < 0 || rating > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('별점은 0에서 5 사이로 선택하세요')),
      );
      return;
    }
    FirebaseFirestore.instance.collection('recipes').doc(recipeId).update({
      'wifeRating': rating,
      'wifeReview': review,
    });
    FirebaseFirestore.instance
        .collection('recipes')
        .doc(recipeId)
        .collection('ratingHistory')
        .add({
      'timestamp': Timestamp.now(),
      'rating': rating,
    }).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('별점 및 리뷰가 업데이트되었습니다')),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('업데이트 실패: $error')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '레시피 상세',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.brown[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('recipes')
                  .doc(widget.recipeId)
                  .get()
                  .then((doc) {
                if (doc.exists) {
                  final category = doc.data()!['category'] as String;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecipeSetupScreen(
                        recipeId: widget.recipeId,
                        isEditing: true,
                        category: category,
                      ),
                    ),
                  );
                }
              });
            },
            tooltip: '레시피 편집',
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('recipes')
            .doc(widget.recipeId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print('Firestore Error: ${snapshot.error}');
            return Center(child: Text('오류 발생: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('레시피를 찾을 수 없습니다'));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          final rating = (data['wifeRating'] as num?)?.toDouble() ?? 0.0;
          final review = data['wifeReview'] as String? ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.brown[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['title'] ?? '제목 없음',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown[900],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data['createdAt'] != null
                          ? DateFormat('yyyy년 MM월 dd일')
                              .format(data['createdAt'].toDate())
                          : '날짜 없음',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.brown[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.category,
                            size: 20, color: Colors.brown[700]),
                        const SizedBox(width: 8),
                        Text(
                          '카테고리: ${data['category'] == 'coffee' ? '커피' : '요리'}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.brown[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (data['category'] == 'coffee') ...[
                      _buildDetailRow(
                        icon: Icons.local_cafe,
                        label: '원두 타입',
                        value: data['beanType'] ?? '없음',
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        icon: Icons.grain,
                        label: '원두',
                        value: (data['beans'] as List<dynamic>?)
                                ?.map((b) => '${b['name']} (${b['weight']}g)')
                                .join(', ') ??
                            '없음',
                      ),
                      if (data['blooming'] != null &&
                          (data['blooming']['water'] ?? 0) > 0)
                        _buildDetailRow(
                          icon: Icons.water_drop,
                          label: '블루밍',
                          value:
                              '${data['blooming']['water']}ml, ${data['blooming']['time']}초',
                        ),
                      if ((data['extractions'] as List<dynamic>?)?.isNotEmpty ??
                          false)
                        _buildExtractionDetails(
                          icon: Icons.filter_alt,
                          label: '추출 단계',
                          extractions: data['extractions'] as List<dynamic>,
                        ),
                      if (data['additionalWater'] == true)
                        _buildDetailRow(
                          icon: Icons.waves,
                          label: '가수량',
                          value: '${data['additionalWaterAmount'] ?? 0}ml',
                        ),
                    ] else ...[
                      _buildDetailRow(
                        icon: Icons.restaurant_menu,
                        label: '요리 이름',
                        value: data['recipeName'] ?? '없음',
                      ),
                      if (data['ingredients']?.isNotEmpty ?? false)
                        _buildDetailRow(
                          icon: Icons.list_alt,
                          label: '재료',
                          value: data['ingredients'],
                        ),
                      if (data['instructions']?.isNotEmpty ?? false)
                        _buildDetailRow(
                          icon: Icons.description,
                          label: '조리법',
                          value: data['instructions'],
                        ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      '별점 이력',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown[800],
                      ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('recipes')
                          .doc(widget.recipeId)
                          .collection('ratingHistory')
                          .orderBy('timestamp')
                          .snapshots(),
                      builder: (context, historySnapshot) {
                        if (historySnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (historySnapshot.hasError) {
                          print(
                              'Rating History Error: ${historySnapshot.error}');
                          return Text('오류: ${historySnapshot.error}');
                        }
                        if (!historySnapshot.hasData ||
                            historySnapshot.data!.docs.isEmpty) {
                          return const Text('별점 이력이 없습니다.');
                        }

                        final history = historySnapshot.data!.docs
                            .map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              print('Rating History Doc: $data');
                              final timestamp = data['timestamp'];
                              final rating = data['rating'];

                              DateTime? parsedTimestamp;
                              double parsedRating = 0.0;

                              if (timestamp is Timestamp) {
                                parsedTimestamp = timestamp.toDate();
                              } else if (timestamp is String) {
                                parsedTimestamp = DateTime.tryParse(timestamp);
                              }

                              if (rating is num) {
                                parsedRating = rating.toDouble();
                              } else if (rating is String) {
                                parsedRating = double.tryParse(rating) ?? 0.0;
                              }

                              return {
                                'timestamp': parsedTimestamp,
                                'rating': parsedRating,
                              };
                            })
                            .where((entry) => entry['timestamp'] != null)
                            .toList();

                        if (history.isEmpty) {
                          return const Text('유효한 별점 이력이 없습니다.');
                        }

                        return SizedBox(
                          height: 200,
                          child: LineChart(
                            LineChartData(
                              gridData: const FlGridData(show: true),
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final date =
                                          DateTime.fromMillisecondsSinceEpoch(
                                              value.toInt());
                                      return Text(
                                        DateFormat('MM/dd').format(date),
                                        style: const TextStyle(fontSize: 10),
                                      );
                                    },
                                    interval: 1000 * 60 * 60 * 24 * 30,
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        value.toStringAsFixed(1),
                                        style: const TextStyle(fontSize: 10),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: true),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: history
                                      .asMap()
                                      .entries
                                      .map((e) => FlSpot(
                                          (e.value['timestamp'] as DateTime)
                                              .millisecondsSinceEpoch
                                              .toDouble(),
                                          e.value['rating'] as double))
                                      .toList(),
                                  isCurved: true,
                                  color: Colors.brown[700],
                                  dotData: const FlDotData(show: true),
                                ),
                              ],
                              minY: 0,
                              maxY: 5,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '별점 및 리뷰',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown[800],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          '별점: ',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.brown[600],
                          ),
                        ),
                        RatingBar.builder(
                          initialRating: rating,
                          minRating: 0,
                          direction: Axis.horizontal,
                          allowHalfRating: true,
                          itemCount: 5,
                          itemSize: 30,
                          itemBuilder: (context, _) => Icon(
                            Icons.star,
                            color: Colors.amber,
                          ),
                          onRatingUpdate: (newRating) {
                            setState(() {
                              _currentRating = newRating;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _reviewController..text = review,
                      decoration: InputDecoration(
                        labelText: '리뷰',
                        labelStyle: TextStyle(color: Colors.brown[600]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon:
                            const Icon(Icons.comment, color: Colors.brown),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FloatingActionButton(
                        onPressed: () => _updateRatingAndReview(
                          widget.recipeId,
                          _currentRating != 0.0 ? _currentRating : rating,
                          _reviewController.text,
                        ),
                        backgroundColor: Colors.brown[700],
                        child: const Icon(Icons.save, color: Colors.white),
                        tooltip: '별점 및 리뷰 저장',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.brown[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.brown[800],
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.brown[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractionDetails({
    required IconData icon,
    required String label,
    required List<dynamic> extractions,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.brown[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.brown[800],
                  ),
                ),
                ...extractions.map((e) => Text(
                      '${e['stage']} 단계: ${e['water']}ml',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.brown[600],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
