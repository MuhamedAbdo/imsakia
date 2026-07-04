import 'package:flutter/material.dart';
import '../models/bukhari_model.dart';
import '../services/hadith_database_service.dart';

class BukhariProvider extends ChangeNotifier {
  List<BukhariHadith> _searchResults = [];
  List<Map<String, dynamic>> _sections = [];
  List<Map<String, dynamic>> _hadiths = [];
  bool _isLoading = false;

  List<BukhariHadith> get searchResults => _searchResults;
  List<Map<String, dynamic>> get sections => _sections;
  bool get isLoading => _isLoading;

  // خريطة ترجمة الأبواب بناءً على ترتيبها في صحيح البخاري (97 باباً)
  final Map<int, String> _arabicSections = {
    1: "بدء الوحي", 2: "الإيمان", 3: "العلم", 4: "الوضوء", 5: "الغسل",
    6: "الحيض", 7: "التيمم", 8: "الصلاة", 9: "مواقيت الصلاة", 10: "الأذان",
    11: "الجمعة", 12: "صلاة الخوف", 13: "العيدين", 14: "الوتر", 15: "الاستسقاء",
    16: "الكسوف", 17: "سجود القرآن", 18: "تقصير الصلاة", 19: "التهجد", 20: "فضل الصلاة بمكة والمدينة",
    21: "العمل في الصلاة", 22: "السهو", 23: "الجنائز", 24: "الزكاة", 25: "الحج",
    26: "العمرة", 27: "المحصر", 28: "جزاء الصيد", 29: "فضائل المدينة", 30: "الصوم",
    31: "صلاة التراويح", 32: "فضل ليلة القدر", 33: "الاعتكاف", 34: "البيوع", 35: "السلم",
    36: "الشفعة", 37: "الإجارة", 38: "الحوالات", 39: "الكفالة", 40: "الوكالة",
    41: "المزارعة", 42: "المساقاة", 43: "الاستقراض", 44: "الخصومات", 45: "اللقطة",
    46: "المظالم", 47: "الشركة", 48: "الرهن", 49: "العتق", 50: "المكاتب",
    51: "الهبة", 52: "الشهادات", 53: "الصلح", 54: "الشروط", 55: "الوصايا",
    56: "الجهاد والسير", 57: "الخمس", 58: "الجزية", 59: "بدء الخلق", 60: "أحاديث الأنبياء",
    61: "المناقب", 62: "فضائل الصحابة", 63: "مناقب الأنصار", 64: "المغازي", 65: "تفسير القرآن",
    66: "فضائل القرآن", 67: "النكاح", 68: "الطلاق", 69: "النفقات", 70: "الأطعمة",
    71: "العقيقة", 72: "الذبائح والصيد", 73: "الأضاحي", 74: "الأشربة", 75: "المرضى",
    76: "الطب", 77: "اللباس", 78: "الأدب", 79: "الاستئذان", 80: "الدعوات",
    81: "الرقاق", 82: "القدر", 83: "الأيمان والنذور", 84: "كفارات الأيمان", 85: "الفرائض",
    86: "الحدود", 87: "الديات", 88: "استتابة المرتدين", 89: "الإكراه", 90: "الحيل",
    91: "تعبير الرؤيا", 92: "الفتن", 93: "الأحكام", 94: "التمني", 95: "أخبار الآحاد",
    96: "الاعتصام بالكتاب والسنة", 97: "التوحيد"
  };

  String getArabicSectionName(int id, String fallback) {
    return _arabicSections[id] ?? fallback;
  }

  Future<void> initialize() async {
    if (_hadiths.isNotEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      final items = await HadithDatabaseService.instance.getHadiths('bukhari');
      _hadiths = items.map((item) => {
        'number': item.number,
        'hadith': item.hadith,
        'description': item.description,
      }).toList();

      // إنشاء الأبواب الافتراضية
      _sections = _arabicSections.entries.map((entry) {
        return {
          'id': entry.key,
          'section_name': entry.value,
        };
      }).toList();
    } catch (e) {
      debugPrint("Error loading Bukhari data from DB: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAllSections() async {
    await initialize();
  }

  Future<List<BukhariHadith>> fetchHadithsBySection(int sectionId) async {
    await initialize();

    final sectionHadiths = _hadiths.where((hadith) {
      return hadith['section_id'] == sectionId ||
             hadith['book'] == sectionId.toString() ||
             (hadith['number'] != null && (hadith['number'] as int) ~/ 100 + 1 == sectionId);
    }).toList();

    return sectionHadiths.map((m) => BukhariHadith.fromMap(m)).toList();
  }

  /// دالة البحث المطورة عبر SQLite
  Future<void> searchHadith(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final items = await HadithDatabaseService.instance
          .searchHadiths('bukhari', query.trim());

      _searchResults = items.map((item) => BukhariHadith(
        id: item.number,
        text: item.hadith,
      )).toList();
    } catch (e) {
      debugPrint("Search Error: $e");
    }

    _isLoading = false;
    notifyListeners();
  }
}
