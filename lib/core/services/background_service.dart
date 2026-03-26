import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'dart:convert';
import '../models/prayer_times_model.dart';
import '../models/location_model.dart';
import '../models/settings_model.dart';
import '../models/islamic_event_model.dart';
import 'prayer_times_service.dart';
import 'athan_audio_service.dart';
import 'location_service.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:home_widget/home_widget.dart';

/// MethodChannel to communicate with native MainActivity / AthanReceiver.
const _athanControlChannel = MethodChannel('imsakia/athan_control');

class BackgroundService {
  static const _foregroundNotificationId = 9001;
  static const _channelId = 'adhan_background';
  static const _channelName = 'Adhan Running';
  static const _eventsChannelId = 'islamic_events';
  static const _eventsChannelName = 'المناسبات الإسلامية';
  static const _athanChannelId = 'adhan_athan';

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // ── Notification channels (Created in Main Isolate for reliability)
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        importance: Importance.low,
      ),
    );

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _athanChannelId,
        'Athan Alarm',
        importance: Importance.max,
        description: 'Athan alarm at prayer times',
        enableVibration: true,
        playSound: false,
      ),
    );

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _eventsChannelId,
        _eventsChannelName,
        description: 'يُعلمك بالمناسبات الإسلامية المهمة يومياً',
        importance: Importance.high,
      ),
    );

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: 'أوقات الصلاة',
        initialNotificationContent: 'جاري الحساب...',
        foregroundServiceNotificationId: _foregroundNotificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _iosBackground,
      ),
    );
  }

  static Future<void> start() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }
  }

  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stop');
  }

  /// Sends the unified stop_audio command to the background isolate.
  /// Also invokes the native MethodChannel so AthanReceiver's engine-cache
  /// path can kill audio if the Dart stream handler is not yet listening.
  static void sendStopAudio() {
    developer.log(
      '[BackgroundService] Sending stop_audio command.',
      name: 'BackgroundService',
    );
    FlutterBackgroundService().invoke('stop_audio');
    // Belt-and-suspenders: also signal via native channel from main isolate.
    try {
      _athanControlChannel.invokeMethod('stopAudio');
    } catch (_) {}
  }

  /// Kept for backward-compat — delegates to sendStopAudio.
  @Deprecated('Use sendStopAudio() instead')
  static void sendStopAthan() => sendStopAudio();
}

// ---------------------------------------------------------------------------
// iOS background handler
// ---------------------------------------------------------------------------
@pragma('vm:entry-point')
Future<bool> _iosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

