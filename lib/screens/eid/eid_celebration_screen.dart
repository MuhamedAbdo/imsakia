import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/background_service.dart';
import '../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  EidCelebrationScreen
// ─────────────────────────────────────────────────────────────────────────────
class EidCelebrationScreen extends StatefulWidget {
  final String eidName; // e.g. "عيد الفطر المبارك" or "عيد الأضحى المبارك"

  const EidCelebrationScreen({
    super.key,
    required this.eidName,
  });

  @override
  State<EidCelebrationScreen> createState() => _EidCelebrationScreenState();
}

class _EidCelebrationScreenState extends State<EidCelebrationScreen>
    with TickerProviderStateMixin {
  late AnimationController _fireworkController;
  late AnimationController _textFadeController;
  late AnimationController _pulseController;

  late Animation<double> _textFade;
  late Animation<double> _textScale;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _fireworkController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _textFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _textFade = CurvedAnimation(
      parent: _textFadeController,
      curve: Curves.easeInOut,
    );

    _textScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _textFadeController, curve: Curves.elasticOut),
    );

    _pulse = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fireworkController.dispose();
    _textFadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _stopTakbeer() async {
    BackgroundService.sendStopAudio();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ── Background Gradient ────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A1628),
                  Color(0xFF0D2137),
                  Color(0xFF16213E),
                ],
              ),
            ),
          ),

          // ── Fireworks / Particles ──────────────────────────────────────────
          AnimatedBuilder(
            animation: _fireworkController,
            builder: (context, _) {
              return CustomPaint(
                size: size,
                painter: _FireworksPainter(_fireworkController.value),
              );
            },
          ),

          // ── Star decorations ───────────────────────────────────────────────
          ..._buildStarDecorations(size),

          // ── Content ────────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                const Spacer(),

                // Crescent & Star Icon
                FadeTransition(
                  opacity: _textFade,
                  child: ScaleTransition(
                    scale: _textScale,
                    child: _buildCrescentIcon(),
                  ),
                ),

                const SizedBox(height: 24),

                // "عيدكم مبارك" Calligraphy-style text
                FadeTransition(
                  opacity: _textFade,
                  child: ScaleTransition(
                    scale: _textScale,
                    child: Column(
                      children: [
                        ScaleTransition(
                          scale: _pulse,
                          child: Text(
                            'عيدكم مبارك',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.tajawal(
                              fontSize: 54,
                              fontWeight: FontWeight.bold,
                              color: AppColors.gold,
                              shadows: [
                                Shadow(
                                  color: AppColors.gold.withValues(alpha: 0.7),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.eidName,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.tajawal(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'الله أكبر، الله أكبر، لا إله إلا الله\nالله أكبر، الله أكبر، ولله الحمد',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.tajawal(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            height: 1.8,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // ── Stop Button ───────────────────────────────────────────────
                FadeTransition(
                  opacity: _textFade,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                    child: GestureDetector(
                      onTap: _stopTakbeer,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFB8860B), Color(0xFFDAA520)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.45),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.stop_circle_rounded,
                                color: Colors.white, size: 24),
                            const SizedBox(width: 10),
                            Text(
                              'إيقاف التكبيرات',
                              style: GoogleFonts.tajawal(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrescentIcon() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.gold.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.25),
            blurRadius: 25,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Icon(
        Icons.nightlight_round,
        color: AppColors.gold,
        size: 52,
      ),
    );
  }

  List<Widget> _buildStarDecorations(Size size) {
    final rng = Random(42);
    return List.generate(16, (i) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height * 0.7;
      final s = 2.0 + rng.nextDouble() * 4;
      return Positioned(
        left: x,
        top: y,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (_, _) => Opacity(
            opacity: (0.3 + 0.5 * ((sin((_pulseController.value + i * 0.2) * pi)).abs()))
                .clamp(0.0, 1.0),
            child: Container(
              width: s,
              height: s,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.white38, blurRadius: s * 2),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Fireworks Painter
// ─────────────────────────────────────────────────────────────────────────────
class _FireworksPainter extends CustomPainter {
  final double progress;
  static final Random _rng = Random(7);

  // Pre-generate burst origins so they don't shift every frame
  static final List<Map<String, dynamic>> _bursts = List.generate(7, (i) {
    return {
      'x': 0.1 + _rng.nextDouble() * 0.8,
      'y': 0.05 + _rng.nextDouble() * 0.55,
      'offset': _rng.nextDouble(), // phase offset [0,1)
      'color': [
        const Color(0xFFFFD700), // gold
        const Color(0xFF00E5FF), // cyan
        const Color(0xFFFF8C00), // orange
        const Color(0xFF76FF03), // lime
        const Color(0xFFFF4081), // pink
        const Color(0xFFE040FB), // purple
        const Color(0xFF40C4FF), // light blue
      ][i % 7],
    };
  });

  _FireworksPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final burst in _bursts) {
      final localProgress = ((progress + (burst['offset'] as double)) % 1.0);
      if (localProgress > 0.9) continue; // reset gap

      final cx = (burst['x'] as double) * size.width;
      final cy = (burst['y'] as double) * size.height;
      final color = burst['color'] as Color;

      final maxRadius = size.width * 0.25 * localProgress;
      final alpha = (1.0 - localProgress).clamp(0.0, 1.0);

      const particleCount = 12;
      final paint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      for (int p = 0; p < particleCount; p++) {
        final angle = (p / particleCount) * 2 * pi;
        final px = cx + maxRadius * cos(angle);
        final py = cy + maxRadius * sin(angle);
        final dotSize = (4 * (1 - localProgress)).clamp(1.0, 6.0);
        canvas.drawCircle(Offset(px, py), dotSize, paint);

        // Inner sparkle
        if (particleCount > 6 && p % 2 == 0) {
          final innerR = maxRadius * 0.55;
          final innerAngle = angle + pi / particleCount;
          canvas.drawCircle(
            Offset(cx + innerR * cos(innerAngle), cy + innerR * sin(innerAngle)),
            dotSize * 0.6,
            paint,
          );
        }
      }

      // Central glow ring
      final ringPaint = Paint()
        ..color = color.withValues(alpha: alpha * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      if (maxRadius > 0) canvas.drawCircle(Offset(cx, cy), maxRadius, ringPaint);
    }
  }

  @override
  bool shouldRepaint(_FireworksPainter old) => old.progress != progress;
}
