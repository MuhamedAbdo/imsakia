import 'dart:async';
import 'package:adhan/adhan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../utils/app_constants.dart';
import '../utils/logger.dart'; // تأكد من وجود هذا المسار
import 'hijri_date_service.dart';
import '../features/athan/services/athan_manager.dart';
import 'package:home_widget/home_widget.dart';
import 'home_events_service.dart';
import '../main.dart';

class PrayerTimesService {
  static PrayerTimesService? _instance;
  static PrayerTimesService get instance =>
      _instance ??= PrayerTimesService._();

  PrayerTimesService._();

  Map<String, DateTime>? _currentPrayerTimes;
  StreamController<Map<String, DateTime>>? _prayerTimesController;
  Timer? _updateTimer;
  SharedPreferences? _sharedPreferences;
  bool _isScheduling = false; // 🔥 لمنع تداخل عمليات الجدولة
  bool _isWidgetUpdating = false; // ✅ FIX: منع تداخل تحديثات الويدجت
  DateTime?
  _lastWidgetUpdateTime; // 🔥 لمنع استهلاك المعالج بتحديثات الويدجت المتكررة

  // حذفنا _lastRamadanCalculation لأنه لم يكن يُستخدم
  Duration? _cachedTimeUntilRamadan;

  Stream<Map<String, DateTime>> get prayerTimesStream =>
      (_prayerTimesController ??=
              StreamController<Map<String, DateTime>>.broadcast())
          .stream;

  Future<Map<String, DateTime>?> getCurrentPrayerTimes() async {
    final location = await _getCurrentLocation();
    if (location == null) return null;

    _sharedPreferences ??= await SharedPreferences.getInstance();
    final calculationMethod =
        _sharedPreferences!.getString(AppConstants.calculationMethodKey) ??
        AppConstants.defaultCalculationMethod;
    final madhab =
        _sharedPreferences!.getString(AppConstants.madhabKey) ??
        AppConstants.defaultMadhab;

    final now = DateTime.now();
    final date = DateComponents(now.year, now.month, now.day);
    final coordinates = Coordinates(location.latitude, location.longitude);

    CalculationParameters params;
    switch (calculationMethod) {
      case 'egyptian':
        params = CalculationMethod.egyptian.getParameters();
        break;
      case 'turkey':
        params = CalculationMethod.turkey.getParameters();
        break;
      case 'karachi':
        params = CalculationMethod.karachi.getParameters();
        break;
      case 'umm_al_qura':
        params = CalculationMethod.umm_al_qura.getParameters();
        break;
      case 'dubai':
        params = CalculationMethod.dubai.getParameters();
        break;
      case 'kuwait':
        params = CalculationMethod.kuwait.getParameters();
        break;
      case 'qatar':
        params = CalculationMethod.qatar.getParameters();
        break;
      case 'muslim_world_league':
        params = CalculationMethod.muslim_world_league.getParameters();
        break;
      case 'north_america':
        params = CalculationMethod.north_america.getParameters();
        break;
      default:
        params = CalculationMethod.egyptian.getParameters();
    }

    params.madhab = madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    final prayerTimes = PrayerTimes(coordinates, date, params);

    final Map<String, DateTime> times = {
      'fajr': prayerTimes.fajr,
      'sunrise': prayerTimes.sunrise,
      'dhuhr': prayerTimes.dhuhr,
      'asr': prayerTimes.asr,
      'maghrib': prayerTimes.maghrib,
      'isha': prayerTimes.isha,
    };

    _currentPrayerTimes = times;

    _scheduleAthanAlarmsIfNeeded(_currentPrayerTimes!);

    // 🔥 تحديث بيانات الويدجت (Android Home Screen Widget) - تم تفعيل الـ Throttling
    updateWidgetData();

    _prayerTimesController?.add(_currentPrayerTimes!);
    _startUpdateTimer();
    return _currentPrayerTimes;
  }

