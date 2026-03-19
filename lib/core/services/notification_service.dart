import 'dart:io';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/prayer_times_model.dart';

class NotificationService {
  static const _channelId = 'adhan_prayer_times';
  static const _channelName = 'زاد - مواقيت الصلاة';
  static const _athanChannelId = 'athan_channel_v2';
  static const _athanChannelName = 'زاد - الأذان';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // v21 API: initialize uses named 'settings' parameter
    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _notificationTapBackground,
    );

    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }
  }

  Future<void> _createNotificationChannels() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Prayer time reminders',
        importance: Importance.high,
      ),
    );

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _athanChannelId,
        _athanChannelName,
        description: 'Athan alarm at prayer times',
        importance: Importance.max,
        playSound: false,
        enableVibration: true,
      ),
    );
  }

  Future<void> schedulePrayerNotification({
    required int id,
    required PrayerEntry prayer,
    required String title,
    required String body,
    bool isAthan = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      isAthan ? _athanChannelId : _channelId,
      isAthan ? _athanChannelName : _channelName,
      importance: isAthan ? Importance.max : Importance.high,
      priority: isAthan ? Priority.max : Priority.high,
      fullScreenIntent: isAthan,
      category: isAthan ? AndroidNotificationCategory.alarm : null,
      ongoing: isAthan,
      icon: '@drawable/ic_notification',
      actions: isAthan
          ? const [
              AndroidNotificationAction(
                'stop_audio',
                'إيقاف الأذان',
                cancelNotification: true,
              ),
            ]
          : null,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );
    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    // v21 API: zonedSchedule uses all named parameters
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _toTZDateTime(prayer.time),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> showAthanNotification({
    required String prayerNameAr,
    required String prayerNameEn,
    required int id,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _athanChannelId,
      _athanChannelName,
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      ongoing: true,
      icon: '@drawable/ic_notification',
      actions: [
        AndroidNotificationAction(
          'stop_audio',
          'إيقاف الأذان',
          cancelNotification: true,
        ),
      ],
    );
    const details = NotificationDetails(android: androidDetails);

    // v21 API: show uses all named parameters
    await _plugin.show(
      id: id,
      title: 'حان وقت $prayerNameAr',
      body: 'اضغط لإيقاف الأذان',
      notificationDetails: details,
    );

    // Auto-dismiss after 2 minutes (120 seconds)
    // ID 888/999 are usually persistent, ensure we don't accidentally kill them if this is called for them.
    // However, this method is specifically for Adhan notifications.
    if (id != 888 && id != 999) {
      Timer(const Duration(minutes: 2), () async {
        try {
          await _plugin.cancel(id: id);
          developer.log('[NotificationService] Auto-dismissed Adhan notification $id after 2 minutes.');
        } catch (e) {
          // ignore if already cancelled
        }
      });
    }
  }

  Future<void> cancelAll() async => _plugin.cancelAll();

  // v21 API: cancel uses named 'id' parameter
  Future<void> cancel(int id) async => _plugin.cancel(id: id);

  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    }
    return true;
  }

  tz.TZDateTime _toTZDateTime(DateTime dt) {
    final local = tz.local;
    return tz.TZDateTime(
        local, dt.year, dt.month, dt.day, dt.hour, dt.minute);
  }

  void _onNotificationResponse(NotificationResponse response) {
    // Handled by background service via 'stop_athan' action
  }
}

@pragma('vm:entry-point')
void _notificationTapBackground(NotificationResponse response) {
  // Signal background service to stop Athan
}
