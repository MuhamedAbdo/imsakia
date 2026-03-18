import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
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
import 'package:hijri/hijri_calendar.dart';
import 'package:home_widget/home_widget.dart';

class BackgroundService {
  static const _foregroundNotificationId = 9001;
  static const _channelId = 'adhan_background';
  static const _channelName = 'Adhan Running';
  static const _eventsChannelId = 'islamic_events';
  static const _eventsChannelName = 'المناسبات الإسلامية';

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // ── Notification channels ─────────────────────────────────────────────────
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
        _eventsChannelId,
        _eventsChannelName,
        description: 'يُعلمك بالمناسبات الإسلامية المهمة يومياً',
        importance: Importance.high,
      ),
    );

    // ── Configure the background service ─────────────────────────────────────
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

  developer.log('[BackgroundService] Isolate started.',
      name: 'BackgroundService');

  // ── Notification plugin ───────────────────────────────────────────────────
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

  // ── Foreground / background mode control ────────────────────────────────
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  // ── Stop service command ─────────────────────────────────────────────────
  service.on('stop').listen((event) {
    developer.log('[BackgroundService] Received stop — shutting down service.',
        name: 'BackgroundService');
    service.stopSelf();
  });

  // ── Unified stop_audio command ───────────────────────────────────────────
  service.on('stop_audio').listen((event) async {
    developer.log(
        '[BackgroundService] Received stop_audio command — stopping audio and clearing all notifications.',
        name: 'BackgroundService');
    await athanAudio.stop();
    await flutterLocalNotificationsPlugin.cancelAll();
  });

  // ── Manual reschedule trigger ────────────────────────────────────────────
  service.on('schedule').listen((event) async {
    developer.log(
        '[BackgroundService] Received schedule command — refreshing prayer times.',
        name: 'BackgroundService');
    await _scheduleNextAthan(
        service, athanAudio, flutterLocalNotificationsPlugin);
  });

  // ── Initial prayer-time check ────────────────────────────────────────────
  await _scheduleNextAthan(
      service, athanAudio, flutterLocalNotificationsPlugin);

  // ── Periodic 1-minute tick ───────────────────────────────────────────────
  Timer.periodic(const Duration(minutes: 1), (timer) async {
    await _checkAndTriggerAthan(
        service, athanAudio, flutterLocalNotificationsPlugin);
    await _checkIslamicEvents(flutterLocalNotificationsPlugin);
    await _checkEidTakbeer(service, athanAudio, flutterLocalNotificationsPlugin);
  });
}

// ---------------------------------------------------------------------------
// Per-day debounce key (reset each new day automatically via date component)
// ---------------------------------------------------------------------------
String _lastTriggeredAthanKey = '';

// Last date an Islamic event notification was sent (yyyy-MM-dd)
String _lastEventNotifiedDate = '';

// Last date Eid Takbeer was played (yyyy-MM-dd)
String _lastEidTakbeerDate = '';

// ---------------------------------------------------------------------------
// _scheduleNextAthan – called once on startup and via 'schedule' command
// ---------------------------------------------------------------------------
Future<void> _scheduleNextAthan(
    ServiceInstance service,
    AthanAudioService athanAudio,
    FlutterLocalNotificationsPlugin notifications) async {
  developer.log(
      '[BackgroundService] _scheduleNextAthan: performing initial check.',
      name: 'BackgroundService');
  await _checkAndTriggerAthan(service, athanAudio, notifications);
}

