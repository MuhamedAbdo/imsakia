import 'dart:developer' as developer;
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/background_service.dart' as bg;
import '../../core/theme/app_colors.dart';

class AthanOverlayScreen extends StatefulWidget {
  final String prayerNameAr;
  final String prayerNameEn;
  final String? backgroundImage;

  const AthanOverlayScreen({
    super.key,
    required this.prayerNameAr,
    required this.prayerNameEn,
    this.backgroundImage,
  });

  @override
  State<AthanOverlayScreen> createState() => _AthanOverlayScreenState();
}

class _AthanOverlayScreenState extends State<AthanOverlayScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulse;
  String _currentCityAr = '';

  @override
  void initState() {
    super.initState();
    _loadCityName();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.92, end: 1.08).animate(_pulseController);

    developer.log('[AthanOverlay] Overlay displayed — audio managed by background service.', name: 'AthanOverlay');
  }

  Future<void> _loadCityName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('last_location');
      if (raw != null) {
        final loc = jsonDecode(raw) as Map<String, dynamic>;
        setState(() {
          _currentCityAr = loc['cityName'] ?? 'مدينتك';
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _stopAthan() async {
    developer.log('[AthanOverlay] Stop button tapped — sending stop_audio to background service.', name: 'AthanOverlay');

    // 1. Signal the background isolate AND native layer to stop audio + cancel notifications.
    bg.BackgroundService.sendStopAudio();

    // 2. Clear the playing flag in the MAIN isolate immediately.
    //    This ensures the onResume listener doesn't re-launch the overlay
    //    the moment the user closes the overlay and reopens the app.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('athan_is_playing', false);
      await prefs.setString('athan_prayer_ar', '');
      await prefs.setString('athan_prayer_en', '');
    } catch (_) {}

    // 3. Navigate back to the main screen (do NOT use SystemNavigator.pop()
    //    as it exits the whole app when the overlay is the root route).
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/main',
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Background Image (Mapped to our .png assets in BackgroundService)
          if (widget.backgroundImage != null)
            Positioned.fill(
              child: Image.asset(
                widget.backgroundImage!,
                fit: BoxFit.cover,
              ),
            ),

          // 2. Dark Overlay/Gradient for readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ),

          // 3. Content Area
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Icon + Title Wrapper
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      children: [
                        FadeInDown(
                          duration: const Duration(milliseconds: 800),
                          child: Text(
                            widget.prayerNameAr,
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 72,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Amiri', // Or Cairo if preferred
                              shadows: [
                                Shadow(
                                  color: Colors.black87,
                                  offset: Offset(0, 4),
                                  blurRadius: 12,
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
                            'حان الآن موعد أذان ${widget.prayerNameAr}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontFamily: 'Tajawal',
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(
                                  color: Colors.black87,
                                  offset: Offset(0, 2),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_currentCityAr.isNotEmpty)
                          FadeInDown(
                            delay: const Duration(milliseconds: 400),
                            duration: const Duration(milliseconds: 800),
                            child: Text(
                              'حسب التوقيت المحلي لمدينة $_currentCityAr',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                                fontFamily: 'Tajawal',
                                fontWeight: FontWeight.w300,
                                shadows: [
                                  Shadow(
                                    color: Colors.black87,
                                    offset: Offset(0, 2),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // Animated audio wave
                FadeIn(
                  delay: const Duration(milliseconds: 600),
                  child: _AudioWave(),
                ),

                const SizedBox(height: 32),

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
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.error,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.error.withValues(alpha: 0.5),
                                  blurRadius: 30,
                                  spreadRadius: 6,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.stop_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'إيقاف الأذان',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),
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
            final height = 12 + 40 * sin(animValue * pi).abs();
            return Container(
              width: 6,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        );
      },
    );
  }
}

