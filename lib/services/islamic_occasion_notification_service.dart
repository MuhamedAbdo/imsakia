import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/islamic_occasions.dart';
import 'hijri_date_service.dart';
import '../utils/logger.dart';
import 'custom_occasion_service.dart';

/// خدمة مسؤولة عن جدولة نوعين من الإشعارات عبر AlarmManager النيتف:
///
/// 1️⃣  **إشعارات المناسبات** (IDs: 20000–20013) — الساعة 10:00 صباحاً في يوم المناسبة.
/// 2️⃣  **إشعارات التذكير بالصيام** (IDs: 30000–30013) — الساعة 18:00 في اليوم المحدد
///      قبل المناسبة بـ [IslamicOccasion.reminderDaysBefore].
/// 3️⃣  **إشعارات المناسبات المخصصة** (IDs: 40000+) — الساعة 10:00 صباحاً.
///
/// كلا النوعين مستقل تماماً عن نظام الأذان ويعتمد على MethodChannel النيتف.
class IslamicOccasionNotificationService {
  // ─── Singleton ───────────────────────────────────────────────────────────
  static IslamicOccasionNotificationService? _instance;
  static IslamicOccasionNotificationService get instance =>
      _instance ??= IslamicOccasionNotificationService._();
  IslamicOccasionNotificationService._();

  // ─── MethodChannel ───────────────────────────────────────────────────────
  static const _channel = MethodChannel('imsakia/notifications');

  // ─── ثوابت — IDs ────────────────────────────────────────────────────────
  /// إشعارات المناسبات الصباحية (10:00 ص)
  static const int _baseOccasionId = 20000;

  /// إشعارات التذكير بالصيام (18:00)
  static const int _baseFastingId = 30000;

  /// إشعارات المناسبات المخصصة الصباحية (10:00 ص)
  static const int _baseCustomOccasionId = 40000;

  /// أقصى عدد أيام مدرجة في كل حزمة
  static const int _windowDays = 14;

  // ─── أوقات الإشعارات ────────────────────────────────────────────────────
  static const int _occasionHour = 10;
  static const int _occasionMinute = 0;
  static const int _fastingHour = 18;
  static const int _fastingMinute = 0;

  // ─── Channel IDs للـ Kotlin ──────────────────────────────────────────────
  static const String _occasionChannelId = 'occasion_notifications_v1';
  static const String _fastingChannelId = 'fasting_notifications_v1';

  // ─── SharedPreferences key ───────────────────────────────────────────────
  static const String _scheduledFlagPrefix = 'occasion_native_scheduled_';

  // ═══════════════════════════════════════════════════════════════════════════
  // الدالة الرئيسية
  // ═══════════════════════════════════════════════════════════════════════════

