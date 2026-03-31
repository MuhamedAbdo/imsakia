import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'dart:convert';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
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
  static const _athanChannelId = 'athan_channel';

  /// MethodChannel للتحكم في ZadWatchdogService الكوتلين
  static const _watchdogChannel = MethodChannel('imsakia/watchdog_control');

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

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

    const athanChannelId = 'athan_channel';

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        athanChannelId,
        'Athan',
        importance: Importance.max,
        description: 'الأذان وقت الصلاة',
        enableVibration: true,
        playSound: false,
        showBadge: true,
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
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: 'زاد',
        initialNotificationContent: 'سيتم تنبيهك عند كل صلاة بإذن الله',
        foregroundServiceNotificationId: _foregroundNotificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
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
    // تشغيل ZadWatchdogService بعد التحقق من اكتمال تشغيل الـ BackgroundService
    if (Platform.isAndroid) {
      await startWatchdog();
    }
  }

  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stop');
    // إيقاف Watchdog أيضاً إذا أوقف المستخدم الخدمة عن قصد
    if (Platform.isAndroid) {
      try {
        await _watchdogChannel.invokeMethod('stopWatchdog');
      } catch (_) {}
    }
  }

  /// يُشغّل ZadWatchdogService عبر الـ MethodChannel
  static Future<void> startWatchdog() async {
    try {
      await _watchdogChannel.invokeMethod('startWatchdog');
      developer.log('[BackgroundService] ZadWatchdogService started.', name: 'Watchdog');
    } catch (e) {
      developer.log('[BackgroundService] Failed to start watchdog: $e', name: 'Watchdog');
    }
  }

  static void sendStopAudio() {
    developer.log('[BackgroundService] Sending stop_audio command.',
        name: 'BackgroundService');
    FlutterBackgroundService().invoke('stop_audio');
  }

  static String get athanChannelId => _athanChannelId;
}

@pragma('vm:entry-point')
Future<bool> _iosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  try {
    tz.initializeTimeZones();
    final prefs = await SharedPreferences.getInstance();
    final savedTimeZone = prefs.getString('timezone') ?? 'Africa/Cairo';
    tz.setLocalLocation(tz.getLocation(savedTimeZone));
    developer.log('[BackgroundService] Timezone initialized: $savedTimeZone');
  } catch (e) {
    developer.log('[BackgroundService] Failed to initialize timezone: $e');
  }

  final athanAudio = AthanAudioService();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('ic_notification');

  await flutterLocalNotificationsPlugin.initialize(
    settings: const InitializationSettings(android: initializationSettingsAndroid),
    onDidReceiveNotificationResponse: (NotificationResponse details) async {
      if (details.actionId == 'stop_audio' || details.actionId == null) {
        await athanAudio.stop();
        if (details.id != null) {
          await flutterLocalNotificationsPlugin.cancel(id: details.id!);
        }
      }
    },
  );

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stop').listen((event) {
    service.stopSelf();
  });

  service.on('stop_audio').listen((event) async {
    await athanAudio.stop();
    await flutterLocalNotificationsPlugin.cancelAll();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('athan_is_playing', false);
    } catch (_) {}
  });

  Timer.periodic(const Duration(minutes: 1), (timer) async {
    await _checkAndTriggerAthan(service, athanAudio, flutterLocalNotificationsPlugin);
    await _updateWidgetCountdown(service);
    await _updateForegroundNotification(service);
    await _checkIslamicEvents(flutterLocalNotificationsPlugin);
    await _checkEidTakbeer(service, athanAudio, flutterLocalNotificationsPlugin);
  });

  // ── Watchdog دوري كل 15 دقيقة ──
  // يؤكّد أن هذا الـ Isolate لا يزال في وضع Foreground.
  // هذا يمنع النظام من "تهجين" الخدمة إلى Background ثم قتلها.
  Timer.periodic(const Duration(minutes: 15), (timer) {
    if (service is AndroidServiceInstance) {
      developer.log('[BackgroundService] Watchdog tick — asserting foreground.', name: 'Watchdog');
      service.setAsForegroundService();
    }
  });

  await _checkAndTriggerAthan(service, athanAudio, flutterLocalNotificationsPlugin);
  await _updateForegroundNotification(service);
}