// ---------------------------------------------------------------------------
// Background isolate entry point
// ---------------------------------------------------------------------------
@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // Singleton audio player owned exclusively by this isolate
  final athanAudio = AthanAudioService();

  developer.log(
    '[BackgroundService] Isolate started (adhan precision loop).',
    name: 'BackgroundService',
  );

  // Task 4: Handle SharedPreferences as an async dependency properly
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  // Task 1: Immediate Priority - calculate using cached location on service start
  await _immediateCalculationWithFallback(service, prefs);

  // ── Notification plugin – handles action buttons
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@drawable/ic_notification');

  await flutterLocalNotificationsPlugin.initialize(
    settings: InitializationSettings(android: initializationSettingsAndroid),
    onDidReceiveNotificationResponse: (NotificationResponse details) async {
      developer.log(
        '[BackgroundService] Notification action received: ${details.actionId}',
        name: 'BackgroundService',
      );
      if (details.actionId == 'stop_audio') {
        developer.log(
          '[BackgroundService] Notification stop_audio action → stopping audio.',
          name: 'BackgroundService',
        );
        await athanAudio.stop();
        if (details.id != null) {
          developer.log(
            '[BackgroundService] Auto-dismissing notification ${details.id}.',
            name: 'BackgroundService',
          );
          await flutterLocalNotificationsPlugin.cancel(id: details.id!);
        }
      }
    },
  );

  // ── Foreground / background mode control
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  // ── Stop service command
  service.on('stop').listen((event) {
    developer.log(
      '[BackgroundService] Received stop — shutting down service.',
      name: 'BackgroundService',
    );
    service.stopSelf();
  });

  // ── Unified stop_audio command (from overlay Stop button OR notification action)
  service.on('stop_audio').listen((event) async {
    developer.log(
      '[BackgroundService] Received stop_audio command — stopping audio and clearing all notifications.',
      name: 'BackgroundService',
    );
    await athanAudio.stop();
    await flutterLocalNotificationsPlugin.cancelAll();
    // Clear the playing flag so the UI knows audio has ended.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('athan_is_playing', false);
      await prefs.setString('athan_prayer_ar', '');
      await prefs.setString('athan_prayer_en', '');
    } catch (_) {}
  });

  // ── MethodChannel: native AthanReceiver → stop audio in this isolate ─────
  // This fires when AthanReceiver.kt successfully invokes 'stopAudio' on the
  // cached FlutterEngine, bridging the native BroadcastReceiver to Dart.
  _athanControlChannel.setMethodCallHandler((call) async {
    if (call.method == 'stopAudio') {
      developer.log(
        '[BackgroundService] Native stopAudio received via MethodChannel — stopping audio.',
        name: 'BackgroundService',
      );
      await athanAudio.stop();
      await flutterLocalNotificationsPlugin.cancelAll();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('athan_is_playing', false);
        await prefs.setString('athan_prayer_ar', '');
        await prefs.setString('athan_prayer_en', '');
      } catch (_) {}
    }
  });

  // ── Manual reschedule trigger
  service.on('schedule').listen((event) async {
    developer.log(
      '[BackgroundService] Received schedule command — refreshing prayer times.',
      name: 'BackgroundService',
    );
    await _scheduleNextAthan(
      service,
      athanAudio,
      flutterLocalNotificationsPlugin,
    );
  });

  // ── Initial prayer-time check (Redundant now due to _immediateCalculationWithFallback, but keeping for compatibility)
  await _checkAndTriggerAthan(
    service,
    athanAudio,
    flutterLocalNotificationsPlugin,
    prefs: prefs,
  ).timeout(
    const Duration(seconds: 10),
    onTimeout: () {
      developer.log(
        '[BackgroundService] Initial _checkAndTriggerAthan timed out — will retry on next tick.',
        name: 'BackgroundService',
      );
    },
  );

  Timer.periodic(const Duration(minutes: 1), (timer) async {
    await _checkAndTriggerAthan(
      service,
      athanAudio,
      flutterLocalNotificationsPlugin,
      prefs: prefs,
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        developer.log(
          '[BackgroundService] _checkAndTriggerAthan timed out on minute tick.',
          name: 'BackgroundService',
        );
      },
    );

    // Integrated imsakia extra features
    await _checkIslamicEvents(flutterLocalNotificationsPlugin);
    await _checkEidTakbeer(
      service,
      athanAudio,
      flutterLocalNotificationsPlugin,
      prefs: prefs,
    );
  });
}

// ---------------------------------------------------------------------------
// Per-day debounce keys
// ---------------------------------------------------------------------------
String _lastTriggeredAthanKey = '';
String _lastEventNotifiedDate = '';
String _lastEidTakbeerDate = '';

// ---------------------------------------------------------------------------
// _scheduleNextAthan – called once on startup and via 'schedule' command
// ---------------------------------------------------------------------------
Future<void> _scheduleNextAthan(
  ServiceInstance service,
  AthanAudioService athanAudio,
  FlutterLocalNotificationsPlugin notifications, {
  SharedPreferences? prefs,
}) async {
  developer.log(
    '[BackgroundService] _scheduleNextAthan: performing initial check.',
    name: 'BackgroundService',
  );
  await _checkAndTriggerAthan(
    service,
    athanAudio,
    notifications,
    prefs: prefs,
  );
}

