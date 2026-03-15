import 'dart:developer' as developer;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../core/theme/app_colors.dart';

class AthanOverlayScreen extends StatefulWidget {
  final String prayerNameAr;
  final String prayerNameEn;

  const AthanOverlayScreen({
    super.key,
    required this.prayerNameAr,
    required this.prayerNameEn,
  });

  @override
  State<AthanOverlayScreen> createState() => _AthanOverlayScreenState();
}

class _AthanOverlayScreenState extends State<AthanOverlayScreen>
    with TickerProviderStateMixin {
  late AnimationController _gradientController;
  late AnimationController _pulseController;
  late Animation<double> _pulse;
  late Animation<double> _gradient;

  @override
  void initState() {
    super.initState();

    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.92, end: 1.08).animate(_pulseController);
    _gradient =
        Tween<double>(begin: 0.0, end: 1.0).animate(_gradientController);

    // Audio is owned exclusively by the background service.
    // Do NOT play from the overlay to avoid duplicate streams.
    developer.log('[AthanOverlay] Overlay displayed — audio managed by background service.', name: 'AthanOverlay');
  }

  @override
  void dispose() {
    _gradientController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _stopAthan() async {
    developer.log('[AthanOverlay] Stop button tapped — sending stop_audio to background service.', name: 'AthanOverlay');
    // The background service is the sole audio owner; send the unified command.
    FlutterBackgroundService().invoke('stop_audio');
    // Dismiss the overlay screen.
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _gradient,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                    const Color(0xFF0D0221),
                    const Color(0xFF1F0B3E),
                    _gradient.value,
                  )!,
                  Color.lerp(
                    const Color(0xFF0D3B66),
                    const Color(0xFF071226),
                    _gradient.value,
                  )!,
                ],
              ),
            ),
            child: child,
          );
        },
        child: Stack(
          children: [
            // Decorative circles
            ..._buildDecorations(),

            // Content
            SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(height: 40),

                  // Icon + Title
                  Column(
                    children: [
                      FadeInDown(
                        child: _MosqueIllustration(),
                      ),
                      const SizedBox(height: 32),
                      FadeInDown(
                        delay: const Duration(milliseconds: 200),
                        child: Text(
                          'حان وقت صلاة',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.white70,
                                    letterSpacing: 1,
                                  ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FadeInDown(
                        delay: const Duration(milliseconds: 300),
                        child: Text(
                          widget.prayerNameAr,
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(
                                color: AppColors.gold,
                                fontSize: 56,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FadeInDown(
                        delay: const Duration(milliseconds: 400),
                        child: Text(
                          widget.prayerNameEn,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: Colors.white38,
                                letterSpacing: 4,
                              ),
                        ),
                      ),
                    ],
                  ),

                  // Animated audio wave
                  FadeIn(
                    delay: const Duration(milliseconds: 500),
                    child: _AudioWave(),
                  ),

                  // Stop button
                  FadeInUp(
                    delay: const Duration(milliseconds: 600),
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
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.stop_rounded,
                                      color: Colors.white, size: 36),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'إيقاف الأذان',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.white60,
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
      ),
    );
  }

  List<Widget> _buildDecorations() {
    return [
      Positioned(
        top: -60,
        right: -60,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.gold.withValues(alpha: 0.05),
          ),
        ),
      ),
      Positioned(
        bottom: -80,
        left: -80,
        child: Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.teal.withValues(alpha: 0.07),
          ),
        ),
      ),
      Positioned(
        top: 100,
        left: -40,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.03),
          ),
        ),
      ),
    ];
  }
}

class _MosqueIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(200, 140),
      painter: _MosquePainter(),
    );
  }
}

class _MosquePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Main dome
    final domeRect = Rect.fromCenter(
      center: Offset(w / 2, h * 0.45),
      width: w * 0.4,
      height: h * 0.6,
    );
    canvas.drawArc(domeRect, pi, pi, true, paint);

    // Main body
    canvas.drawRect(
      Rect.fromLTWH(w * 0.3, h * 0.45, w * 0.4, h * 0.55),
      paint,
    );

    // Left minaret
    canvas.drawRect(
      Rect.fromLTWH(w * 0.12, h * 0.3, w * 0.1, h * 0.7),
      paint,
    );
    // Left minaret top dome
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(w * 0.17, h * 0.3), width: w * 0.1, height: h * 0.2),
      pi,
      pi,
      true,
      paint,
    );

    // Right minaret
    canvas.drawRect(
      Rect.fromLTWH(w * 0.78, h * 0.3, w * 0.1, h * 0.7),
      paint,
    );
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(w * 0.83, h * 0.3), width: w * 0.1, height: h * 0.2),
      pi,
      pi,
      true,
      paint,
    );

    // Crescent on main dome
    final crescentPaint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w / 2, h * 0.08), width: 20, height: 20),
      pi * 0.2,
      pi * 1.2,
      false,
      crescentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
