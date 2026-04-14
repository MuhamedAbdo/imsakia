import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as ph;


class PermissionsService {
  static const MethodChannel _channel = MethodChannel('imsakia/notifications');

  // ✅ التحقق الأصلي للمنبهات الدقيقة
  static Future<bool> isExactAlarmGranted() async {
    if (!Platform.isAndroid) return true;
    
    try {
      final result = await _channel.invokeMethod<bool>('isExactAlarmGranted');
      return result ?? false;
    } catch (e) {
      // Fallback to permission_handler
      return await ph.Permission.scheduleExactAlarm.isGranted;
    }
  }

  // ✅ باقي الدوال الأساسية
  static Future<bool> isNotificationGranted() async => 
      await ph.Permission.notification.isGranted;

  static Future<bool> isBatteryOptimizationGranted() async {
    if (!Platform.isAndroid) return true;
    
    try {
      final result = await _channel.invokeMethod<bool>('isBatteryOptimizationGranted');
      return result ?? false;
    } catch (e) {
      // Fallback to permission_handler
      return await ph.Permission.ignoreBatteryOptimizations.isGranted;
    }
  }

  static Future<bool> isAutoStartGranted() async => 
      Platform.isAndroid 
          ? await ph.Permission.systemAlertWindow.isGranted 
          : true;

  // ✅ فتح إعدادات البطارية (مستقل عن Provider)
  // ✅ فتح إعدادات البطارية عبر الـ Native لضمان الاستقرار
  static Future<void> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return;
    
    try {
      await _channel.invokeMethod('openBatteryOptimizationSettings');
    } catch (e) {
      debugPrint("Error opening battery optimization settings: $e");
      // Fallback
      await openAppSettings();
    }
  }

  // ✅ فتح الإعدادات الشاملة (Auto-Start) عبر الـ Native لضمان الاستقرار
  static Future<String> openComprehensivePermissions() async {
    if (!Platform.isAndroid) return "unsupported";
    
    try {
      final String? result = await _channel.invokeMethod<String>('openAutoStartSettings');
      return result ?? "error";
    } catch (e) {
      debugPrint("Error opening auto-start settings: $e");
      return "error";
    }
  }



  static Future<void> openAppSettings() async {
    // 🔥 Fix: use permission_handler's global function
    await ph.openAppSettings(); 
  }

  // ✅ التحقق من جميع الأذونات (دالة مجمعة للواجهات)
  static Future<Map<String, bool>> checkAllPermissions() async {
    final Map<String, bool> statuses = {};
    statuses['notifications'] = await isNotificationGranted();
    statuses['exact_alarm'] = await isExactAlarmGranted();
    statuses['battery_optimization'] = await isBatteryOptimizationGranted();
    statuses['system_alert'] = await isAutoStartGranted();
    return statuses;
  }

  // ✅ التحقق من جميع الأذونات الحرجة
  static Future<bool> areCriticalPermissionsGranted() async {
    return await isNotificationGranted() && await isExactAlarmGranted();
  }

  static Future<void> requestSystemPermissions() async {
    await [
      ph.Permission.notification,
      ph.Permission.scheduleExactAlarm,
    ].request();
  }
}
