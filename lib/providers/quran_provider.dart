import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuranProvider extends ChangeNotifier {
  SharedPreferences? _prefs;

  // Font Size
  double _fontSize = 24.0;
  static const String _fontSizeKey = 'quran_font_size';

  // Bookmark fields
  static const String _lastSurahIdKey = 'last_surah_id';
  static const String _lastAyahNumberKey = 'last_ayah_number';
  static const String _lastJuzIdKey = 'last_juz_id';
  static const String _isJuzModeKey = 'is_juz_mode';
  static const String _bookmarkNameKey = 'bookmark_name';

  int? _lastSurahId;
  int? _lastAyahNumber;
  int? _lastJuzId;
  bool _isJuzMode = false;
  String? _bookmarkName;

  double get fontSize => _fontSize;
  int? get lastSurahId => _lastSurahId;
  int? get lastAyahNumber => _lastAyahNumber;
  int? get lastJuzId => _lastJuzId;
  bool get isJuzMode => _isJuzMode;
  String? get bookmarkName => _bookmarkName;
  bool get hasBookmark => _lastAyahNumber != null;

  QuranProvider() {
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
  }

  void _loadSettings() {
    if (_prefs == null) return;
    _fontSize = _prefs!.getDouble(_fontSizeKey) ?? 24.0;
    _lastSurahId = _prefs!.getInt(_lastSurahIdKey);
    _lastAyahNumber = _prefs!.getInt(_lastAyahNumberKey);
    _lastJuzId = _prefs!.getInt(_lastJuzIdKey);
    _isJuzMode = _prefs!.getBool(_isJuzModeKey) ?? false;
    _bookmarkName = _prefs!.getString(_bookmarkNameKey);
    notifyListeners();
  }

  // --- الدالة الجديدة المطلوبة للـ Slider ---
  Future<void> setFontSize(double size) async {
    _fontSize = size;
    notifyListeners(); // لتحديث الواجهة فوراً
    await _prefs?.setDouble(_fontSizeKey, size); // حفظ في الذاكرة
  }

  // الدوال القديمة (يمكنك الإبقاء عليها إذا كنت تستخدم أزرار + و - في مكان آخر)
  Future<void> increaseFontSize() async {
    if (_fontSize < 50.0) {
      await setFontSize(_fontSize + 2.0);
    }
  }

  Future<void> decreaseFontSize() async {
    if (_fontSize > 16.0) {
      await setFontSize(_fontSize - 2.0);
    }
  }

  Future<void> saveBookmark({
    required int surahId,
    required int ayahNumber,
    int? juzId,
    required bool isJuzMode,
    required String name,
  }) async {
    _lastSurahId = surahId;
    _lastAyahNumber = ayahNumber;
    _lastJuzId = juzId;
    _isJuzMode = isJuzMode;
    _bookmarkName = name;

    notifyListeners();

    await _prefs?.setInt(_lastSurahIdKey, surahId);
    await _prefs?.setInt(_lastAyahNumberKey, ayahNumber);
    if (juzId != null) {
      await _prefs?.setInt(_lastJuzIdKey, juzId);
    } else {
      await _prefs?.remove(_lastJuzIdKey);
    }
    await _prefs?.setBool(_isJuzModeKey, isJuzMode);
    await _prefs?.setString(_bookmarkNameKey, name);
  }

  Future<void> clearBookmark() async {
    _lastSurahId = null;
    _lastAyahNumber = null;
    _lastJuzId = null;
    _isJuzMode = false;
    _bookmarkName = null;

    notifyListeners();

    await _prefs?.remove(_lastSurahIdKey);
    await _prefs?.remove(_lastAyahNumberKey);
    await _prefs?.remove(_lastJuzIdKey);
    await _prefs?.remove(_isJuzModeKey);
    await _prefs?.remove(_bookmarkNameKey);
  }
}