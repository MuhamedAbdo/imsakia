import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class PermissionCheckerService {
  static final PermissionCheckerService _instance = PermissionCheckerService._internal();
  factory PermissionCheckerService() => _instance;
  PermissionCheckerService._internal();

  Future<Map<String, dynamic>> checkAllPermissions() async {
    final deviceInfo = DeviceInfoPlugin();
    int sdkInt = 0;
    String version = "";

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      sdkInt = androidInfo.version.sdkInt;
      version = androidInfo.version.release;
    }

    return {
      'androidInfo': {'sdkInt': sdkInt, 'version': version},
      'notifications': {
        'granted': await Permission.notification.isGranted,
        'description': 'مطلوبة لإرسال تنبيهات الأذان.'
      },
      'exactAlarm': {
        'granted': sdkInt >= 31 ? await Permission.scheduleExactAlarm.isGranted : true,
        'description': 'مطلوبة لدقة مواقيت الأذان على أندرويد 12+.'
      },
      'location': {
        'granted': await Permission.location.isGranted,
        'description': 'مطلوبة لتحديد القبلة ومواقيت الصلاة.'
      },
    };
  }

  // FIXED: Added missing methods for PermissionDiagnosticScreen
  Future<void> requestExactAlarmPermission() async {
    if (Platform.isAndroid) {
      await openAppSettings();
    }
  }

  Future<void> requestNotificationPermission() async {
    await Permission.notification.request();
  }

  Future<void> requestLocationPermission() async {
    await Permission.location.request();
  }
}
