import 'package:hijri/hijri_calendar.dart';

class IslamicEvent {
  final String name;
  final int month;
  final int day;

  const IslamicEvent({
    required this.name,
    required this.month,
    required this.day,
  });

  static const List<IslamicEvent> allEvents = [
    IslamicEvent(name: 'رأس السنة الهجرية', month: 1, day: 1),
    IslamicEvent(name: 'يوم عاشوراء', month: 1, day: 10),
    IslamicEvent(name: 'المولد النبوي الشريف', month: 3, day: 12),
    IslamicEvent(name: 'الإسراء والمعراج', month: 7, day: 27),
    IslamicEvent(name: 'ليلة النصف من شعبان', month: 8, day: 15),
    IslamicEvent(name: 'بداية شهر رمضان', month: 9, day: 1),
    IslamicEvent(name: 'غزوة بدر', month: 9, day: 17),
    IslamicEvent(name: 'فتح مكة', month: 9, day: 20),
    IslamicEvent(name: 'ليلة القدر (بداية العشر الأواخر)', month: 9, day: 21),
    IslamicEvent(name: 'عيد الفطر المبارك', month: 10, day: 1),
    IslamicEvent(name: 'بداية ذي الحجة', month: 12, day: 1),
    IslamicEvent(name: 'يوم عرفة', month: 12, day: 9),
    IslamicEvent(name: 'عيد الأضحى المبارك', month: 12, day: 10),
    IslamicEvent(name: 'أيام التشريق', month: 12, day: 11),
    IslamicEvent(name: 'أيام التشريق', month: 12, day: 12),
    IslamicEvent(name: 'أيام التشريق', month: 12, day: 13),
  ];

  DateTime toGregorian(int hYear, int offset) {
    final hDate = HijriCalendar();
    hDate.hYear = hYear;
    hDate.hMonth = month;
    hDate.hDay = day;
    return hDate.hijriToGregorian(hYear, month, day).subtract(Duration(days: offset));
  }
}
