import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/hadith_model.dart';
import 'package:hijri/hijri_calendar.dart';
import '../utils/logger.dart';

class HadithService extends ChangeNotifier {
  static HadithService? _instance;
  static HadithService get instance => _instance ??= HadithService._();

  HadithService._();

  List<Hadith> _hadiths = [];
  List<Hadith> _ramadanHadiths = [];
  Hadith? _todayHadith;
  int? _lastCalculatedIndex;
  bool _isInitialized = false;
  int _currentAdjustment = 0;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await loadHadiths();
      await loadRamadanHadiths(); // Load Ramadan specifically
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

  Future<void> loadRamadanHadiths() async {
    try {
      final String data = await rootBundle
          .loadString('assets/data/ramadan_hadiths.json')
          .timeout(const Duration(seconds: 3));
      final List<dynamic> jsonList = json.decode(data);
      _ramadanHadiths = jsonList.map((e) => Hadith.fromJson(e)).toList();
    } catch (e) {
      Logger.error('Error loading ramadan hadiths: $e');
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
      final hijriDate = HijriCalendar.fromDate(now);
      hijriDate.hDay += adjustment; // Apply adjustment to day

      final int hijriDay = hijriDate.hDay;
      final int hijriMonth = hijriDate.hMonth;
      final int currentHijriYear = hijriDate.hYear;

      int newIndex;
      Hadith selectedHadith;

      // Special logic for Ramadan
      if (hijriMonth == 9 && _ramadanHadiths.isNotEmpty) {
        // Use Ramadan file, circular index matching the day (1-30)
        newIndex = (hijriDay - 1) % _ramadanHadiths.length;
        selectedHadith = _ramadanHadiths[newIndex];
      } else {
        // Default logic for other months
        newIndex =
            ((hijriDay - 1) + ((currentHijriYear % 4) * 30)) % _hadiths.length;
        selectedHadith = _hadiths[newIndex];
      }

      if (_lastCalculatedIndex != newIndex || _todayHadith?.text != selectedHadith.text) {
        _lastCalculatedIndex = newIndex;
        _todayHadith = selectedHadith;

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