  /// يزامن بيانات مواقيت الصلاة والمناسبات مع ويدجت الشاشة الرئيسية
  Future<void> updateWidgetData({bool force = false}) async {
    if (MyApp.isAthanShowing) {
      Logger.info("Skipping widget update (Athan is playing)");
      return;
    }

    // ✅ FIX: منع التداخل — إذا كان تحديث سابق جارٍ، نتجاهل الطلب الجديد
    if (_isWidgetUpdating && !force) return;
    _isWidgetUpdating = true;

    try {
      // ✅ FIX: رُفعت المهلة من 5s إلى 20s.
      // السبب: HomeWidget.saveWidgetData() يُنفّذ fsync على القرص لكل قيمة (9 استدعاءات).
      // كل fsync قد يستغرق 500ms-1024ms على أجهزة بطيئة → المجموع يتجاوز 5 ثوانٍ بسهولة.
      await Future.any([
        _performWidgetUpdate(force),
        Future.delayed(const Duration(seconds: 20), () {
          throw TimeoutException("Widget update timed out after 20s");
        })
      ]);
    } catch (e) {
      Logger.error("Failed to update widget data: $e");
      // Restore previously cached text to avoid hanging on "Updating..."
      try {
        final nextPrayerDisplay = await HomeWidget.getWidgetData<String>('flutter.next_prayer_display', defaultValue: "--:--");
        final countdownText = await HomeWidget.getWidgetData<String>('flutter.countdown_text', defaultValue: "--:--");
        
        await HomeWidget.saveWidgetData<String>('flutter.next_prayer_display', nextPrayerDisplay);
        await HomeWidget.saveWidgetData<String>('flutter.countdown_text', countdownText);
        await HomeWidget.updateWidget(name: 'PrayerWidget', androidName: 'PrayerWidget');
      } catch (_) {}
    } finally {
      _isWidgetUpdating = false;
    }
  }

  Future<void> _performWidgetUpdate(bool force) async {
      if (_currentPrayerTimes == null) {
        // 🔥 If we are in a background isolate, we need to populate data first
        await getCurrentPrayerTimes();
        if (_currentPrayerTimes == null) return;
      }

      // 🛡️ Throttling Protection: تحديث الويدجت عملية مكلفة جداً، نكتفي بمرة كل 30 ثانية
      // استثناء: عند تغير "اليوم" (منتصف الليل)، نتجاوز التروتلينج فوراً لتحديث التاريخ الهجري
      final now = DateTime.now();
      final bool isNewDay =
          _lastWidgetUpdateTime == null ||
          now.day != _lastWidgetUpdateTime!.day;

      if (!force && !isNewDay && _lastWidgetUpdateTime != null) {
        if (now.difference(_lastWidgetUpdateTime!) <
            const Duration(seconds: 30)) {
          return;
        }
      }
      _lastWidgetUpdateTime = now;

      final nextPrayerKey = getNextPrayer() ?? 'fajr';
      final nextPrayerTime = getNextPrayerTime();
      final nextPrayerName = _getArabicName(nextPrayerKey);

      final lastPrayerKey = getLastPrayer() ?? 'isha';
      final lastPrayerTime = getLastPrayerTime();
      final lastPrayerName = _getArabicName(lastPrayerKey);
      final lastPrayerInfo =
          "$lastPrayerName ${_formatTimeTo12h(lastPrayerTime)}";

      // حساب العد التنازلي للصلاة القادمة
      String countdownText = "جاري التحديث...";
      if (nextPrayerTime != null) {
        final diff = nextPrayerTime.difference(DateTime.now());
        if (diff.isNegative) {
          countdownText = "جاري التحديث...";
        } else {
          final hours = diff.inHours;
          final minutes = diff.inMinutes % 60;
          countdownText =
              "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}";
        }
      }

      _sharedPreferences ??= await SharedPreferences.getInstance();
      final city =
          _sharedPreferences!
              .getString(AppConstants.selectedCityKey)
              ?.split(',')
              .first
              .trim() ??
          'القاهرة';

      // جلب بيانات التاريخ الهجري والمناسبات
      final hijriAdjustment =
          _sharedPreferences!.getInt('hijri_adjustment') ?? 0;
      final hijriDate = HijriDateService.getHijriDate(now, hijriAdjustment);
      final hijriDateFull = hijriDate['formatted'] as String;

      final eventsService = HomeEventsService();
      final event = eventsService.currentEvent;
      final eventTypeName = event?.type.toString().split('.').last ?? 'none';

      final nextPrayerDisplay =
          "$nextPrayerName ${_formatTimeTo12h(nextPrayerTime)}";

      // حفظ البيانات للويدجت بالمفاتيح المطلوبة بدقة للهيكل الجديد
      if (nextPrayerTime != null) {
        await HomeWidget.saveWidgetData<int>(
          'flutter.next_prayer_timestamp',
          nextPrayerTime.millisecondsSinceEpoch,
        );
      } else {
        await HomeWidget.saveWidgetData<int>(
          'flutter.next_prayer_timestamp',
          0,
        );
      }
      await HomeWidget.saveWidgetData<String>(
        'flutter.next_prayer_name',
        nextPrayerName,
      );
      await HomeWidget.saveWidgetData<String>(
        'flutter.next_prayer_display',
        nextPrayerDisplay,
      );
      await HomeWidget.saveWidgetData<String>(
        'flutter.countdown_text',
        countdownText,
      );
      await HomeWidget.saveWidgetData<String>(
        'flutter.last_prayer_display',
        lastPrayerInfo,
      );
      await HomeWidget.saveWidgetData<String>(
        'flutter.hijri_date_full',
        hijriDateFull,
      );
      await HomeWidget.saveWidgetData<String>('flutter.current_city', city);
      await HomeWidget.saveWidgetData<String>(
        'flutter.today_event_type',
        eventTypeName,
      );

      // طلب تحديث الويدجت من جانب الأندرويد
      await HomeWidget.updateWidget(
        name: 'PrayerWidget',
        androidName: 'PrayerWidget',
      );

      Logger.info(
        "Widget data updated: $nextPrayerName at ${nextPrayerTime.toString()}",
      );
  }

