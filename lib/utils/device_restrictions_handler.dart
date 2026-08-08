import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceRestrictionsHandler {
  static const String _oemDialogShownKey = 'oem_dialog_shown';

  /// يتحقق مما إذا كان الهاتف من شاومي أو العلامات التجارية التابعة لها
  static Future<bool> isXiaomiDevice() async {
    if (!Platform.isAndroid) return false;

    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      String manufacturer = androidInfo.manufacturer.toLowerCase();
      return manufacturer == 'xiaomi' ||
          manufacturer == 'redmi' ||
          manufacturer == 'poco';
    } catch (e) {
      return false;
    }
  }

  /// يفتح صفحة التشغيل التلقائي (AutoStart) الخاصة بشاومي
  static Future<void> openXiaomiAutoStartSettings() async {
    if (!Platform.isAndroid) return;

    try {
      final intent = AndroidIntent(
        action: 'miui.intent.action.APP_PERM_EDITOR',
        package: 'com.miui.securitycenter',
        componentName:
            'com.miui.permcenter.autostart.AutoStartManagementActivity',
      );
      await intent.launch();
    } catch (e) {
      // كمسار بديل في حال لم تعمل الواجهة الأساسية
      try {
        final intentBackup = AndroidIntent(
          action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
          data: 'package:com.muhamed.imsakia',
        );
        await intentBackup.launch();
      } catch (e2) {
        debugPrint('Failed to open backup intent: $e2');
      }
    }
  }

  /// يطلب إلغاء قيود البطارية (Battery Optimization)
  static Future<void> requestDisableBatteryOptimizations() async {
    if (!Platform.isAndroid) return;

    var status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isDenied || status.isRestricted) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  /// للتحقق مما إذا كان التطبيق مستثنى بالفعل من قيود البطارية
  static Future<bool> isBatteryOptimizationDisabled() async {
    if (!Platform.isAndroid) return true;
    return await Permission.ignoreBatteryOptimizations.isGranted;
  }

  /// يتحقق مما إذا تم عرض مربع الحوار سابقاً
  static Future<bool> hasShownOemDialog() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_oemDialogShownKey) ?? false;
  }

  /// يقوم بحفظ حالة عرض مربع الحوار
  static Future<void> setHasShownOemDialog(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_oemDialogShownKey, value);
  }
}
