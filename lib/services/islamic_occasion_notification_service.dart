import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../data/islamic_occasions.dart';
import 'hijri_date_service.dart';
import '../utils/logger.dart';

/// خدمة مسؤولة عن جدولة إشعارات المناسبات الإسلامية والتاريخية.
///
/// تعمل باستقلالية تامة عن نظام الأذان ولا تؤثر عليه.
/// كل إشعار يُجدَّل في الساعة 10:00 صباحاً من يوم المناسبة.
class IslamicOccasionNotificationService {
  // ─── Singleton ───────────────────────────────────────────────────────────
  static IslamicOccasionNotificationService? _instance;
  static IslamicOccasionNotificationService get instance =>
      _instance ??= IslamicOccasionNotificationService._();
  IslamicOccasionNotificationService._();

  // ─── ثوابت ───────────────────────────────────────────────────────────────
  /// نبدأ IDs من 2000 لتجنب أي تعارض مع منبهات الأذان (101-246)
  /// ونستخدم dayOffset كـ suffix: يوم 0 → 2000, يوم 1 → 2001 ... يوم 13 → 2013
  static const int _baseNotificationId = 2000;

  /// ساعة إطلاق الإشعار يومياً
  static const int _notificationHour = 10;
  static const int _notificationMinute = 0;

  /// مفتاح SharedPreferences لتتبع آخر يوم جدولنا فيه (لمنع إعادة الجدولة كل مرة)
  static const String _lastScheduledDayKey =
      'occasion_notif_last_scheduled_day';

  bool _tzInitialized = false;

  // ─── تهيئة المناطق الزمنية ───────────────────────────────────────────────

  void _ensureTzInitialized() {
    if (_tzInitialized) return;
    tz_data.initializeTimeZones();
    _tzInitialized = true;
  }

  // ─── الدالة الرئيسية ─────────────────────────────────────────────────────

  /// يفحص الأيام الـ 14 القادمة ويجدول إشعاراً لكل يوم يحمل مناسبة إسلامية.
  ///
  /// يُستدعى من داخل [scheduleAllPrayers] بعد اكتمال جدولة الأذان مباشرةً.
  /// - لا يُعيد الجدولة إذا كان قد جدول في نفس اليوم بالفعل.
  /// - يتجاهل تلقائياً المناسبات التي مرت (الساعة > 10:00 ص في نفس اليوم).
  Future<void> scheduleOccasionNotifications({bool force = false}) async {
    try {
      _ensureTzInitialized();

      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month}-${today.day}';

      // ✅ منع إعادة الجدولة الزائدة: جدولة مرة واحدة فقط في اليوم
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

      // إلغاء الإشعارات القديمة الخاصة بالمناسبات (IDs: 2000 إلى 2013)
      await _cancelAllOccasionNotifications(plugin);

      final hijriAdjustment = prefs.getInt('hijri_adjustment') ?? 0;
      int scheduledCount = 0;

      // فحص الـ 14 يوم القادمة (متزامن مع نافذة جدولة الأذان)
      for (int dayOffset = 0; dayOffset <= 13; dayOffset++) {
        final targetDate = today.add(Duration(days: dayOffset));

        // احسب التاريخ الهجري لهذا اليوم
        final hijriData = HijriDateService.getHijriDate(
          targetDate,
          hijriAdjustment,
        );
        final int hMonth = hijriData['monthIndex'] as int;
        final int hDay = hijriData['dayIndex'] as int;

        // فحص وجود مناسبة
        final occasion = IslamicOccasions.getPrimaryOccasion(hMonth, hDay);
        if (occasion == null) continue;

        // ─── شرط منطقي: لا نجدول إذا مرت الساعة 10:00 ص في نفس اليوم ───
        final scheduledTime = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          _notificationHour,
          _notificationMinute,
        );
        if (scheduledTime.isBefore(today)) {
          Logger.debug(
            'OccasionNotif: Skipping "$occasion" — 10:00 AM already passed.',
          );
          continue;
        }

        // ─── جدولة الإشعار ────────────────────────────────────────────────
        final notifId = _baseNotificationId + dayOffset;
        await _scheduleOccasionNotification(
          plugin: plugin,
          id: notifId,
          occasionName: occasion,
          scheduledDateTime: scheduledTime,
        );

        scheduledCount++;
        Logger.debug(
          'OccasionNotif: Scheduled [$notifId] "$occasion" at $scheduledTime',
        );
      }

      // حفظ اليوم الحالي لتجنب إعادة الجدولة
      await prefs.setString(_lastScheduledDayKey, todayKey);
      debugPrint(
        '!!! OccasionNotif: Scheduled $scheduledCount occasion notification(s) !!!',
      );
    } catch (e) {
      Logger.error('IslamicOccasionNotificationService error: $e');
    }
  }

  // ─── دوال مساعدة ─────────────────────────────────────────────────────────

  Future<void> _scheduleOccasionNotification({
    required FlutterLocalNotificationsPlugin plugin,
    required int id,
    required String occasionName,
    required DateTime scheduledDateTime,
  }) async {
    // تحويل التوقيت لـ TZDateTime باستخدام المنطقة الزمنية المحلية للجهاز
    final tzScheduled = tz.TZDateTime.from(scheduledDateTime, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'islamic_occasions_channel',       // channel ID
      'المناسبات الإسلامية',             // channel Name
      channelDescription: 'تذكير بالمناسبات الدينية والتاريخية الإسلامية',
      importance: Importance.high,
      priority: Priority.high,
      // ✅ صوت الإشعار الافتراضي للنظام (لا أذان)
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(''),
    );

    const notifDetails = NotificationDetails(android: androidDetails);

    await plugin.zonedSchedule(
      id: id,
      title: 'حدث في مثل هذا اليوم 🗓️',
      body: occasionName,
      scheduledDate: tzScheduled,
      notificationDetails: notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'islamic_occasion|$occasionName',
    );
  }

  /// يلغي كافة إشعارات المناسبات (IDs: 2000–2013)
  Future<void> _cancelAllOccasionNotifications(
    FlutterLocalNotificationsPlugin plugin,
  ) async {
    for (int i = 0; i <= 13; i++) {
      await plugin.cancel(id: _baseNotificationId + i);
    }
  }

  /// يلغي كافة إشعارات المناسبات (للاستدعاء الخارجي عند الحاجة)
  Future<void> cancelAll() async {
    final plugin = FlutterLocalNotificationsPlugin();
    await _cancelAllOccasionNotifications(plugin);
    Logger.debug('OccasionNotif: All occasion notifications cancelled.');
  }
}
