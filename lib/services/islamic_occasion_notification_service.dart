import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../data/islamic_occasions.dart';
import 'hijri_date_service.dart';
import '../utils/logger.dart';
import 'custom_occasion_service.dart';

/// خدمة مسؤولة عن جدولة نوعين من الإشعارات:
///
/// 1️⃣  **إشعارات المناسبات** (IDs: 2000–2013) — الساعة 10:00 صباحاً في يوم المناسبة.
/// 2️⃣  **إشعارات التذكير بالصيام** (IDs: 3000–3013) — الساعة 18:00 في اليوم المحدد
///      قبل المناسبة بـ [IslamicOccasion.reminderDaysBefore].
///
/// كلا النوعين مستقل تماماً عن نظام الأذان.
class IslamicOccasionNotificationService {
  // ─── Singleton ───────────────────────────────────────────────────────────
  static IslamicOccasionNotificationService? _instance;
  static IslamicOccasionNotificationService get instance =>
      _instance ??= IslamicOccasionNotificationService._();
  IslamicOccasionNotificationService._();

  // ─── ثوابت — IDs ────────────────────────────────────────────────────────
  /// إشعارات المناسبات الصباحية (10:00 ص)
  static const int _baseOccasionId = 2000; // 2000–2013

  /// إشعارات التذكير بالصيام (18:00)
  static const int _baseFastingId = 3000; // 3000–3013

  /// إشعارات المناسبات المخصصة الصباحية (10:00 ص)
  static const int _baseCustomOccasionId = 4000; // 4000–4013

  /// أقصى عدد أيام مدرجة في كل حزمة
  static const int _windowDays = 14;

  // ─── أوقات الإشعارات ────────────────────────────────────────────────────
  static const int _occasionHour = 10;
  static const int _occasionMinute = 0;
  static const int _fastingHour = 18;
  static const int _fastingMinute = 0;

  // ─── SharedPreferences key ───────────────────────────────────────────────
  static const String _lastScheduledDayKey =
      'occasion_notif_last_scheduled_day';

  bool _tzInitialized = false;

  // ─── تهيئة المناطق الزمنية ───────────────────────────────────────────────
  void _ensureTzInitialized() {
    if (_tzInitialized) return;
    tz_data.initializeTimeZones();
    _tzInitialized = true;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // الدالة الرئيسية
  // ═══════════════════════════════════════════════════════════════════════════

  /// يجدول إشعارات المناسبات وإشعارات التذكير بالصيام للـ 14 يوماً القادمة.
  ///
  /// يُستدعى تلقائياً من [scheduleAllPrayers] في نهاية كل دورة جدولة.
  Future<void> scheduleOccasionNotifications({bool force = false}) async {
    try {
      _ensureTzInitialized();

      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month}-${today.day}';

      // ✅ ضمان الجدولة مرة واحدة فقط يومياً (ما لم يُطلب Force)
      if (!force) {
        final lastScheduled = prefs.getString(_lastScheduledDayKey);
        if (lastScheduled == todayKey) {
          Logger.debug('OccasionNotif: Already scheduled today, skipping.');
          return;
        }
      }

      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );

      // إلغاء جميع الإشعارات السابقة (مناسبات + صيام)
      await _cancelAll(plugin);

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
          await _scheduleNotification(
            plugin: plugin,
            id: _baseOccasionId + offset,
            title: 'حدث في مثل هذا اليوم 🗓️',
            body: occasion.primaryName,
            scheduledDateTime: occasionTime,
            channelId: 'islamic_occasions_channel',
            channelName: 'المناسبات الإسلامية',
            channelDesc: 'تذكير بالمناسبات الدينية والتاريخية الإسلامية',
            payload: 'islamic_occasion|${occasion.primaryName}',
          );
          occasionCount++;
          Logger.debug(
            'OccasionNotif: [${_baseOccasionId + offset}] "${occasion.primaryName}" at $occasionTime',
          );
        } else {
          Logger.debug(
            'OccasionNotif: Skipping "${occasion.primaryName}" — 10:00 AM passed.',
          );
        }

