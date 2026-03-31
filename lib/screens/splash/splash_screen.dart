import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../utils/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/location_provider.dart';
import '../../providers/prayer_times_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/hijri_calendar_provider.dart';
import '../main_layout.dart';
import '../athan/athan_overlay_screen.dart';
import '../../core/services/miui_service.dart';
import '../../core/services/athan_scheduling_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  
  String _statusText = 'جاري التحميل...';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    
    // Start engine initialization
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _startAnimations() {
    _fadeController.forward();
    _scaleController.forward();
  }

  Future<void> _initialize() async {
    final settings = context.read<SettingsProvider>();
    final location = context.read<LocationProvider>();
    final prayerTimes = context.read<PrayerTimesProvider>();
    final hijri = context.read<HijriCalendarProvider>();

    final locale = settings.languageCode;

    try {
      // Step 0: Check if Athan is actively playing natively with Fail-Safe Triple Validation
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      // Backward Compatibility Cleanup (Task 9)
      try {
        final legacyKeys = ['athan_is_playing', 'athan_prayer_image', 'athan_prayer_ar', 'athan_prayer_en'];
        for (final key in legacyKeys) {
          if (prefs.containsKey(key)) {
            await prefs.remove(key);
          }
        }
      } catch (e) {
        debugPrint('Splash: Legacy cleanup failed: $e');
      }

      final isPlaying = prefs.getBool('flutter.athan_is_playing') ?? false;
      final startTime = prefs.getInt('flutter.athan_start_time') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // 1. Time-based Validation: Must have started within the last 5 minutes
      final isTimeValid = (now - startTime) < (5 * 60 * 1000);

      // 2. Real-time Native Validation (State Sync): Is the audio actually playing natively?
      bool isReallyPlaying = false;
      if (isPlaying && isTimeValid) {
        try {
          const channel = MethodChannel('imsakia/athan_control');
          // Timeout protection: max 500ms for native check to prevent UI hang
          isReallyPlaying = await channel.invokeMethod<bool>('checkAthanPlaying')
              .timeout(const Duration(milliseconds: 500), onTimeout: () => false) ?? false;
        } catch (e) {
          debugPrint('Splash: MethodChannel error: $e');
          isReallyPlaying = false; 
        }
      }

      // TRIPLE VALIDATION logic (Zero-Failure Routing Lock)
      if (isPlaying && isTimeValid && isReallyPlaying) {
        debugPrint('Splash: Athan is playing and valid! Bypassing startup...');
        
        if (!mounted) return;
        final nameAr = prefs.getString('flutter.athan_prayer_ar') ?? 'الصلاة';
        final nameEn = prefs.getString('flutter.athan_prayer_en') ?? 'Prayer';
        final image = prefs.getString('flutter.athan_image');

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/athan_overlay'),
            fullscreenDialog: true,
            builder: (_) => AthanOverlayScreen(
              prayerNameAr: nameAr,
              prayerNameEn: nameEn,
              backgroundImage: image,
            ),
          ),
        );
        return; 
      } else {
        // KILL-SAFE RECOVERY (Task 2 & 8)
        // If state says it WAS playing but native says NO, force atomic reset
        if (isPlaying || !isTimeValid || !isReallyPlaying) {
           debugPrint('Splash: Inconsistency detected ($isPlaying/$isTimeValid/$isReallyPlaying). Performing Hard Reset.');
           try {
             await prefs.setBool('flutter.athan_is_playing', false);
             await prefs.remove('flutter.athan_start_time');
             // Nuclear cleanup on native side
             const channel = MethodChannel('imsakia/athan_control');
             await channel.invokeMethod('stopNativeAudio').timeout(const Duration(milliseconds: 500));
           } catch (_) {}
        }
      }

      // Step 1: Load location (with last known as fallback if stalling)
      _updateStatus(locale == 'ar' ? 'جاري تحديد موقعك...' : 'Getting location...');
      if (!location.hasLocation) {
        // LocationProvider will handle timeout/fallback logic
        await location.fetchGpsLocation(
          locale: locale,
          onLocationChanged: (loc) => prayerTimes.calculate(loc, settings.calculationMethod),
        ).timeout(
          const Duration(seconds: 12),
          onTimeout: () => debugPrint('Location fetch timed out in splash'),
        );
      }

      // Step 2: Calculate prayer times
      if (location.hasLocation) {
        _updateStatus(locale == 'ar' ? 'جاري حساب المواقيت...' : 'Calculating times...');
        await prayerTimes.calculate(location.location!, settings.calculationMethod);
      }

      _updateStatus(locale == 'ar' ? 'جاري تحميل التاريخ...' : 'Loading Hijri...');
      await hijri.fetch(
        offset: settings.hijriBaseOffset,
        countryCode: location.location?.countryCode,
      );

      // Step 3.5: Force Schedule Athan (Requirement 1)
      await AthanSchedulingService.ensureAthanScheduled();

      // Step 4: Xiaomi (MIUI) Guidance (Task: Xiaomi Fix)
      final isMiui = await MiuiService.isMiui();
      final setupCompleted = await MiuiService.isSetupCompleted();
      
      if (isMiui && !setupCompleted) {
         if (!mounted) return;
         await Navigator.of(context).pushNamed('/miui_guidance');
      }

      // Final wait for aesthetic transition
      await Future.delayed(const Duration(seconds: 1));
      _navigateToMain();
    } catch (e) {
      debugPrint('Initialization error: $e');
      _navigateToMain(); // Navigate anyway to avoid bricking
    }
  }

  void _navigateToMain() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, anim1, anim2) => const MainLayout(),
        transitionsBuilder: (context, anim, secondaryAnim, child) => 
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  void _updateStatus(String text) {
    if (mounted) setState(() => _statusText = text);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E3A8A),
              Color(0xFF0F172A),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background Mosque Icon (Silmulated Overlay)
            Positioned(
              top: size.height * 0.15,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Icon(
                  Icons.mosque,
                  size: size.width * 0.4,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Memorial Seal
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                            )
                          ]
                        ),
                        child: Icon(Icons.star_rounded, color: AppColors.gold, size: size.width * 0.15),
                      ),
                      
                      SizedBox(height: size.height * 0.05),
                      
                      // Memorial Text
                      Text(
                        AppConstants.splashTitle,
                        style: GoogleFonts.tajawal(
                          fontSize: size.width * 0.06,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Text(
                        AppConstants.splashSubtitle,
                        style: GoogleFonts.reemKufi(
                          fontSize: size.width * 0.05,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      SizedBox(height: size.height * 0.03),
                      
                      // Dedication Name
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            AppConstants.splashDedication,
                            style: GoogleFonts.reemKufi(
                              fontSize: size.width * 0.07,
                              fontWeight: FontWeight.bold,
                              color: AppColors.gold,
                            ),
                          ),
                        ),
                      ),
                      
                      SizedBox(height: size.height * 0.08),
                      
                      // Loading Status
                      Column(
                        children: [
                          const SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _statusText,
                            style: GoogleFonts.tajawal(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
