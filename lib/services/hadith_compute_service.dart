import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/hadith_item.dart';

/// خدمة معالجة بيانات الأحاديث في الخلفية لضمان سلاسة الأداء
class HadithComputeService {
  
  /// معالجة ملف JSON وتحويله إلى قائمة من الأحاديث
  /// تعمل في Isolate منفصل لتجنب تجميد الواجهة
  static Future<List<HadithItem>> parseHadithsFromJson(String jsonString) async {
    return await compute(_parseHadithsIsolate, jsonString);
  }

  /// دالة معالجة الـ JSON (تعمل في Isolate منفصل)
  static List<HadithItem> _parseHadithsIsolate(String jsonString) {
    try {
      final List<dynamic> jsonData = json.decode(jsonString);
      final List<HadithItem> hadiths = [];

      for (var item in jsonData) {
        try {
          final hadith = HadithItem.fromJson(item as Map<String, dynamic>);
          hadiths.add(hadith);
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing hadith item: $e');
          }
          // تجاهل العناصر التالفة والمتابعة
          continue;
        }
      }

      return hadiths;
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing JSON: $e');
      }
      return [];
    }
  }

  /// البحث عن الأحاديث بناءً على نص البحث
  static Future<List<HadithItem>> searchHadiths(
    List<HadithItem> hadiths,
    String query,
  ) async {
    if (query.isEmpty) return hadiths;
    
    return await compute(_searchHadithsIsolate, {
      'hadiths': hadiths.map((h) => h.toJson()).toList(),
      'query': query.toLowerCase(),
    });
  }

  /// دالة البحث (تعمل في Isolate منفصل)
  static List<HadithItem> _searchHadithsIsolate(Map<String, dynamic> params) {
    final List<dynamic> hadithsJson = params['hadiths'];
    final String query = params['query'];
    
    final List<HadithItem> results = [];
    
    for (var item in hadithsJson) {
      final hadith = HadithItem.fromJson(item as Map<String, dynamic>);
      
      if (hadith.hadith.toLowerCase().contains(query) ||
          hadith.searchTerm.toLowerCase().contains(query) ||
          hadith.description.toLowerCase().contains(query)) {
        results.add(hadith);
      }
    }
    
    return results;
  }

  /// تصفية الأحاديث حسب النطاق المحدد
  static Future<List<HadithItem>> getHadithsByRange(
    List<HadithItem> hadiths,
    int startNumber,
    int endNumber,
  ) async {
    return await compute(_filterByRangeIsolate, {
      'hadiths': hadiths.map((h) => h.toJson()).toList(),
      'start': startNumber,
      'end': endNumber,
    });
  }

  /// دالة التصفية حسب النطاق (تعمل في Isolate منفصل)
  static List<HadithItem> _filterByRangeIsolate(Map<String, dynamic> params) {
    final List<dynamic> hadithsJson = params['hadiths'];
    final int start = params['start'];
    final int end = params['end'];
    
    final List<HadithItem> results = [];
    
    for (var item in hadithsJson) {
      final hadith = HadithItem.fromJson(item as Map<String, dynamic>);
      
      if (hadith.number >= start && hadith.number <= end) {
        results.add(hadith);
      }
    }
    
    return results;
  }
}
