import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:adhan/adhan.dart';
import '../utils/logger.dart';
import 'athan_player_service.dart';
import 'prayer_widget_service.dart';

class BackgroundAthanService {
  static BackgroundAthanService? _instance;
  static BackgroundAthanService get instance => _instance ??= BackgroundAthanService._();

  BackgroundAthanService._();

  static const int _athanNotificationId = 1001;
  
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  Timer? _prayerCheckTimer;
  Timer? _widgetUpdateTimer;
  bool _isInitialized = false;
  
  // Track triggered prayers to prevent multiple notifications
  final Map<String, DateTime> _triggeredPrayers = {};

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      Logger.info('Initializing BackgroundAthanService...');
      
      // Initialize notifications
      await _initializeNotifications();
      
      // Start prayer time monitoring
      _startPrayerTimeMonitoring();
      
      // Start widget updates
      _startWidgetUpdates();
      
      // Initialize widget service
      await PrayerWidgetService.instance.initialize();
      
      _isInitialized = true;
      Logger.success('BackgroundAthanService initialized successfully');
    } catch (e) {
      Logger.error('Failed to initialize BackgroundAthanService: $e');
      // Continue without background service
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

  Future<void> requestPermissions() async {
    try {
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
    } catch (e) {
      Logger.warning('Permission request failed: $e');
      // Continue without permissions if denied
    }
  }

  void _startPrayerTimeMonitoring() {
    // Check every 10 seconds for more precise prayer times
    _prayerCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkPrayerTimes();
      // Clean old triggered prayers (older than 1 hour)
      _cleanOldTriggeredPrayers();
    });
  }

  void _cleanOldTriggeredPrayers() {
    final now = DateTime.now();
    final toRemove = <String>[];
    
    for (final entry in _triggeredPrayers.entries) {
      if (now.difference(entry.value).inHours > 1) {
        toRemove.add(entry.key);
      }
    }
    
    for (final key in toRemove) {
      _triggeredPrayers.remove(key);
    }
  }

  void _startWidgetUpdates() {
    // Update widget every 15 minutes
    _widgetUpdateTimer = Timer.periodic(const Duration(minutes: 15), (timer) {
      PrayerWidgetService.instance.updateWidgetNow();
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
        final prayerName = prayer['name'] as String;
        final prayerTime = prayer['time'] as DateTime;
        final timeDiff = prayerTime.difference(now);

        // Log for debugging
        Logger.info('Checking $prayerName: prayerTime=$prayerTime, now=$now, diff=${timeDiff.inSeconds}s');

        // Check if prayer time is exactly now (within 5 seconds tolerance)
        if (timeDiff.inSeconds >= 0 && timeDiff.inSeconds <= 5) {
          // Check if this prayer was already triggered recently
          final lastTriggered = _triggeredPrayers[prayerName];
          if (lastTriggered != null) {
            final timeSinceTriggered = now.difference(lastTriggered);
            if (timeSinceTriggered.inMinutes < 5) {
              Logger.info('$prayerName already triggered ${timeSinceTriggered.inMinutes} minutes ago, skipping');
              continue;
            }
          }
          
          Logger.info('Triggering athan for $prayerName at exact time');
          _triggeredPrayers[prayerName] = now;
          await _triggerAthanNotification(prayerName);
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
      await _playAthanSound(prayerName);
      
      // Update widget after athan
      await PrayerWidgetService.instance.updateWidgetNow();
      
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

  Future<void> _playAthanSound(String prayerName) async {
    try {
      await AthanPlayerService.instance.playAthan(prayerName: prayerName);
    } catch (e) {
      Logger.error('Error playing athan sound: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse notificationResponse) {
    Logger.info('Athan notification tapped');
    // Handle notification tap if needed
  }

  Future<void> scheduleTestNotification() async {
    // Simple test notification
    await _notifications.show(
      999,
      'Test Athan Notification',
      'This is a test notification for athan',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test Notification',
          channelDescription: 'Test notification channel',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  void dispose() {
    _prayerCheckTimer?.cancel();
    _widgetUpdateTimer?.cancel();
    PrayerWidgetService.instance.dispose();
    _isInitialized = false;
  }
}
