import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../utils/app_constants.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/settings_screen.dart';
import '../services/hadith_service.dart';
import '../services/azkar_service.dart';
import '../screens/azkar_detail_screen.dart';
import '../../main.dart';
import '../../features/athan/services/athan_manager.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  Timer? _navigationTimer;
  Timer? _emergencyTimeoutTimer; // 🛡️ صمام الأمان لمنع التجمد المطلق

  @override
  void initState() {
    super.initState();
    _checkGracefulExit();
    _initializeAnimations();
    _startAnimations();
    
    // 🛡️ صمام الأمان (Timeout Fallback) لمدة 5 ثوانٍ
    // إذا لم يتم التوجيه لأي سبب (مثل حالة Athan وهمية)، نفرض الدخول.
    _emergencyTimeoutTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        debugPrint("!!! SPLASH TIMEOUT: Forcing route to /main !!!");
        MyApp.isAthanShowing = false; // فك التعليق
        _navigateToMainApp(force: true);
      }
    });
  }

  Future<void> _checkGracefulExit() async {
    // ✅ نظام الخروج الصامت: تحقق من العلم قبل أي شيء
    final shouldExit = await AthanManager.getShouldExitFlag();
    if (!mounted) return;

    if (shouldExit) {
      await AthanManager.clearShouldExitFlag();
      await AthanManager.forceExit();
      return;
    }

    if (!MyApp.isAthanShowing) {
      // ⏳ جعل التطبيق ينتظر تحميل الخدمات ومرور الـ 3 ثوانٍ معاً بشكل متزامن
      Future.wait([
        _initializeServicesInBackground(),
        Future.delayed(
          const Duration(seconds: 4),
        ), // رفعنا الوقت لـ 4 ثوانٍ ليعطي هيبة وظهور مريح للإهداء
      ]).then((_) {
        if (mounted) {
          _navigateToMainApp();
        }
      });
    } else {
      // ✅ صمام الأمان: إذا انتهى الأذان وظل المستخدم عالقاً هنا
      // نقوم بنقله للتطبيق تلقائياً بعد مهلة كافية
      _navigationTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && !MyApp.isAthanShowing) {
          _navigateToMainApp();
        }
      });
    }
  }

  Future<void> _initializeServicesInBackground() async {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );

    final futures = <Future>[];

    if (!settingsProvider.isInitialized) {
      futures.add(
        settingsProvider
            .initialize()
            .timeout(const Duration(seconds: 3), onTimeout: () {})
            .catchError((e) {}),
      );
    }

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeProvider.syncWithSettingsProvider(settingsProvider.themeMode);

    futures.add(
      HadithService.instance
          .initialize()
          .timeout(const Duration(seconds: 3), onTimeout: () {})
          .catchError((e) {}),
    );

    futures.add(
      AzkarService.instance
          .initialize()
          .timeout(const Duration(seconds: 3), onTimeout: () {})
          .catchError((e) {}),
    );

    await Future.wait(futures);
  }

  void _navigateToMainApp({bool force = false}) {
    // 🔥 Guard: If Athan Overlay is currently showing, CANCEL everything.
    // This prevents SplashScreen from "pushReplacement" which would kill the Athan Overlay.
    if (!mounted) return;
    if (MyApp.isAthanShowing && !force) {
      _navigationTimer?.cancel();
      _navigationTimer = null;
      return;
    }
    
    _emergencyTimeoutTimer?.cancel();

    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );

    MyApp.sessionSplashShown = true;

    if (settingsProvider.isFirstLaunch) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const SettingsScreen(isFirstTimeSetup: true),
        ),
      );
    } else {
      Navigator.of(context).pushReplacementNamed('/main');
      
      // 🚀 التحقق من الإشعار: هل توجد حمولة معلقة لفتح الأذكار؟
      if (pendingAzkarRoutePayload != null) {
        final categoryId = pendingAzkarRoutePayload == 'azkar_morning' ? 'morning' : 'evening';
        final category = AzkarService.instance.categories.firstWhere(
          (c) => c.id == categoryId,
          orElse: () => AzkarService.instance.categories.first,
        );
        
        // تفريغ المتغير لمنع الفتح المتكرر
        pendingAzkarRoutePayload = null;

        // التوجيه لشاشة تفاصيل الأذكار
        Future.delayed(const Duration(milliseconds: 500), () {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => AzkarDetailScreen(category: category),
            ),
          );
        });
      }
    }
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: AppConstants.animationDuration * 3,
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: AppConstants.animationDuration * 2,
      vsync: this,
    );

    _rotationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _startAnimations() {
    _fadeController.forward();
    _scaleController.forward();
    _rotationController.repeat();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _rotationController.dispose();
    _pulseController.dispose();
    _navigationTimer?.cancel();
    _emergencyTimeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 Real-time Monitoring: If Athan is showing, cancel the timer IMMEDIATELY
    if (MyApp.isAthanShowing && _navigationTimer != null) {
      _navigationTimer?.cancel();
      _navigationTimer = null;
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E3A8A),
              Color(0xFF3B82F6),
              Color(0xFF6366F1),
              Color(0xFF8B5CF6),
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: IntrinsicHeight(
              child: Stack(
                children: [
                  _buildBackgroundDecorations(),
                  Center(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _fadeAnimation,
                        _scaleAnimation,
                        _pulseAnimation,
                      ]),
                      builder: (context, child) {
                        return FadeTransition(
                          opacity: _fadeAnimation,
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedBuilder(
                                  animation: _rotationAnimation,
                                  builder: (context, child) {
                                    return Transform.rotate(
                                      angle: _rotationAnimation.value * 0.1,
                                      child: ScaleTransition(
                                        scale: _pulseAnimation,
                                        child: Container(
                                          width:
                                              MediaQuery.of(
                                                context,
                                              ).size.width *
                                              0.3,
                                          height:
                                              MediaQuery.of(
                                                context,
                                              ).size.width *
                                              0.3,
                                          constraints: const BoxConstraints(
                                            minWidth: 100,
                                            maxWidth: 140,
                                            minHeight: 100,
                                            maxHeight: 140,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Colors.white.withValues(
                                                  alpha: 0.2,
                                                ),
                                                Colors.white.withValues(
                                                  alpha: 0.1,
                                                ),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              70,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.4,
                                              ),
                                              width: 3,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.white.withValues(
                                                  alpha: 0.3,
                                                ),
                                                blurRadius: 20,
                                                spreadRadius: 5,
                                              ),
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.2,
                                                ),
                                                blurRadius: 15,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.mosque,
                                            size: 70,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.05,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: Text(
                                    AppConstants.splashTitle,
                                    style: GoogleFonts.tajawal(
                                      fontSize:
                                          MediaQuery.of(context).size.width *
                                          0.07,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      height: 1.5,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.02,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 30,
                                  ),
                                  child: Text(
                                    AppConstants.splashSubtitle,
                                    style: GoogleFonts.reemKufi(
                                      fontSize:
                                          MediaQuery.of(context).size.width *
                                          0.045,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      height: 1.5,
                                      shadows: [
                                        Shadow(
                                          color: Colors.white.withValues(
                                            alpha: 0.5,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.04,
                                ),
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal:
                                        MediaQuery.of(context).size.width *
                                        0.06,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFFFFD700),
                                        Color(0xFFFFA500),
                                        Color(0xFFFF8C00),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(35),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.orange.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 15,
                                        spreadRadius: 3,
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    AppConstants.splashDedication,
                                    style: GoogleFonts.reemKufi(
                                      fontSize:
                                          MediaQuery.of(context).size.width *
                                          0.07,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF8B4513),
                                      height: 1.4,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.5,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.06,
                                ),
                                AnimatedBuilder(
                                  animation: _fadeController,
                                  builder: (context, child) {
                                    return Opacity(
                                      opacity: _fadeAnimation.value * 0.8,
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            25,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.3,
                                            ),
                                            width: 2,
                                          ),
                                        ),
                                        child: const CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                          strokeWidth: 3,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundDecorations() {
    return Stack(
      children: [
        Positioned(
          top: 100,
          left: 50,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(
                    alpha: 0.1 * _pulseAnimation.value,
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          top: 200,
          right: 80,
          child: AnimatedBuilder(
            animation: _rotationAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationAnimation.value * 0.5,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          bottom: 150,
          left: 100,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(
                    alpha: 0.08 * _pulseAnimation.value,
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          bottom: 100,
          right: 60,
          child: AnimatedBuilder(
            animation: _rotationAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: -_rotationAnimation.value * 0.3,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
