import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../audio/services/audio_handler.dart';

class AthanManager {
  static Future<void> initialize() async {
    await AndroidAlarmManager.initialize();
  }

  /// Schedule alarm for Athan.
  /// Provide a unique alarmId for each prayer (e.g. 0 for Fajr, 1 for Dhuhr, etc.)
  static Future<void> scheduleNextAthan({
      required int alarmId,
      required DateTime time,
      required bool isFajr,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Store whether this specific alarm is Fajr or not for the isolate to check later
    await prefs.setBool('isFajr_$alarmId', isFajr);

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
    
    // Schedule the exact alarm
    await AndroidAlarmManager.oneShotAt(
      time,
      alarmId,
      athanAlarmCallback,
      exact: true,
      wakeup: true,
      alarmClock: true,     // Critical to ensure Android 14+ wakes up accurately
      allowWhileIdle: true, 
      rescheduleOnReboot: true,
    );
  }
}

@pragma('vm:entry-point')
Future<void> athanAlarmCallback(int alarmId) async {
    // 1. Initialize plugin channels so we can communicate with Native APIs (Shared Prefs, Audio Service)
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
      await audioHandler?.customAction('playAthan', {'path': pathToPlay});
    } else {
      debugPrint("Athan file not found at path: $pathToPlay");
    }
}
