import 'dart:io';
import 'package:flutter/services.dart';
import '../utils/logger.dart';
import 'permissions_service.dart';

/// خدمة جدولة إشعارات الأذكار عبر AlarmManager النيتف.
///
/// تعتمد على [MethodChannel] لاستدعاء `scheduleNativeNotification` في Kotlin،
/// مما يضمن عمل الإشعارات حتى مع تفعيل Battery Optimization في هواتف الأندرويد.
class AzkarNotificationService {
  // ─── Singleton ───────────────────────────────────────────────────────────
  static AzkarNotificationService? _instance;
  static AzkarNotificationService get instance =>
      _instance ??= AzkarNotificationService._();
  AzkarNotificationService._();

  // ─── MethodChannel ───────────────────────────────────────────────────────
  static const _channel = MethodChannel('imsakia/notifications');

  // ─── IDs — محفوظة من الإصدار القديم لضمان إلغاء الجدولات القديمة ───────
  static const int _baseMorningId = 50001;
  static const int _baseEveningId = 50002;

  // ─── Channel IDs (تُرسل للـ Kotlin لتحديد قناة الإشعار) ─────────────────
  static const String _azkarChannelId = 'azkar_notifications_v1';

  // ─── Scheduling Logic ────────────────────────────────────────────────────

  /// يجدول إشعارَي أذكار الصباح والمساء عبر AlarmManager النيتف.
  ///
  /// - أذكار الصباح: بعد الفجر بـ 90 دقيقة
  /// - أذكار المساء: بعد العصر بـ 30 دقيقة
  Future<void> scheduleAzkarNotifications(
    DateTime fajrTime,
    DateTime asrTime,
  ) async {
    if (!Platform.isAndroid) return;

    try {
      final now = DateTime.now();

      // أذكار الصباح
      final morningTime = fajrTime.add(const Duration(minutes: 90));
      if (morningTime.isAfter(now)) {
        await _scheduleOne(
          id: _baseMorningId,
          title: 'أذكار الصباح ☀️',
          body: 'حان الآن موعد أذكار الصباح، فاذكر الله يذكرك.',
          scheduledDateTime: morningTime,
          payload: 'azkar_morning',
        );
        Logger.debug('AzkarNotif [Native]: Morning scheduled at $morningTime');
      } else {
        Logger.debug('AzkarNotif [Native]: Morning skipped (past time)');
      }

      // أذكار المساء
      final eveningTime = asrTime.add(const Duration(minutes: 30));
      if (eveningTime.isAfter(now)) {
        await _scheduleOne(
          id: _baseEveningId,
          title: 'أذكار المساء 🌙',
          body: 'حان الآن موعد أذكار المساء، اختم يومك بذكر الله.',
          scheduledDateTime: eveningTime,
          payload: 'azkar_evening',
        );
        Logger.debug('AzkarNotif [Native]: Evening scheduled at $eveningTime');
      } else {
        Logger.debug('AzkarNotif [Native]: Evening skipped (past time)');
      }
    } catch (e) {
      Logger.error('AzkarNotificationService error: $e');
    }
  }

  // ─── Helper ──────────────────────────────────────────────────────────────

  Future<void> _scheduleOne({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    required String payload,
  }) async {
    try {
      final timeInMillis = scheduledDateTime.millisecondsSinceEpoch;

      await _channel.invokeMethod<bool>('scheduleNativeNotification', {
        'id': id,
        'timeInMillis': timeInMillis,
        'title': title,
        'body': body,
        'payload': payload,
        'channelId': _azkarChannelId,
      });
    } on PlatformException catch (e) {
      if (e.code == 'EXACT_ALARM_PERMISSION_DENIED') {
        Logger.warning(
          'AzkarNotif: exact alarm permission missing — opening settings for user',
        );
        // توجيه المستخدم لتفعيل الصلاحية (يُنفَّذ فقط إن كانت الواجهة مفتوحة)
        await PermissionsService.openExactAlarmSettings();
      } else {
        Logger.error('AzkarNotif scheduleNativeNotification[$id] error: ${e.message}');
      }
    } catch (e) {
      Logger.error('AzkarNotif scheduleNativeNotification[$id] unexpected error: $e');
    }
  }

  // ─── Cancel Logic ────────────────────────────────────────────────────────

  /// يلغي إشعارَي الأذكار المجدولَين.
  Future<void> cancelAll() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('cancelNativeNotification', {'id': _baseMorningId});
      await _channel.invokeMethod('cancelNativeNotification', {'id': _baseEveningId});
      Logger.debug('AzkarNotif [Native]: All azkar notifications cancelled.');
    } catch (e) {
      Logger.error('AzkarNotif cancelAll error: $e');
    }
  }
}
