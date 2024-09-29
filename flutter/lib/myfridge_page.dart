import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:intl/intl.dart';
import 'package:translator/translator.dart';
import 'package:provider/provider.dart';
import 'recipe_provider.dart'; // RecipeProvider 임포트
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class MyFridgePage extends StatefulWidget {
  const MyFridgePage({super.key});

  @override
  _MyFridgePageState createState() => _MyFridgePageState();
}

class _MyFridgePageState extends State<MyFridgePage> {
  final TextEditingController _ingredientController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();
  final PexelsService _pexelsService = PexelsService();
  final DateFormat _inputDateFormat = DateFormat('yyyy.MM.dd');
  bool _isRoomTemperature = false; // 실온 재료 여부

// 카메라에서 이미지 선택 후 처리
  Future<void> _pickFromCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      // 카메라로 촬영한 이미지 처리 메서드 호출
      await _processReceipt(File(image.path));
    }
  }

  void _addIngredient() async {
    final ingredient = _ingredientController.text.trim();
    final expiryDate = _expiryDateController.text.trim();

    if (ingredient.isNotEmpty) {
      String imageUrl;
      try {
        imageUrl = await _pexelsService.searchImage(ingredient);

        if (imageUrl == 'https://via.placeholder.com/150') {
          final translator = GoogleTranslator();
          final translation = await translator.translate(ingredient, to: 'en');
          imageUrl = await _pexelsService.searchImage(translation.text);
        }

        // 보관 방법에 따라 저장 타입 설정
        final storageType = _isRoomTemperature ? '보관 재료' : '요리 가능 재료';
        final isCooking = storageType == '요리 가능 재료'; // isCooking 결정

        final newIngredient = {
          'name': ingredient,
          'image': imageUrl.isNotEmpty ? imageUrl : '',
          'expiryDate': expiryDate,
          'storage': storageType, // 저장 타입 설정
        };

        // addIngredient 메서드 호출
        Provider.of<RecipeProvider>(context, listen: false)
            .addIngredient(newIngredient, isCooking); // isCooking 전달

        _ingredientController.clear();
        _expiryDateController.clear();

        setState(() {
          _isRoomTemperature = false; // 상태 초기화 및 화면 리빌드
        });
      } catch (e) {
        print('Error fetching image: $e');
      }
    }
  }

  Future<void> _processReceipt(File image) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('http://10.0.2.2:5000/process_recipe'),
    );

    request.files.add(await http.MultipartFile.fromPath('file', image.path));

    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final result = jsonDecode(responseData);

        String ingredientsText = result['ingredients'];
        if (ingredientsText.isEmpty) {
          // 텍스트 인식 실패 시
          showErrorMessage('텍스트를 인식하지 못했습니다. 다시 시도해 주세요.');
          return;
        }

        List<String> ingredients = ingredientsText.split('\n');

        List<String> cookingIngredients = [];
        List<String> nonCookingIngredients = [];
        bool isCookingSection = false;

        for (String ingredient in ingredients) {
          ingredient = ingredient.trim();
          if (ingredient.isEmpty) continue;

          // "요리 가능한 재료:" 키워드가 포함된 경우
          if (ingredient.contains('요리 가능')) {
            isCookingSection = true; // 요리 가능 섹션 시작
            cookingIngredients
                .add(ingredient.replaceAll(RegExp(r'^\d+\.\s*'), '').trim());
            continue; // 다음 재료로 넘어가기
          }

          // "요리 할 수 없는 재료:" 섹션 발견 시
          if (ingredient.contains('요리 할 수 없는 재료')) {
            isCookingSection = false;
            nonCookingIngredients
                .add(ingredient.replaceAll(RegExp(r'^\d+\.\s*'), '').trim());
            continue; // 다음 재료로 넘어가기
          }

          // 요리 가능 섹션에 있는 경우 재료 추가
          if (isCookingSection) {
            cookingIngredients
                .add(ingredient.replaceAll(RegExp(r'^\d+\.\s*'), '').trim());
          } else {
            nonCookingIngredients
                .add(ingredient.replaceAll(RegExp(r'^\d+\.\s*'), '').trim());
          }
        }

        // 요리 가능 재료 처리
        for (String ingredient in cookingIngredients) {
          String imageUrl = await _pexelsService.searchImage(ingredient);
          final newIngredient = {
            'name': ingredient,
            'image': imageUrl.isNotEmpty ? imageUrl : '',
            'expiryDate': '',
            'storage': '요리 가능 재료', // 요리 가능 재료로 저장
          };
          Provider.of<RecipeProvider>(context, listen: false)
              .addIngredient(newIngredient, true); // isCooking을 true로 설정
        }

        // 요리 불가능 재료 처리
        for (String ingredient in nonCookingIngredients) {
          String imageUrl = await _pexelsService.searchImage(ingredient);
          final newIngredient = {
            'name': ingredient,
            'image': imageUrl.isNotEmpty ? imageUrl : '',
            'expiryDate': '',
            'storage': '보관 재료', // 보관 재료로 저장
          };
          Provider.of<RecipeProvider>(context, listen: false)
              .addIngredient(newIngredient, false); // isCooking을 false로 설정
        }

        setState(() {});

        if (kDebugMode) {
          print('Extracted cooking ingredients: $cookingIngredients');
        }
        if (kDebugMode) {
          print('Extracted non-cooking ingredients: $nonCookingIngredients');
        }
      } else {
        if (kDebugMode) {
          print('Error: ${response.statusCode}');
          showErrorMessage('이미지를 처리하는 중 오류가 발생했습니다.');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error processing receipt: $e');
        showErrorMessage('오류가 발생했습니다. 다시 시도해 주세요.');
      }
    }
  }

  Color _getExpiryDateIndicatorColor(String expiryDate) {
    if (expiryDate.isEmpty) {
      return Colors.grey;
    }

    DateTime expiry;
    try {
      expiry = _inputDateFormat.parse(expiryDate);
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing date: $e');
      }
      return Colors.grey;
    }

    final now = DateTime.now();
    final difference = expiry.difference(now).inDays;

    if (difference < 0) {
      return Colors.black;
    } else if (difference <= 2) {
      return Colors.red;
    } else if (difference <= 7) {
      return Colors.yellow;
    } else {
      return Colors.green;
    }
  }

  void _editIngredient(int index) async {
    final ingredient = Provider.of<RecipeProvider>(context, listen: false)
        .getIngredients()[index];

    _ingredientController.text = ingredient['name']!;
    _expiryDateController.text = ingredient['expiryDate'] ?? '';
    _isRoomTemperature = ingredient['storage'] == '보관 재료'; // 현재 저장 상태 설정

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('재료 수정'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _ingredientController,
                    decoration: InputDecoration(labelText: '재료 이름'),
                  ),
                  TextField(
                    controller: _expiryDateController,
                    decoration: InputDecoration(labelText: '유통기한 (YYYY.MM.DD)'),
                    keyboardType: TextInputType.datetime,
                  ),
                  Row(
                    children: [
                      Text('저장 방법: '),
                      Switch(
                        value: _isRoomTemperature,
                        onChanged: (value) {
                          setState(() {
                            _isRoomTemperature = value; // 상태 변경
                          });
                        },
                      ),
                      Text(_isRoomTemperature ? '보관 재료' : '요리 가능 재료'),
                    ],
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final updatedIngredient = _ingredientController.text.trim();
                final updatedExpiryDate = _expiryDateController.text.trim();

                if (updatedIngredient.isNotEmpty) {
                  // 수정된 재료의 이미지 검색
                  String newImageUrl = ingredient['image']!;

                  if (updatedIngredient != ingredient['name']) {
                    newImageUrl =
                        await _pexelsService.searchImage(updatedIngredient);
                    if (newImageUrl == 'https://via.placeholder.com/150') {
                      final translator = GoogleTranslator();
                      final translation = await translator
                          .translate(updatedIngredient, to: 'en');
                      newImageUrl =
                          await _pexelsService.searchImage(translation.text);
                    }
                  }

                  // 수정된 재료의 storage 및 isCooking 결정
                  final updatedStorageType =
                      _isRoomTemperature ? '보관 재료' : '요리 가능 재료';
                  final isCooking = updatedStorageType == '요리 가능 재료';

                  // 재료 업데이트
                  final updated = {
                    'name': updatedIngredient,
                    'image': newImageUrl,
                    'expiryDate': updatedExpiryDate,
                    'storage': updatedStorageType,
                  };

                  // 기존 재료 수정
                  Provider.of<RecipeProvider>(context, listen: false)
                      .updateIngredient(index, updated, isCooking);

                  Navigator.of(context).pop();
                }
              },
              child: Text('수정'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('취소'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIngredientInput(),
            SizedBox(height: 16),
            Expanded(
              child: PageView(
                children: [
                  _buildIngredientList('요리 가능 재료'),
                  _buildIngredientList('보관 재료'),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: SpeedDial(
        animatedIcon: AnimatedIcons.menu_close,
        backgroundColor: const Color(0xFFFF7E36),
        children: [
          SpeedDialChild(
            child: const Icon(Icons.camera_alt),
            label: '카메라',
            onTap: () async {
              // 카메라에서 이미지 선택
              await _pickFromCamera();
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.image),
            label: '갤러리',
            onTap: () async {
              // 갤러리에서 이미지 선택
              final ImagePicker _picker = ImagePicker();
              final XFile? image =
                  await _picker.pickImage(source: ImageSource.gallery);

              if (image != null) {
                // 갤러리에서 선택한 이미지 처리 메서드 호출
                await _processReceipt(File(image.path));
              }
            },
          ),
        ],
      ),
    );
  }

  void showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red, // 오류 메시지이므로 빨간색으로 표시
      ),
    );
  }

// 재료 입력 UI 구성
  Widget _buildIngredientInput() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ingredientController,
                decoration: InputDecoration(
                  labelText: '재료 입력',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _addIngredient(),
              ),
            ),
            SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isRoomTemperature = !_isRoomTemperature;
                });
              },
              child: Text(_isRoomTemperature ? '보관 선택됨' : '보관'),
            ),
          ],
        ),
        SizedBox(height: 8),
        TextField(
          controller: _expiryDateController,
          decoration: InputDecoration(
            labelText: '유통기한 (YYYY.MM.DD)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.datetime,
          onSubmitted: (_) => _addIngredient(),
        ),
        SizedBox(height: 8),
        ElevatedButton(
          onPressed: _addIngredient,
          child: Text('재료 추가'),
        ),
      ],
    );
  }

