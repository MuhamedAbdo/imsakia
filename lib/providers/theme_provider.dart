import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'settings_provider.dart';

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _themeMode = AppThemeMode.system;
  SharedPreferences? _prefs;

  AppThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    // Don't load theme mode here - let SettingsProvider handle it
    // This prevents duplicate loading and race conditions
  }

  /// Sync theme mode with SettingsProvider
  void syncWithSettingsProvider(AppThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      // Defer notifyListeners to avoid calling during build phase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
      debugPrint('🎨 ThemeProvider synced with: ${mode.toString().split('.').last}');
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    await _prefs?.setString('theme_mode', mode.toString().split('.').last);
    notifyListeners();
  }

  ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E88E5),
      brightness: Brightness.light,
      primary: const Color(0xFF1E88E5),
      secondary: const Color(0xFFD4AF37),
      surface: const Color(0xFFF5F5F5),
      background: const Color(0xFFFAFAFA),
    ),
    scaffoldBackgroundColor: const Color(0xFFFAFAFA),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E88E5),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black12,
    ),
    textTheme: GoogleFonts.tajawalTextTheme().copyWith(
      headlineLarge: GoogleFonts.tajawal(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1E88E5),
      ),
      headlineMedium: GoogleFonts.tajawal(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1E88E5),
      ),
      bodyLarge: GoogleFonts.tajawal(
        fontSize: 16,
        color: const Color(0xFF212121),
      ),
      bodyMedium: GoogleFonts.tajawal(
        fontSize: 14,
        color: const Color(0xFF424242),
      ),
    ),
  );

  ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E88E5),
      brightness: Brightness.dark,
      primary: const Color(0xFF64B5F6),
      secondary: const Color(0xFFD4AF37),
      surface: const Color(0xFF1E1E1E),
      background: const Color(0xFF121212),
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: Color(0xFF64B5F6),
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1E1E1E),
      elevation: 4,
      shadowColor: Colors.black26,
    ),
    textTheme: GoogleFonts.tajawalTextTheme(ThemeData.dark().textTheme).copyWith(
      headlineLarge: GoogleFonts.tajawal(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF64B5F6),
      ),
      headlineMedium: GoogleFonts.tajawal(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF64B5F6),
      ),
      bodyLarge: GoogleFonts.tajawal(
        fontSize: 16,
        color: const Color(0xFFE0E0E0),
      ),
      bodyMedium: GoogleFonts.tajawal(
        fontSize: 14,
        color: const Color(0xFFBDBDBD),
      ),
    ),
  );
}
