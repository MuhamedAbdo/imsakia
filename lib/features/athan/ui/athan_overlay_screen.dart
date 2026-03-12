import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../audio/services/audio_handler.dart';
import '../services/athan_manager.dart';

class AthanOverlayScreen extends StatefulWidget {
  final String prayerName;
  final bool isFajr;

  const AthanOverlayScreen({
    super.key,
    required this.prayerName,
    this.isFajr = false,
  });

  @override
  State<AthanOverlayScreen> createState() => _AthanOverlayScreenState();
}

class _AthanOverlayScreenState extends State<AthanOverlayScreen>
    with TickerProviderStateMixin {
  // === Animation Controllers ===
  late final AnimationController _gradientController;
  late final AnimationController _pulseController;
  late final AnimationController _fadeInController;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  // Gradient color sets: [from, to] for each prayer
  late final List<List<Color>> _gradientPalette;
  late final Animation<Color?> _colorTop;
  late final Animation<Color?> _colorBottom;

  StreamSubscription? _playbackSub;
  StreamSubscription? _mediaSub;

  bool _stopping = false;

  @override
  void initState() {
    super.initState();

    // --- Build color palette based on prayer ---
    if (widget.isFajr) {
      // Pre-dawn: deep navy → purple → soft pink horizon
      _gradientPalette = [
        [const Color(0xFF0A0E27), const Color(0xFF1B1240)],
        [const Color(0xFF1B1240), const Color(0xFF4A2C6E)],
        [const Color(0xFF4A2C6E), const Color(0xFF9B4A8A)],
        [const Color(0xFF9B4A8A), const Color(0xFF1B1240)],
        [const Color(0xFF1B1240), const Color(0xFF0A0E27)],
      ];
    } else if (widget.prayerName.contains('الظهر') ||
        widget.prayerName.contains('العصر')) {
      // Daytime: golden sky → azure
      _gradientPalette = [
        [const Color(0xFF2980B9), const Color(0xFF6DD5FA)],
        [const Color(0xFF6DD5FA), const Color(0xFFFFD700)],
        [const Color(0xFFFFD700), const Color(0xFFFF8C00)],
        [const Color(0xFFFF8C00), const Color(0xFF6DD5FA)],
        [const Color(0xFF6DD5FA), const Color(0xFF2980B9)],
      ];
    } else {
      // Dusk / Isha: deep navy sunset
      _gradientPalette = [
        [const Color(0xFF141E30), const Color(0xFF243B55)],
        [const Color(0xFF243B55), const Color(0xFF1F3A5F)],
        [const Color(0xFF1F3A5F), const Color(0xFF0D1B2A)],
        [const Color(0xFF0D1B2A), const Color(0xFF243B55)],
        [const Color(0xFF243B55), const Color(0xFF141E30)],
      ];
    }

    // --- Gradient animation (slow cycle) ---
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _colorTop = TweenSequence<Color?>([
      for (int i = 0; i < _gradientPalette.length - 1; i++)
        TweenSequenceItem(
          tween: ColorTween(
            begin: _gradientPalette[i][0],
            end: _gradientPalette[i + 1][0],
          ),
          weight: 1,
        ),
    ]).animate(_gradientController);

    _colorBottom = TweenSequence<Color?>([
      for (int i = 0; i < _gradientPalette.length - 1; i++)
        TweenSequenceItem(
          tween: ColorTween(
            begin: _gradientPalette[i][1],
            end: _gradientPalette[i + 1][1],
          ),
          weight: 1,
        ),
    ]).animate(_gradientController);

    // --- Pulse animation for stop button glow ---
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.10).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // --- Fade-in animation for elements on load ---
    _fadeInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _fadeAnimation = CurvedAnimation(
      parent: _fadeInController,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _fadeInController, curve: Curves.easeOutBack),
    );

    // --- Listen to audio to auto-close when athan finishes naturally ---
    if (audioHandler != null) {
      _playbackSub = audioHandler!.playbackState.listen((state) {
        if (!state.playing &&
            audioHandler!.mediaItem.value?.id != 'athan_alert') {
          _closeOverlay();
        }
      });
      _mediaSub = audioHandler!.mediaItem.listen((item) {
        if (item == null || item.id != 'athan_alert') {
          _closeOverlay();
        }
      });
    }
  }

  @override
  void dispose() {
    _gradientController.dispose();
    _pulseController.dispose();
    _fadeInController.dispose();
    _playbackSub?.cancel();
    _mediaSub?.cancel();
    super.dispose();
  }

  void _closeOverlay() {
    if (mounted && !_stopping) {
      _stopping = true;
      Navigator.of(context).pop();
    }
  }

  Future<void> _stopAthan() async {
    if (_stopping) return;
    _stopping = true;

    // Stop audio immediately (fire-and-forget, don't await so UI stays responsive)
    audioHandler?.customAction('stopAthan');

    // Cancel the athan notification
    await AthanManager.cancelAthanNotification();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Prevent back-button from dismissing without stopping athan
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _stopAthan();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AnimatedBuilder(
          animation: _gradientController,
          builder: (context, child) {
            return Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _colorTop.value ?? Colors.black,
                    _colorBottom.value ?? Colors.black87,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: child,
            );
          },
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: _buildContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Stars / decorative top glow
          _buildTopGlow(),

          const SizedBox(height: 20),

          // Mosque Icon
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFFFFF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(bounds),
            child: const Icon(Icons.mosque_rounded, size: 90, color: Colors.white),
          ),

          const SizedBox(height: 24),

          // "حان الآن موعد"
          Text(
            'حان الآن موعد',
            style: GoogleFonts.tajawal(
              fontSize: 22,
              color: Colors.white70,
              letterSpacing: 1.5,
            ),
          ),

          const SizedBox(height: 8),

          // Prayer name
          Text(
            'أذان ${widget.prayerName}',
            textAlign: TextAlign.center,
            style: GoogleFonts.tajawal(
              fontSize: 44,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Divider line
          Container(
            width: 60,
            height: 2,
            decoration: BoxDecoration(
              color: Colors.white38,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 60),

          // Pulsing Stop Button
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: child,
              );
            },
            child: GestureDetector(
              onTap: _stopAthan,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE53935).withValues(alpha: 0.85),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE53935).withValues(alpha: 0.55),
                      blurRadius: 30,
                      spreadRadius: 8,
                    ),
                    BoxShadow(
                      color: const Color(0xFFE53935).withValues(alpha: 0.25),
                      blurRadius: 60,
                      spreadRadius: 20,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.stop_rounded, size: 72, color: Colors.white),
                    const SizedBox(height: 4),
                    Text(
                      'إيقاف',
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

          const SizedBox(height: 32),

          // Hint text
          Text(
            'اضغط لإيقاف الأذان',
            style: GoogleFonts.tajawal(
              fontSize: 14,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopGlow() {
    return AnimatedBuilder(
      animation: _gradientController,
      builder: (context, _) {
        final t = _gradientController.value;
        return Container(
          width: 200,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.04 + 0.04 * t),
                blurRadius: 60,
                spreadRadius: 20,
              ),
            ],
          ),
        );
      },
    );
  }
}
