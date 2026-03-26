import 'package:flutter/foundation.dart';
import '../core/models/settings_model.dart';
import '../core/services/storage_service.dart';
import '../core/services/background_service.dart';
import '../core/services/athan_scheduling_service.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService _storage;
  late SettingsModel _settings;

  SettingsProvider(this._storage) {
    _settings = _storage.getSettings();
    
    // Safety Fallback: Reset Fajr if it points to the deleted Abdul Baset file
    if (_settings.selectedFajrSound == 'assets/audio/fajr_abdulbaset.mp3') {
      _settings = _settings.copyWith(selectedFajrSound: 'assets/audio/fajr_makkah.mp3');
      _storage.saveSettings(_settings);
    }

    if (_settings.languageCode != 'ar') {
      _settings = _settings.copyWith(languageCode: 'ar');
      _storage.saveSettings(_settings);
    }
  }

  SettingsModel get settings => _settings;
  CalculationMethod get calculationMethod => _settings.calculationMethod;
  LocationMode get locationMode => _settings.locationMode;

  int get hijriBaseOffset => _settings.hijriBaseOffset;
  int get hijriOffset => _settings.hijriOffset;

  bool get athanEnabled => _settings.athanEnabled;
  bool get notificationsEnabled => _settings.notificationsEnabled;
  String get languageCode => _settings.languageCode;
  bool get isDarkMode => _settings.isDarkMode;
  bool get athanSoundEnabled => _settings.athanSoundEnabled;
  bool get isUnifiedAthan => _settings.isUnifiedAthan;
  bool get qiblaVibrationEnabled => _settings.qiblaVibrationEnabled;

  // Sounds
  String get selectedAthanSound => _settings.selectedAthanSound;
  String get selectedFajrSound => _settings.selectedFajrSound;
  String get selectedDhuhrSound => _settings.selectedDhuhrSound;
  String get selectedAsrSound => _settings.selectedAsrSound;
  String get selectedMaghribSound => _settings.selectedMaghribSound;
  String get selectedIshaSound => _settings.selectedIshaSound;

  Future<void> setCalculationMethod(CalculationMethod method) async {
    _settings = _settings.copyWith(calculationMethod: method);
    await _save();
  }

  Future<void> setLocationMode(LocationMode mode) async {
    _settings = _settings.copyWith(locationMode: mode);
    await _save();
  }

  /// Applies a Hijri day correction cumulatively.
  Future<void> applyHijriOffset(int delta) async {
    final newBase = _settings.hijriBaseOffset + delta;
    _settings = _settings.copyWith(
      hijriBaseOffset: newBase,
      hijriOffset: 0,
    );
    await _save();
  }

  Future<void> setAthanEnabled(bool enabled) async {
    _settings = _settings.copyWith(athanEnabled: enabled);
    if (enabled) {
      await BackgroundService.start();
    } else {
      await BackgroundService.stop();
    }
    await _save();
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _settings = _settings.copyWith(notificationsEnabled: enabled);
    await _save();
  }

  Future<void> setLanguageCode(String code) async {
    _settings = _settings.copyWith(languageCode: code);
    await _save();
  }

  Future<void> setDarkMode(bool dark) async {
    _settings = _settings.copyWith(isDarkMode: dark);
    await _save();
  }

  Future<void> setAthanSoundEnabled(bool enabled) async {
    _settings = _settings.copyWith(athanSoundEnabled: enabled);
    await _save();
  }

  Future<void> setQiblaVibrationEnabled(bool enabled) async {
    _settings = _settings.copyWith(qiblaVibrationEnabled: enabled);
    await _save();
  }

  /// Toggles unified-athan mode.
  /// When enabling: syncs all per-prayer sounds to the current general sound
  ///               (Fajr keeps its dedicated sound).
  /// When disabling: per-prayer sounds keep their last values.
  Future<void> setIsUnifiedAthan(bool unified) async {
    if (unified) {
      // Dhuhr, Asr, Maghrib, and Isha must use the user-selected athan_ sound.
      // CRITICAL: The Fajr prayer MUST ignore the unified setting and default to assets/audio/fajr_makkah.mp3
      _settings = _settings.copyWith(
        isUnifiedAthan: true,
        selectedFajrSound: 'assets/audio/fajr_makkah.mp3',
        selectedDhuhrSound: _settings.selectedAthanSound,
        selectedAsrSound: _settings.selectedAthanSound,
        selectedMaghribSound: _settings.selectedAthanSound,
        selectedIshaSound: _settings.selectedAthanSound,
      );
    } else {
      _settings = _settings.copyWith(isUnifiedAthan: false);
    }
    await _save();
  }

  /// Sets the unified Athan sound and syncs all non-Fajr prayers.
  Future<void> setSelectedAthanSound(String path) async {
    _settings = _settings.copyWith(
      selectedAthanSound: path,
      // When unified, update all non-Fajr prayers
      selectedDhuhrSound:
          _settings.isUnifiedAthan ? path : _settings.selectedDhuhrSound,
      selectedAsrSound:
          _settings.isUnifiedAthan ? path : _settings.selectedAsrSound,
      selectedMaghribSound:
          _settings.isUnifiedAthan ? path : _settings.selectedMaghribSound,
      selectedIshaSound:
          _settings.isUnifiedAthan ? path : _settings.selectedIshaSound,
    );
    await _save();
  }

  Future<void> setSelectedFajrSound(String path) async {
    _settings = _settings.copyWith(selectedFajrSound: path);
    await _save();
  }

  Future<void> setSelectedDhuhrSound(String path) async {
    _settings = _settings.copyWith(selectedDhuhrSound: path);
    await _save();
  }

  Future<void> setSelectedAsrSound(String path) async {
    _settings = _settings.copyWith(selectedAsrSound: path);
    await _save();
  }

  Future<void> setSelectedMaghribSound(String path) async {
    _settings = _settings.copyWith(selectedMaghribSound: path);
    await _save();
  }

  Future<void> setSelectedIshaSound(String path) async {
    _settings = _settings.copyWith(selectedIshaSound: path);
    await _save();
  }

  Future<void> _save() async {
    await _storage.saveSettings(_settings);
    
    // Natively schedule athans on settings change (e.g., sound change or toggle)
    AthanSchedulingService.scheduleFutureAthans();
    
    notifyListeners();
  }
}
