import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
// import 'recipe_detail_screen.dart';
// import 'recipe_setup_screen.dart';

class RecipeListScreen extends StatefulWidget {
  const RecipeListScreen({super.key});

  @override
  _RecipeListScreenState createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  bool isCoffeeSelected = true;

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String? beanId = args?['beanId'];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '레시피 목록',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.brown[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
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
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('recipes')
                    .where('category',
                        isEqualTo: isCoffeeSelected ? 'coffee' : 'cooking')
                    // .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('레시피가 없습니다.'));
                  }
                  final recipes = snapshot.data!.docs.where((recipe) {
                    if (beanId == null || !isCoffeeSelected) return true;
                    var data = recipe.data() as Map<String, dynamic>;
                    var beans = data['beans'] as List<dynamic>? ?? [];
                    return beans.any((bean) =>
                        bean['beanId'] == beanId || bean['name'] == beanId);
                  }).toList();
                  return ListView.builder(
                    itemCount: recipes.length,
                    itemBuilder: (context, index) {
                      final recipe = recipes[index];
                      final recipeData = recipe.data() as Map<String, dynamic>;
                      return ListTile(
                        title: isCoffeeSelected
                            ? FutureBuilder<QuerySnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection('beans')
                                    .get(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData)
                                    return const Text('로딩 중...');
                                  var beansMap = {
                                    for (var doc in snapshot.data!.docs)
                                      doc.id: doc['name']
                                  };
                                  var beans =
                                      recipeData['beans'] as List<dynamic>? ??
                                          [];
                                  return Text(
                                    recipeData['title'],
                                  );
                                  // Text(
                                  //   beans.isNotEmpty
                                  //       ? beans
                                  //           .map((bean) =>
                                  //               '${bean['beanId'] != null ? beansMap[bean['beanId']] ?? bean['name'] ?? '알 수 없음' : bean['name'] ?? '알 수 없음'}')
                                  //           .join(', ')
                                  //       : '원두 없음',
                                  //   overflow: TextOverflow.ellipsis,
                                  // );
                                },
                              )
                            : Text(recipeData['recipeName'] ?? '요리 이름 없음'),
                        subtitle: Text(
                          recipeData['createdAt'] != null
                              ? DateFormat('yyyy-MM-dd').format(
                                  (recipeData['createdAt'] as Timestamp)
                                      .toDate())
                              : '날짜 없음',
                        ),
                        trailing: Text(
                          '평점: ${recipeData['wifeRating']?.toStringAsFixed(1) ?? '0.0'}',
                        ),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/recipe_detail',
                            arguments: {
                              'recipeId': recipe.id,
                              'category':
                                  isCoffeeSelected ? 'coffee' : 'cooking',
                            },
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/recipe_setup',
            arguments: {
              'category': isCoffeeSelected ? 'coffee' : 'cooking',
              'isEditing': false,
            },
          );
        },
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
        tooltip: '레시피 추가',
        child: const Icon(Icons.add),
      ),
    );
  }
}
