import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/settings_provider.dart';
import '../providers/hijri_calendar_provider.dart';


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
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _moveMonth({required bool isNext, int offset = 0}) {
    setState(() {
      if (_tabController!.index == 0) {
        final hDateNow = HijriCalendar.fromDate(_focusedDay.add(Duration(days: offset)));
        int hYear = hDateNow.hYear;
        int hMonth = hDateNow.hMonth;

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
        _focusedDay = hDate.hijriToGregorian(hYear, hMonth, 1).subtract(Duration(days: offset));
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
    final settings = Provider.of<SettingsProvider>(context);
    final offset = settings.hijriBaseOffset;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDarkMode
            ? const Color(0xFF121212)
            : const Color(0xFFF7F8FA),
        appBar: AppBar(
          centerTitle: true,
          automaticallyImplyLeading: true,
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_forward_ios),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
          title: Text(
            'التقويم',
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
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
            _buildCustomHeader(isDarkMode, offset),
            _buildDaysOfWeekHeader(isDarkMode),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildHijriCustomGridView(isDarkMode, offset),
                  _buildGregorianView(isDarkMode),
                ],
              ),
            ),
            if (_selectedDay != null)
              _buildSelectedDateCard(_selectedDay!, isDarkMode, offset),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomHeader(bool isDarkMode, int offset) {
    String title = "";
    if (_tabController!.index == 0) {
      final hDateNow = HijriCalendar.fromDate(_focusedDay.add(Duration(days: offset)));
      title = "${hDateNow.longMonthName} ${hDateNow.hYear}";
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
            onPressed: () => _moveMonth(isNext: false, offset: offset),
          ),
          Text(
            title,
            style: GoogleFonts.tajawal(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : const Color(0xFF546E7A),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
            onPressed: () => _moveMonth(isNext: true, offset: offset),
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

  Widget _buildHijriCustomGridView(bool isDarkMode, int offset) {
    final hijriProvider = Provider.of<HijriCalendarProvider>(context);
    // Current Hijri date with offset
    final hDateNow = HijriCalendar.fromDate(_focusedDay.add(Duration(days: offset)));
    int hYear = hDateNow.hYear;
    int hMonth = hDateNow.hMonth;

    // First day of the Hijri month (accounting for offset to find the Gregorian equivalent)
    var hDate = HijriCalendar();
    hDate.hYear = hYear;
    hDate.hMonth = hMonth;
    hDate.hDay = 1;
    var firstDayOfMonth = hDate.hijriToGregorian(hYear, hMonth, 1).subtract(Duration(days: offset));

    // Calculate grid shift: designing for week starting Saturday (6)
    int gridShift;
    if (firstDayOfMonth.weekday == DateTime.saturday) {
      gridShift = 0;
    } else if (firstDayOfMonth.weekday == DateTime.sunday) {
      gridShift = 1;
    } else {
      gridShift = firstDayOfMonth.weekday + 1;
    }

    int daysInMonth = hDate.getDaysInMonth(hYear, hMonth);

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
      ),
      itemCount: daysInMonth + gridShift,
      itemBuilder: (context, index) {
        if (index < gridShift) return const SizedBox.shrink();

        int dayNo = index - gridShift + 1;

        // Gregorian date for this specific Hijri day (with offset adjustment)
        DateTime currentGregorian = hDate.hijriToGregorian(hYear, hMonth, dayNo).subtract(Duration(days: offset));
        
        // Detect Islamic Event
        bool hasEvent = hijriProvider.getEventForDate(currentGregorian, offset) != null;

        DateTime todayMidnight = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        );
        bool isToday = currentGregorian.isAtSameMomentAs(todayMidnight);

        bool isSelected = false;
        if (_selectedDay != null) {
          isSelected = currentGregorian.isAtSameMomentAs(_selectedDay!);
        }

        return GestureDetector(
          onTap: () => setState(() {
            _selectedDay = DateTime(
              currentGregorian.year,
              currentGregorian.month,
              currentGregorian.day,
            );
            _focusedDay = _selectedDay!;
          }),
          child: _customDayItem(
            dayNo.toString(),
            isDarkMode,
            isSelected: isSelected,
            isToday: isToday,
            hasEvent: hasEvent,
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
      onDaySelected: (selectedDay, focusedDay) => setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      }),
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
    required bool hasEvent,
  }) {
    return Container(
      margin: const EdgeInsets.all(4),
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
              color: isSelected
                  ? Colors.white
                  : (isDarkMode ? Colors.white : Colors.black),
              fontWeight: isSelected || isToday
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
          if (hasEvent && !isSelected)
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedDateCard(DateTime date, bool isDarkMode, int offset) {
    final hijriProvider = Provider.of<HijriCalendarProvider>(context, listen: false);
    final hDateNow = HijriCalendar.fromDate(date.add(Duration(days: offset)));
    final event = hijriProvider.getEventForDate(date, offset);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDarkMode
                  ? Colors.black54
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDarkMode ? Colors.white10 : Colors.grey.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                event != null ? Icons.star : Icons.event_available,
                color: event != null ? Colors.amber : Colors.blue,
                size: 28,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (event != null)
                    Text(
                      event.name,
                      style: GoogleFonts.tajawal(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  Text(
                    "${hDateNow.hDay} ${hDateNow.longMonthName} ${hDateNow.hYear}",
                    style: GoogleFonts.tajawal(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.amber[200] : Colors.blue[900],
                    ),
                  ),
                  Text(
                    "${_getDayName(date.weekday)}، ${date.day}/${date.month}/${date.year} م",
                    style: GoogleFonts.tajawal(
                      fontSize: 13,
                      color: isDarkMode ? Colors.white70 : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
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
}
