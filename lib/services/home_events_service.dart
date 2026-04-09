import 'package:flutter/foundation.dart';
import 'package:hijri/hijri_calendar.dart';

enum EventType {
  adhaCountdown,
  arafah,
  eidAdha,
  ramadanCountdown,
  ramadan,
  none
}

class EventData {
  final EventType type;
  final String title;
  final String subtitle;
  final String imagePath;
  final bool showCountdown;

  EventData({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.imagePath,
    this.showCountdown = false,
  });
}

class HomeEventsService extends ChangeNotifier {
  HijriCalendar? _debugDate;
  EventData? _currentEvent;
  
  EventData? get currentEvent => _currentEvent;
  bool get isDebugMode => _debugDate != null;

  HomeEventsService() {
    calculateCurrentEvent(); 
  }

  /// Sets a specific Hijri date for testing.
  /// Format: year, month, day (e.g., 1445, 12, 9)
  void setDebugDate(int hYear, int hMonth, int hDay) {
    _debugDate = HijriCalendar();
    _debugDate!.hYear = hYear;
    _debugDate!.hMonth = hMonth;
    _debugDate!.hDay = hDay;
    calculateCurrentEvent();
    notifyListeners();
  }

  /// Clears debug mode and returns to real time.
  void clearDebugMode() {
    _debugDate = null;
    calculateCurrentEvent();
    notifyListeners();
  }

  /// Recalculates the event based on the latest date (real or debug).
  void refresh() {
    calculateCurrentEvent();
    notifyListeners();
  }

  void calculateCurrentEvent() {
    final HijriCalendar now = _debugDate ?? HijriCalendar.now();
    
    final int day = now.hDay;
    final int month = now.hMonth;

    // 1. Day of Arafah (9 Dhu al-Hijjah) - 🔥 أولوية قصوى
    if (month == 12 && day == 9) {
      _currentEvent = EventData(
        type: EventType.arafah,
        title: 'يوم عرفة',
        subtitle: 'وقفة عرفات - لبيك اللهم لبيك',
        imagePath: 'assets/images/events/kaaba.png',
        showCountdown: false,
      );
      return;
    }

    // 2. Eid Days (10, 11, 12, 13 Dhu al-Hijjah) - 🔥 أولوية قصوى
    if (month == 12 && day >= 10 && day <= 13) {
      String subtitle = 'أيام تشريق مباركة';
      if (day == 10) subtitle = 'عيد الأضحى المبارك - كل عام وأنتم بخير';
      if (day == 11) subtitle = 'عيد الأضحى - يوم القَرّ';

      _currentEvent = EventData(
        type: EventType.eidAdha,
        title: 'عيد أضحى مبارك',
        subtitle: subtitle,
        imagePath: 'assets/images/events/kaaba.png',
        showCountdown: false,
      );
      return;
    }

    // 3. Ramadan (1 - 30 Ramadan)
    if (month == 9) {
      _currentEvent = EventData(
        type: EventType.ramadan,
        title: 'رمضان كريم',
        subtitle: 'نسأل الله أن يتقبل منا ومنكم',
        imagePath: 'assets/images/events/crescent.png',
        showCountdown: false,
      );
      return;
    }

    // 4. Ramadan Countdown
    if ((month == 12 && day >= 14) || (month < 9)) {
       _currentEvent = EventData(
        type: EventType.ramadanCountdown,
        title: 'باقي على شهر رمضان المبارك',
        subtitle: 'اللهم بلغنا رمضان وبارك لنا فيه',
        imagePath: 'assets/images/events/crescent.png',
        showCountdown: true,
      );
      return;
    }

    // 5. Eid al-Adha Countdown - 🔥 آخر خيار (الوضع الافتراضي لباقي السنة)
    _currentEvent = EventData(
      type: EventType.adhaCountdown,
      title: 'باقي على عيد الأضحى المبارك',
      subtitle: 'عشر ذي الحجة قادمة',
      imagePath: 'assets/images/events/sheep.png',
      showCountdown: true,
    );
  }

  Duration getRemainingDurationToTarget() {
    final HijriCalendar now = _debugDate ?? HijriCalendar.now();
    
    // Create target dates based on type
    final target = HijriCalendar();
    target.hYear = now.hYear;

    if (_currentEvent?.type == EventType.adhaCountdown) {
      // إذا كنا في ذي الحجة وتجاوزنا اليوم العاشر، نحسب للسنة القادمة
      if (now.hMonth == 12 && now.hDay >= 10) {
        target.hYear++;
      }
      target.hMonth = 12;
      target.hDay = 10;
    } else if (_currentEvent?.type == EventType.ramadanCountdown) {
      if (now.hMonth > 9 || (now.hMonth == 12 && now.hDay >= 14)) {
        target.hYear++;
      }
      target.hMonth = 9;
      target.hDay = 1;
    } else {
      return Duration.zero;
    }

    // Convert to Gregorian to get exact duration
    final targetDate = target.hijriToGregorian(target.hYear, target.hMonth, target.hDay);
    
    // For debug mode, we simulate the "now" as the start of that Hijri day
    final simulatedNow = _debugDate != null 
        ? _debugDate!.hijriToGregorian(_debugDate!.hYear, _debugDate!.hMonth, _debugDate!.hDay)
        : DateTime.now();
    
    return targetDate.difference(simulatedNow);
  }
}
