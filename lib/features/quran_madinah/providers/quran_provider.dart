import 'package:flutter/material.dart';
import 'package:imsakia/features/quran_madinah/services/madinah_db_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuranProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  static const String _lastPageKey = 'lastReadPage';
  static const String _fontSizeKey = 'currentFontSize';

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  int _currentPage = 1;
  int get currentPage => _currentPage;

  double _currentFontSize = 24.0;
  double get currentFontSize => _currentFontSize;

  List<int> _bookmarks = [];
  List<int> get bookmarks => _bookmarks;

  List<Map<String, dynamic>> _surahs = [];
  List<Map<String, dynamic>> get surahs => _surahs;

  QuranProvider(this._prefs) {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    // Ensure database is populated (this takes time only on first launch)
    await DbHelper.populateDatabaseIfEmpty();

    // Load last read page
    _currentPage = _prefs.getInt(_lastPageKey) ?? 1;

    // Load font size
    _currentFontSize = _prefs.getDouble(_fontSizeKey) ?? 24.0;

    // Load bookmarks (stored as list of strings format in prefs)
    final savedBookmarks = _prefs.getStringList('bookmarks');
    if (savedBookmarks != null) {
      _bookmarks = savedBookmarks.map((e) => int.parse(e)).toList();
    }

    // Load Surah Index
    _surahs = await DbHelper.getAllSurahs();

    // Load Juz Index
    _juzs = await DbHelper.getAllJuzs();

    _isLoading = false;
    notifyListeners();
  }

  List<Map<String, dynamic>> _juzs = [];
  List<Map<String, dynamic>> get juzs => _juzs;

  Future<void> setPage(int page) async {
    _currentPage = page;
    await _prefs.setInt(_lastPageKey, page);
    notifyListeners();
  }

  Future<void> setFontSize(double size) async {
    _currentFontSize = size;
    await _prefs.setDouble(_fontSizeKey, size);
    notifyListeners();
  }

  bool isBookmarked(int page) {
    return _bookmarks.contains(page);
  }

  Future<void> toggleBookmark(int page) async {
    if (_bookmarks.contains(page)) {
      _bookmarks.remove(page);
    } else {
      _bookmarks.add(page);
    }
    // Sort for aesthetics
    _bookmarks.sort();
    await _prefs.setStringList(
      'bookmarks',
      _bookmarks.map((e) => e.toString()).toList(),
    );
    notifyListeners();
  }

  // Helper method to determine revelation type based on widely accepted scholars
  static bool isMadani(int suraNumber) {
    const madaniSurahs = [
      2,
      3,
      4,
      5,
      8,
      9,
      22,
      24,
      33,
      47,
      48,
      49,
      58,
      59,
      60,
      62,
      63,
      64,
      65,
      66,
      76,
      98,
      110,
    ];
    return madaniSurahs.contains(suraNumber);
  }
}
