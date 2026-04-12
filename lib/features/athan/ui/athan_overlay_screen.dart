import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/services.dart';
import '../../audio/services/audio_handler.dart';
import '../services/athan_manager.dart';

class AthanOverlayScreen extends StatefulWidget {
  final String prayerName;
  final bool isFajr;

  const AthanOverlayScreen({
    super.key,
    required this.prayerName,
    this.isFajr = false,
    this.isColdStart = false,
  });

  final bool isColdStart;

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
  late final AnimationController _acceptanceFadeController;
  late final Animation<double> _acceptanceFadeAnimation;

  @override
  void initState() {
    // 🔥 Ensure screen wakes up instantly on boot/locked
    WakelockPlus.enable();
    
    // 🛡️ Sovereignty: Take over full screen, hide navigation and status bars
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
    
    super.initState();
    _openedAt = DateTime.now();

    // ✅ تحقق أمان: لو الاسم غير صالح، أغلق الشاشة فوراً لمنع الشاشات المعلقة
    if (widget.prayerName.isEmpty ||
        widget.prayerName == "الصلاة" ||
        widget.prayerName.toLowerCase() == "null") {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }


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

    // --- Acceptance text fade-in ---
    _acceptanceFadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _acceptanceFadeAnimation = CurvedAnimation(
      parent: _acceptanceFadeController,
      curve: Curves.easeIn,
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
    _pulseController.dispose();
    _fadeInController.dispose();
    _acceptanceFadeController.dispose();
    _playbackSub?.cancel();
    _mediaSub?.cancel();

    // --- Allow screen to turn off again ---
    WakelockPlus.disable();

    // 🛡️ Restore System UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );

    super.dispose();
  }

  void _closeOverlay({bool force = false}) {
    if (!mounted || _stopping) return;

    // 🔥 تجنب الإغلاق التلقائي في أول ثانيتين للسماح للمشغل بالمزامنة
    // إلا إذا كان الإغلاق "قسرياً" (بواسطة زر المستخدم أو إشارة الناتيف)
    final now = DateTime.now();
    final elapsed = now.difference(_openedAt).inSeconds;

    if (!force && elapsed < 2) {
      return;
    }

    if (mounted && !_stopping) {
      
      // ✅ Natural Return Protocol: 
      // If it's a natural end (not forced by button), show "تقبل الله طاعتكم" and wait 2s
      if (!force) {
        _acceptanceFadeController.forward();
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _stopping = true;
            _handleNavigation();
          }
        });
      } else {
        // Forced by user: close immediately
        _stopping = true;
        _handleNavigation();
      }
    }
  }

  void _handleNavigation() {
    if (mounted) {
      Navigator.of(context).pop();
      // ✅ استدعاء الميثود المنقذة لضمان الخروج التام في حالة الـ Cold Start
      AthanManager.finalizeAthanSession();
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
        resizeToAvoidBottomInset: false,
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
            // --- Acceptance Text (Natural Return) ---
            FadeTransition(
              opacity: _acceptanceFadeAnimation,
              child: Text(
                'تقبل الله طاعتكم',
                style: GoogleFonts.tajawal(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.8),
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 20),
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
