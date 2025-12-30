import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/surah.dart';

class QuranService {
  static final QuranService _instance = QuranService._internal();
  factory QuranService() => _instance;
  QuranService._internal();

  static const String _lastReadPageKey = 'last_read_page';
  static const String _lastReadSurahKey = 'last_read_surah';
  static const String _bookmarksKey = 'quran_bookmarks';

  List<Surah> _surahs = [];
  bool _isLoaded = false;

  List<Surah> get surahs => List.unmodifiable(_surahs);
  bool get isLoaded => _isLoaded;

  /// Load surahs data from assets
  Future<void> loadSurahs() async {
    if (_isLoaded) return;

    try {
      // Try to load from JSON file first
      final String jsonString = await rootBundle.loadString('assets/data/surahs.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      
      _surahs = (jsonData['surahs'] as List)
          .map((surahJson) => Surah.fromJson(surahJson))
          .toList();
      
      _isLoaded = true;
      print('✅ Loaded ${_surahs.length} surahs from JSON');
    } catch (e) {
      print('❌ Error loading surahs from JSON: $e');
      // Fallback to hardcoded data if JSON fails
      _loadFallbackSurahs();
    }
  }

  void _loadFallbackSurahs() {
    _surahs = [
      const Surah(number: 1, name: 'الفاتحة', englishName: 'Al-Fatihah', totalAyahs: 7, revelationType: 'Meccan', startPage: 1),
      const Surah(number: 2, name: 'البقرة', englishName: 'Al-Baqarah', totalAyahs: 286, revelationType: 'Medinan', startPage: 2),
      const Surah(number: 3, name: 'آل عمران', englishName: 'Al-Imran', totalAyahs: 200, revelationType: 'Medinan', startPage: 50),
      const Surah(number: 4, name: 'النساء', englishName: 'An-Nisa', totalAyahs: 176, revelationType: 'Medinan', startPage: 77),
      const Surah(number: 5, name: 'المائدة', englishName: 'Al-Ma\'idah', totalAyahs: 120, revelationType: 'Medinan', startPage: 106),
      const Surah(number: 6, name: 'الأنعام', englishName: 'Al-An\'am', totalAyahs: 165, revelationType: 'Meccan', startPage: 128),
      const Surah(number: 7, name: 'الأعراف', englishName: 'Al-A\'raf', totalAyahs: 206, revelationType: 'Meccan', startPage: 151),
      const Surah(number: 8, name: 'الأنفال', englishName: 'Al-Anfal', totalAyahs: 75, revelationType: 'Medinan', startPage: 177),
      const Surah(number: 9, name: 'التوبة', englishName: 'At-Tawbah', totalAyahs: 129, revelationType: 'Medinan', startPage: 187),
      const Surah(number: 10, name: 'يونس', englishName: 'Yunus', totalAyahs: 109, revelationType: 'Meccan', startPage: 208),
      const Surah(number: 11, name: 'هود', englishName: 'Hud', totalAyahs: 123, revelationType: 'Meccan', startPage: 221),
      const Surah(number: 12, name: 'يوسف', englishName: 'Yusuf', totalAyahs: 111, revelationType: 'Meccan', startPage: 235),
      const Surah(number: 13, name: 'الرعد', englishName: 'Ar-Ra\'d', totalAyahs: 43, revelationType: 'Medinan', startPage: 249),
      const Surah(number: 14, name: 'إبراهيم', englishName: 'Ibrahim', totalAyahs: 52, revelationType: 'Meccan', startPage: 255),
      const Surah(number: 15, name: 'الحجر', englishName: 'Al-Hijr', totalAyahs: 99, revelationType: 'Meccan', startPage: 262),
      const Surah(number: 16, name: 'النحل', englishName: 'An-Nahl', totalAyahs: 128, revelationType: 'Meccan', startPage: 267),
      const Surah(number: 17, name: 'الإسراء', englishName: 'Al-Isra', totalAyahs: 111, revelationType: 'Meccan', startPage: 282),
      const Surah(number: 18, name: 'الكهف', englishName: 'Al-Kahf', totalAyahs: 110, revelationType: 'Meccan', startPage: 293),
      const Surah(number: 19, name: 'مريم', englishName: 'Maryam', totalAyahs: 98, revelationType: 'Meccan', startPage: 305),
      const Surah(number: 20, name: 'طه', englishName: 'Taha', totalAyahs: 135, revelationType: 'Meccan', startPage: 312),
      const Surah(number: 21, name: 'الأنبياء', englishName: 'Al-Anbiya', totalAyahs: 112, revelationType: 'Meccan', startPage: 322),
      const Surah(number: 22, name: 'الحج', englishName: 'Al-Hajj', totalAyahs: 78, revelationType: 'Medinan', startPage: 332),
      const Surah(number: 23, name: 'المؤمنون', englishName: 'Al-Mu\'minun', totalAyahs: 118, revelationType: 'Meccan', startPage: 342),
      const Surah(number: 24, name: 'النور', englishName: 'An-Nur', totalAyahs: 64, revelationType: 'Medinan', startPage: 350),
      const Surah(number: 25, name: 'الفرقان', englishName: 'Al-Furqan', totalAyahs: 77, revelationType: 'Meccan', startPage: 359),
      const Surah(number: 26, name: 'الشعراء', englishName: 'Ash-Shu\'ara', totalAyahs: 227, revelationType: 'Meccan', startPage: 367),
      const Surah(number: 27, name: 'النمل', englishName: 'An-Naml', totalAyahs: 93, revelationType: 'Meccan', startPage: 377),
      const Surah(number: 28, name: 'القصص', englishName: 'Al-Qasas', totalAyahs: 88, revelationType: 'Meccan', startPage: 385),
      const Surah(number: 29, name: 'العنكبوت', englishName: 'Al-\'Ankabut', totalAyahs: 69, revelationType: 'Meccan', startPage: 396),
      const Surah(number: 30, name: 'الروم', englishName: 'Ar-Rum', totalAyahs: 60, revelationType: 'Meccan', startPage: 404),
      const Surah(number: 31, name: 'لقمان', englishName: 'Luqman', totalAyahs: 34, revelationType: 'Meccan', startPage: 411),
      const Surah(number: 32, name: 'السجدة', englishName: 'As-Sajdah', totalAyahs: 30, revelationType: 'Meccan', startPage: 415),
      const Surah(number: 33, name: 'الأحزاب', englishName: 'Al-Ahzab', totalAyahs: 73, revelationType: 'Medinan', startPage: 418),
      const Surah(number: 34, name: 'سبأ', englishName: 'Saba', totalAyahs: 54, revelationType: 'Meccan', startPage: 428),
      const Surah(number: 35, name: 'فاطر', englishName: 'Fatir', totalAyahs: 45, revelationType: 'Meccan', startPage: 434),
      const Surah(number: 36, name: 'يس', englishName: 'Ya-Sin', totalAyahs: 83, revelationType: 'Meccan', startPage: 440),
      const Surah(number: 37, name: 'الصافات', englishName: 'As-Saffat', totalAyahs: 182, revelationType: 'Meccan', startPage: 446),
      const Surah(number: 38, name: 'ص', englishName: 'Sad', totalAyahs: 88, revelationType: 'Meccan', startPage: 453),
      const Surah(number: 39, name: 'الزمر', englishName: 'Az-Zumar', totalAyahs: 75, revelationType: 'Meccan', startPage: 458),
      const Surah(number: 40, name: 'غافر', englishName: 'Ghafir', totalAyahs: 85, revelationType: 'Meccan', startPage: 467),
      const Surah(number: 41, name: 'فصلت', englishName: 'Fussilat', totalAyahs: 54, revelationType: 'Meccan', startPage: 477),
      const Surah(number: 42, name: 'الشورى', englishName: 'Ash-Shura', totalAyahs: 53, revelationType: 'Meccan', startPage: 483),
      const Surah(number: 43, name: 'الزخرف', englishName: 'Az-Zukhruf', totalAyahs: 89, revelationType: 'Meccan', startPage: 489),
      const Surah(number: 44, name: 'الدخان', englishName: 'Ad-Dukhan', totalAyahs: 59, revelationType: 'Meccan', startPage: 496),
      const Surah(number: 45, name: 'الجاثية', englishName: 'Al-Jathiyah', totalAyahs: 37, revelationType: 'Meccan', startPage: 499),
      const Surah(number: 46, name: 'الأحقاف', englishName: 'Al-Ahqaf', totalAyahs: 35, revelationType: 'Meccan', startPage: 502),
      const Surah(number: 47, name: 'محمد', englishName: 'Muhammad', totalAyahs: 38, revelationType: 'Medinan', startPage: 507),
      const Surah(number: 48, name: 'الفتح', englishName: 'Al-Fath', totalAyahs: 29, revelationType: 'Medinan', startPage: 511),
      const Surah(number: 49, name: 'الحجرات', englishName: 'Al-Hujurat', totalAyahs: 18, revelationType: 'Medinan', startPage: 515),
      const Surah(number: 50, name: 'ق', englishName: 'Qaf', totalAyahs: 45, revelationType: 'Meccan', startPage: 518),
      const Surah(number: 51, name: 'الذاريات', englishName: 'Adh-Dhariyat', totalAyahs: 60, revelationType: 'Meccan', startPage: 520),
      const Surah(number: 52, name: 'الطور', englishName: 'At-Tur', totalAyahs: 49, revelationType: 'Meccan', startPage: 523),
      const Surah(number: 53, name: 'النجم', englishName: 'An-Najm', totalAyahs: 62, revelationType: 'Meccan', startPage: 526),
      const Surah(number: 54, name: 'القمر', englishName: 'Al-Qamar', totalAyahs: 55, revelationType: 'Meccan', startPage: 528),
      const Surah(number: 55, name: 'الرحمن', englishName: 'Ar-Rahman', totalAyahs: 78, revelationType: 'Medinan', startPage: 531),
      const Surah(number: 56, name: 'الواقعة', englishName: 'Al-Waqi\'ah', totalAyahs: 96, revelationType: 'Meccan', startPage: 534),
      const Surah(number: 57, name: 'الحديد', englishName: 'Al-Hadid', totalAyahs: 29, revelationType: 'Medinan', startPage: 537),
      const Surah(number: 58, name: 'المجادلة', englishName: 'Al-Mujadilah', totalAyahs: 22, revelationType: 'Medinan', startPage: 542),
      const Surah(number: 59, name: 'الحشر', englishName: 'Al-Hashr', totalAyahs: 24, revelationType: 'Medinan', startPage: 545),
      const Surah(number: 60, name: 'الممتحنة', englishName: 'Al-Mumtahanah', totalAyahs: 13, revelationType: 'Medinan', startPage: 549),
      const Surah(number: 61, name: 'الصف', englishName: 'As-Saff', totalAyahs: 14, revelationType: 'Medinan', startPage: 551),
      const Surah(number: 62, name: 'الجمعة', englishName: 'Al-Jumu\'ah', totalAyahs: 11, revelationType: 'Medinan', startPage: 553),
      const Surah(number: 63, name: 'المنافقون', englishName: 'Al-Munafiqun', totalAyahs: 11, revelationType: 'Medinan', startPage: 554),
      const Surah(number: 64, name: 'التغابن', englishName: 'At-Taghabun', totalAyahs: 18, revelationType: 'Medinan', startPage: 556),
      const Surah(number: 65, name: 'الطلاق', englishName: 'At-Talaq', totalAyahs: 12, revelationType: 'Medinan', startPage: 558),
      const Surah(number: 66, name: 'التحريم', englishName: 'At-Tahrim', totalAyahs: 12, revelationType: 'Medinan', startPage: 560),
      const Surah(number: 67, name: 'الملك', englishName: 'Al-Mulk', totalAyahs: 30, revelationType: 'Meccan', startPage: 562),
      const Surah(number: 68, name: 'القلم', englishName: 'Al-Qalam', totalAyahs: 52, revelationType: 'Meccan', startPage: 564),
      const Surah(number: 69, name: 'الحاقة', englishName: 'Al-Haqqah', totalAyahs: 52, revelationType: 'Meccan', startPage: 566),
      const Surah(number: 70, name: 'المعارج', englishName: 'Al-Ma\'arij', totalAyahs: 44, revelationType: 'Meccan', startPage: 568),
      const Surah(number: 71, name: 'نوح', englishName: 'Nuh', totalAyahs: 28, revelationType: 'Meccan', startPage: 570),
      const Surah(number: 72, name: 'الجن', englishName: 'Al-Jinn', totalAyahs: 28, revelationType: 'Meccan', startPage: 572),
      const Surah(number: 73, name: 'المزمل', englishName: 'Al-Muzzammil', totalAyahs: 20, revelationType: 'Meccan', startPage: 574),
      const Surah(number: 74, name: 'المدثر', englishName: 'Al-Muddaththir', totalAyahs: 56, revelationType: 'Meccan', startPage: 575),
      const Surah(number: 75, name: 'القيامة', englishName: 'Al-Qiyamah', totalAyahs: 40, revelationType: 'Meccan', startPage: 577),
      const Surah(number: 76, name: 'الإنسان', englishName: 'Al-Insan', totalAyahs: 31, revelationType: 'Medinan', startPage: 578),
      const Surah(number: 77, name: 'المرسلات', englishName: 'Al-Mursalat', totalAyahs: 50, revelationType: 'Meccan', startPage: 580),
      const Surah(number: 78, name: 'النبأ', englishName: 'An-Naba', totalAyahs: 40, revelationType: 'Meccan', startPage: 582),
      const Surah(number: 79, name: 'النازعات', englishName: 'An-Nazi\'at', totalAyahs: 46, revelationType: 'Meccan', startPage: 583),
      const Surah(number: 80, name: 'عبس', englishName: '\'Abasa', totalAyahs: 42, revelationType: 'Meccan', startPage: 585),
      const Surah(number: 81, name: 'التكوير', englishName: 'At-Takwir', totalAyahs: 29, revelationType: 'Meccan', startPage: 586),
      const Surah(number: 82, name: 'الانفطار', englishName: 'Al-Infitar', totalAyahs: 19, revelationType: 'Meccan', startPage: 587),
      const Surah(number: 83, name: 'المطففين', englishName: 'Al-Mutaffifin', totalAyahs: 36, revelationType: 'Meccan', startPage: 588),
      const Surah(number: 84, name: 'الانشقاق', englishName: 'Al-Inshiqaq', totalAyahs: 25, revelationType: 'Meccan', startPage: 589),
      const Surah(number: 85, name: 'البروج', englishName: 'Al-Buruj', totalAyahs: 22, revelationType: 'Meccan', startPage: 590),
      const Surah(number: 86, name: 'الطارق', englishName: 'At-Tariq', totalAyahs: 17, revelationType: 'Meccan', startPage: 591),
      const Surah(number: 87, name: 'الأعلى', englishName: 'Al-A\'la', totalAyahs: 19, revelationType: 'Meccan', startPage: 591),
      const Surah(number: 88, name: 'الغاشية', englishName: 'Al-Ghashiyah', totalAyahs: 26, revelationType: 'Meccan', startPage: 592),
      const Surah(number: 89, name: 'الفجر', englishName: 'Al-Fajr', totalAyahs: 30, revelationType: 'Meccan', startPage: 593),
      const Surah(number: 90, name: 'البلد', englishName: 'Al-Balad', totalAyahs: 20, revelationType: 'Meccan', startPage: 594),
      const Surah(number: 91, name: 'الشمس', englishName: 'Ash-Shams', totalAyahs: 15, revelationType: 'Meccan', startPage: 595),
      const Surah(number: 92, name: 'الليل', englishName: 'Al-Layl', totalAyahs: 21, revelationType: 'Meccan', startPage: 595),
      const Surah(number: 93, name: 'الضحى', englishName: 'Ad-Duha', totalAyahs: 11, revelationType: 'Meccan', startPage: 596),
      const Surah(number: 94, name: 'الشرح', englishName: 'Ash-Sharh', totalAyahs: 8, revelationType: 'Meccan', startPage: 596),
      const Surah(number: 95, name: 'التين', englishName: 'At-Tin', totalAyahs: 8, revelationType: 'Meccan', startPage: 597),
      const Surah(number: 96, name: 'العلق', englishName: 'Al-\'Alaq', totalAyahs: 19, revelationType: 'Meccan', startPage: 597),
      const Surah(number: 97, name: 'القدر', englishName: 'Al-Qadr', totalAyahs: 5, revelationType: 'Meccan', startPage: 598),
      const Surah(number: 98, name: 'البينة', englishName: 'Al-Bayyinah', totalAyahs: 8, revelationType: 'Medinan', startPage: 598),
      const Surah(number: 99, name: 'الزلزلة', englishName: 'Az-Zalzalah', totalAyahs: 8, revelationType: 'Medinan', startPage: 599),
      const Surah(number: 100, name: 'العاديات', englishName: 'Al-\'Adiyat', totalAyahs: 11, revelationType: 'Meccan', startPage: 599),
      const Surah(number: 101, name: 'القارعة', englishName: 'Al-Qari\'ah', totalAyahs: 11, revelationType: 'Meccan', startPage: 600),
      const Surah(number: 102, name: 'التكاثر', englishName: 'At-Takathur', totalAyahs: 8, revelationType: 'Meccan', startPage: 600),
      const Surah(number: 103, name: 'العصر', englishName: 'Al-\'Asr', totalAyahs: 3, revelationType: 'Meccan', startPage: 601),
      const Surah(number: 104, name: 'الهمزة', englishName: 'Al-Humazah', totalAyahs: 9, revelationType: 'Meccan', startPage: 601),
      const Surah(number: 105, name: 'الفيل', englishName: 'Al-Fil', totalAyahs: 5, revelationType: 'Meccan', startPage: 601),
      const Surah(number: 106, name: 'قريش', englishName: 'Quraysh', totalAyahs: 4, revelationType: 'Meccan', startPage: 602),
      const Surah(number: 107, name: 'الماعون', englishName: 'Al-Ma\'un', totalAyahs: 7, revelationType: 'Meccan', startPage: 602),
      const Surah(number: 108, name: 'الكوثر', englishName: 'Al-Kawthar', totalAyahs: 3, revelationType: 'Meccan', startPage: 602),
      const Surah(number: 109, name: 'الكافرون', englishName: 'Al-Kafirun', totalAyahs: 6, revelationType: 'Meccan', startPage: 603),
      const Surah(number: 110, name: 'النصر', englishName: 'An-Nasr', totalAyahs: 3, revelationType: 'Medinan', startPage: 603),
      const Surah(number: 111, name: 'المسد', englishName: 'Al-Masad', totalAyahs: 5, revelationType: 'Meccan', startPage: 603),
      const Surah(number: 112, name: 'الإخلاص', englishName: 'Al-Ikhlas', totalAyahs: 4, revelationType: 'Meccan', startPage: 604),
      const Surah(number: 113, name: 'الفلق', englishName: 'Al-Falaq', totalAyahs: 5, revelationType: 'Meccan', startPage: 604),
      const Surah(number: 114, name: 'الناس', englishName: 'An-Nas', totalAyahs: 6, revelationType: 'Meccan', startPage: 604),
    ];
    _isLoaded = true;
    print('✅ Loaded all ${_surahs.length} surahs from complete dataset');
  }

  /// Get surah by number
  Surah? getSurahByNumber(int number) {
    try {
      return _surahs.firstWhere((surah) => surah.number == number);
    } catch (e) {
      return null;
    }
  }

  /// Get surah by page number
  Surah? getSurahByPage(int pageNumber) {
    if (!_isLoaded || pageNumber < 1 || pageNumber > 604) return null;
    
    for (int i = _surahs.length - 1; i >= 0; i--) {
      if (_surahs[i].startPage <= pageNumber) {
        return _surahs[i];
      }
    }
    return _surahs.first;
  }

  /// Search surahs by name or number
  List<Surah> searchSurahs(String query) {
    if (!_isLoaded) return [];
    
    final lowerQuery = query.toLowerCase();
    return _surahs.where((surah) {
      return surah.name.toLowerCase().contains(lowerQuery) ||
             surah.englishName.toLowerCase().contains(lowerQuery) ||
             surah.number.toString().contains(query);
    }).toList();
  }

  /// Save last read page
  Future<void> saveLastReadPage(int pageNumber, {int? surahNumber}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastReadPageKey, pageNumber);
      if (surahNumber != null) {
        await prefs.setInt(_lastReadSurahKey, surahNumber);
      }
      print('💾 Saved last read page: $pageNumber');
    } catch (e) {
      print('❌ Error saving last read page: $e');
    }
  }

  /// Get last read page
  Future<int?> getLastReadPage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_lastReadPageKey);
    } catch (e) {
      print('❌ Error getting last read page: $e');
      return null;
    }
  }

  /// Get last read surah
  Future<int?> getLastReadSurah() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_lastReadSurahKey);
    } catch (e) {
      print('❌ Error getting last read surah: $e');
      return null;
    }
  }

  /// Save bookmark
  Future<void> saveBookmark(int pageNumber, {int? surahNumber}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarks = prefs.getStringList(_bookmarksKey) ?? [];
      
      final bookmarkData = {
        'page': pageNumber,
        'surah': surahNumber,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      bookmarks.add(json.encode(bookmarkData));
      await prefs.setStringList(_bookmarksKey, bookmarks);
      print('🔖 Saved bookmark at page: $pageNumber');
    } catch (e) {
      print('❌ Error saving bookmark: $e');
    }
  }

  /// Get all bookmarks
  Future<List<Map<String, dynamic>>> getBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarks = prefs.getStringList(_bookmarksKey) ?? [];
      
      return bookmarks
          .map((bookmark) => json.decode(bookmark) as Map<String, dynamic>)
          .toList()
        ..sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
    } catch (e) {
      print('❌ Error getting bookmarks: $e');
      return [];
    }
  }

  /// Remove bookmark
  Future<void> removeBookmark(int pageNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarks = prefs.getStringList(_bookmarksKey) ?? [];
      
      final filteredBookmarks = bookmarks.where((bookmark) {
        final bookmarkData = json.decode(bookmark) as Map<String, dynamic>;
        return bookmarkData['page'] != pageNumber;
      }).toList();
      
      await prefs.setStringList(_bookmarksKey, filteredBookmarks);
      print('🗑️ Removed bookmark at page: $pageNumber');
    } catch (e) {
      print('❌ Error removing bookmark: $e');
    }
  }

  /// Check if page is bookmarked
  Future<bool> isPageBookmarked(int pageNumber) async {
    try {
      final bookmarks = await getBookmarks();
      return bookmarks.any((bookmark) => bookmark['page'] == pageNumber);
    } catch (e) {
      print('❌ Error checking bookmark: $e');
      return false;
    }
  }
}
