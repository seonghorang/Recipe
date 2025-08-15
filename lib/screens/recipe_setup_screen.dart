import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RecipeSetupScreen extends StatefulWidget {
  final String? recipeId; // 편집용
  final bool isEditing; // 추가/편집 구분 플래그
  final String category;
  const RecipeSetupScreen({
    super.key,
    required this.category,
    this.recipeId,
    this.isEditing = false,
  });

  @override
  _RecipeSetupScreenState createState() => _RecipeSetupScreenState();
}

class _RecipeSetupScreenState extends State<RecipeSetupScreen> {
  final _titleController = TextEditingController();
  String _beanType = 'single';
  List<Map<String, dynamic>> _beans =
      []; // [{beanId: String, weight: String, name: String}]
  List<Map<String, dynamic>> _beanOptions = []; // [{id: String, name: String}]
  final _bloomingWaterController = TextEditingController();
  final _bloomingTimeController = TextEditingController();
  final List<Map<String, String>> _extractions = [];
  bool _additionalWater = false;
  final _additionalWaterAmountController = TextEditingController();
  final _recipeNameController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _instructionsController = TextEditingController();
  Map<String, dynamic>? _recentRecipe;

  @override
  void initState() {
    super.initState();
    _loadBeans();
    _loadRecentRecipe();
    if (widget.isEditing && widget.recipeId != null) {
      _loadRecipeData();
    }
  }

