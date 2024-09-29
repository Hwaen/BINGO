import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RecipeService {
  final String apiKey = dotenv.get("RCP_apikey");
  final String serviceId = 'COOKRCP01';
  final String dataType = 'json'; // 'json' 또는 'xml' 선택 가능
  final int startIdx = 1;
  final int endIdx = 100; // 100개 정도 가져와서 랜덤으로 선택

  Future<Map<String, dynamic>> getRandomRecipe() async {
    final String url =
        'http://openapi.foodsafetykorea.go.kr/api/$apiKey/$serviceId/$dataType/$startIdx/$endIdx';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final recipes = data['COOKRCP01']['row'];

      if (recipes != null && recipes.isNotEmpty) {
        final random = Random();
        final randomIndex = random.nextInt(recipes.length);
        return recipes[randomIndex];
      } else {
        throw Exception('No recipes found');
      }
    } else {
      throw Exception('Failed to load recipes');
    }
  }
}
