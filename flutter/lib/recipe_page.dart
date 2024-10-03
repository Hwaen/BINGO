//저장된 레시피

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'recipe_provider.dart';
import 'recipe_detail_page.dart';

class RecipePage extends StatelessWidget {
  const RecipePage({super.key});

// 괄호와 괄호 안의 내용을 제거하는 함수
  String removeParenthesesContent(String ingredients) {
    final regex = RegExp(r'\(.*?\)'); // 괄호와 그 안의 내용을 모두 포함
    final filteredIngredients = ingredients.replaceAll(regex, '').trim();

    // 중복된 공백 제거
    return filteredIngredients.replaceAll(RegExp(r'\s{2,}'), ' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<RecipeProvider>(
        builder: (context, recipeProvider, child) {
          final recipes = recipeProvider.savedRecipes; // 저장된 레시피 목록 사용

          if (recipes.isEmpty) {
            return Center(
              child: Text(
                '저장된 레시피가 없습니다.',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          return ListView.builder(
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              final ingredientsWithoutParentheses =
                  removeParenthesesContent(recipe.ingredients);

              return GestureDetector(
                onTap: () {
                  // 레시피 카드 클릭 시 상세 페이지로 이동
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecipeDetailPage(recipe: recipe),
                    ),
                  );
                },
                child: Card(
                  margin: EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(8)),
                        child: Image.network(
                          recipe.imageUrl,
                          width: double.infinity,
                          height: 150,
                          fit: BoxFit.cover,
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
                                Icons.favorite,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                // 레시피 삭제
                                context
                                    .read<RecipeProvider>()
                                    .removeRecipe(recipe.id);
                              },
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 4.0),
                        child: Text(
                          ingredientsWithoutParentheses,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
