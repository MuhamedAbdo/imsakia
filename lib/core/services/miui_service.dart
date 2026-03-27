import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class MiuiService {
  static const _athanChannel = MethodChannel('imsakia/athan_control');
  static const _setupFlagKey = 'miui_guided_setup_completed';

  static Future<bool> isMiui() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _athanChannel.invokeMethod<bool>('isMiui') ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> isSetupCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_setupFlagKey) ?? false;
  }

  static Future<void> markSetupCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupFlagKey, true);
  }

  static Future<void> openAutostartSettings() async {
    try {
      await _athanChannel.invokeMethod('openAutostartSettings');
    } catch (e) {
      // Fallback handled natively (App Info)
    }
  }

  static Future<void> openOverlaySettings() async {
    try {
      await _athanChannel.invokeMethod('openOverlaySettings');
    } catch (e) {
      // Fallback
    }
  }

  static Future<void> openAppInfoSettings() async {
    try {
      await const MethodChannel('imsakia/notifications').invokeMethod('openNotificationSettings');
    } catch (e) {
      // Fallback
    }
  }

  static Future<void> openBatteryOptimizationSettings() async {
    try {
      await const MethodChannel('imsakia/notifications').invokeMethod('openBatteryOptimizationSettings');
    } catch (e) {
      // Fallback
    }
  }
}
