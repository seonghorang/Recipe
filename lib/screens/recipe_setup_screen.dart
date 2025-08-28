import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'select_recipe_screen.dart';

class RecipeSetupScreen extends StatefulWidget {
  final String category; // ✅ 커피 or 요리 구분
  final String? recipeId; // 수정 모드일 때 사용
  final bool isEditing; // 수정 모드 여부

  const RecipeSetupScreen({
    super.key,
    required this.category,
    this.recipeId,
    required this.isEditing,
  });

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
  // List<Map<String, dynamic>> _beans: 레시피에 사용될 원두들을 동적으로 관리하는 리스트
  // 각 원소는 { 'beanId': selectedId, 'name': selectedName, 'weight': inputWeight } 형태
  List<Map<String, dynamic>> _beans = [];

  final TextEditingController _bloomingWaterController =
      TextEditingController();
  final TextEditingController _bloomingTimeController = TextEditingController();
  List<Map<String, dynamic>> _extractions = []; // 아직 사용 안 함
  bool _additionalWater = false;
  final TextEditingController _additionalWaterAmountController =
      TextEditingController();

  // Firebase /beans 컬렉션에서 가져올 마스터 원두 목록
  // {id: 'docId', name: '원두명'} 형태로 저장
  List<Map<String, String>> _availableBeans = [];

  @override
  void initState() {
    super.initState();
    _fetchAvailableBeans(); // 사용 가능한 원두 목록 불러오기

    print("[InitState] RecipeSetupScreen initState 시작."); // <<< 추가
    print("[InitState] widget.isEditing: ${widget.isEditing}"); // <<< 추가
    print("[InitState] widget.recipeId: ${widget.recipeId}"); // <<< 추가

    if (widget.isEditing && widget.recipeId != null) {
      print("[InitState] 새 레시피 추가 모드 감지, _loadMostRecentRecipe 호출 시도.");
      _loadRecipeData(widget.recipeId!, isForEditing: true); // 기존 레시피 데이터 로드
    } else if (!widget.isEditing && widget.recipeId != null) {
      _loadMostRecentRecipe();
    }
    // 새로운 레시피 추가 시, 최소 하나의 원두 입력 칸을 기본으로 제공 (이 로직은 그대로 유지)
    if (widget.category == "coffee" && _beans.isEmpty) {
      if (_beans.isEmpty) {
        // 이전 로드에서 _beans가 채워지지 않았다면
        _beans.add({'beanId': null, 'weight': '', 'name': ''});
      }
    }
  }

