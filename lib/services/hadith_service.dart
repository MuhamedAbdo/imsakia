import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/hadith_model.dart';
import 'hijri_date_service.dart';
import '../utils/logger.dart';

class HadithService extends ChangeNotifier {
  static HadithService? _instance;
  static HadithService get instance => _instance ??= HadithService._();

  HadithService._();

  List<Hadith> _hadiths = [];
  Hadith? _todayHadith;
  int? _lastCalculatedIndex;
  bool _isInitialized = false;
  int _currentAdjustment = 0;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await loadHadiths();
      _isInitialized = true;
      Logger.success('HadithService initialized successfully');
    } catch (e) {
      Logger.error('Error initializing HadithService: $e');
      _loadFallbackHadiths();
      _isInitialized = true;
    }
  }

  Future<void> loadHadiths() async {
    try {
      final String hadithsString = await rootBundle
          .loadString('assets/data/hadiths.json')
          .timeout(const Duration(seconds: 3));

      final List<dynamic> hadithsJson = json.decode(hadithsString);
      _hadiths = hadithsJson.map((data) => Hadith.fromJson(data)).toList();

      if (_hadiths.isEmpty) {
        _loadFallbackHadiths();
      } else {
        _updateTodayHadith(_currentAdjustment);
      }
    } catch (e) {
      _loadFallbackHadiths();
    }
  }

  void _loadFallbackHadiths() {
    _hadiths = [
      Hadith(
        id: 1,
        text: 'قال ﷺ: إنما الأعمال بالنيات، وإنما لكل امرئ ما نوى.',
        source: 'متفق عليه',
      ),
      Hadith(
        id: 2,
        text: 'قال ﷺ: من حسن إسلام المرء تركه ما لا يعنيه.',
        source: 'الترمذي',
      ),
      Hadith(
        id: 3,
        text: 'قال ﷺ: لا يؤمن أحدكم حتى يحب لأخيه ما يحب لنفسه.',
        source: 'البخاري ومسلم',
      ),
    ];
    _updateTodayHadith(_currentAdjustment);
  }

  void _updateTodayHadith(int adjustment) {
    if (_hadiths.isEmpty) return;

    try {
      _currentAdjustment = adjustment;
      final now = DateTime.now();

      // جلب التاريخ الهجري بناءً على التعديل
      final hijriDate = HijriDateService.getHijriDate(now, adjustment);

      // التأكد من تحويل القيم لنوع int بأمان
      final int hijriDay = hijriDate['dayIndex'] ?? 1;
      final int currentHijriYear = hijriDate['hYear'] ?? 1445;

      // معادلة اختيار الحديث بناءً على اليوم الهجري
      final int newIndex =
          ((hijriDay - 1) + ((currentHijriYear % 4) * 30)) % _hadiths.length;

      if (_lastCalculatedIndex != newIndex) {
        _lastCalculatedIndex = newIndex;
        _todayHadith = _hadiths[newIndex];

        // الحل الجذري للخطأ: تأجيل الإشعار باستخدام microtask
        // هذا يضمن أن notifyListeners تُستدعى بعد انتهاء بناء الواجهة الحالية
        Future.microtask(() {
          if (hasListeners) notifyListeners();
        });
      }
    } catch (e) {
      Logger.error('Error updating today hadith: $e');
      if (_todayHadith == null && _hadiths.isNotEmpty) {
        _todayHadith = _hadiths[0];
        Future.microtask(() {
          if (hasListeners) notifyListeners();
        });
      }
    }
  }

  /// تحديث الحديث بناءً على التعديل الهجري (تُستدعى من الـ UI)
  void updateWithAdjustment(int adjustment) {
    if (_isInitialized) {
      _updateTodayHadith(adjustment);
    } else {
      _currentAdjustment = adjustment;
    }
  }

  Hadith? getTodayHadith() => _todayHadith;
  bool get isInitialized => _isInitialized;
}
