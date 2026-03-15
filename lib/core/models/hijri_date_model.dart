class HijriDateModel {
  final int year;
  final int month;
  final int day;
  final String monthNameAr;
  final String monthNameEn;
  final bool isOnlineSynced;

  const HijriDateModel({
    required this.year,
    required this.month,
    required this.day,
    required this.monthNameAr,
    required this.monthNameEn,
    this.isOnlineSynced = false,
  });

  static const List<String> _monthNamesAr = [
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الثاني',
    'جمادى الأولى',
    'جمادى الثانية',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];

  static const List<String> _monthNamesEn = [
    'Muharram',
    'Safar',
    'Rabi\' al-Awwal',
    'Rabi\' al-Thani',
    'Jumada al-Ula',
    'Jumada al-Thania',
    'Rajab',
    'Sha\'ban',
    'Ramadan',
    'Shawwal',
    'Dhu al-Qi\'dah',
    'Dhu al-Hijjah',
  ];

  factory HijriDateModel.create(int year, int month, int day,
      {bool isOnlineSynced = false}) {
    final monthIndex = month.clamp(1, 12) - 1;
    return HijriDateModel(
      year: year,
      month: month,
      day: day,
      monthNameAr: _monthNamesAr[monthIndex],
      monthNameEn: _monthNamesEn[monthIndex],
      isOnlineSynced: isOnlineSynced,
    );
  }

  String toArabicString() => '$day $monthNameAr $year';
  String toEnglishString() => '$day $monthNameEn $year AH';

  HijriDateModel withOffset(int days) {
    // Simple offset for display — real impl adjusts day/month/year
    final adjusted = day + days;
    if (adjusted < 1) {
      final prevMonth = month - 1 < 1 ? 12 : month - 1;
      return HijriDateModel.create(
          prevMonth == 12 ? year - 1 : year, prevMonth, 29 + adjusted,
          isOnlineSynced: isOnlineSynced);
    } else if (adjusted > 30) {
      final nextMonth = month + 1 > 12 ? 1 : month + 1;
      return HijriDateModel.create(
          nextMonth == 1 ? year + 1 : year, nextMonth, adjusted - 30,
          isOnlineSynced: isOnlineSynced);
    }
    return HijriDateModel.create(year, month, adjusted,
        isOnlineSynced: isOnlineSynced);
  }
}
