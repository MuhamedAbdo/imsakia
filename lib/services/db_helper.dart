import 'package:sqflite/sqflite.dart' as sqlite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:path/path.dart';
import 'dart:io';
import 'package:flutter/services.dart';

class DbHelper {
  static sqlite.Database? _db;

  Future<sqlite.Database> get db async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  Future<sqlite.Database> initDb() async {
    // Initialize databaseFactory based on platform
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Initialize FFI for desktop platforms
      ffi.sqfliteFfiInit();
      sqlite.databaseFactory = ffi.databaseFactoryFfi;
    }

    var databasesPath = await sqlite.getDatabasesPath();
    var path = join(databasesPath, "quran.db");

    var exists = await sqlite.databaseExists(path);

    if (exists) {
      // Validate the database structure - Ensure it's the professional version
      bool isValid = false;
      sqlite.Database? checkDb;
      try {
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          checkDb = await ffi.databaseFactoryFfi.openDatabase(path);
        } else {
          checkDb = await sqlite.openDatabase(path);
        }

        // Check for essential tables AND professional tables like 'hizbs'
        final tables = await checkDb.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND (name='surahs' OR name='ayahs' OR name='hizbs')",
        );

        if (tables.length >= 3) {
          isValid = true;
        } else {
          print(
            "Database validation failed: Professional tables missing or incomplete.",
          );
        }
      } catch (e) {
        print("Error validating existing database: $e");
      } finally {
        await checkDb?.close();
      }

      if (!isValid) {
        print("Deleting invalid/old database and forcing re-copy...");
        await File(path).delete();
        exists = false;
      }
    }

    if (!exists) {
      try {
        print("Copying database from assets...");
        ByteData data = await rootBundle.load("assets/quran.db");
        List<int> bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await File(path).writeAsBytes(bytes, flush: true);
        print("Database copied successfully!");
      } catch (e) {
        print("Error copying database: $e");
      }
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final db = await ffi.databaseFactoryFfi.openDatabase(
        path,
        options: sqlite.OpenDatabaseOptions(readOnly: false),
      );
      await _createIndexes(db);
      return db;
    } else {
      final db = await sqlite.openDatabase(path);
      await _createIndexes(db);
      return db;
    }
  }

  Future<List<Map<String, dynamic>>> getSurahs() async {
    sqlite.Database myDb = await db;
    // Use GROUP BY id to avoid duplicated surahs in the source DB
    final List<Map<String, dynamic>> surahs = await myDb.rawQuery(
      'SELECT * FROM surahs GROUP BY id ORDER BY id ASC',
    );

    final List<Map<String, dynamic>> modifiableSurahs = surahs
        .map((surah) => Map<String, dynamic>.from(surah))
        .toList();

    for (var surah in modifiableSurahs) {
      final countResult = await myDb.rawQuery(
        'SELECT COUNT(DISTINCT id) as count FROM ayahs WHERE surah_id = ?',
        [surah['id']],
      );
      surah['ayah_count'] = countResult.first['count'];
    }

    return modifiableSurahs;
  }

  Future<void> _createIndexes(sqlite.Database db) async {
    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ayahs_surah_id ON ayahs(surah_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ayahs_juz_id ON ayahs(juz_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ayahs_number_in_surah ON ayahs(number_in_surah)',
      );
    } catch (e) {
      print("Warning: Could not create indexes: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getJuzs() async {
    sqlite.Database myDb = await db;

    // Dynamically get juz metadata from ayahs and surahs
    // Since the juzs table in the professional DB is empty,
    // we derive the juz list and its surah boundaries from the ayahs table.
    return await myDb.rawQuery('''
      SELECT 
        a.juz_id as id, 
        s_start.name_ar as start_surah_name, 
        s_end.name_ar as end_surah_name
      FROM (
        SELECT juz_id, MIN(surah_id) as min_s, MAX(surah_id) as max_s 
        FROM ayahs 
        GROUP BY juz_id
      ) a
      LEFT JOIN surahs s_start ON a.min_s = s_start.id
      LEFT JOIN surahs s_end ON a.max_s = s_end.id
      GROUP BY a.juz_id
      ORDER BY a.juz_id ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> searchAyahs(String query) async {
    sqlite.Database myDb = await db;
    // Normalize the query by removing common Arabic diacritics and normalizing Alif/Yah
    String normalizedQuery = query
        .replaceAll(RegExp(r'[\u064B-\u0652]'), '') // Remove Tashkeel
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');

    // Use a SQL REPLACE chain to normalize the database text column during search
    // We use GROUP BY a.surah_id, a.number_in_surah to avoid duplicates
    return await myDb.rawQuery(
      '''
      SELECT a.*, s.name_ar as surah_name_ar, s.name_en as surah_name_en
      FROM ayahs a
      INNER JOIN surahs s ON a.surah_id = s.id
      WHERE 
        REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
          a.text, 
          'ً', ''), 'ٌ', ''), 'ٍ', ''), 'َ', ''), 'ُ', ''), 'ِ', ''), 'ّ', ''), 'ْ', ''),
          'أ', 'ا'), 'إ', 'ا'), 'آ', 'ا'), 'ة', 'ه') LIKE ?
      GROUP BY a.surah_id, a.number_in_surah
      ORDER BY a.surah_id ASC, a.number_in_surah ASC
      LIMIT 100
    ''',
      ['%$normalizedQuery%'],
    );
  }

  Future<List<Map<String, dynamic>>> getAyahsByJuz(int juzId) async {
    sqlite.Database myDb = await db;
    return await myDb.rawQuery(
      '''
      SELECT a.*, s.name_ar as surah_name_ar
      FROM ayahs a
      INNER JOIN surahs s ON a.surah_id = s.id
      WHERE a.juz_id = ?
      GROUP BY a.surah_id, a.number_in_surah
      ORDER BY a.surah_id ASC, a.number_in_surah ASC
    ''',
      [juzId],
    );
  }

  Future<List<Map<String, dynamic>>> getAyahsBySurah(int surahId) async {
    sqlite.Database myDb = await db;
    return await myDb.query(
      'ayahs',
      where: 'surah_id = ?',
      whereArgs: [surahId],
      groupBy: 'number_in_surah',
      orderBy: 'number_in_surah ASC',
    );
  }

  Future<Map<String, dynamic>?> getTafsirByAyah(int ayahId) async {
    sqlite.Database myDb = await db;
    final results = await myDb.query(
      'ayah_edition',
      where: 'ayah_id = ?',
      whereArgs: [ayahId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }
}
