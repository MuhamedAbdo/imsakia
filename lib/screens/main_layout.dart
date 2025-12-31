import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart';
import '../services/prayer_times_service.dart';
import '../services/athan_player_service.dart';
import '../services/hijri_date_service.dart';
import '../services/hadith_service.dart';
import '../utils/app_constants.dart';
import 'quran_screen.dart';
import 'tasbih_screen.dart';
import 'azkar_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const QuranScreen(),
    const TasbihScreen(),
    const AzkarScreen(),
    const FiqhScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    print('App Reached MainLayout');
    return PopScope(
      canPop: false, // Always intercept back button
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        // If we are NOT on the first tab (Prayer Times), go back to the first tab
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0; // Go to Prayer Times tab
          });
        } else {
          // If we ARE on the Prayer Times tab, show exit confirmation
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
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Colors.grey,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.access_time),
                label: 'مواقيت الصلاة',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.menu_book),
                label: 'القرآن',
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
                label: 'فقه الصيام',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showExitConfirmation(BuildContext context) async {
    await showDialog<bool?>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'تأكيد الخروج',
          style: GoogleFonts.tajawal(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          'هل تريد الخروج من التطبيق؟',
          style: GoogleFonts.tajawal(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end, // RTL alignment for Arabic
            children: [
              // Cancel button - secondary action
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
                child: Text(
                  'إلغاء',
                  style: GoogleFonts.tajawal(
                    fontSize: 16,
                    fontWeight: FontWeight.w500, // Lighter weight for secondary action
                  ),
                ),
              ),
              const SizedBox(width: 8), // Spacing between buttons
              // Exit button - primary action
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  SystemNavigator.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(
                  'خروج',
                  style: GoogleFonts.tajawal(
                    fontSize: 16,
                    fontWeight: FontWeight.w600, // Bolder weight for primary action
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final PrayerTimesService _prayerService = PrayerTimesService.instance;
  final AthanPlayerService _athanPlayer = AthanPlayerService.instance;
  late SettingsProvider _settingsProvider;
  
  Map<String, DateTime?> _prayerTimes = {};
  String? _nextPrayer;
  Duration? _timeUntilNextPrayer;
  Duration? _timeUntilRamadan;
  Timer? _countdownTimer;
  Timer? _hadithUpdateTimer;
  String _currentCity = 'القاهرة';
  String _currentCountry = 'مصر';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    _loadPrayerTimes();
    _startCountdownTimer();
    
    // Initialize HadithService once
    if (!HadithService.instance.isInitialized) {
      HadithService.instance.initialize();
    }
    
    // Start hadith update timer with longer interval to reduce spam
    _startHadithUpdateTimer();
    
    // Listen to settings changes
    _settingsProvider.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _hadithUpdateTimer?.cancel();
    _settingsProvider.removeListener(_onSettingsChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Check hadith when app resumes (no setState needed)
      HadithService.instance.checkAndUpdateHadith();
      // Refresh prayer times when app resumes
      _loadPrayerTimes();
    }
  }

  void _onSettingsChanged() {
    if (mounted) {
      // Refresh prayer times when settings change
      _loadPrayerTimes();
    }
  }

  Future<void> _loadPrayerTimes() async {
    final prayerTimes = await _prayerService.getCurrentPrayerTimes();
    if (prayerTimes != null && mounted) {
      setState(() {
        _prayerTimes = prayerTimes;
        _nextPrayer = _prayerService.getNextPrayer();
        _timeUntilNextPrayer = _prayerService.getTimeUntilNextPrayer();
        _timeUntilRamadan = _prayerService.getTimeUntilRamadan();
      });
    }
    
    // Load city information
    final cityName = await _prayerService.getCurrentCityName();
    final countryName = await _prayerService.getCurrentCountryName();
    if (mounted) {
      setState(() {
        _currentCity = cityName;
        _currentCountry = countryName;
      });
    }
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _updatePrayerInfo();
    });
  }

  void _startHadithUpdateTimer() {
    // Check every 5 minutes instead of 1 minute to reduce log spam
    _hadithUpdateTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted) {
        HadithService.instance.checkAndUpdateHadith();
      }
    });
    
    // Force initial update after a short delay to ensure proper initialization
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        HadithService.instance.forceUpdateHadith();
      }
    });
  }

  void _updatePrayerInfo() {
    if (!mounted) return;
    
    // Get current values
    final newPrayerTimes = _prayerService.getAllPrayerTimes();
    final newNextPrayer = _prayerService.getNextPrayer();
    final newTimeUntilNextPrayer = _prayerService.getTimeUntilNextPrayer();
    final newTimeUntilRamadan = _prayerService.getTimeUntilRamadan();
    
    // Only update state if values actually changed
    bool shouldUpdate = false;
    
    if (_nextPrayer != newNextPrayer || 
        _timeUntilNextPrayer?.inSeconds != newTimeUntilNextPrayer?.inSeconds ||
        _timeUntilRamadan?.inSeconds != newTimeUntilRamadan?.inSeconds) {
      shouldUpdate = true;
    }
    
    if (shouldUpdate) {
      setState(() {
        _prayerTimes = newPrayerTimes;
        _nextPrayer = newNextPrayer;
        _timeUntilNextPrayer = newTimeUntilNextPrayer;
        _timeUntilRamadan = newTimeUntilRamadan;
        
        // Check if countdown reaches 00:00:00 and trigger Athan
        if (_timeUntilNextPrayer != null && 
            _timeUntilNextPrayer!.inSeconds <= 5 && 
            _timeUntilNextPrayer!.inSeconds > 0 &&
            !_athanPlayer.isMuted &&
            _nextPrayer != null) {
          _athanPlayer.playAthan(prayerName: _nextPrayer!);
        }
      });
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) {
      // For negative durations, calculate time until tomorrow's first prayer
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));
      final tomorrowFajr = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 5, 30); // Approximate
      final untilTomorrow = tomorrowFajr.difference(now);
      
      final hours = untilTomorrow.inHours;
      final minutes = untilTomorrow.inMinutes.remainder(60);
      final seconds = untilTomorrow.inSeconds.remainder(60);
      
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _getPrayerName(String prayerKey) {
    switch (prayerKey) {
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
        return prayerKey;
    }
  }

  String _getNextPrayerName() {
    if (_nextPrayer == null) return '';
    
    switch (_nextPrayer!) {
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
        return _nextPrayer!;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Remove automatic hadith refresh on build to prevent infinite loops
    // Hadith updates are now handled by the timer and lifecycle events
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              'مواقيت الصلاة',
              style: GoogleFonts.tajawal(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$_currentCity - $_currentCountry',
              style: GoogleFonts.tajawal(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: Theme.of(context).brightness == Brightness.dark
                ? [AppConstants.darkBackgroundColor, AppConstants.darkSurfaceColor]
                : [AppConstants.backgroundColor, AppConstants.surfaceColor],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.mediumPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Next Prayer Card
              _buildNextPrayerCard(),
              
              const SizedBox(height: 24),
              
              // Ramadan Countdown Card
              _buildRamadanCountdownCard(),
              
              const SizedBox(height: 24),
              
              // Prayer Times List
              _buildPrayerTimesList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextPrayerCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppConstants.primaryGradient,
        borderRadius: BorderRadius.circular(AppConstants.largeBorderRadius),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.largePadding),
        child: Column(
          children: [
            Text(
              'الصلاة القادمة',
              style: GoogleFonts.tajawal(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getNextPrayerName(),
              style: GoogleFonts.tajawal(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppConstants.mediumBorderRadius),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.access_time,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatDuration(_timeUntilNextPrayer ?? Duration.zero),
                    style: GoogleFonts.tajawal(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Athan controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Play/Stop button
                GestureDetector(
                  onTap: () {
                    if (_athanPlayer.isPlaying) {
                      _athanPlayer.stopAthan();
                    } else {
                      // For manual play, use the next prayer or default to fajr
                      final prayerToPlay = _nextPrayer ?? 'fajr';
                      _athanPlayer.playAthan(prayerName: prayerToPlay);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _athanPlayer.isPlaying 
                          ? Colors.white.withOpacity(0.3)
                          : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      _athanPlayer.isPlaying ? Icons.stop : Icons.play_arrow,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                
                // Mute/Unmute button
                GestureDetector(
                  onTap: () {
                    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
                    settingsProvider.toggleAthanMute();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Provider.of<SettingsProvider>(context).athanMuted 
                          ? Colors.white.withOpacity(0.3)
                          : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Provider.of<SettingsProvider>(context).athanMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRamadanCountdownCard() {
    // Get Hijri date with adjustment
    final hijriAdjustment = Provider.of<SettingsProvider>(context, listen: false).hijriAdjustment;
    final isRamadan = HijriDateService.isRamadan(DateTime.now(), hijriAdjustment);
    
    // Hide Imsak card if not Ramadan
    if (!isRamadan) {
      return _buildRamadanCountdown();
    }
    
    // Show Hadith of the Day during Ramadan
    return _buildHadithOfTheDayCard();
  }
  
  Widget _buildRamadanCountdown() {
    if (_timeUntilRamadan == null) return const SizedBox.shrink();
    
    final days = _timeUntilRamadan!.inDays;
    final hours = _timeUntilRamadan!.inHours.remainder(24);
    final minutes = _timeUntilRamadan!.inMinutes.remainder(60);
    
    return Container(
      decoration: BoxDecoration(
        gradient: AppConstants.goldGradient,
        borderRadius: BorderRadius.circular(AppConstants.largeBorderRadius),
        boxShadow: [
          BoxShadow(
            color: AppConstants.secondaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.mediumPadding),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.nights_stay,
              color: const Color(0xFF8B4513),
              size: 32,
            ),
            const SizedBox(width: 16),
            Column(
              children: [
                Text(
                  'باقي على رمضان 1447هـ',
                  style: GoogleFonts.tajawal(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8B4513),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildTimeUnit(days.toString().padLeft(2, '0'), 'يوم'),
                    const SizedBox(width: 12),
                    _buildTimeUnit(hours.toString().padLeft(2, '0'), 'ساعة'),
                    const SizedBox(width: 12),
                    _buildTimeUnit(minutes.toString().padLeft(2, '0'), 'دقيقة'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHadithOfTheDayCard() {
    return Consumer<HadithService>(
      builder: (context, hadithService, child) {
        // Get all hadiths and calculate index inline to ensure it's always fresh
        final allHadiths = hadithService.getAllHadiths();
        
        if (allHadiths.isEmpty) {
          // Show fallback card if hadiths not loaded yet
          return Container(
            key: ValueKey('fallback-hadith'),
            decoration: BoxDecoration(
              gradient: AppConstants.primaryGradient,
              borderRadius: BorderRadius.circular(AppConstants.largeBorderRadius),
              boxShadow: [
                BoxShadow(
                  color: AppConstants.primaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.mediumPadding),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'حديث اليوم',
                          style: GoogleFonts.tajawal(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.menu_book,
                          color: Colors.white70,
                          size: 24,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '«قال ﷺ: إنما الأعمال بالنيات، وإنما لكل امرئ ما نوى.»',
                        style: GoogleFonts.tajawal(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'متفق عليه',
                      style: GoogleFonts.tajawal(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        
        // CRITICAL: Use exact formula with fresh DateTime.now()
        final now = DateTime.now(); // This is critical to catch the system time change
        final hijriAdjustment = Provider.of<SettingsProvider>(context, listen: false).hijriAdjustment;
        final hijriDate = HijriDateService.getHijriDate(now, hijriAdjustment);
        final day = int.parse(hijriDate['day']);
        final year = int.parse(hijriDate['year']);
        final index = ((day - 1) + ((year % 4) * 30)) % allHadiths.length;
        final todayHadith = allHadiths[index];
        
        // Debug prints
        print('🕌 UI Hadith Calculation - Current Hijri Day: $day, Year: $year, Selected Hadith Index: $index, Hadith ID: ${todayHadith.id}');
        
        return Container(
          key: ValueKey('hadith-$index'), // Forces Flutter to redraw when index changes
          decoration: BoxDecoration(
            gradient: AppConstants.primaryGradient,
            borderRadius: BorderRadius.circular(AppConstants.largeBorderRadius),
            boxShadow: [
              BoxShadow(
                color: AppConstants.primaryColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.mediumPadding),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'حديث اليوم',
                        style: GoogleFonts.tajawal(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.menu_book,
                        color: Colors.white70,
                        size: 24,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '«${todayHadith.text}»',
                      style: GoogleFonts.tajawal(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    todayHadith.source,
                    style: GoogleFonts.tajawal(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeUnit(String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF8B4513).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: GoogleFonts.tajawal(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF8B4513),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.tajawal(
            fontSize: 12,
            color: const Color(0xFF8B4513).withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildPrayerTimesList() {
    // Get Hijri date with adjustment
    final hijriAdjustment = Provider.of<SettingsProvider>(context, listen: false).hijriAdjustment;
    final hijriDate = HijriDateService.getHijriDate(DateTime.now(), hijriAdjustment);
    final isRamadan = HijriDateService.isRamadan(DateTime.now(), hijriAdjustment);
    
    final prayerKeys = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hijri Date Display
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppConstants.goldGradient,
            borderRadius: BorderRadius.circular(AppConstants.mediumBorderRadius),
            boxShadow: [
              BoxShadow(
                color: AppConstants.secondaryColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today,
                color: const Color(0xFF8B4513),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                hijriDate['formatted'],
                style: GoogleFonts.tajawal(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8B4513),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'مواقيت الصلاة اليوم',
          style: GoogleFonts.tajawal(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        
        // Imsak time during Ramadan - MOVED TO TOP
        if (isRamadan) ...[
          Container(
            decoration: BoxDecoration(
              gradient: AppConstants.goldGradient,
              borderRadius: BorderRadius.circular(AppConstants.mediumBorderRadius),
              boxShadow: [
                BoxShadow(
                  color: AppConstants.secondaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppConstants.mediumPadding,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF8B4513),
                child: const Icon(
                  Icons.nights_stay,
                  color: Colors.white,
                ),
              ),
              title: Text(
                'الإمساك',
                style: GoogleFonts.tajawal(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF8B4513),
                ),
              ),
              trailing: Text(
                _prayerService.getImsakTime()?.getFormattedTime() ?? '--:--',
                style: GoogleFonts.tajawal(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8B4513),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16), // Proper spacing before Fajr
        ],
        
        // Regular prayer times
        ...prayerKeys.map((key) {
          final isNext = _isNextPrayer(key);
          final prayerTime = _prayerTimes[key];
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isNext 
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                  : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(AppConstants.mediumBorderRadius),
              border: isNext 
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : null,
              boxShadow: isNext 
                  ? [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppConstants.mediumPadding,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: isNext 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                child: Icon(
                  _getPrayerIcon(key),
                  color: isNext 
                      ? Colors.white
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              title: Text(
                _getPrayerName(key),
                style: GoogleFonts.tajawal(
                  fontSize: 16,
                  fontWeight: isNext ? FontWeight.bold : FontWeight.w500,
                  color: isNext 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              trailing: Text(
                prayerTime?.getFormattedTime() ?? '--:--',
                style: GoogleFonts.tajawal(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isNext 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  IconData _getPrayerIcon(String prayerKey) {
    switch (prayerKey) {
      case 'fajr':
        return Icons.wb_sunny;
      case 'sunrise':
        return Icons.wb_twighlight;
      case 'dhuhr':
        return Icons.wb_sunny;
      case 'asr':
        return Icons.wb_cloudy;
      case 'maghrib':
        return Icons.nights_stay;
      case 'isha':
        return Icons.bedtime;
      default:
        return Icons.access_time;
    }
  }

  bool _isNextPrayer(String prayerKey) {
    if (_nextPrayer == null) return false;
    
    return _nextPrayer == prayerKey;
  }
}

class AzkarScreen extends StatelessWidget {
  const AzkarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the actual AzkarScreenWidget from its separate file
    return const AzkarScreenWidget();
  }
}

class FiqhScreen extends StatelessWidget {
  const FiqhScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'فقه الصيام',
          style: GoogleFonts.tajawal(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: const Center(
        child: Text('قيد التطوير...'),
      ),
    );
  }
}