  /// يجدول إشعارات المناسبات وإشعارات التذكير بالصيام للـ 14 يوماً القادمة.
  ///
  /// يُستدعى تلقائياً من [scheduleAllPrayers] في نهاية كل دورة جدولة.
  Future<void> scheduleOccasionNotifications({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final dateKey = '$_scheduledFlagPrefix${today.year}-${today.month}-${today.day}';

      // ✅ ضمان الجدولة مرة واحدة فقط يومياً (ما لم يُطلب Force)
      if (!force) {
        final isScheduledToday = prefs.getBool(dateKey) ?? false;
        if (isScheduledToday) {
          Logger.debug('OccasionNotif [Native]: Already scheduled today, skipping.');
          return;
        }
      }

      // إلغاء جميع الإشعارات السابقة أولاً
      await _cancelAll();

      final hijriAdjustment = prefs.getInt('hijri_adjustment') ?? 0;
      int occasionCount = 0;
      int fastingCount = 0;
      int customOccasionCount = 0;

      final customOccasions = await CustomOccasionService.getOccasions();

      // ─── فحص الـ 14 يوماً القادمة ────────────────────────────────────────
      for (int offset = 0; offset < _windowDays; offset++) {
        final targetDate = today.add(Duration(days: offset));
        final hijriData = HijriDateService.getHijriDate(
          targetDate,
          hijriAdjustment,
        );
        final int hMonth = hijriData['monthIndex'] as int;
        final int hDay = hijriData['dayIndex'] as int;

        final occasion = IslamicOccasions.getOccasion(hMonth, hDay);
        if (occasion == null) continue;

        // ── 1️⃣ إشعار المناسبة الصباحي (10:00 ص) ────────────────────────
        final occasionTime = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          _occasionHour,
          _occasionMinute,
        );

        if (occasionTime.isAfter(today)) {
          await _scheduleOne(
            id: _baseOccasionId + offset,
            title: 'حدث في مثل هذا اليوم 🗓️',
            body: occasion.primaryName,
            scheduledDateTime: occasionTime,
            payload: 'islamic_occasion|${occasion.primaryName}',
            channelId: _occasionChannelId,
          );
          occasionCount++;
        }

        // ── 2️⃣ إشعار التذكير بالصيام (18:00) ───────────────────────────
        if (occasion.hasFastingReminder && occasion.fastingReminderTitle != null) {
          final reminderDate = targetDate.subtract(
            Duration(days: occasion.reminderDaysBefore),
          );
          final fastingTime = DateTime(
            reminderDate.year,
            reminderDate.month,
            reminderDate.day,
            _fastingHour,
            _fastingMinute,
          );

          if (fastingTime.isAfter(today)) {
            final fastingOffset =
                fastingTime.difference(today).inDays.clamp(0, _windowDays - 1);

            await _scheduleOne(
              id: _baseFastingId + fastingOffset,
              title: occasion.fastingReminderTitle!,
              body: occasion.fastingReminderBody ?? '',
              scheduledDateTime: fastingTime,
              payload: 'fasting_reminder|${occasion.primaryName}',
              channelId: _fastingChannelId,
            );
            fastingCount++;
          }
        }
      }

      // ─── 3️⃣ فحص المناسبات المخصصة للـ 14 يوماً القادمة ──────────────────
      for (int offset = 0; offset < _windowDays; offset++) {
        final targetDate = today.add(Duration(days: offset));
        final hijriData = HijriDateService.getHijriDate(
          targetDate,
          hijriAdjustment,
        );
        final int hMonth = hijriData['monthIndex'] as int;
        final int hDay = hijriData['dayIndex'] as int;

        final matchingCustomOccasions = customOccasions.where((o) {
          if (o.isHijri) {
            return o.month == hMonth && o.day == hDay;
          } else {
            return o.month == targetDate.month && o.day == targetDate.day;
          }
        }).toList();

        for (var customOccasion in matchingCustomOccasions) {
          final occasionTime = DateTime(
            targetDate.year,
            targetDate.month,
            targetDate.day,
            _occasionHour,
            _occasionMinute,
          );

          if (occasionTime.isAfter(today)) {
            await _scheduleOne(
              id: _baseCustomOccasionId + offset + customOccasion.id.hashCode % 1000,
              title: 'مناسبة مخصصة 🌟',
              body: customOccasion.title,
              scheduledDateTime: occasionTime,
              payload: 'custom_occasion|${customOccasion.title}',
              channelId: _occasionChannelId,
            );
            customOccasionCount++;
          }
        }
      }

      // حفظ تاريخ اليوم لمنع إعادة الجدولة
      await prefs.setBool(dateKey, true);
      debugPrint(
        'OccasionNotif [Native]: Scheduled $occasionCount occasions, '
        '$fastingCount fasting, $customOccasionCount custom.',
      );
    } catch (e) {
      Logger.error('IslamicOccasionNotificationService error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // دوال مساعدة خاصة
  // ═══════════════════════════════════════════════════════════════════════════

  /// جدولة إشعار واحد عبر MethodChannel النيتف.
  Future<void> _scheduleOne({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    required String payload,
    required String channelId,
  }) async {
    try {
      final timeInMillis = scheduledDateTime.millisecondsSinceEpoch;

      await _channel.invokeMethod<bool>('scheduleNativeNotification', {
        'id': id,
        'timeInMillis': timeInMillis,
        'title': title,
        'body': body,
        'payload': payload,
        'channelId': channelId,
      });
    } on PlatformException catch (e) {
      if (e.code == 'EXACT_ALARM_PERMISSION_DENIED') {
        // الجدولة تحدث في الخلفية — نسجل تحذيراً فقط بدون توجيه المستخدم
        Logger.warning(
          'OccasionNotif: exact alarm permission missing for ID=$id — skipping. '
          'User should be directed from settings screen.',
        );
      } else {
        Logger.error('OccasionNotif scheduleNativeNotification[$id] error: ${e.message}');
      }
    } catch (e) {
      Logger.error('OccasionNotif scheduleNativeNotification[$id] unexpected: $e');
    }
  }

  /// يلغي كافة إشعارات المناسبات والصيام والمخصصة دفعة واحدة.
  Future<void> _cancelAll() async {
    try {
      // إلغاء المناسبات (20000–20013)
      await _channel.invokeMethod('cancelNativeNotificationsInRange', {
        'fromId': _baseOccasionId,
        'toId': _baseOccasionId + _windowDays - 1,
      });

      // إلغاء تذكيرات الصيام (30000–30013)
      await _channel.invokeMethod('cancelNativeNotificationsInRange', {
        'fromId': _baseFastingId,
        'toId': _baseFastingId + _windowDays - 1,
      });

      // إلغاء المناسبات المخصصة (40000–41399)
      await _channel.invokeMethod('cancelNativeNotificationsInRange', {
        'fromId': _baseCustomOccasionId,
        'toId': _baseCustomOccasionId + (_windowDays * 100) - 1,
      });

      Logger.debug('OccasionNotif [Native]: All cancelled.');
    } catch (e) {
      Logger.error('OccasionNotif _cancelAll error: $e');
    }
  }

  /// إلغاء خارجي عند الحاجة (مثلاً عند تعطيل الإشعارات من الإعدادات).
  Future<void> cancelAll() async {
    await _cancelAll();
    Logger.debug('OccasionNotif [Native]: External cancelAll done.');
  }
}