  String _formatTimeTo12h(DateTime? time) {
    if (time == null) return '--:--';
    return DateFormat('h:mm a', 'ar').format(time);
  }

  Future<void> scheduleAllPrayers() async {
    if (_isScheduling) return;
    _isScheduling = true;

    try {
      final location = await _getCurrentLocation();
      if (location == null) return;

      _sharedPreferences ??= await SharedPreferences.getInstance();

      // 🔥 مسح كافة المنبهات القديمة قبل جدولة الجديدة لتجنب امتلاء الذاكرة (الحد الأقصى 500)
      await AthanManager.cancelAllAlarms();

      // We schedule alarms even if Athan is disabled to support silent notifications

      final calculationMethod =
          _sharedPreferences!.getString(AppConstants.calculationMethodKey) ??
          AppConstants.defaultCalculationMethod;
      final madhab =
          _sharedPreferences!.getString(AppConstants.madhabKey) ??
          AppConstants.defaultMadhab;

      final now = DateTime.now();
      final coordinates = Coordinates(location.latitude, location.longitude);

      CalculationParameters params = _getParams(calculationMethod);
      params.madhab = madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;

      // --- Schedule for next 14 days to prevent widget stopping in background ---
      for (int dayOffset = 0; dayOffset <= 14; dayOffset++) {
        final targetDate = now.add(Duration(days: dayOffset));
        final dateComponents = DateComponents(
          targetDate.year,
          targetDate.month,
          targetDate.day,
        );
        final prayerTimes = PrayerTimes(coordinates, dateComponents, params);

        final Map<String, DateTime> times = {
          'fajr': prayerTimes.fajr,
          'sunrise': prayerTimes.sunrise,
          'dhuhr': prayerTimes.dhuhr,
          'asr': prayerTimes.asr,
          'maghrib': prayerTimes.maghrib,
          'isha': prayerTimes.isha,
        };

        final idOffset = dayOffset * 10; // Today: 0, Tomorrow: 10

        times.forEach((name, time) {
          if (time.isAfter(now)) {
            int baseId = _getPrayerId(name);
            AthanManager.scheduleNextAthan(
              alarmId: baseId + idOffset,
              time: time,
              isFajr: name == 'fajr',
              prayerName: _getArabicName(name),
            );
          }
        });
      }
    } catch (e) {
      Logger.error("Failed to schedule prayers: $e");
    } finally {
      _isScheduling = false;
      // ✅ عند إعادة الجدولة، نجبر الويدجت على التحديث فوراً
      updateWidgetData(force: true);
    }
  }

  CalculationParameters _getParams(String method) {
    switch (method) {
      case 'egyptian':
        return CalculationMethod.egyptian.getParameters();
      case 'turkey':
        return CalculationMethod.turkey.getParameters();
      case 'karachi':
        return CalculationMethod.karachi.getParameters();
      case 'umm_al_qura':
        return CalculationMethod.umm_al_qura.getParameters();
      case 'dubai':
        return CalculationMethod.dubai.getParameters();
      case 'kuwait':
        return CalculationMethod.kuwait.getParameters();
      case 'qatar':
        return CalculationMethod.qatar.getParameters();
      case 'muslim_world_league':
        return CalculationMethod.muslim_world_league.getParameters();
      case 'north_america':
        return CalculationMethod.north_america.getParameters();
      default:
        return CalculationMethod.egyptian.getParameters();
    }
  }

  int _getPrayerId(String name) {
    switch (name) {
      case 'fajr':
        return 101;
      case 'dhuhr':
        return 102;
      case 'asr':
        return 103;
      case 'maghrib':
        return 104;
      case 'isha':
        return 105;
      case 'sunrise':
        return 106;
      default:
        return 0;
    }
  }

