import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/quran_provider.dart';
import 'providers/bukhari_provider.dart'; // تأكد من وجود هذا الاستيراد
import 'screens/splash_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/main_layout.dart';
import 'services/hadith_service.dart';
import 'services/azkar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imsakia/features/quran_madinah/providers/quran_provider.dart'
    as madinah;
import 'features/audio/providers/audio_player_provider.dart';
import 'features/audio/providers/download_provider.dart';
import 'features/audio/services/audio_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Arabic locale for date formatting
  await initializeDateFormatting('ar', null);

  // تأخير تهيئة الخدمات غير الحرجة لتسريع بدء التطبيق وتجنب تقطيع الواجهة
  Future.delayed(const Duration(milliseconds: 500), () async {
    await initAudioService();
    await HadithService.instance.initialize();
    await AzkarService.instance.initialize();
  });
  final settingsProvider = SettingsProvider();
  await settingsProvider.initialize();

  final prefs = await SharedPreferences.getInstance();

  runApp(MyApp(settingsProvider: settingsProvider, prefs: prefs));
}

class MyApp extends StatelessWidget {
  final SettingsProvider settingsProvider;
  final SharedPreferences prefs;

  const MyApp({super.key, required this.settingsProvider, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: HadithService.instance),
        ChangeNotifierProvider(create: (_) => QuranProvider()),
        ChangeNotifierProvider(
          create: (_) => BukhariProvider(),
        ), // إضافة البروفايدر هنا
        ChangeNotifierProvider(create: (_) => madinah.QuranProvider(prefs)),
        ChangeNotifierProvider(create: (_) => AudioPlayerProvider()),
        ChangeNotifierProvider(create: (_) => DownloadProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return Consumer<SettingsProvider>(
            builder: (context, settingsProvider, child) {
              themeProvider.syncWithSettingsProvider(
                settingsProvider.themeMode,
              );

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
                builder: (context, child) {
                  SystemChrome.setPreferredOrientations([
                    DeviceOrientation.portraitUp,
                  ]);
                  return child!;
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
