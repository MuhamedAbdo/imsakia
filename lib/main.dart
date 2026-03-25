import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;

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

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Native MethodChannel — same name as registered in MainActivity.kt.
const _athanControlChannel = MethodChannel('imsakia/athan_control');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Audio Service at the very beginning
  await initAudioService();

  // Initialize Arabic locale for date formatting
  await initializeDateFormatting('ar', null);

  // Time zones
  tz.initializeTimeZones();

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

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

  // ── Determine the initial route BEFORE runApp ──────────────────────────
  // Priority 1: notification tap (cold-start from tapping the athan notification)
  final initialNotification = await flutterLocalNotificationsPlugin
      .getNotificationAppLaunchDetails();
  final launchFromNotification =
      initialNotification?.didNotificationLaunchApp == true;

  String prayerNameAr = 'الصلاة';
  String prayerNameEn = 'Prayer';
  String? backgroundImage;

  if (launchFromNotification) {
    try {
      final payloadStr = initialNotification?.notificationResponse?.payload;
      if (payloadStr != null && payloadStr.isNotEmpty) {
        final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
        prayerNameAr = payload['ar'] as String? ?? 'الصلاة';
        prayerNameEn = payload['en'] as String? ?? 'Prayer';
        backgroundImage = payload['image'] as String?;
      }
    } catch (_) {}
  }

  // Priority 2: SharedPreferences flag (app woke up while Athan is playing,
  // e.g. from native launchAthanOverlay Intent or after a forced restart).
  final prefs = await SharedPreferences.getInstance();
  final athanIsPlaying = prefs.getBool('athan_is_playing') ?? false;

  if (!launchFromNotification && athanIsPlaying) {
    prayerNameAr = prefs.getString('athan_prayer_ar') ?? 'الصلاة';
    prayerNameEn = prefs.getString('athan_prayer_en') ?? 'Prayer';
    backgroundImage = prefs.getString('athan_prayer_image');
  }

  // Determine first route: go to Athan overlay if either signal fires.
  final bool showAthanFirst = launchFromNotification || athanIsPlaying;

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
        ChangeNotifierProvider(
          create: (_) => LocationProvider(locationService, storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => PrayerTimesProvider(prayerService),
        ),
        ChangeNotifierProvider(
          create: (_) => HijriCalendarProvider(hijriService),
        ),
        ChangeNotifierProvider(create: (_) => QiblaProvider()),
        ChangeNotifierProvider(create: (_) => AudioPlayerProvider()),
        ChangeNotifierProvider(
          create: (_) => DownloadProvider(),
        ),
      ],
      child: MyApp(
        showAthanFirst: showAthanFirst,
        prayerNameAr: prayerNameAr,
        prayerNameEn: prayerNameEn,
        backgroundImage: backgroundImage,
      ),
    ),
  );

  }

class MyApp extends StatefulWidget {
  final bool showAthanFirst;
  final String prayerNameAr;
  final String prayerNameEn;
  final String? backgroundImage;

  const MyApp({
    super.key,
    this.showAthanFirst = false,
    this.prayerNameAr = 'الصلاة',
    this.prayerNameEn = 'Prayer',
    this.backgroundImage,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Subscriptions – cancelled on dispose to avoid leaks.
  StreamSubscription<Map<String, dynamic>?>? _athanStartedSub;
  StreamSubscription<Map<String, dynamic>?>? _showEidSub;
  AppLifecycleListener? _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _registerAthanChannelHandler();
    _registerBackgroundServiceListeners();
    _registerLifecycleListener();
    // Poll for a pending cold-start intent that native sent before we were ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _pollPendingAthanIntent());
  }

  @override
  void dispose() {
    _athanStartedSub?.cancel();
    _showEidSub?.cancel();
    _lifecycleListener?.dispose();
    super.dispose();
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  void _pushAthanOverlay(String nameAr, String nameEn, String? image) {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/athan'),
        fullscreenDialog: true,
        builder: (_) => AthanOverlayScreen(
          prayerNameAr: nameAr,
          prayerNameEn: nameEn,
          backgroundImage: image,
        ),
      ),
      (route) => false,
    );
  }

