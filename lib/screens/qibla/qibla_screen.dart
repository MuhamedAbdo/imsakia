import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';
import 'package:animate_do/animate_do.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/settings_provider.dart';
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

    return Stack(
      children: [
        // Background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.darkNavy, AppColors.darkBg],
            ),
          ),
        ),

        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),

              // Title
              FadeInDown(
                child: Text(
                  locale == 'ar' ? 'اتجاه القبلة' : 'Qibla Direction',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              FadeInDown(
                delay: const Duration(milliseconds: 100),
                child: Text(
                  locale == 'ar'
                      ? 'اتجه نحو الكعبة المشرفة'
                      : 'Face towards the Holy Kaaba',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white54,
                      ),
                ),
              ),

              const Spacer(),

              // Compass area with Sensor Check
              Expanded(
                flex: 4,
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
                  margin:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.3)),
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
                                ?.copyWith(color: AppColors.gold),
                          ),
                          Text(
                            locale == 'ar'
                                ? '21.4225° شمالاً، 39.8262° شرقاً'
                                : '21.4225°N, 39.8262°E',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white54),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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

  Stream<LocationStatus> get stream => _locationStreamController.stream;

  @override
  void initState() {
    super.initState();
    _checkLocationStatus();
  }

  Future<void> _checkLocationStatus() async {
    final locationStatus = await FlutterQiblah.checkLocationStatus();
    if (locationStatus.enabled &&
        locationStatus.status == LocationPermission.denied) {
      await FlutterQiblah.requestPermissions();
      final s = await FlutterQiblah.checkLocationStatus();
      _locationStreamController.sink.add(s);
    } else {
      _locationStreamController.sink.add(locationStatus);
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
          if (snapshot.data!.enabled == true) {
            switch (snapshot.data!.status) {
              case LocationPermission.always:
              case LocationPermission.whileInUse:
                return QiblahCompassWidget(locale: widget.locale);

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

  const QiblahCompassWidget({super.key, required this.locale});

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
          // Shimmer effect while preparing sensor
          return Shimmer.fromColors(
            baseColor: Colors.grey.shade400.withValues(alpha: 0.3),
            highlightColor: Colors.grey.shade100.withValues(alpha: 0.6),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: compassSize,
                    height: compassSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        // Dial (Fixed)
                        SvgPicture.asset(
                          'assets/images/qibla_compass.svg',
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                          fit: BoxFit.contain,
                        ),
                        // Kaaba (Fixed at top)
                        SvgPicture.asset(
                          'assets/images/qibla_kaaba.svg',
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                          fit: BoxFit.contain,
                        ),
                        // Needle (Static in placeholder)
                        SvgPicture.asset(
                          'assets/images/qibla_needle.svg',
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ),
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

        final qiblahDirection = snapshot.data!;
        
        // Exact angle rotation math from reference project (handling shortest path with AnimatedRotation)
        final double turns = (qiblahDirection.qiblah * -1) / 360.0;

        // Alignment logic (within 1.5 degrees)
        bool isAligned = qiblahDirection.qiblah.abs() <= 1.5 || (360 - qiblahDirection.qiblah.abs()) <= 1.5;

        // Trigger haptic feedback when entering aligned state
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
                  SizedBox(
                    width: compassSize,
                    height: compassSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        // 1. Dial (Static)
                        SvgPicture.asset(
                          'assets/images/qibla_compass.svg',
                          colorFilter: ColorFilter.mode(
                            currentColor,
                            BlendMode.srcIn,
                          ),
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
                            colorFilter: ColorFilter.mode(
                              currentColor,
                              BlendMode.srcIn,
                            ),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  Container(
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
                  ),
                ],
              ),
            );
          },
        );
      },
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
