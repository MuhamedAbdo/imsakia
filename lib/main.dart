import 'dart:ui';
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
import 'features/athan/providers/athan_provider.dart';
import 'features/athan/services/athan_manager.dart';
import 'features/athan/ui/athan_overlay_screen.dart';
import 'utils/app_constants.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/prayer_times_service.dart';
import 'services/home_events_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background notification response handler (fires when app is killed)
// Must be a top-level function annotated with @pragma
@pragma('vm:entry-point')
void notificationBackgroundResponseHandler(NotificationResponse response) async {
  if (response.payload == 'stop_athan' ||
      (response.actionId != null && response.actionId == 'stop_athan_action')) {
    // Initialize isolate plugin channels
    DartPluginRegistrant.ensureInitialized();
    // Stop athan audio by calling the audio handler if alive
    if (audioHandler == null) {
      await initAudioService();
    }
    await audioHandler?.customAction('stopAthan');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Copy Athan assets to local storage for background isolate access
  await _prepareAthanAssets();

  // Initialize Arabic locale for date formatting
  await initializeDateFormatting('ar', null);

  // Критично: audio service and alarm manager MUST be initialized before the
  // notification plugin, so audioHandler is not null when the athan overlay opens.
  await initAudioService();
  await AthanManager.initialize();

  // Start non-critical services without blocking
  HadithService.instance.initialize();
  AzkarService.instance.initialize();

  final settingsProvider = SettingsProvider();
  await settingsProvider.initialize();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // Initialize the notification plugin with foreground AND background handlers
  await flutterLocalNotificationsPlugin.initialize(
    settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // Foreground tap: navigate to overlay if it's the Athan notification (ID 888)
      if (response.id == 888 || (response.payload != null && response.payload!.startsWith('athan_overlay|'))) {
        String prayerName = "الصلاة";
        bool isFajr = false;
        
        if (response.payload != null && response.payload!.contains('|')) {
          final parts = response.payload!.split('|');
          if (parts.length >= 3) {
            prayerName = parts[1];
            isFajr = parts[2] == 'true';
          }
        }
        
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => AthanOverlayScreen(prayerName: prayerName, isFajr: isFajr)),
        );
      }
      // Foreground action button tap: stop athan
      if (response.actionId == 'stop_athan_action') {
        audioHandler?.customAction('stopAthan');
      }
    },
    onDidReceiveBackgroundNotificationResponse: notificationBackgroundResponseHandler,
  );

  final NotificationAppLaunchDetails? notificationAppLaunchDetails = await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  
  Widget? overlayScreen;
  
  // 1. تحقق من الأذان المعلق في Native SharedPreferences (Guaranteed Delivery)
  final pendingPrayer = await AthanManager.getPendingAthan();
  if (pendingPrayer != null && pendingPrayer.isNotEmpty) {
    overlayScreen = AthanOverlayScreen(prayerName: pendingPrayer, isColdStart: true);
    // ✅ نظّف فوراً بعد الاستهلاك
    await AthanManager.clearPendingAthan();
  } else if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
    // 2. تحقق من Notification Launch (Fallback)
    final payload = notificationAppLaunchDetails?.notificationResponse?.payload;
    if (payload != null && payload.startsWith('athan_overlay|')) {
      final parts = payload.split('|');
      if (parts.length >= 2) {
        overlayScreen = AthanOverlayScreen(prayerName: parts[1], isColdStart: true);
      }
    }
  }

  final prefs = await SharedPreferences.getInstance();
  runApp(MyApp(settingsProvider: settingsProvider, prefs: prefs, initialOverlay: overlayScreen));
}

class MyApp extends StatefulWidget {
  final SettingsProvider settingsProvider;
  final SharedPreferences prefs;
  final Widget? initialOverlay;

