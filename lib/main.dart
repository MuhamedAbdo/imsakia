import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;

// Zad legacy providers (Keep these)
import 'providers/theme_provider.dart';
import 'providers/quran_provider.dart';
import 'providers/bukhari_provider.dart';
import 'services/hadith_service.dart';
import 'services/azkar_service.dart';
import 'package:imsakia/features/quran_madinah/providers/quran_provider.dart' as madinah;

// New Adhan Core Engine Services
import 'core/services/storage_service.dart';
import 'core/services/location_service.dart';
import 'core/services/prayer_times_service.dart';
import 'core/services/hijri_calendar_service.dart';
import 'core/services/aladhan_api_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/background_service.dart' as bg;

// New Adhan Core Engine Providers
import 'providers/settings_provider.dart';
import 'providers/location_provider.dart';
import 'providers/prayer_times_provider.dart';
import 'providers/hijri_calendar_provider.dart';
import 'providers/qibla_provider.dart';

// Screens
import 'screens/splash/splash_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/main_layout.dart';
import 'screens/athan/athan_overlay_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Arabic locale for date formatting
  await initializeDateFormatting('ar', null);

  // Time zones
  tz.initializeTimeZones();

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Initialize Adhan Storage Service
  final storageService = await StorageService.create();
  final settings = storageService.getSettings();

  // Initialize Adhan Notification Service
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Wire Adhan Services
  final aladhanApi = AladhanApiService();
  final hijriService = HijriCalendarService(aladhanApi);
  final locationService = LocationService();
  final prayerService = PrayerTimesService();

  // Start background service manually if athan is enabled
  await bg.BackgroundService.initialize();
  if (settings.athanEnabled) {
    await bg.BackgroundService.start();
  }

  // Start Zad non-critical services
  HadithService.instance.initialize();
  AzkarService.instance.initialize();

  // Handle notification taps (Athan overlay)
  final initialNotification = await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  final launchFromAthan = initialNotification?.didNotificationLaunchApp == true;
  
  String prayerNameAr = 'الصلاة';
  String prayerNameEn = 'Prayer';

  if (launchFromAthan) {
    try {
      final payloadStr = initialNotification?.notificationResponse?.payload;
      if (payloadStr != null && payloadStr.isNotEmpty) {
        final payload = jsonDecode(payloadStr);
        prayerNameAr = payload['ar'] ?? 'الصلاة';
        prayerNameEn = payload['en'] ?? 'Prayer';
      }
    } catch (_) {}
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        // Zad Legacy Providers
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: HadithService.instance),
        ChangeNotifierProvider(create: (_) => QuranProvider()),
        ChangeNotifierProvider(create: (_) => BukhariProvider()),
        ChangeNotifierProvider(create: (_) => madinah.QuranProvider(prefs)),

        // New Adhan Providers
        ChangeNotifierProvider(create: (_) => SettingsProvider(storageService)),
        ChangeNotifierProvider(create: (_) => LocationProvider(locationService, storageService)),
        ChangeNotifierProvider(create: (_) => PrayerTimesProvider(prayerService)),
        ChangeNotifierProvider(create: (_) => HijriCalendarProvider(hijriService)),
        ChangeNotifierProvider(create: (_) => QiblaProvider()),
      ],
      child: MyApp(
        launchFromAthan: launchFromAthan,
        prayerNameAr: prayerNameAr,
        prayerNameEn: prayerNameEn,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool launchFromAthan;
  final String prayerNameAr;
  final String prayerNameEn;

  const MyApp({
    super.key,
    this.launchFromAthan = false,
    this.prayerNameAr = 'الصلاة',
    this.prayerNameEn = 'Prayer',
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Consumer<SettingsProvider>(
          builder: (context, settingsProvider, child) {
            themeProvider.syncWithSettingsProvider(
              // Assuming settingsProvider.isDarkMode handles boolean now (from adhan logic)
              settingsProvider.isDarkMode ? AppThemeMode.dark : AppThemeMode.light,
            );

            return MaterialApp(
              title: settingsProvider.languageCode == 'ar' ? 'زاد' : 'Zad',
              navigatorKey: navigatorKey,
              debugShowCheckedModeBanner: false,
              theme: themeProvider.lightTheme,
              darkTheme: themeProvider.darkTheme,
              themeMode: settingsProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
              home: launchFromAthan
                  ? AthanOverlayScreen(
                      prayerNameAr: prayerNameAr,
                      prayerNameEn: prayerNameEn,
                    )
                  : const SplashScreen(),
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
    );
  }
}
