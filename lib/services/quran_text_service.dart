import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/quran_models.dart';

class QuranTextService {
  static final QuranTextService _instance = QuranTextService._internal();
  factory QuranTextService() => _instance;
  QuranTextService._internal();

  List<QuranSurah> _surahs = [];
  bool _isLoaded = false;

  // خريطة دقيقة لبدايات الأرباع (سورة:آية)
  // تم ضبطها لتتوافق مع ملف الـ XML الخاص بك
  final Map<String, Map<String, int>> _quartersMap = {
    "1:1": {"q": 1, "j": 1},   // الفاتحة
    "2:1": {"q": 1, "j": 1},   // البقرة 1
    "2:26": {"q": 2, "j": 1},  // البقرة 26
    "2:44": {"q": 3, "j": 1},  // البقرة 44
    "2:60": {"q": 4, "j": 1},  // البقرة 60
    "2:75": {"q": 5, "j": 1},  // البقرة 75
    "2:92": {"q": 6, "j": 1},  // البقرة 92
    "2:106": {"q": 7, "j": 1}, // البقرة 106
    "2:124": {"q": 8, "j": 1}, // البقرة 124
    "2:142": {"q": 9, "j": 2}, // بداية الجزء الثاني
    "3:93": {"q": 22, "j": 4}, 
    "4:1": {"q": 25, "j": 4},  // بداية الجزء الرابع
    "5:1": {"q": 41, "j": 6},  // بداية الجزء السادس
    "5:11": {"q": 43, "j": 6}, // ربع سورة المائدة آية 11
  };

  Map<String, int>? getHizbDetails(int s, int a) {
    return _quartersMap["$s:$a"];
  }

  Future<void> loadQuranData() async {
    if (_isLoaded) return;
    String surahsJson = await rootBundle.loadString('assets/data/surahs.json');
    List<dynamic> surahsData = json.decode(surahsJson);
    String quranXml = await rootBundle.loadString('assets/data/quran.json.xml');
    _surahs = await _parseQuranXml(quranXml, surahsData);
    _isLoaded = true;
  }

  Future<List<QuranSurah>> _parseQuranXml(String xml, List<dynamic> surahsData) async {
    List<QuranSurah> surahs = [];
    final surahRegex = RegExp(r'<sura[^>]*index="(\d+)"[^>]*name="([^"]*)"[^>]*>(.*?)</sura>', dotAll: true);
    final ayahRegex = RegExp(r'<aya index="(\d+)" text="([^"]*)"');
    final surahMatches = surahRegex.allMatches(xml);
    for (var match in surahMatches) {
      int sIndex = int.parse(match.group(1)!);
      List<QuranAyah> ayahs = [];
      final ayahMatches = ayahRegex.allMatches(match.group(3)!);
      for (var aMatch in ayahMatches) {
        ayahs.add(QuranAyah(
          surahNumber: sIndex,
          ayahNumber: int.parse(aMatch.group(1)!),
          arabicText: aMatch.group(2)!.replaceAll('&quot;', '"'),
        ));
      }
      surahs.add(QuranSurah(
        number: sIndex,
        name: surahsData[sIndex-1]['name'],
        ayahs: ayahs,
        englishName: surahsData[sIndex-1]['englishName'],
        revelationType: surahsData[sIndex-1]['revelationType'],
        ayahCount: ayahs.length,
      ));
    }
    return surahs;
  }

  Future<void> saveProgress(int index, double offset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_read_index', index);
    await prefs.setDouble('last_read_offset', offset);
  }

  Future<Map<String, dynamic>?> getProgress() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('last_read_index')) return null;
    return {'index': prefs.getInt('last_read_index'), 'offset': prefs.getDouble('last_read_offset')};
  }

  Future<void> saveBookmark(int index, double offset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bookmark_index', index);
    await prefs.setDouble('bookmark_offset', offset);
  }

  Future<Map<String, dynamic>?> getBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('bookmark_index')) return null;
    return {'index': prefs.getInt('bookmark_index'), 'offset': prefs.getDouble('bookmark_offset')};
  }

  List<QuranSurah> get surahs => _surahs;
  Future<void> saveFontSize(double s) async => (await SharedPreferences.getInstance()).setDouble('font_size', s);
  Future<double> getFontSize() async => (await SharedPreferences.getInstance()).getDouble('font_size') ?? 24.0;
}