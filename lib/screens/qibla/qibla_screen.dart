import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';
import 'package:animate_do/animate_do.dart';
import 'package:adhan/adhan.dart' as adhan;

import '../../core/theme/app_colors.dart';
import '../../providers/settings_provider.dart';
import '../../core/services/storage_service.dart';
import 'location_error_widget.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  final _deviceSupportFuture = FlutterQiblah.androidDeviceSensorSupport();

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<SettingsProvider>().languageCode;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        automaticallyImplyLeading: true,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_forward_ios),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          locale == 'ar' ? 'اتجاه القبلة' : 'Qibla Direction',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),

          // Subtitle
          FadeInDown(
            delay: const Duration(milliseconds: 100),
            child: Text(
              locale == 'ar'
                  ? 'اتجه نحو الكعبة المشرفة'
                  : 'Face towards the Holy Kaaba',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.white54 
                        : Colors.black54,
                  ),
            ),
          ),

          const Spacer(),

          // Compass area with Sensor Check
          Expanded(
            flex: 8,
            child: FutureBuilder(
              future: _deviceSupportFuture,
              builder: (_, AsyncSnapshot<bool?> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      locale == 'ar'
                          ? 'حدث خطأ: ${snapshot.error.toString()}'
                          : 'Error: ${snapshot.error.toString()}',
                      style: const TextStyle(color: AppColors.error),
                    ),
                  );
                }
                if (snapshot.data == true) {
                  return QiblaCompass(locale: locale);
                } else {
                  return _UnsupportedWidget(locale: locale);
                }
              },
            ),
          ),

          const Spacer(),

          // Distance to Mecca
          FadeInUp(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mosque, color: AppColors.gold, size: 24),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        locale == 'ar'
                            ? 'مكة المكرمة'
                            : 'Makkah al-Mukarramah',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: AppColors.gold,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        locale == 'ar'
                            ? '21.4225° شمالاً، 39.8262° شرقاً'
                            : '21.4225°N, 39.8262°E',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.white54 
                                  : Colors.black54,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class QiblaCompass extends StatefulWidget {
  final String locale;

  const QiblaCompass({super.key, required this.locale});

  @override
  State<QiblaCompass> createState() => _QiblaCompassState();
}

class _QiblaCompassState extends State<QiblaCompass> {
  final _locationStreamController =
      StreamController<LocationStatus>.broadcast();

  // Track if we are using cached location for UI feedback
  bool _isOffline = false;
  double? _cachedLat;
  double? _cachedLon;

  Stream<LocationStatus> get stream => _locationStreamController.stream;

  @override
  void initState() {
    super.initState();
    _checkLocationStatus();
  }

  Future<void> _checkLocationStatus() async {
    // Rule: Always check permission first even if offline
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (_) {}

    final locationStatus = await FlutterQiblah.checkLocationStatus();
    _locationStreamController.sink.add(locationStatus);

    if (locationStatus.enabled &&
        (locationStatus.status == LocationPermission.always ||
         locationStatus.status == LocationPermission.whileInUse)) {
      
      // Try to get a fresh fix, but with a short timeout to handle offline/no-signal
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
        ).timeout(const Duration(seconds: 3));
        
        setState(() {
          _isOffline = false;
          _cachedLat = position.latitude;
          _cachedLon = position.longitude;
        });
      } catch (e) {
        // Fallback: Fetch last saved location from StorageService
        try {
          final storage = await StorageService.create();
          final lastLoc = storage.getLastLocation();
          
          if (lastLoc != null) {
            setState(() {
              _isOffline = true;
              _cachedLat = lastLoc.latitude;
              _cachedLon = lastLoc.longitude;
            });
            developer.log('[Qibla] Using cached location: ${lastLoc.latitude}, ${lastLoc.longitude}', name: 'QiblaScreen');
          }
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _locationStreamController.close();
    FlutterQiblah().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8.0),
      child: StreamBuilder(
        stream: stream,
        builder: (context, AsyncSnapshot<LocationStatus> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CupertinoActivityIndicator(color: AppColors.gold);
          }
          final status = snapshot.data;
          if (status != null && status.enabled == true) {
            switch (status.status) {
              case LocationPermission.always:
              case LocationPermission.whileInUse:
                return Column(
                  children: [
                    Expanded(
                      child: QiblahCompassWidget(
                        locale: widget.locale,
                        isOffline: _isOffline,
                        lat: _cachedLat,
                        lon: _cachedLon,
                      ),
                    ),
                    if (_isOffline)
                      FadeInUp(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            widget.locale == 'ar'
                                ? 'يتم الحساب بناءً على آخر موقع مسجل (بدون إنترنت)'
                                : 'Calculating based on last recorded location (Offline)',
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white54
                                  : Colors.black54,
                              fontSize: 12,
                              fontFamily: 'Tajawal',
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );

              case LocationPermission.denied:
                return LocationErrorWidget(
                  error: widget.locale == 'ar'
                      ? "تم رفض إذن الوصول للموقع"
                      : "Location service permission denied",
                  callback: _checkLocationStatus,
                  locale: widget.locale,
                );
              case LocationPermission.deniedForever:
                return LocationErrorWidget(
                  error: widget.locale == 'ar'
                      ? "تم رفض إذن الموقع بشكل دائم!"
                      : "Location service Denied Forever!",
                  callback: _checkLocationStatus,
                  locale: widget.locale,
                );
              default:
                return const SizedBox.shrink();
            }
          } else {
            return LocationErrorWidget(
              error: widget.locale == 'ar'
                  ? "يرجى تفعيل خدمة الموقع (GPS)"
                  : "Please enable Location service",
              callback: _checkLocationStatus,
              locale: widget.locale,
            );
          }
        },
      ),
    );
  }
}

