import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_intent_plus/android_intent.dart';

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
      return await Permission.scheduleExactAlarm.isGranted;
    }
  }

  // ✅ باقي الدوال الأساسية
  static Future<bool> isNotificationGranted() async => 
      await Permission.notification.isGranted;

  static Future<bool> isBatteryOptimizationGranted() async => 
      Platform.isAndroid 
          ? await Permission.ignoreBatteryOptimizations.isGranted 
          : true;

  static Future<bool> isAutoStartGranted() async => 
      Platform.isAndroid 
          ? await Permission.systemAlertWindow.isGranted 
          : true;

  // ✅ فتح إعدادات البطارية (مستقل عن Provider)
  static Future<void> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return;
    
    try {
      final packageName = await _getPackageName();
      final intent = AndroidIntent(
        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
        data: 'package:$packageName',
      );
      await intent.launch();
    } catch (e) {
      // Fallback to app details
      await openAppSettings();
    }
  }

  // ✅ فتح الإعدادات الشاملة حسب الشركة (مستقل عن Provider)
  static Future<void> openComprehensivePermissions() async {
    if (!Platform.isAndroid) return;
    
    try {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      final manufacturer = deviceInfo.manufacturer.toLowerCase();
      final packageName = await _getPackageName();
      
      AndroidIntent? intent;
      
      if (manufacturer.contains('xiaomi') || manufacturer.contains('poco')) {
        intent = AndroidIntent(
          action: 'miui.intent.action.APP_PERMS_EDITOR',
          package: 'com.miui.securitycenter',
          componentName: 'com.miui.permcenter.permissions.PermissionsEditorActivity',
          arguments: {'extra_pkgname': packageName},
        );
      } else if (manufacturer.contains('oppo') || manufacturer.contains('realme')) {
        intent = AndroidIntent(
          action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
          data: 'package:$packageName',
        );
      } else if (manufacturer.contains('huawei')) {
        intent = AndroidIntent(
          action: 'com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity',
        );
      } else if (manufacturer.contains('vivo')) {
        intent = AndroidIntent(
          action: 'com.vivo.permissionmanager.activity.BgStartUpManagerActivity',
        );
      }
      
      if (intent != null) {
        await intent.launch();
      } else {
        await openAppSettings();
      }
    } catch (e) {
      // Ultimate fallback
      await openAppSettings();
    }
  }

  // ✅ مساعدة: جلب اسم الحزمة
  static Future<String> _getPackageName() async {
    if (Platform.isAndroid) {
      // In a real app, use package_info_plus. For now, we use the known package name.
      return "com.muhamed.imsakia";
    }
    return '';
  }

  static Future<void> openAppSettings() async {
    // 🔥 Fix: use permission_handler's global function
    await openAppSettings(); 
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
      Permission.notification,
      Permission.scheduleExactAlarm,
    ].request();
  }
}
