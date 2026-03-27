import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/prayer_times_model.dart';
import '../models/location_model.dart';
import '../models/settings_model.dart';
import '../models/islamic_event_model.dart';
import 'prayer_times_service.dart';
import 'athan_audio_service.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:home_widget/home_widget.dart';

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
            AndroidFlutterLocalNotificationsPlugin>();

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
  static void sendStopAudio() {
    developer.log('[BackgroundService] Sending stop_audio command.',
        name: 'BackgroundService');
    FlutterBackgroundService().invoke('stop_audio');
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

  developer.log('[BackgroundService] Isolate started (adhan precision loop).',
      name: 'BackgroundService');

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
            name: 'BackgroundService');
        await athanAudio.stop();
        if (details.id != null) {
          developer.log(
              '[BackgroundService] Auto-dismissing notification ${details.id}.',
              name: 'BackgroundService');
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
    developer.log('[BackgroundService] Received stop — shutting down service.',
        name: 'BackgroundService');
    service.stopSelf();
  });

  // ── Unified stop_audio command (from overlay Stop button OR notification action)
  service.on('stop_audio').listen((event) async {
    developer.log(
        '[BackgroundService] Received stop_audio command — stopping audio and clearing all notifications.',
        name: 'BackgroundService');
    await athanAudio.stop();
    await flutterLocalNotificationsPlugin.cancelAll();
    try {
      const athanChannel = MethodChannel('imsakia/athan_control');
      await athanChannel.invokeMethod('stopNativeAudio').timeout(const Duration(milliseconds: 500));
    } catch (e) {
      developer.log('[BackgroundService] Failed to stop native audio: $e');
    }
    // Clear the playing flag so the UI knows audio has ended.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('flutter.athan_is_playing', false);
      await prefs.setBool('athan_is_playing', false);
    } catch (_) {}
  });

  // ── No repetitive scheduling logic needed here anymore.
  // The Main Isolate registers precise OS-level alarms with Native SDK.

  // ── Periodic 1-minute tick (For UI/Widget & Daily Islamic Events only)
  Timer.periodic(const Duration(minutes: 1), (timer) async {
    await _updateWidgetCountdown(service);
    await _checkIslamicEvents(flutterLocalNotificationsPlugin);
    await _checkEidTakbeer(service, athanAudio, flutterLocalNotificationsPlugin);
  });
}

// ---------------------------------------------------------------------------
// Per-day debounce keys
// ---------------------------------------------------------------------------
String _lastEventNotifiedDate = '';
String _lastEidTakbeerDate = '';

// ---------------------------------------------------------------------------
// _updateWidgetCountdown – runs every minute to refresh the widget
// ---------------------------------------------------------------------------
Future<void> _updateWidgetCountdown(ServiceInstance service) async {
  try {
    final prefs = await SharedPreferences.getInstance();

    final settingsRaw = prefs.getString('settings');
    if (settingsRaw == null) return;
    final settings = SettingsModel.fromJson(jsonDecode(settingsRaw) as Map<String, dynamic>);

    if (!settings.athanEnabled) return;

    final locationRaw = prefs.getString('last_location');
    if (locationRaw == null) return;
    final location = LocationModel.fromJson(jsonDecode(locationRaw) as Map<String, dynamic>);

    final prayerService = PrayerTimesService();
    final now = DateTime.now();
    final times = prayerService.calculate(location, settings.calculationMethod);

    final nextPrayer = times.nextPrayer;
    if (nextPrayer != null) {
      if (service is AndroidServiceInstance) {
        String formatTime(DateTime time) {
          final hr = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
          final mn = time.minute.toString().padLeft(2, '0');
          final ampm = time.hour >= 12 ? 'م' : 'ص';
          return "$hr:$mn $ampm";
        }

        final contentStr = (nextPrayer.name == Prayer.sunrise || nextPrayer.name == Prayer.imsak)
            ? '${nextPrayer.name.nameAr} - ${formatTime(nextPrayer.time)}'
            : 'الصلاة القادمة: ${nextPrayer.name.nameAr} - ${formatTime(nextPrayer.time)}';

        service.setForegroundNotificationInfo(
          title: 'أوقات الصلاة',
          content: contentStr,
        );
      }

      final remaining = nextPrayer.time.difference(now);
      final countdown = remaining.isNegative ? Duration.zero : remaining;
      final wHours = countdown.inHours.toString().padLeft(2, '0');
      final wMins = (countdown.inMinutes % 60).toString().padLeft(2, '0');
      final wNextName = '${nextPrayer.name.nameAr} ${_formatTime12(nextPrayer.time)}';
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
  } catch (e) {
    developer.log('[BackgroundService] Error in _updateWidgetCountdown: $e');
  }
}


// ---------------------------------------------------------------------------
// _checkIslamicEvents – fires at 08:00 AM daily
// ---------------------------------------------------------------------------
Future<void> _checkIslamicEvents(
    FlutterLocalNotificationsPlugin notifications) async {
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
    FlutterLocalNotificationsPlugin notifications) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final eidTakbeerEnabled = prefs.getBool('enable_eid_takbeer') ?? true;
    if (!eidTakbeerEnabled) return;

    final hijri = HijriCalendar.now();
    final isEidAlFitr = hijri.hMonth == 10 && hijri.hDay == 1;
    final isEidAlAdha = hijri.hMonth == 12 && hijri.hDay == 10;
    if (!isEidAlFitr && !isEidAlAdha) return;

    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month}-${now.day}';
    if (_lastEidTakbeerDate == todayKey) return;

    final settingsRaw = prefs.getString('settings');
    if (settingsRaw == null) return;
    final settings = SettingsModel.fromJson(jsonDecode(settingsRaw) as Map<String, dynamic>);

    final locationRaw = prefs.getString('last_location');
    if (locationRaw == null) return;
    final location = LocationModel.fromJson(jsonDecode(locationRaw) as Map<String, dynamic>);

    final prayerService = PrayerTimesService();
    final times = prayerService.calculate(location, settings.calculationMethod);

    final fajrEntry = times.toList().firstWhere((e) => e.name == Prayer.fajr, orElse: () => times.toList().first);
    final triggerTime = fajrEntry.time.add(const Duration(minutes: 30));
    final diff = now.difference(triggerTime);

    if (diff.inSeconds < 0 || diff.inSeconds > 60) return;
    _lastEidTakbeerDate = todayKey;

    final eidName = isEidAlFitr ? 'عيد الفطر المبارك' : 'عيد الأضحى المبارك';
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(title: 'أوقات الصلاة', content: 'تكبيرات العيد جارية الآن 🎉');
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
// Helper: format a DateTime as 12-hour h:mm
// ---------------------------------------------------------------------------
String _formatTime12(DateTime time) {
  final hr = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
  final mn = time.minute.toString().padLeft(2, '0');
  return '$hr:$mn';
}

