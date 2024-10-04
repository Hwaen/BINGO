// 핵심 코드

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

import 'recipe_service.dart';

class Recipe {
  final String id;
  final String title;
  final String imageUrl;
  final String imageUrl2;
  final String ingredients;
  final String description;
  final String type;
  final List<Map<String, dynamic>> manualSteps;  
  final String tip;
  final String category;
  final double energy;
  final bool heart;

  Recipe({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.imageUrl2,
    required this.ingredients,
    required this.description,
    required this.type,
    required this.manualSteps,
    required this.tip,
    required this.category,
    required this.energy,
    required this.heart

  });

  get expiryDate => null;

  // JSON 변환 메서드
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'imageUrl': imageUrl,
        'imageUrl2': imageUrl2,
        'ingredients': ingredients,
        'description': description,
        'type': type,
        'manualSteps': manualSteps.map((step) => step).toList(),
        'tip': tip,
        'category': category,
        'energy' : energy,
        'heart' : false,
      };

  static Recipe fromJson(Map<String, dynamic> json) => Recipe(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        imageUrl: json['imageUrl'] ?? '',
        imageUrl2: json['imageUrl2'] ?? '',
        ingredients: json['ingredients'] ?? '',
        description: json['description'] ?? '',
        type: json['type'] ?? '',
        manualSteps: (json['manualSteps'] as List<dynamic>? ?? [])
            .map((e) => e as Map<String, dynamic>)
            .toList(),        
        tip: json['tip'] ?? '',
        category: json['category'] ?? '',
        energy: json['energy'] ?? '',
        heart: json['heart'] ?? ''
      );
}

class RecipeProvider with ChangeNotifier {
  Timer? _midnightTimer;
  final List<Map<String, dynamic>> _ingredients = [];

  final List<Map<String, dynamic>> _cookingIngredients = []; // 요리 가능한 재료
  final List<Map<String, dynamic>> _nonCookingIngredients = []; // 보관 가능한 재료
  final RecipeService recipeService = RecipeService(); // RecipeService 인스턴스

  List<Map<String, dynamic>> get cookingIngredients => _cookingIngredients;
  List<Map<String, dynamic>> get nonCookingIngredients => _nonCookingIngredients;

  RecipeProvider() {
    loadSavedIngredients(); // 앱 시작 시 저장된 재료 목록 불러오기
    loadSavedRecipes(); // 저장된 추천 레시피 불러오기
    _scheduleMidnightRefresh(); // 자정 갱신 스케줄링
  }

  void _scheduleMidnightRefresh() {
    // 현재 시간
    DateTime now = DateTime.now();

    // 자정 시간 계산
    DateTime nextMidnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 0);
    Duration timeUntilMidnight = nextMidnight.difference(now);

    // 자정까지 남은 시간 동안 타이머 설정
    _midnightTimer?.cancel(); // 기존 타이머가 있으면 취소
    _midnightTimer = Timer(timeUntilMidnight, () {
      recommendRecipesFromCookingIngredients(); // 자정에 레시피 갱신
      _scheduleMidnightRefresh(); // 다음 자정을 위해 다시 타이머 설정
    });

