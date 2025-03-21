import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  String selectedCategory = 'coffee'; // 기본 카테고리를 커피로 설정

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
            .orderBy('title', descending: true)
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
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              var recipe = recipes[index];
              return ListTile(
                title: Text(
                  (recipe['category'] == 'coffee'
                      ? (recipe.data().toString().contains('beans')
                          ? (recipe['beans'] as List<dynamic>)
                              .map((bean) => bean['name'])
                              .join(', ')
                          : '없음')
                      : (recipe.data().toString().contains('recipeName')
                          ? recipe['recipeName']
                          : '없음')),
                ),
                subtitle: Text(recipe['title']),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          RecipeDetailScreen(recipeId: recipe.id),
                    ),
                  );
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteRecipe(recipe.id),
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
  }
}
