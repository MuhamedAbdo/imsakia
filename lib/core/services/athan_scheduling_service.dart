import 'package:flutter/services.dart';
import 'dart:developer' as developer;

class AthanSchedulingService {
  static const MethodChannel _athanChannel = MethodChannel('imsakia/athan_control');

  /// Request exact alarm permission (Android 12+)
  /// Keeping this as it is still relevant for the system to function correctly.
  static Future<void> ensureExactAlarmPermission() async {
    try {
      final bool granted = await _athanChannel.invokeMethod('ensureExactAlarmPermission');
      developer.log('[SCHEDULER] Exact alarm permission status: $granted');
    } catch (e) {
      developer.log('[SCHEDULER] Failed to check/request exact alarm permission: $e');
    }
  }

  /// DISCONTINUED: Scheduling is now handled by the Background Service Isolate.
  /// This method is kept as a skeleton to prevent compilation errors in other files.
  static Future<void> scheduleFutureAthans({int daysToSchedule = 7, bool force = false}) async {
    developer.log('[SCHEDULER] scheduleFutureAthans() called - SKIP (Handled by Background Isolate)');
    return;
  }

  /// DISCONTINUED: Service handled by Background Isolate.
  static Future<void> ensureAthanScheduled() async {
     developer.log('[SCHEDULER] ensureAthanScheduled() called - SKIP');
     return;
  }

  /// DISCONTINUED: Service handled by Background Isolate.
  static Future<void> forceRescheduleAll() async {
     developer.log('[SCHEDULER] forceRescheduleAll() called - SKIP');
     return;
  }

  /// DISCONTINUED: Alarms are no longer scheduled via Native AlarmManager.
  static Future<void> cancelAllAthans() async {
    developer.log('[SCHEDULER] cancelAllAthans() called - SKIP');
    return;
  }
}
