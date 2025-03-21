import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class RecipeDetailScreen extends StatefulWidget {
  final String recipeId; // 레시피 문서 ID 추가

  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  _RecipeDetailScreenState createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  DocumentSnapshot? recipeData;
  final TextEditingController _reviewController = TextEditingController();
  double _wifeRating = 0.0; // 별점 상태

  @override
  void initState() {
    super.initState();
    _loadRecipeData(); // Firestore에서 레시피 데이터 불러오기
  }

  Future<void> _loadRecipeData() async {
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('recipes')
        .doc(widget.recipeId)
        .get();

    if (doc.exists) {
      setState(() {
        recipeData = doc;
        _reviewController.text = doc.data().toString().contains('wifeReview')
            ? doc['wifeReview']
            : ''; // 기존 평 불러오기
        _wifeRating = doc.data().toString().contains('wifeRating')
            ? (doc['wifeRating']?.toDouble() ?? 0.0)
            : 0.0; // 기존 별점 불러오기
      });
    }
  }

  Future<void> _saveReview() async {
    await FirebaseFirestore.instance
        .collection('recipes')
        .doc(widget.recipeId)
        .update({
      'wifeReview': _reviewController.text,
      'wifeRating': _wifeRating, // 별점 저장
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('미깅이의 평가가 저장되었습니다.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(recipeData?['title'] ?? '레시피 상세')), // 제목 표시
      body: recipeData == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (recipeData?['category'] == 'coffee') ...[
                    const Text("원두 타입",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      recipeData?['beanType'] ?? '정보 없음',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    const Text("원두 정보",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: 135), // ✅ 최대 너비 설정
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: (recipeData?['beans'] as List<dynamic>? ?? [])
                            .map((bean) => Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Expanded(
                                        flex: 2,
                                        child: Text(bean['name'],
                                            textAlign: TextAlign.left)),
                                    const SizedBox(width: 8),
                                    const Text(':'),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        flex: 1,
                                        child: Text("${bean['weight']}g",
                                            textAlign: TextAlign.right)),
                                  ],
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text("블루밍",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      "물: ${recipeData?['blooming']['water']}g, 시간: ${recipeData?['blooming']['time']}초",
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    const Text("추출 단계",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Column(
                      children: (recipeData?['extractions'] as List<dynamic>? ??
                              [])
                          .map((stage) =>
                              Text("${stage['stage']}차: ${stage['water']}g"))
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "가수 여부: ${recipeData?['additionalWater'] == true ? '예' : '아니오'}",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ] else if (recipeData?['category'] == 'cooking') ...[
                    const Text("요리 이름",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      recipeData?['recipeName'] ?? '정보 없음',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    const Text("재료 목록",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      recipeData?['ingredients'] ?? '정보 없음',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    const Text("조리 방법",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      recipeData?['instructions'] ?? '정보 없음',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text("미깅이의 평",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextField(
                    controller: _reviewController,
                    decoration: InputDecoration(
                      hintText: recipeData?['category'] == 'coffee'
                          ? '커피가 어땠나요?'
                          : '요리가 맛있었나요?', // 카테고리에 따라 다르게 표시
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(10), // ✅ 네모 박스 테두리 적용
                        borderSide:
                            BorderSide(color: Colors.grey.shade400, width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: Color.fromARGB(255, 97, 60, 35), width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.orange, width: 2),
                      ),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                  const Text("별점",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  RatingBar(
                    initialRating: _wifeRating,
                    minRating: 1,
                    direction: Axis.horizontal,
                    allowHalfRating: true,
                    itemCount: 5,
                    itemSize: 40.0,
                    ratingWidget: RatingWidget(
                      full: const Icon(Icons.star, color: Colors.orange),
                      half: const Icon(Icons.star_half, color: Colors.orange),
                      empty:
                          const Icon(Icons.star_border, color: Colors.orange),
                    ),
                    onRatingUpdate: (rating) {
                      setState(() {
                        _wifeRating = rating; // 별점 업데이트
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _saveReview,
                    child: const Text('저장'),
                  ),
                ],
              ),
            ),
    );
  }
}
