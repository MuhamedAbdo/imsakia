import 'dart:math';

class HijriDateService {
  static const List<String> arabicMonths = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الثاني', 'جمادى الأول', 'جمادى الثاني',
    'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة'
  ];

  static const List<String> arabicWeekdays = [
    'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'
  ];

  // Simple approximation for Hijri date calculation
  static Map<String, dynamic> getHijriDate(DateTime dateTime, int adjustment) {
    // This is a simplified calculation - for production, use a proper Hijri library
    final baseDate = DateTime(2024, 7, 11); // Approximate start of Hijri year 1445
    
    // Calculate approximate Hijri year
    final daysSinceBase = dateTime.difference(baseDate).inDays;
    int hijriYear = 1445 + (daysSinceBase / 354).floor();
    
    // Calculate approximate month and day
    final dayOfYear = (daysSinceBase % 354) + 200; // Approximate
    
    int hijriMonth = (dayOfYear / 29.5).floor();
    int hijriDay = (dayOfYear % 29.5).floor() + 1;
    
    // Apply adjustment
    hijriDay += adjustment;
    
    // Handle month overflow
    if (hijriDay > 30) {
      hijriDay -= 30;
      hijriMonth++;
    }
    if (hijriMonth > 11) {
      hijriMonth = 0;
      hijriYear++;
    }
    
    // Handle day underflow
    if (hijriDay < 1) {
      hijriDay += 30;
      hijriMonth--;
    }
    if (hijriMonth < 0) {
      hijriMonth = 11;
      hijriYear--;
    }
    
    final monthName = arabicMonths[hijriMonth];
    final weekdayName = arabicWeekdays[dateTime.weekday % 7];
    
    return {
      'year': hijriYear.toString(),
      'month': monthName,
      'day': hijriDay.toString(),
      'weekday': weekdayName,
      'formatted': '$weekdayName، $hijriDay $monthName $hijriYearهـ',
    };
  }
  
  static bool isRamadan(DateTime dateTime, int adjustment) {
    final hijriDate = getHijriDate(dateTime, adjustment);
    return hijriDate['month'] == 'رمضان';
  }
  
  static bool isAfterRamadan(DateTime dateTime, int adjustment) {
    final hijriDate = getHijriDate(dateTime, adjustment);
    return hijriDate['month'] != 'رمضان';
  }
}
