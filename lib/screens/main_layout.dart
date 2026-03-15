import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/location_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/prayer_times_provider.dart';
import '../services/hadith_service.dart';
import '../services/bukhari_database_service.dart';
import '../core/models/prayer_times_model.dart';
import '../core/theme/app_colors.dart';


import 'azkar_screen.dart';
import 'allah_names_page.dart';
import 'radio_page.dart';
import 'calendar_page.dart';
import 'bukhari_library_page.dart';
import '../widgets/neumorphic_box.dart';
import '../features/quran_madinah/ui/index_screen.dart';
import 'qibla/qibla_screen.dart';
import 'settings/settings_screen.dart';


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
                  color: isDark ? Colors.white : Colors.black87,
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

  /// Index 0: Prayers (HomeScreen)
  /// Index 1: Qibla (QiblaScreen)
  /// Index 2: Settings (SettingsScreen)
  final List<Widget> _screens = [
    const HomeScreen(),
    const QiblaScreen(),
    const SettingsScreen(),
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
        floatingActionButtonLocation:
            FloatingActionButtonLocation.centerFloat,
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
              unselectedItemColor:
                  isDark ? Colors.grey[500] : Colors.grey[400],
              selectedLabelStyle: GoogleFonts.tajawal(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              unselectedLabelStyle: GoogleFonts.tajawal(fontSize: 11),
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('تأكيد الخروج',
            style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
        content: Text('هل تريد الخروج من التطبيق؟',
            style: GoogleFonts.tajawal()),
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
            child: Text('خروج',
                style: GoogleFonts.tajawal(color: Colors.white)),
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

    final String cityName = locationProvider.location?.cityName ?? 'جاري التحديد...';
    final String countryName = locationProvider.location?.countryName ?? '';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF121212)
            : const Color(0xFFF0F2F5),
        body: RefreshIndicator(
          onRefresh: () async {
            await locationProvider.fetchGpsLocation(
              locale: settings.languageCode,
              onLocationChanged: (loc) => prayerProvider.calculate(
                loc,
                settings.calculationMethod,
              ),
            );
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Dynamic Header ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _buildDynamicHeader(
                    context, isDark, cityName, countryName, prayerProvider.prayerTimes),
              ),

              // ── Quran Card ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _buildQuranCard(context, isDark),
              ),

              // ── Prayer Times Horizontal Row ────────────────────────────────
              SliverToBoxAdapter(
                child: Consumer<PrayerTimesProvider>(
                  builder: (context, prayerProvider, child) {
                    return _buildHorizontalPrayerRow(
                        context, isDark, prayerProvider.prayerTimes);
                  },
                ),
              ),

              // ── Services Grid ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _buildServicesSection(context, isDark),
              ),

              // ── Hadith / Special Event Card ────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: _buildSpecialEventCard(settings.hijriOffset),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
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
          Positioned.fill(
            child: Image.asset(
              headerImage,
              fit: BoxFit.cover,
            ),
          ),
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
                // Row: App name + Settings
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.asset(
                          'assets/images/zad_icon.png',
                          height: 45,
                          fit: BoxFit.contain,
                        ),
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                color: Colors.white70, size: 13),
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
                    // Settings icon
                    GestureDetector(
                      onTap: () =>
                          Navigator.pushNamed(context, '/settings'),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.settings_outlined,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // "الصلاة القادمة" card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.22),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: 0.18),
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
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1565C0)
                                  .withValues(alpha: 0.45),
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

  // ── 2. Quran Card ─────────────────────────────────────────────────────────

  Widget _buildQuranCard(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const IndexScreen(),
            ),
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
      BuildContext context, bool isDark, PrayerTimesModel? model) {
    if (model == null) return const SizedBox.shrink();

    // Adjust Imsak logic conditionally if we are in Ramadan.
    // We compute the current hijri month locally for this check.
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    var today = HijriCalendar.now();
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
              color: isDark ? Colors.white : Colors.black87,
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
                    case Prayer.fajr: time = model.fajr; break;
                    case Prayer.sunrise: time = model.sunrise; break;
                    case Prayer.dhuhr: time = model.dhuhr; break;
                    case Prayer.asr: time = model.asr; break;
                    case Prayer.maghrib: time = model.maghrib; break;
                    case Prayer.isha: time = model.isha; break;
                    default: time = DateTime.now(); // Should not happen with defined keys
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
        ? activeColor.withValues(alpha: 0.2)
        : (isDark ? const Color(0xFF1E2428) : Colors.white);
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subColor = isNext ? AppColors.gold : (isDark ? Colors.grey[400]! : Colors.grey[600]!);

    return Container(
      width: 90,
      margin: const EdgeInsets.only(left: 12),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isNext
              ? AppColors.gold
              : (isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.2)),
          width: isNext ? 2 : 1,
        ),
        boxShadow: isNext ? [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ] : [],
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
              color: isNext ? AppColors.gold : textColor,
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
        'title': 'الأذكار',
        'icon': Icons.auto_stories,
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AzkarScreenWidget())),
      },
      {
        'title': 'القرآن الكريم',
        'icon': Icons.menu_book_rounded,
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const IndexScreen())),
      },
      {
        'title': 'مكتبة الحديث',
        'asset': 'assets/images/muhammed.png',
        'isAsset': true,
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const BukhariLibraryPage())),
      },
      {
        'title': 'الراديو',
        'icon': Icons.radio,
        'onTap': () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const RadioPage())),
      },
      {
        'title': 'أسماء الله',
        'asset': 'assets/images/names.svg',
        'isSvg': true,
        'isAsset': true,
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AllahNamesPage())),
      },
      {
        'title': 'التقويم',
        'icon': Icons.event_note_rounded,
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CalendarPage())),
      },
      {
        'title': 'القبلة',
        'icon': Icons.explore_rounded,
        'onTap': () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const UnderDevelopmentPage())),
      },
      {
        'title': 'الصوتيات',
        'icon': Icons.library_music_rounded,
        'onTap': () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const UnderDevelopmentPage())),
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
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          // Wrap in a fixed-height scrollable
          SizedBox(
            height: 205,
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: services.length,
              itemBuilder: (context, index) {
                final item = services[index];
                return _buildServiceCard(context, isDark, item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(
      BuildContext context, bool isDark, Map<String, dynamic> item) {
    final Color iconColor =
        isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return GestureDetector(
      onTap: item['onTap'] as VoidCallback?,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2428) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.grey.withValues(alpha: 0.12),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 
                  isDark ? 0.22 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon or Image
            if (item['isAsset'] == true)
              (item['isSvg'] == true)
                  ? SvgPicture.asset(
                      item['asset'] as String,
                      height: 28,
                      width: 28,
                      colorFilter: ColorFilter.mode(
                          iconColor, BlendMode.srcIn),
                    )
                  : Image.asset(
                      item['asset'] as String,
                      height: 28,
                      width: 28,
                    )
            else
              Icon(
                item['icon'] as IconData,
                size: 28,
                color: iconColor,
              ),
            const SizedBox(height: 8),
            Text(
              item['title'] as String,
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 5. Special Event / Hadith / Ramadan ───────────────────────────────────
  // All existing logic below is UNCHANGED

  Widget _buildSpecialEventCard(int adjustment) {
    final hijriDate = HijriCalendar.now();
    final day = hijriDate.hDay;
    final month = hijriDate.hMonth;

    if (month == 10 && day == 1) {
      return _buildGreetingCard(
          'عيد فطر مبارك', 'تقبل الله صيامكم وقيامكم', Colors.orange);
    }
    if (month == 12 && day == 9) {
      return _buildGreetingCard(
          'وقفة عرفات', 'لبيك اللهم لبيك', Colors.brown);
    }
    if (month == 12 && day >= 10 && day <= 13) {
      return _buildGreetingCard(
          'عيد أضحى مبارك', 'أيام تشريق مباركة', Colors.green);
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
    if (hNow.hMonth > 9 ||
        (hNow.hMonth == 9 && hNow.hDay >= 1)) {
      targetYear++;
    }

    final targetRamadan = HijriCalendar();
    targetRamadan.hYear = targetYear;
    targetRamadan.hMonth = 9;
    targetRamadan.hDay = 1;

    DateTime targetDateTime = targetRamadan.hijriToGregorian(
        targetRamadan.hYear, 9, 1);
    DateTime nowAdjusted =
        DateTime.now().add(Duration(days: adjustment));

    Duration diff = targetDateTime.difference(nowAdjusted);
    int days = diff.inDays;
    int hours = diff.inHours.remainder(24);
    int minutes = diff.inMinutes.remainder(60);

    if (days < 0) return _buildHadithOfTheDayCard();

    return NeumorphicBox(
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
                _buildTimeUnit(
                    days.toString().padLeft(2, '0'), 'يوم'),
                const SizedBox(width: 15),
                _buildTimeUnit(
                    hours.toString().padLeft(2, '0'), 'ساعة'),
                const SizedBox(width: 15),
                _buildTimeUnit(
                    minutes.toString().padLeft(2, '0'), 'دقيقة'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHadithOfTheDayCard() {
    return Consumer<HadithService>(
      builder: (context, service, _) {
        final hadith = service.getTodayHadith();
        if (hadith == null) {
          // Fallback: show daily Bukhari hadith
          return FutureBuilder<Map<String, dynamic>?>(
            future: BukhariDatabaseService.getDailyHadith(),
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                    child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator()));
              }
              if (!snapshot.hasData || snapshot.data == null) {
                return const SizedBox.shrink();
              }
              return _buildHadithCard(
                  context, snapshot.data!['text'] ?? '');
            },
          );
        }
        return _buildHadithCard(context, hadith.text);
      },
    );
  }

  Widget _buildHadithCard(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return NeumorphicBox(
      borderRadius: 20,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome,
                    color: Colors.amber, size: 20),
                const SizedBox(width: 10),
                Text(
                  'حديث اليوم',
                  style: GoogleFonts.tajawal(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Colors.amber[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              text,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.amiri(
                fontSize: 17,
                height: 1.7,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingCard(String title, String sub, Color color) {
    return NeumorphicBox(
      borderRadius: 15,
      baseColor: color,
      lightShadowColor: color.withValues(alpha: 0.5),
      darkShadowColor: color.withValues(alpha: 0.8),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(title,
                style: GoogleFonts.tajawal(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
            Text(sub,
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeUnit(String value, String label) {
    return Column(
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        Text(label,
            style: GoogleFonts.tajawal(
                fontSize: 12, color: const Color(0xFF8B4513))),
      ],
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
