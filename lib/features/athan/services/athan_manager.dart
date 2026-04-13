import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../services/prayer_times_service.dart';
import '../../audio/services/audio_handler.dart';

/// The notification ID for the athan full-screen overlay notification.
const int kAthanNotificationId = 888;

/// The channel ID for the athan notification.
const String kAthanChannelId = 'athan_full_screen';

class AthanManager {
  static Future<void> initialize() async {
    await AndroidAlarmManager.initialize();
  }

  static Future<void> cancelAthan(int alarmId) async {
    try {
      const channel = MethodChannel('imsakia/notifications');
      await channel.invokeMethod('cancelAthan', {'id': alarmId});
    } catch (_) {}
  }

  static Future<void> stopAthan() async {
    try {
      const channel = MethodChannel('imsakia/notifications');
      await channel.invokeMethod('stopAthan');
      await cancelAthanNotification();

      // ✅ Refresh widget data immediately
      await PrayerTimesService.instance.updateWidgetData();
    } catch (_) {}
  }

  static Future<String?> getPendingAthan() async {
    try {
      const channel = MethodChannel('imsakia/notifications');
      final result = await channel.invokeMethod<String>('getPendingAthan');
      return result;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearPendingAthan() async {
    try {
      const channel = MethodChannel('imsakia/notifications');
      await channel.invokeMethod('clearPendingAthan');
    } catch (_) {}
  }

  static Future<void> cancelAllAlarms() async {
    try {
      const channel = MethodChannel('imsakia/notifications');
      await channel.invokeMethod('clearAllAlarms');
      await channel.invokeMethod('forceClearSystemAlarms');
    } catch (_) {}
  }

  static Future<void> forceClearSystemAlarms() async {
    try {
      const channel = MethodChannel('imsakia/notifications');
      await channel.invokeMethod('forceClearSystemAlarms');
    } catch (_) {}
  }

  static Future<void> cancelAthanNotification() async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.cancel(id: 888);

      // ✅ Refresh widget data
      await PrayerTimesService.instance.updateWidgetData();
    } catch (_) {}
  }

  static Future<void> scheduleNextAthan({
    required int alarmId,
    required DateTime time,
    required bool isFajr,
    required String prayerName,
    bool isTest = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('isFajr_$alarmId', isFajr);
    await prefs.setString('prayerName_$alarmId', prayerName);

    String prayerKey = "dhuhr";
    if (isFajr) {
      prayerKey = "fajr";
    } else if (prayerName.contains("عصر")) {
      prayerKey = "asr";
    } else if (prayerName.contains("مغرب")) {
      prayerKey = "maghrib";
    } else if (prayerName.contains("عشاء")) {
      prayerKey = "isha";
    }

    await prefs.setString('prayerKey_$alarmId', prayerKey);

    final isEnabled = prefs.getBool('athan_enabled') ?? true;
    bool isSilent = !isEnabled;

    if (isTest) {
      isSilent = false;
    }

    try {
      const channel = MethodChannel('imsakia/notifications');
      await channel.invokeMethod('scheduleExactAthan', {
        'timeInMillis': time.millisecondsSinceEpoch,
        'id': alarmId,
        'prayerName': prayerName,
        'prayerKey': prayerKey,
        'isSilent': isSilent,
      });
    } catch (e) {
      debugPrint("AthanManager: Failed to schedule $prayerName (ID: $alarmId): $e");
    }
  }

  static Future<void> performSmartExit() async {
    try {
      const channel = MethodChannel('imsakia/notifications');
      await channel.invokeMethod('performSmartExit');
    } catch (_) {}
  }

  static Future<void> forceExit() async {
    try {
      const channel = MethodChannel('imsakia/notifications');
      await channel.invokeMethod('forceExit');
    } catch (_) {}
  }

  static Future<void> finalizeAthanSession() async {
    try {
      const channel = MethodChannel('imsakia/notifications');
      await channel.invokeMethod('finalizeAthanSession');
    } catch (_) {}
  }

  static Future<bool> getShouldExitFlag() async {
    try {
      const channel = MethodChannel('imsakia/notifications');
      final result = await channel.invokeMethod<bool>('getShouldExitFlag');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> clearShouldExitFlag() async {
    try {
      const channel = MethodChannel('imsakia/notifications');
      await channel.invokeMethod('clearShouldExitFlag');
    } catch (_) {}
  }

  /// Schedules a test athan alert with a configurable delay.
  static Future<void> scheduleTestAthan({Duration delay = const Duration(minutes: 5)}) async {
    await AndroidAlarmManager.oneShot(
      delay,
      999, // Unique ID for test
      athanAlarmCallback,
      exact: true,
      wakeup: true,
      allowWhileIdle: true,
    );
  }
}

@pragma('vm:entry-point')
Future<void> athanAlarmCallback(int alarmId) async {
  WidgetsFlutterBinding.ensureInitialized(); // ✅ CRITICAL: Must be first - initializes plugin channels
  DartPluginRegistrant.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();

  final isEnabled = prefs.getBool('athan_enabled') ?? true;
  if (!isEnabled) return;

  final isFajr = prefs.getBool('isFajr_$alarmId') ?? false;
  final prayerName = prefs.getString('prayerName_$alarmId') ?? "الصلاة";
  final prayerKey =
      prefs.getString('prayerKey_$alarmId') ?? (isFajr ? "fajr" : "dhuhr");
  final pathToPlay =
      prefs.getString('athan_path_$prayerKey') ??
      "assets/audio/athan_mishari.mp3";

  if (audioHandler == null) {
    await initAudioService();
  }

  await audioHandler?.customAction('playAthan', {
    'path': pathToPlay,
    'prayerName': prayerName,
    if (alarmId == 999) 'activeTestKey': 'test_athan',
  });
  await showFullScreenAthan(prayerName, isFajr);
}

Future<void> showFullScreenAthan(String prayerName, bool isFajr) async {
  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  const AndroidNotificationAction stopAction = AndroidNotificationAction(
    'stop_athan_action',
    'إيقاف الأذان',
    showsUserInterface: false,
    cancelNotification: true,
  );

  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    kAthanChannelId,
    'إشعار الأذان',
    channelDescription: 'يُعرض عند حلول وقت الصلاة',
    importance: Importance.max,
    priority: Priority.max,
    fullScreenIntent: true,
    visibility: NotificationVisibility.public,
    category: AndroidNotificationCategory.alarm,
    ongoing: true,
    autoCancel: false,
    timeoutAfter: 30 * 60 * 1000,
    showWhen: false,
    actions: const [stopAction],
    largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
  );

  await plugin.show(
    id: kAthanNotificationId,
    title: 'حان وقت الصلاة 🕌',
    body: 'أذان $prayerName',
    notificationDetails: NotificationDetails(android: androidDetails),
    payload: 'athan_overlay|$prayerName|$isFajr',
  );
}
