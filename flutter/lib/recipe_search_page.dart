// 레시피 검색 페이지

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'recipe_detail_page.dart';
import 'recipe_provider.dart'; // Import RecipeProvider

class RecipeSearchPage extends StatefulWidget {
  const RecipeSearchPage({super.key});

  @override
  _RecipeSearchPageState createState() => _RecipeSearchPageState();
}

class _RecipeSearchPageState extends State<RecipeSearchPage> {
  String _food = '';
  List<Recipe> _recipes = [];
  bool _loading = false;
  String _errorMessage = '';
  final Set<String> _savedRecipeIds =
      <String>{}; // Add this to keep track of saved recipes

  Future<void> _searchRecipe() async {
    setState(() {
      _loading = true;
      _errorMessage = '';
    });

    const url = 'http://10.0.2.2:5000/search_recipe'; // 에뮬레이터에서의 Flask 서버 URL
    try {
      final response = await http.get(
        Uri.parse('$url?ingredient=$_food'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonResponse = jsonDecode(response.body);

        setState(() {
          _recipes = jsonResponse
              .map((data) {
                try {
                  return Recipe.fromJson(data as Map<String, dynamic>);
                } catch (e) {
                  print('Error parsing recipe: $e');
                  return null; // 또는 Recipe 객체를 생성할 수 없는 경우 null을 반환
                }
              })
              .where((recipe) => recipe != null)
              .cast<Recipe>()
              .toList();
          _errorMessage = '';
        });
      } else {
        setState(() {
          _recipes = [];
          _errorMessage = '레시피를 가져오는 데 실패했습니다. 상태 코드: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _recipes = [];
        _errorMessage = '레시피를 가져오는 데 오류가 발생했습니다: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _toggleFavorite(Recipe recipe) {
    setState(() {
      if (_savedRecipeIds.contains(recipe.id)) {
        _savedRecipeIds.remove(recipe.id);
        context.read<RecipeProvider>().removeRecipe(recipe.id);
      } else {
        _savedRecipeIds.add(recipe.id);
        final savedRecipe = Recipe(
          id: recipe.id,
          title: recipe.title,
          imageUrl: recipe.imageUrl,
          imageUrl2: recipe.imageUrl2,
          description: recipe.description,
          manualSteps: recipe.manualSteps,
          ingredients: recipe.ingredients,
          tip: recipe.tip,
          category: recipe.category,
        );

        // 저장된 레시피 추가
        context.read<RecipeProvider>().saveRecipe(savedRecipe);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('레시피 검색'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              onChanged: (value) {
                setState(() {
                  _food = value;
                });
              },
              decoration: InputDecoration(
                labelText: '음식을 입력하세요',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _searchRecipe,
              child: Text('레시피 검색'),
            ),
            SizedBox(height: 20),
            _loading
                ? CircularProgressIndicator()
                : _errorMessage.isNotEmpty
                    ? Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.red),
                      )
                    : Expanded(
                        child: ListView.builder(
                          itemCount: _recipes.length,
                          itemBuilder: (context, index) {
                            final recipe = _recipes[index];
                            final isFavorite =
                                _savedRecipeIds.contains(recipe.id);
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RecipeDetailPage(
                                      recipe: recipe,
                                    ),
                                  ),
                                );
                              },
                              child: Card(
                                margin: EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (recipe.imageUrl.isNotEmpty)
                                      SizedBox(
                                        width: double.infinity,
                                        height: 150,
                                        child: Image.network(
                                          recipe.imageUrl,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    else
                                      Container(
                                        width: double.infinity,
                                        height: 150,
                                        color: Colors.grey[300],
                                        child: Center(
                                          child: Icon(
                                            Icons.food_bank,
                                            size: 50,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              recipe.title,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              isFavorite
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              color: isFavorite
                                                  ? Colors.red
                                                  : Colors.grey,
                                            ),
                                            onPressed: () {
                                              _toggleFavorite(recipe);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0, vertical: 4.0),
                                      child: Text(
                                        '재료: ${recipe.ingredients}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0, vertical: 4.0),
                                      child: Text(
                                        '분류: ${recipe.category}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0, vertical: 4.0),
                                      child: Text(
                                        '팁: ${recipe.tip}',
                                        style:
                                            TextStyle(color: Colors.grey[600]),
                                        softWrap: true,
                                        overflow: TextOverflow.visible,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0, vertical: 4.0),
                                      child: Text(
                                        '음식 칼로리: ${recipe.description}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ],
        ),
      ),
    );
  }
}
