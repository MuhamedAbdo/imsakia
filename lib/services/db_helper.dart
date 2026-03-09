import 'package:sqflite/sqflite.dart' as sqlite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:path/path.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class DbHelper {
  static sqlite.Database? _db;
  static final DbHelper _instance = DbHelper._internal();
  factory DbHelper() => _instance;
  DbHelper._internal();

  Future<sqlite.Database> get db async {
    if (_db != null && _db!.isOpen) return _db!;
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
        // Verification: Ensure tafsir tables are there
        final tables = await checkDb.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND (name='ayah_edition')",
        );
        if (tables.isNotEmpty) isValid = true;
      } catch (e) {
        debugPrint("Error validating database: \$e");
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
        List<int> bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await File(path).writeAsBytes(bytes, flush: true);
      } catch (e) {
        debugPrint("Error copying database: \$e");
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
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ayah_edition_ayah_id ON ayah_edition(ayah_id)',
      );
    } catch (e) {
      debugPrint("Warning: Indexes: \$e");
    }
  }

  // دالة جلب التفسير من المصحف القديم الذي أضِفنا عليه تعديلنا
  Future<String> getTafsir(int surahId, int ayahNum) async {
    sqlite.Database myDb = await db;
    
    // Calculates the absolute ayah ID which exactly aligns with the shimerli ayah_id.
    int absoluteAyahId = 0;
    
    // Total ayahs per surah in standard King Fahd Quran
    const surahAyahCounts = [
      7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128, 111, 
      110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73, 54, 45, 
      83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60, 49, 62, 55, 
      78, 96, 29, 22, 24, 13, 14, 11, 11, 18, 12, 12, 30, 52, 52, 44, 28, 28, 20, 
      56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25, 22, 17, 19, 26, 30, 20, 15, 21, 
      11, 8, 8, 19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6
    ];

    // Add all ayahs of preceding surahs
    for (int i = 0; i < surahId - 1; i++) {
       absoluteAyahId += surahAyahCounts[i];
    }
    
    // Add current ayah number within the surah
    absoluteAyahId += ayahNum;

    try {
      final List<Map<String, dynamic>> tafsir = await myDb.query(
        'ayah_edition',
        columns: ['data'],
        where: 'ayah_id = ? AND edition_id = 1', // Assuming edition_id 1 is the default Tafsir
        whereArgs: [absoluteAyahId],
        limit: 1,
      );

      if (tafsir.isNotEmpty) {
        return tafsir.first['data']?.toString() ?? "التفسير غير متوفر.";
      }
    } catch (e) {
      debugPrint("Error fetching tafsir: $e");
    }

    return "لا يوجد تفسير متاح.";
  }
}