// 재료 목록 UI 구성
  Widget _buildIngredientList(String storageType) {
    return Consumer<RecipeProvider>(
      builder: (context, recipeProvider, child) {
        final ingredients = recipeProvider.getIngredients();
        final filteredIngredients = ingredients
            .where((ingredient) => ingredient['storage'] == storageType)
            .toList();

        // 유통기한을 기준으로 재료 정렬
        filteredIngredients.sort((a, b) {
          final expiryDateA =
              a['expiryDate'] != null && a['expiryDate']!.isNotEmpty
                  ? _inputDateFormat.parse(a['expiryDate']!)
                  : DateTime.now();
          final expiryDateB =
              b['expiryDate'] != null && b['expiryDate']!.isNotEmpty
                  ? _inputDateFormat.parse(b['expiryDate']!)
                  : DateTime.now();
          return expiryDateA.compareTo(expiryDateB);
        });

        return Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                storageType == '요리 가능 재료' ? '요리 가능 재료 목록' : '보관 재료 목록',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filteredIngredients.length,
                itemBuilder: (context, index) {
                  final ingredient = filteredIngredients[index];
                  final name = ingredient['name']!;
                  final imageUrl = ingredient['image']!;
                  final expiryDate = ingredient['expiryDate'] ?? '';
                  final storage = ingredient['storage'] ?? '요리 가능 재료';

                  final color = _getExpiryDateIndicatorColor(expiryDate);

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: Stack(
                            alignment: Alignment.topRight,
                            children: [
                              Image.network(imageUrl, fit: BoxFit.cover),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: CircleAvatar(
                                  backgroundColor: color,
                                  radius: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: TextStyle(fontSize: 16)),
                              Text('유통기한: $expiryDate',
                                  style: TextStyle(fontSize: 14)),
                              Text('보관 방법: $storage',
                                  style: TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () {
                            Provider.of<RecipeProvider>(context, listen: false)
                                .removeIngredient(index); // 재료 삭제
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      // 수정 시 index를 올바르게 찾도록 수정
                      int originalIndex = ingredients.indexOf(ingredient);
                      _editIngredient(originalIndex); // 원래 인덱스 사용
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class PexelsService {
  final String _accessKey =
      'eF9GnybSb69VqyqMWelHNylGYV8njeRJeBTJzCSIhCPhn9LYfuStiQNq';

  Future<String> searchImage(String query) async {
    // 여러 키워드를 공백으로 분리하여 검색
    final keywords = query.split(' ').join(','); // 키워드를 쉼표로 구분

    final response = await http.get(
        Uri.parse(
            'https://api.pexels.com/v1/search?query=${Uri.encodeQueryComponent(keywords)}&per_page=1'),
        headers: {'Authorization': _accessKey});

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('API Response: $data');
      if (data['photos'] != null && data['photos'].isNotEmpty) {
        return data['photos'][0]['src']['medium'];
      } else {
        print('No photos found for query: $query');
      }
    } else {
      print('Error fetching data: ${response.statusCode}');
    }
    return 'https://via.placeholder.com/150';
  }
}
