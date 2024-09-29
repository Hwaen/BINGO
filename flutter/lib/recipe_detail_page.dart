import 'package:flutter/material.dart';
import 'recipe_provider.dart'; // Recipe 클래스의 위치에 맞게 경로를 수정

class RecipeDetailPage extends StatelessWidget {
  final Recipe recipe;

  RecipeDetailPage({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: ListView(
          children: [
            if (recipe.imageUrl2.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 200,
                child: Image.network(
                  recipe.imageUrl2,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 200,
                color: Colors.grey[300],
                child: Center(
                  child: Icon(
                    Icons.food_bank,
                    size: 100,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            SizedBox(height: 16),
            Text(
              '음식 이름: ${recipe.title}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              '음식 재료: ${recipe.ingredients}',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 10),
            Text(
              '음식 칼로리: ${recipe.description}',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 10),
            Text(
              '조리법:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            ..._buildCookingSteps(recipe.manualSteps),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCookingSteps(List<Map<String, dynamic>> manualSteps) {
    List<Widget> stepsWidgets = [];

    for (var stepData in manualSteps) {
      String step = stepData['step'] ?? '';
      String imageUrl2 = stepData['image'] ?? '';

      if (step.isNotEmpty || imageUrl2.isNotEmpty) {
        stepsWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0), // 단계 간의 여백 증가
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (step.isNotEmpty)
                  Text(
                    step,
                    style: TextStyle(fontSize: 16),
                  ),
                if (step.isNotEmpty && imageUrl2.isNotEmpty)
                  SizedBox(height: 16), // 텍스트와 이미지 사이의 여백
                if (imageUrl2.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    height: 250, // 이미지 크기 키우기
                    child: Image.network(
                      imageUrl2,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Center(child: Text('이미지 로드 실패')),
                    ),
                  ),
              ],
            ),
          ),
        );
      }
    }

    return stepsWidgets;
  }
}