  Future<void> _loadMostRecentRecipe() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print("[LoadRecent] 사용자 로그인 안됨. 최근 레시피 불러오기 건너뛰기.");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요하여 최근 레시피를 불러올 수 없습니다.')));
      return;
    }
    print("[LoadRecent] 현재 로그인 사용자 UID: ${currentUser.uid}");
    print("[LoadRecent] 현재 레시피 카테고리: ${widget.category}");

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('recipes')
          .where('userId', isEqualTo: currentUser.uid)
          .where('category', isEqualTo: widget.category)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      print("[LoadRecent] Firestore 쿼리 결과: ${snapshot.docs.length}개 문서.");

      if (snapshot.docs.isNotEmpty) {
        final mostRecentRecipe = snapshot.docs.first;
        print("[LoadRecent] 가장 최근 레시피 ID: ${mostRecentRecipe.id}");
        print(
            "[LoadRecent] 가장 최근 레시피 데이터: ${mostRecentRecipe.data()}"); // <<< 이 로그가 가장 중요!

        _loadRecipeData(mostRecentRecipe.id,
            isForEditing: false); // 불러오기 로직 재활용
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('최근 레시피를 불러왔습니다.')));
      } else {
        print("[LoadRecent] 쿼리 조건에 맞는 최근 레시피가 없습니다.");
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('최근 레시피가 없습니다. 새롭게 작성해주세요.')));
        // ... (최소 원두 입력칸 제공 로직) ...
      }
    } catch (e) {
      print("[LoadRecent] Error loading most recent recipe: $e"); // 에러 메시지 확인
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('최근 레시피 로드 실패: ${e.toString()}')));
      if (widget.category == "coffee" && _beans.isEmpty) {
        setState(() {
          // 오류 발생 시에도 최소 원두 입력칸은 제공
          _beans.add({'beanId': null, 'weight': '', 'name': ''});
        });
      }
    }
  }

  // 사용 가능한 원두 목록을 Firestore에서 가져오는 함수
  Future<void> _fetchAvailableBeans() async {
    try {
      final QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('beans').get();
      setState(() {
        _availableBeans = snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  'name': doc['name'] as String? ?? doc.id, // 이름 없으면 ID 사용
                })
            .toList();
        // 원두 추가 시 드롭다운의 초기값은 첫 번째 원두가 되도록 할 수 있습니다.
        // 또는 그냥 null로 두어 사용자가 명시적으로 선택하게 할 수도 있습니다.
      });
    } catch (e) {
      print("Error fetching available beans: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('원두 목록 로드 실패: ${e.toString()}')));
    }
  }

  // 기존 레시피 데이터를 로드하는 함수 (수정 모드일 때)
  Future<void> _loadRecipeData(String recipeIdToLoad,
      {required bool isForEditing}) async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('recipes')
          .doc(recipeIdToLoad)
          .get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;

        setState(() {
          _dateController.text = data['title'] ?? '';

          if (widget.category == "coffee") {
            _beanType = data['beanType'] ?? 'single';
            _bloomingWaterController.text =
                (data['blooming']?['water'] ?? 0).toString();
            _bloomingTimeController.text =
                (data['blooming']?['time'] ?? 0).toString();
            _additionalWater = data['additionalWater'] ?? false;
            _additionalWaterAmountController.text =
                (data['additionalWaterAmount'] ?? 0).toString();

            // 기존 beans 데이터 로드
            if (data.containsKey('beans') && data['beans'] is List) {
              _beans = List<Map<String, dynamic>>.from(data['beans']);
            } else {
              _beans = [];
            }
          } else {
            _recipeNameController.text = data['recipeName'] ?? '';
            _ingredientsController.text = data['ingredients'] ?? '';
            _instructionsController.text = data['instructions'] ?? '';
          }
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('레시피 데이터를 불러왔습니다.')));
      }
    } catch (e) {
      print("Error loading recipe data: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('레시피 로드 실패: ${e.toString()}')));
    }
  }

  // 새 원두 종류를 Firestore /beans 컬렉션에 추가하고 드롭다운 목록도 업데이트
  Future<void> _addNewBean() async {
    String? newBeanName = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 원두 추가'),
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
            child: const Text('취소'),
          ),
          TextButton(
            // TextField의 Controller를 직접 가져오기 어렵기 때문에, onSubmitted 사용을 권장합니다.
            // 또는 TextButton 내에서 새로운 TextEditingController를 선언하고 값을 가져옵니다.
            // 여기서는 간단히 Navigator.pop(ctx, newController.text) 방식으로 변경했습니다.
            onPressed: () {
              final tempController = TextEditingController(); // 임시 컨트롤러
              showDialog(
                context: ctx,
                builder: (innerCtx) => AlertDialog(
                  title: const Text('새 원두 이름 입력'),
                  content: TextField(controller: tempController),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(innerCtx),
                        child: const Text('취소')),
                    TextButton(
                        onPressed: () =>
                            Navigator.pop(innerCtx, tempController.text),
                        child: const Text('확인')),
                  ],
                ),
              ).then((result) {
                if (result != null && result.isNotEmpty)
                  Navigator.pop(ctx, result);
              });
            },
            child: const Text('추가'),
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
      // 마스터 원두 목록 (_availableBeans) 업데이트
      setState(() {
        _availableBeans.add({'id': docRef.id, 'name': newBeanName});
        // 새로 추가된 원두를 드롭다운에서 선택된 상태로 설정할 수도 있습니다.
      });
    }
  }

  // 현재 레시피에 원두 입력 항목(한 줄)을 추가하는 함수
  void _addBeanEntryRow() {
    setState(() {
      _beans.add({
        'beanId': null, // 처음에는 선택되지 않은 상태
        'weight': '',
        'name': '' // 처음에는 이름 없음
      });
    });
  }

  // 레시피 저장/수정 함수
  Future<void> _saveRecipe() async {
    if (_dateController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('날짜는 필수입니다.')));
      return;
    }

    // 레시피 추가/수정은 userId가 필수라고 가정 (로그인 필요성 유지)
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
      return;
    }

    Map<String, dynamic> recipeData = {
      'title': _dateController.text,
      'category': widget.category,
      'userId': currentUser.uid, // 레시피 작성자 ID 저장
      'updatedAt': FieldValue.serverTimestamp(), // 수정 시간
    };

    if (!widget.isEditing) {
      // 새로 생성 시에만 createdAt 추가
      recipeData['createdAt'] = FieldValue.serverTimestamp();
    }

    if (widget.category == "coffee") {
      recipeData.addAll({
        'beanType': _beanType,
        'beans': _beans
            .where(
                (b) => b['beanId'] != null && b['weight'].toString().isNotEmpty)
            .toList(), // 비어있지 않은 원두 항목만 저장
        'blooming': {
          'water': int.tryParse(_bloomingWaterController.text) ?? 0,
          'time': int.tryParse(_bloomingTimeController.text) ?? 0,
        },
        'additionalWater': _additionalWater,
        'additionalWaterAmount': _additionalWater
            ? int.tryParse(_additionalWaterAmountController.text) ?? 0
            : 0,
      });
    } else {
      // 요리 레시피
      recipeData.addAll({
        'recipeName': _recipeNameController.text,
        'ingredients': _ingredientsController.text,
        'instructions': _instructionsController.text,
      });
    }

    try {
      if (widget.isEditing && widget.recipeId != null) {
        await FirebaseFirestore.instance
            .collection('recipes')
            .doc(widget.recipeId)
            .update(recipeData);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('레시피가 수정되었습니다.')));
      } else {
        await FirebaseFirestore.instance.collection('recipes').add(recipeData);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('레시피가 등록되었습니다.')));
      }
      Navigator.pop(context); // 이전 화면으로 돌아가기
    } catch (e) {
      print('레시피 저장/수정 오류: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('오류 발생: $e')));
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _recipeNameController.dispose();
    _ingredientsController.dispose();
    _instructionsController.dispose();
    _bloomingWaterController.dispose();
    _bloomingTimeController.dispose();
    _additionalWaterAmountController.dispose();
    // _beanWeightController.dispose(); // _addSelectedBeanToList 함수에서 사용했으므로 여기서 dispose

    // 필요하다면 동적으로 추가된 TextField 컨트롤러도 dispose해야 하지만,
    // 현재 구현에서는 하나의 TextField 컨트롤러를 사용하지 않고, 각 항목에 별도의 컨트롤러를 두지 않았습니다.
    // 만약 각 동적 항목에 TextEditingController를 사용한다면 여기서 dispose 처리가 필요합니다.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${widget.category == "coffee" ? "커피" : "요리"} 레시피 ${widget.isEditing ? "수정" : "설정"}'),
        // actions: [
        //   if (!widget.isEditing) // 수정 모드가 아닐 때만 불러오기 버튼 표시
        //     IconButton(
        //       icon: const Icon(Icons.download), // 불러오기 아이콘
        //       onPressed: () async {
        //         final selectedRecipeId = await Navigator.push(
        //           context,
        //           MaterialPageRoute(
        //             builder: (context) =>
        //                 SelectRecipeScreen(category: widget.category),
        //           ),
        //         );
        //         if (selectedRecipeId != null) {
        //           _loadRecipeData(selectedRecipeId,
        //               isForEditing: false); // 불러온 레시피ID로 데이터 로드 (새 작성용)
        //         }
        //       },
        //     ),
        // ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _dateController,
              decoration:
                  const InputDecoration(labelText: '날짜 (예: 2024-03-02)'),
            ),
            const SizedBox(height: 10),
            if (widget.category == "coffee") ...[
              const Text('원두 타입'),
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
              // === 원두 추가 및 목록 UI ===
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('사용된 원두',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed:
                        _addBeanEntryRow, // <<< 여기를 수정 (_addBean() 대신 _addBeanEntryRow() 호출)
                  ),
                  IconButton(
                    icon: const Icon(Icons.library_add), // 새로운 원두 종류 추가 버튼
                    onPressed: _addNewBean,
                  ),
                ],
              ),
              Column(
                children: _beans.asMap().entries.map((entry) {
                  int idx = entry.key;
                  Map<String, dynamic> beanEntry = entry.value;

                  // 이 부분은 각 항목에 대한 TextFieldController가 필요할 수 있습니다.
                  // 단순하게 value를 받아와서 _beans 리스트의 해당 Map을 업데이트하는 방식으로 구현합니다.
                  TextEditingController beanWeightController =
                      TextEditingController(
                          text: beanEntry['weight'].toString());
                  beanWeightController.addListener(() {
                    beanEntry['weight'] =
                        int.tryParse(beanWeightController.text) ?? 0;
                  });

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            value: beanEntry['beanId'],
                            hint: const Text('원두 선택'),
                            onChanged: (String? newValue) {
                              setState(() {
                                // 선택된 원두의 id와 name을 _beans 리스트 내 해당 항목에 업데이트
                                beanEntry['beanId'] = newValue;
                                beanEntry['name'] = _availableBeans.firstWhere(
                                    (bean) => bean['id'] == newValue)['name'];
                              });
                            },
                            items: _availableBeans
                                .map<DropdownMenuItem<String>>((bean) {
                              return DropdownMenuItem<String>(
                                value: bean['id'],
                                child: Text(bean['name']!),
                              );
                            }).toList(),
                            decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: beanWeightController,
                            decoration: const InputDecoration(
                                labelText: 'g',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8)),
                            keyboardType: TextInputType.number,
                            // onSubmitted 또는 onChanged에서 바로 업데이트도 가능 (addListener 대신)
                            onChanged: (value) {
                              beanEntry['weight'] = int.tryParse(value) ?? 0;
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _beans.removeAt(idx);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              const Text('블루밍'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _bloomingWaterController,
                      decoration: const InputDecoration(labelText: '물 (g)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _bloomingTimeController,
                      decoration: const InputDecoration(labelText: '시간 (초)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              CheckboxListTile(
                title: const Text('가수 여부'),
                value: _additionalWater,
                onChanged: (value) => setState(() => _additionalWater = value!),
              ),
              if (_additionalWater)
                TextField(
                  controller: _additionalWaterAmountController,
                  decoration: const InputDecoration(labelText: '가수량 (g)'),
                  keyboardType: TextInputType.number,
                ),
            ] else ...[
              TextField(
                controller: _recipeNameController,
                decoration: const InputDecoration(labelText: '요리 이름'),
              ),
              TextField(
                controller: _ingredientsController,
                decoration: const InputDecoration(labelText: '재료 목록'),
                maxLines: 3,
              ),
              TextField(
                controller: _instructionsController,
                decoration: const InputDecoration(labelText: '조리 방법'),
                maxLines: 5,
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveRecipe, // <<< _addRecipe 대신 _saveRecipe 호출
              child: Text(widget.isEditing ? '수정' : '저장'),
            ),
          ],
        ),
      ),
    );
  }
}
