import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/athan_model.dart';

/// العقد (Abstract contract) لمصدر بيانات الأذان
abstract class AthanRemoteDataSource {
  Future<List<AthanModel>> fetchAthans();
  Future<List<AthanModel>> getCachedAthans();
}

/// التطبيق الفعلي باستخدام حزمة http والتخزين المؤقت المحلي
class AthanRemoteDataSourceImpl implements AthanRemoteDataSource {
  static const String _apiUrl =
      'https://gist.githubusercontent.com/MuhamedAbdo/11e230a238e9648bcc22cb37f941555a/raw/athan_api.json';
  static const String _cacheKey = 'cached_athan_api_json';
  static const String _cacheFileName = 'athan_api_cache.json';

  final http.Client _client;

  AthanRemoteDataSourceImpl({http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<List<AthanModel>> fetchAthans() async {
    final response = await _client
        .get(
          Uri.parse(_apiUrl),
          headers: {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final rawBody = utf8.decode(response.bodyBytes);
      // حفظ نسخة من الـ JSON محلياً (SharedPreferences + ملف محلي)
      await _saveToCache(rawBody);

      final List<dynamic> jsonList = jsonDecode(rawBody) as List<dynamic>;
      return jsonList
          .map((e) => AthanModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception(
          'فشل تحميل قائمة الأذانات (كود الخطأ: ${response.statusCode})');
    }
  }

  /// حفظ الـ JSON محلياً في SharedPreferences وملف محلي
  Future<void> _saveToCache(String rawJson) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, rawJson);
    } catch (e) {
      debugPrint('[AthanRemoteDataSource] Error saving to SharedPreferences: $e');
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_cacheFileName');
      await file.writeAsString(rawJson);
    } catch (e) {
      debugPrint('[AthanRemoteDataSource] Error saving to file: $e');
    }
  }

  @override
  Future<List<AthanModel>> getCachedAthans() async {
    // 1. محاولة القراءة من SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson != null && cachedJson.trim().isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(cachedJson) as List<dynamic>;
        return jsonList
            .map((e) => AthanModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[AthanRemoteDataSource] Error reading from SharedPreferences: $e');
    }

    // 2. محاولة القراءة من الملف المحلي في ApplicationDocumentsDirectory
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_cacheFileName');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List<dynamic> jsonList = jsonDecode(content) as List<dynamic>;
          return jsonList
              .map((e) => AthanModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[AthanRemoteDataSource] Error reading cache file: $e');
    }

    return [];
  }
}