  Future<void> _loadBeans() async {
    var snapshot = await FirebaseFirestore.instance.collection('beans').get();
    setState(() {
      _beanOptions = snapshot.docs
          .map((doc) => {'id': doc.id, 'name': doc['name']})
          .toList();
      print('Beans loaded: $_beanOptions'); // 디버깅 로그
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bloomingWaterController.dispose();
    _bloomingTimeController.dispose();
    _additionalWaterAmountController.dispose();
    _recipeNameController.dispose();
    _ingredientsController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentRecipe() async {
    if (widget.isEditing) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('recipes')
        .where('category', isEqualTo: widget.category)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      setState(() {
        _recentRecipe = snapshot.docs.first.data();
        if (widget.category == 'coffee') {
          _beanType = _recentRecipe!['beanType'] ?? 'single';
          _beans = (_recentRecipe!['beans'] as List<dynamic>?)
                  ?.map((b) => {
                        'beanId': b['beanId']?.toString() ?? '',
                        'weight': b['weight']?.toString() ?? '',
                        'name': b['name']?.toString() ?? '',
                      })
                  .toList() ??
              [];
          _bloomingWaterController.text =
              _recentRecipe!['blooming']?['water']?.toString() ?? '';
          _bloomingTimeController.text =
              _recentRecipe!['blooming']?['time']?.toString() ?? '';
          _extractions.addAll((_recentRecipe!['extractions'] as List<dynamic>?)
                  ?.map((e) => {
                        'stage': e['stage'].toString(),
                        'water': e['water'].toString(),
                      })
                  .toList() ??
              []);
          _additionalWater = _recentRecipe!['additionalWater'] ?? false;
          _additionalWaterAmountController.text =
              _recentRecipe!['additionalWaterAmount']?.toString() ?? '';
        } else {
          _recipeNameController.text = _recentRecipe!['recipeName'] ?? '';
          _ingredientsController.text = _recentRecipe!['ingredients'] ?? '';
          _instructionsController.text = _recentRecipe!['instructions'] ?? '';
        }
      });
    }
  }

  Future<void> _loadRecipeData() async {
    final doc = await FirebaseFirestore.instance
        .collection('recipes')
        .doc(widget.recipeId)
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _titleController.text = data['title'] ?? '';
        if (data['category'] == 'coffee') {
          _beanType = data['beanType'] ?? 'single';
          _beans = (data['beans'] as List<dynamic>?)
                  ?.map((b) => {
                        'beanId': b['beanId']?.toString() ?? '',
                        'weight': b['weight']?.toString() ?? '',
                        'name': b['name']?.toString() ?? '',
                      })
                  .toList() ??
              [];
          _bloomingWaterController.text =
              data['blooming']?['water']?.toString() ?? '';
          _bloomingTimeController.text =
              data['blooming']?['time']?.toString() ?? '';
          _extractions.addAll((data['extractions'] as List<dynamic>?)
                  ?.map((e) => {
                        'stage': e['stage'].toString(),
                        'water': e['water'].toString(),
                      })
                  .toList() ??
              []);
          _additionalWater = data['additionalWater'] ?? false;
          _additionalWaterAmountController.text =
              data['additionalWaterAmount']?.toString() ?? '';
        } else {
          _recipeNameController.text = data['recipeName'] ?? '';
          _ingredientsController.text = data['ingredients'] ?? '';
          _instructionsController.text = data['instructions'] ?? '';
        }
      });
    }
  }

  Future<void> _addNewBean() async {
    String? newBeanName = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('새 원두 추가'),
        content: TextField(
          decoration: InputDecoration(
            labelText: '원두 이름',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onSubmitted: (value) => Navigator.pop(ctx, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () {
              var controller = ctx.widget.toString().contains('TextField')
                  ? (ctx.widget as TextField).controller?.text ?? ''
                  : '';
              Navigator.pop(ctx, controller);
            },
            child: Text('추가'),
          ),
        ],
      ),
    );
    if (newBeanName != null && newBeanName.isNotEmpty) {
      var docRef = await FirebaseFirestore.instance.collection('beans').add({
        'name': newBeanName,
        'createdAt': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
      });
      setState(() {
        _beanOptions.add({'id': docRef.id, 'name': newBeanName});
      });
    }
  }

  void _addBean() {
    setState(() {
      _beans.add({'beanId': null, 'weight': '', 'name': ''});
    });
  }

  void _addExtraction() {
    setState(() {
      _extractions.add({'stage': '${_extractions.length + 1}', 'water': ''});
    });
  }

  Future<void> _saveRecipe() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('제목을 입력하세요')),
      );
      return;
    }
    if (widget.category == 'coffee') {
      if (_beans.any((b) => b['beanId'] == null || b['weight'].isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('모든 원두와 무게를 입력하세요')),
        );
        return;
      }
      try {
        Map<String, dynamic> recipeData = {
          'title': _titleController.text,
          'category': widget.category,
          'createdAt': FieldValue.serverTimestamp(),
          'userId': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
          'wifeRating': widget.isEditing ? null : 0.0,
          'wifeReview': '',
        };
        if (widget.category == 'coffee') {
          recipeData.addAll({
            'beanType': _beanType,
            'beans': _beans
                .map((b) => {
                      'beanId': b['beanId'],
                      'weight': int.parse(b['weight'] ?? '0'),
                    })
                .toList(),
            'blooming': {
              'water': int.parse(_bloomingWaterController.text.isEmpty
                  ? '0'
                  : _bloomingWaterController.text),
              'time': int.parse(_bloomingTimeController.text.isEmpty
                  ? '0'
                  : _bloomingTimeController.text),
            },
            'extractions': _extractions,
            'additionalWater': _additionalWater,
            'additionalWaterAmount': _additionalWater
                ? int.parse(_additionalWaterAmountController.text.isEmpty
                    ? '0'
                    : _additionalWaterAmountController.text)
                : 0,
          });
        } else {
          recipeData.addAll({
            'recipeName': _recipeNameController.text,
            'ingredients': _ingredientsController.text,
            'instructions': _instructionsController.text,
          });
        }
        if (widget.isEditing) {
          await FirebaseFirestore.instance
              .collection('recipes')
              .doc(widget.recipeId)
              .update(recipeData);
        } else {
          await FirebaseFirestore.instance
              .collection('recipes')
              .add(recipeData);
        }
        Navigator.pop(context);
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $error')),
        );
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText ?? '입력하세요',
          helperText: keyboardType == TextInputType.number ? '양수만 입력하세요' : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        keyboardType: keyboardType,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isEditing ? '레시피 수정' : '레시피 추가',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.brown[700],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16.0,
            16.0,
            16.0,
            16.0 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(
                controller: _titleController,
                label: '레시피 제목',
              ),
              const SizedBox(height: 16),
              if (widget.category == 'coffee') ...[
                Text('원두', style: Theme.of(context).textTheme.titleMedium),
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _beans.length,
                  itemBuilder: (context, index) {
                    var bean = _beans[index];
                    return Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: bean['beanId']?.isEmpty ?? true
                                ? null
                                : bean['beanId'],
                            hint: Text('원두 선택'),
                            isExpanded: true,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            items: _beanOptions.map((option) {
                              return DropdownMenuItem<String>(
                                value: option['id'] as String,
                                child: Text(option['name'] as String),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _beans[index]['beanId'] = value;
                                _beans[index]['name'] = _beanOptions.firstWhere(
                                        (opt) => opt['id'] == value)['name']
                                    as String;
                              });
                            },
                            menuMaxHeight: 288,
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller:
                                TextEditingController(text: bean['weight']),
                            decoration: InputDecoration(
                              labelText: '무게 (g)',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              setState(() {
                                _beans[index]['weight'] = value;
                              });
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _beans.removeAt(index);
                            });
                          },
                        ),
                      ],
                    );
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: _addBean,
                      child: Text('원두 추가'),
                    ),
                    ElevatedButton(
                      onPressed: _addNewBean,
                      child: Text('새 원두 추가'),
                    ),
                  ],
                ),
                _buildTextField(
                  controller: _bloomingWaterController,
                  label: '블루밍 물량 (ml)',
                  keyboardType: TextInputType.number,
                ),
                _buildTextField(
                  controller: _bloomingTimeController,
                  label: '블루밍 시간 (초)',
                  keyboardType: TextInputType.number,
                ),
                ..._extractions.asMap().entries.map((entry) {
                  int index = entry.key;
                  var extraction = entry.value;
                  return Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller:
                              TextEditingController(text: extraction['stage']),
                          label: '추출 단계',
                          onChanged: (value) => extraction['stage'] = value,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTextField(
                          controller:
                              TextEditingController(text: extraction['water']),
                          label: '물량 (ml)',
                          keyboardType: TextInputType.number,
                          onChanged: (value) => extraction['water'] = value,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _extractions.removeAt(index);
                          });
                        },
                      ),
                    ],
                  );
                }).toList(),
                ElevatedButton(
                  onPressed: _addExtraction,
                  child: const Text('추출 단계 추가'),
                ),
                CheckboxListTile(
                  title: const Text('가수 여부'),
                  value: _additionalWater,
                  onChanged: (value) {
                    setState(() {
                      _additionalWater = value!;
                    });
                  },
                ),
                if (_additionalWater)
                  _buildTextField(
                    controller: _additionalWaterAmountController,
                    label: '가수량 (ml)',
                    keyboardType: TextInputType.number,
                  ),
              ] else ...[
                _buildTextField(
                  controller: _recipeNameController,
                  label: '요리 이름',
                ),
                _buildTextField(
                  controller: _ingredientsController,
                  label: '재료',
                ),
                _buildTextField(
                  controller: _instructionsController,
                  label: '조리법',
                ),
              ],
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _saveRecipe,
          backgroundColor: Colors.brown[700],
          foregroundColor: Colors.white,
          tooltip: '레시피 저장',
          child: const Icon(Icons.save),
        ),
      ),
    );
  }
}
