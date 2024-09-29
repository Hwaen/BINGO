import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hello_flutter/recipe_detail_screen.dart';
import 'package:provider/provider.dart';
import 'recipe_provider.dart';
import 'recipe_detail_page.dart';
import 'package:intl/intl.dart';

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

    // initState에서 context 사용을 위한 처리
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchRecommendedRecipes();
    });
  }

  void _fetchRecommendedRecipes() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _recommendedRecipes = [];
    });

    try {
      final recipeProvider =
          Provider.of<RecipeProvider>(context, listen: false);
      final recipes =
          await recipeProvider.recommendRecipesFromCookingIngredients();

      if (recipes.isEmpty) {
        throw Exception("추천할 레시피가 없습니다.");
      }

      // 로드된 레시피 출력
      if (kDebugMode) {
        print("로드된 레시피 목록:");
        for (var recipe in recipes) {
          print(
              "레시피 ID: ${recipe.id}, 이름: ${recipe.title}, 이미지: ${recipe.imageUrl}, 재료: ${recipe.ingredients}");
        }
      }

      setState(() {
        _recommendedRecipes = recipes; // 이미 Recipe 객체의 리스트라면 그냥 대입
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print("레시피 로드 오류: $e");
      }
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  String _removeBrackets(String text) {
    final RegExp expBrackets = RegExp(r'\(.*?\)');
    final RegExp expNumbers = RegExp(r'\d+(\.\d+)?\s*(g|kg|ml|l|컵|티스푼|테이블스푼)?');
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
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _hasError
                  ? Center(child: Text('추천 레시피 로드 실패.'))
                  : _recommendedRecipes.isNotEmpty
                      ? SizedBox(
                          height: 180, // 높이 조정
                          child: PageView.builder(
                            itemCount: _recommendedRecipes.length,
                            itemBuilder: (context, index) {
                              final recipe = _recommendedRecipes[index];

                              // ATT_FILE_NO_MK 값이 없거나 잘못된 경우 기본 이미지로 처리
                              String imageUrl = recipe.imageUrl.isNotEmpty
                                  ? recipe.imageUrl
                                  : 'https://example.com/default_image.jpg';

                              return GestureDetector(
                                onTap: () {
                                  // 레시피 클릭 시 RecipeDetailScreen으로 이동
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RecipeDetailScreen(
                                        recipe:
                                            recipe, // recipe를 RecipeDetailScreen의 인자로 전달
                                      ),
                                    ),
                                  );
                                },
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
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
                                          // 카테고리 추가
                                          Text(
                                            recipe.category, // 카테고리 정보 추가
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.black),
                                          ),
                                          SizedBox(height: 4), // 여백 추가
                                          // 수정된 부분: _removeBrackets 적용
                                          Text(
                                            _removeBrackets(recipe.ingredients),
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          SizedBox(height: 4), // 여백 추가
                                          // 칼로리 정보 추가
                                          Text(
                                            '음식 칼로리: ${recipe.description}', // 칼로리 정보 표시
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ],
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
