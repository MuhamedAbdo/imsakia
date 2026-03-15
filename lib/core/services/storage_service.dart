import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings_model.dart';
import '../models/location_model.dart';

class StorageService {
  static const _keySettings = 'settings';
  static const _keyLocation = 'last_location';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // ── Settings ──────────────────────────────────────────────

  SettingsModel getSettings() {
    final raw = _prefs.getString(_keySettings);
    if (raw == null) return const SettingsModel();
    try {
      return SettingsModel.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const SettingsModel();
    }
  }

  Future<void> saveSettings(SettingsModel settings) async {
    await _prefs.setString(_keySettings, jsonEncode(settings.toJson()));
  }

  // ── Location ──────────────────────────────────────────────

  LocationModel? getLastLocation() {
    final raw = _prefs.getString(_keyLocation);
    if (raw == null) return null;
    try {
      return LocationModel.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLocation(LocationModel location) async {
    await _prefs.setString(_keyLocation, jsonEncode(location.toJson()));
  }
}
