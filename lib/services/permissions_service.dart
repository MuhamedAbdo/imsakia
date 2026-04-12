import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionsService {
  static Future<Map<String, bool>> checkAllPermissions() async {
    final Map<String, bool> statuses = {};

    // 1. Notifications
    statuses['notifications'] = await Permission.notification.isGranted;

    // 2. Exact Alarms (Android 12+)
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 31) {
        statuses['exact_alarm'] = await Permission.scheduleExactAlarm.isGranted;
      } else {
        statuses['exact_alarm'] = true; // Not required for older versions
      }
    } else {
      statuses['exact_alarm'] = true;
    }

    // 3. Battery Optimization
    if (Platform.isAndroid) {
      statuses['battery_optimization'] = await Permission.ignoreBatteryOptimizations.isGranted;
    } else {
      statuses['battery_optimization'] = true;
    }

    // 4. System Alert Window (Xiaomi/Overlays)
    if (Platform.isAndroid) {
      statuses['system_alert'] = await Permission.systemAlertWindow.isGranted;
    } else {
      statuses['system_alert'] = true;
    }

    return statuses;
  }

  static Future<bool> areCriticalPermissionsGranted() async {
    final perms = await checkAllPermissions();
    // Notifications and Exact Alarms are REQUIRED for logic
    return (perms['notifications'] ?? false) && (perms['exact_alarm'] ?? false);
  }

  static Future<void> requestSystemPermissions() async {
    await [
      Permission.notification,
      Permission.scheduleExactAlarm,
    ].request();
  }
}