// ---------------------------------------------------------------------------
// _checkAndTriggerAthan – runs every minute
// ---------------------------------------------------------------------------
Future<void> _checkAndTriggerAthan(
    ServiceInstance service,
    AthanAudioService athanAudio,
    FlutterLocalNotificationsPlugin notifications) async {
  try {
    final prefs = await SharedPreferences.getInstance();

    final settingsRaw = prefs.getString('settings');
    if (settingsRaw == null) {
      developer.log('[BackgroundService] No settings found — skipping check.',
          name: 'BackgroundService');
      return;
    }
    final settings =
        SettingsModel.fromJson(jsonDecode(settingsRaw) as Map<String, dynamic>);

    if (!settings.athanEnabled) {
      developer.log('[BackgroundService] Athan disabled — skipping check.',
          name: 'BackgroundService');
      return;
    }

    final locationRaw = prefs.getString('last_location');
    if (locationRaw == null) {
      developer.log('[BackgroundService] No location found — skipping check.',
          name: 'BackgroundService');
      return;
    }
    final location =
        LocationModel.fromJson(jsonDecode(locationRaw) as Map<String, dynamic>);

    final prayerService = PrayerTimesService();
    final now = DateTime.now();

    final times = prayerService.calculate(location, settings.calculationMethod);

    // ── UPDATE FOREGROUND NOTIFICATION DYNAMICALLY ─────────────────────────
    final nextPrayer = times.nextPrayer;
    if (nextPrayer != null && service is AndroidServiceInstance) {
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

    developer.log(
      '[BackgroundService] Tick at $now — checking ${times.toList().length} prayers.',
      name: 'BackgroundService',
    );

    // ── WIDGET LIVE UPDATE ─────────────────────────────────────────────────
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
        developer.log(
          '[BackgroundService] Widget updated: ${wHours}h ${wMins}m → $wNextName.',
          name: 'BackgroundService',
        );
      } catch (e) {
        developer.log(
          '[BackgroundService] Widget update failed: $e',
          name: 'BackgroundService',
        );
      }
    }

    for (final entry in times.toList()) {
      final diff = entry.time.difference(now);

      // Window: 0 – 60 seconds before/after prayer time
      if (diff.inSeconds >= 0 && diff.inSeconds <= 60) {
        // Unique key includes date + prayer name to prevent cross-day collisions
        final currentKey =
            '${now.year}-${now.month}-${now.day}_${entry.name.nameAr}';

        if (_lastTriggeredAthanKey == currentKey) {
          developer.log(
            '[BackgroundService] Debounce key match — skipping duplicate trigger for $currentKey.',
            name: 'BackgroundService',
          );
          continue;
        }

        developer.log(
          '[BackgroundService] ✅ Triggering alert for $currentKey at $now.',
          name: 'BackgroundService',
        );
        _lastTriggeredAthanKey = currentKey;

        final notifId = 100 + entry.name.index;

        // ── Imsak & Sunrise: silent notification only ───────────────────────
        if (entry.name == Prayer.imsak || entry.name == Prayer.sunrise) {
          developer.log(
            '[BackgroundService] ${entry.name.nameAr} — showing silent reminder only.',
            name: 'BackgroundService',
          );
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
            notificationDetails:
                const NotificationDetails(android: silentDetails),
          );
          break;
        }

        // ── Main prayers (Fajr, Dhuhr, Asr, Maghrib, Isha): full Athan flow ─

        developer.log(
          '[BackgroundService] Cancelling all previous notifications before ${entry.name.nameAr} Athan.',
          name: 'BackgroundService',
        );
        await notifications.cancelAll();

        final prayerImage = _resolvePrayerHeaderAsset(entry.name);

        // ── Audio ───────────────────────────────────────────────────────────
        if (settings.athanSoundEnabled) {
          final assetPath = _resolveAthanAsset(entry.name, settings);
          developer.log(
            '[BackgroundService] Audio command: playing $assetPath for ${entry.name.nameAr}.',
            name: 'BackgroundService',
          );
          athanAudio.play(assetPath);
        } else {
          developer.log('[BackgroundService] Sound disabled — skipping audio.',
              name: 'BackgroundService');
        }

        // ── Athan notification ──────────────────────────────────────────────
        developer.log(
          '[BackgroundService] Showing Athan notification id=$notifId for ${entry.name.nameAr}.',
          name: 'BackgroundService',
        );

        const androidDetails = AndroidNotificationDetails(
          'adhan_athan',
          'Athan Alarm',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          ongoing: true,
          actions: [
            AndroidNotificationAction(
              'stop_audio',
              'إيقاف الأذان',
              cancelNotification: true,
            ),
          ],
        );

        await notifications.show(
          id: notifId,
          title: 'حان وقت ${entry.name.nameAr}',
          body: 'اضغط لإيقاف الأذان',
          notificationDetails:
              const NotificationDetails(android: androidDetails),
          payload:
              jsonEncode({
            'ar': entry.name.nameAr,
            'en': entry.name.nameEn,
            'image': prayerImage,
          }),
        );

        service.invoke('athan_started', {
          'prayer': entry.name.nameAr,
          'prayerEn': entry.name.nameEn,
          'image': prayerImage,
        });

        developer.log(
          '[BackgroundService] 🔔 Athan sequence complete for ${entry.name.nameAr}.',
          name: 'BackgroundService',
        );
        break;
      }
    }
  } catch (e, st) {
    developer.log('[BackgroundService] Error in _checkAndTriggerAthan: $e\n$st',
        name: 'BackgroundService');
  }
}

