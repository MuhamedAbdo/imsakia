import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../utils/app_constants.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/settings_screen.dart';
import '../screens/main_layout.dart';
import '../services/hadith_service.dart';
import '../services/athan_player_service.dart';
import '../services/azkar_service.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    
    // Initialize services in background without blocking UI
    _initializeServicesInBackground();
    
    // Safety timer: force navigation after 4 seconds even if initialization fails
    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _navigateToMainApp();
      }
    });
  }
  
  void _initializeServicesInBackground() {
    // Initialize SettingsProvider
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    if (!settingsProvider.isInitialized) {
      settingsProvider.initialize().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          print('⚠️ SettingsProvider initialization timeout');
        },
      ).catchError((e) {
        print('❌ SettingsProvider initialization error: $e');
      });
    }
    
    // Initialize ThemeProvider and sync with SettingsProvider
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeProvider.syncWithSettingsProvider(settingsProvider.themeMode);
    
    // Initialize HadithService in background
    HadithService.instance.initialize().timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        print('⚠️ HadithService initialization timeout');
      },
    ).catchError((e) {
      print('❌ HadithService initialization error: $e');
    });
    
    // Initialize AthanService in background
    AthanPlayerService.instance.initialize().timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        print('⚠️ AthanService initialization timeout');
      },
    ).catchError((e) {
      print('❌ AthanService initialization error: $e');
    });
    
    // Initialize AzkarService in background
    AzkarService.instance.initialize().timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        print('⚠️ AzkarService initialization timeout');
      },
    ).catchError((e) {
      print('❌ AzkarService initialization error: $e');
    });
  }
  
  void _navigateToMainApp() {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    
    if (settingsProvider.isFirstLaunch) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const SettingsScreen(isFirstTimeSetup: true),
        ),
      );
    } else {
      Navigator.of(context).pushReplacementNamed('/main');
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

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  void _startAnimations() {
    _fadeController.forward();
    _scaleController.forward();
    _rotationController.repeat();
    _pulseController.repeat(reverse: true);
  }

  void _navigateToNextScreen() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/main');
      }
    });
  }

  Future<void> _navigateToNextScreenAsync() async {
    await Future.delayed(AppConstants.splashDuration);
    
    // Initialize SettingsProvider if not already done
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    if (!settingsProvider.isInitialized) {
      await settingsProvider.initialize();
    }

    if (mounted) {
      if (settingsProvider.isFirstLaunch) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const SettingsScreen(isFirstTimeSetup: true),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const MainLayout(),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
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
        child: Stack(
          children: [
            // Background decorative elements
            _buildBackgroundDecorations(),
            
            // Main content
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_fadeAnimation, _scaleAnimation, _pulseAnimation]),
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Animated Logo Container
                          AnimatedBuilder(
                            animation: _rotationAnimation,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _rotationAnimation.value * 0.1,
                                child: ScaleTransition(
                                  scale: _pulseAnimation,
                                  child: Container(
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white.withOpacity(0.2),
                                          Colors.white.withOpacity(0.1),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(70),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.4),
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white.withOpacity(0.3),
                                          blurRadius: 20,
                                          spreadRadius: 5,
                                        ),
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
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
                          
                          const SizedBox(height: 50),
                          
                          // Main Title with shadow
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              AppConstants.splashTitle,
                              style: GoogleFonts.tajawal(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Subtitle with glow effect
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 30),
                            child: Text(
                              AppConstants.splashSubtitle,
                              style: GoogleFonts.reemKufi(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.9),
                                height: 1.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.white.withOpacity(0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          
                          const SizedBox(height: 40),
                          
                          // Enhanced Dedication Card
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
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
                                color: Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.4),
                                  blurRadius: 15,
                                  spreadRadius: 3,
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Text(
                              AppConstants.splashDedication,
                              style: GoogleFonts.reemKufi(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8B4513),
                                height: 1.4,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          
                          const SizedBox(height: 60),
                          
                          // Enhanced Loading Indicator
                          AnimatedBuilder(
                            animation: _fadeController,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _fadeAnimation.value * 0.8,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(25),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
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
    );
  }

  Widget _buildBackgroundDecorations() {
    return Stack(
      children: [
        // Floating circles
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
                  color: Colors.white.withOpacity(0.1 * _pulseAnimation.value),
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
                    color: Colors.white.withOpacity(0.15),
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
                  color: Colors.white.withOpacity(0.08 * _pulseAnimation.value),
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
                    color: Colors.white.withOpacity(0.12),
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
