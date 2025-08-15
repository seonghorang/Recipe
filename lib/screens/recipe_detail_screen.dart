import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';

class RecipeDetailScreen extends StatelessWidget {
  final String recipeId;
  final String category;
  const RecipeDetailScreen({
    super.key,
    required this.recipeId,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
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
                Navigator.pushNamed(
                  context,
                  '/recipe_setup',
                  arguments: {
                    'recipeId': recipeId,
                    'isEditing': true,
                    'category': category,
                  },
                );
              },
            ),
          ],
        ),
        body: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('recipes')
              .doc(recipeId)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('레시피를 찾을 수 없습니다.'));
            }
            final data = snapshot.data!.data() as Map<String, dynamic>;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16.0,
                16.0,
                16.0,
                16.0 + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['title'] ?? '제목 없음',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.brown[800],
                        ),
                  ),
                  const SizedBox(height: 16),
                  if (data['category'] == 'coffee') ...[
                    _buildDetailRow(
                      context: context,
                      icon: Icons.local_cafe,
                      label: '원두',
                      value: (data['beans'] as List<dynamic>?)?.isNotEmpty ??
                              false
                          ? FutureBuilder<QuerySnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('beans')
                                  .get(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return Text('로딩 중...');
                                var beansMap = {
                                  for (var doc in snapshot.data!.docs)
                                    doc.id: doc['name']
                                };
                                var beans =
                                    (data['beans'] as List<dynamic>?) ?? [];
                                return Text(
                                  beans
                                      .map((bean) =>
                                          '${bean['beanId'] != null ? beansMap[bean['beanId']] ?? bean['name'] ?? '알 수 없음' : bean['name'] ?? '알 수 없음'} (${bean['weight']}g)')
                                      .join(', '),
                                );
                              },
                            )
                          : Text('원두 없음'),
                    ),
                    _buildDetailRow(
                      context: context,
                      icon: Icons.water_drop,
                      label: '블루밍',
                      value: Text(
                        data['blooming'] != null
                            ? '물량: ${data['blooming']['water']}ml, 시간: ${data['blooming']['time']}초'
                            : '없음',
                      ),
                    ),
                    _buildDetailRow(
                      context: context,
                      icon: Icons.local_drink,
                      label: '추출',
                      value: (data['extractions'] as List<dynamic>?)
                                  ?.isNotEmpty ??
                              false
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: (data['extractions'] as List<dynamic>)
                                  .asMap()
                                  .entries
                                  .map(
                                    (entry) => Text(
                                      '단계 ${entry.value['stage']}: ${entry.value['water']}ml',
                                    ),
                                  )
                                  .toList(),
                            )
                          : const Text('없음'),
                    ),
                    _buildDetailRow(
                      context: context,
                      icon: Icons.add_circle,
                      label: '가수',
                      value: Text(
                        data['additionalWater'] == true
                            ? '${data['additionalWaterAmount']}ml'
                            : '없음',
                      ),
                    ),
                  ] else ...[
                    _buildDetailRow(
                      context: context,
                      icon: Icons.restaurant_menu,
                      label: '요리 이름',
                      value: Text(data['recipeName'] ?? '없음'),
                    ),
                    _buildDetailRow(
                      context: context,
                      icon: Icons.list,
                      label: '재료',
                      value: Text(data['ingredients'] ?? '없음'),
                    ),
                    _buildDetailRow(
                      context: context,
                      icon: Icons.description,
                      label: '조리법',
                      value: Text(data['instructions'] ?? '없음'),
                    ),
                  ],
                  _buildDetailRow(
                    context: context,
                    icon: Icons.star,
                    label: '미깅쓰 평가',
                    value: Row(
                      children: [
                        RatingBarIndicator(
                          rating: (data['wifeRating'] ?? 0.0).toDouble(),
                          itemBuilder: (context, _) => const Icon(
                            Icons.star,
                            color: Colors.amber,
                          ),
                          itemCount: 5,
                          itemSize: 20.0,
                          direction: Axis.horizontal,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          data['wifeRating'] != null
                              ? '${data['wifeRating'].toStringAsFixed(1)}'
                              : '0.0',
                        ),
                      ],
                    ),
                  ),
                  _buildDetailRow(
                    context: context,
                    icon: Icons.comment,
                    label: '미깅쓰 리뷰',
                    value: Text(data['wifeReview'] ?? '리뷰 없음'),
                  ),
                  _buildDetailRow(
                    context: context,
                    icon: Icons.date_range,
                    label: '작성일',
                    value: Text(
                      data['createdAt'] != null
                          ? DateFormat('yyyy-MM-dd')
                              .format((data['createdAt'] as Timestamp).toDate())
                          : '알 수 없음',
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Widget value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.brown[700]),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.brown[800],
                      ),
                ),
                const SizedBox(height: 4),
                value,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
