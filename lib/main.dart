import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/quran_provider.dart';
import 'providers/quran_audio_provider.dart';
import 'providers/bukhari_provider.dart'; // تأكد من وجود هذا الاستيراد
import 'screens/splash_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/azkar_detail_screen.dart';
import 'screens/main_layout.dart';
import 'screens/sequential_permissions_screen.dart';
import 'services/hadith_service.dart';
import 'services/azkar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imsakia/features/quran_madinah/providers/quran_provider.dart'
    as madinah;
import 'features/audio/providers/audio_player_provider.dart';
import 'features/audio/providers/download_provider.dart';
import 'features/audio/services/audio_handler.dart';
import 'features/athan/providers/athan_provider.dart';
import 'features/athan_library/providers/athan_library_provider.dart';
import 'features/athan/services/athan_manager.dart';
import 'features/athan/ui/athan_overlay_screen.dart';
import 'utils/app_constants.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/prayer_times_service.dart';
import 'services/home_events_service.dart';
import 'services/bookmark_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
String? pendingAzkarRoutePayload; // المتغير العام لحفظ الحمولة (Payload)

void handleNotificationPayload(String payload) {
  if (payload.startsWith('azkar_')) {
    final categoryId = payload == 'azkar_morning' ? 'morning' : 'evening';
    final category = AzkarService.instance.categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => AzkarService.instance.categories.first,
    );
    
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => AzkarDetailScreen(category: category),
      ),
    );
  } else {
    // 🔔 For occasion/fasting reminders, opening the app is currently sufficient.
    // If needed, we can show a dialog or navigate to the calendar screen here.
    debugPrint('handleNotificationPayload: Handled occasion payload = $payload');
  }
}


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

  // 🛡️ SOVEREIGN PROTOCOL: Emergency Athan Mode Check
  const channel = MethodChannel('imsakia/notifications');
  bool isEmergencyAthan = false;
  try {
    isEmergencyAthan = await channel.invokeMethod<bool>('isEmergencyAthanMode') ?? false;
  } on MissingPluginException {
    // الـ method مش موجودة على الجانب الـ native — نتعامل كحالة طبيعية
    isEmergencyAthan = false;
  } catch (_) {
    isEmergencyAthan = false;
  }

  if (isEmergencyAthan) {
    // We keep this true for now, but will override it below if overlayScreen == null
    MyApp.isAthanShowing = true;
    debugPrint("!!! SOVEREIGN: Emergency Athan Mode Detected - Freezing Widget Sync !!!");
  }

  // 🔔 Cold Start: التحقق من فتح التطبيق بالنقر على إشعار أذكار/مناسبة
  try {
    final notificationPayload =
        await channel.invokeMethod<String?>('getInitialNotificationPayload');
    if (notificationPayload != null && notificationPayload.isNotEmpty) {
      if (notificationPayload.startsWith('azkar_') ||
          notificationPayload.startsWith('islamic_occasion') ||
          notificationPayload.startsWith('fasting_reminder') ||
          notificationPayload.startsWith('custom_occasion')) {
        pendingAzkarRoutePayload = notificationPayload;
        debugPrint('main: notification payload captured on cold start: $notificationPayload');
      }
    }
  } on MissingPluginException {
    // الـ method غير موجودة بعد — لا بأس
  } catch (e) {
    debugPrint('main: getInitialNotificationPayload error: $e');
  }

  // Copy Athan assets to local storage for background isolate access
  await _prepareAthanAssets();

  // Initialize Arabic locale for date formatting
  await initializeDateFormatting('ar', null);

  // Критично: audio service and alarm manager MUST be initialized before the
  // notification plugin, so audioHandler is not null when the athan overlay opens.
  await initAudioService();
  await AthanManager.initialize();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // Initialize the notification plugin with foreground AND background handlers
  await flutterLocalNotificationsPlugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
      linux: LinuxInitializationSettings(defaultActionName: 'Open notification'),
      windows: WindowsInitializationSettings(
        appName: 'Imsakia',
        appUserModelId: 'com.muhamed.imsakia',
        guid: 'd185bb81-1bf3-4660-84a1-0e3196edc9c6'
      ),
    ),
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      final payload = response.payload;
      if (payload != null && payload.startsWith('athan_overlay|')) {
        final parts = payload.split('|');
        final prayerName = parts.length >= 2 ? parts[1] : 'الصلاة';
        final isFajr = prayerName == 'الفجر';
        
        if (MyApp.isAthanShowing) {
          debugPrint("Athan already showing, ignoring notification tap");
          return;
        }
        
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => AthanOverlayScreen(prayerName: prayerName, isFajr: isFajr)),
        );
      } else if (payload == 'azkar_morning' || payload == 'azkar_evening') {
        if (MyApp.sessionSplashShown && navigatorKey.currentState != null) {
          // التوجيه المباشر إذا كان التطبيق مفتوحاً ومتجاوزاً الـ Splash Screen
          handleNotificationPayload(payload!);
        } else {
          // التخزين في حال كان التطبيق في مرحلة الإقلاع أو הـ Splash
          pendingAzkarRoutePayload = payload;
        }
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
    if (payload != null) {
      if (payload.startsWith('athan_overlay|')) {
        final parts = payload.split('|');
        if (parts.length >= 2) {
          overlayScreen = AthanOverlayScreen(prayerName: parts[1], isColdStart: true);
        }
      } else if (payload == 'azkar_morning' || payload == 'azkar_evening') {
        // 3. التقاط حمولة الأذكار وتخزينها للمرحلة التي تلي SplashScreen
        pendingAzkarRoutePayload = payload;
      }
    }
  }

  if (overlayScreen != null) {
    // 🚀 وضع الطوارئ: لا ننتظر الأذكار أو الأحاديث نهائياً
    debugPrint("!!! HARDENED: Athan Mode - Skipping ALL non-essential background tasks !!!");
    MyApp.isAthanShowing = true;
  } else {
    // 💡 صمام الأمان (Cold Start Reset): تفريغ الحالة تماماً إذا لم يكن الإقلاع لأجل الأذان
    if (MyApp.isAthanShowing) {
      debugPrint("!!! SAFEGUARD: False Athan flag detected on normal launch. Forcing reset. !!!");
      MyApp.isAthanShowing = false;
    }
    
    // الحالة الطبيعية
    HadithService.instance.initialize();
    AzkarService.instance.initialize();
  }

  final settingsProvider = SettingsProvider();
  await settingsProvider.initialize();

  // 🔄 Migration خفية: نقل الـ Bookmarks القديمة من مسارات JSON إلى bookKey الجديد
  await BookmarkService.migrateIfNeeded();

  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();

  // 🔥 ONE-TIME CLEANUP: Clear orphaned alarms from other branches/versions
  // This ensures the Sovereign Athan system starts with a clean slate.
  final hasCleanedOrphans = prefs.getBool('orphaned_alarms_cleaned_v1') ?? false;
  if (!hasCleanedOrphans) {
    debugPrint("!!! HARDENED: Performing one-time orphaned alarm cleanup !!!");
    await AthanManager.cancelAllAlarms();
    await prefs.setBool('orphaned_alarms_cleaned_v1', true);
  }

  final hasCompletedSetup = prefs.getBool('setup_completed') ?? false;
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(MyApp(
    settingsProvider: settingsProvider, 
    prefs: prefs, 
    initialOverlay: overlayScreen,
    showPermissionsGate: !hasCompletedSetup,
  ));
}

