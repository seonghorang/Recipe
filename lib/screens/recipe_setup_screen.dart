import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final List<Map<String, String>> _beans = [];
  final _bloomingWaterController = TextEditingController();
  final _bloomingTimeController = TextEditingController();
  final List<Map<String, String>> _extractions = [];
  bool _additionalWater = false;
  final _additionalWaterAmountController = TextEditingController();
  final _recipeNameController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _instructionsController = TextEditingController();

  Map<String, dynamic>? _recentRecipe; // 최근 레시피 데이터 저장

  @override
  void initState() {
    super.initState();
    _loadRecentRecipe(); // 새 레시피 추가 시 최근 레시피 불러오기
    if (widget.isEditing && widget.recipeId != null) {
      _loadRecipeData(); // 편집 모드에서 기존 레시피 데이터 불러오기
    }
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
    if (widget.isEditing) return; // 편집 모드에서는 건너뜀
    final snapshot = await FirebaseFirestore.instance
        .collection('recipes')
        .where('category', isEqualTo: widget.category)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      setState(() {
        _recentRecipe = snapshot.docs.first.data();
        // 최근 레시피 데이터로 필드 미리 채우기
        if (widget.category == 'coffee') {
          _beanType = _recentRecipe!['beanType'] ?? 'single';
          _beans.addAll((_recentRecipe!['beans'] as List<dynamic>?)
                  ?.map((b) => {
                        'name': b['name'].toString(),
                        'weight': b['weight'].toString(),
                      })
                  .toList() ??
              []);
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
          _beans.addAll((data['beans'] as List<dynamic>?)
                  ?.map((b) => {
                        'name': b['name'].toString(),
                        'weight': b['weight'].toString(),
                      })
                  .toList() ??
              []);
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

  void _addBean() {
    setState(() {
      _beans.add({'name': '', 'weight': ''});
    });
  }

  void _addExtraction() {
    setState(() {
      _extractions.add({'stage': '${_extractions.length + 1}', 'water': ''});
    });
  }

  void _saveRecipe() {
    // 유효성 검사
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목을 입력하세요')),
      );
      return;
    }
    if (widget.category == 'coffee') {
      if (_beanType.isEmpty || !['single', 'blend'].contains(_beanType)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('원두 타입을 선택하세요 (single/blend)')),
        );
        return;
      }
      if (_beans.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('최소 하나의 원두를 추가하세요')),
        );
        return;
      }
      for (var bean in _beans) {
        if (bean['name']?.isEmpty ?? true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('모든 원두의 이름을 입력하세요')),
          );
          return;
        }
        final weight = int.tryParse(bean['weight'] ?? '0');
        if (weight == null || weight <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('모든 원두의 무게를 양수로 입력하세요')),
          );
          return;
        }
      }
      if (_bloomingWaterController.text.isNotEmpty ||
          _bloomingTimeController.text.isNotEmpty) {
        final water = int.tryParse(_bloomingWaterController.text);
        if (water == null || water <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('블루밍 물량을 양수로 입력하세요')),
          );
          return;
        }
        final time = int.tryParse(_bloomingTimeController.text);
        if (time == null || time <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('블루밍 시간을 양수로 입력하세요')),
          );
          return;
        }
      }
      for (var extraction in _extractions) {
        final amount = int.tryParse(extraction['water'] ?? '0');
        if (amount == null || amount <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('모든 추출 단계의 물량을 양수로 입력하세요')),
          );
          return;
        }
      }
      if (_additionalWater &&
          _additionalWaterAmountController.text.isNotEmpty) {
        final amount = int.tryParse(_additionalWaterAmountController.text);
        if (amount == null || amount <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('가수량을 양수로 입력하세요')),
          );
          return;
        }
      }
    } else {
      if (_recipeNameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('요리 이름을 입력하세요')),
        );
        return;
      }
    }

    // 데이터 준비
    Map<String, dynamic> recipeData = {
      'title': _titleController.text,
      'category': widget.category,
      'createdAt': widget.isEditing
          ? FieldValue.serverTimestamp()
          : FieldValue.serverTimestamp(),
      'wifeRating': widget.isEditing ? null : 0.0,
      'wifeReview': '',
    };

    if (widget.category == 'coffee') {
      recipeData.addAll({
        'beanType': _beanType,
        'beans': _beans
            .map((bean) => {
                  'name': bean['name'],
                  'weight': int.parse(bean['weight']!),
                })
            .toList(),
        'blooming': {
          'water': _bloomingWaterController.text.isNotEmpty
              ? int.parse(_bloomingWaterController.text)
              : 0,
          'time': _bloomingTimeController.text.isNotEmpty
              ? int.parse(_bloomingTimeController.text)
              : 0,
        },
        'extractions': _extractions
            .map((e) => {
                  'stage': e['stage'],
                  'water': int.parse(e['water']!),
                })
            .toList(),
        'additionalWater': _additionalWater,
        'additionalWaterAmount':
            _additionalWater && _additionalWaterAmountController.text.isNotEmpty
                ? int.parse(_additionalWaterAmountController.text)
                : 0,
      });
    } else {
      recipeData.addAll({
        'recipeName': _recipeNameController.text,
        'ingredients': _ingredientsController.text,
        'instructions': _instructionsController.text,
      });
    }

    // 저장 또는 업데이트
    if (widget.isEditing && widget.recipeId != null) {
      FirebaseFirestore.instance
          .collection('recipes')
          .doc(widget.recipeId)
          .update(recipeData);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('레시피가 수정되었습니다')),
      );
    } else {
      FirebaseFirestore.instance.collection('recipes').add(recipeData);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('레시피가 추가되었습니다')),
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing
              ? '${widget.category == 'coffee' ? '커피' : '요리'} 레시피 수정'
              : '${widget.category == 'coffee' ? '커피' : '요리'} 레시피 추가'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
          child: Column(
            children: [
              _buildTextField(
                controller: _titleController,
                label: '제목',
                hintText: '레시피 제목을 입력하세요 (예: 에티오피아 커피)',
              ),
              if (widget.category == 'coffee') ...[
                DropdownButton<String>(
                  value: _beanType,
                  onChanged: (value) {
                    setState(() {
                      _beanType = value!;
                    });
                  },
                  items: const [
                    DropdownMenuItem(
                        value: 'single', child: Text('Single Origin')),
                    DropdownMenuItem(value: 'blend', child: Text('Blend')),
                  ],
                ),
                ..._beans.asMap().entries.map((entry) {
                  int index = entry.key;
                  var bean = entry.value;
                  return Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: TextEditingController(text: bean['name']),
                          label: '원두 이름',
                          onChanged: (value) => bean['name'] = value,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTextField(
                          controller:
                              TextEditingController(text: bean['weight']),
                          label: '무게 (g)',
                          keyboardType: TextInputType.number,
                          onChanged: (value) => bean['weight'] = value,
                        ),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _beans.removeAt(index);
                          });
                        },
                      ),
                    ],
                  );
                }).toList(),
                ElevatedButton(
                  onPressed: _addBean,
                  child: const Text('원두 추가'),
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
                        icon:
                            const Icon(Icons.remove_circle, color: Colors.red),
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
              // ElevatedButton(
              //   onPressed: _saveRecipe,
              //   child: Text(widget.isEditing ? '수정 저장' : '레시피 추가'),
              // ),
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
}
