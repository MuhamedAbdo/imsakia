import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خريطة: اسم الملف القديم → bookKey الجديد
/// تُستخدم في Migration المفاتيح القديمة إلى الجديدة
const Map<String, String> _kLegacyPathToBookKey = {
  'bukhari.json'  : 'bukhari',
  'muslim.json'   : 'muslim',
  'abi_daud.json' : 'abi_daud',
  'ahmed.json'    : 'ahmed',
  'darimi.json'   : 'darimi',
  'ibn_maja.json' : 'ibn_maja',
  'malik.json'    : 'malik',
  'nasai.json'    : 'nasai',
  'trmizi.json'   : 'trmizi',
};

class BookmarkService {
  static const String _bookmarkPrefix = 'bookmarks_';
  static const String _migrationDoneKey = 'bookmark_migration_v2_done';

  // ── Migration ────────────────────────────────────────────────

  /// يُستدعى مرة واحدة فقط عند تهيئة التطبيق.
  /// ينقل العلامات المرجعية من المفاتيح القديمة (bookmarks_bukhari.json)
  /// إلى المفاتيح الجديدة (bookmarks_bukhari).
  static Future<void> migrateIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyMigrated = prefs.getBool(_migrationDoneKey) ?? false;
      if (alreadyMigrated) return;

      debugPrint('🔄 BookmarkService: تشغيل Migration ...');
      int migratedCount = 0;

      for (final entry in _kLegacyPathToBookKey.entries) {
        final oldKey = '$_bookmarkPrefix${entry.key}'; // bookmarks_bukhari.json
        final newKey = '$_bookmarkPrefix${entry.value}'; // bookmarks_bukhari

        final oldData = prefs.getString(oldKey);
        if (oldData != null) {
          // نقل البيانات إلى المفتاح الجديد (دمج إن وُجدت بيانات جديدة)
          final oldList = json.decode(oldData) as List<dynamic>;
          final existingJson = prefs.getString(newKey) ?? '[]';
          final existingList = json.decode(existingJson) as List<dynamic>;
          final merged = <int>{
            ...oldList.map((e) => e as int),
            ...existingList.map((e) => e as int),
          }.toList();
          await prefs.setString(newKey, json.encode(merged));
          await prefs.remove(oldKey);
          migratedCount++;
          debugPrint('   ✅ نُقل ${merged.length} bookmark من $oldKey → $newKey');
        }
      }

      await prefs.setBool(_migrationDoneKey, true);
      debugPrint('✅ BookmarkService: Migration اكتمل — $migratedCount كتاب تأثر');
    } catch (e) {
      debugPrint('❌ BookmarkService Migration Error: $e');
    }
  }

  // ── Public API ────────────────────────────────────────────────

  /// الحصول على مفتاح التخزين بناءً على bookKey
  static String _getBookKey(String bookKey) => '$_bookmarkPrefix$bookKey';

  /// حفظ أو إزالة علامة مرجعية لحديث في كتاب معين
  static Future<bool> toggleBookmark(String bookKey, int hadithNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getBookKey(bookKey);

      final bookmarksJson = prefs.getString(key) ?? '[]';
      final List<dynamic> bookmarksList = json.decode(bookmarksJson);
      final Set<int> bookmarks = Set<int>.from(bookmarksList.map((e) => e as int));

      if (bookmarks.contains(hadithNumber)) {
        bookmarks.remove(hadithNumber);
      } else {
        bookmarks.add(hadithNumber);
      }

      await prefs.setString(key, json.encode(bookmarks.toList()));
      return bookmarks.contains(hadithNumber);
    } catch (e) {
      debugPrint('❌ Error toggling bookmark: $e');
      return false;
    }
  }

  /// التحقق مما إذا كان الحديث محفوظاً كعلامة مرجعية
  static Future<bool> isBookmarked(String bookKey, int hadithNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getBookKey(bookKey);
      final bookmarksJson = prefs.getString(key) ?? '[]';
      final List<dynamic> bookmarksList = json.decode(bookmarksJson);
      return bookmarksList.map((e) => e as int).contains(hadithNumber);
    } catch (e) {
      debugPrint('Error checking bookmark: $e');
      return false;
    }
  }

  /// الحصول على جميع الأحاديث المحفوظة في كتاب معين
  static Future<Set<int>> getBookmarks(String bookKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getBookKey(bookKey);
      final bookmarksJson = prefs.getString(key) ?? '[]';
      final List<dynamic> bookmarksList = json.decode(bookmarksJson);
      return Set<int>.from(bookmarksList.map((e) => e as int));
    } catch (e) {
      debugPrint('❌ Error getting bookmarks: $e');
      return <int>{};
    }
  }

  /// الحصول على قائمة مرتبة من أرقام الأحاديث المحفوظة
  static Future<List<int>> getBookmarkedHadithNumbers(String bookKey) async {
    final bookmarks = await getBookmarks(bookKey);
    return bookmarks.toList()..sort();
  }

  /// الحصول على عدد الأحاديث المحفوظة في كتاب معين
  static Future<int> getBookmarksCount(String bookKey) async {
    final bookmarks = await getBookmarks(bookKey);
    return bookmarks.length;
  }

  /// مسح جميع العلامات المرجعية لكتاب معين
  static Future<bool> clearBookmarks(String bookKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_getBookKey(bookKey));
      return true;
    } catch (e) {
      debugPrint('Error clearing bookmarks: $e');
      return false;
    }
  }

  /// الحصول على إحصائيات العلامات المرجعية لجميع الكتب
  static Future<Map<String, int>> getAllBookmarksStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final Map<String, int> stats = {};
      for (final key in keys) {
        if (key.startsWith(_bookmarkPrefix) && key != _migrationDoneKey) {
          final bookmarksJson = prefs.getString(key) ?? '[]';
          final List<dynamic> bookmarksList = json.decode(bookmarksJson);
          final bookName = key.replaceFirst(_bookmarkPrefix, '');
          stats[bookName] = bookmarksList.length;
        }
      }
      return stats;
    } catch (e) {
      debugPrint('Error getting bookmarks stats: $e');
      return {};
    }
  }
}
