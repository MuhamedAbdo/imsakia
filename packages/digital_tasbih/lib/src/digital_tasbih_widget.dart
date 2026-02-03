import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

class DigitalTasbih extends StatefulWidget {
  const DigitalTasbih({super.key});

  @override
  State<DigitalTasbih> createState() => _DigitalTasbihState();
}

class _DigitalTasbihState extends State<DigitalTasbih>
    with TickerProviderStateMixin {
  int _count = 0;
  late AnimationController _buttonController;
  late AnimationController _lcdController;
  late Animation<double> _buttonAnimation;
  late Animation<double> _lcdAnimation;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadCount();

    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _lcdController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _buttonAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );

    _lcdAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _lcdController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _buttonController.dispose();
    _lcdController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadCount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _count = prefs.getInt('digital_tasbih_count') ?? 0;
    });
  }

  Future<void> _saveCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('digital_tasbih_count', _count);
  }

  Future<void> _playSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/click.mp3'));
    } catch (e) {
      // Sound file not found, continue without sound
    }
  }

  Future<void> _incrementCount() async {
    // Haptic feedback
    HapticFeedback.lightImpact();

    // Play sound
    _playSound();

    // Animate button
    _buttonController.forward().then((_) {
      _buttonController.reverse();
    });

    // Animate LCD
    _lcdController.forward().then((_) {
      _lcdController.reverse();
    });

    // Update count
    setState(() {
      _count++;
    });
    _saveCount();
  }

  void _resetCount() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('إعادة تعيين'),
          content: const Text('هل تريد إعادة تعيين العداد؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _count = 0;
                });
                _saveCount();
                Navigator.pop(context);
              },
              child: const Text('موافق'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'المسبحة الرقمية',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            onPressed: _resetCount,
          ),
        ],
      ),
      body: Center(
        child: DigitalTasbihWidget(
          count: _count,
          onPressed: _incrementCount,
          isDark: isDark,
        ),
      ),
    );
  }
}

class DigitalTasbihWidget extends StatelessWidget {
  final int count;
  final VoidCallback onPressed;
  final bool isDark;

  const DigitalTasbihWidget({
    super.key,
    required this.count,
    required this.onPressed,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
      height: 600,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 25,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Wooden body with horizontal grain
          _WoodenBody(isDark: isDark),

          // LCD Display - rectangular
          _LCDDisplay(count: count, isDark: isDark),

          // Two circular buttons
          _Buttons(onPressed: onPressed, isDark: isDark),
        ],
      ),
    );
  }
}

class _WoodenBody extends StatelessWidget {
  final bool isDark;

  const _WoodenBody({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFD4A574), // Light brown wood
            const Color(0xFFC19A6B), // Medium brown
            const Color(0xFFA0826D), // Darker brown
          ],
        ),
      ),
      child: CustomPaint(
        painter: HorizontalWoodGrainPainter(),
        child: Container(),
      ),
    );
  }
}

class _LCDDisplay extends StatelessWidget {
  final int count;
  final bool isDark;

  const _LCDDisplay({required this.count, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 100,
      left: 50,
      right: 50,
      height: 80,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C), // Dark display background
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
            // Inner shadow for recessed effect
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 2,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            count.toString().padLeft(3, '0'),
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE0E0E0), // Light grey/white text
              fontFamily: 'monospace',
              letterSpacing: 8,
            ),
          ),
        ),
      ),
    );
  }
}

class _Buttons extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isDark;

  const _Buttons({required this.onPressed, required this.isDark});

  @override
  State<_Buttons> createState() => _ButtonsState();
}

class _ButtonsState extends State<_Buttons>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
  }


  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('إعادة تعيين'),
          content: const Text('هل تريد إعادة تعيين العداد؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // You'll need to add reset functionality
              },
              child: const Text('موافق'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 80,
      left: 40,
      right: 40,
      height: 120,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Smaller button (left)
          _CircularButton(
            size: 50,
            onPressed: () {
              // Reset functionality for smaller button
              _showResetDialog(context);
            },
            isMainButton: false,
          ),

          // Larger button (right) - main counter
          _CircularButton(
            size: 70,
            onPressed: widget.onPressed,
            isMainButton: true,
          ),
        ],
      ),
    );
  }
}

class _CircularButton extends StatefulWidget {
  final double size;
  final VoidCallback onPressed;
  final bool isMainButton;

  const _CircularButton({
    required this.size,
    required this.onPressed,
    required this.isMainButton,
  });

  @override
  State<_CircularButton> createState() => _CircularButtonState();
}

class _CircularButtonState extends State<_CircularButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePress() {
    _controller.forward().then((_) {
      _controller.reverse();
    });
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: _handlePress,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFFD700), // Bright gold center
                  const Color(0xFFFFD700), // Gold
                  const Color(0xFFDAA520), // Goldenrod
                ],
              ),
              boxShadow: [
                // Subtle glow effect
                BoxShadow(
                  color: Colors.amber.withOpacity(_glowAnimation.value),
                  blurRadius: 15,
                  spreadRadius: 2,
                  offset: const Offset(0, 0),
                ),
                // Regular shadow
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
                // Inner shadow for depth
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 2,
                  spreadRadius: -1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Icon(
                widget.isMainButton ? Icons.add : Icons.refresh,
                color: Colors.white,
                size: widget.size * 0.6,
              ),
            ),
          );
        },
      ),
    );
  }
}

class HorizontalWoodGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.brown.withOpacity(0.15)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final random = math.Random(42); // Fixed seed for consistent pattern

    // Draw horizontal wood grain lines
    for (int i = 0; i < 25; i++) {
      final y = (i + 1) * (size.height / 26);
      final path = Path();
      path.moveTo(0, y);

      for (double x = 0; x <= size.width; x += 15) {
        final yOffset = math.sin(x * 0.01) * 3 + random.nextDouble() * 2 - 1;
        path.lineTo(x, y + yOffset);
      }

      canvas.drawPath(path, paint);
    }

    // Add some vertical grain lines occasionally
    paint.color = Colors.brown.withOpacity(0.08);
    for (int i = 0; i < 8; i++) {
      final x = random.nextDouble() * size.width;
      final path = Path();
      path.moveTo(x, 0);

      for (double y = 0; y <= size.height; y += 20) {
        final xOffset = random.nextDouble() * 4 - 2;
        path.lineTo(x + xOffset, y);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WoodGrainPainter extends CustomPainter {
  final bool isDark;

  WoodGrainPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark
          ? Colors.black.withOpacity(0.1)
          : Colors.brown.withOpacity(0.1)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final random = math.Random(42); // Fixed seed for consistent pattern

    for (int i = 0; i < 20; i++) {
      final path = Path();
      final startY = random.nextDouble() * size.height;

      path.moveTo(0, startY);

      for (double x = 0; x <= size.width; x += 10) {
        final y =
            startY + math.sin(x * 0.02) * 10 + random.nextDouble() * 5 - 2.5;
        path.lineTo(x, y);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
