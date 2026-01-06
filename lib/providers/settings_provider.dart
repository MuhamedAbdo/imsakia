import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_constants.dart';

enum AppThemeMode { light, dark, system }

class SettingsProvider extends ChangeNotifier {
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  // Settings state
  AppThemeMode _themeMode = AppThemeMode.system;
  String _selectedCity = AppConstants.defaultCity;
  String _selectedCalculationMethod = AppConstants.defaultCalculationMethod;
  String _selectedMadhab = AppConstants.defaultMadhab;
  bool _dstEnabled = AppConstants.defaultDST;
  bool _notificationsEnabled = true;
  bool _isFirstLaunch = true;
  int _hijriAdjustment = 0; // New Hijri adjustment setting

  // Getters
  AppThemeMode get themeMode => _themeMode;
  String get selectedCity => _selectedCity;
  String get selectedCalculationMethod => _selectedCalculationMethod;
  String get selectedMadhab => _selectedMadhab;
  bool get dstEnabled => _dstEnabled;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get isFirstLaunch => _isFirstLaunch;
  bool get isInitialized => _isInitialized;
  int get hijriAdjustment => _hijriAdjustment;

  /// Initialize all settings from SharedPreferences
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      
      // Load all settings
      await Future.wait([
        _loadThemeMode(),
        _loadCity(),
        _loadCalculationMethod(),
        _loadMadhab(),
        _loadDST(),
        _loadNotifications(),
        _loadHijriAdjustment(),
        _loadFirstLaunch(),
      ]);

      _isInitialized = true;
      
      // Notify listeners after all settings are loaded
      notifyListeners();
      
