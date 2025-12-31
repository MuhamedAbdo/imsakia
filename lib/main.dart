import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/main_layout.dart';
import 'services/athan_player_service.dart';
import 'services/hadith_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  await AthanPlayerService.instance.initialize();
  
  // Initialize SettingsProvider and load theme before building app
  final settingsProvider = SettingsProvider();
  await settingsProvider.initialize();
  
  // Initialize ThemeProvider and sync with SettingsProvider
  final themeProvider = ThemeProvider();
  themeProvider.syncWithSettingsProvider(settingsProvider.themeMode);
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: HadithService.instance),
      ],
      child: const MyApp(),
    ),
  );
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
