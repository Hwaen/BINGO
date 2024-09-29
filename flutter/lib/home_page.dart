import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:hello_flutter/recipe_search_page.dart';

import 'feed.dart';
import 'myfridge_page.dart'; // 내 냉장고 페이지
import 'recipe_page.dart'; // 레시피 페이지
import 'mybingo_page.dart'; // 나의 빙고 페이지

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const Feed(),
    const MyFridgePage(),
    RecipePage(),
    const MybingoPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          _currentIndex == 0
              ? '오늘의 추천 레시피'
              : _currentIndex == 1
                  ? '내 냉장고'
                  : _currentIndex == 2
                      ? '저장된 레시피'
                      : '나의 빙고',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              // 돋보기 버튼을 눌렀을 때 RecipeSearchPage로 이동
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecipeSearchPage(),
                ),
              );
            },
            icon: const Icon(CupertinoIcons.search, color: Colors.black),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.menu_rounded, color: Colors.black),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(CupertinoIcons.bell, color: Colors.black),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      // 카메라 및 갤러리 기능 삭제
      floatingActionButton: null, // 또는 필요에 따라 다른 버튼으로 대체
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.black,
        showUnselectedLabels: true,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        iconSize: 28,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fastfood_outlined),
            label: '내 냉장고',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            label: '레시피',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: '나의 빙고',
          ),
        ],
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
