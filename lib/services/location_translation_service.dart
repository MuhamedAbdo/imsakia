class LocationTranslationService {
  // 🌍 22 Arab League Countries (English Key -> Arabic Display)
  static const Map<String, String> countryTranslations = {
    'Egypt': 'مصر',
    'Saudi Arabia': 'السالمية العربية السعودية',
    'United Arab Emirates': 'الإمارات العربية المتحدة',
    'Kuwait': 'الكويت',
    'Qatar': 'قطر',
    'Oman': 'عمان',
    'Bahrain': 'البحرين',
    'Jordan': 'الأردن',
    'Palestine': 'فلسطين',
    'Lebanon': 'لبنان',
    'Syria': 'سوريا',
    'Iraq': 'العراق',
    'Yemen': 'اليمن',
    'Libya': 'ليبيا',
    'Tunisia': 'تونس',
    'Algeria': 'الجزائر',
    'Morocco': 'المغرب',
    'Sudan': 'السودان',
    'Mauritania': 'موريتانيا',
    'Somalia': 'الصومال',
    'Djibouti': 'جيبوتي',
    'Comoros': 'جزر القمر',
  };

  // 🏛 Major States Translations (Major regions in EG, KSA, UAE)
  static const Map<String, String> stateTranslations = {
    // Egypt
    'Cairo': 'القاهرة',
    'Giza': 'الجيزة',
    'Alexandria': 'الإسكندرية',
    'Dakahlia': 'الدقهلية',
    'Red Sea': 'البحر الأحمر',
    'Beheira': 'البحيرة',
    'Faiyum': 'الفيوم',
    'Gharbia': 'الغربية',
    'Ismailia': 'الإسماعيلية',
    'Monufia': 'المنوفية',
    'Minya': 'المنيا',
    'Qalyubia': 'القليوبية',
    'New Valley': 'الوادي الجديد',
    'Suez': 'السويس',
    'Aswan': 'أسوان',
    'Assiut': 'أسيوط',
    'Beni Suef': 'بني سويف',
    'Port Said': 'بورسعيد',
    'Damietta': 'دمياط',
    'Sharqia': 'الشرقية',
    'South Sinai': 'جنوب سيناء',
    'Kafr el-Sheikh': 'كفر الشيخ',
    'Matrouh': 'مطروح',
    'Luxor': 'الأقصر',
    'Qena': 'قنا',
    'North Sinai': 'شمال سيناء',
    'Sohag': 'سوهاج',

    // Saudi Arabia
    'Riyadh': 'الرياض',
    'Makkah': 'مكة المكرمة',
    'Madinah': 'المدينة المنورة',
    'Jeddah': 'جدة',
    'Eastern Province': 'المنطقة الشرقية',
    'Asir': 'عسير',
    'Tabuk': 'تبوك',
    'Hail': 'حائل',
    'Qassim': 'القصيم',
    'Jazan': 'جازان',
    'Najran': 'نجران',
    'Al Bahah': 'الباحة',
    'Al Jawf': 'الجوف',

    // UAE
    'Dubai': 'دبي',
    'Abu Dhabi': 'أبو ظبي',
    'Sharjah': 'الشارقة',
    'Ajman': 'عجمان',
    'Umm Al Quwain': 'أم القيوين',
    'Ras Al Khaimah': 'رأس الخيمة',
    'Fujairah': 'الفجيرة',
  };

  static String getArabicCountryName(String englishName) {
    return countryTranslations[englishName] ?? englishName;
  }

  static String getArabicStateName(String englishName) {
    // Handle cases like "Cairo Governorate" or "Makkah Province"
    final cleanName = englishName
        .replaceAll(' Governorate', '')
        .replaceAll(' Province', '')
        .trim();
    return stateTranslations[cleanName] ??
        stateTranslations[englishName] ??
        englishName;
  }

  static bool isArabCountry(String englishName) {
    return countryTranslations.containsKey(englishName);
  }

  // 🔍 محرك البحث الثنائي (Bilingual Search)
  static bool matchesSearch(String query, String englishName) {
    if (query.isEmpty) return true;
    final lowercaseQuery = query.toLowerCase();

    // Check English
    if (englishName.toLowerCase().contains(lowercaseQuery)) return true;

    // Check Arabic
    final arabicName = getArabicCountryName(englishName);
    if (arabicName.contains(query)) return true;

    return false;
  }
}
