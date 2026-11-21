import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FontSettingsProvider extends ChangeNotifier {
  static const String _keyFontScale = 'font_settings_scale';
  static const String _keyLineHeight = 'font_settings_line_height';

  static const double minFontScale = 0.85;
  static const double maxFontScale = 1.40;
  static const double defaultFontScale = 1.0;

  static const double minLineHeight = 1.4;
  static const double maxLineHeight = 2.2;
  static const double defaultLineHeight = 1.6;

  double _fontScale = defaultFontScale;
  double _lineHeight = defaultLineHeight;
  SharedPreferences? _prefs;

  double get fontScale => _fontScale;
  double get lineHeight => _lineHeight;

  FontSettingsProvider([SharedPreferences? prefs]) {
    if (prefs != null) {
      _prefs = prefs;
      _loadFromPrefs();
    } else {
      _initPrefs();
    }
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFromPrefs();
  }

  void _loadFromPrefs() {
    if (_prefs == null) return;
    final savedScale = _prefs!.getDouble(_keyFontScale);
    final savedLineHeight = _prefs!.getDouble(_keyLineHeight);

    if (savedScale != null) {
      _fontScale = savedScale.clamp(minFontScale, maxFontScale);
    }
    if (savedLineHeight != null) {
      _lineHeight = savedLineHeight.clamp(minLineHeight, maxLineHeight);
    }
    notifyListeners();
  }

  Future<void> setFontScale(double scale) async {
    final clamped = scale.clamp(minFontScale, maxFontScale);
    if ((_fontScale - clamped).abs() < 0.001) return;
    _fontScale = clamped;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setDouble(_keyFontScale, _fontScale);
  }

  Future<void> setLineHeight(double height) async {
    final clamped = height.clamp(minLineHeight, maxLineHeight);
    if ((_lineHeight - clamped).abs() < 0.001) return;
    _lineHeight = clamped;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setDouble(_keyLineHeight, _lineHeight);
  }

  Future<void> resetToDefault() async {
    _fontScale = defaultFontScale;
    _lineHeight = defaultLineHeight;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setDouble(_keyFontScale, defaultFontScale);
    await _prefs!.setDouble(_keyLineHeight, defaultLineHeight);
  }
}
