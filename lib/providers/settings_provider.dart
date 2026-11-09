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

  // Manual Prayer Time Adjustments
  String _prayerAdjustmentMode = AppConstants.defaultPrayerAdjustmentMode;
  int _prayerAdjustmentGlobal = AppConstants.defaultPrayerAdjustment;
  int _prayerAdjustmentFajr = AppConstants.defaultPrayerAdjustment;
  int _prayerAdjustmentDhuhr = AppConstants.defaultPrayerAdjustment;
  int _prayerAdjustmentAsr = AppConstants.defaultPrayerAdjustment;
  int _prayerAdjustmentMaghrib = AppConstants.defaultPrayerAdjustment;
  int _prayerAdjustmentIsha = AppConstants.defaultPrayerAdjustment;

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

  String get prayerAdjustmentMode => _prayerAdjustmentMode;
  int get prayerAdjustmentGlobal => _prayerAdjustmentGlobal;
  int get prayerAdjustmentFajr => _prayerAdjustmentFajr;
  int get prayerAdjustmentDhuhr => _prayerAdjustmentDhuhr;
  int get prayerAdjustmentAsr => _prayerAdjustmentAsr;
  int get prayerAdjustmentMaghrib => _prayerAdjustmentMaghrib;
  int get prayerAdjustmentIsha => _prayerAdjustmentIsha;

  int getPrayerAdjustment(String prayerKey) {
    switch (prayerKey) {
      case 'fajr':
        return _prayerAdjustmentFajr;
      case 'dhuhr':
        return _prayerAdjustmentDhuhr;
      case 'asr':
        return _prayerAdjustmentAsr;
      case 'maghrib':
        return _prayerAdjustmentMaghrib;
      case 'isha':
        return _prayerAdjustmentIsha;
      default:
        return 0;
    }
  }

  double get fontSize => _fontSize;
  Set<String> get fiqhBookmarks => _fiqhBookmarks;

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

    _prayerAdjustmentMode =
        _prefs?.getString(AppConstants.prayerAdjustmentModeKey) ??
        AppConstants.defaultPrayerAdjustmentMode;
    if (_prayerAdjustmentMode != AppConstants.prayerAdjustmentModeGlobal &&
        _prayerAdjustmentMode != AppConstants.prayerAdjustmentModeIndividual) {
      _prayerAdjustmentMode = AppConstants.defaultPrayerAdjustmentMode;
    }

    _prayerAdjustmentGlobal = _normalizeAdjustment(
      _prefs?.getInt(AppConstants.prayerAdjustmentGlobalKey) ??
          AppConstants.defaultPrayerAdjustment,
    );
    _prayerAdjustmentFajr = _normalizeAdjustment(
      _prefs?.getInt(AppConstants.prayerAdjustmentFajrKey) ??
          AppConstants.defaultPrayerAdjustment,
    );
    _prayerAdjustmentDhuhr = _normalizeAdjustment(
      _prefs?.getInt(AppConstants.prayerAdjustmentDhuhrKey) ??
          AppConstants.defaultPrayerAdjustment,
    );
    _prayerAdjustmentAsr = _normalizeAdjustment(
      _prefs?.getInt(AppConstants.prayerAdjustmentAsrKey) ??
          AppConstants.defaultPrayerAdjustment,
    );
    _prayerAdjustmentMaghrib = _normalizeAdjustment(
      _prefs?.getInt(AppConstants.prayerAdjustmentMaghribKey) ??
          AppConstants.defaultPrayerAdjustment,
    );
    _prayerAdjustmentIsha = _normalizeAdjustment(
      _prefs?.getInt(AppConstants.prayerAdjustmentIshaKey) ??
          AppConstants.defaultPrayerAdjustment,
    );
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
    _prayerAdjustmentMode = AppConstants.defaultPrayerAdjustmentMode;
    _prayerAdjustmentGlobal = AppConstants.defaultPrayerAdjustment;
    _prayerAdjustmentFajr = AppConstants.defaultPrayerAdjustment;
    _prayerAdjustmentDhuhr = AppConstants.defaultPrayerAdjustment;
    _prayerAdjustmentAsr = AppConstants.defaultPrayerAdjustment;
    _prayerAdjustmentMaghrib = AppConstants.defaultPrayerAdjustment;
    _prayerAdjustmentIsha = AppConstants.defaultPrayerAdjustment;
  }

  int _normalizeAdjustment(int value) {
    if (value < AppConstants.minPrayerAdjustment) {
      return AppConstants.minPrayerAdjustment;
    }
    if (value > AppConstants.maxPrayerAdjustment) {
      return AppConstants.maxPrayerAdjustment;
    }
    return value;
  }

  Future<void> setPrayerAdjustmentMode(String mode) async {
    if (mode != AppConstants.prayerAdjustmentModeGlobal &&
        mode != AppConstants.prayerAdjustmentModeIndividual) {
      return;
    }
    _prayerAdjustmentMode = mode;
    await _prefs?.setString(AppConstants.prayerAdjustmentModeKey, mode);
    notifyListeners();
  }

  Future<void> setGlobalPrayerAdjustment(int minutes) async {
    final normalized = _normalizeAdjustment(minutes);
    _prayerAdjustmentGlobal = normalized;
    await _prefs?.setInt(AppConstants.prayerAdjustmentGlobalKey, normalized);
    notifyListeners();
  }

  Future<void> setIndividualPrayerAdjustment(
    String prayerKey,
    int minutes,
  ) async {
    final normalized = _normalizeAdjustment(minutes);
    switch (prayerKey) {
      case 'fajr':
        _prayerAdjustmentFajr = normalized;
        await _prefs?.setInt(AppConstants.prayerAdjustmentFajrKey, normalized);
        break;
      case 'dhuhr':
        _prayerAdjustmentDhuhr = normalized;
        await _prefs?.setInt(AppConstants.prayerAdjustmentDhuhrKey, normalized);
        break;
      case 'asr':
        _prayerAdjustmentAsr = normalized;
        await _prefs?.setInt(AppConstants.prayerAdjustmentAsrKey, normalized);
        break;
      case 'maghrib':
        _prayerAdjustmentMaghrib = normalized;
        await _prefs?.setInt(
          AppConstants.prayerAdjustmentMaghribKey,
          normalized,
        );
        break;
      case 'isha':
        _prayerAdjustmentIsha = normalized;
        await _prefs?.setInt(AppConstants.prayerAdjustmentIshaKey, normalized);
        break;
      default:
        return;
    }
    notifyListeners();
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
