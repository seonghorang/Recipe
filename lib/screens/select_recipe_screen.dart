// lib/screens/select_recipe_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // userId를 위해

class SelectRecipeScreen extends StatefulWidget {
  final String category; // 'coffee' 또는 'cooking'

  const SelectRecipeScreen({super.key, required this.category});

  @override
  State<SelectRecipeScreen> createState() => _SelectRecipeScreenState();
}

class _SelectRecipeScreenState extends State<SelectRecipeScreen> {
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('레시피 선택')),
        body: Center(child: Text('로그인이 필요합니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.category == "coffee" ? "커피" : "요리"} 레시피 선택'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('recipes')
            .where('userId', isEqualTo: _currentUser!.uid) // 현재 사용자 레시피만
            .where('category', isEqualTo: widget.category) // 해당 카테고리만
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('오류 발생: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('아직 작성된 레시피가 없습니다.'));
          }

          final recipes = snapshot.data!.docs;

          return ListView.builder(
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              final data = recipe.data() as Map<String, dynamic>;

              String title = data['title'] ?? (data['recipeName'] ?? '제목 없음');

              // 이전에 저장했던 wifeRating을 보여주는 것도 좋겠습니다.
              String wifeRatingInfo = '';
              if (data.containsKey('wifeRating') &&
                  data['wifeRating'] != null) {
                wifeRatingInfo =
                    ' ★${(data['wifeRating'] as num).toStringAsFixed(1)}';
              }

              return ListTile(
                title: Text('$title${wifeRatingInfo}'),
                subtitle: Text(
                    '작성일: ${data['createdAt']?.toDate().toLocal().toString().split(' ')[0] ?? '알 수 없음'}'),
                onTap: () {
                  // 선택된 레시피의 ID를 이전 화면으로 반환
                  Navigator.pop(context, recipe.id);
                },
              );
            },
          );
        },
      ),
    );
  }
}
