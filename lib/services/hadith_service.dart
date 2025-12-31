import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/hadith_model.dart';
import 'hijri_date_service.dart';

class HadithService extends ChangeNotifier {
  static HadithService? _instance;
  static HadithService get instance => _instance ??= HadithService._();

  HadithService._();

  List<Hadith> _hadiths = [];
  Hadith? _todayHadith;
  int? _lastCalculatedIndex;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      print('✅ HadithService already initialized');
      return;
    }

    try {
      await loadHadiths();
      _isInitialized = true;
      print('✅ HadithService initialized successfully');
    } catch (e) {
      print('❌ Error initializing HadithService: $e');
      // Set fallback hadith if loading fails
      _todayHadith = Hadith(
        id: 1,
        text: 'قال ﷺ: إنما الأعمال بالنيات، وإنما لكل امرئ ما نوى.',
        source: 'متفق عليه',
      );
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> loadHadiths() async {
    try {
      print('🔄 Loading hadiths from assets/data/hadiths.json...');

      // Load hadiths with timeout
      final String hadithsString = await rootBundle.loadString('assets/data/hadiths.json')
          .timeout(const Duration(seconds: 3), onTimeout: () {
        throw TimeoutException('Timeout loading hadiths.json', const Duration(seconds: 3));
      });

      // Parse JSON with null safety
      final dynamic hadithsJson = json.decode(hadithsString);

      // Check if parsed data is a List
      if (hadithsJson is! List) {
        throw FormatException('hadiths.json is not a valid array');
      }

      final List<dynamic> hadithsList = hadithsJson;

      if (hadithsList.isEmpty) {
        print('⚠️ hadiths.json is empty, using fallback data');
        _loadFallbackHadiths();
        return;
      }

      _hadiths = hadithsList.map((data) {
        if (data is! Map<String, dynamic>) {
          throw FormatException('Invalid hadith data format');
        }
        return Hadith.fromJson(data);
      }).toList();

      print('✅ Loaded ${_hadiths.length} hadiths from hadiths.json');

      // Calculate today's hadith after loading
      _updateTodayHadith();

    } catch (e) {
      print('❌ Error loading hadiths from hadiths.json: $e');
      print('🔄 Falling back to hardcoded hadiths...');
      _loadFallbackHadiths();
    }
  }

  void _loadFallbackHadiths() {
    _hadiths = [
      Hadith(id: 1, text: 'قال ﷺ: إنما الأعمال بالنيات، وإنما لكل امرئ ما نوى.', source: 'متفق عليه'),
      Hadith(id: 2, text: 'قال ﷺ: من حسن إسلام المرء تركه ما لا يعنيه.', source: 'الترمذي'),
      Hadith(id: 3, text: 'قال ﷺ: لا يؤمن أحدكم حتى يحب لأخيه ما يحب لنفسه.', source: 'البخاري ومسلم'),
      Hadith(id: 4, text: 'قال ﷺ: إن الله طيب لا يقبل إلا طيباً.', source: 'مسلم'),
      Hadith(id: 5, text: 'قال ﷺ: البر حسن الخلق، والإثم ما حاك في صدرك وكرهت أن يطلع عليه الناس.', source: 'مسلم'),
    ];
    print('✅ Loaded ${_hadiths.length} fallback hadiths');
    _updateTodayHadith();
  }

  void _updateTodayHadith() {
    if (_hadiths.isEmpty) return;

    try {
      final now = DateTime.now();
      final hijriAdjustment = 0; // Default adjustment
      final hijriDate = HijriDateService.getHijriDate(now, hijriAdjustment);
      final hijriDay = int.parse(hijriDate['day'] as String);
      final currentHijriYear = int.parse(hijriDate['year'] as String);

      // Calculate what the current hadith should be
      final int newIndex = ((hijriDay - 1) + ((currentHijriYear % 4) * 30)) % _hadiths.length;

      // Only update if index actually changed
      if (_lastCalculatedIndex != newIndex) {
        print('🔄 Hadith index changed from $_lastCalculatedIndex to $newIndex - Updating');
        _lastCalculatedIndex = newIndex;
        _todayHadith = _hadiths[newIndex];
        notifyListeners();
      } else {
        print('📋 Hadith index unchanged ($newIndex) - No update needed');
      }
    } catch (e) {
      print('❌ Error updating today hadith: $e');
      // Set first hadith as fallback
      if (_hadiths.isNotEmpty && _todayHadith == null) {
        _todayHadith = _hadiths[0];
        notifyListeners();
      }
    }
  }

  // Public method to check and update hadith (for timer calls)
  void checkAndUpdateHadith() {
    if (_isInitialized) {
      _updateTodayHadith();
    }
  }

  // Public method to force update hadith
  void forceUpdateHadith() {
    _lastCalculatedIndex = null; // Reset to force update
    _updateTodayHadith();
  }

  Hadith? getTodayHadith() {
    return _todayHadith;
  }

  List<Hadith> getAllHadiths() {
    return _hadiths;
  }

  Hadith? getHadithById(int id) {
    try {
      return _hadiths.firstWhere((hadith) => hadith.id == id);
    } catch (e) {
      return null;
    }
  }

  Hadith getRandomHadith() {
    if (_hadiths.isEmpty) {
      return Hadith(
        id: 1,
        text: 'قال ﷺ: إنما الأعمال بالنيات، وإنما لكل امرئ ما نوى.',
        source: 'متفق عليه',
      );
    }

    final random = DateTime.now().millisecondsSinceEpoch % _hadiths.length;
    return _hadiths[random];
  }

  // Get current hadith index for debugging
  int? getCurrentIndex() {
    return _lastCalculatedIndex;
  }

  bool get isInitialized => _isInitialized;
}