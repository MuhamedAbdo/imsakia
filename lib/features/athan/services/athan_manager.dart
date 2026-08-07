import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../services/prayer_times_service.dart';

/// The notification ID for the athan full-screen overlay notification.
const int kAthanNotificationId = 888;

/// The channel ID for the athan notification.
const String kAthanChannelId = 'athan_full_screen';

class AthanManager {
  /// No-op: AndroidAlarmManager removed.
  /// Scheduling is fully handled by native AlarmManager.setAlarmClock via MethodChannel.
  static Future<void> initialize() async {}

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
    } else if (prayerName.contains("شروق") ||
        prayerName.toLowerCase().contains("sunrise")) {
      prayerKey = "sunrise";
    }

    await prefs.setString('prayerKey_$alarmId', prayerKey);

    final isEnabled = prefs.getBool('athan_enabled') ?? true;
    final isPrayerEnabled = prefs.getBool('${prayerKey}_athan_enabled') ?? true;

    // 🔥 Sunrise is ALWAYS silent
    bool isSilent = !isEnabled || !isPrayerEnabled || prayerKey == "sunrise";

    if (isTest) {
      isSilent = false;
    }

    try {
      const channel = MethodChannel('imsakia/notifications');
      // ✅ SINGLE alarm source: Only native AlarmManager.setAlarmClock is used.
      // The dual AndroidAlarmManager.oneShotAt() has been removed to prevent
      // random delayed re-scheduling from the Dart isolate (root cause of timing jitter).
      await channel.invokeMethod('scheduleExactAthan', {
        'timeInMillis': time.millisecondsSinceEpoch,
        'id': alarmId,
        'prayerName': prayerName,
        'prayerKey': prayerKey,
        'isSilent': isSilent,
      });
    } catch (e) {
      debugPrint(
        "AthanManager: Failed to schedule $prayerName (ID: $alarmId): $e",
      );
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

  /// Schedules a test athan alert with a configurable delay using Sovereign Native Logic.
  static Future<void> scheduleTestAthan({
    Duration delay = const Duration(seconds: 10),
  }) async {
    debugPrint(
      "!!! HARDENED: Triggering simplified Athan Test with $delay !!!",
    );
    final testTime = DateTime.now().add(delay);
    const alarmId = 999;

    try {
      const channel = MethodChannel('imsakia/notifications');
      await channel.invokeMethod('scheduleExactAthan', {
        'timeInMillis': testTime.millisecondsSinceEpoch,
        'id': alarmId,
        'prayerName': "اختبار الأذان",
        'prayerKey': "dhuhr",
        'isSilent': false,
      });
      debugPrint("!!! HARDENED: Test Athan scheduled for $testTime !!!");
    } catch (e) {
      debugPrint("!!! HARDENED ERROR: Failed to schedule test: $e !!!");
    }
  }

  /// ✅ DIAGNOSTIC: Fires the AthanReceiver DIRECTLY via sendBroadcast()
  static Future<String> testDirectReceiver() async {
    try {
      const channel = MethodChannel('imsakia/notifications');
      final result = await channel.invokeMethod<String>('testDirectBroadcast');
      return result ?? "تم الإرسال المباشر";
    } catch (e) {
      return "فشل الاختبار المباشر: $e";
    }
  }
}