// ---------------------------------------------------------------------------
// _checkIslamicEvents – fires at 08:00 AM daily if there's a current event
// ---------------------------------------------------------------------------
Future<void> _checkIslamicEvents(
    FlutterLocalNotificationsPlugin notifications) async {
  try {
    final now = DateTime.now();

    // Only run during the 08:00 AM minute window
    if (now.hour != 8 || now.minute != 0) return;

    // Prevent duplicate notifications within the same day
    final todayKey = '${now.year}-${now.month}-${now.day}';
    if (_lastEventNotifiedDate == todayKey) {
      developer.log(
        '[BackgroundService] Islamic events already notified today ($todayKey) — skipping.',
        name: 'BackgroundService',
      );
      return;
    }

    // Get today's Hijri date
    final hijri = HijriCalendar.now();
    final hMonth = hijri.hMonth;
    final hDay = hijri.hDay;

    developer.log(
      '[BackgroundService] Checking Islamic events for Hijri $hDay/$hMonth.',
      name: 'BackgroundService',
    );

    // Find all events matching today's Hijri date
    final todaysEvents = IslamicEvent.allEvents
        .where((e) => e.month == hMonth && e.day == hDay)
        .toList();

    if (todaysEvents.isEmpty) {
      developer.log(
        '[BackgroundService] No Islamic events today.',
        name: 'BackgroundService',
      );
      return;
    }

    _lastEventNotifiedDate = todayKey;

    for (int i = 0; i < todaysEvents.length; i++) {
      final event = todaysEvents[i];
      developer.log(
        '[BackgroundService] 🌙 Islamic event detected: ${event.name}. Showing notification.',
        name: 'BackgroundService',
      );

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
  } catch (e, st) {
    developer.log(
      '[BackgroundService] Error in _checkIslamicEvents: $e\n$st',
      name: 'BackgroundService',
    );
  }
}

// ---------------------------------------------------------------------------
// _checkEidTakbeer – plays Eid Takbeer 30 min after Fajr on Eid days
// ---------------------------------------------------------------------------
Future<void> _checkEidTakbeer(
    ServiceInstance service,
    AthanAudioService athanAudio,
    FlutterLocalNotificationsPlugin notifications) async {
  try {
    final prefs = await SharedPreferences.getInstance();

    // Check if Eid Takbeer feature is enabled (default: true)
    final eidTakbeerEnabled = prefs.getBool('enable_eid_takbeer') ?? true;
    if (!eidTakbeerEnabled) return;

    // Check today's Hijri date — only run on Eid days
    final hijri = HijriCalendar.now();
    final isEidAlFitr = hijri.hMonth == 10 && hijri.hDay == 1;
    final isEidAlAdha = hijri.hMonth == 12 && hijri.hDay == 10;
    if (!isEidAlFitr && !isEidAlAdha) return;

    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month}-${now.day}';

    // Debounce: play only once per day
    if (_lastEidTakbeerDate == todayKey) return;

    // Get Fajr time to compute the 30-minute trigger window
    final settingsRaw = prefs.getString('settings');
    if (settingsRaw == null) return;
    final settings =
        SettingsModel.fromJson(jsonDecode(settingsRaw) as Map<String, dynamic>);

    final locationRaw = prefs.getString('last_location');
    if (locationRaw == null) return;
    final location =
        LocationModel.fromJson(jsonDecode(locationRaw) as Map<String, dynamic>);

    final prayerService = PrayerTimesService();
    final times = prayerService.calculate(location, settings.calculationMethod);

    final fajrEntry = times.toList().firstWhere(
      (e) => e.name == Prayer.fajr,
      orElse: () => times.toList().first,
    );

    final triggerTime = fajrEntry.time.add(const Duration(minutes: 30));
    final diff = now.difference(triggerTime);

    // Trigger window: within 60 seconds of Fajr + 30 min
    if (diff.inSeconds < 0 || diff.inSeconds > 60) return;

    _lastEidTakbeerDate = todayKey;

    final eidName = isEidAlFitr ? 'عيد الفطر المبارك' : 'عيد الأضحى المبارك';

    developer.log(
      '[BackgroundService] 🎉 $eidName — playing Eid Takbeer.',
      name: 'BackgroundService',
    );

    // Update foreground notification
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'أوقات الصلاة',
        content: 'تكبيرات العيد جارية الآن 🎉',
      );
    }

    // Play Eid Takbeer audio
    athanAudio.play('assets/audio/eid_takbeer.mp3');

    // Notify the UI isolate to show the Eid Celebration Screen
    service.invoke('show_eid_screen', {'eid_name': eidName});

    // Show a notification
    const androidDetails = AndroidNotificationDetails(
      'islamic_events',
      'المناسبات الإسلامية',
      importance: Importance.high,
      priority: Priority.high,
      playSound: false, // audio handled by athanAudio
      enableVibration: true,
      ongoing: false,
    );

    await notifications.show(
      id: 9200,
      title: '🎉 $eidName',
      body: 'تكبيرات العيد جارية الآن',
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  } catch (e, st) {
    developer.log(
      '[BackgroundService] Error in _checkEidTakbeer: $e\n$st',
      name: 'BackgroundService',
    );
  }
}

