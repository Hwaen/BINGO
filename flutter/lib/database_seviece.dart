/* 데이터 베이스 */

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'recipe_provider.dart';
//import 'myfridge_page.dart';
//import 'mybingo_page.dart';

class Database_BINGO{
  //var _db;
  Database? _db;

  Future<Database> get db async{
    if (_db != null) return _db!;

    _db = await initDatabase();
    return _db!;  
  }

  Future<Database> initDatabase() async{
    return openDatabase(
        join(await getDatabasesPath(), 'assets/database.db'),
        onCreate: (db, version) => create_database(db),
        version : 1,
    );
    //return _db;
  }
  
  // CREATE DATABASE
  void create_database(Database db) async {
    // Recipe DB
    db.execute (''' CREATE TABLE "recipes" (
            "rcp_num"	int NOT NULL UNIQUE,
            "rcp_title"	text NOT NULL,
            "rcp_imageUrl" Blob Not NULL,
            "rcp_imageUrl2" BLOB Not NULL,
            "rcp_ingredients"	text NOT NULL,
            "rcp_description" text Not NULL,
            "rcp_type"	text NOT NULL,
            "rcp_manual"	text NOT NULL,
            "rcp_tip" text NOT NULL,
            "rcp_category" text NOT NULL,
            "rcp_eng"	text NOT NULL,
            "rcp_heart"	int NOT NULL,
            PRIMARY KEY("rcp_num") 
            )'''
    );

    // Food DB
    db.execute('''CREATE TABLE "ingredient" (
              "ingredient_index" int NOT NULL UNIQUE,
              "ingredient_name" text NOT NULL,
              "ingredient_exp" text NOT NULL,
              "ingredient_iscook" int NOT NULL,
              PRIMARY KEY("ingredient_index") 
              )'''
    );

    // // User DB
    // db.execute('''CREATE TABLE "user" (
    //   "user_gender" text NOT NULL ,
    //   "user_age" int NOT NULL,
    //   "user_height" real NOT NULL,
    //   "user_weight" real NOT NULL,
    //   "user_acticvitiyLevel" text NOT NULL,
    //   "user_profileImageUrl" text NOT NULL,
    //   "user_calories" real NOT NULL UNIQUE ) 
    //   ''');
  }

/*==============================================================================================*/  
  /* 재료 데이터 베이스 관리*/

  // INSERT ingredient
  Future<bool> insert_ingredient(Map<String, dynamic> ingredient, bool isCooking ) async{
    final Database database = await db;
    try{
      if(isCooking){
        await database.insert(
          'ingredient', {
          'ingredient_index': ingredient['id'],
          'ingredient_name': ingredient['name'],
          'ingredient_exp': ingredient['expiryDate'],
          'ingredient_iscook': 1 }, //요리 가능 보관
          conflictAlgorithm: ConflictAlgorithm.replace
          );
         
      }else{
        await database.insert(
          'ingredient', { 
            'ingredient_index': ingredient['id'],
            'ingredient_name': ingredient['name'],
            'ingredient_exp': ingredient['expiryDate'],
            'ingredient_iscook': 0 }, //재료 보관
        conflictAlgorithm: ConflictAlgorithm.replace
        );
      }
      print("재료 저장 완료");
      return true;
      
    }
    catch(err){
      return false;
    }
  }

  // SELECT ingredient
  Future<List<Map<String, dynamic>>> select_ingredient(Map<String, dynamic> ingredient) async{
    final Database database = await db;
    final List<Map<String, dynamic>> data = await database.query('ingredient', where: "ingredient = ?", whereArgs: [ingredient['id']]);

    return data;
  }
  
  //SELECT ALL ingredient
  Future<List<Map<String, dynamic>>> selectALL_ingredient() async{
    final Database database = await db;
    final List<Map<String, dynamic>> data = await database.query('ingredient');

    return data;
  }

  // UPDATE Ingredient
  Future<bool> update_ingredient(Map<String, dynamic> ingredient, int isCooking) async {
    final Database database = await db;
    try{
      database.update(
        'ingredient', 
        { 'ingredient_index': ingredient['id'],
          'ingredient_exp': ingredient['expiryDate'],
          'ingredient_iscook': isCooking },
        where: "ingredient = ?",
        whereArgs: [ingredient['id']]
        );
        return true;
    }
    catch(err){
      return false;
    }

  }

  // DELETE ingredient
  Future<bool> delete_ingredient(String ingredient) async{
    final Database database = await db;
    try{
      database.delete(
        'ingredient',
        where: "ingredient = ?",
        whereArgs: [ingredient],
        );
    return true;
    }
    catch(err){
      return false;
    }
  }


  /* 레시피 데이터 베이스 */

  // INSERT Recipe
  Future<bool> insert_Recipe(Recipe RCP) async{
    final Database database = await db;
    try{
      database.insert(
        'recipes',
        RCP.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace
        );

        return true;
    }
    catch(err){
      return false;
    }
  }

  // SELECT Recipe
  Future<List<Recipe>> select_Recipe(Recipe RCP) async{
    final Database database = await db;
    final List<Map<String, dynamic>> data = await database.query('recipes', where: "rcp_num = ?", whereArgs: [RCP.id]);

    return List.generate(data.length, (i) {
      return Recipe(
        id: data[i] ['id'], 
        title: data[i] ['title'], 
        imageUrl: data[i] ['imageUrl'], 
        imageUrl2: data[i] ['imageUrl2'], 
        ingredients: data[i] ['ingredients'], 
        description: data[i] ['description'], 
        type: data[i] ['type'],
        manualSteps: data[i] ['manualSteps'],         
        tip: data[i] ['tip'],
        category: data[i] ['category'],
        energy: data[i]['energy'],
        heart: false
        );
    });
  }
  
  // SELECT ALL Recipe
  Future<List<Recipe>> selectALL_Recipe() async{
    final Database database = await db;
    final List<Map<String, dynamic>> data = await database.query('recipes');

    return List.generate(data.length, (i) {
      return Recipe(
        id: data[i] ['id'], 
        title: data[i] ['title'], 
        imageUrl: data[i] ['imageUrl'], 
        imageUrl2: data[i] ['imageUrl2'], 
        ingredients: data[i] ['ingredients'], 
        description: data[i] ['description'], 
        type: data[i] ['type'],
        manualSteps: data[i] ['manualSteps'],         
        tip: data[i] ['tip'],
        category: data[i] ['category'],
        energy: data[i]['energy'],
        heart: false
        );
    });
  }

  // UPDATE Recipe
  Future<bool> update_Recipe(Recipe RCP) async {
    final Database database = await db;
    try{
      database.update(
        'recipes', 
        RCP.toJson(),
        where: "id = ?",
        whereArgs: [RCP.id]
        );
        return true;
    }
    catch(err){
      return false;
    }

  }

  // DELETE Recipe
  Future<bool> delete_Recipe(int id) async{
     final Database database = await db;
    try{
      database.delete(
        'recipes',
        where: "id = ?",
        whereArgs: [id],
        );
    return true;
    }
    catch(err){
      return false;
    }
  }

}
