import 'dart:convert';
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
  
  Future<void> loadHadiths() async {
    try {
      // Always load hadiths from JSON
      final String jsonString = await rootBundle.loadString('assets/data/hadiths.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      
      _hadiths = jsonList.map((json) => Hadith.fromJson(json)).toList();
      
      // Calculate today's hadith index
      _calculateTodayHadith();
      
      notifyListeners();
    } catch (e) {
      print('Error loading hadiths: $e');
      // Fallback hadith if loading fails
      _todayHadith = Hadith(
        id: 1,
        text: 'قال ﷺ: إنما الأعمال بالنيات، وإنما لكل امرئ ما نوى.',
        source: 'متفق عليه',
      );
      notifyListeners();
    }
  }
  
  void _calculateTodayHadith() {
    if (_hadiths.isEmpty) return;
    
    final now = DateTime.now();
    final hijriAdjustment = 0; // Default adjustment, can be made configurable
    
    // Get current Hijri date
    final hijriDate = HijriDateService.getHijriDate(now, hijriAdjustment);
    final hijriDay = int.parse(hijriDate['day'] as String);
    final currentHijriYear = int.parse(hijriDate['year'] as String);
    
    // Enhanced index calculation with year cycle for full 120 hadith utilization
    final int index = ((hijriDay - 1) + ((currentHijriYear % 4) * 30)) % _hadiths.length;
    
    // Ensure index is within bounds
    final safeIndex = index % _hadiths.length;
    
    _todayHadith = _hadiths[safeIndex];
    _lastCalculatedIndex = safeIndex;
    
    // Debug logging
    print('📖 Hadith Updated: Day $hijriDay, Year $currentHijriYear, Index $safeIndex, Hadith ID: ${_todayHadith?.id}');
  }
  
  // Check if we need to update the hadith (called periodically)
  void checkAndUpdateHadith() {
    if (_hadiths.isEmpty) return;
    
    final now = DateTime.now();
    final hijriAdjustment = 0;
    final hijriDate = HijriDateService.getHijriDate(now, hijriAdjustment);
    final hijriDay = int.parse(hijriDate['day'] as String);
    final currentHijriYear = int.parse(hijriDate['year'] as String);
    
    // Calculate what the current hadith should be
    final int newIndex = ((hijriDay - 1) + ((currentHijriYear % 4) * 30)) % _hadiths.length;
    
    // Only update if index actually changed
    if (_lastCalculatedIndex != newIndex) {
      print('🔄 Hadith index changed from $_lastCalculatedIndex to $newIndex - Updating');
      _calculateTodayHadith();
      notifyListeners();
    } else {
      print('📋 Hadith index unchanged ($newIndex) - No update needed');
    }
  }
  
  // Force update hadith (safe to call from anywhere)
  void forceUpdateHadith() {
    _calculateTodayHadith();
    notifyListeners();
  }
  
  Hadith? getTodayHadith() {
    // Don't check for updates during build phase to avoid setState() error
    // Updates are handled by the periodic timer in HomeScreen
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
}
