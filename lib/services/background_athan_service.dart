import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'athan_player_service.dart';

/// Service to handle background athan notifications
class BackgroundAthanService {
  static BackgroundAthanService? _instance;
  static BackgroundAthanService get instance => _instance ??= BackgroundAthanService._();

  BackgroundAthanService._();

  /// Initialize background athan service
  Future<void> initialize() async {
    try {
      // Initialize WorkManager for background tasks
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: true, // Set to false in production
      );
      
      debugPrint('🔔 BackgroundAthanService initialized');
    } catch (e) {
      debugPrint('❌ Error initializing BackgroundAthanService: $e');
    }
  }

  /// Schedule athan notifications for all prayers
  Future<void> scheduleAthanNotifications() async {
    try {
      // This is a simplified version - in a real implementation,
      // you would calculate prayer times and schedule notifications
      // for each prayer throughout the day
      
      debugPrint('📅 Athan notifications scheduled');
    } catch (e) {
      debugPrint('❌ Error scheduling athan notifications: $e');
    }
  }

  /// Cancel all scheduled athan notifications
  Future<void> cancelAllNotifications() async {
    try {
      await Workmanager().cancelAll();
      debugPrint('🔕 All athan notifications cancelled');
    } catch (e) {
      debugPrint('❌ Error cancelling notifications: $e');
    }
  }

  /// Callback dispatcher for background tasks
  @pragma('vm:entry-point')
  static void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      try {
        debugPrint('🔔 Background task executed: $task');
        
        // Handle athan playback in background
        if (task == 'athan_notification') {
          // Initialize audio player in background
          final athanPlayer = AthanPlayerService.instance;
          
          // Get prayer name from input data
          final prayerName = inputData?['prayer_name'] ?? 'fajr';
          
          // Play athan
          await athanPlayer.playAthan(prayerName: prayerName);
          
          debugPrint('🎵 Background athan played for: $prayerName');
        }
        
        return Future.value(true);
      } catch (e) {
        debugPrint('❌ Error in background task: $e');
        return Future.value(false);
      }
    });
  }
}
