import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:adhan/adhan.dart';
import 'package:timezone/timezone.dart' as tz;
import '../utils/logger.dart';
import 'athan_player_service.dart';

class BackgroundAthanService {
  static BackgroundAthanService? _instance;
  static BackgroundAthanService get instance => _instance ??= BackgroundAthanService._();

  BackgroundAthanService._();

  static const String _athanAlarmId = 'athan_alarm';
  static const int _athanNotificationId = 1001;
  
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  Timer? _prayerCheckTimer;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      Logger.info('Initializing BackgroundAthanService...');
      
      // Initialize notifications
      await _initializeNotifications();
      
      // Request permissions
      await _requestPermissions();
      
      // Start prayer time monitoring
      _startPrayerTimeMonitoring();
      
      _isInitialized = true;
      Logger.success('BackgroundAthanService initialized successfully');
    } catch (e) {
      Logger.error('Error initializing BackgroundAthanService: $e');
    }
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  Future<void> _requestPermissions() async {
    // Request notification permissions
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Request exact alarm permission for Android 12+
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
  }

  void _startPrayerTimeMonitoring() {
    // Check every minute for prayer times
    _prayerCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkPrayerTimes();
    });
  }

  Future<void> _checkPrayerTimes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      
      if (!notificationsEnabled) return;

      final location = await _getCurrentLocation();
      if (location == null) return;

      final now = DateTime.now();
      final date = DateComponents(now.year, now.month, now.day);
      final coordinates = Coordinates(location.latitude, location.longitude);
      final params = _getCalculationParams(prefs);
      final prayerTimes = PrayerTimes(coordinates, date, params);
      final prayers = [
        {'name': 'Fajr', 'time': prayerTimes.fajr},
        {'name': 'Dhuhr', 'time': prayerTimes.dhuhr},
        {'name': 'Asr', 'time': prayerTimes.asr},
        {'name': 'Maghrib', 'time': prayerTimes.maghrib},
        {'name': 'Isha', 'time': prayerTimes.isha},
      ];

      for (final prayer in prayers) {
        final prayerTime = prayer['time'] as DateTime;
        final timeDiff = prayerTime.difference(now);

        // Check if prayer time is within the next minute
        if (timeDiff.inSeconds >= 0 && timeDiff.inSeconds <= 60) {
          await _triggerAthanNotification(prayer['name'] as String);
        }
      }
    } catch (e) {
      Logger.error('Error checking prayer times: $e');
    }
  }

  Future<Position?> _getCurrentLocation() async {
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

  CalculationParameters _getCalculationParams(SharedPreferences prefs) {
    // Create basic calculation parameters (Egyptian method)
    return CalculationParameters(
      fajrAngle: 19.5,
      ishaAngle: 17.5,
    );
  }

  Future<void> _triggerAthanNotification(String prayerName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final athanMuted = prefs.getBool('athan_muted') ?? false;
      
      if (athanMuted) {
        Logger.info('Athan is muted, skipping notification for $prayerName');
        return;
      }

      final athanSound = prefs.getString('athan_sound') ?? 'default';
      
      // Show notification
      await _showAthanNotification(prayerName, athanSound);
      
      // Play athan sound
      await _playAthanSound(athanSound);
      
      Logger.info('Triggered athan for $prayerName');
    } catch (e) {
      Logger.error('Error triggering athan notification: $e');
    }
  }

  Future<void> _showAthanNotification(String prayerName, String athanSound) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'athan_channel',
      'أذان الصلاة',
      channelDescription: 'إشعارات أذان الصلاة',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
    );

    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notifications.show(
      _athanNotificationId,
      'حان الآن صلاة $prayerName',
      'حان الآن موعد صلاة $prayerName، حي على الصلاة',
      platformChannelSpecifics,
    );
  }

  Future<void> _playAthanSound(String athanSound) async {
    try {
      await AthanPlayerService.instance.playAthan(athanSound);
    } catch (e) {
      Logger.error('Error playing athan sound: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse notificationResponse) {
    Logger.info('Athan notification tapped');
    // Handle notification tap if needed
  }

  Future<void> scheduleTestNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'test_channel',
      'Test Notification',
      channelDescription: 'Test notification channel',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notifications.zonedSchedule(
      0,
      'Test Athan Notification',
      'This is a test notification for athan',
      tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
      platformChannelSpecifics,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  void dispose() {
    _prayerCheckTimer?.cancel();
    _isInitialized = false;
  }
}