    // 타이머가 제대로 설정되었는지 확인하는 로그 출력
    if (kDebugMode) {
      print('자정 갱신 타이머가 설정되었습니다. 남은 시간: $timeUntilMidnight');
    }
  }

  // 레시피와 냉장고 재료 비교 함수
  List<String> getMatchedIngredients(String recipeIngredients) {
    List<String> recipeIngredientList = recipeIngredients
        .split(',') // 쉼표로 구분하여 재료 분해
        .map((ingredient) => ingredient.trim().toLowerCase()) // 소문자로 변환 및 공백 제거
        .toList();

    List<dynamic> fridgeIngredientNames = _cookingIngredients
        .map((ingredient) =>
            ingredient['name']!.toLowerCase().trim()) // 냉장고 재료 이름 변환
        .toList();

    // 레시피에 사용된 재료 중 냉장고 속 재료와 일치하는 재료를 찾기
    List<String> matchedIngredients = recipeIngredientList
        .where((ingredient) => fridgeIngredientNames.contains(ingredient))
        .toList();

    return matchedIngredients; // 일치하는 재료 리스트 반환
  }

  // 재료 추가 메서드
  void addIngredient(Map<String, dynamic> ingredient, bool isCooking) async {
    ingredient['isCooking'] = isCooking ? 'true' : 'false'; // isCooking 값 추가

    _ingredients.add(ingredient);

    if (isCooking) {
      _cookingIngredients.add(ingredient);
    } else {
      _nonCookingIngredients.add(ingredient);
    }

    // SharedPreferences에 재료 저장
    final prefs = await SharedPreferences.getInstance();
    List<String> savedIngredients =
        prefs.getStringList('saved_ingredients') ?? [];
    savedIngredients.add(jsonEncode(ingredient)); // 재료를 JSON으로 인코딩하여 추가

    // 저장되는 데이터를 로그로 출력하여 확인
    if (kDebugMode) {
      print('저장된 재료 목록: $savedIngredients');
    }

    await prefs.setStringList(
        'saved_ingredients', savedIngredients); // 업데이트된 재료 목록 저장

    notifyListeners(); // 변경 사항을 알림
  }

  // 재료 업데이트 메서드
  void updateIngredient(
      int index, Map<String, String> updatedIngredient, bool isCooking) {
    _ingredients[index] = updatedIngredient;
    _saveIngredients(); // 재료 목록 저장
    notifyListeners();
    loadSavedIngredients();
  }

  // 재료 목록 반환
  List<Map<String, dynamic>> getIngredients() {
    return _ingredients;
  }

  // 유통기한이 임박하거나 지난 재료 반환
  List<Map<String, dynamic>> getExpiringOrExpiredIngredients() {
    final DateFormat inputDateFormat = DateFormat('yyyy.MM.dd');
    DateTime now = DateTime.now();
    return _ingredients.where((ingredient) {
      final expiryDate = ingredient['expiryDate'];
      if (expiryDate == null || expiryDate.isEmpty) {
        return false;
      }

      DateTime expiry;
      try {
        expiry = inputDateFormat.parse(expiryDate);
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing date: $e');
        }
        return false;
      }

      final difference = expiry.difference(now).inDays;
      return difference < 0 || difference <= 2;
    }).toList();
  }

  // 재료 삭제 메서드
  void removeIngredient(int index) {
    _ingredients.removeAt(index);
    _saveIngredients(); // 재료 목록 저장
    notifyListeners();
    loadSavedIngredients();
  }

  // 재료 목록을 SharedPreferences에 저장
  void _saveIngredients() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> ingredientList =
        _ingredients.map((ingredient) => jsonEncode(ingredient)).toList();
    await prefs.setStringList('saved_ingredients', ingredientList);
  }

  // SharedPreferences에서 저장된 재료 목록 불러오기
  Future<void> loadSavedIngredients() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? savedIngredients =
        prefs.getStringList('saved_ingredients');

    if (savedIngredients != null) {
      _ingredients.clear();
      _cookingIngredients.clear();
      _nonCookingIngredients.clear();

      for (var ingredientJson in savedIngredients) {
        Map<String, String> ingredient =
            Map<String, String>.from(jsonDecode(ingredientJson));
        _ingredients.add(ingredient);

        // 불러온 재료 출력
        if (kDebugMode) {
          print('불러온 재료: $ingredient');
        }

        // storage 필드를 통해 요리 가능한 재료와 보관 가능한 재료를 분리
        if (ingredient['storage'] == '요리 가능 재료') {
          _cookingIngredients.add(ingredient);
        } else {
          _nonCookingIngredients.add(ingredient);
        }
      }

      // 요리 가능한 재료 출력
      if (kDebugMode) {
        print('요리 가능한 재료: $_cookingIngredients');
      }

      notifyListeners(); // 변경 사항 알림
    }
  }

  Future<void> loadSavedRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? savedRecipesJson = prefs.getStringList('saved_recipes');

    if (savedRecipesJson != null) {
      _savedRecipes.clear(); // 기존 저장된 레시피 목록을 초기화
      _savedRecipes.addAll(savedRecipesJson.map((recipeJson) {
        return Recipe.fromJson(jsonDecode(recipeJson));
      }).toList());

      notifyListeners(); // UI 업데이트를 위한 알림
    }
  }

  final List<Recipe> _savedRecipes = [];

  List<Recipe> get savedRecipes => _savedRecipes;

  // 레시피 저장 및 불러오는 메서드는 기존과 동일하게 유지
  void saveRecipe(Recipe recipe) async {
    _savedRecipes.add(recipe);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList(
      'saved_recipes',
      _savedRecipes.map((recipe) => jsonEncode(recipe.toMap())).toList(),
    );
  }

  void removeRecipe(String id) async {
    _savedRecipes.removeWhere((r) => r.id == id);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList(
      'saved_recipes',
      _savedRecipes.map((recipe) => jsonEncode(recipe.toMap())).toList(),
    );
  }

  // recipe_service에서 랜덤 레시피를 가져오는 함수
  Future<List<Recipe>> fetchRandomRecipes() async {
    try {
      // 여기에 recipe_service를 통해 레시피 데이터를 가져오는 로직 추가
      List<Recipe> randomRecipes = await fetchRandomRecipes();
      return randomRecipes;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching random recipes: $e');
      }
      return [];
    }
  }

  Future<List<Recipe>> recommendRecipesFromCookingIngredients() async {
    // 현재 날짜 가져오기
    DateTime now = DateTime.now();

    // 유통기한이 오늘 이전인 재료를 제외한 요리 가능한 재료 목록을 가져오기
    List<Map<String, dynamic>> availableIngredients =
        _cookingIngredients.where((ingredient) {
      final expiryDate = ingredient['expiryDate'];
      if (expiryDate != null && expiryDate.isNotEmpty) {
        DateTime expiry;
        try {
          expiry = DateFormat('yyyy.MM.dd').parse(expiryDate);
        } catch (e) {
          print('Error parsing expiry date: $e');
          return false;
        }
        // 유통기한이 오늘 이후인 재료만 사용
        return expiry.isAfter(now);
      }
      return true; // 유통기한이 없는 재료는 사용
    }).toList();

    // 1. 요리 가능 재료 목록 안에 있는 재료들로 레시피 추출
    List<Recipe> recipes =
        await _searchRecipesWithIngredients(availableIngredients);
    List<Recipe> prioritizedRecipes = _prioritizeRecipesByCategory(recipes);

    // 3개 미만이라도 추출
    if (prioritizedRecipes.isNotEmpty) {
      return prioritizedRecipes.take(3).toList(); // 3개 이하일 경우 그대로 반환
    }

    // 1.5. 저장된 권장 칼로리를 기준으로 레시피 추출
    final prefs = await SharedPreferences.getInstance();
    final double? recommendedCalories = prefs.getDouble('recommendedCalories');

    if (recommendedCalories != null) {
      // 권장 칼로리의 3분의 1 값 ± 100kcal 범위
      double targetCalories = recommendedCalories / 3;
      double minCalories = targetCalories - 100;
      double maxCalories = targetCalories + 100;

      // 해당 범위에 맞는 레시피 추출
      List<Recipe> calorieFilteredRecipes = recipes.where((recipe) {
        double recipeCalories = double.tryParse(recipe.description) ?? 0;
        return recipeCalories >= minCalories && recipeCalories <= maxCalories;
      }).toList();

      List<Recipe> prioritizedCalorieRecipes =
          _prioritizeRecipesByCategory(calorieFilteredRecipes);
      if (prioritizedCalorieRecipes.isNotEmpty) {
        return prioritizedCalorieRecipes.take(3).toList(); // 3개 이하라도 반환
      }
    }

    // 2. 유통기한 기준으로 재료를 하나씩 제거하며 레시피 추출
    for (int i = availableIngredients.length - 1; i >= 0; i--) {
      List<Map<String, dynamic>> reducedIngredients =
          availableIngredients.sublist(0, i);
      List<Recipe> reducedRecipes =
          await _searchRecipesWithIngredients(reducedIngredients);
      List<Recipe> prioritizedReducedRecipes =
          _prioritizeRecipesByCategory(reducedRecipes);

      if (prioritizedReducedRecipes.isNotEmpty) {
        return prioritizedReducedRecipes.take(3).toList(); // 3개 이하라도 반환
      }
    }

    // 3. 추천된 레시피가 없을 경우 랜덤 레시피 추출
    if (prioritizedRecipes.isEmpty) {
      if (kDebugMode) {
        print("추천 레시피가 없으므로 랜덤 레시피를 가져옵니다.");
      }

      // Stack Overflow를 방지하기 위해 재귀적으로 호출하지 않도록 수정
      try {
        List<Recipe> randomRecipes = await recipeService.randomRecipes();
        return randomRecipes.take(3).toList(); // 3개 이하라도 반환
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching random recipes: $e');
        }
        return []; // 오류 시 빈 리스트 반환
      }
    }

    return prioritizedRecipes.take(3).toList(); // 최종적으로 3개 이하라도 반환
  }
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
        rcpShow.where((r) => r.category == "국" || r.category == "찌개").isEmpty) {
      rcpShow.add(rcpStew.removeAt(0));
    }
    // 밥/일품을 1개 이하로 선택
    else if (rcpDish.isNotEmpty &&
        rcpShow.where((r) => r.category == "밥" || r.category == "일품").isEmpty) {
      rcpShow.add(rcpDish.removeAt(0));
    }

    // 더 이상 선택할 수 있는 레시피가 없을 경우 루프 탈출
    if (rcpSub.isEmpty && rcpStew.isEmpty && rcpDish.isEmpty) {
      break;
    }
  }

  return rcpShow;
}

