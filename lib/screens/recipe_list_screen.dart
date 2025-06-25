import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'recipe_detail_screen.dart';
import 'recipe_setup_screen.dart';

class RecipeListScreen extends StatefulWidget {
  const RecipeListScreen({super.key});

  @override
  _RecipeListScreenState createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  final CollectionReference recipesCollection =
      FirebaseFirestore.instance.collection('recipes');
  String selectedCategory = 'coffee';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('레시피 목록'),
        actions: [
          DropdownButton<String>(
            value: selectedCategory,
            onChanged: (value) {
              setState(() {
                selectedCategory = value!;
              });
            },
            items: const [
              DropdownMenuItem(value: 'coffee', child: Text('커피 레시피')),
              DropdownMenuItem(value: 'cooking', child: Text('요리 레시피')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToSetupScreen(),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: recipesCollection
            .where('category', isEqualTo: selectedCategory)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('오류 발생: ${snapshot.error}'));
          }

          final recipes = snapshot.data?.docs ?? [];
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              var recipe = recipes[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            RecipeDetailScreen(recipeId: recipe.id),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                recipe['title'] ?? '제목 없음',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '카테고리: ${recipe['category'] == 'coffee' ? '커피' : '요리'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                recipe['createdAt'] != null
                                    ? DateFormat('yyyy년 MM월 dd일')
                                        .format(recipe['createdAt'].toDate())
                                    : '날짜 없음',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (recipe['wifeRating'] != null &&
                                  recipe['wifeRating'] > 0)
                                Row(
                                  children: List.generate(
                                    5,
                                    (i) => Icon(
                                      i < recipe['wifeRating']
                                          ? Icons.star
                                          : Icons.star_border,
                                      size: 16,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteRecipe(recipe.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _navigateToSetupScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => RecipeSetupScreen(category: selectedCategory)),
    );
  }

  void _deleteRecipe(String id) {
    recipesCollection.doc(id).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('레시피가 삭제되었습니다')),
    );
  }
}
