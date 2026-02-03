import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:imsakia/data/clothes_azkar.dart';
import 'package:imsakia/data/entry_azkar.dart';
import 'package:imsakia/data/evening_azkar.dart';
import 'package:imsakia/data/food_azkar.dart';
import 'package:imsakia/data/hajj_azkar.dart';
import 'package:imsakia/data/morning_azkar.dart';
import 'package:imsakia/data/prayer_azkar.dart';
import 'package:imsakia/data/prophetic_duas.dart';
import 'package:imsakia/data/sleep_azkar.dart';
import 'package:imsakia/data/tasbih_azkar.dart';
import 'package:imsakia/data/total_duas.dart';
import 'package:imsakia/data/wakeup_azkar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/azkar.dart';
import '../utils/logger.dart';

class AzkarService {
  static AzkarService? _instance;
  static AzkarService get instance => _instance ??= AzkarService._();

  AzkarService._();

  List<AzkarCategory> _categories = [];
  StreamController<List<AzkarCategory>>? _categoriesController;
  Timer? _saveTimer;
  bool _isInitialized = false;

  Stream<List<AzkarCategory>> get categoriesStream =>
      (_categoriesController ??=
              StreamController<List<AzkarCategory>>.broadcast())
          .stream;

  List<AzkarCategory> get categories => List.unmodifiable(_categories);

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) {
      Logger.debug('AzkarService already initialized');
      return;
    }

    try {
      // Use fallback data directly for now to avoid JSON loading issues
      Logger.info('Using hardcoded fallback Azkar...');
      _loadFallbackData();
      await _loadSavedProgress();
      _isInitialized = true;
      Logger.success('AzkarService initialized successfully');
    } catch (e) {
      Logger.error('Error initializing AzkarService: $e');
      // Load fallback data if JSON loading fails
      _loadFallbackData();
      _isInitialized = true;
    }
  }

  void _loadFallbackData() {
    Logger.info('Loading hardcoded fallback Azkar...');

    _categories = [
     AzkarCategory(
        id: 'morning',
        title: 'أذكار الصباح',
        description: 'الأذكار المستحبة في الصباح',
        icon: Icons.wb_sunny,
        color: Color(0xFFFFD700),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
        ),
        azkar: morningAzkarList, // <-- هنا الاستدعاء السحري! سطر واحد بدل 100 سطر
      ),
      AzkarCategory(
        id: 'evening',
        title: 'أذكار المساء',
        description: 'الأذكار المستحبة في المساء',
        icon: Icons.nightlight_round,
        color: Color(0xFF1E3A8A),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
        ),
        azkar: eveningAzkarList,
      ),
      AzkarCategory(
        id: 'prayer',
        title: 'أذكار الصلاة',
        description: 'الأذكار بعد الصلاة المكتوبة',
        icon: Icons.mosque,
        color: Color(0xFF10B981),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        ),
        azkar:prayerAzkarList,
      ),
      AzkarCategory(
        id: 'sleep',
        title: 'أذكار النوم',
        description: 'الأذكار المستحبة قبل النوم',
        icon: Icons.bedtime,
        color: Color(0xFF6B46C1),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6B46C1), Color(0xFF9333EA)],
        ),
        azkar: sleepAzkarList,
      ),
      AzkarCategory(
        id: 'wakeup',
        title: 'أذكار الاستيقاظ',
        description: 'الأذكار المستحبة عند الاستيقاظ من النوم',
        icon: Icons.wb_sunny_outlined,
        color: Color(0xFFF59E0B),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF59E0B), Color(0xFFFF9500)],
        ),
        azkar: wakeupAzkarList,
      ),
      AzkarCategory(
        id: 'food',
        title: 'أذكار الطعام',
        description: 'الأذكار المستحبة قبل وبعد الأكل',
        icon: Icons.restaurant,
        color: Color(0xFFDC2626),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
        ),
        azkar: foodAzkarList,
      ),
      AzkarCategory(
        id: 'home',
        title: 'أذكار الدخول والخروج',
        description: 'الأذكار المستحبة عند الدخول والخروج من المنزل',
        icon: Icons.home,
        color: Color(0xFF059669),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF059669), Color(0xFF10B981)],
        ),
        azkar:entryAzkarList,
      ),
      AzkarCategory(
        id: 'clothes',
        title: 'أذكار اللباس',
        description: 'الأذكار المستحبة عند لبس الثياب',
        icon: Icons.checkroom,
        color: Color(0xFF7C3AED),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
        ),
        azkar: 
        clothesAzkarList,
        )   ,
        // 1. تسابيح
AzkarCategory(
  id: 'tasbih',
  title: 'تسابيح',
  description: 'فضائل التسبيح والذكر المستمر',
  icon: Icons.fingerprint, // أو Icons.repeat
  color: const Color(0xFF009688),
  gradient: const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF009688), Color(0xFF4DB6AC)],
  ),
  azkar: tasbihAzkarList,
),

