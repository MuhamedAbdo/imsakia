import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';

import 'dart:math' as math;
import 'neumorphic_box.dart';

class WoodGrainPainter extends CustomPainter {
  final bool isDark;

  WoodGrainPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // Main wood grain lines
    final mainPaint = Paint()
      ..color = isDark
          ? const Color(0xFF2C1810).withValues(alpha: 0.15) // تحديث هنا
          : const Color(0xFF8B4513).withValues(alpha: 0.2) // تحديث هنا
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Fine wood grain detail
    final detailPaint = Paint()
      ..color = isDark
          ? const Color(0xFF1A0E08).withValues(alpha: 0.08) // تحديث هنا
          : const Color(0xFFD2691E).withValues(alpha: 0.1) // تحديث هنا
      ..strokeWidth = 0.3
      ..style = PaintingStyle.stroke;

    // Draw main wood grain lines
    for (int i = 0; i < 25; i++) {
      final y = (size.height / 25) * i;
      const startX = 0.0;
      final endX = size.width;

      final path = Path();
      path.moveTo(startX, y);

      for (double x = startX; x <= endX; x += 8) {
        final wave = math.sin(x * 0.02) * 2;
        final offsetY = y + wave + (i % 3 == 0 ? 1 : -1) * 2;
        path.lineTo(x, offsetY);
      }

      canvas.drawPath(path, mainPaint);
    }

    // Draw fine wood grain details
    for (int i = 0; i < 40; i++) {
      final y = (size.height / 40) * i + 5;
      const startX = 10.0;
      final endX = size.width - 10;

      final path = Path();
      path.moveTo(startX, y);

      for (double x = startX; x <= endX; x += 15) {
        final wave = math.sin(x * 0.05) * 1;
        final offsetY = y + wave;
        path.lineTo(x, offsetY);
      }

      canvas.drawPath(path, detailPaint);
    }

    // Add wood knots
    final knotPaint = Paint()
      ..color = isDark
          ? const Color(0xFF1A0E08).withValues(alpha: 0.3) // تحديث هنا
          : const Color(0xFF8B4513).withValues(alpha: 0.4) // تحديث هنا
      ..style = PaintingStyle.fill;

    final knots = [
      Offset(size.width * 0.3, size.height * 0.2),
      Offset(size.width * 0.7, size.height * 0.4),
      Offset(size.width * 0.5, size.height * 0.7),
    ];

    for (final knot in knots) {
      canvas.drawOval(
        Rect.fromCenter(center: knot, width: 8, height: 4),
        knotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CustomTasbih extends StatefulWidget {
  const CustomTasbih({super.key});

  @override
  State<CustomTasbih> createState() => _CustomTasbihState();
}

class _CustomTasbihState extends State<CustomTasbih>
    with TickerProviderStateMixin {
  int _count = 0;
  int _dailyCount = 0;
  late AnimationController _largeButtonController;
  late AnimationController _smallButtonController;
  late Animation<double> _largeButtonScale;
  late Animation<double> _smallButtonScale;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadCount();
    _loadDailyCount();

    _largeButtonController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );

    _smallButtonController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );

    _largeButtonScale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _largeButtonController, curve: Curves.elasticOut),
    );

    _smallButtonScale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _smallButtonController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _largeButtonController.dispose();
    _smallButtonController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadCount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _count = prefs.getInt('custom_tasbih_count') ?? 0;
    });
  }

  Future<void> _saveCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('custom_tasbih_count', _count);
  }

  Future<void> _loadDailyCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = 'daily_count_${today.day}_${today.month}_${today.year}';
    const lastResetKey = 'last_reset_date';

    final lastResetDate = prefs.getString(lastResetKey);
    final todayString = '${today.day}_${today.month}_${today.year}';

    if (lastResetDate != todayString) {
      await prefs.setString(lastResetKey, todayString);
      await prefs.setInt(todayKey, 0);
      _dailyCount = 0;
    } else {
      setState(() {
        _dailyCount = prefs.getInt(todayKey) ?? 0;
      });
    }
  }

  Future<void> _saveDailyCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = 'daily_count_${today.day}_${today.month}_${today.year}';
    await prefs.setInt(todayKey, _dailyCount);
  }

  Future<void> _playClickSound() async {
    try {
      await _audioPlayer.setAsset('assets/sounds/click.mp3');
      await _audioPlayer.play();
    } catch (e) {
      // ignore
    }
  }

  Future<void> _incrementCount() async {
    HapticFeedback.heavyImpact();
    _playClickSound();
    _largeButtonController.forward().then(
      (_) => _largeButtonController.reverse(),
    );
    setState(() {
      _count++;
      _dailyCount++;
    });
    _saveCount();
    _saveDailyCount();
  }

  Future<void> _resetCount() async {
    HapticFeedback.mediumImpact();
    _playClickSound();
    _smallButtonController.forward().then(
      (_) => _smallButtonController.reverse(),
    );
    setState(() {
      _count = 0;
    });
    _saveCount();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NeumorphicBox(
          borderRadius: 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Text(
                'تسبيحات اليوم',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                  fontFamily: 'Cairo',
                  shadows: [
                    Shadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.3),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$_dailyCount',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                  fontFamily: 'Cairo',
                  shadows: [
                    Shadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.3),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 25),
        Container(
          width: 280,
          height: 450,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(60),
            gradient: RadialGradient(
              center: const Alignment(0.2, -0.3),
              radius: 1.8,
              colors: isDark
                  ? [
                      const Color(0xFF3E2723),
                      const Color(0xFF2C1810),
                      const Color(0xFF1A0E08),
                    ]
                  : [
                      const Color(0xFFD2691E),
                      const Color(0xFFB8956A),
                      const Color(0xFF8B4513),
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 25,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 40,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(60),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  isDark
                      ? Colors.black.withValues(alpha: 0.1)
                      : Colors.brown.withValues(alpha: 0.05),
                ],
                stops: const [0.7, 1.0],
              ),
            ),
            child: CustomPaint(
              painter: WoodGrainPainter(isDark: isDark),
              child: Stack(
                children: [
                  Positioned(
                    top: 60,
                    left: 40,
                    right: 40,
                    height: 85,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0A0A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.8),
                          width: 8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.9),
                            blurRadius: 15,
                            spreadRadius: -5,
                            offset: const Offset(0, 6),
                            blurStyle: BlurStyle.inner,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: -3,
                            offset: const Offset(0, 3),
                            blurStyle: BlurStyle.inner,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(8),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF222222),
                              Color(0xFF1A1A1A),
                              Color(0xFF151515),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _count.toString(),
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF00FF41),
                              fontFamily: 'Courier New',
                              letterSpacing: 8,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 70,
                    left: 50,
                    right: 50,
                    height: 120,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildButton(_resetCount, 50, _smallButtonScale),
                        _buildButton(_incrementCount, 85, _largeButtonScale),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // دالة مساعدة لتجنب تكرار كود الأزرار
  Widget _buildButton(
    VoidCallback onTap,
    double size,
    Animation<double> animation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: animation.value,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.3, -0.3),
                  radius: 1.5,
                  colors: [
                    Color(0xFFF8F8F8),
                    Color(0xFFE8E8E8),
                    Color(0xFFD0D0D0),
                    Color(0xFFB8B8B8),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: -2,
                    offset: const Offset(-5, -5),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 12,
                    spreadRadius: 1,
                    offset: const Offset(5, 5),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
