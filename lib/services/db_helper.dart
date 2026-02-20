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
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      ffi.sqfliteFfiInit();
      sqlite.databaseFactory = ffi.databaseFactoryFfi;
    }

    var databasesPath = await sqlite.getDatabasesPath();
    var path = join(databasesPath, "quran.db");
    var exists = await sqlite.databaseExists(path);

    if (exists) {
      bool isValid = false;
      sqlite.Database? checkDb;
      try {
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          checkDb = await ffi.databaseFactoryFfi.openDatabase(path);
        } else {
          checkDb = await sqlite.openDatabase(path);
        }
        final tables = await checkDb.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND (name='surahs' OR name='ayahs' OR name='hizbs')",
        );
        if (tables.length >= 3) isValid = true;
      } catch (e) {
        print("Error validating database: $e");
      } finally {
        await checkDb?.close();
      }
      if (!isValid) {
        await File(path).delete();
        exists = false;
      }
    }

    if (!exists) {
      try {
        ByteData data = await rootBundle.load("assets/quran.db");
        List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await File(path).writeAsBytes(bytes, flush: true);
      } catch (e) {
        print("Error copying database: $e");
      }
    }

    sqlite.Database db;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      db = await ffi.databaseFactoryFfi.openDatabase(path);
    } else {
      db = await sqlite.openDatabase(path);
    }
    await _createIndexes(db);
    return db;
  }

  Future<void> _createIndexes(sqlite.Database db) async {
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_ayahs_surah_id ON ayahs(surah_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_ayahs_juz_id ON ayahs(juz_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_ayahs_number_in_surah ON ayahs(number_in_surah)');
    } catch (e) {
      print("Warning: Indexes: $e");
    }
  }

  // دالة جلب التفسير (معدلة لجدولك)
  Future<String> getTafsir(int surahId, int ayahNum) async {
    sqlite.Database myDb = await db;
    // جلب id الآية أولاً
    final List<Map<String, dynamic>> ayah = await myDb.query(
      'ayahs',
      columns: ['id'],
      where: 'surah_id = ? AND number_in_surah = ?',
      whereArgs: [surahId, ayahNum],
      limit: 1,
    );

    if (ayah.isNotEmpty) {
      final List<Map<String, dynamic>> tafsir = await myDb.query(
        'ayah_edition',
        where: 'ayah_id = ?',
        whereArgs: [ayah.first['id']],
        limit: 1,
      );
      if (tafsir.isNotEmpty) {
        return tafsir.first['data'] ?? tafsir.first['text'] ?? "التفسير غير متوفر.";
      }
    }
    return "لا يوجد تفسير متاح.";
  }

  Future<List<Map<String, dynamic>>> getSurahs() async {
    sqlite.Database myDb = await db;
    final List<Map<String, dynamic>> surahs = await myDb.rawQuery('SELECT * FROM surahs GROUP BY id ORDER BY id ASC');
    final List<Map<String, dynamic>> modifiableSurahs = surahs.map((s) => Map<String, dynamic>.from(s)).toList();
    for (var surah in modifiableSurahs) {
      final countResult = await myDb.rawQuery('SELECT COUNT(DISTINCT id) as count FROM ayahs WHERE surah_id = ?', [surah['id']]);
      surah['ayah_count'] = countResult.first['count'];
    }
    return modifiableSurahs;
  }

  Future<List<Map<String, dynamic>>> getJuzs() async {
    sqlite.Database myDb = await db;
    final results = await myDb.rawQuery('''
      SELECT 
        juz_id as id, 
        MIN(surah_id) as min_surah_id,
        MAX(surah_id) as max_surah_id
      FROM ayahs 
      GROUP BY juz_id
      ORDER BY juz_id ASC
    ''');
    
    List<Map<String, dynamic>> juzs = [];
    for (var result in results) {
      final startSurah = await myDb.query(
        'surahs',
        columns: ['name_ar'],
        where: 'id = ?',
        whereArgs: [result['min_surah_id']],
        limit: 1,
      );
      final endSurah = await myDb.query(
        'surahs',
        columns: ['name_ar'],
        where: 'id = ?',
        whereArgs: [result['max_surah_id']],
        limit: 1,
      );
      
      juzs.add({
        'id': result['id'],
        'start_surah_name': startSurah.isNotEmpty ? startSurah.first['name_ar'] : '',
        'end_surah_name': endSurah.isNotEmpty ? endSurah.first['name_ar'] : '',
      });
    }
    return juzs;
  }

  Future<List<Map<String, dynamic>>> searchAyahs(String query) async {
    sqlite.Database myDb = await db;
    String normalizedQuery = query.replaceAll(RegExp(r'[\u064B-\u0652\u0670]'), '').replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا').replaceAll('ة', 'ه').replaceAll('ى', 'ي');
    String queryWithoutAL = normalizedQuery.startsWith('ال') ? normalizedQuery.substring(2) : normalizedQuery;

    const String cleanTextSql = "REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(a.text, 'ً', ''), 'ٌ', ''), 'ٍ', ''), 'َ', ''), 'ُ', ''), 'ِ', ''), 'ّ', ''), 'ْ', ''), 'ٰ', ''), 'أ', 'ا'), 'إ', 'ا'), 'آ', 'ا'), 'ة', 'ه')";
    const String cleanNameSql = "REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(s.name_ar, 'ً', ''), 'ٌ', ''), 'ٍ', ''), 'َ', ''), 'ُ', ''), 'ِ', ''), 'ّ', ''), 'ْ', ''), 'ٰ', ''), 'أ', 'ا'), 'إ', 'ا'), 'آ', 'ا'), 'ة', 'ه')";

    return await myDb.rawQuery('''
      SELECT 0 as priority, 0 as id, s.id as surah_id, 1 as number_in_surah, 'سورة ' || s.name_ar as text, s.name_ar as surah_name_ar, s.name_en as surah_name_en
      FROM surahs s
      WHERE $cleanNameSql LIKE ? OR $cleanNameSql LIKE ?
      UNION ALL
      SELECT 1 as priority, a.id, a.surah_id, a.number_in_surah, a.text, s.name_ar as surah_name_ar, s.name_en as surah_name_en
      FROM ayahs a
      INNER JOIN surahs s ON a.surah_id = s.id
      WHERE ($cleanTextSql = ? OR $cleanTextSql LIKE ? OR $cleanTextSql LIKE ? OR $cleanTextSql LIKE ?)
      OR ($cleanTextSql = ? OR $cleanTextSql LIKE ? OR $cleanTextSql LIKE ? OR $cleanTextSql LIKE ?)
      GROUP BY a.surah_id, a.number_in_surah
      ORDER BY priority ASC, surah_id ASC, number_in_surah ASC
      LIMIT 100
    ''', ['%$normalizedQuery%', '%$queryWithoutAL%', normalizedQuery, '$normalizedQuery %', '% $normalizedQuery', '% $normalizedQuery %', queryWithoutAL, '$queryWithoutAL %', '% $queryWithoutAL', '% $queryWithoutAL %']);
  }

  Future<List<Map<String, dynamic>>> getAyahsByJuz(int juzId) async {
    sqlite.Database myDb = await db;
    return await myDb.rawQuery('''
      SELECT a.*, s.name_ar as surah_name_ar FROM ayahs a
      INNER JOIN surahs s ON a.surah_id = s.id
      WHERE a.juz_id = ? GROUP BY a.surah_id, a.number_in_surah
      ORDER BY a.surah_id ASC, a.number_in_surah ASC
    ''', [juzId]);
  }

  Future<List<Map<String, dynamic>>> getAyahsBySurah(int surahId) async {
    sqlite.Database myDb = await db;
    return await myDb.query('ayahs', where: 'surah_id = ?', whereArgs: [surahId], groupBy: 'number_in_surah', orderBy: 'number_in_surah ASC');
  }

  Future<Map<String, dynamic>?> getTafsirByAyah(int ayahId) async {
    sqlite.Database myDb = await db;
    final results = await myDb.query('ayah_edition', where: 'ayah_id = ?', whereArgs: [ayahId], limit: 1);
    return results.isNotEmpty ? results.first : null;
  }
}