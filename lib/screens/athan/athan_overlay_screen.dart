import 'dart:developer' as developer;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart' as fbs;
import 'package:animate_do/animate_do.dart';
import '../../core/theme/app_colors.dart';

class AthanOverlayScreen extends StatefulWidget {
  final String prayerNameAr;
  final String prayerNameEn;
  final String? cityName;
  final String? backgroundImage;

  const AthanOverlayScreen({
    super.key,
    required this.prayerNameAr,
    required this.prayerNameEn,
    this.cityName,
    this.backgroundImage,
  });

  @override
  State<AthanOverlayScreen> createState() => _AthanOverlayScreenState();
}

class _AthanOverlayScreenState extends State<AthanOverlayScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.92, end: 1.08).animate(_pulseController);

    developer.log('[AthanOverlay] Overlay displayed for ${widget.prayerNameAr}', name: 'AthanOverlay');
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _stopAthan() async {
    developer.log('[AthanOverlay] Stop button tapped.', name: 'AthanOverlay');
    
    // Stop Audio via Background Service
    try {
      fbs.FlutterBackgroundService().invoke('stop_audio');
    } catch (e) {
      developer.log('[AthanOverlay] Failed to stop audio: $e');
    }

    // Dismiss the overlay screen
    if (mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        SystemNavigator.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Background Image
          if (widget.backgroundImage != null)
            Positioned.fill(
              child: Image.asset(
                widget.backgroundImage!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(color: Colors.black87),
              ),
            ),

          // 2. Dark Overlay/Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          ),

          // 3. Content Area
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const SizedBox(height: 40),

                // Announcement Text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      FadeInDown(
                        duration: const Duration(milliseconds: 800),
                        child: Text(
                          'حان الآن موعد أذان ${widget.prayerNameAr}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Tajawal',
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                offset: Offset(0, 4),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeInDown(
                        delay: const Duration(milliseconds: 200),
                        duration: const Duration(milliseconds: 800),
                        child: Text(
                          'حسب التوقيت المحلي لمدينة ${widget.cityName ?? ""}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Animated audio wave
                FadeIn(
                  delay: const Duration(milliseconds: 600),
                  child: _AudioWave(),
                ),

                // Stop button
                FadeInUp(
                  delay: const Duration(milliseconds: 800),
                  child: Column(
                    children: [
                      ScaleTransition(
                        scale: _pulse,
                        child: GestureDetector(
                          onTap: _stopAthan,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.error,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.error.withValues(alpha: 0.5),
                                  blurRadius: 40,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.stop_rounded,
                              color: Colors.white,
                              size: 50,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'إيقاف الأذان',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioWave extends StatefulWidget {
  @override
  State<_AudioWave> createState() => _AudioWaveState();
}

class _AudioWaveState extends State<_AudioWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(7, (i) {
            final delay = i / 7;
            final animValue = ((_controller.value + delay) % 1.0);
            final height = 15 + 50 * sin(animValue * pi).abs();
            return Container(
              width: 8,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        );
      },
    );
  }
}
