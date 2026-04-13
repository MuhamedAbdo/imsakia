import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class BukhariDatabaseService {
  static Database? _db;
  static Completer<Database>? _initCompleter;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    if (_initCompleter == null) {
      _initCompleter = Completer<Database>();
      _initDb().then((db) {
        _db = db;
        _initCompleter!.complete(db);
      }).catchError((e) {
        _initCompleter!.completeError(e);
        _initCompleter = null; // allow retry
      });
    }
    return _initCompleter!.future;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, "ara-bukhari.sqlite");

    bool needsCopy = false;
    final exists = await databaseExists(path);
    if (!exists) {
      needsCopy = true;
    } else {
      try {
        final db = await openDatabase(path);
        // التحقق من وجود جدول الأحاديث وأن قاعدة البيانات غير تالفة
        await db.rawQuery('SELECT 1 FROM hadiths LIMIT 1');
        await db.close();
      } catch (e) {
        debugPrint("Bukhari DB corruption detected, deleting... $e");
        needsCopy = true;
        await deleteDatabase(path);
      }
    }

    if (needsCopy) {
      debugPrint("Copying Bukhari DB from assets...");
      ByteData data = await rootBundle.load("assets/data/ara-bukhari.sqlite");
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(path).writeAsBytes(bytes, flush: true);
    }
    return await openDatabase(path);
  }

  static Future<Map<String, dynamic>?> getDailyHadith() async {
    try {
      final db = await database;
      
      // 1. معرفة عدد الأحاديث الكلي
      final countResult = await db.rawQuery('SELECT COUNT(*) as total FROM hadiths');
      int totalHadiths = countResult.first['total'] as int;

      if (totalHadiths == 0) return null;

      // 2. حساب مؤشر (Index) ثابت لكل يوم
      // نستخدم عدد الأيام منذ بداية التاريخ الميلادي لضمان التغير اليومي
      final now = DateTime.now();
      final int dayOfYear = DateTime(now.year, now.month, now.day).difference(DateTime(1970)).inDays;
      
      // العملية الحسابية لضمان عدم التكرار إلا بعد انتهاء القائمة
      final int targetIndex = dayOfYear % totalHadiths;

      // 3. جلب الحديث باستخدام OFFSET (لتجنب الثغرات في أرقام الـ ID)
      final List<Map<String, dynamic>> results = await db.rawQuery(
          'SELECT text FROM hadiths LIMIT 1 OFFSET $targetIndex'
      );

      if (results.isNotEmpty) {
        return results.first;
      }
    } catch (e) {
      debugPrint("خطأ في جلب حديث اليوم: $e");
    }
    return null;
  }
}