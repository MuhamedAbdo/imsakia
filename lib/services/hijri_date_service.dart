import 'package:hijri/hijri_calendar.dart';
import '../utils/logger.dart';

class HijriDateService {
  static const List<String> arabicMonths = [
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الثاني',
    'جمادى الأول',
    'جمادى الثاني',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];

  static const List<String> arabicWeekdays = [
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
  ];

  /// تحويل التاريخ الميلادي إلى هجري باستخدام مكتبة hijri
  static Map<String, dynamic> getHijriDate(DateTime dateTime, int adjustment) {
    var hDate = HijriCalendar.fromDate(dateTime);

    // تطبيق التعديل يدويًا إذا وجد (Adjustment)
    if (adjustment != 0) {
      hDate = HijriCalendar.fromDate(dateTime.add(Duration(days: adjustment)));
    }

    final hijriDay = hDate.hDay;
    final hijriMonthIndex = hDate.hMonth; // 1-based
    final hijriYear = hDate.hYear;

    final monthName = arabicMonths[hijriMonthIndex - 1];
    // مكتبة hijri تعطي اليوم رقمياً (1 للأحد، 2 للاثنين...)
    final weekdayName = arabicWeekdays[dateTime.weekday % 7];

    Logger.debug('Calculated Hijri Date: $hijriDay $monthName $hijriYear');

    return {
      'year': hijriYear.toString(),
      'month': monthName,
      'day': hijriDay.toString(),
      'weekday': weekdayName,
      'formatted': '$weekdayName، $hijriDay $monthName $hijriYearهـ',
      'monthIndex': hijriMonthIndex,
      'dayIndex': hijriDay,
    };
  }

  static bool isRamadan(DateTime dateTime, int adjustment) {
    final hijriDate = getHijriDate(dateTime, adjustment);
    return hijriDate['monthIndex'] == 9;
  }

  static int getDaysUntilRamadan(DateTime dateTime, int adjustment) {
    final hijriDate = getHijriDate(dateTime, adjustment);
    final currentMonth = hijriDate['monthIndex'] as int;
    final currentYear = int.parse(hijriDate['year']);

    if (currentMonth == 9) return 0;

    var ramadanStart = HijriCalendar();
    
    // لو كنا قبل رمضان في نفس السنة أو بعده (للسنة القادمة)
    ramadanStart.hYear = (currentMonth < 9) ? currentYear : currentYear + 1;
    ramadanStart.hMonth = 9;
    ramadanStart.hDay = 1;

    // نستخدم تحويل المكتبة لمعرفة الفرق بالأيام الميلادية
    return ramadanStart
        .hijriToGregorian(ramadanStart.hYear, 9, 1)
        .difference(dateTime)
        .inDays;
  }

  static DateTime getNextRamadanStart(DateTime dateTime, int adjustment) {
    final hijriDate = getHijriDate(dateTime, adjustment);
    int currentYear = int.parse(hijriDate['year']);
    int currentMonth = hijriDate['monthIndex'];

    var ramadanStart = HijriCalendar();
    ramadanStart.hYear = (currentMonth >= 9) ? currentYear + 1 : currentYear;
    ramadanStart.hMonth = 9;
    ramadanStart.hDay = 1;

    return ramadanStart.hijriToGregorian(ramadanStart.hYear, 9, 1);
  }
}