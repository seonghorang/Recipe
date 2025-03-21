import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RecipeSetupScreen extends StatefulWidget {
  final String category; // ✅ 커피 or 요리 구분

  const RecipeSetupScreen({super.key, required this.category});

  @override
  _RecipeSetupScreenState createState() => _RecipeSetupScreenState();
}

class _RecipeSetupScreenState extends State<RecipeSetupScreen> {
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _recipeNameController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();

  // 커피 레시피 관련 필드
  String _beanType = 'single';
  List<Map<String, dynamic>> _beans = [];
  final TextEditingController _bloomingWaterController =
      TextEditingController();
  final TextEditingController _bloomingTimeController = TextEditingController();
  List<Map<String, dynamic>> _extractions = [];
  bool _additionalWater = false;
  final TextEditingController _additionalWaterAmountController =
      TextEditingController();

  void _addBean() {
    setState(() {
      _beans.add({'name': '', 'weight': ''});
    });
  }

  void _addExtractionStep() {
    setState(() {
      _extractions.add({'stage': _extractions.length + 1, 'water': ''});
    });
  }

  void _addRecipe() {
    if (_dateController.text.isEmpty) return;

    Map<String, dynamic> recipeData = {
      'title': _dateController.text,
      'category': widget.category,
    };

    if (widget.category == "coffee") {
      recipeData.addAll({
        'beanType': _beanType,
        'beans': _beans,
        'blooming': {
          'water': int.tryParse(_bloomingWaterController.text) ?? 0,
          'time': int.tryParse(_bloomingTimeController.text) ?? 0,
        },
        'extractions': _extractions,
        'additionalWater': _additionalWater,
        'additionalWaterAmount': _additionalWater
            ? int.tryParse(_additionalWaterAmountController.text) ?? 0
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
    Navigator.pop(context);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        keyboardType: keyboardType,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text('${widget.category == "coffee" ? "커피" : "요리"} 레시피 설정')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
                controller: _dateController, label: '날짜 (예: 2024-03-02)'),
            if (widget.category == "coffee") ...[
              const SizedBox(height: 10),
              const Text('원두 타입',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile(
                      title: const Text('단일'),
                      value: 'single',
                      groupValue: _beanType,
                      onChanged: (value) => setState(() => _beanType = value!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile(
                      title: const Text('혼합'),
                      value: 'blend',
                      groupValue: _beanType,
                      onChanged: (value) => setState(() => _beanType = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text('원두',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Column(
                children: _beans.asMap().entries.map((entry) {
                  int index = entry.key;
                  return Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: TextEditingController(
                              text: _beans[index]['name']),
                          label: '원두명',
                          onChanged: (value) => _beans[index]['name'] = value,
                        ),
                      ),
                      Expanded(
                        child: _buildTextField(
                          controller: TextEditingController(
                              text: _beans[index]['weight']),
                          label: '무게 (g)',
                          keyboardType: TextInputType.number,
                          onChanged: (value) => _beans[index]['weight'] = value,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              TextButton(onPressed: _addBean, child: const Text('+ 원두 추가')),
              const SizedBox(height: 10),
              const Text('블루밍',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              _buildTextField(
                  controller: _bloomingWaterController,
                  label: '물 (g)',
                  keyboardType: TextInputType.number),
              _buildTextField(
                  controller: _bloomingTimeController,
                  label: '시간 (초)',
                  keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              const Text('추출 단계',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Column(
                children: _extractions.asMap().entries.map((entry) {
                  int index = entry.key;
                  return Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: TextEditingController(
                              text: _extractions[index]['stage'].toString()),
                          label: '차수',
                          keyboardType: TextInputType.number,
                          onChanged: (value) => _extractions[index]['stage'] =
                              int.tryParse(value) ?? 1,
                        ),
                      ),
                      Expanded(
                        child: _buildTextField(
                          controller: TextEditingController(
                              text: _extractions[index]['water'].toString()),
                          label: '물 (g)',
                          keyboardType: TextInputType.number,
                          onChanged: (value) => _extractions[index]['water'] =
                              int.tryParse(value) ?? 0,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              TextButton(
                  onPressed: _addExtractionStep,
                  child: const Text('+ 추출 단계 추가')),
              CheckboxListTile(
                title: const Text('가수 여부'),
                value: _additionalWater,
                onChanged: (value) => setState(() => _additionalWater = value!),
              ),
              if (_additionalWater)
                _buildTextField(
                    controller: _additionalWaterAmountController,
                    label: '가수량 (g)',
                    keyboardType: TextInputType.number),
            ] else ...[
              _buildTextField(
                  controller: _recipeNameController, label: '요리 이름'),
              _buildTextField(
                  controller: _ingredientsController, label: '재료 목록'),
              _buildTextField(
                  controller: _instructionsController, label: '조리 방법'),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addRecipe,
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}
