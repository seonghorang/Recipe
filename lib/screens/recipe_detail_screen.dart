import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
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
  void initState() {
    super.initState();
    // 초기 별점과 리뷰를 Firestore에서 가져와 설정
    FirebaseFirestore.instance
        .collection('recipes')
        .doc(widget.recipeId)
        .get()
        .then((doc) {
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _currentRating = (data['wifeRating'] as num?)?.toDouble() ?? 0.0;
          _reviewController.text = data['wifeReview'] as String? ?? '';
        });
      }
    });
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _updateRatingAndReview(
      String recipeId, double rating, String review) async {
    if (rating < 0 || rating > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('별점은 0에서 5 사이로 선택하세요')),
      );
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('recipes')
          .doc(recipeId)
          .update({
        'wifeRating': rating,
        'wifeReview': review,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance
          .collection('recipes')
          .doc(recipeId)
          .collection('ratingHistory')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'rating': rating,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('별점 및 리뷰가 업데이트되었습니다')),
        );
      }
    } catch (error) {
      print('Firestore update error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('업데이트 실패: $error')),
        );
      }
    }
  }

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
                FirebaseFirestore.instance
                    .collection('recipes')
                    .doc(widget.recipeId)
                    .get()
                    .then((doc) {
                  if (doc.exists && mounted) {
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

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16.0,
                16.0,
                16.0,
                16.0 + MediaQuery.of(context).padding.bottom,
              ),
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
                        if ((data['extractions'] as List<dynamic>?)
                                ?.isNotEmpty ??
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
                            initialRating: _currentRating,
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
                              print('Rating updated: $newRating'); // 디버깅
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reviewController,
                        decoration: InputDecoration(
                          labelText: '리뷰',
                          hintText: '리뷰를 입력하세요.',
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
                            _currentRating,
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
