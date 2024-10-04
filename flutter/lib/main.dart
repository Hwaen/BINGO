import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'recipe_provider.dart'; // RecipeProvider import
import 'recipe_search_page.dart'; // RecipeSearchPage import
import 'home_page.dart';
import 'mybingo_page.dart';
import 'database_seviece.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env"); 
  
  runApp(
    ChangeNotifierProvider(
      create: (context) => RecipeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FutureBuilder(
        future: _loadIngredients(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else {
            return HomePage(); // 첫 화면을 Feed로 설정
          }
        },
      ),
      routes: {
        '/recipeSearch': (context) => RecipeSearchPage(),
        '/home': (context) => HomePage(),
        '/mybingo': (context) => MybingoPage(),
      },
    );
  }

  Future<void> _loadIngredients(BuildContext context) async {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    recipeProvider.loadSavedIngredients();
  }
}
