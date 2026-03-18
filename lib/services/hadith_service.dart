import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/hadith_model.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

class HadithService extends ChangeNotifier {
  static HadithService? _instance;
  static HadithService get instance => _instance ??= HadithService._();

  HadithService._();

  List<Hadith> _hadiths = [];
  List<Hadith> _ramadanHadiths = [];
  Hadith? _todayHadith;
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

  Future<void> _updateTodayHadith(int adjustment) async {
    if (_hadiths.isEmpty) return;

    try {
      _currentAdjustment = adjustment;
      final now = DateTime.now();
      final hijriDate = HijriCalendar.fromDate(now);
      hijriDate.hDay += adjustment;

      final int hijriDay = hijriDate.hDay;
      final int hijriMonth = hijriDate.hMonth;
      final int currentHijriYear = hijriDate.hYear;
      final String todayKey = "${now.year}-${now.month}-${now.day}_adj$adjustment";

      final prefs = await SharedPreferences.getInstance();
      const String keyLastDate = 'hadith_last_date';
      const String keyCurrentText = 'hadith_current_text';
      const String keySeenRamadan = 'hadith_seen_ramadan';

      // 1. Check if we already picked one for today
      if (prefs.getString(keyLastDate) == todayKey) {
        final cachedText = prefs.getString(keyCurrentText);
        if (cachedText != null) {
          // Find which list it belongs to and set it
          Hadith? found;
          if (hijriMonth == 9) {
            found = _ramadanHadiths.firstWhere((h) => h.text == cachedText, orElse: () => _ramadanHadiths[0]);
          } else {
            found = _hadiths.firstWhere((h) => h.text == cachedText, orElse: () => _hadiths[0]);
          }
          
          if (_todayHadith?.text != found.text) {
             _todayHadith = found;
             notifyListeners();
          }
          return;
        }
      }

      Hadith selectedHadith;

      // 2. Ramadan Logic (Month 9)
      if (hijriMonth == 9 && _ramadanHadiths.isNotEmpty) {
        // Special focus for Laylat al-Qadr (26, 27, 28 Ramadan)
        if (hijriDay == 26 || hijriDay == 27 || hijriDay == 28) {
          // IDs 25, 26, 27, 28 are Laylat al-Qadr hadiths (indices 24-27)
          final qadrIndices = [24, 25, 26, 27];
          final randomIndex = qadrIndices[now.minute % qadrIndices.length];
          selectedHadith = _ramadanHadiths[randomIndex];
        } else {
          // Non-repeating random for other Ramadan days
          List<String> seenIds = prefs.getStringList(keySeenRamadan) ?? [];
          if (seenIds.length >= _ramadanHadiths.length) seenIds = [];

          final available = _ramadanHadiths.where((h) => !seenIds.contains(h.id.toString())).toList();
          if (available.isEmpty) {
            selectedHadith = _ramadanHadiths[now.millisecond % _ramadanHadiths.length];
          } else {
            selectedHadith = available[now.millisecondsSinceEpoch % available.length];
          }
          
          seenIds.add(selectedHadith.id.toString());
          await prefs.setStringList(keySeenRamadan, seenIds);
        }
      } else {
        // 3. Default logic for other months (Circular based on day/year)
        final int index = ((hijriDay - 1) + ((currentHijriYear % 4) * 30)) % _hadiths.length;
        selectedHadith = _hadiths[index];
      }

      // 4. Save state
      _todayHadith = selectedHadith;
      await prefs.setString(keyLastDate, todayKey);
      await prefs.setString(keyCurrentText, selectedHadith.text);
      notifyListeners();

    } catch (e) {
      Logger.error('Error updating today hadith: $e');
      if (_todayHadith == null && _hadiths.isNotEmpty) {
        _todayHadith = _hadiths[0];
        notifyListeners();
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
