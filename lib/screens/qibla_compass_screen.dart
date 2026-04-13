import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:adhan/adhan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_constants.dart';

enum LocationSource { precise, cached, manual }

class QiblaCompassScreen extends StatefulWidget {
  const QiblaCompassScreen({super.key});

  @override
  State<QiblaCompassScreen> createState() => _QiblaCompassScreenState();
}

class _QiblaCompassScreenState extends State<QiblaCompassScreen> {
  double? _qiblaDirection;
  double? _heading;
  bool _isLoading = true;
  String _error = '';
  StreamSubscription? _compassSubscription;
  bool _isAligned = false;
  LocationSource _locationSource = LocationSource.manual;
  String _locationName = '';

  @override
  void initState() {
    super.initState();
    _initQibla();
  }

  Future<void> _initQibla() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. محاولة جلب الموقع المخبأ (Cached)
      double? lat = prefs.getDouble('last_lat');
      double? lng = prefs.getDouble('last_lng');

      if (lat != null && lng != null) {
        _locationSource = LocationSource.cached;
        _locationName = "آخر موقع معروف";
        _calculateQibla(lat, lng);
      } else {
        // 2. محاولة جلب إحداثيات المدينة المختارة (Manual)
        final selectedCityStr =
            prefs.getString(AppConstants.selectedCityKey) ?? 'Cairo, Egypt';
        final cityName = selectedCityStr.split(',').first.trim();
        _locationName = cityName;
        _locationSource = LocationSource.manual;

        final cityData = AppConstants.cities.firstWhere(
          (c) =>
              c['nameEn'].toString().toLowerCase() == cityName.toLowerCase() ||
              c['name'].toString() == cityName,
          orElse: () => AppConstants.cities.first,
        );
        _calculateQibla(
            cityData['latitude'] as double, cityData['longitude'] as double);
      }

      if (mounted) setState(() => _isLoading = false);

      // 3. تشغيل البحث عن الموقع الدقيق في الخلفية (Precise)
      _fetchPreciseLocation();

      // 4. بدء اشتراك البوصلة
      _compassSubscription = FlutterCompass.events?.listen((event) {
        if (mounted) {
          setState(() {
            _heading = event.heading;
            _checkAlignment();
          });
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'حدث خطأ في تهيئة الحساسات: $e');
    }
  }

  Future<void> _fetchPreciseLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition();

      // تم العثور على موقع دقيق!
      if (mounted) {
        setState(() {
          _locationSource = LocationSource.precise;
          _calculateQibla(position.latitude, position.longitude);
        });
      }

      // تحديث الكاش
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('last_lat', position.latitude);
      await prefs.setDouble('last_lng', position.longitude);
    } catch (e) {
      debugPrint('Precise location error: $e');
    }
  }

  void _calculateQibla(double lat, double lng) {
    final coordinates = Coordinates(lat, lng);
    final qibla = Qibla(coordinates);
    setState(() {
      _qiblaDirection = qibla.direction;
    });
  }

  void _checkAlignment() {
    if (_qiblaDirection == null || _heading == null) return;

    // Calculate the difference
    double diff = (_qiblaDirection! - _heading!).abs();
    if (diff > 180) diff = 360 - diff;

    final aligned = diff < 2.5; // Within 2.5 degrees is close enough
    if (aligned && !_isAligned) {
      HapticFeedback.mediumImpact();
    }
    _isAligned = aligned;
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDarkMode
            ? const Color(0xFF0A0A0A)
            : const Color(0xFFF5F5F0),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'قبلة الصلاة',
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          centerTitle: true,
          iconTheme: IconThemeData(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
              )
            : _error.isNotEmpty
            ? Center(child: Text(_error, style: GoogleFonts.tajawal()))
            : _buildCompassUI(isDarkMode),
      ),
    );
  }

  Widget _buildCompassUI(bool isDarkMode) {
    if (_heading == null || _qiblaDirection == null) {
      return const Center(child: Text('جاري تحديد المستشعرات...'));
    }

    // needle angle = qiblaDirection - heading (in degrees)
    double needleAngleDegrees = _qiblaDirection! - _heading!;
    double needleAngleRadians = needleAngleDegrees * (math.pi / 180);

    return Column(
      children: [
        const SizedBox(height: 40),

        // Degree Display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              Text(
                '${_qiblaDirection?.toStringAsFixed(1)}°',
                style: GoogleFonts.tajawal(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFD4AF37),
                ),
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: _locationSource == LocationSource.precise
                    ? const SizedBox.shrink()
                    : Text(
                        _locationSource == LocationSource.cached
                            ? '(تعتمد القبلة على آخر موقع معروف)'
                            : '(تعتمد القبلة على موقعك المسجل: $_locationName)',
                        key: ValueKey(_locationSource),
                        style: GoogleFonts.tajawal(
                          fontSize: 11,
                          color: isDarkMode ? Colors.white38 : Colors.black38,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // The Compass Visual
        Center(
          child: SizedBox(
            width: 300,
            height: 300,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Dial Background
                CustomPaint(
                  size: const Size(300, 300),
                  painter: CompassDialPainter(isDarkMode: isDarkMode),
                ),

                // North Marker (Fixed to phone top)
                Positioned(
                  top: 20,
                  child: Text(
                    'N',
                    style: GoogleFonts.tajawal(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),

                // Smooth Needle
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: needleAngleRadians),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  builder: (context, angle, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Alignment Glow Effect
                        if (_isAligned)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withValues(alpha: 0.3),
                                  blurRadius: 30,
                                  spreadRadius: 20,
                                ),
                              ],
                            ),
                          ),

                        // Needle
                        Transform.rotate(
                          angle: angle,
                          child: SvgPicture.asset(
                            'assets/images/needle.svg',
                            height: 220,
                            // Ensure the image fits and doesn't clip
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        const Spacer(),

        // Calibration Instruction
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
          child: Column(
            children: [
              Text(
                _isAligned
                    ? 'أنت الآن في اتجاه القبلة الصحيح'
                    : 'حرك هاتفك حتى يشير السهم للأعلى',
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(
                  fontSize: 16,
                  color: _isAligned
                      ? Colors.green
                      : (isDarkMode ? Colors.white70 : Colors.black54),
                  fontWeight: _isAligned ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFFD4AF37),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'لزيادة الدقة، قم بتحريك الهاتف على شكل رقم (8) في الهواء لمعايرة البوصلة.',
                        style: GoogleFonts.tajawal(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }
}

class CompassDialPainter extends CustomPainter {
  final bool isDarkMode;
  CompassDialPainter({required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer Circle
    final paint = Paint()
      ..color = const Color(0xFFD4AF37).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, paint);

    // Minor notches
    final notchPaint = Paint()
      ..color = isDarkMode ? Colors.white24 : Colors.black12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 0; i < 60; i++) {
      final angle = (i * 6) * math.pi / 180;
      final start = Offset(
        center.dx + (radius - 5) * math.cos(angle),
        center.dy + (radius - 5) * math.sin(angle),
      );
      final end = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(start, end, notchPaint);
    }

    // Major notches (every 30 degrees)
    final majorNotchPaint = Paint()
      ..color = const Color(0xFFD4AF37)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var i = 0; i < 12; i++) {
      final angle = (i * 30) * math.pi / 180;
      final start = Offset(
        center.dx + (radius - 12) * math.cos(angle),
        center.dy + (radius - 12) * math.sin(angle),
      );
      final end = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(start, end, majorNotchPaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
