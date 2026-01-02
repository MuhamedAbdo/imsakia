import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/quran_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/main_layout.dart';
import 'services/hadith_service.dart';
import 'services/azkar_service.dart';
import 'services/background_athan_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services (except background athan service)
  await HadithService.instance.initialize();
  await AzkarService.instance.initialize();
  
  // Initialize settings provider first
  final settingsProvider = SettingsProvider();
  await settingsProvider.initialize();
  
  // Initialize background athan service AFTER settings are loaded
  try {
    await BackgroundAthanService.instance.initialize();
  } catch (e) {
    print('Background athan service initialization failed: $e');
    // Continue without background service
  }
  
  runApp(MyApp(settingsProvider: settingsProvider));
}

class MyApp extends StatelessWidget {
  final SettingsProvider settingsProvider;
  
  const MyApp({super.key, required this.settingsProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: HadithService.instance),
        ChangeNotifierProvider(create: (_) => QuranProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return Consumer<SettingsProvider>(
            builder: (context, settingsProvider, child) {
              // Sync theme providers
              themeProvider.syncWithSettingsProvider(settingsProvider.themeMode);
              
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
        },
      ),
    );
  }
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