  void _scheduleAthanAlarmsIfNeeded(Map<String, DateTime> newTimes) {
    // 🔥 تم إلغاء الاستدعاء الدوري للجدولة لمنع الـ Maximum limit reached
    // الجدولة الآن تحدث فقط عند تشغيل التطبيق أو تغيير الإعدادات
  }

  String _getArabicName(String name) {
    switch (name) {
      case 'fajr':
        return 'الفجر';
      case 'sunrise':
        return 'الشروق';
      case 'dhuhr':
        return 'الظهر';
      case 'asr':
        return 'العصر';
      case 'maghrib':
        return 'المغرب';
      case 'isha':
        return 'العشاء';
      default:
        return 'الصلاة';
    }
  }

  Future<LocationSettings?> _getCurrentLocation() async {
    _sharedPreferences ??= await SharedPreferences.getInstance();
    final selectedCity =
        _sharedPreferences!.getString(AppConstants.selectedCityKey) ??
        "Cairo, Egypt";

    double? cachedLat = _sharedPreferences!.getDouble('last_lat');
    double? cachedLng = _sharedPreferences!.getDouble('last_lng');

    if (cachedLat != null && cachedLng != null) {
      return LocationSettings(
        latitude: cachedLat,
        longitude: cachedLng,
        city: selectedCity.split(',').first.trim(),
        country: selectedCity.split(',').last.trim(),
      );
    }

    try {
      // 🛡️ HARDENED: Do NOT use geocoding in background or when waking up for Athan.
      // We strictly rely on cached coordinates or defaults.
    } catch (e) {
      Logger.error("Geocoding Error: $e");
    }

    return LocationSettings(
      latitude: 30.0444,
      longitude: 31.2357,
      city: "Cairo",
      country: "Egypt",
    );
  }

  void _startUpdateTimer() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(
      AppConstants.countdownUpdateInterval,
      (timer) => _updatePrayerTimes(),
    );
  }

  Future<void> _updatePrayerTimes() async => await getCurrentPrayerTimes();

  String? getNextPrayer() {
    if (_currentPrayerTimes == null) return null;
    final now = DateTime.now();
    for (final entry in _currentPrayerTimes!.entries) {
      if (entry.value.isAfter(now)) return entry.key;
    }
    return 'fajr';
  }

  DateTime? getNextPrayerTime() {
    if (_currentPrayerTimes == null) return null;
    final nextPrayer = getNextPrayer();
    final prayerTime = _currentPrayerTimes![nextPrayer];
    if (prayerTime == null) return null;

    final now = DateTime.now();
    // إذا كانت الصلاة المجلوبة (مثل الظهر) قد مرت اليوم، أو كنا في نهاية اليوم وننتقل للفجر
    if (prayerTime.isBefore(now)) {
      return prayerTime.add(const Duration(days: 1));
    }
    return prayerTime;
  }

  Duration? getTimeUntilNextPrayer() {
    final nextTime = getNextPrayerTime();
    return nextTime?.difference(DateTime.now());
  }

  String? getLastPrayer() {
    if (_currentPrayerTimes == null) return null;
    final now = DateTime.now();
    String? last;
    final keys = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];
    for (final key in keys) {
      final time = _currentPrayerTimes![key];
      if (time != null && time.isBefore(now)) {
        last = key;
      } else if (time != null && time.isAfter(now)) {
        break;
      }
    }
    return last ?? 'isha';
  }

  DateTime? getLastPrayerTime() {
    if (_currentPrayerTimes == null) return null;
    final lastPrayer = getLastPrayer();
    final time = _currentPrayerTimes![lastPrayer];
    if (time == null) return null;
    if (time.isAfter(DateTime.now())) {
      return time.subtract(const Duration(days: 1));
    }
    return time;
  }

  Future<Duration?> getTimeUntilRamadan() async {
    final now = DateTime.now();
    _sharedPreferences ??= await SharedPreferences.getInstance();
    final adj = _sharedPreferences!.getInt('hijri_adjustment') ?? 0;

    DateTime start = HijriDateService.getNextRamadanStart(now, adj);
    Duration diff = start.difference(now);

    if (diff.inDays > 350) {
      start = start.subtract(const Duration(days: 354));
      diff = start.difference(now);
    }

    _cachedTimeUntilRamadan = diff;
    return _cachedTimeUntilRamadan;
  }

  void dispose() {
    _updateTimer?.cancel();
    _prayerTimesController?.close();
  }
}

class LocationSettings {
  final double latitude;
  final double longitude;
  final String city;
  final String country;
  LocationSettings({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.country,
  });
}

extension PrayerTimeFormatting on DateTime? {
  String getFormattedTime() =>
      this == null ? '--:--' : DateFormat('h:mm a', 'en_US').format(this!);
}
