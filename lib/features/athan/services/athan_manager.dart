import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
      debugPrint("Native Alarm Cancelled: ID=$alarmId");
    } catch (e) {
      debugPrint("Failed to cancel alarm: $e");
    }
  }

  static Future<void> stopAthan() async {
    try {
      const channel = MethodChannel('imsakia/notifications');
      await channel.invokeMethod('stopAthan');
      await cancelAthanNotification();
    } catch (e) {
      debugPrint("Failed to stop athan: $e");
    }
  }

  static Future<String?> getPendingAthan() async {
    try {
      const channel = MethodChannel('imsakia/notifications');
      final result = await channel.invokeMethod<String>('getPendingAthan');
      return result;
    } catch (e) {
      debugPrint('❌ Error getting pending athan: $e');
      return null;
    }
  }

  static Future<void> clearPendingAthan() async {
    try {
      const channel = MethodChannel('imsakia/notifications');
      await channel.invokeMethod('clearPendingAthan');
    } catch (e) {
      debugPrint('❌ Error clearing pending athan: $e');
    }
  }

  static Future<void> cancelAllAlarms() async {
    try {
      const channel = MethodChannel('imsakia/notifications');
      await channel.invokeMethod('clearAllAlarms');
      await channel.invokeMethod('forceClearSystemAlarms'); 
      debugPrint("All Native Alarms Cleared (Basic and Force)");
    } catch (e) {
      debugPrint("Failed to clear all alarms: $e");
    }
  }

  static Future<void> forceClearSystemAlarms() async {
    try {
      const channel = MethodChannel('imsakia/notifications');
      await channel.invokeMethod('forceClearSystemAlarms');
      debugPrint("Force Clear System Alarms triggered.");
    } catch (e) {
      debugPrint("Failed to force clear alarms: $e");
    }
  }

  static Future<void> cancelAthanNotification() async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.cancel(id: kAthanNotificationId);
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
    final isSilent = !isEnabled;
    
    if (!isEnabled && !isTest) {
      debugPrint("!!! ATHAN MANAGER: Athan is disabled, scheduling for SILENT notification. !!!");
    }
    
    if (Platform.isAndroid) {
      final status = await Permission.scheduleExactAlarm.status;
      if (status.isDenied || status.isRestricted) {
        debugPrint("Cannot schedule exact alarm: Permission denied.");
        return; 
      }
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
      debugPrint("Native Athan '$prayerName' scheduled for $time (ID=$alarmId, Key=$prayerKey, Silent=$isSilent)");
    } catch (e) {
      debugPrint("Native Alarm Scheduling Failed: $e");
    }
  }

  static Future<void> performSmartExit() async {
    try {
      const channel = MethodChannel('imsakia/notifications');
      await channel.invokeMethod('performSmartExit');
      debugPrint("Native Smart Exit triggered.");
    } catch (e) {
      debugPrint("Failed to perform smart exit: $e");
    }
  }

  static Future<void> forceExit() async {
    try {
      const channel = MethodChannel('imsakia/notifications');
      await channel.invokeMethod('forceExit');
      debugPrint("Native Force Exit (Graceful Backgrounding) triggered.");
    } catch (e) {
      debugPrint("Failed to perform force exit: $e");
    }
  }

  static Future<void> finalizeAthanSession() async {
    try {
      const channel = MethodChannel('imsakia/notifications');
      await channel.invokeMethod('finalizeAthanSession');
      debugPrint("!!! ATHAN MANAGER: Native finalizeAthanSession triggered !!!");
    } catch (e) {
      debugPrint("!!! ATHAN MANAGER: Failed to perform finalizeAthanSession: $e");
    }
  }

  static Future<bool> getShouldExitFlag() async {
    try {
      const channel = MethodChannel('imsakia/notifications');
      final result = await channel.invokeMethod<bool>('getShouldExitFlag');
      return result ?? false;
    } catch (e) {
      debugPrint("Failed to get shouldExit flag: $e");
      return false;
    }
  }

  static Future<void> clearShouldExitFlag() async {
    try {
      const channel = MethodChannel('imsakia/notifications');
      await channel.invokeMethod('clearShouldExitFlag');
    } catch (e) {
      debugPrint("Failed to clear shouldExit flag: $e");
    }
  }
}

@pragma('vm:entry-point')
Future<void> athanAlarmCallback(int alarmId) async {
    DartPluginRegistrant.ensureInitialized();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    
    final isEnabled = prefs.getBool('athan_enabled') ?? true;
    if (!isEnabled) return;

    final isFajr = prefs.getBool('isFajr_$alarmId') ?? false;
    final prayerName = prefs.getString('prayerName_$alarmId') ?? "الصلاة";
    final prayerKey = prefs.getString('prayerKey_$alarmId') ?? (isFajr ? "fajr" : "dhuhr");
    final pathToPlay = prefs.getString('athan_path_$prayerKey') ?? "assets/audio/athan_mishari.mp3";
    
    if (audioHandler == null) {
        await initAudioService();
    }
    
    await audioHandler?.customAction('playAthan', {'path': pathToPlay, 'prayerName': prayerName});
    await showFullScreenAthan(prayerName, isFajr);
}

Future<void> showFullScreenAthan(String prayerName, bool isFajr) async {
  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
  
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
  
  final NotificationDetails details = NotificationDetails(android: androidDetails);

  await plugin.show(
    id: kAthanNotificationId,
    title: 'حان وقت الصلاة 🕌',
    body: 'أذان $prayerName',
    notificationDetails: details,
    payload: 'athan_overlay|$prayerName|$isFajr',
  );
}
