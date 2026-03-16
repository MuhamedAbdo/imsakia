import 'dart:developer' as developer;

/// BackgroundService stub - flutter_background_service has been removed
/// due to conflicts with the main isolate.
class BackgroundService {
  static const _foregroundNotificationId = 9001;
  static const _channelId = 'adhan_background';
  static const _channelName = 'زاد - خدمات الخلفية';

  /// Initialize background service (disabled)
  static Future<void> initialize() async {
    developer.log(
      '[BackgroundService] Background service disabled (flutter_background_service removed)',
      name: 'BackgroundService',
    );
  }

  /// Start background service (disabled)
  static Future<void> start() async {
    developer.log(
      '[BackgroundService] Background service start disabled',
      name: 'BackgroundService',
    );
  }

  /// Stop background service (disabled)
  static Future<void> stop() async {
    developer.log(
      '[BackgroundService] Background service stop disabled',
      name: 'BackgroundService',
    );
  }

  /// Send stop audio command (disabled)
  static void sendStopAudio() {
    developer.log(
      '[BackgroundService] Send stop audio command (disabled)',
      name: 'BackgroundService',
    );
  }

  /// Deprecated - use sendStopAudio instead
  @Deprecated('Use sendStopAudio() instead')
  static void sendStopAthan() => sendStopAudio();
}
