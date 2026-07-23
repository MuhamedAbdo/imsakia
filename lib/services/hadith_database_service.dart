import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/hadith_item.dart';

/// Singleton service that reads hadiths from the bundled SQLite database.
///
/// Usage:
///   final hadiths = await HadithDatabaseService.instance.getHadiths('bukhari');
class HadithDatabaseService {
  // ── Singleton ────────────────────────────────────────────────
  HadithDatabaseService._();
  static final HadithDatabaseService instance = HadithDatabaseService._();

  // ── Constants ────────────────────────────────────────────────
  static const String _dbAssetPath = 'assets/hadith_database.db.gz';
  static const String _dbFileName  = 'hadith_database.db';
  static const String _table       = 'hadiths';

  Database? _db;
  bool _isInitializing = false;
  
  // Cache for loaded books to avoid repeated DB queries
  final Map<String, List<HadithItem>> _bookCache = {};

  // ── Public API ───────────────────────────────────────────────

  /// جلب جميع أحاديث كتاب معين، مُرتَّبة حسب رقم الحديث.
  Future<List<HadithItem>> getHadiths(String bookKey) async {
    if (_bookCache.containsKey(bookKey)) {
      return _bookCache[bookKey]!;
    }
    final db = await _getDatabase();
    final rows = await db.query(
      _table,
      columns:  ['number', 'hadith', 'description'],
      where:    'book_key = ?',
      whereArgs: [bookKey],
      orderBy:  'number ASC',
    );
    final result = rows.map(_rowToItem).toList();
    _bookCache[bookKey] = result;
    return result;
  }

  /// بحث في أحاديث كتاب معين.
  /// يدعم البحث بالرقم (مطابقة تامة) أو النص (LIKE بعد إزالة التشكيل).
  Future<List<HadithItem>> searchHadiths(String bookKey, String query) async {
    final q = query.trim();
    if (q.isEmpty) return getHadiths(bookKey);

    // Get from cache or DB
    final allHadiths = await getHadiths(bookKey);

    // بحث بالرقم
    final numericId = int.tryParse(q);
    if (numericId != null) {
      final matches = allHadiths.where((h) => h.number == numericId).toList();
      if (matches.isNotEmpty) return matches;
    }

    // Prepare optimized map for Isolate (only IDs and text)
    final Map<int, String> searchMap = {};
    for (final h in allHadiths) {
      searchMap[h.number] = h.hadith;
    }

    // بحث نصي ذكي — يعمل في Isolate لتجنب تجميد الـ UI
    final matchedIds = await compute(_searchIsolateOptimized, {'map': searchMap, 'query': q});

    // Reconstruct list from main memory cache while preserving order
    final idToHadith = {for (var h in allHadiths) h.number: h};
    return matchedIds.map((id) => idToHadith[id]!).toList();
  }

  /// بحث عام في جميع كتب الحديث.
  /// يستخدم عمود clean_hadith للبحث المباشر في قاعدة البيانات بأداء عالي.
  Future<List<HadithItem>> searchAllHadiths(String query, {int limit = 100}) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final cleanQuery = _removeDiacritics(q)
        .replaceAll('إ', 'ا')
        .replaceAll('أ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ة', 'ه');

    final db = await _getDatabase();
    
    // Check if numeric for exact number match across all books
    final numericId = int.tryParse(q);
    
    List<Map<String, Object?>> rows;
    
    if (numericId != null) {
      rows = await db.query(
        _table,
        columns: ['book_key', 'number', 'hadith', 'description'],
        where: 'number = ?',
        whereArgs: [numericId],
        limit: limit,
      );
    } else {
      rows = await db.query(
        _table,
        columns: ['book_key', 'number', 'hadith', 'description'],
        where: 'clean_hadith LIKE ?',
        whereArgs: ['%$cleanQuery%'],
        limit: limit,
      );
    }

