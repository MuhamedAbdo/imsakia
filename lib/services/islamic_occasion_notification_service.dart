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
/// 3️⃣  **إشعارات المناسبات المخصصة** (IDs: 40000–49999) — الساعة 10:00 صباحاً.
///
/// ═══ ضمانات عدم تعارض الـ IDs ═══════════════════════════════════════════════
///  • أوقات الصلاة (Prayer):    100 –   999  (يُعيِّنها PrayerTimesService)
///  • مناسبات إسلامية:         20000 – 20013 (base + offset اليوم في النافذة)
///  • تذكيرات الصيام:          30000 – 30013 (base + offset يوم المناسبة ذاتها)
///  • مناسبات مخصصة:          40000 – 49999 (base + موضع المناسبة في القائمة)
///
/// الفصل بين النطاقات رياضياً مضمون:
///  - أوقات الصلاة:   base ∈ {101–106}, offset ≤ 140  → max = 246   < 20000 ✅
///  - مناسبات:        base = 20000, offset ≤ 13       → max = 20013  < 30000 ✅
///  - صيام:           base = 30000, offset ≤ 13       → max = 30013  < 40000 ✅
///  - مخصصة:          base = 40000, listIndex ≤ 9999  → max = 49999  ✅
/// ═══════════════════════════════════════════════════════════════════════════════
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

  /// إشعارات المناسبات المخصصة الصباحية (10:00 ص) — نطاق: 40000–49999
  static const int _baseCustomOccasionId = 40000;

  /// الحد الأقصى لـ listIndex المقبول للمناسبات المخصصة.
  /// يضمن بقاء جميع الـ IDs ضمن النطاق 40000–49999 مهما بلغ عدد المناسبات.
  static const int _maxCustomListIndex = 9999;

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
  static const String _activeNativeIdsKey = 'active_native_notification_ids';

  /// مفتاح العلم الذي يكتبه [BootReceiver] في FlutterSharedPreferences عند كل
  /// BOOT_COMPLETED أو MY_PACKAGE_REPLACED. وجوده يعني أن AlarmManager مسح
  /// جميع المنبهات، ويجب إعادة جدولة المناسبات بصرف النظر عن علم اليوم.
  /// يُكتب من native كـ "flutter.needs_occasion_reschedule" ليقرأه Dart تلقائياً.
  static const String _needsRescheduleAfterBootKey =
      'needs_occasion_reschedule';

  /// تتبع المهمة الجارية حالياً لمنع التداخل والتنفيذ المتزامن
  Future<void>? _inFlightSchedule;

  // ═══════════════════════════════════════════════════════════════════════════
  // الدالة الرئيسية
  // ═══════════════════════════════════════════════════════════════════════════

  /// يجدول إشعارات المناسبات وإشعارات التذكير بالصيام للـ 14 يوماً القادمة.
  ///
  /// يُستدعى تلقائياً من [scheduleAllPrayers] في نهاية كل دورة جدولة،
  /// ومن `main.dart` عند استئناف التطبيق (Resume) لإعادة المحاولة فوراً إن فشلت محاولة سابقة.
  ///
  /// منطق تجاوز الحارس اليومي:
  ///  - [force] = true  → يتجاوز العلم دائماً (استدعاء صريح من scheduleAllPrayers)
  ///  - [_needsRescheduleAfterBootKey] = true → يتجاوز العلم بعد الإقلاع (Fix 5)
  Future<void> scheduleOccasionNotifications({bool force = false}) {
    if (_inFlightSchedule != null) {
      Logger.debug(
        'OccasionNotif: Scheduling already in flight, sharing active task.',
      );
      return _inFlightSchedule!;
    }
    return _inFlightSchedule = _executeSchedule(force).whenComplete(() {
      _inFlightSchedule = null;
    });
  }

  Future<void> _executeSchedule(bool force) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // ── Fix 5: تحديث الذاكرة المحلية لاستيعاب ما كتبه BootReceiver ─────────
      // BootReceiver يعمل في سياق native قبل أن يُشغَّل Flutter، لذا يجب إعادة
      // القراءة صراحةً لضمان رؤية العلم الذي كتبه.
      await prefs.reload();

      final today = DateTime.now();
      final dateKey =
          '$_scheduledFlagPrefix${today.year}-${today.month}-${today.day}';

      // ── Fix 5: كشف إعادة التشغيل أو تحديث الحزمة ─────────────────────────
      // يكتب BootReceiver هذا العلم في FlutterSharedPreferences ("flutter.<key>")
      // عند كل BOOT_COMPLETED أو MY_PACKAGE_REPLACED، أي كلما مسح Android
      // جميع منبهات AlarmManager تلقائياً.
      final needsRescheduleAfterBoot =
          prefs.getBool(_needsRescheduleAfterBootKey) ?? false;
      final effectiveForce = force || needsRescheduleAfterBoot;

      // ✅ ضمان الجدولة مرة واحدة فقط يومياً (ما لم يُطلب Force أو حدث إقلاع)
      if (!effectiveForce) {
        final isScheduledToday = prefs.getBool(dateKey) ?? false;
        if (isScheduledToday) {
          Logger.debug(
            'OccasionNotif [Native]: Already scheduled today, skipping.',
          );
          return;
        }
      } else if (needsRescheduleAfterBoot) {
        Logger.debug(
          'OccasionNotif [Native]: Post-boot/update reschedule forced — bypassing daily guard.',
        );
      }

      // إلغاء جميع الإشعارات السابقة أولاً
      await _cancelAll();

      final hijriAdjustment = prefs.getInt('hijri_adjustment') ?? 0;
      int occasionCount = 0;
      int fastingCount = 0;
      int customOccasionCount = 0;
      bool allSucceeded = true;
      List<String> scheduledIds = [];

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
        // ID = 20000 + offset → نطاق 20000–20013، فريد لكل يوم في النافذة.
        final occasionTime = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          _occasionHour,
          _occasionMinute,
        );

        if (occasionTime.isAfter(today)) {
          final id = _baseOccasionId + offset;
          final success = await _scheduleOne(
            id: id,
            title: 'حدث في مثل هذا اليوم 🗓️',
            body: occasion.primaryName,
            scheduledDateTime: occasionTime,
            payload: 'islamic_occasion|${occasion.primaryName}',
            channelId: _occasionChannelId,
          );
          if (success) {
            scheduledIds.add(id.toString());
            occasionCount++;
          } else {
            allSucceeded = false;
          }
        }

        // ── 2️⃣ إشعار التذكير بالصيام (18:00) ───────────────────────────
        if (occasion.hasFastingReminder &&
            occasion.fastingReminderTitle != null) {
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
            // ── Fix 4: الـ ID مرتبط بـ [offset] يوم المناسبة (لا بالمسافة من اليوم) ──
            // السبب: ربط الـ ID بمسافة التذكير من اليوم كان يتسبب في تعارض IDs عندما
            // تكون مناسبتان مختلفتان لهما تذكيران يقعان على نفس البُعد الزمني من اليوم.
            // الربط بـ [offset] يضمن أن كل مناسبة (التي لها offset فريد في النافذة)
            // تحصل على ID تذكير صيام فريد رياضياً — نطاق: 30000–30013.
            final id = _baseFastingId + offset;

            final success = await _scheduleOne(
              id: id,
              title: occasion.fastingReminderTitle!,
              body: occasion.fastingReminderBody ?? '',
              scheduledDateTime: fastingTime,
              payload: 'fasting_reminder|${occasion.primaryName}',
              channelId: _fastingChannelId,
            );
            if (success) {
              scheduledIds.add(id.toString());
              fastingCount++;
            } else {
              allSucceeded = false;
            }
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
            // ── Fix 3: ID = 40000 + موضع المناسبة في القائمة الكاملة ─────────────
            // العلة القديمة: `hashCode % 1000` يُنتج قيماً سالبة في Dart عندما
            // يكون hashCode سالباً، مما قد يُنتج IDs خارج النطاق 40000–49999 أو
            // تعارضاً مع نطاق 30000.
            //
            // الحل: كل مناسبة مخصصة (CustomOccasion) لها تاريخ ثابت (Gregorian أو
            // Hijri)، لذا تظهر مرة واحدة على الأكثر في أي نافذة 14 يوماً. هذا يعني
            // أن موضعها (listIndex) في قائمة customOccasions يكفي وحده لتمييز الـ ID
            // داخل النطاق 40000–49999 دون الحاجة لدمجه مع [offset].
            final listIndex = customOccasions.indexWhere(
              (c) => c.id == customOccasion.id,
            );
            if (listIndex == -1 || listIndex > _maxCustomListIndex) continue;
            final id = _baseCustomOccasionId + listIndex;

            final success = await _scheduleOne(
              id: id,
              title: 'مناسبة مخصصة 🌟',
              body: customOccasion.title,
              scheduledDateTime: occasionTime,
              payload: 'custom_occasion|${customOccasion.title}',
              channelId: _occasionChannelId,
            );
            if (success) {
              scheduledIds.add(id.toString());
              customOccasionCount++;
            } else {
              allSucceeded = false;
            }
          }
        }
      }

      // حفظ الـ IDs التي تمت جدولتها بنجاح فقط لاستخدامها عند الإلغاء
      bool persistenceSucceeded = true;
      if (scheduledIds.isNotEmpty) {
        persistenceSucceeded = await prefs.setStringList(
          _activeNativeIdsKey,
          scheduledIds,
        );
      }

      // ── تعيين الحارس ومسح علم الإقلاع فقط عند النجاح التام للجدولة والحفظ ──
      if (allSucceeded && persistenceSucceeded) {
        await prefs.setBool(dateKey, true);
        if (needsRescheduleAfterBoot) {
          await prefs.remove(_needsRescheduleAfterBootKey);
        }
      } else {
        Logger.warning(
          'OccasionNotif: Partial failure or persistence issue detected '
          '(allSucceeded=$allSucceeded, persistenceSucceeded=$persistenceSucceeded). '
          'Daily guard and boot flag preserved for retry.',
        );
      }

      debugPrint(
        'OccasionNotif [Native]: Scheduled $occasionCount occasions, '
        '$fastingCount fasting, $customOccasionCount custom.'
        '${needsRescheduleAfterBoot ? " [post-boot forced]" : ""}',
      );
    } catch (e) {
      Logger.error('IslamicOccasionNotificationService error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // دوال مساعدة خاصة
  // ═══════════════════════════════════════════════════════════════════════════

  /// جدولة إشعار واحد عبر MethodChannel النيتف.
  /// يُعيد true فقط إذا أكّد نظام الأندرويد نجاح الجدولة صراحةً.
  Future<bool> _scheduleOne({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    required String payload,
    required String channelId,
  }) async {
    try {
      final timeInMillis = scheduledDateTime.millisecondsSinceEpoch;

      final bool? success = await _channel
          .invokeMethod<bool>('scheduleNativeNotification', {
            'id': id,
            'timeInMillis': timeInMillis,
            'title': title,
            'body': body,
            'payload': payload,
            'channelId': channelId,
          });

      return success == true;
    } on PlatformException catch (e) {
      if (e.code == 'EXACT_ALARM_PERMISSION_DENIED') {
        // الجدولة تحدث في الخلفية — نسجل تحذيراً فقط بدون توجيه المستخدم
        Logger.warning(
          'OccasionNotif: exact alarm permission missing for ID=$id — skipping. '
          'User should be directed from settings screen.',
        );
      } else {
        Logger.error(
          'OccasionNotif scheduleNativeNotification[$id] error: ${e.message}',
        );
      }
      return false;
    } catch (e) {
      Logger.error(
        'OccasionNotif scheduleNativeNotification[$id] unexpected: $e',
      );
      return false;
    }
  }

  /// يلغي كافة إشعارات المناسبات والصيام والمخصصة دفعة واحدة بناءً على ما تم حفظه.
  Future<void> _cancelAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeIds = prefs.getStringList(_activeNativeIdsKey) ?? [];

      if (activeIds.isNotEmpty) {
        final idsToCancel = activeIds
            .map((e) => int.tryParse(e) ?? 0)
            .where((id) => id > 0)
            .toList();
        await _channel.invokeMethod('cancelSpecificNativeNotifications', {
          'ids': idsToCancel,
        });
        await prefs.remove(_activeNativeIdsKey);
        Logger.debug(
          'OccasionNotif [Native]: Cancelled ${idsToCancel.length} specific notifications.',
        );
      } else {
        // حماية إضافية للرجوع للوراء في حالة الترقية من الإصدار القديم
        Logger.debug(
          'OccasionNotif [Native]: No active IDs tracked. Skipping range cancelling to prevent OOM.',
        );
      }
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
