import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:audio_service/audio_service.dart';

import '../features/athan/services/athan_manager.dart';
import '../features/athan/providers/athan_provider.dart';
import '../features/audio/services/audio_handler.dart';
import '../providers/settings_provider.dart';
import '../services/prayer_times_service.dart';
import '../services/hijri_date_service.dart';
import '../services/hadith_service.dart';
import '../services/bukhari_database_service.dart';
import '../services/permissions_service.dart';
import 'azkar_screen.dart';
import 'allah_names_page.dart';
import 'radio_page.dart';
import 'calendar_page.dart';
import 'bukhari_library_page.dart';
import '../features/quran_madinah/ui/index_screen.dart';
import 'qibla_compass_screen.dart';
import 'settings_screen.dart';
import 'tasbih_screen.dart';
import '../features/audio/screens/audio_reciters_screen.dart';
import '../widgets/event_card_widget.dart';

// =============================================================================
//  UnderDevelopmentPage
// =============================================================================
class UnderDevelopmentPage extends StatelessWidget {
  const UnderDevelopmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F0),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme:
              IconThemeData(color: isDark ? Colors.white : Colors.black),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.construction_rounded,
                    size: 80, color: Colors.amber),
              ),
              const SizedBox(height: 24),
              Text(
                'سيتم تطويره قريباً',
                style: GoogleFonts.tajawal(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color:
                      isDark ? Colors.white : const Color(0xFF546E7A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'نحن نعمل على إضافة هذا القسم المميّز',
                style: GoogleFonts.tajawal(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  MainLayout
// =============================================================================
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _batteryBannerDismissed = false;
  bool _wasPaused = false;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      const QiblaCompassScreen(),
      const TasbihScreen(),
      SettingsScreen(onSettingsSaved: () {
        if (mounted) {
          setState(() => _currentIndex = 0);
        }
      }),
    ];
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _checkBatteryOptimization());
  }

  Future<void> _checkBatteryOptimization() async {
    if (!mounted || _batteryBannerDismissed) return;
    if (!Platform.isAndroid) return;
    try {
      final isIgnoring =
          await Permission.ignoreBatteryOptimizations.isGranted;
      if (!isIgnoring && mounted) _showBatteryBanner();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasPaused = true;
    } else if (state == AppLifecycleState.resumed) {
      if (!_batteryBannerDismissed) _checkBatteryAndHideBanner();
      if (_wasPaused) {
        _wasPaused = false;
        _navigateToSplash();
      }
    }
  }

  void _navigateToSplash() {
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> _checkBatteryAndHideBanner() async {
    if (!mounted) return;
    try {
      final isIgnoring =
          await Permission.ignoreBatteryOptimizations.isGranted;
      if (isIgnoring && mounted) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
        setState(() => _batteryBannerDismissed = true);
      }
    } catch (_) {}
  }

  void _showBatteryBanner() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        leading: const Icon(Icons.battery_alert_rounded,
            color: Color(0xFFE65100), size: 28),
        content: Text(
          'لضمان دقة الأذان والتنبيهات، يرجى إيقاف تحسين البطارية للتطبيق.',
          style: GoogleFonts.tajawal(
              fontSize: 13, fontWeight: FontWeight.w500),
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: const Color(0xFFFFF3E0),
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: () async {
              try {
                const MethodChannel('imsakia/notifications')
                    .invokeMethod(
                        'openBatteryOptimizationSettings');
              } catch (_) {
                await Permission.ignoreBatteryOptimizations
                    .request();
              }
            },
            child: Text(
              'إعدادات',
              style: GoogleFonts.tajawal(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFE65100)),
            ),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context)
                  .hideCurrentMaterialBanner();
              setState(() => _batteryBannerDismissed = true);
            },
            child: Text('إغلاق',
                style:
                    GoogleFonts.tajawal(color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            if (snapshot.hasData &&
                snapshot.data?.id == 'athan_alert') {
              return FloatingActionButton.extended(
                onPressed: () => AthanManager.stopAthan(),
                backgroundColor: Colors.redAccent,
                icon: const Icon(Icons.stop_circle_outlined,
                    color: Colors.white),
                label: Text(
                  'إيقاف الأذان',
                  style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        floatingActionButtonLocation:
            FloatingActionButtonLocation.centerFloat,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E2024)
                : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) =>
                  setState(() => _currentIndex = index),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor:
                  Theme.of(context).colorScheme.primary,
              unselectedItemColor: isDark
                  ? Colors.grey[500]
                  : Colors.grey[700],
              selectedLabelStyle: GoogleFonts.tajawal(
                  fontWeight: FontWeight.bold, fontSize: 12),
              unselectedLabelStyle: GoogleFonts.tajawal(
                fontSize: 11,
                fontWeight: isDark
                    ? FontWeight.normal
                    : FontWeight.w500,
              ),
              items: const [
                BottomNavigationBarItem(
                    icon: Icon(Icons.mosque),
                    label: 'الصلوات'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.explore),
                    label: 'القبلة'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.fingerprint),
                    label: 'المسبحة'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.settings),
                    label: 'الإعدادات'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showExitConfirmation(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('تأكيد الخروج',
            style: GoogleFonts.tajawal(
                fontWeight: FontWeight.bold)),
        content: Text('هل تريد الخروج من التطبيق؟',
            style: GoogleFonts.tajawal()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text('إلغاء', style: GoogleFonts.tajawal()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await SystemNavigator.pop();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor:
                    Theme.of(context).colorScheme.primary),
            child: Text('خروج',
                style: GoogleFonts.tajawal(
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
//  HomeScreen
// =============================================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  Map<String, DateTime>? _prayerTimes;
  String? _nextPrayer;
  Duration? _timeUntilNextPrayer;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitialData();
    _startCountdownTimer();
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Provider.of<AthanProvider>(context, listen: false)
            .refreshStatus();
      }
    });
  }

  void _loadInitialData() async {
    await _loadPrayerTimes();
    if (!HadithService.instance.isInitialized) {
      HadithService.instance.initialize();
    }
  }

  Future<void> _loadPrayerTimes() async {
    final times =
        await PrayerTimesService.instance.getCurrentPrayerTimes();
    if (mounted && times != null) {
      setState(() {
        _prayerTimes = times;
        _nextPrayer =
            PrayerTimesService.instance.getNextPrayer();
        _timeUntilNextPrayer =
            PrayerTimesService.instance.getTimeUntilNextPrayer();
      });
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _nextPrayer =
            PrayerTimesService.instance.getNextPrayer();
        _timeUntilNextPrayer =
            PrayerTimesService.instance.getTimeUntilNextPrayer();
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hijriDateMap = HijriDateService.getHijriDate(
        DateTime.now(), settings.hijriAdjustment);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF121212)
            : const Color(0xFFF7F8FA),
        body: RefreshIndicator(
          onRefresh: _loadPrayerTimes,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildDynamicHeader(context, isDark),
              ),
              SliverToBoxAdapter(
                child: _buildWarningBanner(),
              ),
              SliverToBoxAdapter(
                child: _buildHijriCard(
                    hijriDateMap['formatted'] as String, isDark),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: EventCardWidget(),
                ),
              ),
              SliverToBoxAdapter(
                child: _buildQuranCard(context, isDark),
              ),
              SliverToBoxAdapter(
                child: _buildHorizontalPrayerRow(context, isDark,
                    hijriDateMap['monthIndex'] as int),
              ),
              SliverToBoxAdapter(
                child: _buildServicesSection(context, isDark),
              ),
              SliverToBoxAdapter(
                child: _buildBukhariDailyCard(context, isDark),
              ),
              const SliverToBoxAdapter(
                  child: SizedBox(height: 150)),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  //  Warning Banner
  // ---------------------------------------------------------------------------
  Widget _buildWarningBanner() {
    return Consumer<AthanProvider>(
      builder: (context, provider, _) {
        if (!provider.isBatteryOptimized) {
          return const SizedBox.shrink();
        }
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
                color: Colors.orange.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تنبيه: قيود البطارية مفعلة',
                      style: GoogleFonts.tajawal(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.orange[900]),
                    ),
                    Text(
                      'الأذان قد يتوقف في الخلفية بسبب قيود النظام.',
                      style: GoogleFonts.tajawal(
                          fontSize: 12,
                          color: Colors.orange[800]),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => PermissionsService
                    .openBatteryOptimizationSettings(),
                child: Text(
                  'تعديل',
                  style: GoogleFonts.tajawal(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[900]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  //  Dynamic Header
  // ---------------------------------------------------------------------------
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

  Widget _buildDynamicHeader(BuildContext context, bool isDark) {
    final headerImage = _getHeaderImage();
    return SizedBox(
      width: double.infinity,
      height: 260,
      child: Stack(
        children: [
          Positioned.fill(
              child:
                  Image.asset(headerImage, fit: BoxFit.cover)),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.65),
                    Colors.black.withValues(alpha: 0.30),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              bottom: 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset('assets/images/app_icon.png',
                    height: 42, fit: BoxFit.contain),
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                        alpha: isDark ? 0.12 : 0.22),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color:
                            Colors.white.withValues(alpha: 0.3),
                        width: 1),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black
                              .withValues(alpha: 0.18),
                          blurRadius: 20,
                          offset: const Offset(0, 6))
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الصلاة القادمة',
                              style: GoogleFonts.tajawal(
                                  fontSize: 12,
                                  color: Colors.white70,
                                  fontWeight:
                                      FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                _getPrayerName(
                                    _nextPrayer ?? ''),
                                style: GoogleFonts.tajawal(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0),
                          borderRadius:
                              BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFF1565C0)
                                    .withValues(alpha: 0.45),
                                blurRadius: 10,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _formatDuration(
                                _timeUntilNextPrayer),
                            style: GoogleFonts.tajawal(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.5),
                          ),
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
    );
  }

  // ---------------------------------------------------------------------------
  //  Hijri Date Card
  // ---------------------------------------------------------------------------
  Widget _buildHijriCard(String formattedDate, bool isDark) {
    final gregorianStr =
        DateFormat.yMMMMd('ar').format(DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.1),
            width: 0.8,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                      color: Colors.black
                          .withValues(alpha: 0.06),
                      blurRadius: 15,
                      spreadRadius: 1,
                      offset: const Offset(0, 4))
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.calendar_today_outlined,
                  color: Color(0xFFD4AF37), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formattedDate,
                    style: GoogleFonts.tajawal(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFD4AF37)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    gregorianStr,
                    style: GoogleFonts.tajawal(
                        fontSize: 13,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF546E7A),
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  //  Quran Card
  // ---------------------------------------------------------------------------
  Widget _buildQuranCard(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const IndexScreen())),
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: isDark
                ? const LinearGradient(
                    colors: [
                      Color(0xFF1B3A4B),
                      Color(0xFF0D2233)
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  )
                : const LinearGradient(
                    colors: [
                      Color(0xFF1565C0),
                      Color(0xFF0288D1)
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF1565C0)
                      .withValues(alpha: 0.30),
                  blurRadius: 16,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text('القرآن الكريم',
                        style: GoogleFonts.tajawal(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('قراءة الورد اليومي',
                        style: GoogleFonts.tajawal(
                            fontSize: 13,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Hero(
                tag: 'quran_logo_hero',
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 12, right: 16),
                  child: Image.asset(
                      'assets/images/quranlogo.png',
                      height: 70,
                      fit: BoxFit.contain),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  //  Horizontal Prayer Times
  // ---------------------------------------------------------------------------
  Widget _buildHorizontalPrayerRow(
      BuildContext context, bool isDark, int currentMonth) {
    if (_prayerTimes == null) return const SizedBox.shrink();
    final prayerKeys = [
      'fajr',
      'sunrise',
      'dhuhr',
      'asr',
      'maghrib',
      'isha'
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مواقيت الصلاة اليوم',
            style: GoogleFonts.tajawal(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark
                    ? Colors.white
                    : const Color(0xFF546E7A)),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (currentMonth == 9)
                  _buildPrayerCard(
                    isDark,
                    name: 'الإمساك',
                    icon: Icons.bedtime_outlined,
                    time: _prayerTimes!['fajr']
                        ?.subtract(const Duration(minutes: 15)),
                    isNext: false,
                  ),
                ...prayerKeys.map((key) => _buildPrayerCard(
                      isDark,
                      name: _getPrayerName(key),
                      icon: _getPrayerIcon(key),
                      time: _prayerTimes![key],
                      isNext: _nextPrayer == key,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerCard(
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
            : activeColor)
        : (isDark
            ? const Color(0xFF1E2428)
            : Colors.white);
    final Color textColor = isNext
        ? (isDark ? Colors.white : const Color(0xFF2D2D2D))
        : (isDark ? Colors.white : Colors.black54);
    final Color subColor = isNext
        ? (isDark ? activeColor : const Color(0xFF2D2D2D))
        : (isDark ? Colors.grey[400]! : Colors.grey[600]!);

    return Container(
      width: 90,
      margin: const EdgeInsets.only(left: 12),
      padding:
          const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNext
              ? activeColor
              : (isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.2)),
          width: isNext ? 2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isNext
                ? activeColor.withValues(alpha: 0.25)
                : Colors.black
                    .withValues(alpha: isDark ? 0.0 : 0.08),
            blurRadius: 15,
            spreadRadius: isNext ? 0 : 1,
            offset: isNext
                ? const Offset(0, 5)
                : const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: subColor, size: 22),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(
                  fontSize: 12,
                  fontWeight: isNext
                      ? FontWeight.bold
                      : FontWeight.w600,
                  color: textColor),
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              time != null
                  ? "${(time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour)).toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}"
                  : "--:--",
              style: GoogleFonts.tajawal(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  //  Services Grid
  // ---------------------------------------------------------------------------
  Widget _buildServicesSection(
      BuildContext context, bool isDark) {
    final services = <Map<String, dynamic>>[
      {
        'title': 'القرآن الكريم',
        'icon': Icons.menu_book_rounded,
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const IndexScreen())),
      },
      {
        'title': 'الأذكار',
        'icon': Icons.auto_stories,
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const AzkarScreenWidget())),
      },
      {
        'title': 'الأحاديث',
        'asset': 'assets/images/muhammed.png',
        'isAsset': true,
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) =>
                    const BukhariLibraryPage())),
      },
      {
        'title': 'الراديو',
        'icon': Icons.radio,
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const RadioPage())),
      },
      {
        'title': 'أسماء الله',
        'asset': 'assets/images/names.svg',
        'isSvg': true,
        'isAsset': true,
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const AllahNamesPage())),
      },
      {
        'title': 'التقويم',
        'icon': Icons.event_note_rounded,
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const CalendarPage())),
      },
      {
        'title': 'القبلة',
        'icon': Icons.explore_rounded,
        'onTap': () {
          final s =
              context.findAncestorStateOfType<_MainLayoutState>();
          s?.setState(() => s._currentIndex = 1);
        },
      },
      {
        'title': 'الصوتيات',
        'icon': Icons.library_music_rounded,
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) =>
                    const AudioRecitersScreen())),
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'خدمات التطبيق',
            style: GoogleFonts.tajawal(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark
                    ? Colors.white
                    : const Color(0xFF546E7A)),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: services.length,
            itemBuilder: (ctx, i) =>
                _buildServiceCard(ctx, isDark, services[i]),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, bool isDark,
      Map<String, dynamic> item) {
    final iconColor =
        isDark ? Colors.grey[400]! : const Color(0xFF546E7A);
    return GestureDetector(
      onTap: item['onTap'] as VoidCallback?,
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E2428)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.1),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: isDark ? 0.22 : 0.06),
              blurRadius: 15,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFFBFBFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : const Color(0xFFE0E0E0),
                  width: 0.5,
                ),
              ),
              child: item['isAsset'] == true
                  ? (item['isSvg'] == true
                      ? SvgPicture.asset(
                          item['asset'] as String,
                          height: 24,
                          width: 24,
                          colorFilter: ColorFilter.mode(
                              iconColor, BlendMode.srcIn),
                        )
                      : Image.asset(
                          item['asset'] as String,
                          height: 24,
                          width: 24,
                        ))
                  : Icon(item['icon'] as IconData,
                      size: 24, color: iconColor),
            ),
            const SizedBox(height: 8),
            Text(
              item['title'] as String,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: GoogleFonts.tajawal(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? Colors.white
                    : const Color(0xFF546E7A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  //  Bukhari Daily Hadith
  // ---------------------------------------------------------------------------
  Widget _buildBukhariDailyCard(
      BuildContext context, bool isDark) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: BukhariDatabaseService.getDailyHadith(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final text = snapshot.data!['text'] as String;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: GestureDetector(
            onTap: () =>
                _showHadithBottomSheet(context, text),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.1),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                        alpha: isDark ? 0.0 : 0.06),
                    blurRadius: 20,
                    spreadRadius: 1,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                          Icons.format_quote_rounded,
                          color: Color(0xFFD4AF37),
                          size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'حديث اليوم',
                        style: GoogleFonts.tajawal(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF546E7A)),
                      ),
                      const Spacer(),
                      const Icon(Icons.open_in_full_rounded,
                          color: Colors.grey, size: 14),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.amiri(
                        fontSize: 16,
                        height: 1.6,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF546E7A)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showHadithBottomSheet(
      BuildContext context, String fullText) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color:
                Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color:
                      Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 8),
                  children: [
                    Text(
                      'حديث اليوم',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.tajawal(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color:
                              const Color(0xFFD4AF37)),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      fullText,
                      textAlign: TextAlign.justify,
                      textDirection: ui.TextDirection.rtl,
                      style: GoogleFonts.amiri(
                          fontSize: 19,
                          height: 1.8,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  //  Helpers
  // ---------------------------------------------------------------------------
  String _formatDuration(Duration? duration) {
    if (duration == null || duration.isNegative) {
      return "00:00";
    }
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    final s = duration.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
}
