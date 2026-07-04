import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/hadith_database_service.dart';

/// خدمة مبسطة لجلب حديث اليوم من البخاري عبر قاعدة البيانات SQLite
class BukhariJsonService {
  static Map<String, dynamic>? _cachedDailyHadith;
  static int? _lastDayOfYear;

  /// الحصول على حديث اليوم بناءً على التاريخ (مع cache يومي)
  static Future<Map<String, dynamic>?> getDailyHadith() async {
    final now = DateTime.now();
    final int dayOfYear = DateTime(now.year, now.month, now.day)
        .difference(DateTime(1970))
        .inDays;

    // إعادة الـ cache إذا كنا في نفس اليوم
    if (_cachedDailyHadith != null && _lastDayOfYear == dayOfYear) {
      return _cachedDailyHadith;
    }

    try {
      final count = await HadithDatabaseService.instance.getCount('bukhari');
      if (count == 0) return null;

      final targetNumber = (dayOfYear % count) + 1;
      final hadith = await HadithDatabaseService.instance
          .getHadithByNumber('bukhari', targetNumber);

      if (hadith != null) {
        _cachedDailyHadith = {
          'text': hadith.hadith,
          'id': hadith.number,
        };
        _lastDayOfYear = dayOfYear;
        return _cachedDailyHadith;
      }
    } catch (e) {
      debugPrint("Error getting daily hadith from DB: $e");
    }

    return null;
  }

  /// مسح الـ cache (للاختبار فقط)
  static void clearCache() {
    _cachedDailyHadith = null;
    _lastDayOfYear = null;
  }
}
