import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
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
  late final AnimationController _pulseController;
  late final AnimationController _fadeInController;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  StreamSubscription? _playbackSub;
  StreamSubscription? _mediaSub;

  bool _stopping = false;
  late final DateTime _openedAt;

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();

    // ✅ تحقق أمان: لو الاسم غير صالح، أغلق الشاشة فوراً لمنع الشاشات المعلقة
    if (widget.prayerName.isEmpty ||
        widget.prayerName == "الصلاة" ||
        widget.prayerName.toLowerCase() == "null") {
      debugPrint(
        "!!! ATHAN OVERLAY: Invalid prayer name, closing immediately !!!",
      );
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }

    debugPrint(
      "!!! FLUTTER: AthanOverlayScreen opened for '${widget.prayerName}' !!!",
    );

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

    // --- Keep screen on during Athan ---
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeInController.dispose();
    _playbackSub?.cancel();
    _mediaSub?.cancel();

    // --- Allow screen to turn off again ---
    WakelockPlus.disable();

    super.dispose();
  }

  void _closeOverlay({bool force = false}) {
    // 🔥 تجنب الإغلاق التلقائي في أول 3 ثوانٍ للسماح للمشغل بالمزامنة
    // إلا إذا كان الإغلاق "قسرياً" (بواسطة زر المستخدم)
    final now = DateTime.now();
    final elapsed = now.difference(_openedAt).inSeconds;

    if (!force && elapsed < 3) {
      debugPrint(
        "!!! ATHAN OVERLAY: Auto-close ignored (Warm-up period: ${elapsed}s) !!!",
      );
      return;
    }

    if (mounted && !_stopping) {
      debugPrint(
        "!!! ATHAN OVERLAY: Closing overlay (Force: $force, Elapsed: ${elapsed}s) !!!",
      );
      _stopping = true;
      Navigator.of(context).pop();
    }
  }

  String _getBackgroundImage() {
    final name = widget.prayerName.trim();
    String path = 'assets/images/fajr_dawn.png';

    if (name.contains('الفجر') || widget.isFajr) {
      path = 'assets/images/fajr_dawn.png';
    } else if (name.contains('الظهر')) {
      path = 'assets/images/dhuhr_noon.png';
    } else if (name.contains('العصر')) {
      path = 'assets/images/asr_afternoon.png';
    } else if (name.contains('المغرب')) {
      path = 'assets/images/maghrib_sunset.png';
    } else if (name.contains('العشاء')) {
      path = 'assets/images/isha_night.png';
    }

    debugPrint(
      "!!! ATHAN OVERLAY: Selected background '$path' for prayer '$name' !!!",
    );
    return path;
  }

  Future<void> _stopAthan() async {
    if (_stopping) return;

    // إيقاف الصوت والخدمة والمنبهات ناتيف
    await AthanManager.stopAthan();

    // 🔥 إغلاق الشاشة فوراً (تجاهل الـ Grace Period)
    _closeOverlay(force: true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _stopAthan();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black,
            image: DecorationImage(
              image: AssetImage(_getBackgroundImage()),
              fit: BoxFit.cover,
              // يمنع الوميض عند التبديل
            ),
          ),
          child: Stack(
            children: [
              // --- Dark Overlay ---
              Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black.withValues(alpha: 0.45),
              ),
              // --- Content ---
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: _buildContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SafeArea(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            // --- Mosque Icon ---
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFFFFF)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ).createShader(bounds),
              child: const Icon(
                Icons.mosque_rounded,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            // --- Title ---
            Text(
              'حان الآن موعد أذان',
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // --- Prayer Name ---
            Text(
              widget.prayerName,
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(
                fontSize: 56,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // --- Divider ---
            Container(
              width: 50,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Spacer(flex: 3),
            // --- Stop Button at Bottom Center ---
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE53935).withValues(alpha: 0.9),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE53935).withValues(alpha: 0.55),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.stop_rounded,
                          color: Colors.white,
                          size: 52,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'إيقاف الأذان',
                      style: GoogleFonts.tajawal(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
