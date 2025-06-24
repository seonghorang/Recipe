import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RecipeSetupScreen extends StatefulWidget {
  final String category;
  const RecipeSetupScreen({super.key, required this.category});

  @override
  _RecipeSetupScreenState createState() => _RecipeSetupScreenState();
}

class _RecipeSetupScreenState extends State<RecipeSetupScreen> {
  final _titleController = TextEditingController(); // 제목 입력
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

  void _addRecipe() {
    // 검증 로직
    // 1. 공통 검증: 제목
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목을 입력하세요')),
      );
      return;
    }

    // 2. 커피 레시피 검증
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
    }
    // 3. 요리 레시피 검증
    else {
      if (_recipeNameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('요리 이름을 입력하세요')),
        );
        return;
      }
    }

    // 데이터 저장
    Map<String, dynamic> recipeData = {
      'title': _titleController.text,
      'category': widget.category,
      'createdAt': FieldValue.serverTimestamp(),
      'wifeRating': 0.0,
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

    FirebaseFirestore.instance.collection('recipes').add(recipeData);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('레시피가 성공적으로 추가되었습니다')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text('${widget.category == 'coffee' ? '커피' : '요리'} 레시피 추가')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
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
              // 원두 추가 UI
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
                        controller: TextEditingController(text: bean['weight']),
                        label: '무게 (g)',
                        keyboardType: TextInputType.number,
                        onChanged: (value) => bean['weight'] = value,
                      ),
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
              // 추출 단계 UI
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
            ElevatedButton(
              onPressed: _addRecipe,
              child: const Text('레시피 추가'),
            ),
          ],
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