// ---------------------------------------------------------------------------
// Task 1: Robust Fallback Implementation
// ---------------------------------------------------------------------------
Future<void> _immediateCalculationWithFallback(
  ServiceInstance service,
  SharedPreferences prefs,
) async {
  developer.log('[BackgroundService] Starting immediate fallback check.', name: 'BackgroundService');
  
  // 1. Immediate Prayer Times from Cached Location
  final locationRaw = prefs.getString('last_location');
  if (locationRaw != null) {
    try {
      final location = LocationModel.fromJson(
        jsonDecode(locationRaw) as Map<String, dynamic>,
      );
      final settingsRaw = prefs.getString('settings');
      if (settingsRaw != null) {
        final settings = SettingsModel.fromJson(
          jsonDecode(settingsRaw) as Map<String, dynamic>,
        );
        
        final prayerService = PrayerTimesService();
        final times = prayerService.calculate(location, settings.calculationMethod);
        
        // Update notification immediately (UI Title: Next Prayer)
        _updateForegroundNotification(service, times);
        developer.log('PRAYER_CALC_SUCCESS (CACHED)', name: 'BackgroundService');
      }
    } catch (e) {
      developer.log('[BackgroundService] Cached calculation failed: $e', name: 'BackgroundService');
    }
  }

  // 2. Attempt Fresh GPS Fetch with Timeout
  try {
    developer.log('LOCATION_FETCH_STARTED', name: 'BackgroundService');
    final locationService = LocationService();
    final freshLocation = await locationService.getCurrentLocation(
      timeout: const Duration(seconds: 8),
    );
    
    // Success: Update cache and recalculate
    await prefs.setString('last_location', jsonEncode(freshLocation.toJson()));
    
    final settingsRaw = prefs.getString('settings');
    if (settingsRaw != null) {
      final settings = SettingsModel.fromJson(
        jsonDecode(settingsRaw) as Map<String, dynamic>,
      );
      final prayerService = PrayerTimesService();
      final times = prayerService.calculate(freshLocation, settings.calculationMethod);
      _updateForegroundNotification(service, times);
      developer.log('PRAYER_CALC_SUCCESS', name: 'BackgroundService');
    }
  } catch (e) {
    // 3. Fallback used on timeout/failure
    developer.log('LOCATION_FALLBACK_USED: $e', name: 'BackgroundService');
  }
}

