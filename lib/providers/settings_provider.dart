import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_constants.dart';
import '../services/prayer_times_service.dart';

enum AppThemeMode { light, dark, system }

class SettingsProvider extends ChangeNotifier {
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  AppThemeMode _themeMode = AppThemeMode.system;
  String _selectedCity = AppConstants.defaultCity;
  String _selectedCityName = "القاهرة، مصر";
  String _selectedCalculationMethod = AppConstants.defaultCalculationMethod;
  String _selectedMadhab = AppConstants.defaultMadhab;
  bool _dstEnabled = AppConstants.defaultDST;
  bool _notificationsEnabled = true;
  bool _isFirstLaunch = true;
  int _hijriAdjustment = 0;
  bool _autoHijriAdjustment = true;

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
    _selectedCity = _prefs?.getString(AppConstants.selectedCityKey) ?? AppConstants.defaultCity;
    _selectedCityName = _prefs?.getString('selected_city_name') ?? "القاهرة، مصر";

    final savedTheme = _prefs?.getString(AppConstants.themeModeKey) ?? 'system';
    _themeMode = AppThemeMode.values.firstWhere(
      (mode) => mode.toString().split('.').last == savedTheme,
      orElse: () => AppThemeMode.system,
    );

    _selectedCalculationMethod = _prefs?.getString(AppConstants.calculationMethodKey) ?? AppConstants.defaultCalculationMethod;
    _selectedMadhab = _prefs?.getString(AppConstants.madhabKey) ?? AppConstants.defaultMadhab;
    _dstEnabled = _prefs?.getBool(AppConstants.dstKey) ?? AppConstants.defaultDST;
    _notificationsEnabled = _prefs?.getBool(AppConstants.notificationsKey) ?? true;

    _hijriAdjustment = _prefs?.getInt(AppConstants.hijriAdjustmentKey) ?? 0;
    _autoHijriAdjustment = _prefs?.getBool('auto_hijri_adjustment') ?? (_hijriAdjustment == 0);

    _isFirstLaunch = _prefs?.getBool(AppConstants.isFirstLaunchKey) ?? true;
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
    await _prefs?.setString(AppConstants.themeModeKey, mode.toString().split('.').last);
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
    _themeMode = AppThemeMode.system;
    _hijriAdjustment = 0;
    _autoHijriAdjustment = true;
  }
}