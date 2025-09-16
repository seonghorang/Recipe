// lib/screens/recipe_detail_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart'; // <<< 이 줄 추가
import 'package:intl/intl.dart';

class RecipeDetailScreen extends StatefulWidget {
  final String recipeId;
  final String category;
  const RecipeDetailScreen({
    super.key,
    required this.recipeId,
    required this.category,
  });

  @override
  _RecipeDetailScreenState createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  // === 추가: 별점 및 리뷰 관련 상태 변수 ===
  double _currentWifeRating = 0.0;
  final TextEditingController _wifeReviewController = TextEditingController();
  bool _isLoadingRating = false;
  // ======================================

  @override
  void initState() {
    super.initState();
    // === 추가: 기존 별점/리뷰 초기값 로드 ===
    _loadWifeRatingAndReview();
    // ===================================
  }

  // === 추가: 별점/리뷰 초기값을 Firestore에서 로드하는 함수 ===
  Future<void> _loadWifeRatingAndReview() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('recipes')
          .doc(widget.recipeId)
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        setState(() {
          _currentWifeRating = (data['wifeRating'] as num?)?.toDouble() ?? 0.0;
          _wifeReviewController.text = (data['wifeReview'] as String?) ?? '';
        });
      }
    } catch (e) {
      // print("레시피 별점/리뷰 초기 로드 오류: $e");
    }
  }
  // ==========================================================

  // === 추가: 별점 및 리뷰를 Firestore에 저장하는 함수 ===
  Future<void> _saveWifeRatingAndReview() async {
    setState(() {
      _isLoadingRating = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('recipes')
          .doc(widget.recipeId)
          .update({
        'wifeRating': _currentWifeRating,
        'wifeReview': _wifeReviewController.text,
        'updatedAt': FieldValue.serverTimestamp(), // 마지막 업데이트 시간 기록
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('별점과 리뷰가 성공적으로 저장되었습니다!')));
    } catch (e) {
      // print("별점/리뷰 저장 오류: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('별점/리뷰 저장 오류: ${e.toString()}')));
    } finally {
      setState(() {
        _isLoadingRating = false;
      });
    }
  }
  // ======================================================

  @override
  void dispose() {
    _wifeReviewController.dispose(); // <<< 추가: 컨트롤러 해제
    super.dispose();
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
                // widget을 사용하여 현재 위젯의 속성에 접근
                Navigator.pushNamed(
                  context,
                  '/recipe_setup',
                  arguments: {
                    'recipeId': widget.recipeId,
                    'isEditing': true,
                    'category': widget.category,
                  },
                );
              },
            ),
          ],
        ),
        body: FutureBuilder<DocumentSnapshot>(
          // widget을 사용하여 현재 위젯의 속성에 접근
          future: FirebaseFirestore.instance
              .collection('recipes')
              .doc(widget.recipeId)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('레시피를 찾을 수 없습니다.'));
            }
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final blooming = data['blooming'] as Map<String, dynamic>?;
            if (blooming == null || blooming.isEmpty) {
              return const Text("없음");
            }
            final water = blooming?['water'] as int? ?? 0;
            final time = blooming?['time'] as int? ?? 0;
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
                              builder: (context, beanSnapshot) {
                                if (!beanSnapshot.hasData)
                                  return const Text('로딩 중...'); // beanSnapshot
                                var beansMap = {
                                  for (var doc in beanSnapshot
                                      .data!.docs) // beanSnapshot
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
                          : const Text('원두 없음'),
                    ),
                    _buildDetailRow(
                      context: context,
                      icon: Icons.water_drop,
                      label: '블루밍',
                      value: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Text('물 ${water}g, 시간 ${time}초')],
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
                    // 요리 레시피 (기존 코드)
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
                  // === 미깅쓰 평가, 미깅쓰 리뷰 부분 수정 시작 ===
                  _buildDetailRow(
                    context: context,
                    icon: Icons
                        .star, // 또는 Icons.grade, Icons.rate_review 등 원하는 아이콘
                    label: '미죵상 별점', // 제목 텍스트
                    value: const SizedBox.shrink(),
                  ),
                  Column(
                    // 별점과 리뷰 입력 UI를 Column으로 묶어서 value로 전달
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 별점 드래그 (RatingBar.builder)
                      RatingBar.builder(
                        initialRating:
                            _currentWifeRating, // 초기값 설정 (initState에서 로드됨)
                        minRating: 0.0,
                        direction: Axis.horizontal,
                        allowHalfRating: true, // 0.5점 단위 허용
                        itemCount: 5,
                        itemPadding:
                            const EdgeInsets.symmetric(horizontal: 2.0),
                        itemBuilder: (context, _) => const Icon(
                          Icons.star,
                          color: Colors.amber,
                        ),
                        itemSize: 25,
                        onRatingUpdate: (rating) {
                          setState(() {
                            _currentWifeRating = rating; // 별점 변경 시 상태 업데이트
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // 리뷰 텍스트 필드
                      TextField(
                        controller: _wifeReviewController, // 컨트롤러 연결
                        decoration: const InputDecoration(
                          labelText: '미죤상 캉가에루',
                          hintText: '나니오 캉가에떼이루?',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 5,
                        minLines: 3,
                      ),
                      const SizedBox(height: 15),

                      // 저장 버튼
                      Center(
                        child: ElevatedButton(
                          onPressed: _isLoadingRating
                              ? null
                              : _saveWifeRatingAndReview,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.brown[700],
                            foregroundColor: Colors.white,
                            minimumSize: const Size(100, 20),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isLoadingRating
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text('별점/리뷰 저장',
                                  style: TextStyle(fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                  // === 미깅쓰 평가, 미깅쓰 리뷰 부분 수정 끝 ===

                  // --- 작성일 정보 표시 (기존 코드) ---
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

  // --- _buildDetailRow 함수는 변경 없음 ---
  // 이 함수를 _RecipeDetailScreenState 클래스 내부로 이동해야 합니다.
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
} // 이 닫는 괄호는 _buildDetailRow 함수 뒤에 있어야 합니다.
