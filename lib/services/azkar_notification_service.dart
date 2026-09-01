
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../utils/logger.dart';

class AzkarNotificationService {
  // ─── Singleton ───────────────────────────────────────────────────────────
  static AzkarNotificationService? _instance;
  static AzkarNotificationService get instance =>
      _instance ??= AzkarNotificationService._();
  AzkarNotificationService._();

  // ─── Constants ──────────────────────────────────────────────────────────
  static const int _baseMorningId = 50001; // ID مستقل لأذكار الصباح
  static const int _baseEveningId = 50002; // ID مستقل لأذكار المساء

  // ─── Scheduling Logic ───────────────────────────────────────────────────
  Future<void> scheduleAzkarNotifications(DateTime fajrTime, DateTime asrTime) async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      final now = DateTime.now();

      // أذكار الصباح: بعد الفجر بـ 90 دقيقة
      final morningTime = fajrTime.add(const Duration(minutes: 90));
      // أذكار المساء: بعد العصر بـ 30 دقيقة
      final eveningTime = asrTime.add(const Duration(minutes: 30));

      if (morningTime.isAfter(now)) {
        await _scheduleNotification(
          plugin: plugin,
          id: _baseMorningId,
          title: 'أذكار الصباح ☀️',
          body: 'حان الآن موعد أذكار الصباح، فاذكر الله يذكرك.',
          scheduledDateTime: morningTime,
          channelId: 'azkar_morning_channel',
          channelName: 'أذكار الصباح',
          payload: 'azkar_morning',
        );
        Logger.debug('AzkarNotif: Morning scheduled at $morningTime');
      }

      if (eveningTime.isAfter(now)) {
        await _scheduleNotification(
          plugin: plugin,
          id: _baseEveningId,
          title: 'أذكار المساء 🌙',
          body: 'حان الآن موعد أذكار المساء، اختم يومك بذكر الله.',
          scheduledDateTime: eveningTime,
          channelId: 'azkar_evening_channel',
          channelName: 'أذكار المساء',
          payload: 'azkar_evening',
        );
        Logger.debug('AzkarNotif: Evening scheduled at $eveningTime');
      }
    } catch (e) {
      Logger.error('AzkarNotificationService error: $e');
    }
  }

  // ─── Helper for Scheduling ──────────────────────────────────────────────
  Future<void> _scheduleNotification({
    required FlutterLocalNotificationsPlugin plugin,
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    required String channelId,
    required String channelName,
    required String payload,
  }) async {
    // نستخدم tz.UTC لتجنب مشاكل عدم تهيئة tz.local
    final tzScheduled = tz.TZDateTime.from(scheduledDateTime, tz.UTC);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: 'ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('ic_launcher'),
      styleInformation: BigTextStyleInformation(body),
    );

    await plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzScheduled,
      notificationDetails: NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  // ─── Cancel Logic ───────────────────────────────────────────────────────
  Future<void> cancelAll() async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.cancel(id: _baseMorningId);
    await plugin.cancel(id: _baseEveningId);
    Logger.debug('AzkarNotif: All azkar notifications cancelled.');
  }
}
