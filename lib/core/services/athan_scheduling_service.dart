import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import '../models/location_model.dart';
import '../models/prayer_times_model.dart';
import '../models/settings_model.dart';
import 'prayer_times_service.dart';

class AthanSchedulingService {
  static const MethodChannel _athanChannel = MethodChannel('imsakia/athan_control');

  /// Schedules Athan for the next [daysToSchedule] days.
  static Future<void> scheduleFutureAthans({int daysToSchedule = 7}) async {
    final prefs = await SharedPreferences.getInstance();
    
    final settingsRaw = prefs.getString('settings');
    if (settingsRaw == null) return;
    
    final settings = SettingsModel.fromJson(jsonDecode(settingsRaw) as Map<String, dynamic>);
    
    if (!settings.athanEnabled) {
      await cancelAllAthans();
      return;
    }

    final locationRaw = prefs.getString('last_location');
    if (locationRaw == null) return;
    final location = LocationModel.fromJson(jsonDecode(locationRaw) as Map<String, dynamic>);

    final prayerService = PrayerTimesService();
    final now = DateTime.now();

    // Clear existing exact alarms first to prevent duplicates
    await cancelAllAthans();

    int notificationIdBase = 1000;

    for (int i = 0; i < daysToSchedule; i++) {
      final targetDate = now.add(Duration(days: i));
      final times = prayerService.calculate(location, settings.calculationMethod, date: targetDate);

      for (final prayer in times.toList()) {
        if (prayer.time.isBefore(now)) continue;

        // Imsak and Sunrise do not have Athan Audio
        if (prayer.name == Prayer.imsak || prayer.name == Prayer.sunrise) continue;

        final uniqueId = notificationIdBase + (i * 10) + prayer.name.index;
        
        final prayerImage = _resolvePrayerHeaderAsset(prayer.name);
        String assetPath = "assets/audio/athan_egypt_ab.mp3"; // Default fallback
        if (settings.athanSoundEnabled) {
          assetPath = _resolveAthanAssetPath(prayer.name, settings);
        } else {
          // If silent Athan in settings, we don't schedule a native Audio alarm?
          // The user specifically requested native Audio control. We'll still schedule 
          // the notification, but NativeAudioController will play it.
          // For now, if athanSoundEnabled is false, we might want to schedule just FLN.
          // But to keep it simple, if no sound needed, we can pass an empty audio path or skip.
          if (!settings.notificationsEnabled) continue;
        }

        // 1. DART LEVEL SCHEDULE (For HeadsUp/UI if needed, though Native handles this mostly now)
        // With Native AlarmManager taking full control, FLN zonedSchedule is optional but good for backup.
        // Actually, AthanTriggerReceiver ALREADY posts the exact Full-Screen Notification.
        // So we strictly ONLY need the Native AlarmManager for 100% reliability without duplicate notifications!
        
        // Let's schedule exclusively native to guarantee no double notifications!
        try {
          await _athanChannel.invokeMethod('scheduleAthanAlarm', {
            'id': uniqueId,
            'timeMs': prayer.time.millisecondsSinceEpoch,
            'prayerAr': prayer.name.nameAr,
            'prayerEn': prayer.name.nameEn,
            'assetPath': assetPath,
            'prayerImage': prayerImage,
          });
          developer.log('Scheduled exact native Athan for ${prayer.name.nameAr} at ${prayer.time}');
        } catch (e) {
          developer.log('Failed to schedule native exact alarm: $e');
        }
      }
    }
  }

  static Future<void> cancelAllAthans() async {
    try {
      // Loop over possible ID range to cancel them. Alternatively, Native should track them.
      // Easiest is to cancel 1000 to 1100
      for (int i = 1000; i < 1100; i++) {
        await _athanChannel.invokeMethod('cancelAthanAlarm', {'id': i});
      }
      developer.log('All native Athan alarms cancelled.');
    } catch (e) {
      developer.log('Failed to cancel native alarms: $e');
    }
  }

  static String _resolveAthanAssetPath(Prayer prayer, SettingsModel settings) {
    if (prayer == Prayer.fajr) {
      return settings.selectedFajrSound;
    }
    return settings.selectedAthanSound;
  }

  static String _resolvePrayerHeaderAsset(Prayer prayer) {
    switch (prayer) {
      case Prayer.fajr: return 'assets/images/headers/fajr.png';
      case Prayer.sunrise: return 'assets/images/headers/sunrise.png';
      case Prayer.dhuhr: return 'assets/images/headers/dhuhr.png';
      case Prayer.asr: return 'assets/images/headers/asr.png';
      case Prayer.maghrib: return 'assets/images/headers/maghrib.png';
      case Prayer.isha: return 'assets/images/headers/isha.png';
      default: return 'assets/images/headers/fajr.png';
    }
  }
}
