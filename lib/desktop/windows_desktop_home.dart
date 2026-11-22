import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/settings_provider.dart';
import '../services/prayer_times_service.dart';
import '../services/hijri_date_service.dart';
import '../services/bukhari_json_service.dart';
import '../widgets/event_card_widget.dart';
import '../features/quran_madinah/ui/index_screen.dart';
import '../features/quran_madinah/ui/mushaf_screen.dart';

/// Desktop Home Dashboard for Windows.
/// Redesigned to make optimal use of desktop screen space with balanced spacing,
/// horizontal prayer times, rich date/occasion display, and compact desktop cards.
class WindowsDesktopHome extends StatefulWidget {
  final void Function(int sectionIndex)? onNavigateToSection;

  const WindowsDesktopHome({
    super.key,
    this.onNavigateToSection,
  });

  @override
  State<WindowsDesktopHome> createState() => _WindowsDesktopHomeState();
}

class _WindowsDesktopHomeState extends State<WindowsDesktopHome> {
  Map<String, DateTime>? _prayerTimes;
  String? _nextPrayer;
  Duration? _timeUntilNextPrayer;
  Timer? _countdownTimer;

  Map<String, dynamic>? _cachedHijriDateMap;
  DateTime? _cachedHijriDateDay;
  int? _cachedHijriAdjustment;

  Map<String, dynamic> _getHijriDateMap(int hijriAdjustment) {
    final now = DateTime.now();
    if (_cachedHijriDateMap == null ||
        _cachedHijriDateDay == null ||
        _cachedHijriDateDay!.year != now.year ||
        _cachedHijriDateDay!.month != now.month ||
        _cachedHijriDateDay!.day != now.day ||
        _cachedHijriAdjustment != hijriAdjustment) {
      _cachedHijriDateDay = DateTime(now.year, now.month, now.day);
      _cachedHijriAdjustment = hijriAdjustment;
      _cachedHijriDateMap = HijriDateService.getHijriDate(now, hijriAdjustment);
    }
    return _cachedHijriDateMap!;
  }

  @override
  void initState() {
    super.initState();
    _loadPrayerTimes();
    _startCountdownTimer();
  }

  Future<void> _loadPrayerTimes() async {
    final times = await PrayerTimesService.instance.getCurrentPrayerTimes();
    if (mounted && times != null) {
      setState(() {
        _prayerTimes = times;
        _nextPrayer = PrayerTimesService.instance.getNextPrayer();
        _timeUntilNextPrayer =
            PrayerTimesService.instance.getTimeUntilNextPrayer();
      });
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _nextPrayer = PrayerTimesService.instance.getNextPrayer();
        _timeUntilNextPrayer =
            PrayerTimesService.instance.getTimeUntilNextPrayer();
      });

