import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BookmarkService {
  static const String _bookmarkPrefix = 'bookmarks_';
  
  /// الحصول على مفتاح التخزين للكتاب المحدد
  static String _getBookKey(String jsonPath) {
    // استخراج اسم الملف من المسار لاستخدامه كمفتاح فريد
    final fileName = jsonPath.split('/').last;
    return '$_bookmarkPrefix$fileName';
  }
  
  /// حفظ أو إزالة علامة مرجعية لحديث في كتاب معين
  static Future<bool> toggleBookmark(String jsonPath, int hadithNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getBookKey(jsonPath);
      
      // الحصول على القائمة الحالية للعلامات المرجعية
      final bookmarksJson = prefs.getString(key) ?? '[]';
      final List<dynamic> bookmarksList = json.decode(bookmarksJson);
      final Set<int> bookmarks = Set<int>.from(bookmarksList.map((e) => e as int));
      
      // تبديل حالة العلامة المرجعية
      if (bookmarks.contains(hadithNumber)) {
        bookmarks.remove(hadithNumber); // إزالة العلامة
      } else {
        bookmarks.add(hadithNumber); // إضافة العلامة
      }
      
      // حفظ القائمة المحدثة
      await prefs.setString(key, json.encode(bookmarks.toList()));
      
      return bookmarks.contains(hadithNumber);
    } catch (e) {
      if (kDebugMode) print('Error toggling bookmark: $e');
      return false;
    }
  }
  
  /// التحقق مما إذا كان الحديث محفوظاً كعلامة مرجعية
  static Future<bool> isBookmarked(String jsonPath, int hadithNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getBookKey(jsonPath);
      
      final bookmarksJson = prefs.getString(key) ?? '[]';
      final List<dynamic> bookmarksList = json.decode(bookmarksJson);
      final Set<int> bookmarks = Set<int>.from(bookmarksList.map((e) => e as int));
      
      return bookmarks.contains(hadithNumber);
    } catch (e) {
      if (kDebugMode) print('Error checking bookmark: $e');
      return false;
    }
  }
  
  /// الحصول على جميع الأحاديث المحفوظة في كتاب معين
  static Future<Set<int>> getBookmarks(String jsonPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getBookKey(jsonPath);
      
      final bookmarksJson = prefs.getString(key) ?? '[]';
      final List<dynamic> bookmarksList = json.decode(bookmarksJson);
      
      return Set<int>.from(bookmarksList.map((e) => e as int));
    } catch (e) {
      if (kDebugMode) print('Error getting bookmarks: $e');
      return <int>{};
    }
  }

  /// الحصول على قائمة مرتبة من أرقام الأحاديث المحفوظة
  static Future<List<int>> getBookmarkedHadithNumbers(String jsonPath) async {
    final bookmarks = await getBookmarks(jsonPath);
    return bookmarks.toList()..sort();
  }
  
  /// الحصول على عدد الأحاديث المحفوظة في كتاب معين
  static Future<int> getBookmarksCount(String jsonPath) async {
    final bookmarks = await getBookmarks(jsonPath);
    return bookmarks.length;
  }
  
  /// مسح جميع العلامات المرجعية لكتاب معين
  static Future<bool> clearBookmarks(String jsonPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getBookKey(jsonPath);
      await prefs.remove(key);
      return true;
    } catch (e) {
      if (kDebugMode) print('Error clearing bookmarks: $e');
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
        if (key.startsWith(_bookmarkPrefix)) {
          final bookmarksJson = prefs.getString(key) ?? '[]';
          final List<dynamic> bookmarksList = json.decode(bookmarksJson);
          final fileName = key.replaceFirst(_bookmarkPrefix, '');
          stats[fileName] = bookmarksList.length;
        }
      }
      
      return stats;
    } catch (e) {
      if (kDebugMode) print('Error getting bookmarks stats: $e');
      return {};
    }
  }
}
