import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:adhan/adhan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_constants.dart';

class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance =>
      _instance ??= NotificationService._();

  NotificationService._();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _prayerChannelId = 'prayer_times_channel';
  static const String _prayerChannelName = 'مواقيت الصلاة';
  static const String _prayerChannelDescription =
      'إشعارات مواقيت الصلاة اليومية';

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();

    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    await _createNotificationChannel();

    _initialized = true;
    debugPrint('✅ NotificationService initialized');
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _prayerChannelId,
      _prayerChannelName,
      description: _prayerChannelDescription,
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('notification'),
      enableVibration: true,
      playSound: true,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    debugPrint('✅ Notification channel created: $_prayerChannelId');
  }

  Future<bool> requestNotificationPermission() async {
    try {
      // Request Android notification permission
      if (await Permission.notification.request().isGranted) {
        debugPrint('✅ Notification permission granted');
        return true;
      } else {
        debugPrint('❌ Notification permission denied');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error requesting notification permission: $e');
      return false;
    }
  }

  Future<void> schedulePrayerNotifications() async {
    try {
      debugPrint('🔄 Starting prayer notification scheduling...');

      // Cancel all existing notifications first
      await cancelAllNotifications();

      // Schedule notifications for the next 7 days
      for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
        final targetDate = DateTime.now().add(Duration(days: dayOffset));
        final dateComponents = DateComponents(
          targetDate.year,
          targetDate.month,
          targetDate.day,
        );

        // Get prayer times for this specific date
        await _scheduleNotificationsForDate(dateComponents, dayOffset);
      }

      debugPrint('✅ Prayer notifications scheduled for 7 days');
    } catch (e) {
      debugPrint('❌ Error scheduling prayer notifications: $e');
    }
  }

  Future<void> _scheduleNotificationsForDate(
    DateComponents date,
    int dayOffset,
  ) async {
    // Get location from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final selectedCityId =
        prefs.getString(AppConstants.selectedCityKey) ??
        AppConstants.defaultCity;

    final city = AppConstants.cities.firstWhere(
      (city) => city['id'] == selectedCityId,
      orElse: () => AppConstants.cities.first,
    );

    final coordinates = Coordinates(city['latitude'], city['longitude']);

    // Read user settings
    final calculationMethod =
        prefs.getString(AppConstants.calculationMethodKey) ??
        AppConstants.defaultCalculationMethod;
    final madhab =
        prefs.getString(AppConstants.madhabKey) ?? AppConstants.defaultMadhab;
    final dstEnabled =
        prefs.getBool(AppConstants.dstKey) ?? AppConstants.defaultDST;

    // Get calculation parameters
    CalculationParameters params;
    switch (calculationMethod) {
      case 'egyptian':
        params = CalculationMethod.egyptian.getParameters();
        break;
      case 'karachi':
        params = CalculationMethod.karachi.getParameters();
        break;
      case 'umm_al_qura':
        params = CalculationMethod.umm_al_qura.getParameters();
        break;
      case 'muslim_world_league':
        params = CalculationMethod.muslim_world_league.getParameters();
        break;
      case 'north_america':
        params = CalculationMethod.north_america.getParameters();
        break;
      default:
        params = CalculationMethod.egyptian.getParameters();
    }

    params.madhab = madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;

    final prayerTimes = PrayerTimes(coordinates, date, params);

    // Apply DST offset
    final dstOffset = dstEnabled ? const Duration(hours: 1) : Duration.zero;

    final prayers = [
      {'name': 'الفجر', 'time': prayerTimes.fajr.add(dstOffset), 'id': 100},
      {'name': 'الشروق', 'time': prayerTimes.sunrise.add(dstOffset), 'id': 101},
      {'name': 'الظهر', 'time': prayerTimes.dhuhr.add(dstOffset), 'id': 102},
      {'name': 'العصر', 'time': prayerTimes.asr.add(dstOffset), 'id': 103},
      {'name': 'المغرب', 'time': prayerTimes.maghrib.add(dstOffset), 'id': 104},
      {'name': 'العشاء', 'time': prayerTimes.isha.add(dstOffset), 'id': 105},
    ];

    for (final prayer in prayers) {
      final scheduledTime = prayer['time'] as DateTime;
      final prayerName = prayer['name'] as String;
      final notificationId = (prayer['id'] as int) + (dayOffset * 100);

      // Only schedule if the time is in the future
      if (scheduledTime.isAfter(DateTime.now())) {
        await _scheduleNotification(
          id: notificationId,
          title: 'حان وقت صلاة $prayerName',
          body: 'حان الآن وقت صلاة $prayerName في ${city['name']}',
          scheduledTime: scheduledTime,
          prayerName: prayerName,
        );

        debugPrint('📅 Scheduled $prayerName for ${scheduledTime.toString()}');
      }
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String prayerName,
  }) async {
    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _prayerChannelId,
            _prayerChannelName,
            channelDescription: _prayerChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
            sound: RawResourceAndroidNotificationSound('notification'),
            icon: '@mipmap/ic_launcher',
            largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            styleInformation: BigTextStyleInformation(
              body,
              htmlFormatBigText: true,
              contentTitle: title,
              htmlFormatContentTitle: true,
            ),
            enableVibration: true,
            playSound: true,
            color: const Color(0xFF1E88E5),
            ledColor: const Color(0xFF1E88E5),
            ledOnMs: 1000,
            ledOffMs: 500,
            autoCancel: true,
            ongoing: false,
            silent: false,
            category: AndroidNotificationCategory.reminder,
            visibility: NotificationVisibility.public,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'notification.aiff',
            badgeNumber: 1,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('❌ Error scheduling notification $id: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      debugPrint('🗑️ All notifications cancelled');
    } catch (e) {
      debugPrint('❌ Error cancelling notifications: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(id);
      debugPrint('🗑️ Notification $id cancelled');
    } catch (e) {
      debugPrint('❌ Error cancelling notification $id: $e');
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _flutterLocalNotificationsPlugin
          .pendingNotificationRequests();
    } catch (e) {
      debugPrint('❌ Error getting pending notifications: $e');
      return [];
    }
  }

  static void _onNotificationTapped(NotificationResponse notificationResponse) {
    debugPrint('🔔 Notification tapped: ${notificationResponse.payload}');
    // Handle notification tap if needed
  }

  Future<bool> areNotificationsEnabled() async {
    try {
      final status = await Permission.notification.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('❌ Error checking notification status: $e');
      return false;
    }
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('❌ Error checking battery optimization status: $e');
      return false;
    }
  }

  Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('❌ Error requesting battery optimization permission: $e');
      return false;
    }
  }

  Future<void> openBatteryOptimizationSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      debugPrint('❌ Error opening battery optimization settings: $e');
    }
  }

  Future<void> openNotificationSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      debugPrint('❌ Error opening notification settings: $e');
    }
  }
}