    return rows.map(_rowToItem).toList();
  }

  /// جلب حديث واحد برقمه.
  Future<HadithItem?> getHadithByNumber(String bookKey, int number) async {
    final db = await _getDatabase();
    final rows = await db.query(
      _table,
      columns:   ['number', 'hadith', 'description'],
      where:     'book_key = ? AND number = ?',
      whereArgs: [bookKey, number],
      limit:     1,
    );
    if (rows.isEmpty) return null;
    return _rowToItem(rows.first);
  }

  /// عدد الأحاديث في كتاب.
  Future<int> getCount(String bookKey) async {
    final db = await _getDatabase();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM $_table WHERE book_key = ?',
      [bookKey],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ── Internal ─────────────────────────────────────────────────

  Future<Database> _getDatabase() async {
    if (_db != null && _db!.isOpen) return _db!;
    if (_isInitializing) {
      // انتظار قصير ثم إعادة المحاولة
      await Future.delayed(const Duration(milliseconds: 100));
      return _getDatabase();
    }
    _isInitializing = true;
    _db = await _openDatabase();
    _isInitializing = false;
    return _db!;
  }

  Future<Database> _openDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath  = join(docsDir.path, _dbFileName);

    bool needsCopy = !File(dbPath).existsSync();

    if (!needsCopy) {
      // Check if it's the old version without clean_hadith
      final tempDb = await openDatabase(dbPath, readOnly: true);
      try {
        await tempDb.rawQuery('SELECT clean_hadith FROM $_table LIMIT 1');
      } catch (e) {
        needsCopy = true; // Column doesn't exist, need to update
      } finally {
        await tempDb.close();
      }
    }

    if (needsCopy) {
      debugPrint('HadithDB: تحديث قاعدة البيانات من assets ...');
      if (File(dbPath).existsSync()) {
        File(dbPath).deleteSync();
      }
      final data  = await rootBundle.load(_dbAssetPath);
      final compressedBytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final decompressedBytes = gzip.decode(compressedBytes);
      await File(dbPath).writeAsBytes(decompressedBytes, flush: true);
      debugPrint('HadithDB: تم التحديث بنجاح.');
    }

    return openDatabase(
      dbPath,
      readOnly: true, // قاعدة القراءة فقط — لا نكتب فيها
    );
  }

  HadithItem _rowToItem(Map<String, dynamic> row) {
    return HadithItem(
      number:      (row['number']      as int?)    ?? 0,
      hadith:      (row['hadith']      as String?) ?? '',
      description: (row['description'] as String?) ?? '',
      searchTerm:  '', // عمود search_term غير موجود في DB — نُرجع نصاً فارغاً
      bookKey:     (row['book_key']    as String?),
    );
  }

  // ── Isolate search function ──────────────────────────────────

  static List<int> _searchIsolateOptimized(Map<String, dynamic> params) {
    final Map<int, String> searchMap = params['map'] as Map<int, String>;
    final String query = params['query'].toString().toLowerCase();

    final cleanQuery = _removeDiacritics(query)
        .replaceAll('إ', 'ا')
        .replaceAll('أ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي');

    final isNumeric = RegExp(r'^\d+$').hasMatch(query.trim());

    final List<int> exact   = [];
    final List<int> partial = [];

    for (final entry in searchMap.entries) {
      final id = entry.key;
      final text = entry.value;

      if (isNumeric && id.toString() == query.trim()) {
        exact.add(id);
        continue;
      }

      final cleanHadith  = _removeDiacritics(text.toLowerCase())
          .replaceAll('إ', 'ا').replaceAll('أ', 'ا')
          .replaceAll('آ', 'ا').replaceAll('ى', 'ي');

      if (cleanHadith.contains(cleanQuery)) {
        if (isNumeric && id.toString().contains(query.trim())) {
          exact.add(id);
        } else {
          partial.add(id);
        }
      }
    }

    exact.sort();
    partial.sort();
    return [...exact, ...partial];
  }

  static String _removeDiacritics(String text) =>
      text.replaceAll(RegExp(r'[\u064B-\u0652]'), '');
}
