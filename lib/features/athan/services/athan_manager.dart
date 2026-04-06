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

  // ✅ جلب الأذان المعلق من الـ Native SharedPreferences
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

  // ✅ تنظيف الأذان المعلق بعد الاستهلاك
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
      await channel.invokeMethod('forceClearSystemAlarms'); // 🔥 مسح قسري للمنبهات المتراكمة
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

  /// Cancels the currently displayed athan notification.
  static Future<void> cancelAthanNotification() async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.cancel(id: kAthanNotificationId);
  }

  /// Schedule alarm for Athan.
  /// Provide a unique alarmId for each prayer (e.g. 0 for Fajr, 1 for Dhuhr, etc.)
  static Future<void> scheduleNextAthan({
      required int alarmId,
      required DateTime time,
      required bool isFajr,
      required String prayerName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Store whether this specific alarm is Fajr or not for the isolate to check later
    await prefs.setBool('isFajr_$alarmId', isFajr);
    await prefs.setString('prayerName_$alarmId', prayerName);

    final isEnabled = prefs.getBool('athan_enabled') ?? true;
    if (!isEnabled) {
      return; // Do not schedule if master toggle is off.
    }
    
    // Check Exact Alarm Permission natively
    if (Platform.isAndroid) {
      final status = await Permission.scheduleExactAlarm.status;
      if (status.isDenied || status.isRestricted) {
        debugPrint("Cannot schedule exact alarm: Permission denied.");
        return; // Abort scheduling if we don't have permission
      }
    }
    
    try {
      const channel = MethodChannel('imsakia/notifications');
      await channel.invokeMethod('scheduleExactAthan', {
        'timeInMillis': time.millisecondsSinceEpoch,
        'id': alarmId,
        'prayerName': prayerName,
      });
      debugPrint("Native Athan '$prayerName' scheduled for $time (ID=$alarmId)");
    } catch (e) {
      debugPrint("Native Alarm Scheduling Failed: $e");
    }
  }
}

@pragma('vm:entry-point')
Future<void> athanAlarmCallback(int alarmId) async {
    // 1. Initialize plugin channels so we can communicate with Native APIs
    DartPluginRegistrant.ensureInitialized();
    
    // 2. Load SharedPreferences and ensure latest data is reloaded in this background isolate
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    
    final isEnabled = prefs.getBool('athan_enabled') ?? true;
    if (!isEnabled) {
      return; // Abort if user disabled Athan recently
    }

    // 3. Determine if this specific alarm is for Fajr
    final isFajr = prefs.getBool('isFajr_$alarmId') ?? false;
    final prayerName = prefs.getString('prayerName_$alarmId') ?? "الصلاة";
    
    // 4. Retrieve cached local audio paths
    final normalPath = prefs.getString('localNormalAthanPath');
    final fajrPath = prefs.getString('localFajrAthanPath');
    
    final String? pathToPlay = isFajr ? fajrPath : normalPath;
    
    // 5. Initialize foreground audio service and trigger playback
    if (pathToPlay != null && File(pathToPlay).existsSync()) {
      if (audioHandler == null) {
        // Init creates the persistent foreground notification
        await initAudioService();
      }
      
      // Request playback via our Custom Action in AudioHandler
      await audioHandler?.customAction('playAthan', {'path': pathToPlay, 'prayerName': prayerName});
      
      // Show full screen intent notification above the lock screen
      await showFullScreenAthan(prayerName, isFajr);
    } else {
      debugPrint("Athan file not found at path: $pathToPlay");
      // Still show the notification so the user knows athan time arrived,
      // even if audio file is missing (edge case after reinstall).
      await showFullScreenAthan(prayerName, isFajr);
    }
}

/// Shows a full-screen-intent notification that appears above the lock screen.
/// Includes a "Stop Athan" action button so the user can stop it without opening the app.
Future<void> showFullScreenAthan(String prayerName, bool isFajr) async {
  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
  
  // Initialize with default settings (isolate context)
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );


  // === Stop Action Button ===
  // This button appears directly on the notification / lock screen.
  // Tapping it fires the background handler in main.dart without opening the app.
  const AndroidNotificationAction stopAction = AndroidNotificationAction(
    'stop_athan_action',       // action ID
    'إيقاف الأذان',            // label shown on lock screen button
    showsUserInterface: false, // Do NOT open the app UI
    cancelNotification: true,  // Auto-cancel notification when action is tapped
  );

  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    kAthanChannelId,
    'إشعار الأذان',
    channelDescription: 'يُعرض عند حلول وقت الصلاة',
    importance: Importance.max,
    priority: Priority.max,
    // Full-screen intent kicks in when phone is locked
    fullScreenIntent: true,
    visibility: NotificationVisibility.public,
    category: AndroidNotificationCategory.alarm,
    // Keep notification alive so user is forced to tap Stop
    ongoing: true,
    autoCancel: false,
    // Auto-dismiss after 30 minutes (prevents stuck notification if app is killed)
    timeoutAfter: 30 * 60 * 1000,
    showWhen: false,
    // The Stop action button
    actions: const [stopAction],
    // Large icon
    largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
  );
  
  final NotificationDetails details = NotificationDetails(android: androidDetails);

  await plugin.show(
    id: kAthanNotificationId,
    title: 'حان وقت الصلاة 🕌',
    body: 'أذان $prayerName',
    notificationDetails: details,
    // Payload used when the notification BODY is tapped (opens overlay in main app)
    payload: 'athan_overlay|$prayerName|$isFajr',
  );
}