// 2. جوامع الدعاء
AzkarCategory(
  id: 'total_dua',
  title: 'جوامع الدعاء',
  description: 'أدعية جامعة لخيري الدنيا والآخرة',
  icon: Icons.auto_awesome, 
  color: const Color(0xFFE91E63),
  gradient: const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE91E63), Color(0xFFF06292)],
  ),
  azkar: totalDuasList,
),

// 3. أذكار الحج والعمرة
AzkarCategory(
  id: 'hajj',
  title: 'أذكار الحج والعمرة',
  description: 'الأذكار والأدعية أثناء النسك',
  icon: Icons.explore, // تأكد من وجود مكتبة font_awesome أو استخدم Icons.mosque
  color: const Color(0xFF455A64),
  gradient: const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF455A64), Color(0xFF78909C)],
  ),
  azkar: hajjAzkarList,
),

// 4. أدعية نبوية
AzkarCategory(
  id: 'prophetic_dua',
  title: 'أدعية نبوية',
  description: 'ما ورد عن النبي ﷺ من أدعية',
  icon: Icons.menu_book,
  color: const Color(0xFF8B4513),
  gradient: const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B4513), Color(0xFFA0522D)],
  ),
  azkar: propheticDuasList,
), 
    ];

    Logger.success('Loaded ${_categories.length} fallback Azkar categories');
    _categoriesController?.add(_categories);
  }

  Future<void> _loadSavedProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      for (int i = 0; i < _categories.length; i++) {
        final category = _categories[i];
        final savedProgress = prefs.getString('azkar_progress_${category.id}');

        if (savedProgress != null) {
          final Map<String, dynamic> progress = json.decode(savedProgress);
          final updatedAzkar = category.azkar.map((azkar) {
            final azkarProgress = progress[azkar.id];
            if (azkarProgress != null) {
              return azkar.copyWith(
                currentCount: azkarProgress['currentCount'] as int? ?? 0,
                isCompleted: azkarProgress['isCompleted'] as bool? ?? false,
              );
            }
            return azkar;
          }).toList();

          _categories[i] = category.copyWith(azkar: updatedAzkar);
        }
      }

      _notifyCategoriesChanged();
      Logger.success('Loaded saved Azkar progress');
    } catch (e) {
      Logger.error('Error loading saved Azkar progress: $e');
    }
  }

  Future<void> incrementAzkarCount(String categoryId, String azkarId) async {
    try {
      final categoryIndex = _categories.indexWhere(
        (cat) => cat.id == categoryId,
      );
      if (categoryIndex == -1) return;

      final category = _categories[categoryIndex];
      final azkarIndex = category.azkar.indexWhere(
        (azkar) => azkar.id == azkarId,
      );
      if (azkarIndex == -1) return;

      final azkar = category.azkar[azkarIndex];
      if (azkar.isCompleted) return; // Don't increment if already completed

      final updatedAzkar = azkar.incrementCount();
      final updatedAzkarList = List<Azkar>.from(category.azkar);
      updatedAzkarList[azkarIndex] = updatedAzkar;

      _categories[categoryIndex] = category.copyWith(azkar: updatedAzkarList);

      _notifyCategoriesChanged();
      _scheduleSave();

      Logger.info(
        'Incremented azkar count: $azkarId (${updatedAzkar.currentCount}/${updatedAzkar.target})',
      );
    } catch (e) {
      Logger.error('Error incrementing azkar count: $e');
    }
  }

  Future<void> resetCategoryCounters(String categoryId) async {
    try {
      final categoryIndex = _categories.indexWhere(
        (cat) => cat.id == categoryId,
      );
      if (categoryIndex == -1) return;

      _categories[categoryIndex] = _categories[categoryIndex]
          .resetAllCounters();

      _notifyCategoriesChanged();
      _scheduleSave();

      Logger.info('Reset counters for category: $categoryId');
    } catch (e) {
      Logger.error('Error resetting category counters: $e');
    }
  }

  Future<void> resetAllCounters() async {
    try {
      _categories = _categories
          .map((category) => category.resetAllCounters())
          .toList();

      _notifyCategoriesChanged();
      _scheduleSave();

      Logger.info('Reset all Azkar counters');
    } catch (e) {
      Logger.error('Error resetting all counters: $e');
    }
  }

  AzkarCategory? getCategoryById(String categoryId) {
    try {
      return _categories.firstWhere((category) => category.id == categoryId);
    } catch (e) {
      return null;
    }
  }

  void _notifyCategoriesChanged() {
    _categoriesController?.add(_categories);
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), () {
      _saveProgress();
    });
  }

  Future<void> _saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      for (final category in _categories) {
        final Map<String, dynamic> progress = {};
        for (final azkar in category.azkar) {
          progress[azkar.id] = {
            'currentCount': azkar.currentCount,
            'isCompleted': azkar.isCompleted,
          };
        }

        await prefs.setString(
          'azkar_progress_${category.id}',
          json.encode(progress),
        );
      }

      Logger.info('Saved Azkar progress');
    } catch (e) {
      Logger.error('Error saving Azkar progress: $e');
    }
  }

  void dispose() {
    _saveTimer?.cancel();
    _categoriesController?.close();
    _categoriesController = null;
  }
}
