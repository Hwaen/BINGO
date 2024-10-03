import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hello_flutter/recipe_detail_screen.dart';
import 'package:provider/provider.dart';
import 'recipe_provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Feed extends StatefulWidget {
  const Feed({super.key});

  @override
  State<Feed> createState() => _FeedState();
}

class _FeedState extends State<Feed> {
  List<Recipe> _recommendedRecipes = [];
  bool _isLoading = true;
  bool _hasError = false;
  final DateFormat _inputDateFormat = DateFormat('yyyy.MM.dd');

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 재료를 먼저 로드
    await Provider.of<RecipeProvider>(context, listen: false)
        .loadSavedIngredients();

    // 재료가 로드된 후에 레시피 추천 API 호출
    _fetchRecommendedRecipes();
  }

  void _fetchRecommendedRecipes() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _recommendedRecipes = [];
    });

    try {
      // context가 유효한지 확인
      if (!mounted) return;

      final recipeProvider =
          Provider.of<RecipeProvider>(context, listen: false);

      // 재료 기반 추천 레시피 불러오기
      final recipes =
          await recipeProvider.recommendRecipesFromCookingIngredients();

      // 추천된 레시피가 없는 경우 랜덤 레시피를 불러옴
      if (recipes.isEmpty) {
        if (kDebugMode) {
          print("추천된 레시피가 없습니다. 랜덤 레시피를 가져옵니다.");
        }
        final randomRecipes = await recipeProvider.fetchRandomRecipes();

        setState(() {
          _recommendedRecipes = randomRecipes;
          _isLoading = false;
        });
      } else {
        setState(() {
          _recommendedRecipes = recipes; // 추천된 레시피를 상태에 저장
          _isLoading = false; // 로딩 완료
        });
      }
    } catch (e) {
      // 에러 처리
      setState(() {
        _hasError = true; // 에러 플래그 설정
        _isLoading = false; // 로딩 완료 (에러로)
      });
    }
  }

  // 중량과 특수문자를 제거하고 재료 이름만 추출하는 함수
  String _extractIngredientName(String ingredient) {
    // 중량 및 단위 제거 (예: '200g', '30ml' 등)
    final RegExp expNumbers =
        RegExp(r'\d+(\.\d+)?\s*(g|kg|ml|l|컵|티스푼|테이블스푼)?|\(\)');
    // 중량이나 단위 앞의 단어만 남김
    final cleanedIngredient = ingredient.replaceAll(expNumbers, '').trim();
    return cleanedIngredient; // 중량이 제거된 재료 이름 반환
  }

// 레시피와 냉장고 재료 비교 함수
  List<String> getMatchedIngredients(
      String recipeIngredients, List<Map<String, dynamic>> cookingIngredients) {
    DateTime now = DateTime.now(); // 현재 날짜
    final DateFormat inputDateFormat = DateFormat('yyyy.MM.dd');

// 레시피 재료에서 중량과 괄호를 제거하고 소문자로 변환하여 분해
    List<String> recipeIngredientList = recipeIngredients
        .replaceAll(RegExp(r',+'), ',') // 연속된 쉼표를 하나의 쉼표로 변경
        .split(RegExp(r'[,| ]')) // 쉼표나 공백으로 구분하여 재료 분해
        .map((ingredient) => _extractIngredientName(ingredient)
            .toLowerCase()) // 중량 및 괄호 제거 후 소문자로 변환
        .where((ingredient) => ingredient.isNotEmpty) // 빈 문자열 제거
        .toList();

    // 냉장고 재료 중 유통기한이 유효한 재료만 필터링하여 이름 리스트로 변환
    List<dynamic> fridgeIngredientNames = cookingIngredients
        .where((ingredient) {
          final expiryDate = ingredient['expiryDate'];
          if (expiryDate != null && expiryDate.isNotEmpty) {
            try {
              DateTime expiry = inputDateFormat.parse(expiryDate);
              return expiry.isAfter(now); // 유통기한이 오늘 이후인 재료만 포함
            } catch (e) {
              if (kDebugMode) {
                print('Error parsing expiry date: $e');
              }
              return false;
            }
          }
          return true; // 유통기한이 없는 재료는 포함
        })
        .map((ingredient) => ingredient['name']!.toLowerCase().trim())
        .toList();

    // 레시피 재료 중 냉장고 속 유효한 재료와 일치하는 재료를 찾기
    List<String> matchedIngredients =
        recipeIngredientList.where((recipeIngredient) {
      return fridgeIngredientNames.any((fridgeIngredient) =>
          fridgeIngredient.contains(recipeIngredient) ||
          recipeIngredient.contains(fridgeIngredient));
    }).toList();

    return matchedIngredients; // 일치하는 유효한 재료 리스트 반환
  }

// 레시피와 냉장고 속 재료 비교하여 일치하는 재료를 텍스트로 반환
  String getUsedIngredientsText(Recipe recipe, RecipeProvider recipeProvider) {
    // RecipeProvider에서 냉장고 재료 가져오기
    List<dynamic> matchedIngredients = getMatchedIngredients(
        recipe.ingredients, recipeProvider.cookingIngredients);

    // 괄호를 제거하는 처리 추가
    List<dynamic> cleanedIngredients = matchedIngredients
        .map((ingredient) => ingredient
            .replaceAll(RegExp(r'\([^)]*\)'), '')
            .trim()) // 괄호 제거 및 공백 제거
        .toList();

    if (cleanedIngredients.isNotEmpty) {
      return '냉장고 속 ${cleanedIngredients.join(', ')} 재료를 사용했어요';
    } else {
      return '냉장고 속 재료를 사용하지 않았어요';
    }
  }

  // 권장 칼로리를 SharedPreferences에서 불러오는 함수
  Future<String> getRecommendedCaloriesText() async {
    final prefs = await SharedPreferences.getInstance();
    double? recommendedCalories = prefs.getDouble('recommendedCalories');

    if (recommendedCalories != null) {
      return '내 권장 칼로리는 ${recommendedCalories.toStringAsFixed(0)}kcal 예요.';
    } else {
      return '권장 칼로리 정보가 없습니다.';
    }
  }