// ---------------------------------------------------------------------------
// Helper: resolve the asset path based on settings & prayer
// ---------------------------------------------------------------------------
String _resolveAthanAsset(Prayer prayer, SettingsModel settings) {
  if (settings.isUnifiedAthan) {
    developer.log(
      '[BackgroundService] Unified Athan mode — using ${settings.selectedAthanSound} for ${prayer.nameAr}.',
      name: 'BackgroundService',
    );
    return settings.selectedAthanSound;
  }

  final String path;
  switch (prayer) {
    case Prayer.fajr:
      path = settings.selectedFajrSound;
    case Prayer.dhuhr:
      path = settings.selectedDhuhrSound;
    case Prayer.asr:
      path = settings.selectedAsrSound;
    case Prayer.maghrib:
      path = settings.selectedMaghribSound;
    case Prayer.isha:
      path = settings.selectedIshaSound;
    default:
      path = settings.selectedAthanSound;
  }

  developer.log(
    '[BackgroundService] Per-prayer mode — using $path for ${prayer.nameAr}.',
    name: 'BackgroundService',
  );
  return path;
}

// ---------------------------------------------------------------------------
// Helper: resolve the header background image asset path based on prayer
// ---------------------------------------------------------------------------
String _resolvePrayerHeaderAsset(Prayer prayer) {
  switch (prayer) {
    case Prayer.fajr:
      return 'assets/images/header_fajr.png';
    case Prayer.dhuhr:
    case Prayer.asr:
      return 'assets/images/header_dhuhr.png';
    case Prayer.maghrib:
      return 'assets/images/header_maghrib.png';
    default:
      return 'assets/images/header_isha.png';
  }
}

// ---------------------------------------------------------------------------
// Helper: format a DateTime as 12-hour h:mm (no AM/PM suffix)
// ---------------------------------------------------------------------------
String _formatTime12(DateTime time) {
  final hr =
      time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
  final mn = time.minute.toString().padLeft(2, '0');
  return '$hr:$mn';
}
