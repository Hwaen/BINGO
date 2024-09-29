import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'myfridge_page.dart';
import 'database_seviece.dart';

class Recipe {
  final String id;
  final String title;
  final String imageUrl;
  final String imageUrl2;
  final String description;
  final List<Map<String, dynamic>> manualSteps;
  final String ingredients;
  final String tip;
  final String category;

  Recipe({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.imageUrl2,
    required this.description,
    required this.manualSteps,
    required this.ingredients,
    required this.tip,
    required this.category,
  });

  get expiryDate => null;

  Map<String, dynamic> toMap(){
    return{
        'id': id,
        'title': title,
        'imageUrl': imageUrl,
        'imageUrl2': imageUrl2,
        'description': description,
        'manualSteps': manualSteps,
            // .map((step) => step)
            // .toList(), // List<Map<String, dynamic>> 형식으로 변환
        'ingredients': ingredients,
        'tip': tip,
        'category': category,
    };
  }


  // JSON 변환 메서드
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'imageUrl': imageUrl,
        'imageUrl2': imageUrl2,
        'description': description,
        'manualSteps': manualSteps.map((step) => step).toList(),
        'ingredients': ingredients,
        'tip': tip,
        'category': category,
      };

  static Recipe fromJson(Map<String, dynamic> json) => Recipe(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        imageUrl: json['imageUrl'] ?? '',
        imageUrl2: json['imageUrl2'] ?? '',
        description: json['description'] ?? '',
        manualSteps: (json['manualSteps'] as List<dynamic>? ?? [])
            .map((e) => e as Map<String, dynamic>)
            .toList(),
        ingredients: json['ingredients'] ?? '',
        tip: json['tip'] ?? '',
        category: json['category'] ?? '',
      );
}

class RecipeProvider extends Database_BINGO with ChangeNotifier {
  //final List<Map<String, String>> _ingredients = [];
  final List<Ingredient> _ingredient = [];

  final List<Map<String, dynamic>> _cookingIngredients = []; // 요리 가능한 재료
  final List<Map<String, dynamic>> _nonCookingIngredients = []; // 보관 가능한 재료

  List<Map<String, dynamic>> get cookingIngredients => _cookingIngredients;
  List<Map<String, dynamic>> get nonCookingIngredients => _nonCookingIngredients;

  RecipeProvider() {
    _loadSavedIngredients(); // 앱 시작 시 저장된 재료 목록 불러오기
  }

  // 재료 추가 메서드
  void addIngredient(Ingredient ingredient /*Map<String, dynamic> ingredient*/, bool isCooking) {
    //_ingredients.add(ingredient); // 모든 재료를 _ingredients에 추가
    
    if (isCooking) {
      //_cookingIngredients.add(ingredient.toMap());

      ingredient.storageType = 1;
      insert_ingredient(ingredient);   
    } else {
      //_nonCookingIngredients.add(ingredient);

      ingredient.storageType = 0;
      insert_ingredient(ingredient);
    }
    //_saveIngredients(); // 재료 목록 저장
    notifyListeners();
  }

  // 재료 업데이트 메서드
  void updateIngredient( Ingredient updatedIngredient, /*int index, Map<String, String> updatedIngredient, bool isCooking*/) {
    //_ingredients[index] = updatedIngredient;
    updateIngredient(updatedIngredient);
   
    //_saveIngredients(); // 재료 목록 저장
    notifyListeners();
  }

  // 재료 목록 반환  => database의 selectingredient 사용
  // List<Map<String, String>> getIngredients() {
  //   return _ingredients;
  // }

  // 유통기한이 임박하거나 지난 재료 반환
  List<Map<String, String>> getExpiringOrExpiredIngredients() {
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
        print('Error parsing date: $e');
        return false;
      }

