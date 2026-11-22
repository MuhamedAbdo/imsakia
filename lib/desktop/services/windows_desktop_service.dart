import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'windows_athan_service.dart';

/// Service managing native Windows desktop lifecycle, System Tray interactions,
/// window visibility, and Windows user auto-startup registration.
class WindowsDesktopService {
  WindowsDesktopService._();
  static final WindowsDesktopService instance = WindowsDesktopService._();

  static const MethodChannel _channel = MethodChannel('imsakia/desktop');
  static const String _prefAutoStart = 'windows_auto_start_enabled';

  bool _isInitialized = false;
  final ValueNotifier<bool> isAutoStartEnabledNotifier = ValueNotifier<bool>(false);

  Future<void> initialize() async {
    if (!Platform.isWindows || _isInitialized) return;
    _isInitialized = true;

    _channel.setMethodCallHandler(_handleNativeCall);

    try {
      final prefs = await SharedPreferences.getInstance();
      final bool alreadyConfigured =
          prefs.getBool('windows_auto_start_configured') ?? false;

      if (!alreadyConfigured) {
        // Auto-enable with Windows by default on first launch / setup
        await setAutoStartEnabled(true);
        await prefs.setBool('windows_auto_start_configured', true);
        debugPrint(
          '[WindowsDesktopService] Auto-start enabled automatically by default',
        );
      } else {
        // Sync startup state from native Windows registry
        final bool registryState = await isAutoStartEnabled();
        isAutoStartEnabledNotifier.value = registryState;
        await prefs.setBool(_prefAutoStart, registryState);
      }
    } catch (e) {
      debugPrint('[WindowsDesktopService] Error configuring auto-start: $e');
    }
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onExitRequested':
        debugPrint('[WindowsDesktopService] onExitRequested received from tray menu');
        await _handleExitRequested();
        break;

      case 'onWindowShown':
        debugPrint('[WindowsDesktopService] onWindowShown received from tray icon');
        break;

      case 'onSystemResumeOrTimeChange':
        debugPrint('[WindowsDesktopService] onSystemResumeOrTimeChange received from OS');
        WindowsAthanService.instance.onSystemResumeOrTimeChange();
        break;

      default:
        debugPrint('[WindowsDesktopService] Unhandled native call: ${call.method}');
        break;
    }
  }

  /// Handles clean application exit when user selects "Exit Zaad" from tray context menu.
  Future<void> _handleExitRequested() async {
    try {
      // 1. Cancel pending application-owned scheduled tasks (tests, timers, audio)
      WindowsAthanService.instance.dispose();
    } catch (e) {
      debugPrint('[WindowsDesktopService] Error during exit cleanup: $e');
    } finally {
      // 2. Tell native runner to release tray resources and terminate cleanly
      try {
        await exitApp();
      } catch (e) {
        debugPrint('[WindowsDesktopService] Error calling exitApp: $e');
        exit(0);
      }
    }
  }

  /// Checks if Zaad is registered in Windows CurrentUser Run registry key.
  Future<bool> isAutoStartEnabled() async {
    if (!Platform.isWindows) return false;
    try {
      final bool? result = await _channel.invokeMethod<bool>('isAutoStartEnabled');
      final enabled = result ?? false;
      isAutoStartEnabledNotifier.value = enabled;
      return enabled;
    } on MissingPluginException {
      debugPrint('[WindowsDesktopService] Native runner channel not ready yet (app needs full restart to load updated C++ binary).');
      return false;
    } catch (e) {
      debugPrint('[WindowsDesktopService] isAutoStartEnabled failed: $e');
      return false;
    }
  }

  /// Registers or unregisters Zaad in Windows CurrentUser Run registry key.
  Future<bool> setAutoStartEnabled(bool enable) async {
    if (!Platform.isWindows) return false;
    try {
      final bool? success = await _channel.invokeMethod<bool>(
        'setAutoStartEnabled',
        {'enabled': enable},
      );
      final bool result = success ?? false;
      if (result) {
        isAutoStartEnabledNotifier.value = enable;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefAutoStart, enable);
      }
      return result;
    } on MissingPluginException {
      debugPrint('[WindowsDesktopService] Native runner channel not ready yet (app needs full restart to load updated C++ binary).');
      return false;
    } catch (e) {
      debugPrint('[WindowsDesktopService] setAutoStartEnabled failed: $e');
      return false;
    }
  }

  /// Shows and restores the main application window.
  Future<void> showWindow() async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod('showWindow');
    } catch (e) {
      debugPrint('[WindowsDesktopService] showWindow failed: $e');
    }
  }

  /// Hides the main application window into the System Tray.
  Future<void> hideWindow() async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod('hideWindow');
    } catch (e) {
      debugPrint('[WindowsDesktopService] hideWindow failed: $e');
    }
  }

  /// Terminates the application cleanly.
  Future<void> exitApp() async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod('exitApp');
    } catch (_) {
      exit(0);
    }
  }
}
