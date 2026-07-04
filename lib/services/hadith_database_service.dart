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

  // ── Public API ───────────────────────────────────────────────

  /// جلب جميع أحاديث كتاب معين، مُرتَّبة حسب رقم الحديث.
  Future<List<HadithItem>> getHadiths(String bookKey) async {
    final db = await _getDatabase();
    final rows = await db.query(
      _table,
      columns:  ['number', 'hadith', 'description'],
      where:    'book_key = ?',
      whereArgs: [bookKey],
      orderBy:  'number ASC',
    );
    return rows.map(_rowToItem).toList();
  }

  /// بحث في أحاديث كتاب معين.
  /// يدعم البحث بالرقم (مطابقة تامة) أو النص (LIKE بعد إزالة التشكيل).
  Future<List<HadithItem>> searchHadiths(String bookKey, String query) async {
    final q = query.trim();
    if (q.isEmpty) return getHadiths(bookKey);

    final db = await _getDatabase();

    // بحث بالرقم
    final numericId = int.tryParse(q);
    if (numericId != null) {
      final rows = await db.query(
        _table,
        columns:   ['number', 'hadith', 'description'],
        where:     'book_key = ? AND number = ?',
        whereArgs: [bookKey, numericId],
      );
      if (rows.isNotEmpty) return rows.map(_rowToItem).toList();
    }

    // بحث نصي ذكي — يعمل في Isolate لتجنب تجميد الـ UI
    final allHadiths = await getHadiths(bookKey);
    return compute(_searchIsolate, {'hadiths': allHadiths.map((h) => h.toJson()).toList(), 'query': q});
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

    // فك ضغط ونسخ الـ DB من assets إلى التخزين المحلي (عند أول تشغيل فقط)
    if (!File(dbPath).existsSync()) {
      debugPrint('HadithDB: فك ضغط ونسخ قاعدة البيانات من assets ...');
      final data  = await rootBundle.load(_dbAssetPath);
      final compressedBytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final decompressedBytes = gzip.decode(compressedBytes);
      await File(dbPath).writeAsBytes(decompressedBytes, flush: true);
      debugPrint('HadithDB: تم فك الضغط والنسخ بنجاح.');
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
    );
  }

  // ── Isolate search function ──────────────────────────────────

  static List<HadithItem> _searchIsolate(Map<String, dynamic> params) {
    final List<dynamic> hadithsJson = params['hadiths'];
    final String query = params['query'].toString().toLowerCase();

    final cleanQuery = _removeDiacritics(query)
        .replaceAll('إ', 'ا')
        .replaceAll('أ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي');

    final isNumeric = RegExp(r'^\d+$').hasMatch(query.trim());

    final List<HadithItem> exact   = [];
    final List<HadithItem> partial = [];

    for (final raw in hadithsJson) {
      final hadith = HadithItem.fromJson(raw as Map<String, dynamic>);

      if (isNumeric && hadith.number.toString() == query.trim()) {
        exact.add(hadith);
        continue;
      }

      final cleanHadith  = _removeDiacritics(hadith.hadith.toLowerCase())
          .replaceAll('إ', 'ا').replaceAll('أ', 'ا')
          .replaceAll('آ', 'ا').replaceAll('ى', 'ي');
      final cleanSearch  = _removeDiacritics(hadith.searchTerm.toLowerCase());
      final cleanDesc    = _removeDiacritics(hadith.description.toLowerCase());

      if (cleanHadith.contains(cleanQuery) ||
          cleanSearch.contains(cleanQuery)  ||
          cleanDesc.contains(cleanQuery)) {
        if (isNumeric && hadith.number.toString().contains(query.trim())) {
          exact.add(hadith);
        } else {
          partial.add(hadith);
        }
      }
    }

    exact.sort((a, b)   => a.number.compareTo(b.number));
    partial.sort((a, b) => a.number.compareTo(b.number));
    return [...exact, ...partial];
  }

  static String _removeDiacritics(String text) =>
      text.replaceAll(RegExp(r'[\u064B-\u0652]'), '');
}
