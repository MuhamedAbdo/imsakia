import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/custom_occasion.dart';

class CustomOccasionService {
  static const String _storageKey = 'custom_occasions';

  /// الحصول على جميع المناسبات المخصصة المحفوظة
  static Future<List<CustomOccasion>> getOccasions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_storageKey);
      if (data == null) return [];

      final List<dynamic> jsonList = json.decode(data);
      return jsonList
          .map((e) => CustomOccasion.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting custom occasions: $e');
      return [];
    }
  }

  /// إضافة مناسبة جديدة
  static Future<bool> addOccasion(CustomOccasion occasion) async {
    try {
      final List<CustomOccasion> occasions = await getOccasions();
      occasions.add(occasion);
      return await _saveOccasions(occasions);
    } catch (e) {
      debugPrint('Error adding custom occasion: $e');
      return false;
    }
  }

  /// حذف مناسبة بناءً على المعرف
  static Future<bool> deleteOccasion(String id) async {
    try {
      final List<CustomOccasion> occasions = await getOccasions();
      occasions.removeWhere((element) => element.id == id);
      return await _saveOccasions(occasions);
    } catch (e) {
      debugPrint('Error deleting custom occasion: $e');
      return false;
    }
  }

  /// حفظ القائمة في SharedPreferences
  static Future<bool> _saveOccasions(List<CustomOccasion> occasions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String data =
          json.encode(occasions.map((e) => e.toJson()).toList());
      return await prefs.setString(_storageKey, data);
    } catch (e) {
      debugPrint('Error saving custom occasions: $e');
      return false;
    }
  }
}
