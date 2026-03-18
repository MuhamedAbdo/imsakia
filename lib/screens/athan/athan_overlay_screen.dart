import 'dart:developer' as developer;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
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

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.92, end: 1.08).animate(_pulseController);

    // Audio is owned exclusively by the background service.
    // Do NOT play from the overlay to avoid duplicate streams.
    developer.log(
      '[AthanOverlay] Overlay displayed — audio managed by background service.',
      name: 'AthanOverlay',
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _stopAthan() async {
    developer.log(
      '[AthanOverlay] Stop button tapped — stopping audio and dismissing overlay.',
      name: 'AthanOverlay',
    );
    // Tell the background isolate to stop audio and cancel all notifications.
    bg.BackgroundService.sendStopAudio();
    // Dismiss: pop if we have a route stack, else exit the task.
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
          // 1. Background Image - Full Screen and Sharp
          if (widget.backgroundImage != null)
            Positioned.fill(
              child: Image.asset(
                widget.backgroundImage!,
                fit: BoxFit.cover,
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),

          // 2. Subtle Black Gradient (at the bottom)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.2),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // 3. Main Content
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Dynamic Prayer Text (Top 1/3 area)
                FadeInDown(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Text(
                      'حان الآن موعد أذان ${widget.prayerNameAr}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.bold,
                        fontSize: 32,
                        color: Colors.white,
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
                ),

                const Spacer(flex: 1),

                // English Prayer Name (Subtle)
                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  child: Text(
                    widget.prayerNameEn.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      letterSpacing: 4,
                      fontSize: 18,
                      color: Colors.white54,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),

                const Spacer(flex: 3),

                // Animated audio wave
                FadeIn(
                  delay: const Duration(milliseconds: 400),
                  child: _AudioWave(),
                ),

                const SizedBox(height: 48),

                // Stop button (Bottom area)
                FadeInUp(
                  delay: const Duration(milliseconds: 600),
                  child: Column(
                    children: [
                      ScaleTransition(
                        scale: _pulse,
                        child: GestureDetector(
                          onTap: _stopAthan,
                          child: Container(
                            width: 84,
                            height: 84,
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
                          fontSize: 16,
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
            final height = 8 + 32 * sin(animValue * pi).abs();
            return Container(
              width: 5,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 3),
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
