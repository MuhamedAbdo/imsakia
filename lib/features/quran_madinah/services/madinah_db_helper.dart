import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:imsakia/features/quran_madinah/models/aya.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DbHelper {
  static const String _dbName = 'quran_app.db';
  static const int _dbVersion = 1;
  static const String _tableName = 'ayahs';

  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux) {
      // Initialize FFI for Desktop
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, _dbName);

    return await openDatabase(path, version: _dbVersion, onCreate: _onCreate);
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY,
        jozz INTEGER,
        sura_no INTEGER,
        sura_name_en TEXT,
        sura_name_ar TEXT,
        page INTEGER,
        line_start INTEGER,
        line_end INTEGER,
        aya_no INTEGER,
        aya_text TEXT,
        aya_text_emlaey TEXT
      )
    ''');
  }

  /// Initializes the database with JSON data if it's empty
  static Future<void> populateDatabaseIfEmpty() async {
    final db = await database;
    final countSq = await db.rawQuery('SELECT COUNT(*) FROM $_tableName');
    final count = Sqflite.firstIntValue(countSq);

    if (count == 0) {
      // Database is empty, read from JSON and populate
      final String jsonString = await rootBundle.loadString(
        'assets/data/hafs_smart_v8.json',
      );
      final List<dynamic> jsonList = json.decode(jsonString);

      Batch batch = db.batch();
      for (var jsonMap in jsonList) {
        batch.insert(_tableName, jsonMap);
      }
      await batch.commit(noResult: true);
    }
  }

  /// Fetch all Ayahs for a specific page
  static Future<List<Aya>> getAyahsByPage(int page) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'page = ?',
      whereArgs: [page],
      orderBy: 'id ASC',
    );
    return List.generate(maps.length, (i) {
      return Aya.fromJson(maps[i]);
    });
  }

  /// Fetch a distinct list of Surahs (for the Index page)
  static Future<List<Map<String, dynamic>>> getAllSurahs() async {
    final db = await database;
    // We can get details by grouping by sura_no
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        sura_no, 
        sura_name_ar, 
        sura_name_en, 
        COUNT(id) as ayah_count, 
        MIN(page) as start_page
      FROM $_tableName 
      GROUP BY sura_no 
      ORDER BY sura_no ASC
    ''');
    return maps;
  }

  /// Search ayahs using the Emlaey string (without diacritics)
  static Future<List<Aya>> searchAyahs(String query) async {
    final db = await database;

    // Using LIKE to find substrings
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'aya_text_emlaey LIKE ?',
      whereArgs: ['%$query%'],
      limit: 100, // Reasonable cap
    );

    return List.generate(maps.length, (i) {
      return Aya.fromJson(maps[i]);
    });
  }
}