  static bool isAthanShowing = false;
  MyApp({super.key, required this.settingsProvider, required this.prefs, this.initialOverlay}) {
    if (initialOverlay != null) {
      isAthanShowing = true;
    }
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const platform = MethodChannel('imsakia/notifications');
  String? _currentAthanOverlay;
  bool _isColdStartForAthan = false;

  @override
  void initState() {
    super.initState();
    _isColdStartForAthan = widget.initialOverlay != null;
    _setupMethodChannel();
    // ✅ نظام الخروج الآمن: مسح أي علم سابق عند فتح التطبيق لضمان العمل الطبيعي
    AthanManager.clearShouldExitFlag();
    // 🔥 جدولة المنبهات عند فتح التطبيق لأول مرة
    Future.delayed(const Duration(seconds: 2), () {
      PrayerTimesService.instance.scheduleAllPrayers();
    });
  }

  void _setupMethodChannel() {
    platform.setMethodCallHandler((call) async {
      
      if (call.method == "showAthanOverlay") {
        final prayerName = call.arguments['prayerName'] ?? "الصلاة";
        
        // 1. Passive check: Are we already showing this exact Athan?
        if (_currentAthanOverlay == prayerName) {
           return;
        }

        // 🔥 إضافة تأخير طفيف لضمان استقرار الـ Activity فوق القفل قبل فتح الشاشة
        Future.delayed(const Duration(milliseconds: 500), () async {
          if (navigatorKey.currentState != null) {
            // 2. Set state before pushing
            setState(() {
              _currentAthanOverlay = prayerName;
              MyApp.isAthanShowing = true;
            });

            // 3. Push on top of current stack WITHOUT clearing it
            await navigatorKey.currentState!.push(
              MaterialPageRoute(
                settings: RouteSettings(
                  name: 'athan_overlay',
                  arguments: {'prayerName': prayerName},
                ),
                builder: (context) => AthanOverlayScreen(prayerName: prayerName),
              ),
            );

            // 4. Reset state after pop (manual or auto)
            setState(() {
              _currentAthanOverlay = null;
              MyApp.isAthanShowing = false;
            });
          }
        });
      } else if (call.method == "dismissAthanOverlay") {
        // 1. تأخير بسيط جداً (500ms) للسماح بتنسيق العمليات
        await Future.delayed(const Duration(milliseconds: 500));
        
        // 2. Pop the overlay if it exists
        if (navigatorKey.currentState != null) {
          bool wasOnOverlay = false;
          navigatorKey.currentState!.popUntil((route) {
            if (route.settings.name == 'athan_overlay') {
              wasOnOverlay = true;
              return false; // This pops the overlay
            }
            return true; // Stop here (the route below overlay)
          });
          
          if (wasOnOverlay) {
            // 3. Reset state
            setState(() {
              _currentAthanOverlay = null;
            });
            
            // ✅ تنظيف العلم عند الإغلاق الناجح
            AthanManager.clearShouldExitFlag();

            // 4. Trigger native smart exit OR SELF-DESTRUCT for cold start
            if (_isColdStartForAthan) {
              await AthanManager.forceExit();
            } else {
              await AthanManager.performSmartExit();
            }
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.settingsProvider),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: HadithService.instance),
        ChangeNotifierProvider(create: (_) => QuranProvider()),
        ChangeNotifierProvider(create: (_) => HomeEventsService()),
        ChangeNotifierProvider(
          create: (_) => BukhariProvider(),
        ),
        ChangeNotifierProvider(create: (_) => madinah.QuranProvider(widget.prefs)),
        ChangeNotifierProvider(create: (_) => AudioPlayerProvider()),
        ChangeNotifierProvider(create: (_) => DownloadProvider()),
        ChangeNotifierProvider<AthanProvider>(create: (_) => AthanProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return Consumer<SettingsProvider>(
            builder: (context, settingsProvider, child) {
              themeProvider.syncWithSettingsProvider(
                settingsProvider.themeMode,
              );

              return MaterialApp(
                title: AppConstants.appName,
                navigatorKey: navigatorKey,
                debugShowCheckedModeBanner: false,
                theme: themeProvider.lightTheme,
                darkTheme: themeProvider.darkTheme,
                themeMode: _getThemeMode(settingsProvider.themeMode),
                home: widget.initialOverlay ?? const SplashScreen(),
                routes: {
                  '/settings': (context) => const SettingsScreen(),
                  '/main': (context) => const MainLayout(),
                },
                builder: (context, child) {
                  // 🔥 تحميل الصور مسبقاً في الذاكرة لضمان ظهور شاشة الأذان في جزء من الثانية (Pre-cache)
                  _precacheAthanImages(context);
                  
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

  bool _imagesPrecached = false;
  void _precacheAthanImages(BuildContext context) {
    if (_imagesPrecached) return;
    _imagesPrecached = true;
    
    final assets = [
      'assets/images/fajr_dawn.png',
      'assets/images/dhuhr_noon.png',
      'assets/images/asr_afternoon.png',
      'assets/images/maghrib_sunset.png',
      'assets/images/isha_night.png',
    ];
    
    for (final val in assets) {
      precacheImage(AssetImage(val), context).catchError((_) {
      });
    }
  }
}

/// Copies the Athan audio file from assets to local storage.
/// This ensures background isolates can access the file even when the app is killed.
Future<void> _prepareAthanAssets() async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/athan_makkah.mp3';
    final file = File(path);

    if (!await file.exists()) {
      final byteData = await rootBundle.load('assets/audio/athan_makkah.mp3');
      await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }
  } catch (_) {
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