// 재료를 가지고 레시피 검색
Future<List<Recipe>> _searchRecipesWithIngredients(
    List<Map<String, dynamic>> ingredients) async {
  if (ingredients.isEmpty) return [];

  List<dynamic> ingredientNames = ingredients
      .map((ingredient) => ingredient['name']!.toLowerCase().trim())
      .toList();

  if (kDebugMode) {
    print('사용할 재료로 레시피 검색 중: $ingredientNames');
  }

  List<Recipe> allRecipes = [];
  List<dynamic> recipeData = await searchRecipe(ingredientNames);

  allRecipes = recipeData
      .map((data) {
        if (data is Map<String, dynamic>) {
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
          return Recipe.fromJson({
            'id': data['RCP_SEQ'] ?? '',
            'title': data['RCP_NM'] ?? '',
            'imageUrl': data['ATT_FILE_NO_MAIN'] ?? '',
            'ingredients': data['RCP_PARTS_DTLS'] ?? '',
            'imageUrl2': data['ATT_FILE_NO_MK'] ?? '',
            'description': data['INFO_NA'] ?? '',
            'type': data['RCP_PAT2'] ?? '',
            'manualSteps': manualSteps,
            'tip': data['RCP_NA_TIP'] ?? '',
            'category': data['RCP_PAT2'] ?? '',
            'energy' : data['INFO_ENG'] ?? '',
            'heart' : false
          });
        } else {
          return null;
        }
      })
      .where((recipe) => recipe != null)
      .cast<Recipe>()
      .toList();

  return allRecipes;
}

