import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BukhariDatabaseService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, "ara-bukhari.sqlite");

    final exists = await databaseExists(path);
    if (!exists) {
      // تأكد أن المسار في assets مطابق تماماً لما هو في pubspec.yaml
      ByteData data = await rootBundle.load(join("assets/data/ara-bukhari.sqlite"));
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(path).writeAsBytes(bytes, flush: true);
    }
    return await openDatabase(path);
  }

  static Future<Map<String, dynamic>?> getDailyHadith() async {
    try {
      final db = await database;
      final prefs = await SharedPreferences.getInstance();
      
      const String keyLastDate = 'bukhari_last_date';
      const String keyCurrentId = 'bukhari_current_id';
      const String keySeenIds = 'bukhari_seen_ids';

      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month}-${now.day}";
      final lastDate = prefs.getString(keyLastDate);

      // If it's the same day and we have a cached hadith, return it
      if (lastDate == todayStr) {
        final cachedId = prefs.getInt(keyCurrentId);
        if (cachedId != null) {
          final List<Map<String, dynamic>> cachedResult = await db.query(
            'hadiths',
            where: 'id = ?',
            whereArgs: [cachedId],
            limit: 1,
          );
          if (cachedResult.isNotEmpty) return cachedResult.first;
        }
      }

      // 1. Get total count
      final countResult = await db.rawQuery('SELECT COUNT(*) as total FROM hadiths');
      int totalHadiths = countResult.first['total'] as int;
      if (totalHadiths == 0) return null;

      // 2. Load seen IDs
      List<int> seenIds = (prefs.getStringList(keySeenIds) ?? [])
          .map((e) => int.parse(e))
          .toList();

      // Clear if exhausted
      if (seenIds.length >= totalHadiths) {
        seenIds = [];
      }

      // 3. Find a new random ID not in seenIds
      String seenIdsStr = seenIds.join(',');
      int remaining = totalHadiths - seenIds.length;
      int randomOffset = DateTime.now().millisecondsSinceEpoch % remaining;
      
      final List<Map<String, dynamic>> results = await db.rawQuery(
        seenIds.isEmpty 
          ? 'SELECT * FROM hadiths LIMIT 1 OFFSET $randomOffset'
          : 'SELECT * FROM hadiths WHERE id NOT IN ($seenIdsStr) LIMIT 1 OFFSET $randomOffset'
      );

      if (results.isNotEmpty) {
        final hadith = results.first;
        final newId = hadith['id'] as int;
        
        // Save state
        seenIds.add(newId);
        await prefs.setString(keyLastDate, todayStr);
        await prefs.setInt(keyCurrentId, newId);
        await prefs.setStringList(keySeenIds, seenIds.map((e) => e.toString()).toList());
        
        return hadith;
      }
    } catch (e) {
      debugPrint("Error fetching Bukhari hadith: $e");
    }
    return null;
  }
}