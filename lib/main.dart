import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/quran_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/main_layout.dart';
import 'services/athan_player_service.dart';
import 'services/hadith_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize services with timeout
    await AthanPlayerService.instance.initialize()
        .timeout(const Duration(seconds: 3), onTimeout: () {
      print('⚠️ AthanPlayerService initialization timeout, continuing...');
    });
    
    // Initialize SettingsProvider and load theme before building app
    final settingsProvider = SettingsProvider();
    await settingsProvider.initialize()
        .timeout(const Duration(seconds: 3), onTimeout: () {
      print('⚠️ SettingsProvider initialization timeout, using defaults...');
    });
    
    // Initialize ThemeProvider and sync with SettingsProvider
    final themeProvider = ThemeProvider();
    themeProvider.syncWithSettingsProvider(settingsProvider.themeMode);
    
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: themeProvider),
          ChangeNotifierProvider.value(value: settingsProvider),
          ChangeNotifierProvider.value(value: HadithService.instance),
          ChangeNotifierProvider(create: (_) => QuranProvider()),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e) {
    print('❌ Error during app initialization: $e');
    // Run app with default providers even if initialization fails
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider.value(value: HadithService.instance),
          ChangeNotifierProvider(create: (_) => QuranProvider()),
        ],
        child: const MyApp(),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, SettingsProvider>(
      builder: (context, themeProvider, settingsProvider, child) {
        // Ensure settings are loaded before building MaterialApp
        if (!settingsProvider.isInitialized) {
          return MaterialApp(
            home: Scaffold(
              body: Container(
                color: Colors.white,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          );
        }

        return MaterialApp(
          title: 'إمساكية',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: _getThemeMode(settingsProvider.themeMode),
          home: const SplashScreen(),
          routes: {
            '/settings': (context) => const SettingsScreen(),
            '/main': (context) => const MainLayout(),
          },
        );
      },
    );
  }

  ThemeMode _getThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}
