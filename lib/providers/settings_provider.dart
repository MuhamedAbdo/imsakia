import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_constants.dart';
import '../services/prayer_times_service.dart';

enum AppThemeMode { light, dark, system }

class SettingsProvider extends ChangeNotifier {
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  AppThemeMode _themeMode = AppThemeMode.dark;
  String _selectedCity = AppConstants.defaultCity;
  String _selectedCityName = "القاهرة، مصر";
  String _selectedCalculationMethod = AppConstants.defaultCalculationMethod;
  String _selectedMadhab = AppConstants.defaultMadhab;
  bool _dstEnabled = AppConstants.defaultDST;
  bool _notificationsEnabled = true;
  bool _isFirstLaunch = true;
  int _hijriAdjustment = 0;
  bool _autoHijriAdjustment = true;
  double _fontSize = 16.0;
  Set<String> _fiqhBookmarks = {};

  bool _fajrAthanEnabled = true;
  bool _dhuhrAthanEnabled = true;
  bool _asrAthanEnabled = true;
  bool _maghribAthanEnabled = true;
  bool _ishaAthanEnabled = true;

  // Manual Prayer Time Calibration Offsets (Minutes)
  int _prayerOffsetGlobal = 0;
  int _prayerOffsetFajr = 0;
  int _prayerOffsetDhuhr = 0;
  int _prayerOffsetAsr = 0;
  int _prayerOffsetMaghrib = 0;
  int _prayerOffsetIsha = 0;

  // Getters
  AppThemeMode get themeMode => _themeMode;
  String get selectedCity => _selectedCity;
  String get selectedCityName => _selectedCityName;
  String get selectedCalculationMethod => _selectedCalculationMethod;
  String get selectedMadhab => _selectedMadhab;
  bool get dstEnabled => _dstEnabled;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get isFirstLaunch => _isFirstLaunch;
  bool get isInitialized => _isInitialized;
  int get hijriAdjustment => _hijriAdjustment;
  bool get autoHijriAdjustment => _autoHijriAdjustment;

  bool get fajrAthanEnabled => _fajrAthanEnabled;
  bool get dhuhrAthanEnabled => _dhuhrAthanEnabled;
  bool get asrAthanEnabled => _asrAthanEnabled;
  bool get maghribAthanEnabled => _maghribAthanEnabled;
  bool get ishaAthanEnabled => _ishaAthanEnabled;
  double get fontSize => _fontSize;
  Set<String> get fiqhBookmarks => _fiqhBookmarks;

  int get prayerOffsetGlobal => _prayerOffsetGlobal;
  int get prayerOffsetFajr => _prayerOffsetFajr;
  int get prayerOffsetDhuhr => _prayerOffsetDhuhr;
  int get prayerOffsetAsr => _prayerOffsetAsr;
  int get prayerOffsetMaghrib => _prayerOffsetMaghrib;
  int get prayerOffsetIsha => _prayerOffsetIsha;

  Map<String, int> get prayerIndividualOffsets => {
    'fajr': _prayerOffsetFajr,
    'dhuhr': _prayerOffsetDhuhr,
    'asr': _prayerOffsetAsr,
    'maghrib': _prayerOffsetMaghrib,
    'isha': _prayerOffsetIsha,
  };

