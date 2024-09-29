/* 데이터 베이스 */

import 'package:path/path.dart';
import 'recipe_provider.dart';
import 'myfridge_page.dart';

import 'package:sqflite/sqflite.dart';

class Database_BINGO{
  var _db;

  Future<Database> get db async{
    if (_db != null) return _db!;

    _db = await initDatabase();
    return _db!;  
  }

  Future<Database> initDatabase() async{
    _db = openDatabase(
        join(await getDatabasesPath(), 'database.db'),
        onCreate: (db, version) => create_database(db),
        version : 1,
        );
        return _db;
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
            ) 
            ''');

  // food DB
    db.execute('''CREATE TABLE "ingredient" (
      "ingredient_name" text NOT NULL UNIQUE,
      "ingredient_exp" text NOT NULL,
      "ingredient_iscook" int NOT NULL,
      PRIMARY KEY("ingredient_name") 
      ) 
      ''');

    // user DB
    db.execute('''CREATE TABLE "user" (
      "gender" text NOT NULL UNIQUE,
      "acticvitiyLevel" text NOT NULL,
      "profileImageUrl" text NOT NULL,
      "recommendedCalories" real NOT NULL
      ) 
      ''');
  }

/*==============================================================================================*/
  /* 재료 데이터 베이스 관리*/

  // INSERT ingredient
  Future<bool> insert_ingredient(Ingredient ingredient) async{
    final Database database = await db;
    try{
      await database.insert(
        'ingredient',
        ingredient.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace
        );

        return true;
    }
    catch(err){
      return false;
    }
  }

  // SELECT ingredient
  Future<List<Ingredient>> select_ingredient(Ingredient ingredient) async{
    final Database database = await db;
    final List<Map<String, dynamic>> data = await database.query('ingredient', where: "ingredient = ?", whereArgs: [ingredient.ingredient]);

    return List.generate(data.length, (i) {
      return Ingredient(
        ingredient: data[i] ['ingredient'],
        //imageUrl: data[i] ['imageUrl'],
        expiryDate: data[i] ['expiryDate'],
        storageType: data[i] ['is_Retort']

        );
    });
  }
  
  // UPDATE Ingredient
  Future<bool> update_ingredient(Ingredient ingredient) async {
    final Database database = await db;
    try{
      database.update(
        'ingredient', 
        ingredient.toMap(),
        where: "ingredient = ?",
        whereArgs: [ingredient.ingredient]
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



  ///////////* 레시피 데이터 베이스 */////////
  
  // INSERT Recipe
  Future<bool> insert_Recipe(Recipe RCP) async{
    final Database database = await db;
    try{
      database.insert(
        'recipes',
        RCP.toMap(),
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
        description: data[i] ['description'], 
        manualSteps: data[i] ['manualSteps'], 
        ingredients: data[i] ['ingredients'], 
        tip: data[i] ['tip'],
        category: data[i] ['category']
        );
    });
  }
  
  // UPDATE Recipe
  Future<bool> update_Recipe(Recipe RCP) async {
    final Database database = await db;
    try{
      database.update(
        'recipes', 
        RCP.toMap(),
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
  Future<bool> deleteRecipe(int id) async{
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
