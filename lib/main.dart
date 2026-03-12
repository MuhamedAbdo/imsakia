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
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
      // Foreground tap: navigate to overlay
      if (response.payload != null && response.payload!.startsWith('athan_overlay|')) {
        final parts = response.payload!.split('|');
        if (parts.length >= 3) {
          final prayerName = parts[1];
          final isFajr = parts[2] == 'true';
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => AthanOverlayScreen(prayerName: prayerName, isFajr: isFajr)),
          );
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
  
  if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
    final payload = notificationAppLaunchDetails?.notificationResponse?.payload;
    if (payload != null && payload.startsWith('athan_overlay|')) {
      final parts = payload.split('|');
      if (parts.length >= 3) {
        final prayerName = parts[1];
        final isFajr = parts[2] == 'true';
        overlayScreen = AthanOverlayScreen(prayerName: prayerName, isFajr: isFajr);
      }
    }
  }

  final prefs = await SharedPreferences.getInstance();
  runApp(MyApp(settingsProvider: settingsProvider, prefs: prefs, initialOverlay: overlayScreen));
}

class MyApp extends StatelessWidget {
  final SettingsProvider settingsProvider;
  final SharedPreferences prefs;
  final Widget? initialOverlay;

  const MyApp({super.key, required this.settingsProvider, required this.prefs, this.initialOverlay});

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
        ChangeNotifierProvider<AthanProvider>(create: (_) {
           final provider = AthanProvider();
           provider.fetchMuezzins(); // Pre-fetch UI options
           return provider;
        }),
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
                navigatorKey: navigatorKey,
                debugShowCheckedModeBanner: false,
                theme: themeProvider.lightTheme,
                darkTheme: themeProvider.darkTheme,
                themeMode: _getThemeMode(settingsProvider.themeMode),
                home: initialOverlay ?? const SplashScreen(),
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