// 괄호와 숫자를 제거하는 함수 (변경 사항 없음)
  String _removeBrackets(String text) {
    final RegExp expBrackets = RegExp(r'\(.*?\)');
    final RegExp expNumbers =
        RegExp(r'\d+(\.\d+)?\s*(g|kg|ml|l|컵|티스푼|테이블스푼)?|\(\)');
    final cleanedText = text.replaceAll(expBrackets, '').trim();
    return cleanedText.replaceAll(expNumbers, '').trim();
  }

  Color _getExpiryColor(String expiryDate) {
    if (expiryDate.isEmpty) {
      return Colors.transparent;
    }

    DateTime expiry;
    try {
      expiry = _inputDateFormat.parse(expiryDate);
    } catch (e) {
      print('Error parsing date: $e');
      return Colors.transparent;
    }

    final now = DateTime.now();
    final difference = expiry.difference(now).inDays;

    if (difference < 0) {
      return Colors.black;
    } else if (difference <= 2) {
      return Colors.red;
    } else if (difference <= 7) {
      return Colors.orange;
    } else {
      return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipeProvider = Provider.of<RecipeProvider>(context);
    final filteredIngredients =
        recipeProvider.getExpiringOrExpiredIngredients();

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // 추천 레시피 섹션
          Text(
            '오늘은 이 메뉴 어때요?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),

          // 권장 칼로리 텍스트 고정
          FutureBuilder<String>(
            future: getRecommendedCaloriesText(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircularProgressIndicator(); // 로딩 중일 때
              } else if (snapshot.hasError) {
                return Text('권장 칼로리 정보를 불러오는데 실패했습니다.');
              } else if (snapshot.hasData) {
                return Text(
                  snapshot.data!,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ); // 권장 칼로리 텍스트 표시
              } else {
                return SizedBox.shrink(); // 데이터가 없을 때 빈 공간
              }
            },
          ),
          SizedBox(height: 10),

          // 레시피 슬라이드 섹션
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _hasError
                  ? Center(child: Text('추천 레시피 로드 실패.'))
                  : _recommendedRecipes.isNotEmpty
                      ? SizedBox(
                          height: 230, // 높이 조정
                          child: PageView.builder(
                            itemCount: _recommendedRecipes.length,
                            itemBuilder: (context, index) {
                              final recipe = _recommendedRecipes[index];
                              final recipeProvider =
                                  Provider.of<RecipeProvider>(context,
                                      listen: false);
                              final bool isSaved = recipeProvider.savedRecipes
                                  .any((r) => r.id == recipe.id);

                              // ATT_FILE_NO_MK 값이 없거나 잘못된 경우 기본 이미지로 처리
                              String imageUrl = recipe.imageUrl.isNotEmpty
                                  ? recipe.imageUrl
                                  : 'https://example.com/default_image.jpg';

                              // 레시피에 사용된 냉장고 속 재료 텍스트
                              String usedIngredientsText =
                                  getUsedIngredientsText(
                                      recipe, recipeProvider);

                              return GestureDetector(
                                onTap: () {
                                  // 레시피 클릭 시 RecipeDetailScreen으로 이동
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RecipeDetailScreen(
                                        recipe: recipe,
                                      ),
                                    ),
                                  );
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.network(
                                            imageUrl,
                                            width: 90, // 이미지 너비
                                            height: 90, // 이미지 높이
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Container(
                                                width: 90,
                                                height: 90,
                                                color: Colors.grey[300],
                                                child: Center(
                                                  child: Icon(Icons.error,
                                                      color: Colors.red),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                recipe.title,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                recipe.category,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                _removeBrackets(recipe.tip),
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                '음식 칼로리: ${recipe.description}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // 하트 아이콘 버튼 추가
                                        IconButton(
                                          icon: Icon(
                                            isSaved
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            color: isSaved
                                                ? Colors.red
                                                : Colors.grey,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              if (isSaved) {
                                                recipeProvider.removeRecipe(
                                                    recipe.id); // Recipe 객체 삭제
                                              } else {
                                                recipeProvider.saveRecipe(
                                                    recipe); // Recipe 객체 저장
                                              }
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    // 각 레시피에 사용된 냉장고 속 재료 표시
                                    Text(
                                      usedIngredientsText,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        )
                      : Center(child: Text('추천 레시피가 없습니다.')),

          SizedBox(height: 20),

          // 유통기한 임박 재료 섹션
          Text(
            '빨리 먹으면 좋아요!',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          ...filteredIngredients.map((ingredient) {
            final expiryColor = _getExpiryColor(ingredient['expiryDate'] ?? '');
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Image.network(
                        ingredient['image'] ?? '',
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 90,
                            height: 90,
                            color: Colors.grey[300],
                            child: Center(
                              child: Icon(Icons.error, color: Colors.red),
                            ),
                          );
                        },
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: expiryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ingredient['name'] ?? '',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '유통기한: ${ingredient['expiryDate']}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                      if (expiryColor == Colors.red)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            '유통기한이 임박해요',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (expiryColor == Colors.black)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            '유통기한이 지났어요',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }
}