        // ── 2️⃣ إشعار التذكير بالصيام (18:00) ───────────────────────────
        if (occasion.hasFastingReminder &&
            occasion.fastingReminderTitle != null) {
          // تاريخ إرسال إشعار الصيام = targetDate - reminderDaysBefore
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
            // نحسب offset للـ ID بناءً على الفرق عن اليوم الحالي
            final fastingOffset =
                fastingTime.difference(today).inDays.clamp(0, _windowDays - 1);

            await _scheduleNotification(
              plugin: plugin,
              id: _baseFastingId + fastingOffset,
              title: occasion.fastingReminderTitle!,
              body: occasion.fastingReminderBody ?? '',
              scheduledDateTime: fastingTime,
              channelId: 'fasting_reminders_channel',
              channelName: 'تذكيرات الصيام',
              channelDesc: 'تذكيرات بسنن الصيام والأيام المستحبة',
              payload: 'fasting_reminder|${occasion.primaryName}',
            );
            fastingCount++;
            Logger.debug(
              'FastingNotif: [${_baseFastingId + fastingOffset}] '
              '"${occasion.fastingReminderTitle}" at $fastingTime',
            );
          } else {
            Logger.debug(
              'FastingNotif: Skipping "${occasion.fastingReminderTitle}" — 18:00 passed.',
            );
          }
        }
      }

      // ─── 3️⃣ فحص المناسبات المخصصة للـ 14 يوماً القادمة ───────────────────
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
            await _scheduleNotification(
              plugin: plugin,
              id: _baseCustomOccasionId + offset + customOccasion.id.hashCode % 100, // لتجنب التعارض في نفس اليوم
              title: 'مناسبة مخصصة 🌟',
              body: customOccasion.title,
              scheduledDateTime: occasionTime,
              channelId: 'custom_occasions_channel',
              channelName: 'المناسبات المخصصة',
              channelDesc: 'تذكير بمناسباتك الخاصة',
              payload: 'custom_occasion|${customOccasion.title}',
            );
            customOccasionCount++;
            Logger.debug(
              'OccasionNotif: Custom "${customOccasion.title}" at $occasionTime',
            );
          }
        }
      }

      // حفظ اليوم لمنع إعادة الجدولة
      await prefs.setString(_lastScheduledDayKey, todayKey);
      debugPrint(
        '!!! OccasionNotif: $occasionCount occasion(s) + $fastingCount fasting reminder(s) + $customOccasionCount custom occasion(s) scheduled !!!',
      );
    } catch (e) {
      Logger.error('IslamicOccasionNotificationService error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // دوال مساعدة خاصة
  // ═══════════════════════════════════════════════════════════════════════════

  /// جدولة إشعار واحد عبر [zonedSchedule].
  Future<void> _scheduleNotification({
    required FlutterLocalNotificationsPlugin plugin,
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    required String channelId,
    required String channelName,
    required String channelDesc,
    required String payload,
  }) async {
    final tzScheduled = tz.TZDateTime.from(scheduledDateTime, tz.local);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
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

  /// يلغي كافة إشعارات المناسبات (2000–2013) وإشعارات الصيام (3000–3013) والمخصصة (4000+).
  Future<void> _cancelAll(FlutterLocalNotificationsPlugin plugin) async {
    for (int i = 0; i < _windowDays; i++) {
      await plugin.cancel(id: _baseOccasionId + i);
      await plugin.cancel(id: _baseFastingId + i);
      // We can't easily cancel all possible hash combinations for custom occasions,
      // so we use cancelAll to be safe, but wait, if we use cancelAll it cancels prayers too!
      // Actually FlutterLocalNotificationsPlugin doesn't have cancelByChannel easily.
      // So we will just cancel a range around baseCustomOccasionId for safety.
      for (int j = 0; j < 100; j++) {
        await plugin.cancel(id: _baseCustomOccasionId + i + j);
      }
    }
  }

  /// إلغاء خارجي عند الحاجة (مثلاً عند تعطيل الإشعارات من الإعدادات).
  Future<void> cancelAll() async {
    final plugin = FlutterLocalNotificationsPlugin();
    await _cancelAll(plugin);
    Logger.debug('OccasionNotif: All occasion & fasting notifications cancelled.');
  }
}