  // ── MethodChannel: native open_athan → navigate to /athan ─────────────────
  void _registerAthanChannelHandler() {
    _athanControlChannel.setMethodCallHandler((call) async {
      if (call.method == 'open_athan') {
        final args = call.arguments as Map?;
        final nameAr = args?['prayer'] as String? ?? 'الصلاة';
        final nameEn = args?['prayerEn'] as String? ?? 'Prayer';
        final image = args?['image'] as String?;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pushAthanOverlay(nameAr, nameEn, image);
        });
      }
      // Legacy compatibility – handle old 'showAthanOverlay' method name too.
      if (call.method == 'showAthanOverlay') {
        final args = call.arguments as Map?;
        final nameAr = args?['prayer'] as String? ?? 'الصلاة';
        final nameEn = args?['prayerEn'] as String? ?? 'Prayer';
        final image = args?['image'] as String?;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pushAthanOverlay(nameAr, nameEn, image);
        });
      }
    });
  }

  // ── Cold-start poll: ask native for any buffered intent data ──────────────
  Future<void> _pollPendingAthanIntent() async {
    try {
      final result = await _athanControlChannel.invokeMethod<Map>('getPendingAthanIntent');
      if (result != null) {
        final nameAr = result['prayer'] as String? ?? 'الصلاة';
        final nameEn = result['prayerEn'] as String? ?? 'Prayer';
        final image = result['image'] as String?;
        _pushAthanOverlay(nameAr, nameEn, image);
      }
    } catch (_) {
      // Not critical – the postDelayed channel call is the primary path.
    }
  }

  // ── Background isolate events ──────────────────────────────────────────────
  void _registerBackgroundServiceListeners() {
    Map<String, dynamic>? pendingAthanData;

    _athanStartedSub = fbs.FlutterBackgroundService().on('athan_started').listen((data) {
      if (data == null) return;
      final nameAr = data['prayer'] as String? ?? 'الصلاة';
      final nameEn = data['prayerEn'] as String? ?? 'Prayer';
      final image = data['image'] as String?;

      if (navigatorKey.currentState != null) {
        _pushAthanOverlay(nameAr, nameEn, image);
      } else {
        pendingAthanData = {'nameAr': nameAr, 'nameEn': nameEn, 'image': image};
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (pendingAthanData != null) {
            _pushAthanOverlay(
              pendingAthanData!['nameAr'] as String,
              pendingAthanData!['nameEn'] as String,
              pendingAthanData!['image'] as String?,
            );
            pendingAthanData = null;
          }
        });
      }
    });

    _showEidSub = fbs.FlutterBackgroundService().on('show_eid_screen').listen((data) {
      final eidName = data?['eid_name'] as String? ?? 'عيدكم مبارك';
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => EidCelebrationScreen(eidName: eidName),
        ),
      );
    });
  }

  // ── AppLifecycle: resume → check athan_is_playing flag ───────────────────
  void _registerLifecycleListener() {
    _lifecycleListener = AppLifecycleListener(
      onResume: () async {
        try {
          final prefs = await SharedPreferences.getInstance();
          final isPlaying = prefs.getBool('athan_is_playing') ?? false;
          if (!isPlaying) return;
          final nameAr = prefs.getString('athan_prayer_ar') ?? 'الصلاة';
          final nameEn = prefs.getString('athan_prayer_en') ?? 'Prayer';
          final image = prefs.getString('athan_prayer_image');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final ctx = navigatorKey.currentContext;
            if (ctx == null) return;
            final currentName = ModalRoute.of(ctx)?.settings.name;
            if (currentName == '/athan') return;
            _pushAthanOverlay(nameAr, nameEn, image);
          });
        } catch (_) {}
      },
    );
  }

  // ── build: the MaterialApp tree ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Consumer<SettingsProvider>(
          builder: (context, settingsProvider, child) {
            themeProvider.syncWithSettingsProvider(
              settingsProvider.isDarkMode
                  ? AppThemeMode.dark
                  : AppThemeMode.light,
            );

            return MaterialApp(
              title: settingsProvider.languageCode == 'ar' ? 'زاد' : 'Zad',
              navigatorKey: navigatorKey,
              debugShowCheckedModeBanner: false,
              theme: themeProvider.lightTheme,
              darkTheme: themeProvider.darkTheme,
              themeMode: settingsProvider.isDarkMode
                  ? ThemeMode.dark
                  : ThemeMode.light,
              // showAthanFirst covers BOTH the notification-tap and the
              // SharedPreferences athan_is_playing flag checked before runApp.
              initialRoute: widget.showAthanFirst ? '/athan' : '/',
              routes: {
                '/': (context) => const SplashScreen(),
                '/athan': (context) => AthanOverlayScreen(
                      prayerNameAr: widget.prayerNameAr,
                      prayerNameEn: widget.prayerNameEn,
                      backgroundImage: widget.backgroundImage,
                    ),
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