void _updateForegroundNotification(ServiceInstance service, PrayerTimesModel times) {
  if (service is AndroidServiceInstance) {
    final nextPrayer = times.nextPrayer;
    if (nextPrayer != null) {
      String formatTime(DateTime time) {
        final hr = time.hour > 12
            ? time.hour - 12
            : (time.hour == 0 ? 12 : time.hour);
        final mn = time.minute.toString().padLeft(2, '0');
        final ampm = time.hour >= 12 ? 'م' : 'ص';
        return "$hr:$mn $ampm";
      }

      final contentStr =
          (nextPrayer.name == Prayer.sunrise || nextPrayer.name == Prayer.imsak)
          ? '${nextPrayer.name.nameAr} - ${formatTime(nextPrayer.time)}'
          : 'الصلاة القادمة: ${nextPrayer.name.nameAr} - ${formatTime(nextPrayer.time)}';

      service.setForegroundNotificationInfo(
        title: 'أوقات الصلاة',
        content: contentStr,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// _checkAndTriggerAthan – runs every minute (Ported from adhan project)
// ---------------------------------------------------------------------------
Future<void> _checkAndTriggerAthan(
  ServiceInstance service,
  AthanAudioService athanAudio,
  FlutterLocalNotificationsPlugin notifications, {
  SharedPreferences? prefs,
}) async {
  try {
    final activePrefs = prefs ?? await SharedPreferences.getInstance();

    final settingsRaw = activePrefs.getString('settings');
    if (settingsRaw == null) return;
    final settings = SettingsModel.fromJson(
      jsonDecode(settingsRaw) as Map<String, dynamic>,
    );

    if (!settings.athanEnabled) return;

    final locationRaw = activePrefs.getString('last_location');
    if (locationRaw == null) return;
    final location = LocationModel.fromJson(
      jsonDecode(locationRaw) as Map<String, dynamic>,
    );

    final prayerService = PrayerTimesService();
    final now = DateTime.now();

    final times = prayerService.calculate(location, settings.calculationMethod);

    // ── UPDATE FOREGROUND NOTIFICATION DYNAMICALLY
    _updateForegroundNotification(service, times);

    final nextPrayer = times.nextPrayer;

    // ── WIDGET LIVE UPDATE
    if (nextPrayer != null) {
      final remaining = nextPrayer.time.difference(now);
      final countdown = remaining.isNegative ? Duration.zero : remaining;
      final wHours = countdown.inHours.toString().padLeft(2, '0');
      final wMins = (countdown.inMinutes % 60).toString().padLeft(2, '0');
      final wNextName =
          '${nextPrayer.name.nameAr} ${_formatTime12(nextPrayer.time)}';
      try {
        await HomeWidget.saveWidgetData<String>('widget_hours', wHours);
        await HomeWidget.saveWidgetData<String>('widget_minutes', wMins);
        await HomeWidget.saveWidgetData<String>('next_prayer', wNextName);
        await Future.delayed(const Duration(milliseconds: 50));
        await HomeWidget.updateWidget(
          name: 'PrayerWidgetProvider',
          androidName: 'PrayerWidgetProvider',
        );
      } catch (e) {
        developer.log('[BackgroundService] Widget update failed: $e');
      }
    }

    for (final entry in times.toList()) {
      final diff = entry.time.difference(now);

      developer.log("CHECK: ${entry.name} diff=${diff.inSeconds}");

      if (diff.inSeconds >= -120 && diff.inSeconds <= 65) {
        final currentKey =
            '${now.year}-${now.month}-${now.day}_${entry.name.nameAr}';
        if (_lastTriggeredAthanKey == currentKey) continue;

        _lastTriggeredAthanKey = currentKey;

        developer.log("TRIGGER: ${entry.name}");

        int delaySeconds = diff.inSeconds;

        if (delaySeconds > 1) {
          delaySeconds -= 1;
        } else {
          delaySeconds = 0;
        }

        Future.delayed(Duration(seconds: delaySeconds), () async {
          final now2 = DateTime.now();
          final actualDiff = entry.time.difference(now2).inSeconds;

          if (actualDiff < -180) {
            developer.log("Skipped late Athan: ${entry.name}");
            return;
          }

          final notifId = 100 + entry.name.index;

          // ── Imsak & Sunrise: silent notification only
          if (entry.name == Prayer.imsak || entry.name == Prayer.sunrise) {
            const silentDetails = AndroidNotificationDetails(
              'adhan_background',
              'Adhan Running',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              playSound: false,
              enableVibration: false,
              ongoing: false,
            );
            await notifications.show(
              id: notifId,
              title: 'تنبيه: ${entry.name.nameAr}',
              body: entry.name == Prayer.imsak
                  ? 'حان وقت الإمساك — امتنع عن الطعام والشراب'
                  : 'حان وقت الشروق',
              notificationDetails: const NotificationDetails(
                android: silentDetails,
              ),
            );
            return;
          }

          // ── Main prayers Athan flow
          // Cancel other notifications before showing the new one
          await notifications.cancelAll();

          final prayerImage = _resolvePrayerHeaderAsset(entry.name);

          // Audio - Trigger ALARM stream natively (AthanAudioService should handle audio focus)
          if (settings.athanSoundEnabled) {
            try {
              final assetPath = _resolveAthanAsset(entry.name, settings);
              await athanAudio.stop(); // Safe guard
              athanAudio.play(assetPath);
            } catch (e) {
              developer.log('[BackgroundService] Audio trigger failed: $e', name: 'BackgroundService');
            }
          }

          // ── Build a native BroadcastReceiver PendingIntent for the Stop action.
          final androidDetails = AndroidNotificationDetails(
            'adhan_athan',
            'Athan Alarm',
            importance: Importance.max,
            priority: Priority.max,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
            ongoing: true,
            autoCancel: false,
            actions: const [
              AndroidNotificationAction(
                'stop_audio',
                'إيقاف الأذان',
                cancelNotification: false,
                showsUserInterface: false,
              ),
            ],
          );

          await notifications.show(
            id: notifId,
            title: 'حان وقت ${entry.name.nameAr}',
            body: 'اضغط لإيقاف الأذان',
            notificationDetails: NotificationDetails(android: androidDetails),
            payload: jsonEncode({
              'ar': entry.name.nameAr,
              'en': entry.name.nameEn,
              'image': prayerImage,
            }),
          );

          // Persist the playing flag
          try {
            await activePrefs.setBool('athan_is_playing', true);
            await activePrefs.setString('athan_prayer_ar', entry.name.nameAr);
            await activePrefs.setString('athan_prayer_en', entry.name.nameEn);
            await activePrefs.setString('athan_prayer_image', prayerImage);
          } catch (_) {}

          service.invoke('athan_started', {
            'prayer': entry.name.nameAr,
            'prayerEn': entry.name.nameEn,
            'image': prayerImage,
          });

          // ── Native Intent: force MainActivity to the foreground on the lock screen.
          try {
            await _athanControlChannel.invokeMethod('launchAthanOverlay', {
              'prayer': entry.name.nameAr,
              'prayerEn': entry.name.nameEn,
              'image': prayerImage,
            });

            developer.log(
              '[BackgroundService] launchAthanOverlay native call succeeded.',
              name: 'BackgroundService',
            );
          } catch (e) {
            developer.log(
              '[BackgroundService] launchAthanOverlay native call failed: $e',
              name: 'BackgroundService',
            );
          }
        });

        break;
      }
    }
  } catch (e, st) {
    developer.log(
      '[BackgroundService] Error in _checkAndTriggerAthan: $e\n$st',
    );
  }
}

// ---------------------------------------------------------------------------
// _checkIslamicEvents – fires at 08:00 AM daily
// ---------------------------------------------------------------------------
Future<void> _checkIslamicEvents(
  FlutterLocalNotificationsPlugin notifications,
) async {
  try {
    final now = DateTime.now();
    if (now.hour != 8 || now.minute != 0) return;

    final todayKey = '${now.year}-${now.month}-${now.day}';
    if (_lastEventNotifiedDate == todayKey) return;

    final hijri = HijriCalendar.now();
    final hMonth = hijri.hMonth;
    final hDay = hijri.hDay;

    final todaysEvents = IslamicEvent.allEvents
        .where((e) => e.month == hMonth && e.day == hDay)
        .toList();

    if (todaysEvents.isEmpty) return;
    _lastEventNotifiedDate = todayKey;

    for (int i = 0; i < todaysEvents.length; i++) {
      final event = todaysEvents[i];
      const androidDetails = AndroidNotificationDetails(
        'islamic_events',
        'المناسبات الإسلامية',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        ongoing: false,
      );

      await notifications.show(
        id: 9100 + i,
        title: '🌙 مناسبة إسلامية',
        body: event.name,
        notificationDetails: const NotificationDetails(android: androidDetails),
      );
    }
  } catch (e) {
    developer.log('[BackgroundService] Error in _checkIslamicEvents: $e');
  }
}

// ---------------------------------------------------------------------------
// _checkEidTakbeer – plays Eid Takbeer 30 min after Fajr
// ---------------------------------------------------------------------------
Future<void> _checkEidTakbeer(
  ServiceInstance service,
  AthanAudioService athanAudio,
  FlutterLocalNotificationsPlugin notifications, {
  SharedPreferences? prefs,
}) async {
  try {
    final activePrefs = prefs ?? await SharedPreferences.getInstance();
    final eidTakbeerEnabled = activePrefs.getBool('enable_eid_takbeer') ?? true;
    if (!eidTakbeerEnabled) return;

    final hijri = HijriCalendar.now();
    final isEidAlFitr = hijri.hMonth == 10 && hijri.hDay == 1;
    final isEidAlAdha = hijri.hMonth == 12 && hijri.hDay == 10;
    if (!isEidAlFitr && !isEidAlAdha) return;

    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month}-${now.day}';
    if (_lastEidTakbeerDate == todayKey) return;

    final settingsRaw = activePrefs.getString('settings');
    if (settingsRaw == null) return;
    final settings = SettingsModel.fromJson(
      jsonDecode(settingsRaw) as Map<String, dynamic>,
    );

    final locationRaw = activePrefs.getString('last_location');
    if (locationRaw == null) return;
    final location = LocationModel.fromJson(
      jsonDecode(locationRaw) as Map<String, dynamic>,
    );

    final prayerService = PrayerTimesService();
    final times = prayerService.calculate(location, settings.calculationMethod);

    final fajrEntry = times.toList().firstWhere(
      (e) => e.name == Prayer.fajr,
      orElse: () => times.toList().first,
    );
    final triggerTime = fajrEntry.time.add(const Duration(minutes: 30));
    final diff = now.difference(triggerTime);

    if (diff.inSeconds < 0 || diff.inSeconds > 60) return;
    _lastEidTakbeerDate = todayKey;

    final eidName = isEidAlFitr ? 'عيد الفطر المبارك' : 'عيد الأضحى المبارك';
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'أوقات الصلاة',
        content: 'تكبيرات العيد جارية الآن 🎉',
      );
    }

    await athanAudio.stop();
    athanAudio.play('assets/audio/eid_takbeer.mp3');
    service.invoke('show_eid_screen', {'eid_name': eidName});

    const androidDetails = AndroidNotificationDetails(
      'islamic_events',
      'المناسبات الإسلامية',
      importance: Importance.high,
      priority: Priority.high,
      playSound: false,
      enableVibration: true,
      ongoing: false,
    );

    await notifications.show(
      id: 9200,
      title: '🎉 $eidName',
      body: 'تكبيرات العيد جارية الآن',
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  } catch (e) {
    developer.log('[BackgroundService] Error in _checkEidTakbeer: $e');
  }
}

// ---------------------------------------------------------------------------
// Helper: resolve the asset path
// ---------------------------------------------------------------------------
String _resolveAthanAsset(Prayer prayer, SettingsModel settings) {
  final String path = switch (prayer) {
    Prayer.fajr => settings.selectedFajrSound,
    _ when settings.isUnifiedAthan => settings.selectedAthanSound,
    Prayer.dhuhr => settings.selectedDhuhrSound,
    Prayer.asr => settings.selectedAsrSound,
    Prayer.maghrib => settings.selectedMaghribSound,
    Prayer.isha => settings.selectedIshaSound,
    _ => settings.selectedAthanSound,
  };
  return path;
}

// ---------------------------------------------------------------------------
// Helper: resolve the header background image asset path (.png mapping)
// ---------------------------------------------------------------------------
String _resolvePrayerHeaderAsset(Prayer prayer) {
  final Map<Prayer, String> assetMap = {
    Prayer.fajr: 'assets/images/header_fajr.png',
    Prayer.dhuhr: 'assets/images/header_dhuhr.png',
    Prayer.asr: 'assets/images/header_dhuhr.png',
    Prayer.maghrib: 'assets/images/header_maghrib.png',
    Prayer.isha: 'assets/images/header_isha.png',
  };

  final asset = assetMap[prayer];
  if (asset == null) return 'assets/images/header_isha.png';
  return asset;
}

// ---------------------------------------------------------------------------
// Helper: format a DateTime as 12-hour h:mm
// ---------------------------------------------------------------------------
String _formatTime12(DateTime time) {
  final hr = time.hour > 12
      ? time.hour - 12
      : (time.hour == 0 ? 12 : time.hour);
  final mn = time.minute.toString().padLeft(2, '0');
  return '$hr:$mn';
}