String _lastTriggeredAthanKey = '';
DateTime _lastRecalculateDate = DateTime.now();

Future<void> _checkAndTriggerAthan(
    ServiceInstance service,
    AthanAudioService athanAudio,
    FlutterLocalNotificationsPlugin notifications) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    if (now.day != _lastRecalculateDate.day) {
      _lastRecalculateDate = now;
    }

    final settingsRaw = prefs.getString('settings');
    if (settingsRaw == null) return;
    final settings = SettingsModel.fromJson(jsonDecode(settingsRaw) as Map<String, dynamic>);

    if (!settings.athanEnabled) return;

    final locationRaw = prefs.getString('last_location');
    if (locationRaw == null) return;
    final location = LocationModel.fromJson(jsonDecode(locationRaw) as Map<String, dynamic>);

    final times = PrayerTimesService().calculate(location, settings.calculationMethod);

    for (final entry in times.toList()) {
      final diff = entry.time.difference(now);

      if (diff.inSeconds >= 0 && diff.inSeconds <= 90) {
        final currentKey = '${now.year}-${now.month}-${now.day}_${entry.name.nameEn}';

        if (_lastTriggeredAthanKey == currentKey) continue;

        _lastTriggeredAthanKey = currentKey;

        if (entry.name == Prayer.imsak || entry.name == Prayer.sunrise) {
          const silentDetails = AndroidNotificationDetails(
            'adhan_background',
            'زاد - تنبيه',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            playSound: false,
            enableVibration: false,
          );
          await notifications.show(
            id: 150 + entry.name.index,
            title: 'تنبيه: ${entry.name.nameAr}',
            body: entry.name == Prayer.imsak ? 'حان وقت الإمساك' : 'حان وقت الشروق',
            notificationDetails: const NotificationDetails(android: silentDetails),
          );
          continue;
        }

        if (settings.athanSoundEnabled) {
          final assetPath = _resolveAthanSound(entry.name, settings);
          try {
            await athanAudio.play(assetPath);
          } catch (e) {
            service.invoke('fallback_audio', {'asset': assetPath});
          }
        }

        final androidDetails = AndroidNotificationDetails(
          BackgroundService.athanChannelId,
          'Athan',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          ticker: 'Athan',
          autoCancel: false,
          icon: 'ic_notification',
          styleInformation: const BigTextStyleInformation(''),
          actions: [
            const AndroidNotificationAction(
              'stop_audio',
              'إيقاف الأذان',
              cancelNotification: true,
              showsUserInterface: true,
            ),
          ],
        );

        await notifications.show(
          id: 100 + entry.name.index,
          title: 'حان الآن موعد أذان ${entry.name.nameAr}',
          body: 'حسب التوقيت المحلي لمدينة ${location.cityName}',
          notificationDetails: NotificationDetails(android: androidDetails),
          payload: jsonEncode({
            'ar': entry.name.nameAr,
            'en': entry.name.nameEn,
            'city': location.cityName,
            'image': _resolveAthanImage(entry.name),
          }),
        );

        service.invoke('open_athan', {
          'prayer': entry.name.nameAr,
          'prayerEn': entry.name.nameEn,
          'city': location.cityName,
          'image': _resolveAthanImage(entry.name),
        });

        await prefs.setBool('athan_is_playing', true);
        await prefs.setString('athan_prayer_ar', entry.name.nameAr);
        await prefs.setString('athan_prayer_en', entry.name.nameEn);
        await prefs.setString('athan_city', location.cityName);
        await prefs.setString('athan_image', _resolveAthanImage(entry.name));
        
        break;
      }
    }
  } catch (e, st) {
    developer.log('[BackgroundService] Trigger Error: $e\n$st');
  }
}

