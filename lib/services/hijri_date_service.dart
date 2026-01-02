import '../utils/logger.dart';

class HijriDateService {
  static const List<String> arabicMonths = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الثاني', 'جمادى الأول', 'جمادى الثاني',
    'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة'
  ];

  static const List<String> arabicWeekdays = [
    'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'
  ];

  // Standard Islamic month lengths
  static const List<int> islamicMonthLengths = [
    30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, 29
  ];

  // Global offset to align with actual moon sightings
  static const int globalOffset = 0;

  // Improved Hijri date calculation with accurate reference
  static Map<String, dynamic> getHijriDate(DateTime dateTime, int adjustment) {
    // Use verified reference: January 1, 2025 = 1 Rajab 1446
    final baseDate = DateTime(2025, 1, 1); // 1 Rajab 1446
    final baseHijriYear = 1446;
    final baseHijriMonth = 7; // Rajab
    final baseHijriDay = 1;
    
    // Calculate days since base date
    final daysSinceBase = dateTime.difference(baseDate).inDays;
    
    // Apply global offset and user adjustment
    final totalOffset = globalOffset + adjustment;
    final adjustedDaysSinceBase = daysSinceBase + totalOffset;
    
    // Approximate Hijri year (354.367 days per year)
    double hijriYearFloat = baseHijriYear + (adjustedDaysSinceBase / 354.367);
    int hijriYear = hijriYearFloat.floor();
    
    // Calculate remaining days after full years
    final daysInFullYears = (hijriYear - baseHijriYear) * 354;
    final remainingDays = adjustedDaysSinceBase - daysInFullYears;
    
    // Calculate month and day using standard Islamic month lengths
    int hijriMonth = baseHijriMonth - 1; // Convert to 0-based
    int hijriDay = baseHijriDay;
    int daysRemaining = remainingDays;
    
    // Move forward through months
    while (daysRemaining > 0) {
      final currentMonthLength = islamicMonthLengths[hijriMonth % 12];
      if (daysRemaining >= currentMonthLength) {
        daysRemaining -= currentMonthLength;
        hijriMonth++;
        if (hijriMonth >= 12) {
          hijriMonth = 0;
          hijriYear++;
        }
      } else {
        hijriDay += daysRemaining;
        daysRemaining = 0;
      }
    }
    
    // Handle backward movement if needed
    while (daysRemaining < 0) {
      hijriMonth--;
      if (hijriMonth < 0) {
        hijriMonth = 11;
        hijriYear--;
      }
      final currentMonthLength = islamicMonthLengths[hijriMonth];
      hijriDay = currentMonthLength + daysRemaining;
      daysRemaining = 0;
    }
    
    // Convert to 1-based month
    hijriMonth++;
    
    // Ensure day is within valid range
    if (hijriDay < 1) {
      hijriDay = 1;
    } else if (hijriDay > islamicMonthLengths[hijriMonth - 1]) {
      hijriDay = islamicMonthLengths[hijriMonth - 1];
    }
    
    final monthName = arabicMonths[hijriMonth - 1];
    final weekdayName = arabicWeekdays[dateTime.weekday % 7];
    
    // Print verification
    Logger.debug('Calculated Hijri Date: $hijriDay $monthName $hijriYear (Original: ${dateTime.day}/${dateTime.month}/${dateTime.year})');
    
    return {
      'year': hijriYear.toString(),
      'month': monthName,
      'day': hijriDay.toString(),
      'weekday': weekdayName,
      'formatted': '$weekdayName، $hijriDay $monthName $hijriYearهـ',
      'monthIndex': hijriMonth,
      'dayIndex': hijriDay,
    };
  }
  
  static bool isRamadan(DateTime dateTime, int adjustment) {
    final hijriDate = getHijriDate(dateTime, adjustment);
    return hijriDate['month'] == 'رمضان';
  }
  
  static bool isAfterRamadan(DateTime dateTime, int adjustment) {
    final hijriDate = getHijriDate(dateTime, adjustment);
    final monthIndex = hijriDate['monthIndex'] as int;
    return monthIndex > 9; // Ramadan is month 9 (index 9 in 1-based)
  }
  
  static bool isBeforeRamadan(DateTime dateTime, int adjustment) {
    final hijriDate = getHijriDate(dateTime, adjustment);
    final monthIndex = hijriDate['monthIndex'] as int;
    return monthIndex < 9; // Ramadan is month 9 (index 9 in 1-based)
  }
  
  static int getDaysUntilRamadan(DateTime dateTime, int adjustment) {
    final hijriDate = getHijriDate(dateTime, adjustment);
    final currentMonth = hijriDate['monthIndex'] as int;
    final currentDay = hijriDate['dayIndex'] as int;
    
    if (currentMonth == 9) {
      return 0; // Already Ramadan
    } else if (currentMonth < 9) {
      // Calculate days until Ramadan in same year using standard month lengths
      int daysUntilRamadan = 0;
      // Days remaining in current month
      final currentMonthLength = islamicMonthLengths[currentMonth - 1];
      daysUntilRamadan += (currentMonthLength - currentDay);
      // Days for full months until Ramadan
      for (int month = currentMonth; month < 8; month++) {
        daysUntilRamadan += islamicMonthLengths[month % 12];
      }
      return daysUntilRamadan;
    } else {
      // Ramadan is in next year
      int daysUntilRamadan = 0;
      // Days remaining in current month
      final currentMonthLength = islamicMonthLengths[currentMonth - 1];
      daysUntilRamadan += (currentMonthLength - currentDay);
      // Days for remaining months in current year
      for (int month = currentMonth; month < 12; month++) {
        daysUntilRamadan += islamicMonthLengths[month % 12];
      }
      // Days for months until Ramadan next year
      for (int month = 0; month < 8; month++) {
        daysUntilRamadan += islamicMonthLengths[month];
      }
      return daysUntilRamadan;
    }
  }
  
  static DateTime getNextRamadanStart(DateTime dateTime, int adjustment) {
    final daysUntil = getDaysUntilRamadan(dateTime, adjustment);
    return dateTime.add(Duration(days: daysUntil));
  }
  
  static DateTime getCurrentRamadanStart(DateTime dateTime, int adjustment) {
    final hijriDate = getHijriDate(dateTime, adjustment);
    final currentYear = int.parse(hijriDate['year'] as String);
    
    // Approximate Ramadan start date
    // This is a simplified calculation - in production, use a proper Hijri library
    final ramadanStart = DateTime(2023, 7, 15).add(Duration(days: (currentYear - 1445) * 354));
    return ramadanStart;
  }
}
