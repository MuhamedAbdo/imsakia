import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class DigitalTasbih extends StatefulWidget {
  const DigitalTasbih({super.key});

  @override
  State<DigitalTasbih> createState() => _DigitalTasbihState();
}

class _DigitalTasbihState extends State<DigitalTasbih>
    with TickerProviderStateMixin {
  int _counter = 0;
  late AnimationController _bigButtonController;
  late AnimationController _smallButtonController;
  late Animation<double> _bigButtonScale;
  late Animation<double> _smallButtonScale;

  @override
  void initState() {
    super.initState();
    _loadCounter();

    _bigButtonController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _smallButtonController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _bigButtonScale = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _bigButtonController, curve: Curves.easeInOut),
    );
    _smallButtonScale = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _smallButtonController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bigButtonController.dispose();
    _smallButtonController.dispose();
    super.dispose();
  }

  Future<void> _loadCounter() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _counter = prefs.getInt('tasbih_counter') ?? 0;
    });
  }

  Future<void> _saveCounter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tasbih_counter', _counter);
  }

  Future<void> _playClickSound() async {
    // Placeholder for click sound - add your sound file here
    try {
      // For now, use system sound as fallback
      SystemSound.play(SystemSoundType.click);
    } catch (e) {
      // Continue without sound if error occurs
    }
  }

  Future<void> _incrementCounter() async {
    setState(() {
      _counter++;
    });
    await _saveCounter();

    // Play click sound (non-blocking)
    _playClickSound();

    // Light haptic feedback
    HapticFeedback.lightImpact();

    // Button animation
    _bigButtonController.forward().then((_) {
      _bigButtonController.reverse();
    });
  }

  Future<void> _resetCounter() async {
    setState(() {
      _counter = 0;
    });
    await _saveCounter();

    // Heavy haptic feedback
    HapticFeedback.heavyImpact();

    // Button animation
    _smallButtonController.forward().then((_) {
      _smallButtonController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3E2723), Color(0xFF2C1810), Color(0xFF1A0E08)],
        ),
      ),
      child: Stack(
        children: [
          // Main wooden container
          Center(
            child: Container(
              width: 320,
              height: 500,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                  bottomLeft: Radius.circular(80),
                  bottomRight: Radius.circular(80),
                ),
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.3),
                  radius: 1.5,
                  colors: [
                    const Color(0xFFD4A574), // Light brown center
                    const Color(0xFFB8956A),
                    const Color(0xFF8D6E63),
                    const Color(0xFF6D4C41),
                    const Color(0xFF4E342E), // Dark brown edges
                  ],
                  stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.7),
                    offset: const Offset(10, 10),
                    blurRadius: 25,
                    spreadRadius: 3,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    offset: const Offset(-5, -5),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Wood grain effect
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                        bottomLeft: Radius.circular(80),
                        bottomRight: Radius.circular(80),
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(30),
                            topRight: Radius.circular(30),
                            bottomLeft: Radius.circular(80),
                            bottomRight: Radius.circular(80),
                          ),
                        ),
                        child: CustomPaint(painter: WoodGrainPainter()),
                      ),
                    ),
                  ),

                  // LCD Display
                  Positioned(
                    top: 60,
                    left: 40,
                    right: 40,
                    height: 80,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0D0D), // Very dark border
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          // Thick dark border effect
                          BoxShadow(
                            color: Colors.black.withOpacity(0.9),
                            offset: const Offset(0, 6),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                          // Internal shadow for recessed look
                          BoxShadow(
                            color: Colors.black.withOpacity(0.8),
                            offset: const Offset(0, 3),
                            blurRadius: 6,
                            spreadRadius: -3,
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.6),
                            offset: const Offset(-2, -2),
                            blurRadius: 4,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            // Inner shadow depth
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                              spreadRadius: -1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _counter == 0 ? '' : _counter.toString(),
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF808080), // Dark LCD grey
                              fontFamily: 'Courier New',
                              letterSpacing: 6,
                              shadows: [
                                Shadow(
                                  color: Color(0xFF606060),
                                  offset: Offset(1, 1),
                                  blurRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Big Button
                  Positioned(
                    bottom: 80,
                    left: 60,
                    child: AnimatedBuilder(
                      animation: _bigButtonScale,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _bigButtonScale.value,
                          child: GestureDetector(
                            onTapDown: (_) {
                              _bigButtonController.forward();
                            },
                            onTapUp: (_) {
                              _bigButtonController.reverse();
                              _incrementCounter();
                            },
                            onTapCancel: () {
                              _bigButtonController.reverse();
                            },
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment(-0.8, -0.8),
                                  end: Alignment(0.8, 0.8),
                                  colors: [
                                    Color(0xFFE8D5B7), // Bright highlight
                                    Color(0xFFD4A574),
                                    Color(0xFFB8956A),
                                    Color(0xFF9B7653),
                                    Color(0xFF6B4E37), // Dark shadow
                                  ],
                                  stops: [0.0, 0.2, 0.4, 0.7, 1.0],
                                ),
                                boxShadow: [
                                  // Bright white highlight (top-left)
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.6),
                                    offset: const Offset(-10, -10),
                                    blurRadius: 20,
                                    spreadRadius: 3,
                                  ),
                                  // Dark shadow (bottom-right)
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.6),
                                    offset: const Offset(10, 10),
                                    blurRadius: 20,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                              child: Container(
                                margin: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    begin: Alignment(-0.6, -0.6),
                                    end: Alignment(0.6, 0.6),
                                    colors: [
                                      Color(0xFFF5E6D3), // Glossy highlight
                                      Color(0xFFE8D5B7),
                                      Color(0xFFD4A574),
                                      Color(0xFFB8956A),
                                    ],
                                    stops: [0.0, 0.3, 0.6, 1.0],
                                  ),
                                  boxShadow: [
                                    // Inner shadows for depth
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      offset: const Offset(3, 3),
                                      blurRadius: 6,
                                      spreadRadius: -1,
                                    ),
                                    // Subtle gloss effect
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.4),
                                      offset: const Offset(-2, -2),
                                      blurRadius: 4,
                                      spreadRadius: -1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Small Button
                  Positioned(
                    bottom: 120,
                    right: 50,
                    child: AnimatedBuilder(
                      animation: _smallButtonScale,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _smallButtonScale.value,
                          child: GestureDetector(
                            onTapDown: (_) {
                              _smallButtonController.forward();
                            },
                            onTapUp: (_) {
                              _smallButtonController.reverse();
                              _resetCounter();
                            },
                            onTapCancel: () {
                              _smallButtonController.reverse();
                            },
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment(-0.8, -0.8),
                                  end: Alignment(0.8, 0.8),
                                  colors: [
                                    Color(0xFFE8D5B7), // Bright highlight
                                    Color(0xFFD4A574),
                                    Color(0xFFB8956A),
                                    Color(0xFF9B7653),
                                    Color(0xFF6B4E37), // Dark shadow
                                  ],
                                  stops: [0.0, 0.2, 0.4, 0.7, 1.0],
                                ),
                                boxShadow: [
                                  // Bright white highlight (top-left)
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.6),
                                    offset: const Offset(-8, -8),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                  // Dark shadow (bottom-right)
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.6),
                                    offset: const Offset(8, 8),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Container(
                                margin: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    begin: Alignment(-0.6, -0.6),
                                    end: Alignment(0.6, 0.6),
                                    colors: [
                                      Color(0xFFF5E6D3), // Glossy highlight
                                      Color(0xFFE8D5B7),
                                      Color(0xFFD4A574),
                                      Color(0xFFB8956A),
                                    ],
                                    stops: [0.0, 0.3, 0.6, 1.0],
                                  ),
                                  boxShadow: [
                                    // Inner shadows for depth
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      offset: const Offset(2, 2),
                                      blurRadius: 4,
                                      spreadRadius: -1,
                                    ),
                                    // Subtle gloss effect
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.4),
                                      offset: const Offset(-1, -1),
                                      blurRadius: 3,
                                      spreadRadius: -1,
                                    ),
                                  ],
                                ),
                              ),
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
        ],
      ),
    );
  }
}

class WoodGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.1)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw wood grain lines
    for (int i = 0; i < 20; i++) {
      final path = Path();
      final startY = (size.height / 20) * i;

      path.moveTo(0, startY);

      for (double x = 0; x <= size.width; x += 10) {
        final y =
            startY +
            (x * 0.02 * (i % 3 == 0 ? 1 : -1)) +
            (x * 0.01 * (i % 2 == 0 ? 1 : -1));
        path.lineTo(x, y);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