      if (_timeUntilNextPrayer != null && _timeUntilNextPrayer!.isNegative) {
        _timeUntilNextPrayer = Duration.zero;
        _loadPrayerTimes();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _getHeaderImage() {
    switch (_nextPrayer) {
      case 'fajr':
        return 'assets/images/fajr_dawn.png';
      case 'dhuhr':
        return 'assets/images/dhuhr_noon.png';
      case 'asr':
        return 'assets/images/asr_afternoon.png';
      case 'maghrib':
        return 'assets/images/maghrib_sunset.png';
      default:
        return 'assets/images/isha_night.png';
    }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null || duration.isNegative) {
      return "00:00:00";
    }
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    final s = duration.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _getPrayerName(String key) {
    const map = {
      'fajr': 'الفجر',
      'sunrise': 'الشروق',
      'dhuhr': 'الظهر',
      'asr': 'العصر',
      'maghrib': 'المغرب',
      'isha': 'العشاء',
    };
    return map[key] ?? 'الصلاة';
  }

  IconData _getPrayerIcon(String key) {
    switch (key) {
      case 'fajr':
        return Icons.wb_twilight;
      case 'sunrise':
        return Icons.wb_sunny_outlined;
      case 'maghrib':
        return Icons.nightlight_round;
      case 'isha':
        return Icons.nights_stay;
      default:
        return Icons.wb_sunny;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = Provider.of<SettingsProvider>(context);
    final hijriDateMap = _getHijriDateMap(settings.hijriAdjustment);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Hero Section: Next Prayer Banner & Date/Occasion Info
              _buildTopHeroSection(context, isDark, hijriDateMap),
              const SizedBox(height: 24),

              // 2. Horizontal Prayer Times Row (Desktop responsive layout)
              _buildHorizontalPrayerTimes(
                context,
                isDark,
                hijriDateMap['monthIndex'] as int,
              ),
              const SizedBox(height: 24),

              // 3. Featured Quran & Daily Hadith row
              _buildQuranAndHadithRow(context, isDark),
              const SizedBox(height: 24),

              // 4. Compact Desktop Shortcuts & Services Grid (Excluding Qibla)
              _buildDesktopServicesSection(context, isDark),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 1. Top Hero Section
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTopHeroSection(
    BuildContext context,
    bool isDark,
    Map<String, dynamic> hijriDateMap,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 850;

        final prayerCard = _buildNextPrayerHeroCard(context, isDark);
        final dateCard = _buildDateAndOccasionCard(
          context,
          isDark,
          hijriDateMap['formatted'] as String,
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: prayerCard),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: dateCard),
            ],
          );
        } else {
          return Column(
            children: [
              prayerCard,
              const SizedBox(height: 16),
              dateCard,
            ],
          );
        }
      },
    );
  }

  Widget _buildNextPrayerHeroCard(BuildContext context, bool isDark) {
    final headerImage = _getHeaderImage();
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(headerImage, fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.25),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4AF37)
                                    .withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFD4AF37)
                                      .withValues(alpha: 0.6),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                'الصلاة القادمة',
                                style: GoogleFonts.tajawal(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFD4AF37),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _getPrayerName(_nextPrayer ?? ''),
                          style: GoogleFonts.tajawal(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'الوقت المتبقي لرفع الأذان',
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1565C0)
                              .withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.hourglass_top_rounded,
                          color: Colors.white70,
                          size: 20,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatDuration(_timeUntilNextPrayer),
                          style: GoogleFonts.tajawal(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
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

  Widget _buildDateAndOccasionCard(
    BuildContext context,
    bool isDark,
    String formattedHijriDate,
  ) {
    final gregorianStr = DateFormat.yMMMMd('ar').format(DateTime.now());
    return Container(
      constraints: const BoxConstraints(minHeight: 220),
      height: 220,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E2428)
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: Color(0xFFD4AF37),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedHijriDate,
                      style: GoogleFonts.tajawal(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFD4AF37),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      gregorianStr,
                      style: GoogleFonts.tajawal(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : const Color(0xFF546E7A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                ),
                color: isDark ? Colors.white54 : Colors.grey[400],
                tooltip: 'فتح التقويم',
                onPressed: () {
                  if (widget.onNavigateToSection != null) {
                    widget.onNavigateToSection!(6); // Calendar index
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, thickness: 0.6),
          const SizedBox(height: 6),
          const Expanded(
            child: Center(
              child: EventCardWidget(
                margin: EdgeInsets.zero,
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                imageSize: 64,
                titleFontSize: 15,
                countdownNumberFontSize: 22,
                borderRadius: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 2. Horizontal Prayer Times Row (Desktop spacing)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHorizontalPrayerTimes(
    BuildContext context,
    bool isDark,
    int currentMonth,
  ) {
    if (_prayerTimes == null) return const SizedBox.shrink();
    final prayerKeys = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E2428)
            : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                color: Color(0xFFD4AF37),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'مواقيت الصلاة اليوم',
                style: GoogleFonts.tajawal(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF263238),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final items = <Widget>[
                if (currentMonth == 9)
                  _buildDesktopPrayerCard(
                    isDark,
                    name: 'الإمساك',
                    icon: Icons.bedtime_outlined,
                    time: _prayerTimes!['fajr']?.subtract(
                      const Duration(minutes: 15),
                    ),
                    isNext: false,
                  ),
                ...prayerKeys.map(
                  (key) => _buildDesktopPrayerCard(
                    isDark,
                    name: _getPrayerName(key),
                    icon: _getPrayerIcon(key),
                    time: _prayerTimes![key],
                    isNext: _nextPrayer == key,
                  ),
                ),
              ];

              return Row(
                children: items
                    .map((item) => Expanded(child: item))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopPrayerCard(
    bool isDark, {
    required String name,
    required IconData icon,
    required DateTime? time,
    required bool isNext,
  }) {
    const Color activeColor = Color(0xFFD4AF37);
    final Color cardBg = isNext
        ? (isDark
            ? activeColor.withValues(alpha: 0.2)
            : const Color(0xFFFFF8E1))
        : (isDark
            ? const Color(0xFF262C31)
            : const Color(0xFFF7F8FA));

    final Color textColor = isNext
        ? (isDark ? Colors.white : const Color(0xFF2D2D2D))
        : (isDark ? Colors.white : Colors.black87);

    final Color subColor = isNext
        ? activeColor
        : (isDark ? Colors.grey[400]! : Colors.grey[600]!);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNext
              ? activeColor
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06)),
          width: isNext ? 2 : 1,
        ),
        boxShadow: isNext
            ? [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: subColor, size: 22),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(
                fontSize: 13,
                fontWeight: isNext ? FontWeight.bold : FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              time != null
                  ? "${(time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour)).toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} ${time.hour >= 12 ? 'م' : 'ص'}"
                  : "--:--",
              style: GoogleFonts.tajawal(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          if (isNext) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'القادمة',
                style: GoogleFonts.tajawal(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: activeColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3. Featured Quran Card & Daily Hadith Row
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildQuranAndHadithRow(BuildContext context, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 850;
        final quranCard = _buildDesktopQuranCard(context, isDark);
        final hadithCard = _buildDesktopHadithCard(context, isDark);

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 1, child: quranCard),
              const SizedBox(width: 20),
              Expanded(flex: 1, child: hadithCard),
            ],
          );
        } else {
          return Column(
            children: [
              quranCard,
              const SizedBox(height: 16),
              hadithCard,
            ],
          );
        }
      },
    );
  }

  Widget _buildDesktopQuranCard(BuildContext context, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () async {
          final prefs = await SharedPreferences.getInstance();
          final lastPage = prefs.getInt('last_read_quran_page');
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => lastPage != null
                    ? MushafScreen(initialPage: lastPage)
                    : const IndexScreen(),
              ),
            );
          }
        },
        child: Container(
          height: 130,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: isDark
                ? const LinearGradient(
                    colors: [Color(0xFF1B3A4B), Color(0xFF0D2233)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  )
                : const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF0288D1)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1565C0).withValues(alpha: 0.30),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'القرآن الكريم',
                      style: GoogleFonts.tajawal(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'متابعة قراءة الورد اليومي للمصحف الشريف',
                      style: GoogleFonts.tajawal(
                        fontSize: 13,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Image.asset(
                'assets/images/quranlogo.png',
                height: 70,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopHadithCard(BuildContext context, bool isDark) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: BukhariJsonService.getDailyHadith(),
      builder: (context, snapshot) {
        final text = snapshot.data?['text'] as String? ??
            'قال رسول الله ﷺ: «من يرد الله به خيرا يفقهه في الدين»';

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => _showHadithDialog(context, text),
            child: Container(
              height: 130,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E2428)
                    : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.format_quote_rounded,
                        color: Color(0xFFD4AF37),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'حديث اليوم • صحيح البخاري',
                        style: GoogleFonts.tajawal(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFD4AF37),
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.open_in_new_rounded,
                        color: Colors.grey,
                        size: 14,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.amiri(
                      fontSize: 15,
                      height: 1.5,
                      color: isDark ? Colors.white70 : const Color(0xFF546E7A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showHadithDialog(BuildContext context, String fullText) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.format_quote_rounded,
                color: Color(0xFFD4AF37),
              ),
              const SizedBox(width: 8),
              Text(
                'حديث اليوم',
                style: GoogleFonts.tajawal(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFD4AF37),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 400),
            child: SingleChildScrollView(
              child: Text(
                fullText,
                style: GoogleFonts.amiri(
                  fontSize: 18,
                  height: 1.8,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'إغلاق',
                style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 4. Compact Desktop Shortcuts & Services Grid (EXCLUDING QIBLA)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDesktopServicesSection(BuildContext context, bool isDark) {
    // Note: Qibla is strictly excluded for Windows desktop.
    final services = <Map<String, dynamic>>[
      {
        'title': 'القرآن الكريم',
        'icon': Icons.menu_book_rounded,
        'sectionIndex': 1,
      },
      {
        'title': 'الأذكار',
        'icon': Icons.auto_stories_rounded,
        'sectionIndex': 2,
      },
      {
        'title': 'مكتبة الحديث',
        'icon': Icons.format_quote_rounded,
        'sectionIndex': 3,
      },
      {
        'title': 'الفقه الإسلامي',
        'icon': Icons.gavel_rounded,
        'sectionIndex': 4,
      },
      {
        'title': 'الموسوعة الإسلامية',
        'icon': Icons.history_edu_rounded,
        'sectionIndex': 5,
      },
      {
        'title': 'التقويم والمناسبات',
        'icon': Icons.calendar_month_rounded,
        'sectionIndex': 6,
      },
      {
        'title': 'المسبحة الإلكترونية',
        'icon': Icons.fingerprint_rounded,
        'sectionIndex': 7,
      },
      {
        'title': 'الصوتيات',
        'icon': Icons.library_music_rounded,
        'sectionIndex': 8,
      },
      {
        'title': 'الراديو',
        'icon': Icons.radio_rounded,
        'sectionIndex': 9,
      },
      {
        'title': 'أسماء الله الحسنى',
        'icon': Icons.auto_awesome_rounded,
        'sectionIndex': 10,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.apps_rounded,
              color: Color(0xFFD4AF37),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'أقسام وتطبيقات زاد',
              style: GoogleFonts.tajawal(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? Colors.white : const Color(0xFF263238),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth >= 1200
                ? 5
                : (constraints.maxWidth >= 900
                    ? 4
                    : (constraints.maxWidth >= 600 ? 3 : 2));

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.35,
              ),
              itemCount: services.length,
              itemBuilder: (ctx, i) =>
                  _buildServiceDesktopCard(ctx, isDark, services[i]),
            );
          },
        ),
      ],
    );
  }

  Widget _buildServiceDesktopCard(
    BuildContext context,
    bool isDark,
    Map<String, dynamic> item,
  ) {
    final iconColor = isDark ? const Color(0xFFD4AF37) : const Color(0xFF1565C0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          final sectionIndex = item['sectionIndex'] as int?;
          if (sectionIndex != null && widget.onNavigateToSection != null) {
            widget.onNavigateToSection!(sectionIndex);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2428) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.08),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item['icon'] as IconData,
                  size: 24,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item['title'] as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.tajawal(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF263238),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