class MyApp extends StatefulWidget {
  final SettingsProvider settingsProvider;
  final SharedPreferences prefs;
  final Widget? initialOverlay;
  final bool showPermissionsGate;

  static bool isAthanShowing = false;
  static bool sessionSplashShown = false;
  MyApp({super.key, required this.settingsProvider, required this.prefs, this.initialOverlay, this.showPermissionsGate = false}) {
    if (initialOverlay != null) {
      isAthanShowing = true;
    }
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
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
    // 🔄 Self-Healing: سجّل Observer لمراقبة دورة حياة التطبيق (Resume)
    WidgetsBinding.instance.addObserver(this);
    // 🔥 جدولة المنبهات وتحديث الويدجت عند فتح التطبيق
    // 🛡️ HARDENED: Skip this if we're showing an overlay to avoid heavy initialization & Geocoding issues
    if (widget.initialOverlay == null) {
      // Future.microtask(() => _rescheduleAndSync()); // Temporarily disabled for Single Variable Testing
    } else {
      debugPrint("!!! HARDENED: Athan Overlay detected, skipping heavy background scheduling !!!");
    }
  }

  /// 🔄 Self-Healing: يُعيد جدولة جميع صلوات اليوم ويُحدّث الويدجت.
  /// يُستدعى عند كل فتح للتطبيق (Launch) أو عودة إليه (Resume).
  /// هذا يضمن التعافي الفوري في حال مُسحت المنبهات من AlarmManager
  /// بسبب Force Stop أو ADB Debugging أو أي سبب قسري آخر.
  Future<void> _rescheduleAndSync() async {
    debugPrint("!!! SELF-HEALING: Rescheduling all prayers on app launch/resume !!!");
    // مسح علم needs_sync لأننا نُعيد الجدولة بشكل كامل الآن
    await widget.prefs.setBool('needs_sync', false);
    await PrayerTimesService.instance.scheduleAllPrayers();
    // 🔥 تزامن الدخول: نحدث الويدجت فوراً وبشكل صارم
    await PrayerTimesService.instance.updateWidgetData(force: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 🔄 Self-Healing: عند رجوع المستخدم للتطبيق بعد تشغيله في الخلفية
    // نُعيد جدولة المنبهات تلقائياً لضمان التعافي من أي مسح قسري
    if (state == AppLifecycleState.resumed && widget.initialOverlay == null) {
      debugPrint("!!! SELF-HEALING: App resumed — rescheduling prayers to recover from any alarm wipe !!!");
      // PrayerTimesService.instance.scheduleAllPrayers(); // Temporarily disabled for Single Variable Testing
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setupMethodChannel() {
    platform.setMethodCallHandler((call) async {
      
      if (call.method == "showAthanOverlay") {
        final prayerName = call.arguments['prayerName'] ?? "الصلاة";
        
        // 1. Passive check: Are we already showing this exact Athan?
        if (_currentAthanOverlay == prayerName || MyApp.isAthanShowing) {
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
        
        // ✅ تنظيف العلم عند الإغلاق الناجح
        AthanManager.clearShouldExitFlag();

        if (_isColdStartForAthan) {
          // خروج طوارئ فوري: إنهاء التطبيق تماماً لأنه فُتح للأذان فقط
          setState(() {
            _currentAthanOverlay = null;
          });
          await AthanManager.forceExit();
          SystemNavigator.pop();
          return;
        }

        // الحالة الطبيعية (Warm Start): الـ Overlay تم وضعه فوق شاشات أخرى
        if (navigatorKey.currentState != null) {
          bool wasOnOverlay = false;
          navigatorKey.currentState!.popUntil((route) {
            if (route.settings.name == 'athan_overlay') {
              wasOnOverlay = true;
              return false; // This pops the overlay
            }
            return true; // Stop popping at the route below
          });
          
          if (wasOnOverlay) {
            setState(() {
              _currentAthanOverlay = null;
            });
            await AthanManager.performSmartExit();
          }
        }
      } else if (call.method == "notificationPayloadReceived") {
        // 🔔 Warm Start: المستخدم نقر على إشعار أذكار/مناسبة والتطبيق مفتوح
        final payload = call.arguments as String?;
        if (payload != null && payload.isNotEmpty) {
          debugPrint('_setupMethodChannel: notificationPayloadReceived = $payload');
          if (MyApp.sessionSplashShown && navigatorKey.currentState != null) {
            // التوجيه المباشر إذا كان التطبيق تجاوز شاشة الإقلاع
            handleNotificationPayload(payload);
          } else {
            // التخزين للمرحلة التي تلي الـ SplashScreen
            pendingAzkarRoutePayload = payload;
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
        ChangeNotifierProvider(create: (_) => QuranAudioProvider()),
        ChangeNotifierProvider(create: (_) => HomeEventsService()),
        ChangeNotifierProvider(
          create: (_) => BukhariProvider(),
        ),
        ChangeNotifierProvider(create: (_) => madinah.QuranProvider(widget.prefs)),
        ChangeNotifierProvider(create: (_) => AudioPlayerProvider()),
        ChangeNotifierProvider(create: (_) => DownloadProvider()),
        ChangeNotifierProvider<AthanProvider>(create: (_) => AthanProvider()),
        ChangeNotifierProvider(create: (_) => AthanLibraryProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return Consumer<SettingsProvider>(
            builder: (context, settingsProvider, child) {
              themeProvider.syncWithSettingsProvider(
                settingsProvider.themeMode,
              );

              ThemeData lightTheme = themeProvider.lightTheme;
              ThemeData darkTheme = themeProvider.darkTheme;

              if (widget.initialOverlay != null) {
                const noAnimTheme = PageTransitionsTheme(
                  builders: {
                    TargetPlatform.android: NoAnimationPageTransitionsBuilder(),
                    TargetPlatform.iOS: NoAnimationPageTransitionsBuilder(),
                  },
                );
                lightTheme = lightTheme.copyWith(pageTransitionsTheme: noAnimTheme);
                darkTheme = darkTheme.copyWith(pageTransitionsTheme: noAnimTheme);
              }

              return MaterialApp(
                title: AppConstants.appName,
                navigatorKey: navigatorKey,
                debugShowCheckedModeBanner: false,
                theme: lightTheme,
                darkTheme: darkTheme,
                themeMode: _getThemeMode(settingsProvider.themeMode),
                home: _resolveInitialScreen(),
                routes: {
                  '/settings': (context) => const SettingsScreen(),
                  '/main': (context) => const MainLayout(),
                  '/sequential-permissions': (context) => const SequentialPermissionsScreen(),
                  '/city-selection': (context) => const SettingsScreen(isFirstTimeSetup: true),
                },
                builder: (context, child) {
                  // 🔥 تحميل الصور مسبقاً في الذاكرة لضمان ظهور شاشة الأذان في جزء من الثانية (Pre-cache)
                  _precacheAthanImages(context);
                  
                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
                    child: child!,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _resolveInitialScreen() {
    // 1️⃣ الأولوية القصوى والمباشرة: الأذان
    if (widget.initialOverlay != null) {
      MyApp.isAthanShowing = true;
      return widget.initialOverlay!;
    }

    // 2️⃣ إكمال الإعدادات لأول مرة
    if (widget.showPermissionsGate) {
      return const SequentialPermissionsScreen();
    }

    // 3️⃣ 🛡️ حماية الجلسة: لو التطبيق لسا شغال (نفس الـ process)
    // ومش أول مرة يُبنى فيها هذا الـ widget، نتجه مباشرةً للواجهة الرئيسية
    // هذا يمنع الـ Splash من الظهور عند: قفل الشاشة، مقاطعة اتصال،
    // أو أي إعادة إنشاء للـ Activity بدون إغلاق العملية فعلاً.
    if (MyApp.sessionSplashShown) {
      return const MainLayout();
    }

    // 4️⃣ أول مرة حقيقية في هذه الجلسة → نفتح الـ Splash
    return const SplashScreen();
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

class NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoAnimationPageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
