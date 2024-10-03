//랜덤 추천 레시피

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'recipe_provider.dart'; // Recipe 클래스 사용

class RecipeService {
  final String apiKey = dotenv.get('RCP_apikey');
  final String serviceId = 'COOKRCP01';
  final String dataType = 'json';
  final int startIdx = 1;
  final int endIdx = 1000; // 1000개 정도 가져와서 랜덤으로 선택

  // 카테고리별 및 칼로리 범위를 고려한 랜덤 레시피 가져오기
  Future<List<Recipe>> randomRecipes() async {
    // 권장 칼로리 값 불러오기
    final prefs = await SharedPreferences.getInstance();
    final double? recommendedCalories = prefs.getDouble('recommendedCalories');

    if (recommendedCalories == null) {
      throw Exception('권장 칼로리 값이 설정되지 않았습니다.');
    }

    // 권장 칼로리의 1/3 값 ± 100kcal 범위
    double targetCalories = recommendedCalories / 3;
    double minCalories = targetCalories - 100;
    double maxCalories = targetCalories + 100;

    List<String> categories = ["반찬", "국", "밥"]; // 카테고리 리스트
    List<Recipe> allRecipes = [];

    for (String category in categories) {
      try {
        final String url =
            'http://openapi.foodsafetykorea.go.kr/api/$apiKey/$serviceId/$dataType/$startIdx/$endIdx';

        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List<dynamic> recipes = data['COOKRCP01']['row'];

          if (recipes.isNotEmpty) {
            // 카테고리 및 칼로리 범위에 맞는 레시피 필터링
            final filteredRecipes = recipes.where((recipe) {
              double recipeCalories = double.tryParse(recipe['INFO_ENG']) ?? 0;
              return recipe['RCP_PAT2'] == category &&
                  recipeCalories >= minCalories &&
                  recipeCalories <= maxCalories;
            }).toList();

            // 필터링된 레시피를 Recipe 객체로 변환
            allRecipes.addAll(filteredRecipes
                .map((data) {
                  List<Map<String, dynamic>> manualSteps = [];
                  for (int i = 1; i <= 20; i++) {
                    String stepKey = 'MANUAL0$i';
                    String imgKey = 'MANUAL_IMG0$i'; // 이미지 키
                    if (data[stepKey] != null) {
                      manualSteps.add({
                        'step': data[stepKey],
                        'image': data[imgKey] ?? '', // 이미지가 없을 경우 빈 문자열
                      });
                    }
                  }
                  return Recipe(
                    id: data['RCP_SEQ'] ?? '',
                    title: data['RCP_NM'] ?? '',
                    imageUrl: data['ATT_FILE_NO_MAIN'] ?? '',
                    imageUrl2: data['ATT_FILE_NO_MK'] ?? '',
                    ingredients: data['RCP_PARTS_DTLS'] ?? '',
                    description: data['INFO_ENG'] ?? '',
                    type: data[''] ?? '',
                    manualSteps: manualSteps,                    
                    tip: data['RCP_NA_TIP'] ?? '',
                    category: data['RCP_PAT2'] ?? '',
                    energy: data[''] ?? '',
                    heart: false
                  );
                })
                .cast<Recipe>()
                .toList()); // Recipe 타입으로 캐스팅
          }
        } else {
          print('Failed to load recipes. HTTP Status: ${response.statusCode}');
        }
      } catch (e) {
        print('Error fetching recipes for category $category: $e');
      }
    }

    // 카테고리 우선순위대로 최대 3개의 레시피 선택
    return _prioritizeRecipesByCategory(allRecipes);
  }

  List<Recipe> _prioritizeRecipesByCategory(List<Recipe> recipes) {
    List<Recipe> rcpSub = []; // 반찬 메뉴
    List<Recipe> rcpStew = []; // 국/찌개 메뉴
    List<Recipe> rcpDish = []; // 밥/일품 메뉴
    List<Recipe> rcpShow = []; // 최종 보여줄 레시피

    // 레시피를 카테고리별로 분류
    for (var recipe in recipes) {
      if (recipe.category == "반찬") {
        rcpSub.add(recipe);
      } else if (recipe.category == "국" || recipe.category == "찌개") {
        rcpStew.add(recipe);
      } else if (recipe.category == "밥" || recipe.category == "일품") {
        rcpDish.add(recipe);
      }
    }

    // 우선순위에 따라 최대 3개의 레시피를 선택
    // 밥 < 국/찌개 < 반찬 순으로 우선순위 적용
    while (rcpShow.length < 3) {
      // 반찬 우선 선택
      if (rcpSub.isNotEmpty &&
          (rcpShow.where((r) => r.category == "반찬").length < 2 ||
              rcpStew.isEmpty && rcpDish.isEmpty)) {
        rcpShow.add(rcpSub.removeAt(0));
      }
      // 국/찌개가 1개 이하인 경우 선택
      else if (rcpStew.isNotEmpty &&
          rcpShow
              .where((r) => r.category == "국" || r.category == "찌개")
              .isEmpty) {
        rcpShow.add(rcpStew.removeAt(0));
      }
      // 밥/일품을 1개 이하로 선택
      else if (rcpDish.isNotEmpty &&
          rcpShow
              .where((r) => r.category == "밥" || r.category == "일품")
              .isEmpty) {
        rcpShow.add(rcpDish.removeAt(0));
      }

      // 더 이상 선택할 수 있는 레시피가 없을 경우 루프 탈출
      if (rcpSub.isEmpty && rcpStew.isEmpty && rcpDish.isEmpty) {
        break;
      }
    }

    return rcpShow.take(3).toList(); // 최대 3개의 레시피 반환
  }
}