Future<List<Map<String, dynamic>>> searchRecipe(
    List<dynamic> ingredients) async {
  String apiKey = dotenv.get('RCP_apikey');
  String link = "https://openapi.foodsafetykorea.go.kr/api/";
  String serviceId = "COOKRCP01";
  String dataType = "json";
  String startIdx = "1";
  String endIdx = "1000"; // 대량의 데이터를 요청할 경우 1000으로 설정

  // 재료를 URL 인코딩하여 쉼표로 구분
  String combinedIngredients = ingredients.map((ing) {
    return Uri.encodeComponent(ing);
  }).join(',');

  // 최종 URL 구성
  final response = await http.get(Uri.parse(
      '$link$apiKey/$serviceId/$dataType/$startIdx/$endIdx/RCP_PARTS_DTLS=$combinedIngredients'));

  // 응답 처리
  if (response.statusCode == 200) {
    final jsonData = json.decode(response.body);
    String resultCode = jsonData['COOKRCP01']['RESULT']['CODE'];

    // 로그 추가: API 응답 데이터 확인
    if (kDebugMode) {
      print("API 응답 코드: $resultCode");
      print("API 응답 데이터: ${jsonData['COOKRCP01']['row']}");
    }

    if (resultCode == "INFO-000") {
      List<Map<String, dynamic>> recipes = [];

      for (var item in jsonData['COOKRCP01']['row']) {
        Map<String, dynamic> recipe = {
          'RCP_SEQ': item['RCP_SEQ'],
          'RCP_NM': item['RCP_NM'],
          'RCP_WAY2': item['RCP_WAY2'],
          'RCP_PAT2': item['RCP_PAT2'],
          'INFO_WGT': item['INFO_WGT'],
          'INFO_ENG': item['INFO_ENG'],
          'INFO_CAR': item['INFO_CAR'],
          'INFO_PRO': item['INFO_PRO'],
          'INFO_FAT': item['INFO_FAT'],
          'INFO_NA': item['INFO_NA'],
          'HASH_TAG': item['HASH_TAG'],
          'ATT_FILE_NO_MAIN': item['ATT_FILE_NO_MAIN'],
          'ATT_FILE_NO_MK': item['ATT_FILE_NO_MK'],
          'RCP_PARTS_DTLS': item['RCP_PARTS_DTLS'],
        };

        // 조리법 관련 필드 추가
        for (int i = 1; i <= 20; i++) {
          String manualKey = 'MANUAL0$i';
          String manualImgKey = 'MANUAL_IMG0$i';
          if (item[manualKey] != null) {
            recipe[manualKey] = item[manualKey];
          }
          if (item[manualImgKey] != null) {
            recipe[manualImgKey] = item[manualImgKey];
          }
        }

        // 저감 조리법 TIP 추가
        recipe['RCP_NA_TIP'] = item['RCP_NA_TIP'];

        recipes.add(recipe);
      }

      return recipes; // 성공 시 레시피 데이터 반환
    } else {
      if (kDebugMode) {
        print("API Error: ${jsonData['COOKRCP01']['RESULT']['MESSAGE']}");
      }
      return []; // 오류 발생 시 빈 리스트 반환
    }
  } else {
    if (kDebugMode) {
      print("Failed to fetch recipes: ${response.statusCode}");
    }
    return []; // HTTP 오류 발생 시 빈 리스트 반환
  }
}