  int getEffectivePrayerOffset(String prayerKey) {
    if (prayerKey == 'sunrise') return 0;
    int individual = 0;
    switch (prayerKey) {
      case 'fajr':
        individual = _prayerOffsetFajr;
        break;
      case 'dhuhr':
        individual = _prayerOffsetDhuhr;
        break;
      case 'asr':
        individual = _prayerOffsetAsr;
        break;
      case 'maghrib':
        individual = _prayerOffsetMaghrib;
        break;
      case 'isha':
        individual = _prayerOffsetIsha;
        break;
    }
    return (_prayerOffsetGlobal + individual).clamp(-20, 20);
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadSettings();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _setDefaults();
      notifyListeners();
    }
  }

  Future<void> _loadSettings() async {
    _selectedCity =
        _prefs?.getString(AppConstants.selectedCityKey) ??
        AppConstants.defaultCity;
    _selectedCityName =
        _prefs?.getString('selected_city_name') ?? "القاهرة، مصر";

    final savedTheme = _prefs?.getString(AppConstants.themeModeKey) ?? 'dark';
    _themeMode = AppThemeMode.values.firstWhere(
      (mode) => mode.toString().split('.').last == savedTheme,
      orElse: () => AppThemeMode.dark,
    );

    _selectedCalculationMethod =
        _prefs?.getString(AppConstants.calculationMethodKey) ??
        AppConstants.defaultCalculationMethod;
    _selectedMadhab =
        _prefs?.getString(AppConstants.madhabKey) ?? AppConstants.defaultMadhab;
    _dstEnabled =
        _prefs?.getBool(AppConstants.dstKey) ?? AppConstants.defaultDST;
    _notificationsEnabled =
        _prefs?.getBool(AppConstants.notificationsKey) ?? true;

    _hijriAdjustment = _prefs?.getInt(AppConstants.hijriAdjustmentKey) ?? 0;
    _autoHijriAdjustment =
        _prefs?.getBool('auto_hijri_adjustment') ?? (_hijriAdjustment == 0);

    _isFirstLaunch = _prefs?.getBool(AppConstants.isFirstLaunchKey) ?? true;

    _fajrAthanEnabled = _prefs?.getBool('fajr_athan_enabled') ?? true;
    _dhuhrAthanEnabled = _prefs?.getBool('dhuhr_athan_enabled') ?? true;
    _asrAthanEnabled = _prefs?.getBool('asr_athan_enabled') ?? true;
    _maghribAthanEnabled = _prefs?.getBool('maghrib_athan_enabled') ?? true;
    _ishaAthanEnabled = _prefs?.getBool('isha_athan_enabled') ?? true;

    _fontSize = _prefs?.getDouble('fiqh_font_size') ?? 16.0;
    final bookmarksList = _prefs?.getStringList('fiqh_bookmarks') ?? [];
    _fiqhBookmarks = bookmarksList.toSet();

    final offsetsRaw = _prefs?.getString(AppConstants.prayerTimeOffsetsKey);
    if (offsetsRaw != null && offsetsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(offsetsRaw);
        if (decoded is Map<String, dynamic>) {
          _prayerOffsetGlobal = _parseOffset(decoded['global']);
          _prayerOffsetFajr = _parseOffset(decoded['fajr']);
          _prayerOffsetDhuhr = _parseOffset(decoded['dhuhr']);
          _prayerOffsetAsr = _parseOffset(decoded['asr']);
          _prayerOffsetMaghrib = _parseOffset(decoded['maghrib']);
          _prayerOffsetIsha = _parseOffset(decoded['isha']);
        } else {
          _resetPrayerOffsetsInMemory();
        }
      } catch (_) {
        _resetPrayerOffsetsInMemory();
      }
    } else {
      _resetPrayerOffsetsInMemory();
    }
  }

  int _parseOffset(dynamic val) {
    if (val is int) return val.clamp(-15, 15);
    if (val is String) return (int.tryParse(val) ?? 0).clamp(-15, 15);
    return 0;
  }

  void _resetPrayerOffsetsInMemory() {
    _prayerOffsetGlobal = 0;
    _prayerOffsetFajr = 0;
    _prayerOffsetDhuhr = 0;
    _prayerOffsetAsr = 0;
    _prayerOffsetMaghrib = 0;
    _prayerOffsetIsha = 0;
  }

  Future<void> savePrayerOffsets({
    required int global,
    required Map<String, int> individual,
  }) async {
    _prayerOffsetGlobal = global.clamp(-15, 15);
    _prayerOffsetFajr = (individual['fajr'] ?? 0).clamp(-15, 15);
    _prayerOffsetDhuhr = (individual['dhuhr'] ?? 0).clamp(-15, 15);
    _prayerOffsetAsr = (individual['asr'] ?? 0).clamp(-15, 15);
    _prayerOffsetMaghrib = (individual['maghrib'] ?? 0).clamp(-15, 15);
    _prayerOffsetIsha = (individual['isha'] ?? 0).clamp(-15, 15);

    final payload = {
      'global': _prayerOffsetGlobal,
      'fajr': _prayerOffsetFajr,
      'dhuhr': _prayerOffsetDhuhr,
      'asr': _prayerOffsetAsr,
      'maghrib': _prayerOffsetMaghrib,
      'isha': _prayerOffsetIsha,
    };

    await _prefs?.setString(
      AppConstants.prayerTimeOffsetsKey,
      jsonEncode(payload),
    );
    notifyListeners();
  }

  // التعديل التراكمي: يجمع التعديل الجديد مع المخزن مسبقاً
  Future<void> updateHijriAdjustment(int additionalAdjustment) async {
    int currentStored = _prefs?.getInt(AppConstants.hijriAdjustmentKey) ?? 0;
    _hijriAdjustment = currentStored + additionalAdjustment;

    _autoHijriAdjustment = (_hijriAdjustment == 0);

    await _prefs?.setInt(AppConstants.hijriAdjustmentKey, _hijriAdjustment);
    await _prefs?.setBool('auto_hijri_adjustment', _autoHijriAdjustment);

    notifyListeners();
  }

  Future<void> setCity(String cityId) async {
    _selectedCity = cityId;
    _selectedCityName = cityId;
    await _prefs?.setString(AppConstants.selectedCityKey, cityId);
    await _prefs?.setString('selected_city_name', cityId);

    // 🔥 تحديث بيانات الويدجت فوراً عند تغيير المدينة
    PrayerTimesService.instance.updateWidgetData();

    notifyListeners();
  }

  Future<void> setCalculationMethod(String method) async {
    _selectedCalculationMethod = method;
    await _prefs?.setString(AppConstants.calculationMethodKey, method);
    notifyListeners();
  }

  Future<void> setDST(bool enabled) async {
    _dstEnabled = enabled;
    await _prefs?.setBool(AppConstants.dstKey, enabled);
    notifyListeners();
  }

  Future<void> setMadhab(String madhab) async {
    _selectedMadhab = madhab;
    await _prefs?.setString(AppConstants.madhabKey, madhab);
    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    await _prefs?.setString(
      AppConstants.themeModeKey,
      mode.toString().split('.').last,
    );
    notifyListeners();
  }

  Future<void> setPrayerAthanEnabled(String prayerKey, bool enabled) async {
    switch (prayerKey) {
      case 'fajr':
        _fajrAthanEnabled = enabled;
        break;
      case 'dhuhr':
        _dhuhrAthanEnabled = enabled;
        break;
      case 'asr':
        _asrAthanEnabled = enabled;
        break;
      case 'maghrib':
        _maghribAthanEnabled = enabled;
        break;
      case 'isha':
        _ishaAthanEnabled = enabled;
        break;
    }
    await _prefs?.setBool('${prayerKey}_athan_enabled', enabled);

    // إعادة جدولة المنبهات عند تغيير حالة الأذان لأي صلاة
    PrayerTimesService.instance.scheduleAllPrayers();
    notifyListeners();
  }

  Future<void> setFirstLaunchComplete() async {
    _isFirstLaunch = false;
    await _prefs?.setBool(AppConstants.isFirstLaunchKey, false);
    notifyListeners();
  }

  void _setDefaults() {
    _selectedCity = AppConstants.defaultCity;
    _selectedCityName = "القاهرة، مصر";
    _themeMode = AppThemeMode.dark;
    _hijriAdjustment = 0;
    _autoHijriAdjustment = true;
    _fontSize = 16.0;
    _fiqhBookmarks = {};
    _resetPrayerOffsetsInMemory();
  }

  // Font Size Methods
  Future<void> setFontSize(double size) async {
    _fontSize = size;
    await _prefs?.setDouble('fiqh_font_size', size);
    notifyListeners();
  }

  // Fiqh Bookmarks Methods
  Future<void> addFiqhBookmark(String bookmarkKey) async {
    _fiqhBookmarks.add(bookmarkKey);
    await _prefs?.setStringList('fiqh_bookmarks', _fiqhBookmarks.toList());
    notifyListeners();
  }

  Future<void> removeFiqhBookmark(String bookmarkKey) async {
    _fiqhBookmarks.remove(bookmarkKey);
    await _prefs?.setStringList('fiqh_bookmarks', _fiqhBookmarks.toList());
    notifyListeners();
  }
}
