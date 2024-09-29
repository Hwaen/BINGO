import 'package:flutter/material.dart';
import 'recipe_provider.dart';

class RecipeDetailScreen extends StatelessWidget {
  final Recipe recipe; // Recipe 객체 사용

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title), // recipe의 title 사용
      ),
      body: CustomScrollView(
        slivers: [
          // 상단 이미지
          if (recipe.imageUrl.isNotEmpty)
            SliverToBoxAdapter(
              child: Image.network(
                recipe.imageUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: Center(
                      child: Icon(
                        Icons.food_bank,
                        size: 100,
                        color: Colors.grey[600],
                      ),
                    ),
                  );
                },
              ),
            ),
          // 여백과 레시피 정보
          SliverPadding(
            padding: EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  recipe.title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  '재료: ${recipe.ingredients}', // 재료 정보 추가
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  '음식 칼로리: ${recipe.description}', // 칼로리 정보 추가
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  '팁: ${recipe.tip}', // 팁 정보 추가
                  style: TextStyle(fontSize: 16, color: Colors.black45),
                ),
                SizedBox(height: 16),
                Text(
                  '조리 단계',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
              ]),
            ),
          ),
          // 조리 단계 내용
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16.0), // 가로 여백 추가
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= recipe.manualSteps.length) {
                    return SizedBox.shrink(); // 단계가 없으면 빈 위젯 반환
                  }

                  String stepDescription =
                      recipe.manualSteps[index]['step'] ?? '';
                  String? stepImage = recipe.manualSteps[index]['image'] ?? '';

                  // 조리 단계에 정보가 없는 경우는 반환하지 않음
                  if (stepDescription.isEmpty) {
                    return SizedBox.shrink();
                  }

                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Container(
                      padding: EdgeInsets.all(12.0), // 내부 여백
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '단계 ${index + 1}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(stepDescription),
                          if (stepImage!.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Image.network(
                                stepImage,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                      child: Text('이미지를 불러올 수 없습니다.'));
                                },
                              ),
                            ),
                          SizedBox(height: 16),
                        ],
                      ),
                    ),
                  );
                },
                childCount: recipe.manualSteps.length, // 실제 단계 수에 맞게 설정
              ),
            ),
          ),
        ],
      ),
    );
  }
}
