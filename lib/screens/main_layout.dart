import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hijri/hijri_calendar.dart' as hj;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../providers/location_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/prayer_times_provider.dart';
import '../providers/hijri_calendar_provider.dart';
import '../core/models/hijri_date_model.dart';
import '../core/models/islamic_event_model.dart';
import '../services/hadith_service.dart';
import '../services/bukhari_database_service.dart';
import '../core/models/prayer_times_model.dart';
import '../core/theme/app_colors.dart';
import 'azkar_screen.dart';
import 'allah_names_page.dart';
import 'radio_page.dart';
import 'calendar_page.dart';
import 'bukhari_library_page.dart';
import '../features/quran_madinah/ui/index_screen.dart';
import 'qibla/qibla_screen.dart';
import 'settings/settings_screen.dart';
import 'tasbih_screen.dart';
import '../features/audio/screens/audio_reciters_screen.dart';
import 'eid/eid_celebration_screen.dart';
import '../core/services/miui_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Helper: UnderDevelopmentPage (kept here, same as before in tibyan_menu_page)
// ─────────────────────────────────────────────────────────────────────────────
class UnderDevelopmentPage extends StatelessWidget {
  const UnderDevelopmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF121212)
            : const Color(0xFFF5F5F0),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
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
                child: const Icon(
                  Icons.construction_rounded,
                  size: 80,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'سيتم تطويره قريباً',
                style: GoogleFonts.tajawal(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF546E7A),
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

// ─────────────────────────────────────────────────────────────────────────────
//  MainLayout — 3-tab shell
// ─────────────────────────────────────────────────────────────────────────────
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _batteryBannerDismissed = false;
  bool _miuiBannerDismissed = false;
  bool _wasPaused = false;

  /// Index 0: Prayers (HomeScreen)
  /// Index 1: Qibla (QiblaScreen)
  /// Index 2: Settings (SettingsScreen)
  final List<Widget> _screens = [
    const HomeScreen(),
    const QiblaScreen(),
    const TasbihScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Check battery optimization status after first frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBatteryOptimization();
      _checkMiuiGuidance();
    });
  }

  /// Shows a persistent MaterialBanner if battery optimization is active.
  Future<void> _checkBatteryOptimization() async {
    if (!mounted || _batteryBannerDismissed) return;
    // Only relevant on Android
    if (!Platform.isAndroid) return;
    try {
      final isIgnoring = await Permission.ignoreBatteryOptimizations.isGranted;
      if (!isIgnoring && mounted) {
        _showBatteryBanner();
      }
    } catch (_) {
      // Silently ignore — battery check is non-critical
    }
  }

  /// Called when the app lifecycle changes (foreground/background)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasPaused = true;
    } else if (state == AppLifecycleState.resumed) {
      // 1. Re-check battery permission for auto-hide
      if (!_batteryBannerDismissed) {
        _checkBatteryAndHideBanner();
      }
      if (!_miuiBannerDismissed) {
        _checkMiuiGuidance();
      }

      // 2. Only go to Splash if we were truly paused (backgrounded)
      // and not just inactive (e.g. notification shade)
      if (_wasPaused) {
        _wasPaused = false; // Reset the flag
        _navigateToSplash();
      }
    }
  }

  void _navigateToSplash() {
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  /// Re-check battery optimisation status and hide the banner if now granted.
  Future<void> _checkBatteryAndHideBanner() async {
    if (!mounted) return;
    try {
      final isIgnoring = await Permission.ignoreBatteryOptimizations.isGranted;
      if (isIgnoring && mounted) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
        setState(() => _batteryBannerDismissed = true);
      }
    } catch (_) {}
  }

  Future<void> _checkMiuiGuidance() async {
    if (!mounted || _miuiBannerDismissed) return;
    if (!Platform.isAndroid) return;
    
    final isMiui = await MiuiService.isMiui();
    final setupCompleted = await MiuiService.isSetupCompleted();
    
    if (isMiui && !setupCompleted && mounted) {
      _showMiuiWarningBanner();
    }
  }

  void _showBatteryBanner() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        leading: const Icon(
          Icons.battery_alert_rounded,
          color: Color(0xFFE65100),
          size: 28,
        ),
        content: Text(
          'لضمان دقة الأذان والتنبيهات، يرجى إيقاف تحسين البطارية للتطبيق.',
          style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w500),
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: const Color(0xFFFFF3E0),
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: () async {
              // Open the system battery optimisation settings page using native MethodChannel
              try {
                const MethodChannel(
                  'imsakia/notifications',
                ).invokeMethod('openBatteryOptimizationSettings');
              } catch (e) {
                // Fallback to permission_handler if channel fails
                await Permission.ignoreBatteryOptimizations.request();
              }
              // Banner will auto-hide in didChangeAppLifecycleState when user returns
            },
            child: Text(
              'إعدادات',
              style: GoogleFonts.tajawal(
                fontWeight: FontWeight.bold,
                color: const Color(0xFFE65100),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              setState(() => _batteryBannerDismissed = true);
            },
            child: Text(
              'إغلاق',
              style: GoogleFonts.tajawal(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  void _showMiuiWarningBanner() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        leading: const Icon(
          Icons.notification_important_rounded,
          color: Colors.amber,
          size: 28,
        ),
        content: Text(
          'تنبيه: أجهزة شاومي تتطلب إعدادات إاضافية لضمان عمل الأذان بصوت مرتفع وفوري.',
          style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w500),
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: Colors.amber.shade50,
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              Navigator.pushNamed(context, '/miui_guidance');
            },
            child: Text(
              'تفعيل الآن',
              style: GoogleFonts.tajawal(
                fontWeight: FontWeight.bold,
                color: Colors.amber.shade900,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              setState(() => _miuiBannerDismissed = true);
            },
            child: Text(
              'تجاهل',
              style: GoogleFonts.tajawal(color: Colors.grey[700]),
            ),
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
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2024) : Colors.white,
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
              onTap: (index) => setState(() => _currentIndex = index),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor: isDark ? Colors.grey[500] : Colors.grey[700],
              selectedLabelStyle: GoogleFonts.tajawal(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              unselectedLabelStyle: GoogleFonts.tajawal(
                fontSize: 11,
                fontWeight: isDark ? FontWeight.normal : FontWeight.w500,
              ),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.mosque), // Prayers
                  label: 'الصلوات',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.explore), // Compass
                  label: 'القبلة',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.fingerprint), // Tasbih
                  label: 'المسبحة',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings), // Settings
                  label: 'الإعدادات',
                ),
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
            onPressed: () async {
              // First dismiss the dialog
              Navigator.pop(context);
              // Ask the platform to finish the task cleanly
              await SystemNavigator.pop();
              // REMOVED exit(0) to ensure the background service isolate
              // survives even if the UI part of the app is "closed".
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

// ─────────────────────────────────────────────────────────────────────────────
//  HomeScreen — Zad Dashboard
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!HadithService.instance.isInitialized) {
      HadithService.instance.initialize();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final prayerProvider = Provider.of<PrayerTimesProvider>(context);
    final locationProvider = Provider.of<LocationProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String cityName =
        locationProvider.location?.cityName ?? 'جاري التحديد...';
    final String countryName = locationProvider.location?.countryName ?? '';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF121212)
            : const Color(0xFFF7F8FA),
        body: RefreshIndicator(
          onRefresh: () async {
            await locationProvider.fetchGpsLocation(
              locale: settings.languageCode,
              onLocationChanged: (loc) =>
                  prayerProvider.calculate(loc, settings.calculationMethod),
            );
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Dynamic Header ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _buildDynamicHeader(
                  context,
                  isDark,
                  cityName,
                  countryName,
                  prayerProvider.prayerTimes,
                ),
              ),

              // ── Date Card (Hijri & Gregorian) ───────────────────────────────
              SliverToBoxAdapter(child: _buildDateCard(context, isDark)),

              // ── Dynamic Islamic Event Card ───────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _buildDynamicEventCard(
                    context,
                    isDark,
                    settings.hijriBaseOffset,
                  ),
                ),
              ),

              // ── Quran Card ─────────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildQuranCard(context, isDark)),

              // ── Prayer Times Horizontal Row ────────────────────────────────
              SliverToBoxAdapter(
                child: Consumer<PrayerTimesProvider>(
                  builder: (context, prayerProvider, child) {
                    return _buildHorizontalPrayerRow(
                      context,
                      isDark,
                      prayerProvider.prayerTimes,
                    );
                  },
                ),
              ),

              // ── Upcoming Events ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: _buildUpcomingEventsSection(
                  context,
                  isDark,
                  settings.hijriBaseOffset,
                ),
              ),

              // ── Services Grid ──────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildServicesSection(context, isDark)),

              // ── Hadith / Special Event Card (Moved Up) ─────────────────────
              // Removed from here

              // ── Bukhari Daily Hadith (Bottom) ──────────────────────────────
              SliverToBoxAdapter(
                child: _buildBukhariDailyCard(context, isDark),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 150)),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. Dynamic Header ─────────────────────────────────────────────────────

  /// Returns the background image asset path based on the current prayer period.
  String _getHeaderImage(PrayerTimesModel? model) {
    final prayerName = model?.currentPrayer?.name;
    if (prayerName == Prayer.fajr) {
      return 'assets/images/header_fajr.png';
    } else if (prayerName == Prayer.dhuhr) {
      return 'assets/images/header_dhuhr.png';
    } else if (prayerName == Prayer.asr) {
      return 'assets/images/header_dhuhr.png';
    } else if (prayerName == Prayer.maghrib) {
      return 'assets/images/header_maghrib.png';
    } else {
      return 'assets/images/header_isha.png'; // matches Night/Isha/None
    }
  }

  /// Returns gradient overlay colors based on time-of-day and theme.
  List<Color> _getHeaderGradient(bool isDark, String img) {
    if (isDark) {
      // Dark mode: always cool dark overlay
      return [
        const Color(0xFF0D1B2A).withValues(alpha: 0.75),
        const Color(0xFF0D1B2A).withValues(alpha: 0.50),
        Colors.transparent,
      ];
    }
    if (img.contains('fajr')) {
      return [
        const Color(0xFF1A1040).withValues(alpha: 0.70),
        const Color(0xFF4B2C6E).withValues(alpha: 0.45),
        Colors.transparent,
      ];
    }
    if (img.contains('dhuhr')) {
      return [
        const Color(0xFF0B3D6B).withValues(alpha: 0.65),
        const Color(0xFF1565C0).withValues(alpha: 0.35),
        Colors.transparent,
      ];
    }
    if (img.contains('maghrib')) {
      return [
        const Color(0xFF7B2C1E).withValues(alpha: 0.70),
        const Color(0xFFBF5A2B).withValues(alpha: 0.40),
        Colors.transparent,
      ];
    }
    // Night/isha
    return [
      const Color(0xFF050D1A).withValues(alpha: 0.80),
      const Color(0xFF0A1628).withValues(alpha: 0.50),
      Colors.transparent,
    ];
  }

  Widget _buildDynamicHeader(
    BuildContext context,
    bool isDark,
    String cityName,
    String countryName,
    PrayerTimesModel? model,
  ) {
    // Determine the active header image using current prayer
    final String headerImage = _getHeaderImage(model);

    final gradient = _getHeaderGradient(isDark, headerImage);

    // Get the countdown stream
    final provider = Provider.of<PrayerTimesProvider>(context, listen: false);

    return SizedBox(
      width: double.infinity,
      height: 285,
      child: Stack(
        children: [
          // Background image
          Positioned.fill(child: Image.asset(headerImage, fit: BoxFit.cover)),
          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: gradient,
                ),
              ),
            ),
          ),
          // Full-height overlay for text readability (top part)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 180,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Content
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
                // App name + location (settings moved to BottomNav)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onDoubleTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'جاري تشغيل تكبيرات العيد...',
                              textDirection: TextDirection.rtl,
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => const EidCelebrationScreen(
                              eidName: 'عيد الفطر المبارك',
                            ),
                          ),
                        );
                      },
                      onLongPress: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'جاري تشغيل تكبيرات العيد...',
                              textDirection: TextDirection.rtl,
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => const EidCelebrationScreen(
                              eidName: 'عيد الفطر المبارك',
                            ),
                          ),
                        );
                      },
                      child: Image.asset(
                        'assets/images/zad_icon.png',
                        height: 45,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.white70,
                          size: 13,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          cityName.isEmpty
                              ? 'لم يتم تحديد موقع...'
                              : '$cityName${countryName.isNotEmpty ? ' - $countryName' : ''}',
                          style: GoogleFonts.tajawal(
                            fontSize: 12,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const Spacer(),

                // "الصلاة القادمة" card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.22),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Prayer name block
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الصلاة القادمة',
                              style: GoogleFonts.tajawal(
                                fontSize: 12,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              model?.nextPrayer?.name.nameAr ?? '...',
                              style: GoogleFonts.tajawal(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Countdown chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF1565C0,
                              ).withValues(alpha: 0.45),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          _formatDuration(provider.countdown),
                          style: GoogleFonts.tajawal(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.5,
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

  // ── 1.5 Date Card ────────────────────────────────────────────────────────

  Widget _buildDateCard(BuildContext context, bool isDark) {
    return Consumer<HijriCalendarProvider>(
      builder: (context, hijriProvider, _) {
        final hijriDate = hijriProvider.hijriDate;
        final now = DateTime.now();
        final gregorianStr = DateFormat.yMMMMd('ar').format(now);
        final hijriStr = hijriDate != null
            ? '${hijriDate.day} ${hijriDate.monthNameAr} ${hijriDate.year} هـ'
            : '...';

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.1),
                width: 0.8,
              ),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 15,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 5,
                        spreadRadius: -1,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.calendar_today_outlined,
                    color: AppColors.gold,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hijriStr,
                        style: GoogleFonts.tajawal(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.gold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        gregorianStr,
                        style: GoogleFonts.tajawal(
                          fontSize: 14,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF546E7A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Upcoming Events Section ──────────────────────────────────────────────

  Widget _buildUpcomingEventsSection(
    BuildContext context,
    bool isDark,
    int offset,
  ) {
    final hijriProvider = Provider.of<HijriCalendarProvider>(context);
    final events = hijriProvider.getUpcomingEvents(offset);

    if (events.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            'مناسبات قادمة',
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? Colors.white : const Color(0xFF546E7A),
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final item = events[index];
              final event = item['event'] as IslamicEvent;
              final daysLeft = item['daysLeft'] as int;

              return Container(
                width: 150,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: daysLeft == 0
                      ? LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFFB8860B),
                                  const Color(0xFF8B6508),
                                ]
                              : [
                                  const Color(0xFFFFD700),
                                  const Color(0xFFDAA520),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: daysLeft == 0
                      ? null
                      : (isDark ? const Color(0xFF1E2428) : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: daysLeft == 0
                        ? (isDark
                              ? Colors.white24
                              : Colors.orange.withValues(alpha: 0.3))
                        : (isDark
                              ? Colors.white10
                              : Colors.black.withValues(alpha: 0.1)),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: daysLeft == 0
                          ? (isDark
                                ? Colors.black45
                                : Colors.orange.withValues(alpha: 0.2))
                          : Colors.black.withValues(alpha: isDark ? 0.0 : 0.08),
                      blurRadius: daysLeft == 0 ? 12 : 15,
                      spreadRadius: daysLeft == 0 ? 0 : 1,
                      offset: const Offset(0, 4),
                    ),
                    if (daysLeft != 0 && !isDark)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 5,
                        spreadRadius: -1,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      event.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.tajawal(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: daysLeft == 0
                            ? (isDark ? Colors.white : const Color(0xFF546E7A))
                            : (isDark ? Colors.white : const Color(0xFF546E7A)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${event.day} ${HijriDateModel.create(1445, event.month, 1).monthNameAr}',
                      style: GoogleFonts.tajawal(
                        fontSize: 10,
                        color: daysLeft == 0
                            ? (isDark ? Colors.white70 : Colors.black54)
                            : (isDark ? Colors.white38 : Colors.black38),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: daysLeft == 0
                            ? Colors.black.withValues(alpha: 0.1)
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.grey.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        daysLeft == 0 ? 'المناسبة اليوم' : 'بعد $daysLeft يوم',
                        style: GoogleFonts.tajawal(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: daysLeft == 0
                              ? (isDark
                                    ? Colors.white
                                    : const Color(0xFF546E7A))
                              : (isDark ? Colors.white70 : Colors.grey[700]),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── 2. Quran Card ─────────────────────────────────────────────────────────

  Widget _buildQuranCard(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const IndexScreen()),
          );
        },
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
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
              const SizedBox(width: 20),
              // Text content
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
                    const SizedBox(height: 4),
                    Text(
                      'قراءة الورد اليومي',
                      style: GoogleFonts.tajawal(
                        fontSize: 13,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Quran logo
              Hero(
                tag: 'quran_logo_hero',
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 16),
                  child: Image.asset(
                    'assets/images/quranlogo.png',
                    height: 70,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 3. Horizontal Prayer Times Row ───────────────────────────────────────

  Widget _buildHorizontalPrayerRow(
    BuildContext context,
    bool isDark,
    PrayerTimesModel? model,
  ) {
    if (model == null) return const SizedBox.shrink();

    // Adjust Imsak logic conditionally if we are in Ramadan.
    // We compute the current hijri month locally for this check.
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    var today = hj.HijriCalendar.now();
    today.hDay += settings.hijriOffset; // adjust with user offset if applicable
    final int currentMonth = today.hMonth;

    // Convert the prayer list up to isha
    final prayerKeys = [
      Prayer.fajr,
      Prayer.sunrise,
      Prayer.dhuhr,
      Prayer.asr,
      Prayer.maghrib,
      Prayer.isha,
    ];

    final nextPrayer = model.nextPrayer?.name;

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
              color: isDark ? Colors.white : const Color(0xFF546E7A),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Imsak card only in Ramadan (month 9)
                if (currentMonth == 9)
                  _buildPrayerCard(
                    context,
                    isDark,
                    name: 'الإمساك',
                    icon: Icons.bedtime_outlined,
                    time: model.fajr.subtract(const Duration(minutes: 15)),
                    isNext: nextPrayer == Prayer.imsak,
                  ),
                ...prayerKeys.map((key) {
                  // We extract the time directly from the model
                  DateTime time;
                  switch (key) {
                    case Prayer.fajr:
                      time = model.fajr;
                      break;
                    case Prayer.sunrise:
                      time = model.sunrise;
                      break;
                    case Prayer.dhuhr:
                      time = model.dhuhr;
                      break;
                    case Prayer.asr:
                      time = model.asr;
                      break;
                    case Prayer.maghrib:
                      time = model.maghrib;
                      break;
                    case Prayer.isha:
                      time = model.isha;
                      break;
                    default:
                      time =
                          DateTime.now(); // Should not happen with defined keys
                  }

                  return _buildPrayerCard(
                    context,
                    isDark,
                    name: key.nameAr,
                    icon: _getPrayerIcon(key),
                    time: time,
                    isNext: nextPrayer == key,
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerCard(
    BuildContext context,
    bool isDark, {
    required String name,
    required IconData icon,
    required DateTime? time,
    required bool isNext,
  }) {
    final Color activeColor = AppColors.gold;
    final Color cardBg = isNext
        ? (isDark ? activeColor.withValues(alpha: 0.2) : activeColor)
        : (isDark ? const Color(0xFF1E2428) : Colors.white);
    final Color textColor = isNext
        ? (isDark ? Colors.white : const Color(0xFF2D2D2D))
        : (isDark ? Colors.white : Colors.black54);
    final Color subColor = isNext
        ? (isDark ? activeColor : const Color(0xFF2D2D2D))
        : (isDark ? Colors.grey[400]! : Colors.grey[600]!);

    return Container(
      width: 90,
      margin: const EdgeInsets.only(left: 12),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNext
              ? AppColors.gold
              : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.2)),
          width: isNext ? 2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isNext
                ? AppColors.gold.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: isDark ? 0.0 : 0.08),
            blurRadius: isNext ? 15 : 15,
            spreadRadius: isNext ? 0 : 1,
            offset: isNext ? const Offset(0, 5) : const Offset(0, 4),
          ),
          if (!isNext && !isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 5,
              spreadRadius: -1,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: subColor, size: 22),
          const SizedBox(height: 10),
          Text(
            name,
            textAlign: TextAlign.center,
            style: GoogleFonts.tajawal(
              fontSize: 12,
              fontWeight: isNext ? FontWeight.bold : FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            time != null
                ? "${(time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour)).toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}"
                : "--:--",
            style: GoogleFonts.tajawal(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. Services Grid ──────────────────────────────────────────────────────

  Widget _buildServicesSection(BuildContext context, bool isDark) {
    final List<Map<String, dynamic>> services = [
      {
        'title': 'القرآن الكريم',
        'icon': Icons.menu_book_rounded,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const IndexScreen()),
        ),
      },
      {
        'title': 'الأذكار',
        'icon': Icons.auto_stories,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AzkarScreenWidget()),
        ),
      },
      {
        'title': 'الأحاديث',
        'asset': 'assets/images/muhammed.png',
        'isAsset': true,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BukhariLibraryPage()),
        ),
      },
      {
        'title': 'الراديو',
        'icon': Icons.radio,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RadioPage()),
        ),
      },
      {
        'title': 'أسماء الله',
        'asset': 'assets/images/names.svg',
        'isSvg': true,
        'isAsset': true,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AllahNamesPage()),
        ),
      },
      {
        'title': 'التقويم',
        'icon': Icons.event_note_rounded,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CalendarPage()),
        ),
      },
      {
        'title': 'القبلة',
        'icon': Icons.explore_rounded,
        'onTap': () {
          // Find parent state to change index
          final mainState = context.findAncestorStateOfType<_MainLayoutState>();
          if (mainState != null) {
            mainState.setState(() => mainState._currentIndex = 1);
          }
        },
      },
      {
        'title': 'الصوتيات',
        'icon': Icons.library_music_rounded,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AudioRecitersScreen()),
        ),
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
              color: isDark ? Colors.white : const Color(0xFF546E7A),
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final item = services[index];
              return _buildServiceCard(context, isDark, item);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(
    BuildContext context,
    bool isDark,
    Map<String, dynamic> item,
  ) {
    final Color iconColor = isDark
        ? Colors.grey[400]!
        : const Color(0xFF546E7A);

    return GestureDetector(
      onTap: item['onTap'] as VoidCallback?,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2428) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.1),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
              blurRadius: 15,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 5,
                spreadRadius: -1,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon or Image Container
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
                  ? ((item['isSvg'] == true)
                        ? SvgPicture.asset(
                            item['asset'] as String,
                            height: 24,
                            width: 24,
                            colorFilter: ColorFilter.mode(
                              iconColor,
                              BlendMode.srcIn,
                            ),
                          )
                        : Image.asset(
                            item['asset'] as String,
                            height: 24,
                            width: 24,
                          ))
                  : Icon(item['icon'] as IconData, size: 24, color: iconColor),
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
                color: isDark ? Colors.white : const Color(0xFF546E7A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 5-A. Dynamic Islamic Event Card ──────────────────────────────────────

  /// Returns event metadata based on today's Hijri date.
  ///
  /// Map keys:
  ///   title    - String: main Arabic title
  ///   subtitle - String: secondary line
  ///   emoji    - String: leading emoji character
  ///   gradient - List of Color: card gradient colours
  ///   isToday  - bool: true when the event is today (no countdown)
  Map<String, dynamic> _getIslamicEventInfo(int hijriOffset) {
    final hijri = hj.HijriCalendar.now();
    final int day = hijri.hDay + hijriOffset;
    final int month = hijri.hMonth;

    // 1. Eid al-Fitr (1 Shawwal)
    if (month == 10 && day == 1) {
      return {
        'title': 'عيد الفطر المبارك',
        'subtitle': 'تقبل الله صيامكم وقيامكم',
        'emoji': '🌙',
        'gradient': [const Color(0xFFE65100), const Color(0xFFFF8F00)],
        'isToday': true,
        'isEid': true,
      };
    }

    // 2. Day of Arafat (9 Dhul Hijjah)
    if (month == 12 && day == 9) {
      return {
        'title': 'يوم عرفة',
        'subtitle': 'لبيك اللهم لبيك',
        'emoji': '🕌',
        'gradient': [const Color(0xFF4E342E), const Color(0xFF795548)],
        'isToday': true,
        'isEid': false,
      };
    }

    // 3. Eid al-Adha (10 Dhul Hijjah)
    if (month == 12 && day == 10) {
      return {
        'title': 'عيد الأضحى المبارك',
        'subtitle': 'أعاده الله عليكم بالخير واليُمن',
        'emoji': '🐑',
        'gradient': [const Color(0xFF1B5E20), const Color(0xFF388E3C)],
        'isToday': true,
        'isEid': true,
      };
    }

    // 4. Tashreeq Days (11-13 Dhul Hijjah)
    if (month == 12 && day >= 11 && day <= 13) {
      const dayNames = ['الأول', 'الثاني', 'الثالث'];
      final dayIndex = (day - 11).clamp(0, 2);
      return {
        'title': 'أيام التشريق',
        'subtitle': 'اليوم ${dayNames[dayIndex]}',
        'emoji': '✨',
        'gradient': [const Color(0xFF006064), const Color(0xFF00838F)],
        'isToday': true,
        'isEid': true,
      };
    }

    // 5. In Ramadan (Month 9)
    if (month == 9) {
      return {
        'title': 'رمضان كريم',
        'subtitle': 'شهر الخير والبركات',
        'emoji': '🌜',
        'gradient': [const Color(0xFF4A148C), const Color(0xFF7B1FA2)],
        'isToday': true,
        'isEid': false,
      };
    }

    // 6. Countdown to Eid al-Adha (2 Shawwal to 9 Dhul Hijjah)
    final bool afterEidFitr =
        (month == 10 && day >= 2) || month == 11 || (month == 12 && day < 9);
    if (afterEidFitr) {
      final target = hj.HijriCalendar()
        ..hYear = hijri.hYear
        ..hMonth = 12
        ..hDay = 10;
      final targetDate = target.hijriToGregorian(hijri.hYear, 12, 10);
      final diff = targetDate.difference(DateTime.now());
      final remaining = (diff.isNegative ? 0 : diff.inDays) + 1;
      return {
        'title': 'عيد الأضحى المبارك',
        'subtitle': remaining == 0 ? 'غداً إن شاء الله' : 'بعد $remaining يوم',
        'emoji': '🐑',
        'gradient': [const Color(0xFF1B5E20), const Color(0xFF388E3C)],
        'isToday': false,
        'daysLeft': remaining,
        'isEid': false,
      };
    }

    // 7. Default: Countdown to next Ramadan
    int targetYear = hijri.hYear;
    if (month > 9 || (month == 9 && day >= 1)) targetYear++;
    final targetRamadan = hj.HijriCalendar();
    final targetDate = targetRamadan.hijriToGregorian(targetYear, 9, 1);
    final diff = targetDate.difference(DateTime.now());
    final daysLeft = diff.isNegative ? 0 : diff.inDays;

    return {
      'title': 'رمضان المبارك',
      'subtitle': 'بعد $daysLeft يوم إن شاء الله',
      'emoji': '🌛',
      'gradient': [const Color(0xFF1A237E), const Color(0xFF3949AB)],
      'isToday': false,
      'daysLeft': daysLeft,
      'isEid': false,
    };
  }

  Widget _buildDynamicEventCard(
    BuildContext context,
    bool isDark,
    int hijriOffset,
  ) {
    final event = _getIslamicEventInfo(hijriOffset);
    final title = event['title'] as String;
    final subtitle = event['subtitle'] as String;
    final emoji = event['emoji'] as String;
    final month = hj.HijriCalendar.now().hMonth;
    final isToday = event['isToday'] as bool;
    final gradient = event['gradient'] as List<Color>;
    // Eid days: pure festive card, no Hadith
    final bool isEidDay =
        event.containsKey('isEid') && (event['isEid'] as bool);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // ── Event Header ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          gradient[0].withValues(alpha: 0.80),
                          gradient[1].withValues(alpha: 0.65),
                        ]
                      : gradient,
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                boxShadow: [
                  BoxShadow(
                    color: gradient[0].withValues(alpha: isDark ? 0.20 : 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 38)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.tajawal(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // "اليوم" badge — only when there is an actual event today
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'اليوم',
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Daily Hadith section (Nafahat Ramadaniyya) ─────────────────────────
            if (!isEidDay && month == 9)
              Consumer<HadithService>(
                builder: (context, service, _) {
                  final hadith = service.getTodayHadith();
                  if (hadith == null) return const SizedBox.shrink();
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1F24) : Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: gradient[0].withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.format_quote_rounded,
                              color: gradient[0].withValues(
                                alpha: isDark ? 0.75 : 0.85,
                              ),
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'نفحات رمضانية',
                              style: GoogleFonts.tajawal(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF546E7A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          hadith.text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: GoogleFonts.amiri(
                            fontSize: 15,
                            height: 1.7,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF37474F),
                          ),
                        ),
                        if (hadith.source.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              hadith.source,
                              style: GoogleFonts.tajawal(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.white38
                                    : Colors.grey[500],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBukhariDailyCard(BuildContext context, bool isDark) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: BukhariDatabaseService.getDailyHadith(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final hadith = snapshot.data!;
        final text = hadith['text'] as String;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: GestureDetector(
            onTap: () => _showHadithBottomSheet(context, text),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                    color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.06),
                    blurRadius: 20,
                    spreadRadius: 1,
                    offset: const Offset(0, 8),
                  ),
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      spreadRadius: -1,
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
                        Icons.format_quote_rounded,
                        color: AppColors.gold,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'حديث اليوم',
                        style: GoogleFonts.tajawal(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF546E7A),
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.open_in_full_rounded,
                        color: Colors.grey,
                        size: 14,
                      ),
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

  void _showHadithBottomSheet(BuildContext context, String fullText) {
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
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  children: [
                    Text(
                      'حديث اليوم',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.tajawal(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      fullText,
                      textAlign: TextAlign.justify,
                      textDirection: ui.TextDirection.rtl,
                      style: GoogleFonts.amiri(
                        fontSize: 19,
                        height: 1.8,
                        fontWeight: FontWeight.w500,
                      ),
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

  // ── Helpers (unchanged) ───────────────────────────────────────────────────

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return "00:00";
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  IconData _getPrayerIcon(Prayer key) {
    switch (key) {
      case Prayer.fajr:
        return Icons.wb_twilight;
      case Prayer.sunrise:
        return Icons.wb_sunny_outlined;
      case Prayer.maghrib:
        return Icons.nightlight_round;
      case Prayer.isha:
        return Icons.nights_stay;
      default:
        return Icons.wb_sunny;
    }
  }
}
