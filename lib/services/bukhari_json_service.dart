import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class BukhariJsonService {
  static List<dynamic>? _hadithsCache;
  static Completer<void>? _initCompleter;

  /// تهيئة الخدمة وتحميل بيانات الأحاديث
  static Future<void> initialize() async {
    if (_hadithsCache != null) return;
    
    if (_initCompleter == null) {
      _initCompleter = Completer<void>();
      try {
        final jsonString = await rootBundle.loadString('assets/data/bukhari.json');
        final jsonData = json.decode(jsonString);
        _hadithsCache = jsonData is List ? jsonData : [jsonData];
        _initCompleter!.complete();
      } catch (e) {
        debugPrint("Error loading Bukhari JSON: $e");
        _initCompleter!.completeError(e);
        _initCompleter = null;
      }
    }
    return _initCompleter!.future;
  }

  /// الحصول على حديث اليوم بناءً على اليوم الحالي
  static Future<Map<String, dynamic>?> getDailyHadith() async {
    await initialize();
    
    if (_hadithsCache == null || _hadithsCache!.isEmpty) {
      return null;
    }

    try {
      // حساب مؤشر ثابت لكل يوم بناءً على التاريخ
      final now = DateTime.now();
      final int dayOfYear = DateTime(now.year, now.month, now.day).difference(DateTime(1970)).inDays;
      final int targetIndex = dayOfYear % _hadithsCache!.length;

      final hadith = _hadithsCache![targetIndex];
      
      // التأكد من أن الحديث يحتوي على الحقول المطلوبة
      if (hadith is Map<String, dynamic>) {
        return {
          'text': hadith['hadith'] ?? hadith['text'] ?? '',
          'id': hadith['number'] ?? hadith['id'] ?? (targetIndex + 1),
        };
      }
    } catch (e) {
      debugPrint("Error getting daily hadith: $e");
    }
    
    return null;
  }

  /// مسح الـ cache (للاختبار فقط)
  static void clearCache() {
    _hadithsCache = null;
    _initCompleter = null;
  }
}
