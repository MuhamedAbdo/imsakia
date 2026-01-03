import 'dart:async';
import 'package:home_widget/home_widget.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:adhan/adhan.dart';
import '../utils/logger.dart';

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      Logger.info('Widget background task started');
      
      // Update widget data
      await PrayerWidgetService._updateWidgetData();
      
      Logger.success('Widget background task completed');
      return Future.value(true);
    } catch (e) {
      Logger.error('Widget background task failed: $e');
      return Future.value(false);
    }
  });
}

class PrayerWidgetService {
  static PrayerWidgetService? _instance;
  static PrayerWidgetService get instance => _instance ??= PrayerWidgetService._();

  PrayerWidgetService._();

  static const String widgetId = 'prayer_widget';
  static const String updateTask = 'widgetUpdateTask';

  Future<void> initialize() async {
    try {
      Logger.info('Initializing PrayerWidgetService...');
      
      // Initialize workmanager
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: true,
      );
      
      // Register periodic task (every 15 minutes)
      await Workmanager().registerPeriodicTask(
        '1',
        updateTask,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresBatteryNotLow: false,
        ),
      );
      
      // Initial widget update
      await _updateWidgetData();
      
      Logger.success('PrayerWidgetService initialized successfully');
    } catch (e) {
      Logger.error('Failed to initialize PrayerWidgetService: $e');
      // Continue even if workmanager fails - widget can still be updated manually
    }
  }

  static Future<void> _updateWidgetData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get current location
      final position = await _getCurrentLocation();
      if (position == null) {
        Logger.warning('No location available, using default data');
        // Set default data when no location is available
        await _setDefaultWidgetData(prefs);
        return;
      }

      // Calculate prayer times
      final now = DateTime.now();
      final coordinates = Coordinates(position.latitude, position.longitude);
      final params = _getCalculationParams(prefs);
      final date = DateComponents(now.year, now.month, now.day);
      final prayerTimes = PrayerTimes(coordinates, date, params);

      // Get next prayer
      final nextPrayer = await _getNextPrayer(prayerTimes, now);
      
      // Get Hijri date (simplified version)
      final hijriDateString = _getHijriDateString(now);

      // Save to SharedPreferences for Android widget
      await prefs.setString('flutter.nextPrayer', nextPrayer['name'] ?? 'الظهر');
      await prefs.setString('flutter.timeUntil', _formatTimeUntil(nextPrayer['timeUntil']));
      await prefs.setString('flutter.hijriDate', hijriDateString);

      // Update Flutter widget
      await HomeWidget.saveWidgetData('prayer_widget', {
        'nextPrayer': nextPrayer['name'],
        'timeUntil': _formatTimeUntil(nextPrayer['timeUntil']),
        'hijriDate': hijriDateString,
        'lastUpdate': now.toIso8601String(),
      });
      await HomeWidget.updateWidget();
      
      Logger.info('Widget data updated successfully');
      Logger.info('Next prayer: ${nextPrayer['name']}, Time until: ${_formatTimeUntil(nextPrayer['timeUntil'])}');
    } catch (e) {
      Logger.error('Error updating widget data: $e');
      // Set default data on error
      final prefs = await SharedPreferences.getInstance();
      await _setDefaultWidgetData(prefs);
    }
  }

  static Future<void> _setDefaultWidgetData(SharedPreferences prefs) async {
    final now = DateTime.now();
    final hijriDateString = _getHijriDateString(now);
    
    await prefs.setString('flutter.nextPrayer', 'الظهر');
    await prefs.setString('flutter.timeUntil', 'جاري التحديث...');
    await prefs.setString('flutter.hijriDate', hijriDateString);

    // Update Flutter widget
    await HomeWidget.saveWidgetData('prayer_widget', {
      'nextPrayer': 'الظهر',
      'timeUntil': 'جاري التحديث...',
      'hijriDate': hijriDateString,
      'lastUpdate': now.toIso8601String(),
    });
    await HomeWidget.updateWidget();
    
    Logger.info('Default widget data set');
  }

  static Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      Logger.error('Error getting location: $e');
      return null;
    }
  }

  static CalculationParameters _getCalculationParams(SharedPreferences prefs) {
    return CalculationParameters(
      fajrAngle: 19.5,
      ishaAngle: 17.5,
    );
  }

  static Future<Map<String, dynamic>> _getNextPrayer(PrayerTimes prayerTimes, DateTime now) async {
    final prayers = [
      {'name': 'الفجر', 'time': prayerTimes.fajr},
      {'name': 'الظهر', 'time': prayerTimes.dhuhr},
      {'name': 'العصر', 'time': prayerTimes.asr},
      {'name': 'المغرب', 'time': prayerTimes.maghrib},
      {'name': 'العشاء', 'time': prayerTimes.isha},
    ];

    DateTime? nextPrayerTime;
    String? nextPrayerName;

    for (final prayer in prayers) {
      final prayerTime = prayer['time'] as DateTime;
      if (prayerTime.isAfter(now)) {
        nextPrayerTime = prayerTime;
        nextPrayerName = prayer['name'] as String;
        break;
      }
    }

    // If no prayer found today, get tomorrow's Fajr
    if (nextPrayerTime == null) {
      final tomorrow = now.add(const Duration(days: 1));
      final tomorrowDate = DateComponents(tomorrow.year, tomorrow.month, tomorrow.day);
      final prefs = await SharedPreferences.getInstance();
      final tomorrowPrayers = PrayerTimes(
        Coordinates(0, 0), // Will be updated with actual location
        tomorrowDate,
        _getCalculationParams(prefs),
      );
      nextPrayerTime = tomorrowPrayers.fajr;
      nextPrayerName = 'الفجر';
    }

    final timeUntil = nextPrayerTime.difference(now);

    return {
      'name': nextPrayerName,
      'time': nextPrayerTime,
      'timeUntil': timeUntil,
    };
  }

  static String _formatTimeUntil(Duration duration) {
    if (duration.inHours > 0) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return '$hours ساعة $minutes دقيقة';
    } else {
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds % 60;
      return '$minutes دقيقة $seconds ثانية';
    }
  }

  static String _getHijriDateString(DateTime dateTime) {
    // Simplified Hijri date calculation (approximate)
    // In a real app, you would use a proper Hijri calendar library
    final hijriOffset = dateTime.difference(DateTime(2023, 7, 18)).inDays; // Approximate offset
    final hijriDay = (hijriOffset % 30) + 1;
    final hijriMonth = ((hijriOffset ~/ 30) % 12) + 1;
    final hijriYear = 1444 + (hijriOffset ~/ 360);
    
    const months = [
      'محرم', 'صفر', 'ربيع الأول', 'ربيع الثاني', 'جمادى الأولى', 'جمادى الثانية',
      'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة'
    ];
    
    return '$hijriDay ${months[hijriMonth - 1]} $hijriYear هـ';
  }

  Future<void> updateWidgetNow() async {
    await _updateWidgetData();
  }

  void dispose() {
    Workmanager().cancelAll();
  }
}
