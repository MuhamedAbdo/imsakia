import 'package:flutter/material.dart';

class AppConstants {
  // App Info
  static const String appName = 'إمساكية';
  static const String appVersion = '1.0.0';

  // Splash Screen Text
  static const String splashTitle = 'صدقة جارية لروح المرحوم';
  static const String splashSubtitle = 'بإذن الله';
  static const String splashDedication = 'عبدالعال حسن عبدالعال';

  // Prayer Names (Arabic)
  static const List<String> prayerNames = [
    'الفجر',
    'الشروق',
    'الظهر',
    'العصر',
    'المغرب',
    'العشاء',
  ];

  // Prayer Names for calculation
  static const List<String> prayerNamesEn = [
    'Fajr',
    'Sunrise',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];

  // Colors
  static const Color primaryColor = Color(0xFF1E88E5);
  static const Color secondaryColor = Color(0xFFD4AF37);
  static const Color accentColor = Color(0xFF4CAF50);
  static const Color surfaceColor = Color(0xFFF5F5F5);
  static const Color backgroundColor = Color(0xFFFAFAFA);

  // Dark Theme Colors
  static const Color darkPrimaryColor = Color(0xFF64B5F6);
  static const Color darkSurfaceColor = Color(0xFF1E1E1E);
  static const Color darkBackgroundColor = Color(0xFF121212);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1E88E5),
      Color(0xFF1565C0),
    ],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFD4AF37),
      Color(0xFFF4E4BC),
      Color(0xFFD4AF37),
    ],
  );

  // SharedPreferences Keys
  static const String isFirstLaunchKey = 'is_first_launch';
  static const String themeModeKey = 'theme_mode';
  static const String locationKey = 'location';
  static const String selectedCityKey = 'selected_city';
  static const String calculationMethodKey = 'calculation_method';
  static const String madhabKey = 'madhab';
  static const String dstKey = 'dst_enabled';
  static const String athanSoundKey = 'athan_sound';
  static const String notificationsKey = 'notifications_enabled';

  // Default Settings
  static const double defaultLatitude = 30.0444; // Cairo
  static const double defaultLongitude = 31.2357; // Cairo
  static const String defaultCity = 'cairo';
  static const String defaultCalculationMethod = 'egyptian';
  static const String defaultMadhab = 'shafi';
  static const bool defaultDST = false;
  static const String defaultAthanSound = 'default';

  // Cities Data
  static const List<Map<String, dynamic>> cities = [
    {
      'id': 'cairo',
      'name': 'القاهرة',
      'nameEn': 'Cairo',
      'country': 'مصر',
      'latitude': 30.0444,
      'longitude': 31.2357,
      'timezone': 'Africa/Cairo',
    },
    {
      'id': 'riyadh',
      'name': 'الرياض',
      'nameEn': 'Riyadh',
      'country': 'السعودية',
      'latitude': 24.7136,
      'longitude': 46.6753,
      'timezone': 'Asia/Riyadh',
    },
    {
      'id': 'mecca',
      'name': 'مكة المكرمة',
      'nameEn': 'Mecca',
      'country': 'السعودية',
      'latitude': 21.3891,
      'longitude': 39.8579,
      'timezone': 'Asia/Riyadh',
    },
    {
      'id': 'medina',
      'name': 'المدينة المنورة',
      'nameEn': 'Medina',
      'country': 'السعودية',
      'latitude': 24.4584,
      'longitude': 39.6104,
      'timezone': 'Asia/Riyadh',
    },
    {
      'id': 'dubai',
      'name': 'دبي',
      'nameEn': 'Dubai',
      'country': 'الإمارات',
      'latitude': 25.2048,
      'longitude': 55.2708,
      'timezone': 'Asia/Dubai',
    },
    {
      'id': 'kuwait',
      'name': 'الكويت',
      'nameEn': 'Kuwait',
      'country': 'الكويت',
      'latitude': 29.3117,
      'longitude': 47.4818,
      'timezone': 'Asia/Kuwait',
    },
    {
      'id': 'amman',
      'name': 'عمان',
      'nameEn': 'Amman',
      'country': 'الأردن',
      'latitude': 31.9539,
      'longitude': 35.9106,
      'timezone': 'Asia/Amman',
    },
    {
      'id': 'beirut',
      'name': 'بيروت',
      'nameEn': 'Beirut',
      'country': 'لبنان',
      'latitude': 33.8938,
      'longitude': 35.5018,
      'timezone': 'Asia/Beirut',
    },
    {
      'id': 'damascus',
      'name': 'دمشق',
      'nameEn': 'Damascus',
      'country': 'سوريا',
      'latitude': 33.5138,
      'longitude': 36.2765,
      'timezone': 'Asia/Damascus',
    },
    {
      'id': 'jerusalem',
      'name': 'القدس',
      'nameEn': 'Jerusalem',
      'country': 'فلسطين',
      'latitude': 31.7683,
      'longitude': 35.2137,
      'timezone': 'Asia/Jerusalem',
    },
    {
      'id': 'baghdad',
      'name': 'بغداد',
      'nameEn': 'Baghdad',
      'country': 'العراق',
      'latitude': 33.3152,
      'longitude': 44.3661,
      'timezone': 'Asia/Baghdad',
    },
    {
      'id': 'tehran',
      'name': 'طهران',
      'nameEn': 'Tehran',
      'country': 'إيران',
      'latitude': 35.6892,
      'longitude': 51.3890,
      'timezone': 'Asia/Tehran',
    },
    {
      'id': 'istanbul',
      'name': 'إسطنبول',
      'nameEn': 'Istanbul',
      'country': 'تركيا',
      'latitude': 41.0082,
      'longitude': 28.9784,
      'timezone': 'Europe/Istanbul',
    },
    {
      'id': 'casablanca',
      'name': 'الدار البيضاء',
      'nameEn': 'Casablanca',
      'country': 'المغرب',
      'latitude': 33.5731,
      'longitude': -7.5898,
      'timezone': 'Africa/Casablanca',
    },
    {
      'id': 'algiers',
      'name': 'الجزائر',
      'nameEn': 'Algiers',
      'country': 'الجزائر',
      'latitude': 36.7538,
      'longitude': 3.0588,
      'timezone': 'Africa/Algiers',
    },
    {
      'id': 'tunis',
      'name': 'تونس',
      'nameEn': 'Tunis',
      'country': 'تونس',
      'latitude': 36.8065,
      'longitude': 10.1815,
      'timezone': 'Africa/Tunis',
    },
    {
      'id': 'khartoum',
      'name': 'الخرطوم',
      'nameEn': 'Khartoum',
      'country': 'السودان',
      'latitude': 15.5007,
      'longitude': 32.5599,
      'timezone': 'Africa/Khartoum',
    },
    {
      'id': 'sanaa',
      'name': 'صنعاء',
      'nameEn': 'Sanaa',
      'country': 'اليمن',
      'latitude': 15.3694,
      'longitude': 44.1910,
      'timezone': 'Asia/Aden',
    },
    {
      'id': 'doha',
      'name': 'الدوحة',
      'nameEn': 'Doha',
      'country': 'قطر',
      'latitude': 25.2854,
      'longitude': 51.5310,
      'timezone': 'Asia/Qatar',
    },
    {
      'id': 'manama',
      'name': 'المنامة',
      'nameEn': 'Manama',
      'country': 'البحرين',
      'latitude': 26.0667,
      'longitude': 50.5577,
      'timezone': 'Asia/Bahrain',
    },
    {
      'id': 'muscat',
      'name': 'مسقط',
      'nameEn': 'Muscat',
      'country': 'عمان',
      'latitude': 23.5859,
      'longitude': 58.3827,
      'timezone': 'Asia/Muscat',
    },
  ];

  // Animation Durations
  static const Duration splashDuration = Duration(seconds: 3);
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration countdownUpdateInterval = Duration(seconds: 1);

  // Padding and Margins
  static const double smallPadding = 8.0;
  static const double mediumPadding = 16.0;
  static const double largePadding = 24.0;
  static const double extraLargePadding = 32.0;

  // Border Radius
  static const double smallBorderRadius = 8.0;
  static const double mediumBorderRadius = 12.0;
  static const double largeBorderRadius = 16.0;
  static const double extraLargeBorderRadius = 24.0;

  // Font Sizes
  static const double smallFontSize = 12.0;
  static const double mediumFontSize = 14.0;
  static const double largeFontSize = 16.0;
  static const double extraLargeFontSize = 20.0;
  static const double titleFontSize = 24.0;
  static const double headlineFontSize = 32.0;

  // Icon Sizes
  static const double smallIconSize = 16.0;
  static const double mediumIconSize = 24.0;
  static const double largeIconSize = 32.0;
  static const double extraLargeIconSize = 48.0;

  // Elevation
  static const double smallElevation = 2.0;
  static const double mediumElevation = 4.0;
  static const double largeElevation = 8.0;
}