String _resolveAthanSound(Prayer prayer, SettingsModel settings) {
  if (settings.isUnifiedAthan) {
    return prayer == Prayer.fajr ? 'assets/audio/fajr_madinah.mp3' : settings.selectedAthanSound;
  }
  switch (prayer) {
    case Prayer.fajr: return settings.selectedFajrSound;
    case Prayer.dhuhr: return settings.selectedDhuhrSound;
    case Prayer.asr: return settings.selectedAsrSound;
    case Prayer.maghrib: return settings.selectedMaghribSound;
    case Prayer.isha: return settings.selectedIshaSound;
    default: return settings.selectedAthanSound;
  }
}

String _resolveAthanImage(Prayer prayer) {
  switch (prayer) {
    case Prayer.fajr: return 'assets/images/header_fajr.png';
    case Prayer.dhuhr:
    case Prayer.asr: return 'assets/images/header_dhuhr.png';
    case Prayer.maghrib: return 'assets/images/header_maghrib.png';
    case Prayer.isha: return 'assets/images/header_isha.png';
    default: return 'assets/images/header_fajr.png';
  }
}

Future<void> _updateWidgetCountdown(ServiceInstance service) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final settingsRaw = prefs.getString('settings');
    if (settingsRaw == null) return;
    final settings = SettingsModel.fromJson(jsonDecode(settingsRaw));
    final locationRaw = prefs.getString('last_location');
    if (locationRaw == null) return;
    final location = LocationModel.fromJson(jsonDecode(locationRaw));
    final times = PrayerTimesService().calculate(location, settings.calculationMethod);
    final nextPrayer = times.nextPrayer;
    if (nextPrayer != null) {
      await HomeWidget.saveWidgetData<String>('next_prayer', '${nextPrayer.name.nameAr} ${_formatTime12(nextPrayer.time)}');
      await HomeWidget.updateWidget(name: 'PrayerWidgetProvider', androidName: 'PrayerWidgetProvider');
    }
  } catch (_) {}
}

Future<void> _updateForegroundNotification(ServiceInstance service) async {
  if (service is! AndroidServiceInstance) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    final settingsRaw = prefs.getString('settings');
    if (settingsRaw == null) return;
    final settings = SettingsModel.fromJson(jsonDecode(settingsRaw));
    final locationRaw = prefs.getString('last_location');
    if (locationRaw == null) return;
    final location = LocationModel.fromJson(jsonDecode(locationRaw));
    final times = PrayerTimesService().calculate(location, settings.calculationMethod);
    final nextPrayer = times.nextPrayer;
    if (nextPrayer != null) {
      service.setForegroundNotificationInfo(
        title: 'زاد',
        content: 'الصلاة القادمة: ${nextPrayer.name.nameAr} - ${_formatTime12(nextPrayer.time)}',
      );
    }
  } catch (_) {}
}

Future<void> _checkIslamicEvents(FlutterLocalNotificationsPlugin notifications) async {
  try {
    final now = DateTime.now();
    if (now.hour != 8 || now.minute != 0) return;
    final hijri = HijriCalendar.now();
    final todaysEvents = IslamicEvent.allEvents.where((e) => e.month == hijri.hMonth && e.day == hijri.hDay).toList();
    for (int i = 0; i < todaysEvents.length; i++) {
        await notifications.show(
          id: 9100 + i,
          title: '🌙 مناسبة إسلامية',
          body: todaysEvents[i].name,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails('islamic_events', 'المناسبات الإسلامية', importance: Importance.high),
          ),
        );
    }
  } catch (_) {}
}

Future<void> _checkEidTakbeer(ServiceInstance service, AthanAudioService athanAudio, FlutterLocalNotificationsPlugin notifications) async { }

String _formatTime12(DateTime time) {
  final hr = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
  final mn = time.minute.toString().padLeft(2, '0');
  return '$hr:$mn';
}
