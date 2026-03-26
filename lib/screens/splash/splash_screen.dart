import 'dart:async';
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
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main_layout.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _pulseController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  String _statusText = 'جاري التحميل...';

  /// ✅ تصحيح القناة
  static const MethodChannel _channel = MethodChannel('imsakia/athan_control');

  bool _launchedFromAthan = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkLaunchSource();
      await _checkXiaomiGuidance();
      _initialize();
    });
  }

  Future<void> _checkLaunchSource() async {
    try {
      final result = await _channel.invokeMethod<bool>("is_open_from_athan");
      _launchedFromAthan = result ?? false;
      debugPrint("Launched from Athan: $_launchedFromAthan");
    } catch (e) {
      debugPrint("Error checking launch source: $e");
      _launchedFromAthan = false;
    }
  }

  Future<void> _checkXiaomiGuidance() async {
    if (!mounted) return;
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final manufacturer = androidInfo.manufacturer.toLowerCase();

      if (manufacturer.contains('xiaomi')) {
        final prefs = await SharedPreferences.getInstance();
        final dialogShown = prefs.getBool('xiaomi_guidance_shown') ?? false;

        if (!dialogShown) {
          if (!mounted) return;
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E3A8A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Text(
                'تنبيه لمستخدمي شاومي',
                style: GoogleFonts.tajawal(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.right,
              ),
              content: Text(
                'لضمان عمل الأذان بشكل صحيح، يرجى تفعيل "البدء التلقائي" (Autostart) والسماح بالظهور على "شاشة القفل".',
                style: GoogleFonts.tajawal(color: Colors.white70),
                textAlign: TextAlign.right,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'لاحقاً',
                    style: GoogleFonts.tajawal(color: Colors.white60),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await _channel.invokeMethod('openXiaomiPermissions');
                    } catch (e) {
                      debugPrint("Error opening Xiaomi permissions: $e");
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'فتح الإعدادات',
                    style: GoogleFonts.tajawal(
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
          await prefs.setBool('xiaomi_guidance_shown', true);
        }
      }
    } catch (e) {
      debugPrint("Error checking Xiaomi guidance: $e");
    }
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
      /// 🚀 لو جاي من الأذان → ادخل فورًا
      if (_launchedFromAthan) {
        _navigateToMain();
        return;
      }

      _updateStatus(
        locale == 'ar' ? 'جاري تحديد موقعك...' : 'Getting location...',
      );

      if (!location.hasLocation) {
        await location
            .fetchGpsLocation(
              locale: locale,
              onLocationChanged: (loc) =>
                  prayerTimes.calculate(loc, settings.calculationMethod),
            )
            .timeout(
              const Duration(seconds: 12),
              onTimeout: () => debugPrint('Location fetch timed out in splash'),
            );
      }

      if (location.hasLocation) {
        _updateStatus(
          locale == 'ar' ? 'جاري حساب المواقيت...' : 'Calculating times...',
        );
        await prayerTimes.calculate(
          location.location!,
          settings.calculationMethod,
        );
      }

      _updateStatus(
        locale == 'ar' ? 'جاري تحميل التاريخ...' : 'Loading Hijri...',
      );
      await hijri.fetch(
        offset: settings.hijriBaseOffset,
        countryCode: location.location?.countryCode,
      );

      await Future.delayed(const Duration(seconds: 1));
      _navigateToMain();
    } catch (e) {
      debugPrint('Initialization error: $e');
      _navigateToMain();
    }
  }

  void _navigateToMain() {
    if (!mounted) return;

    /// ✅ لو جاي من الأذان
    if (_launchedFromAthan) {
      Navigator.of(context).pushReplacementNamed('/athan');
      return;
    }

    /// ✅ فتح طبيعي
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
            colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
          ),
        ),
        child: Stack(
          children: [
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
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.star_rounded,
                          color: AppColors.gold,
                          size: size.width * 0.15,
                        ),
                      ),
                      SizedBox(height: size.height * 0.05),
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
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.3),
                            ),
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
                      Column(
                        children: [
                          const SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.gold,
                              ),
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
