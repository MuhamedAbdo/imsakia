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

  /// البحث عن الأحاديث مع إعطاء الأولوية للأرقام
  static Future<List<HadithItem>> searchHadithsWithPriority(
    List<HadithItem> hadiths,
    String query,
  ) async {
    if (query.isEmpty) return hadiths;
    
    return await compute(_searchHadithsWithPriorityIsolate, {
      'hadiths': hadiths.map((h) => h.toJson()).toList(),
      'query': query.toLowerCase(),
      'originalQuery': query,
    });
  }

  /// البحث الذكي عن الأحاديث مع إزالة التشكيل
  static Future<List<HadithItem>> searchHadithsWithSmartFilter(
    List<HadithItem> hadiths,
    String query,
  ) async {
    if (query.isEmpty) return hadiths;
    
    return await compute(_searchHadithsWithSmartFilterIsolate, {
      'hadiths': hadiths.map((h) => h.toJson()).toList(),
      'query': query.toLowerCase(),
      'originalQuery': query,
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

  /// دالة البحث مع الأولوية (تعمل في Isolate منفصل)
  static List<HadithItem> _searchHadithsWithPriorityIsolate(Map<String, dynamic> params) {
    final List<dynamic> hadithsJson = params['hadiths'];
    final String query = params['query'];
    final String originalQuery = params['originalQuery'];
    
    final List<HadithItem> exactMatches = [];
    final List<HadithItem> partialMatches = [];
    
    // التحقق مما إذا كان البحث برقم فقط
    final isNumericSearch = RegExp(r'^\d+$').hasMatch(originalQuery.trim());
    
    for (var item in hadithsJson) {
      final hadith = HadithItem.fromJson(item as Map<String, dynamic>);
      
      // البحث في حقل الرقم
      if (hadith.number.toString() == originalQuery.trim()) {
        exactMatches.add(hadith);
        continue;
      }
      
      // البحث في حقول النصوص
      if (hadith.hadith.toLowerCase().contains(query) ||
          hadith.searchTerm.toLowerCase().contains(query) ||
          hadith.description.toLowerCase().contains(query)) {
        
        // إعطاء الأولوية للمطابقات الجزئية للأرقام
        if (isNumericSearch && hadith.number.toString().contains(originalQuery.trim())) {
          exactMatches.add(hadith);
        } else {
          partialMatches.add(hadith);
        }
      }
    }
    
    // ترتيب النتائج: المطابقات التامة أولاً، ثم الجزئية
    exactMatches.sort((a, b) => a.number.compareTo(b.number));
    partialMatches.sort((a, b) => a.number.compareTo(b.number));
    
    return [...exactMatches, ...partialMatches];
  }

  /// دالة البحث الذكي مع إزالة التشكيل (تعمل في Isolate منفصل)
  static List<HadithItem> _searchHadithsWithSmartFilterIsolate(Map<String, dynamic> params) {
    final List<dynamic> hadithsJson = params['hadiths'];
    final String query = params['query'];
    final String originalQuery = params['originalQuery'];
    
    final List<HadithItem> exactMatches = [];
    final List<HadithItem> partialMatches = [];
    
    // إزالة التشكيل من نص البحث
    final queryWithoutDiacritics = _removeDiacriticsFromText(query);
    
    // التحقق مما إذا كان البحث برقم فقط
    final isNumericSearch = RegExp(r'^\d+$').hasMatch(originalQuery.trim());
    
    for (var item in hadithsJson) {
      final hadith = HadithItem.fromJson(item as Map<String, dynamic>);
      
      // البحث في حقل الرقم
      if (hadith.number.toString() == originalQuery.trim()) {
        exactMatches.add(hadith);
        continue;
      }
      
      // البحث في حقول النصوص مع إزالة التشكيل
      final hadithWithoutDiacritics = _removeDiacriticsFromText(hadith.hadith.toLowerCase());
      final searchTermWithoutDiacritics = _removeDiacriticsFromText(hadith.searchTerm.toLowerCase());
      final descriptionWithoutDiacritics = _removeDiacriticsFromText(hadith.description.toLowerCase());
      
      if (hadithWithoutDiacritics.contains(queryWithoutDiacritics) ||
          searchTermWithoutDiacritics.contains(queryWithoutDiacritics) ||
          descriptionWithoutDiacritics.contains(queryWithoutDiacritics)) {
        
        // إعطاء الأولوية للمطابقات الجزئية للأرقام
        if (isNumericSearch && hadith.number.toString().contains(originalQuery.trim())) {
          exactMatches.add(hadith);
        } else {
          partialMatches.add(hadith);
        }
      }
    }
    
    // ترتيب النتائج: المطابقات التامة أولاً، ثم الجزئية
    exactMatches.sort((a, b) => a.number.compareTo(b.number));
    partialMatches.sort((a, b) => a.number.compareTo(b.number));
    
    return [...exactMatches, ...partialMatches];
  }

  /// إزالة التشكيل من النص
  static String _removeDiacriticsFromText(String text) {
    var withDiacritics = RegExp(r'[ًٌٍَُِّْ]');
    return text.replaceAll(withDiacritics, '');
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
