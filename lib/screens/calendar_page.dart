import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import '../services/hijri_date_service.dart';
import '../providers/settings_provider.dart';
import '../data/islamic_occasions.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // المناسبة المختارة حالياً (null = لا توجد مناسبة لهذا اليوم)
  IslamicOccasion? _selectedOccasion;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController!.addListener(() {
      if (!_tabController!.indexIsChanging) setState(() {});
    });

    // Normalize selected day to midnight so TimeOfDay doesn't break equality checks
    final now = DateTime.now();
    _focusedDay = DateTime(now.year, now.month, now.day);
    _selectedDay = _focusedDay;
    HijriCalendar.setLocal('ar');

    // احسب مناسبة اليوم الحالي عند البداية
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateOccasionForSelectedDay(_selectedDay!);
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  /// يحدّث [_selectedOccasion] بناءً على اليوم المختار
  void _updateOccasionForSelectedDay(DateTime gregorianDay) {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final hijriData = HijriDateService.getHijriDate(
      gregorianDay,
      settingsProvider.hijriAdjustment,
    );
    final int hMonth = hijriData['monthIndex'];
    final int hDay = hijriData['dayIndex'] as int;
    final occasion = IslamicOccasions.getOccasion(hMonth, hDay);
    setState(() => _selectedOccasion = occasion);
  }

  void _moveMonth({required bool isNext}) {
    setState(() {
      if (_tabController!.index == 0) {
        final settingsProvider = Provider.of<SettingsProvider>(
          context,
          listen: false,
        );
        final hijriData = HijriDateService.getHijriDate(
          _focusedDay,
          settingsProvider.hijriAdjustment,
        );

        int hYear = int.parse(hijriData['year']);
        int hMonth = hijriData['monthIndex'];

        if (isNext) {
          if (hMonth == 12) {
            hMonth = 1;
            hYear++;
          } else {
            hMonth++;
          }
        } else {
          if (hMonth == 1) {
            hMonth = 12;
            hYear--;
          } else {
            hMonth--;
          }
        }

        var hDate = HijriCalendar();
        hDate.hYear = hYear;
        hDate.hMonth = hMonth;
        hDate.hDay = 1;
        _focusedDay = hDate
            .hijriToGregorian(hYear, hMonth, 1)
            .subtract(Duration(days: settingsProvider.hijriAdjustment));
      } else {
        _focusedDay = DateTime(
          _focusedDay.year,
          isNext ? _focusedDay.month + 1 : _focusedDay.month - 1,
          1,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_tabController == null) return const SizedBox.shrink();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDarkMode
            ? const Color(0xFF121212)
            : const Color(0xFFF5F5F0),
        appBar: AppBar(
          backgroundColor: isDarkMode ? Colors.black : Colors.blue,
          title: Text(
            'التقويم',
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
            tabs: const [
              Tab(text: "الهجري"),
              Tab(text: "الميلادي"),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildCustomHeader(isDarkMode),
            _buildDaysOfWeekHeader(isDarkMode),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildHijriCustomGridView(isDarkMode),
                  _buildGregorianView(isDarkMode),
                ],
              ),
            ),
            if (_selectedDay != null)
              _buildSelectedDateCard(_selectedDay!, isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomHeader(bool isDarkMode) {
    String title = "";
    if (_tabController!.index == 0) {
      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );
      final hijriData = HijriDateService.getHijriDate(
        _focusedDay,
        settingsProvider.hijriAdjustment,
      );
      title = "${hijriData['month']} ${hijriData['year']}";
    } else {
      const months = [
        "يناير",
        "فبراير",
        "مارس",
        "أبريل",
        "مايو",
        "يونيو",
        "يوليو",
        "أغسطس",
        "سبتمبر",
        "أكتوبر",
        "نوفمبر",
        "ديسمبر",
      ];
      title = "${months[_focusedDay.month - 1]} ${_focusedDay.year}";
    }

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(
              Icons.chevron_left,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
            onPressed: () => _moveMonth(isNext: false),
          ),
          Text(
            title,
            style: GoogleFonts.tajawal(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
            onPressed: () => _moveMonth(isNext: true),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysOfWeekHeader(bool isDarkMode) {
    const days = [
      "السبت",
      "الأحد",
      "الاثنين",
      "الثلاثاء",
      "الأربعاء",
      "الخميس",
      "الجمعة",
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: days
            .map(
              (day) => Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: GoogleFonts.tajawal(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.grey : Colors.black54,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildHijriCustomGridView(bool isDarkMode) {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );

    // استخدام _focusedDay مع التعديل للحصول على الشهر والسنة الصحيحين المعروضين حالياً
    final focusedHijriData = HijriDateService.getHijriDate(
      _focusedDay,
      settingsProvider.hijriAdjustment,
    );
    int hYear = int.parse(focusedHijriData['year']);
    int hMonth = focusedHijriData['monthIndex'];

    // الحصول على أول يوم في الشهر الهجري المعدل
    var hDate = HijriCalendar();
    hDate.hYear = hYear;
    hDate.hMonth = hMonth;
    hDate.hDay = 1;
    var firstDayOfMonth = hDate
        .hijriToGregorian(hYear, hMonth, 1)
        .subtract(Duration(days: settingsProvider.hijriAdjustment));

    // حساب الإزاحة بناءً على أن السبت هو 6 في DateTime.weekday والأسبوع يبدأ بالسبت في تصميمنا
    // الأيام في Flutter: Mon=1, Tue=2, Wed=3, Thu=4, Fri=5, Sat=6, Sun=7
    int offset;
    if (firstDayOfMonth.weekday == DateTime.saturday) {
      offset = 0;
    } else if (firstDayOfMonth.weekday == DateTime.sunday) {
      offset = 1;
    } else {
      offset = firstDayOfMonth.weekday + 1;
    }

    // استخدام getMonthLength() للشهر الهجري المعدل
    int daysInMonth = hDate.getDaysInMonth(hYear, hMonth);

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
      ),
      itemCount: daysInMonth + offset,
      itemBuilder: (context, index) {
        if (index < offset) return const SizedBox.shrink();

        int dayNo = index - offset + 1;

        // إنشاء HijriCalendar جديد لكل يوم مع تطبيق التعديل
        var dayHijri = HijriCalendar();
        dayHijri.hYear = hYear;
        dayHijri.hMonth = hMonth;
        dayHijri.hDay = dayNo;

        // تطبيق التعديل عكسياً للحصول على التاريخ الميلادي الصحيح
        DateTime currentGregorian = dayHijri
            .hijriToGregorian(hYear, hMonth, dayNo)
            .subtract(Duration(days: settingsProvider.hijriAdjustment));

        // التحقق إذا كان هذا اليوم هو اليوم الحالي بعد تطبيق التعديل
        DateTime todayMidnight = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        );
        bool isToday = currentGregorian.isAtSameMomentAs(todayMidnight);

        // تحديد ما إذا كان هذا اليوم هو اليوم المحدد حاليًا
        bool isSelected = false;
        if (_selectedDay != null) {
          isSelected = currentGregorian.isAtSameMomentAs(_selectedDay!);
        }

        // فحص وجود مناسبة لهذا اليوم
        final bool hasOccasion = IslamicOccasions.hasOccasion(hMonth, dayNo);

        return GestureDetector(
          onTap: () {
            final normalizedDay = DateTime(
              currentGregorian.year,
              currentGregorian.month,
              currentGregorian.day,
            );
            setState(() {
              _selectedDay = normalizedDay;
              _focusedDay = _selectedDay!;
            });
            _updateOccasionForSelectedDay(normalizedDay);
          },
          child: _customDayItem(
            dayNo.toString(),
            isDarkMode,
            isSelected: isSelected,
            isToday: isToday,
            hasOccasion: hasOccasion,
          ),
        );
      },
    );
  }

  Widget _buildGregorianView(bool isDarkMode) {
    return TableCalendar(
      locale: 'ar_SA',
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2045, 12, 31),
      focusedDay: _focusedDay,
      startingDayOfWeek: StartingDayOfWeek.saturday,
      headerVisible: false,
      daysOfWeekVisible: false,
      calendarFormat: CalendarFormat.month,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
        _updateOccasionForSelectedDay(selectedDay);
      },
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        todayDecoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        selectedDecoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _customDayItem(
    String text,
    bool isDarkMode, {
    required bool isSelected,
    required bool isToday,
    required bool hasOccasion,
  }) {
    return Container(
      margin: const EdgeInsets.all(3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected
            ? Colors.blue
            : (isToday
                  ? Colors.blue.withValues(alpha: 0.2)
                  : Colors.transparent),
        border: isToday ? Border.all(color: Colors.blue, width: 1) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text,
            style: GoogleFonts.tajawal(
              fontSize: 13,
              color: isSelected
                  ? Colors.white
                  : (isDarkMode ? Colors.white : Colors.black),
              fontWeight: isSelected || isToday
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
          // 🔶 مؤشر المناسبة — نقطة ذهبية صغيرة تحت الرقم
          if (hasOccasion)
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.85)
                    : const Color(0xFFE8A800), // ذهبي
              ),
            )
          else
            const SizedBox(height: 5), // مسافة للتوازن البصري
        ],
      ),
    );
  }

  Widget _buildSelectedDateCard(DateTime date, bool isDarkMode) {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final hijriData = HijriDateService.getHijriDate(
      date,
      settingsProvider.hijriAdjustment,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ─── أيقونة التقويم ───
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _selectedOccasion != null
                      ? const Color(0xFFE8A800).withValues(alpha: 0.12)
                      : Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _selectedOccasion != null
                      ? Icons.star_rounded
                      : Icons.event_available,
                  color: _selectedOccasion != null
                      ? const Color(0xFFE8A800)
                      : Colors.blue,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              // ─── نصوص التاريخ والمناسبة ───
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // التاريخ الهجري
                    Text(
                      hijriData['formatted'],
                      style: GoogleFonts.tajawal(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.amber[200] : Colors.blue[900],
                      ),
                    ),
                    // التاريخ الميلادي
                    Text(
                      "${_getDayName(date.weekday)}، ${date.day}/${date.month}/${date.year} م",
                      style: GoogleFonts.tajawal(
                        fontSize: 13,
                        color: isDarkMode ? Colors.white70 : Colors.grey[700],
                      ),
                    ),
                    // ─── المناسبة (مع أنيميشن FadeIn/Out) ───
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SizeTransition(
                          sizeFactor: animation,
                          alignment: AlignmentDirectional.topStart,
                          child: child,
                        ),
                      ),
                      child: _selectedOccasion != null
                          ? Padding(
                              key: ValueKey(_selectedOccasion!.primaryName),
                              padding: const EdgeInsets.only(top: 8),
                              child: GestureDetector(
                                onTap: () => _showOccasionDialog(_selectedOccasion!),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8A800)
                                        .withValues(alpha: 0.13),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFE8A800)
                                          .withValues(alpha: 0.4),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.brightness_5_rounded,
                                        color: Color(0xFFE8A800),
                                        size: 15,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          _selectedOccasion!.primaryName,
                                          style: GoogleFonts.tajawal(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: isDarkMode
                                                ? const Color(0xFFFFD54F)
                                                : const Color(0xFF7A5800),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.info_outline_rounded,
                                        size: 13,
                                        color: isDarkMode
                                            ? const Color(0xFFFFD54F)
                                                .withValues(alpha: 0.7)
                                            : const Color(0xFF7A5800)
                                                .withValues(alpha: 0.6),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(key: ValueKey('empty')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDayName(int day) {
    const days = [
      "الاثنين",
      "الثلاثاء",
      "الأربعاء",
      "الخميس",
      "الجمعة",
      "السبت",
      "الأحد",
    ];
    return days[day - 1];
  }

  /// يعرض نافذة حوار بمعلومات تثقيفية عن المناسبة المختارة.
  void _showOccasionDialog(IslamicOccasion occasion) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8A800),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  occasion.primaryName,
                  style: GoogleFonts.tajawal(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.amber[200] : const Color(0xFF7A5800),
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            occasion.description,
            style: GoogleFonts.tajawal(
              fontSize: 14,
              height: 1.7,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE8A800),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFFE8A800), width: 1),
                ),
              ),
              child: Text(
                'إغلاق',
                style: GoogleFonts.tajawal(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
