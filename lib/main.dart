import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'dart:developer' as developer;

// Zad legacy providers
import 'providers/theme_provider.dart';
import 'providers/quran_provider.dart';
import 'providers/bukhari_provider.dart';
import 'services/hadith_service.dart';
import 'services/azkar_service.dart';
import 'package:imsakia/features/quran_madinah/providers/quran_provider.dart'
    as madinah;

// New Adhan Core Engine Services
import 'core/services/storage_service.dart';
import 'core/services/location_service.dart';
import 'core/services/prayer_times_service.dart';
import 'core/services/hijri_calendar_service.dart';
import 'core/services/aladhan_api_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/background_service.dart' as bg;
import 'core/services/athan_scheduling_service.dart';
import 'core/services/athan_audio_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart' as fbs;

// New Adhan Core Engine Providers
import 'providers/settings_provider.dart';
import 'providers/location_provider.dart';
import 'providers/prayer_times_provider.dart';
import 'providers/hijri_calendar_provider.dart';
import 'providers/qibla_provider.dart';
import 'features/audio/providers/audio_player_provider.dart';
import 'features/audio/providers/download_provider.dart';
import 'features/audio/services/audio_handler.dart';

// Screens
import 'screens/splash/splash_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/main_layout.dart';
import 'screens/athan/athan_overlay_screen.dart';
import 'screens/eid/eid_celebration_screen.dart';
import 'screens/settings/miui_guidance_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Audio Service
  await initAudioService();

  // Initialize Arabic locale
  await initializeDateFormatting('ar', null);

  // Time zones
  tz.initializeTimeZones();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  final storageService = await StorageService.create();
  final settings = storageService.getSettings();

  final notificationService = NotificationService();
  await notificationService.initialize();

  final aladhanApi = AladhanApiService();
  final hijriService = HijriCalendarService(aladhanApi);
  final locationService = LocationService();
  final prayerService = PrayerTimesService();

  // 1. Background Service Init
  await bg.BackgroundService.initialize();
  if (settings.athanEnabled) {
    await bg.BackgroundService.start();
  }
  
  // ── Bulletproof Native Athan Initialization (Keep for permissions)
  await AthanSchedulingService.ensureExactAlarmPermission();

  HadithService.instance.initialize();
  AzkarService.instance.initialize();

  final initialNotification = await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  final launchFromAthan = initialNotification?.didNotificationLaunchApp == true;

  String prayerNameAr = 'الصلاة';
  String prayerNameEn = 'Prayer';
  String? cityName;
  String? backgroundImage;

  if (launchFromAthan) {
    try {
      final payloadStr = initialNotification?.notificationResponse?.payload;
      if (payloadStr != null && payloadStr.isNotEmpty) {
        final payload = jsonDecode(payloadStr);
        prayerNameAr = payload['ar'] ?? 'الصلاة';
        prayerNameEn = payload['en'] ?? 'Prayer';
        cityName = payload['city'];
        backgroundImage = payload['image'];
      }
    } catch (_) {}
  }

  final prefs = await SharedPreferences.getInstance();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: HadithService.instance),
        ChangeNotifierProvider(create: (_) => QuranProvider()),
        ChangeNotifierProvider(create: (_) => BukhariProvider()),
        ChangeNotifierProvider(create: (_) => madinah.QuranProvider(prefs)),
        ChangeNotifierProvider(create: (_) => SettingsProvider(storageService)),
        ChangeNotifierProvider(create: (_) => LocationProvider(locationService, storageService)),
        ChangeNotifierProvider(create: (_) => PrayerTimesProvider(prayerService)),
        ChangeNotifierProvider(create: (_) => HijriCalendarProvider(hijriService)),
        ChangeNotifierProvider(create: (_) => QiblaProvider()),
        ChangeNotifierProvider(create: (_) => AudioPlayerProvider()),
        ChangeNotifierProvider(create: (_) => DownloadProvider()),
      ],
      child: MyApp(
        launchFromAthan: launchFromAthan,
        prayerNameAr: prayerNameAr,
        prayerNameEn: prayerNameEn,
        cityName: cityName,
        backgroundImage: backgroundImage,
      ),
    ),
  );

  void pushAthanOverlay(String nameAr, String nameEn, String? city, String? image) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    
    // Check if already on Athan screen
    bool isAlreadyOnAthan = false;
    nav.popUntil((route) {
      if (route.settings.name == '/athan_overlay') isAlreadyOnAthan = true;
      return true;
    });
    if (isAlreadyOnAthan) return;

    nav.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/athan_overlay'),
        fullscreenDialog: true,
        builder: (_) => AthanOverlayScreen(
          prayerNameAr: nameAr,
          prayerNameEn: nameEn,
          cityName: city,
          backgroundImage: image,
        ),
      ),
    );
  }

  // ── Listen for Athan event from Background Service Isolate
  fbs.FlutterBackgroundService().on('open_athan').listen((data) {
    if (data == null) return;
    final nameAr = data['prayer'] as String? ?? 'الصلاة';
    final nameEn = data['prayerEn'] as String? ?? 'Prayer';
    final city = data['city'] as String?;
    final image = data['image'] as String?;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      pushAthanOverlay(nameAr, nameEn, city, image);
    });
  });

  // 15. AUDIO RELIABILITY - Fallback trigger from background isolate
  fbs.FlutterBackgroundService().on('fallback_audio').listen((data) async {
    final asset = data?['asset'] as String?;
    if (asset != null) {
      developer.log('[Main] Background audio failed. Initializing fallback playback.', name: 'AthanReliability');
      await AthanAudioService().play(asset);
    }
  });

  fbs.FlutterBackgroundService().on('show_eid_screen').listen((data) {
    final eidName = data?['eid_name'] as String? ?? 'عيدكم مبارك';
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => EidCelebrationScreen(eidName: eidName),
      ),
    );
  });

  // Keep Native channel for stopAudio command but disable it for navigation
  const athanChannel = MethodChannel('imsakia/athan_control');
  athanChannel.setMethodCallHandler((call) async {
    if (call.method == 'stopAudio') {
      AthanAudioService().stop();
      final nav = navigatorKey.currentState;
      if (nav != null && nav.canPop()) {
        nav.pop();
      }
    } else if (call.method == 'open_athan') {
        // Handle native intent calls (from fullScreenIntent)
        final args = call.arguments as Map<dynamic, dynamic>?;
        if (args != null) {
            final nameAr = args['prayer'] as String? ?? 'الصلاة';
            final nameEn = args['prayerEn'] as String? ?? 'Prayer';
            final image = args['image'] as String?;
            final city = args['city'] as String?;
            
            pushAthanOverlay(nameAr, nameEn, city, image);
        }
    }
  });

  // 1. Request Notification Permission (Essential for Android 13+)
  await requestNotificationPermission();

  AppLifecycleListener(
    onResume: () async {
      final prefs = await SharedPreferences.getInstance();
      final isPlaying = prefs.getBool('athan_is_playing') ?? false;
      if (!isPlaying) return;
      final nameAr = prefs.getString('athan_prayer_ar') ?? 'الصلاة';
      final nameEn = prefs.getString('athan_prayer_en') ?? 'Prayer';
      final city = prefs.getString('athan_city');
      final image = prefs.getString('athan_image');
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        pushAthanOverlay(nameAr, nameEn, city, image);
      });
    },
  );
}