      debugPrint('✅ SettingsProvider initialized successfully');
      debugPrint('🎨 Theme mode loaded: ${_themeMode.toString().split('.').last}');
      
    } catch (e) {
      debugPrint('❌ Error initializing SettingsProvider: $e');
      // Set defaults if initialization fails
      _setDefaults();
      notifyListeners();
    }
  }

  Future<void> _loadThemeMode() async {
    final savedTheme = _prefs?.getString(AppConstants.themeModeKey) ?? 'system';
    _themeMode = AppThemeMode.values.firstWhere(
      (mode) => mode.toString().split('.').last == savedTheme,
      orElse: () => AppThemeMode.system,
    );
  }

  Future<void> _loadCity() async {
    _selectedCity = _prefs?.getString(AppConstants.selectedCityKey) ?? AppConstants.defaultCity;
  }

  Future<void> _loadCalculationMethod() async {
    _selectedCalculationMethod = _prefs?.getString(AppConstants.calculationMethodKey) ?? AppConstants.defaultCalculationMethod;
  }

  Future<void> _loadMadhab() async {
    _selectedMadhab = _prefs?.getString(AppConstants.madhabKey) ?? AppConstants.defaultMadhab;
  }

  Future<void> _loadDST() async {
    _dstEnabled = _prefs?.getBool(AppConstants.dstKey) ?? AppConstants.defaultDST;
  }

  Future<void> _loadNotifications() async {
    _notificationsEnabled = _prefs?.getBool(AppConstants.notificationsKey) ?? true;
  }

  Future<void> _loadHijriAdjustment() async {
    _hijriAdjustment = _prefs?.getInt(AppConstants.hijriAdjustmentKey) ?? 0;
  }

  Future<void> _loadFirstLaunch() async {
    _isFirstLaunch = _prefs?.getBool(AppConstants.isFirstLaunchKey) ?? true;
  }

  void _setDefaults() {
    _themeMode = AppThemeMode.system;
    _selectedCity = AppConstants.defaultCity;
    _selectedCalculationMethod = AppConstants.defaultCalculationMethod;
    _selectedMadhab = AppConstants.defaultMadhab;
    _dstEnabled = AppConstants.defaultDST;
    _notificationsEnabled = true;
    _isFirstLaunch = true;
  }

  // Theme setters
  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    await _prefs?.setString(AppConstants.themeModeKey, mode.toString().split('.').last);
    notifyListeners();
    debugPrint('🎨 Theme mode changed to: ${mode.toString().split('.').last}');
  }

  // City setters
  Future<void> setCity(String city) async {
    _selectedCity = city;
    await _prefs?.setString(AppConstants.selectedCityKey, city);
    notifyListeners();
    debugPrint('🏙️ City changed to: $city');
  }

  // Calculation method setters
  Future<void> setCalculationMethod(String method) async {
    _selectedCalculationMethod = method;
    await _prefs?.setString(AppConstants.calculationMethodKey, method);
    notifyListeners();
    debugPrint('🧮 Calculation method changed to: $method');
  }

  // Madhab setters
  Future<void> setMadhab(String madhab) async {
    _selectedMadhab = madhab;
    await _prefs?.setString(AppConstants.madhabKey, madhab);
    notifyListeners();
    debugPrint('⚖️ Madhab changed to: $madhab');
  }

  // DST setters
  Future<void> setDST(bool enabled) async {
    _dstEnabled = enabled;
    await _prefs?.setBool(AppConstants.dstKey, enabled);
    notifyListeners();
    debugPrint('🌞 DST changed to: $enabled');
  }

  // Notifications setters
  Future<void> setNotifications(bool enabled) async {
    _notificationsEnabled = enabled;
    await _prefs?.setBool(AppConstants.notificationsKey, enabled);
    notifyListeners();
    debugPrint('🔔 Notifications changed to: $enabled');
  }

  // First launch setters
  Future<void> setFirstLaunchComplete() async {
    _isFirstLaunch = false;
    await _prefs?.setBool(AppConstants.isFirstLaunchKey, false);
    notifyListeners();
    debugPrint('🎉 First launch completed');
  }

  // Hijri adjustment setter
  Future<void> setHijriAdjustment(int adjustment) async {
    _hijriAdjustment = adjustment;
    await _prefs?.setInt(AppConstants.hijriAdjustmentKey, adjustment);
    notifyListeners();
    debugPrint('📅 Hijri adjustment changed to: $adjustment');
  }

  // Batch save all settings (useful for initial setup)
  Future<void> saveAllSettings({
    AppThemeMode? themeMode,
    String? city,
    String? calculationMethod,
    String? madhab,
    bool? dstEnabled,
    bool? notificationsEnabled,
  }) async {
    try {
      if (themeMode != null) await setThemeMode(themeMode);
      if (city != null) await setCity(city);
      if (calculationMethod != null) await setCalculationMethod(calculationMethod);
      if (madhab != null) await setMadhab(madhab);
      if (dstEnabled != null) await setDST(dstEnabled);
      if (notificationsEnabled != null) await setNotifications(notificationsEnabled);

      debugPrint('💾 All settings saved successfully');
    } catch (e) {
      debugPrint('❌ Error saving settings: $e');
    }
  }

  // Get city display name
  String getCityDisplayName() {
    final city = AppConstants.cities.firstWhere(
      (city) => city['id'] == _selectedCity,
      orElse: () => AppConstants.cities.first,
    );
    return '${city['name']} - ${city['country']}';
  }

  // Get calculation method display name
  String getCalculationMethodDisplayName() {
    const methods = {
      'egyptian': 'Egyptian General Authority of Survey',
      'karachi': 'University of Islamic Sciences, Karachi',
      'umm_al_qura': 'Umm al-Qura University, Makkah',
      'muslim_world_league': 'Muslim World League',
      'north_america': 'Islamic Society of North America',
    };
    return methods[_selectedCalculationMethod] ?? 'Egyptian General Authority of Survey';
  }

  // Get madhab display name
  String getMadhabDisplayName() {
    return _selectedMadhab == 'shafi' ? 'الشافعي' : 'الحنفي';
  }

  // Reset all settings to defaults
  Future<void> resetToDefaults() async {
    await saveAllSettings(
      themeMode: AppThemeMode.system,
      city: AppConstants.defaultCity,
      calculationMethod: AppConstants.defaultCalculationMethod,
      madhab: AppConstants.defaultMadhab,
      dstEnabled: AppConstants.defaultDST,
      notificationsEnabled: true,
    );
    debugPrint('🔄 Settings reset to defaults');
  }

  @override
  void dispose() {
    debugPrint('🗑️ SettingsProvider disposed');
    super.dispose();
  }
}