class QiblahCompassWidget extends StatefulWidget {
  final String locale;
  final bool isOffline;
  final double? lat;
  final double? lon;

  const QiblahCompassWidget({
    super.key,
    required this.locale,
    this.isOffline = false,
    this.lat,
    this.lon,
  });

  @override
  State<QiblahCompassWidget> createState() => _QiblahCompassWidgetState();
}

class _QiblahCompassWidgetState extends State<QiblahCompassWidget> {
  bool _wasAligned = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final compassSize = size.height * 0.55 < size.width * 0.9 
        ? size.height * 0.55 
        : size.width * 0.9;

    return StreamBuilder(
      stream: FlutterQiblah.qiblahStream,
      builder: (_, AsyncSnapshot<QiblahDirection> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCompass(compassSize);
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _buildErrorCompass(locale: widget.locale);
        }

        final qiblahDirection = snapshot.data!;
        
        // Rule: If offline, calculate the Qibla offset manually using provided coords.
        // Qibla direction in the package is (AngleToMecca - DeviceHeading).
        // If we are offline, we use the adhan package for AngleToMecca.
        double finalQiblah;
        if (widget.isOffline && widget.lat != null && widget.lon != null) {
          final qiblaAngle = adhan.Qibla(adhan.Coordinates(widget.lat!, widget.lon!)).direction;
          finalQiblah = qiblaAngle - qiblahDirection.direction; // direction here is the device heading relative to north
        } else {
          finalQiblah = qiblahDirection.qiblah;
        }

        final double turns = (finalQiblah * -1) / 360.0;

        // Shortest angular distance logic
        double diff = finalQiblah % 360;
        if (diff > 180) diff -= 360;
        if (diff < -180) diff += 360;

        bool isAligned = diff.abs() <= 2.0;

        if (isAligned && !_wasAligned) {
          _wasAligned = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final settings = context.read<SettingsProvider>();
            if (settings.qiblaVibrationEnabled) {
              HapticFeedback.mediumImpact();
            }
          });
        } else if (!isAligned && _wasAligned) {
          _wasAligned = false;
        }

        final targetColor = isAligned ? AppColors.success : AppColors.gold;

        return TweenAnimationBuilder<Color?>(
          tween: ColorTween(begin: AppColors.gold, end: targetColor),
          duration: const Duration(milliseconds: 300),
          builder: (context, color, child) {
            final currentColor = color ?? AppColors.gold;
            return SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildCompassStack(compassSize, turns, currentColor),
                  const SizedBox(height: 48),
                  _buildGuidanceContainer(currentColor),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingCompass(double size) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade400.withValues(alpha: 0.3),
      highlightColor: Colors.grey.shade100.withValues(alpha: 0.6),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStaticStack(size),
            const SizedBox(height: 32),
            Text(
              widget.locale == 'ar'
                  ? "جار تهيئة البوصلة...\nيرجى الانتظار..."
                  : "Preparing compass...\nPlease wait...",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCompass({required String locale}) {
    return Center(
      child: Text(
        locale == 'ar' ? 'فشل تحميل بيانات البوصلة' : 'Failed to load compass data',
        style: const TextStyle(color: AppColors.error),
      ),
    );
  }

  Widget _buildStaticStack(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SvgPicture.asset(
            'assets/images/qibla_compass.svg',
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            fit: BoxFit.contain,
          ),
          SvgPicture.asset(
            'assets/images/qibla_kaaba.svg',
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            fit: BoxFit.contain,
          ),
          SvgPicture.asset(
            'assets/images/qibla_needle.svg',
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }

  Widget _buildCompassStack(double size, double turns, Color currentColor) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // 1. Dial (Static)
          SvgPicture.asset(
            'assets/images/qibla_compass.svg',
            colorFilter: ColorFilter.mode(currentColor, BlendMode.srcIn),
            fit: BoxFit.contain,
          ),
          
          // 2. Kaaba (Static at the 0° position)
          SvgPicture.asset(
            'assets/images/qibla_kaaba.svg',
            fit: BoxFit.contain,
          ),

          // 3. Needle (Rotating)
          AnimatedRotation(
            turns: turns,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            child: SvgPicture.asset(
              'assets/images/qibla_needle.svg',
              colorFilter: ColorFilter.mode(currentColor, BlendMode.srcIn),
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidanceContainer(Color currentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: currentColor.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        widget.locale == 'ar'
            ? "قم بمحاذاة السهمين معاً\nأبعد جهازك عن أي معادن لضمان الدقة.\nقم بمعايرة البوصلة عند كل استخدام."
            : "Align both arrow heads\nDo not put device close to metal object.\nCalibrate the compass everytime you use it.",
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          height: 1.6,
        ),
      ),
    );
  }
}

class _UnsupportedWidget extends StatelessWidget {
  final String locale;
  const _UnsupportedWidget({required this.locale});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sensors_off, color: AppColors.gold, size: 64),
          const SizedBox(height: 16),
          Text(
            locale == 'ar'
                ? 'جهازك لا يدعم بوصلة القبلة'
                : 'Your device does not support the Qibla compass',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            locale == 'ar'
                ? 'يبدو أن جهازك يفتقر إلى المستشعر المغناطيسي المطلوب لتحديد الاتجاهات.'
                : 'It seems your device lacks the magnetic sensor required for compass direction.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white54,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
