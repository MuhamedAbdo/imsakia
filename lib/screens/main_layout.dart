import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../features/athan/services/athan_manager.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/settings_provider.dart';
import '../services/prayer_times_service.dart';
import '../services/hadith_service.dart';
import '../services/hijri_date_service.dart';
import 'package:audio_service/audio_service.dart';
import '../features/audio/services/audio_handler.dart';

// ستبقى للاستخدام داخل صفحة تبيان
import 'tasbih_screen.dart';
import 'azkar_screen.dart';
import 'fasting_fiqh_screen.dart';
import 'tibyan_menu_page.dart';
import '../widgets/neumorphic_box.dart';
import '../services/athan_service.dart';

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
        floatingActionButton: StreamBuilder<MediaItem?>(
          stream: audioHandler?.mediaItem,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data?.id == 'athan_alert') {
              return FloatingActionButton.extended(
                onPressed: () => AthanManager.stopAthan(),
                backgroundColor: Colors.redAccent,
                icon: const Icon(Icons.stop_circle_outlined, color: Colors.white),
                label: Text(
                  'إيقاف الأذان',
                  style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
            onPressed: () {
              Navigator.pop(context);
              SystemNavigator.pop();
            },
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
    
    // 🔥 اطلب الصلاحيات الهامة بمجرد فتح التطبيق بدلاً من انتظار زر Test
    // تم إضافة تأخير لمدة ثانية لضمان استقرار الـ MethodChannel
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _requestAppPermissions();
    });
  }

  Future<void> _requestAppPermissions() async {
    if (!mounted || !Platform.isAndroid) return;

    // 1. صلاحية الإشعارات
    var notificationStatus = await Permission.notification.status;
    if (!notificationStatus.isGranted) {
      await Permission.notification.request();
    }

    // 2. صلاحية المنبهات الدقيقة (Exact Alarms) - لأندرويد 12+
    var alarmStatus = await Permission.scheduleExactAlarm.status;
    if (alarmStatus.isDenied || alarmStatus.isRestricted) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'تنبيه الأذان الدقيق',
              style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'لضمان عمل الأذان في الوقت الصحيح، نرجو منح التطبيق صلاحية "المنبهات والتذكيرات".',
              style: GoogleFonts.tajawal(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('لاحقاً', style: GoogleFonts.tajawal()),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await Permission.scheduleExactAlarm.request();
                },
                child: Text('منح الصلاحية', style: GoogleFonts.tajawal(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    }

    // 3. صلاحية الظهور فوق التطبيقات (System Alert Window)
    var alertStatus = await Permission.systemAlertWindow.status;
    if (!alertStatus.isGranted) {
      // نطلبها فقط لو المستخدم موافق أو نحتاج تنبيه الشاشة الكاملة
      await Permission.systemAlertWindow.request();
    }

    // 4. تجاهل تحسين البطارية (Battery Optimization)
    var batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    if (!batteryStatus.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }
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

  // Smart adaptive countdown timer.
  // - While remaining > 60s: fires every minute (on the minute boundary)
  //   → saves ~59/60 battery compared to always firing every second
  // - When remaining ≤ 60s: switches to per-second updates automatically
  // - Cancels and reschedules itself to stay aligned with real-time.
  void _startCountdownTimer() {
    _countdownTimer?.cancel();

    final remaining = _prayerService.getTimeUntilNextPrayer();
    final totalSeconds = remaining?.inSeconds ?? 0;

    if (totalSeconds > 60) {
      // ── Minute mode ──────────────────────────────────────────────────────────
      // Fire once at the next whole minute boundary so the display updates exactly
      // when the minute digit changes (e.g. 05:00 → 04:00).
      final secondsIntoCurrentMinute = totalSeconds % 60;
      // How many seconds until the next whole minute tick?
      final secsUntilMinuteBoundary =
          secondsIntoCurrentMinute == 0 ? 60 : secondsIntoCurrentMinute;

      _countdownTimer =
          Timer(Duration(seconds: secsUntilMinuteBoundary), () {
        if (!mounted) return;
        setState(() {
          _timeUntilNextPrayer = _prayerService.getTimeUntilNextPrayer();
          _nextPrayer = _prayerService.getNextPrayer();
        });
        // After the first boundary tick, keep ticking every 60 seconds
        // — unless we've now entered the last minute, in which case re-enter
        // this method to switch to per-second mode.
        _startCountdownTimer();
      });
    } else {
      // ── Second mode (last 60 seconds) ────────────────────────────────────────
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final left = _prayerService.getTimeUntilNextPrayer();
        setState(() {
          _timeUntilNextPrayer = left;
          _nextPrayer = _prayerService.getNextPrayer();
        });
        // Once the prayer time passes (≤ 0), reset and switch back to minute mode
        if ((left?.inSeconds ?? 0) <= 0) {
          _startCountdownTimer();
        }
      });
    }
  }

  /// Formats a Duration for display.
  /// - ≥ 60 seconds remaining → show minutes only, no seconds ("H:MM" or "HH:MM")
  ///   e.g. 2h 35m → "02:35" means "2 hr 35 min"
  /// - < 60 seconds remaining → show "00:SS" (seconds visible)
  String _formatDuration(Duration duration) {
    final absDiff = duration.abs();
    final totalSeconds = absDiff.inSeconds;

    if (totalSeconds >= 60) {
      // Show hours + minutes only — no seconds flicker
      final hours = absDiff.inHours;
      final minutes = absDiff.inMinutes.remainder(60);
      if (hours > 0) {
        return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
      } else {
        return '${minutes.toString().padLeft(2, '0')}:00';
      }
    } else {
      // Last minute: show seconds
      final seconds = absDiff.inSeconds.remainder(60);
      return '00:${seconds.toString().padLeft(2, '0')}';
    }
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
              const SizedBox(height: 10),
              // --- Test Athan & Logs ---
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        debugPrint("--- Athan Test Started (Fajr) ---");
                        final now = DateTime.now();
                        final scheduleTime = now.add(const Duration(seconds: 5));
                        
                        await AthanManager.scheduleNextAthan(
                          alarmId: 101, 
                          time: scheduleTime,
                          isFajr: true,
                          prayerName: 'الفجر',
                          isTest: true,
                        );
                        
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تمت جدولة أذان الفجر للتجربة بعد 5 ثواني 🕌'),
                              duration: Duration(seconds: 3),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.notifications_active, color: Colors.white),
                      label: Text(
                        'تجربة الفجر',
                        style: GoogleFonts.tajawal(
                            fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final logs = await AthanService.readLogs();
                        if (context.mounted) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Athan Logs'),
                              content: SingleChildScrollView(
                                child: Text(logs, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () async {
                                    await AthanService.clearLogs();
                                    if (context.mounted) Navigator.pop(context);
                                  },
                                  child: const Text('Clear'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.list_alt, color: Colors.white, size: 20),
                      label: Text(
                        'Logs',
                        style: GoogleFonts.tajawal(
                            fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildPrayerTestButtons(),
              const SizedBox(height: 15),
              // 🔥 Emergency Stop Button (Requested by User)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: ElevatedButton.icon(
                  onPressed: () => AthanManager.stopAthan(),
                  icon: const Icon(Icons.stop_circle, color: Colors.white),
                  label: Text(
                    "إيقاف الأذان فوراً",
                    style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              _buildSpecialEventCard(settings.hijriAdjustment),
              const SizedBox(height: 20),
              _buildPrayerTimesList(hijriDateMap['monthIndex'] as int),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrayerTestButtons() {
    final prayers = [
      {'name': 'الظهر', 'id': 102, 'color': Colors.blue},
      {'name': 'العصر', 'id': 103, 'color': Colors.orange},
      {'name': 'المغرب', 'id': 104, 'color': Colors.deepOrange},
      {'name': 'العشاء', 'id': 105, 'color': Colors.indigo},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: prayers.map((p) {
          return Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: ElevatedButton(
              onPressed: () async {
                final scheduleTime = DateTime.now().add(const Duration(seconds: 5));
                await AthanManager.scheduleNextAthan(
                  alarmId: p['id'] as int,
                  time: scheduleTime,
                  isFajr: false,
                  prayerName: p['name'] as String,
                  isTest: true,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تجربة أذان ${p['name']} بعد 5 ثواني'), backgroundColor: p['color'] as Color),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: p['color'] as Color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                p['name'] as String,
                style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHijriCard(String formattedDate) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4, top: 4),
      child: NeumorphicBox(
        borderRadius: 15,
        child: Padding(
          padding: const EdgeInsets.all(16),
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
        ),
      ),
    );
  }

  Widget _buildNextPrayerCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: NeumorphicBox(
        borderRadius: 20,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                'الصلاة القادمة',
                style: GoogleFonts.tajawal(
                  color: isDark ? Colors.white70 : Theme.of(context).primaryColor, 
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getPrayerName(_nextPrayer ?? ''),
                style: GoogleFonts.tajawal(
                  fontSize: 32,
                  color: isDark ? Colors.white : Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              NeumorphicBox(
                borderRadius: 30,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined, 
                        color: isDark ? Colors.white70 : Theme.of(context).primaryColor, 
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDuration(_timeUntilNextPrayer ?? Duration.zero),
                        style: GoogleFonts.tajawal(
                          fontSize: 22,
                          color: isDark ? Colors.white : Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: NeumorphicBox(
        borderRadius: 20,
        child: Padding(
          padding: const EdgeInsets.all(20),
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
        ),
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
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: NeumorphicBox(
            borderRadius: 20,
            child: Padding(
              padding: const EdgeInsets.all(22),
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
            ),
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
    
    final Color coloredBase = const Color(0xFFE68A00); // Softer orange for imsak
    final Color coloredDarkShadow = const Color(0xFFCC7A00).withValues(alpha: 0.4);
    final Color coloredLightShadow = const Color(0xFFFF9900).withValues(alpha: 0.4);

    return Container(
        margin: const EdgeInsets.only(bottom: 12, left: 4, right: 4, top: 4),
        child: NeumorphicBox(
          borderRadius: 15,
          baseColor: isNext ? coloredBase : null,
          darkShadowColor: isNext ? coloredDarkShadow : null,
          lightShadowColor: isNext ? coloredLightShadow : null,
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
        ),
    );
  }

  Widget _buildPrayerTile(String key, DateTime? time) {
    bool isNext = _nextPrayer == key;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Colored Neumorphism for the active prayer
    final Color? coloredBase = isNext ? const Color(0xFF388E3C) : null; // Softer green
    final Color? coloredDarkShadow = isNext ? const Color(0xFF2E7D32).withValues(alpha: 0.4) : null;
    final Color? coloredLightShadow = isNext ? const Color(0xFF4CAF50).withValues(alpha: 0.4) : null;

    final Color iconColor = isNext
        ? Colors.white
        : (isDark ? Colors.grey[400]! : Colors.grey);
    final Color textColor = isNext
        ? Colors.white
        : (isDark ? Colors.white : Colors.black87);

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 4, right: 4, top: 4),
      child: NeumorphicBox(
        borderRadius: 15,
        baseColor: coloredBase,
        darkShadowColor: coloredDarkShadow,
        lightShadowColor: coloredLightShadow,
        child: ListTile(
          leading: Icon(
            _getPrayerIcon(key),
            color: iconColor,
          ),
          title: Text(
            _getPrayerName(key),
            style: GoogleFonts.tajawal(
              fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
          trailing: Text(
            time.getFormattedTime(),
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
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
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: NeumorphicBox(
        borderRadius: 15,
        baseColor: color,
        lightShadowColor: color.withValues(alpha: 0.5),
        darkShadowColor: color.withValues(alpha: 0.8),
        child: Padding(
          padding: const EdgeInsets.all(20),
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
        ),
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