      final difference = expiry.difference(now).inDays;
      return difference < 0 || difference <= 2;
    }).toList();
  }

  // 재료 삭제 메서드 => deleteingredient 사용
  // void removeIngredient(int index) {
  //   _ingredients.removeAt(index);
  //   //_saveIngredients(); // 재료 목록 저장
  //   notifyListeners();
  // }


  // 재료 목록을 SharedPreferences에 저장
  // void _saveIngredients() async {
    
  //   final prefs = await SharedPreferences.getInstance();
  //   final List<String> ingredientList =
  //       _ingredients.map((ingredient) => jsonEncode(ingredient)).toList();
  //   await prefs.setStringList('saved_ingredients', ingredientList);

  // }


  // SharedPreferences에서 저장된 재료 목록 불러오기
  void _loadSavedIngredients() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? savedIngredients =
        prefs.getStringList('saved_ingredients');
    if (savedIngredients != null) {
      _ingredients.clear();
      _ingredients.addAll(savedIngredients
          .map((ingredientJson) =>
              Map<String, String>.from(jsonDecode(ingredientJson)))
          .toList());
      notifyListeners();
    }
  }

  List<Recipe> _savedRecipes = [];

  List<Recipe> get savedRecipes => _savedRecipes;

  // 레시피 저장 및 불러오는 메서드는 기존과 동일하게 유지
  void saveRecipe(Recipe recipe) async {
    _savedRecipes.add(recipe);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList(
      'saved_recipes',
      _savedRecipes.map((recipe) => jsonEncode(recipe.toJson())).toList(),
    );
  }

  void removeRecipe(String id) async {
    _savedRecipes.removeWhere((r) => r.id == id);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList(
      'saved_recipes',
      _savedRecipes.map((recipe) => jsonEncode(recipe.toJson())).toList(),
    );
  }

  Future<List<Recipe>> recommendRecipesFromCookingIngredients() async {
   
    List<Map<String, String>> availableIngredients = [
      // 요리 가능한 재료 목록을 강제
      // {'name': '양파', 'expiryDate': '2024.09.27'},
      // {'name': '당근', 'expiryDate': '2024.09.28'}
    ];

    // 유통기한에 따른 재료 색상 분류
    List<Map<String, String>> redIngredients = [];
    List<Map<String, String>> yellowIngredients = [];
    List<Map<String, String>> greenIngredients = [];

    for (var ingredient in availableIngredients) {
      final expiryDate = ingredient['expiryDate'];
      if (expiryDate != null && expiryDate.isNotEmpty) {
        DateTime now = DateTime.now();
        final difference =
            DateFormat('yyyy.MM.dd').parse(expiryDate).difference(now).inDays;

        if (difference <= 2) {
          redIngredients.add(ingredient);
        } else if (difference <= 7) {
          yellowIngredients.add(ingredient);
        } else {
          greenIngredients.add(ingredient);
        }
      } else {
        greenIngredients.add(ingredient); // 유통기한 없는 재료는 초록색으로 처리
      }
    }

    // 빨간색 재료 함께 검색
    List<Recipe> allRecipes =
        await _searchRecipesWithIngredients(redIngredients);

    // 빨간색 재료에서 레시피가 없을 경우, 각각의 재료를 하나씩 제거하면서 검색
    if (allRecipes.isEmpty) {
      allRecipes = await _searchRecipesWithReducedIngredients(redIngredients);
    }

    // 노란색 재료 검색 (빨간색으로 검색된 레시피가 없을 때)
    if (allRecipes.isEmpty) {
      allRecipes = await _searchRecipesWithIngredients(yellowIngredients);
      if (allRecipes.isEmpty) {
        allRecipes =
            await _searchRecipesWithReducedIngredients(yellowIngredients);
      }
    }

    // 초록색 재료 검색 (빨간색/노란색으로 검색된 레시피가 없을 때)
    if (allRecipes.isEmpty) {
      allRecipes = await _searchRecipesWithIngredients(greenIngredients);
      if (allRecipes.isEmpty) {
        allRecipes =
            await _searchRecipesWithReducedIngredients(greenIngredients);
      }
    }

    return allRecipes.take(3).toList(); // 최대 3개의 레시피만 반환
  }

  Future<List<Recipe>> _searchRecipesWithIngredients(List<Map<String, String>> ingredients) async {
    if (ingredients.isEmpty) return [];

    // 재료 이름만 추출하여 리스트 생성 (소문자로 변환)
    List<String> ingredientNames = ingredients
        .map((ingredient) => ingredient['name']!.toLowerCase().trim())
        .toList();

    List<Recipe> allRecipes = [];
    List<dynamic> recipeData = await searchRecipe(ingredientNames);

    // 레시피 데이터 변환
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
              'imageUrl2': data['ATT_FILE_NO_MK'] ?? '',
              'description': data['INFO_NA'] ?? '',
              'manualSteps': manualSteps,
              'ingredients': data['RCP_PARTS_DTLS'] ?? '',
              'tip': data['RCP_NA_TIP'] ?? '',
              'category': data['RCP_PAT2'] ?? '',
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

// 재료를 하나씩 줄여가며 검색
  Future<List<Recipe>> _searchRecipesWithReducedIngredients(
      List<Map<String, String>> ingredients) async {
    List<Recipe> allRecipes = [];

    if (ingredients.length > 1) {
      for (int i = ingredients.length - 1; i >= 1; i--) {
        // 재료를 하나씩 줄여가면서 검색
        List<Map<String, String>> reducedIngredients =
            ingredients.sublist(0, i);
        allRecipes = await _searchRecipesWithIngredients(reducedIngredients);

        if (allRecipes.isNotEmpty) {
          break; // 레시피가 발견되면 더 이상 검색하지 않음
        }
      }
    }

    return allRecipes;
  }

  List<Recipe> showRecipe(List<Recipe> savedRecipes,
      [List<Recipe>? notSavedRecipes]) {
    List<Recipe> rcpSub = []; // 반찬 메뉴
    List<Recipe> rcpStew = []; // 국 메뉴
    List<Recipe> rcpDish = []; // 밥 메뉴
    List<Recipe> rcpShow = []; // 제공할 레시피

    // 저장된 레시피 결합
    List<Recipe> rcp = List.from(savedRecipes);
    if (notSavedRecipes != null) {
      rcp.addAll(notSavedRecipes);
    }

    // 음식 종류 분류
    for (var recipe in rcp) {
      if (recipe.category == "반찬") {
        rcpSub.add(recipe);
      } else if (recipe.category == "국" || recipe.category == "찌개") {
        rcpStew.add(recipe);
      } else if (recipe.category == "밥" || recipe.category == "일품") {
        rcpDish.add(recipe);
      }
    }

    // 반찬 -> 국찌개 -> 밥 순으로 최대 3개의 레시피 선택
    while (rcpShow.length < 3) {
      if (rcpSub.isNotEmpty) {
        rcpShow.add(rcpSub.removeAt(0));
      }
      if (rcpStew.isNotEmpty && rcpShow.length < 3) {
        rcpShow.add(rcpStew.removeAt(0));
      }
      if (rcpDish.isNotEmpty && rcpShow.length < 3) {
        rcpShow.add(rcpDish.removeAt(0));
      }

      // 더 이상 추가할 레시피가 없을 경우 루프 탈출
      if (rcpSub.isEmpty && rcpStew.isEmpty && rcpDish.isEmpty) {
        break;
      }
    }

    // 3개 미만이면 가능한 모든 레시피 보여줌
    return rcpShow;
  }

  Future<List<Map<String, dynamic>>> searchRecipe(
      List<String> ingredients) async {
    String apiKey = dotenv.get("RCP_apikey");
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
}
