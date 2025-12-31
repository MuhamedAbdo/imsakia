import 'package:flutter/foundation.dart';
import '../services/quran_service.dart';

class QuranProvider extends ChangeNotifier {
  final QuranService _quranService = QuranService();
  
  Map<String, dynamic>? _currentBookmark;
  bool _isLoading = false;

  Map<String, dynamic>? get currentBookmark => _currentBookmark;
  bool get isLoading => _isLoading;
  bool get hasBookmark => _currentBookmark != null && _currentBookmark!.isNotEmpty;

  /// Save bookmark (overwrites existing bookmark for the same surah)
  Future<void> saveBookmark(int surahIndex, int verseIndex, double scrollPosition) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _quranService.saveBookmark(surahIndex, verseIndex, scrollPosition);
      
      // Update current bookmark
      _currentBookmark = {
        'surahIndex': surahIndex,
        'verseIndex': verseIndex,
        'scrollPosition': scrollPosition,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      print('🔖 QuranProvider: Saved bookmark for Surah $surahIndex, Verse $verseIndex');
    } catch (e) {
      print('❌ QuranProvider: Error saving bookmark: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load bookmark for specific surah
  Future<void> loadBookmarkForSurah(int surahIndex) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final bookmark = await _quranService.getBookmarkForSurah(surahIndex);
      _currentBookmark = bookmark;
      print('🔖 QuranProvider: Loaded bookmark for Surah $surahIndex: $bookmark');
    } catch (e) {
      print('❌ QuranProvider: Error loading bookmark: $e');
      _currentBookmark = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Remove bookmark
  Future<void> removeBookmark(int surahIndex) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _quranService.removeBookmark(surahIndex);
      
      // Clear current bookmark if it matches the removed surah
      if (_currentBookmark != null && _currentBookmark!['surahIndex'] == surahIndex) {
        _currentBookmark = null;
      }
      
      print('🗑️ QuranProvider: Removed bookmark for Surah $surahIndex');
    } catch (e) {
      print('❌ QuranProvider: Error removing bookmark: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check if surah is bookmarked
  Future<bool> isSurahBookmarked(int surahIndex) async {
    try {
      return await _quranService.isSurahBookmarked(surahIndex);
    } catch (e) {
      print('❌ QuranProvider: Error checking bookmark: $e');
      return false;
    }
  }

  /// Get all bookmarks
  Future<List<Map<String, dynamic>>> getAllBookmarks() async {
    try {
      return await _quranService.getBookmarks();
    } catch (e) {
      print('❌ QuranProvider: Error getting all bookmarks: $e');
      return [];
    }
  }

  /// Clear current bookmark (for state management)
  void clearCurrentBookmark() {
    _currentBookmark = null;
    notifyListeners();
  }
}
