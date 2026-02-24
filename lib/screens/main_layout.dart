import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hijri/hijri_calendar.dart';
import '../providers/settings_provider.dart';
import '../services/prayer_times_service.dart';
import '../services/hadith_service.dart';
import '../services/hijri_date_service.dart';
import '../utils/app_constants.dart';
// ستبقى للاستخدام داخل صفحة تبيان
import 'tasbih_screen.dart';
import 'azkar_screen.dart';
import 'fasting_fiqh_screen.dart';
import 'tibyan_menu_page.dart'; // استيراد الصفحة الجديدة

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with WidgetsBindingObserver {
  int _currentIndex = 0;

  // تحديث قائمة الشاشات: استبدال QuranHomeNew بـ TibyanMenuPage في الفهرس رقم 1
  final List<Widget> _screens = [
    const HomeScreen(),
    const TibyanMenuPage(), // التبويب الجديد
    const TasbihScreen(),
    const AzkarScreenWidget(),
    const FastingFiqhScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        } else {
          await _showExitConfirmation(context);
        }
      },
      child: Scaffold(
        body: _screens[_currentIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Colors.grey,
            selectedLabelStyle: GoogleFonts.tajawal(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            unselectedLabelStyle: GoogleFonts.tajawal(fontSize: 11),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.access_time),
                label: 'المواقيت',
              ),
              BottomNavigationBarItem(
                icon: Icon(
                  Icons.grid_view_rounded,
                ), // أيقونة الشبكة لتدل على أقسام تبيان
                label: 'تبيان',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.fingerprint),
                label: 'المسبحة',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.auto_stories),
                label: 'الأذكار',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.help_outline),
                label: 'الفقه',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showExitConfirmation(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'تأكيد الخروج',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'هل تريد الخروج من التطبيق؟',
          style: GoogleFonts.tajawal(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.tajawal()),
          ),
          ElevatedButton(
            onPressed: () => SystemNavigator.pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: Text(
              'خروج',
              style: GoogleFonts.tajawal(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// --- شاشة HomeScreen تبقى كما هي دون تغيير في منطقها ---

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final PrayerTimesService _prayerService = PrayerTimesService.instance;
  Map<String, DateTime?> _prayerTimes = {};
  String? _nextPrayer;
  Duration? _timeUntilNextPrayer;
  Timer? _countdownTimer;
  String? _lastLoadedCity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitialData();
    _startCountdownTimer();
  }

  void _loadInitialData() async {
    await _loadPrayerTimes();
    if (!HadithService.instance.isInitialized) {
      await HadithService.instance.initialize();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPrayerTimes() async {
    final prayerTimes = await _prayerService.getCurrentPrayerTimes();
    if (mounted) {
      setState(() {
        _prayerTimes = prayerTimes ?? {};
        _nextPrayer = _prayerService.getNextPrayer();
        _timeUntilNextPrayer = _prayerService.getTimeUntilNextPrayer();
      });
    }
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _timeUntilNextPrayer = _prayerService.getTimeUntilNextPrayer();
          _nextPrayer = _prayerService.getNextPrayer();
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    final absDiff = duration.abs();
    final hours = absDiff.inHours;
    final minutes = absDiff.inMinutes.remainder(60);
    final seconds = absDiff.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_lastLoadedCity != settings.selectedCity) {
      _lastLoadedCity = settings.selectedCity;
      _loadPrayerTimes();
    }

    final cityName = settings.selectedCity.split(',').first.trim();
    final countryName = settings.selectedCity.split(',').length > 1
        ? settings.selectedCity.split(',').last.trim()
        : '';
    final hijriDateMap = HijriDateService.getHijriDate(
      DateTime.now(),
      settings.hijriAdjustment,
    );

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: Column(
          children: [
            Text(
              'مواقيت الصلاة',
              style: GoogleFonts.tajawal(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              cityName.isEmpty
                  ? 'لم يتم تحديد موقع'
                  : '$cityName - $countryName',
              style: GoogleFonts.tajawal(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPrayerTimes,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildHijriCard(hijriDateMap['formatted']),
              _buildNextPrayerCard(),
              const SizedBox(height: 20),
              _buildSpecialEventCard(settings.hijriAdjustment),
              const SizedBox(height: 20),
              _buildPrayerTimesList(hijriDateMap['monthIndex'] as int),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHijriCard(String formattedDate) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppConstants.goldGradient,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_month, color: Color(0xFF8B4513)),
          const SizedBox(width: 12),
          Text(
            formattedDate,
            style: GoogleFonts.tajawal(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF8B4513),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextPrayerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppConstants.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            'الصلاة القادمة',
            style: GoogleFonts.tajawal(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            _getPrayerName(_nextPrayer ?? ''),
            style: GoogleFonts.tajawal(
              fontSize: 32,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(_timeUntilNextPrayer ?? Duration.zero),
                  style: GoogleFonts.tajawal(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialEventCard(int adjustment) {
    final hijriDate = HijriDateService.getHijriDate(DateTime.now(), adjustment);
    final day = hijriDate['dayIndex'] as int;
    final month = hijriDate['monthIndex'] as int;

    if (month == 10 && day == 1) {
      return _buildGreetingCard(
        'عيد فطر مبارك',
        'تقبل الله صيامكم وقيامكم',
        Colors.orange,
      );
    }
    if (month == 12 && day == 9) {
      return _buildGreetingCard('وقفة عرفات', 'لبيك اللهم لبيك', Colors.brown);
    }
    if (month == 12 && day >= 10 && day <= 13) {
      return _buildGreetingCard(
        'عيد أضحى مبارك',
        'أيام تشريق مباركة',
        Colors.green,
      );
    }

    if (month != 9) {
      return _buildRamadanCounter(adjustment);
    }

    return _buildHadithOfTheDayCard();
  }

  Widget _buildRamadanCounter(int adjustment) {
    final hNow = HijriCalendar.now();
    hNow.hDay += adjustment;

    int targetYear = hNow.hYear;
    if (hNow.hMonth > 9 || (hNow.hMonth == 9 && hNow.hDay >= 1)) {
      targetYear++;
    }

    final targetRamadan = HijriCalendar();
    targetRamadan.hYear = targetYear;
    targetRamadan.hMonth = 9;
    targetRamadan.hDay = 1;

    DateTime targetDateTime = targetRamadan.hijriToGregorian(
      targetRamadan.hYear,
      9,
      1,
    );
    DateTime nowAdjusted = DateTime.now().add(Duration(days: adjustment));

    Duration diff = targetDateTime.difference(nowAdjusted);
    int days = diff.inDays;
    int hours = diff.inHours.remainder(24);
    int minutes = diff.inMinutes.remainder(60);

    if (days < 0) return _buildHadithOfTheDayCard();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppConstants.goldGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            'باقي على شهر رمضان المبارك',
            style: GoogleFonts.tajawal(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8B4513),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTimeUnit(days.toString().padLeft(2, '0'), 'يوم'),
              const SizedBox(width: 15),
              _buildTimeUnit(hours.toString().padLeft(2, '0'), 'ساعة'),
              const SizedBox(width: 15),
              _buildTimeUnit(minutes.toString().padLeft(2, '0'), 'دقيقة'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHadithOfTheDayCard() {
    return Consumer<HadithService>(
      builder: (context, service, _) {
        final hadith = service.getTodayHadith();
        if (hadith == null) return const SizedBox.shrink();
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.grey[800]!
                  : Theme.of(context).primaryColor.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Text(
                'حديث اليوم',
                style: GoogleFonts.tajawal(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDark
                      ? Colors.amber[200]
                      : Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                hadith.text,
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(
                  fontSize: 17,
                  height: 1.6,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '[ ${hadith.source} ]',
                style: GoogleFonts.tajawal(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrayerTimesList(int currentMonth) {
    final prayerKeys = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'مواقيت الصلاة اليوم',
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        ...prayerKeys.map((key) {
          final time = _prayerTimes[key];
          if (key == 'fajr' && currentMonth == 9 && time != null) {
            final imsakTime = time.subtract(const Duration(minutes: 15));
            return Column(
              children: [
                _buildImsakRow(imsakTime),
                _buildPrayerTile(key, time),
              ],
            );
          }
          return _buildPrayerTile(key, time);
        }),
      ],
    );
  }

  Widget _buildImsakRow(DateTime imsakTime) {
    bool isNext = _nextPrayer == 'fajr';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: AppConstants.goldGradient,
        borderRadius: BorderRadius.circular(15),
        border: isNext
            ? Border.all(color: const Color(0xFF8B4513), width: 2)
            : null,
      ),
      child: ListTile(
        leading: const Icon(Icons.bedtime_outlined, color: Color(0xFF8B4513)),
        title: Text(
          'الإمساك',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF8B4513),
          ),
        ),
        subtitle: isNext
            ? Text(
                'حان الآن موعد الإمساك',
                style: GoogleFonts.tajawal(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF8B4513),
                ),
              )
            : null,
        trailing: Text(
          imsakTime.getFormattedTime(),
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: const Color(0xFF8B4513),
          ),
        ),
      ),
    );
  }

  Widget _buildPrayerTile(String key, DateTime? time) {
    bool isNext = _nextPrayer == key;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isNext
            ? Theme.of(context).primaryColor.withValues(alpha: 0.12)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isNext ? Theme.of(context).primaryColor : Colors.transparent,
        ),
      ),
      child: ListTile(
        leading: Icon(
          _getPrayerIcon(key),
          color: isNext
              ? Theme.of(context).primaryColor
              : (isDark ? Colors.grey[400] : Colors.grey),
        ),
        title: Text(
          _getPrayerName(key),
          style: GoogleFonts.tajawal(
            fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: Text(
          time.getFormattedTime(),
          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTimeUnit(String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value,
            style: GoogleFonts.tajawal(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF8B4513),
            ),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.tajawal(
            fontSize: 12,
            color: const Color(0xFF8B4513),
          ),
        ),
      ],
    );
  }

  Widget _buildGreetingCard(String title, String sub, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.7), color]),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.tajawal(
              fontSize: 22,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: GoogleFonts.tajawal(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  String _getPrayerName(String key) {
    switch (key) {
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
        return '';
    }
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
}