Future<void> requestNotificationPermission() async {
  final android = FlutterLocalNotificationsPlugin()
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await android?.requestNotificationsPermission();
}

class MyApp extends StatelessWidget {
  final bool launchFromAthan;
  final String prayerNameAr;
  final String prayerNameEn;
  final String? cityName;
  final String? backgroundImage;

  const MyApp({
    super.key,
    this.launchFromAthan = false,
    this.prayerNameAr = 'الصلاة',
    this.prayerNameEn = 'Prayer',
    this.cityName,
    this.backgroundImage,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Consumer<SettingsProvider>(
          builder: (context, settingsProvider, child) {
            themeProvider.syncWithSettingsProvider(
              settingsProvider.isDarkMode ? AppThemeMode.dark : AppThemeMode.light,
            );

            return MaterialApp(
              title: settingsProvider.languageCode == 'ar' ? 'زاد' : 'Zad',
              navigatorKey: navigatorKey,
              debugShowCheckedModeBanner: false,
              theme: themeProvider.lightTheme,
              darkTheme: themeProvider.darkTheme,
              themeMode: settingsProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
              initialRoute: launchFromAthan ? '/athan_overlay' : '/',
              routes: {
                '/': (context) => const SplashScreen(),
                '/athan_overlay': (context) => AthanOverlayScreen(
                      prayerNameAr: prayerNameAr,
                      prayerNameEn: prayerNameEn,
                      cityName: cityName,
                      backgroundImage: backgroundImage,
                    ),
                '/settings': (context) => const SettingsScreen(),
                '/main': (context) => const MainLayout(),
                '/miui_guidance': (context) => const MiuiGuidanceScreen(),
              },
            );
          },
        );
      },
    );
  }
}
