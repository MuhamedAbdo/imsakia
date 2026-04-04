import 'dart:io';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:ui';

@pragma('vm:entry-point')
class AthanService {
  @pragma('vm:entry-point')
  static void athanCallback() async {
    // 1. Ensure isolate and bindings are ready
    try {
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();
      // Force the CPU to wake up immediately
      await WakelockPlus.enable();
    } catch (e) {
      print("Failed to initialize bindings/wakelock: $e");
    }
    
    // 2. Logging Setup (Fallback to Print if File Fails)
    File? logFile;
    try {
      logFile = await _getLogFile();
      await _writeLog(logFile, "--- [Background] Athan Isolate Started ---");
    } catch (e) {
      print("Logger failed: $e");
    }

    final FlutterLocalNotificationsPlugin notificationsPlugin =
        FlutterLocalNotificationsPlugin();

    // 3. Initialize Notifications
    try {
      await _writeLog(logFile, "Step: Initializing notifications...");
      await notificationsPlugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
    } catch (e) {
      await _writeLog(logFile, "Error in notifications init: $e");
    }

    // 4. Play Athan Audio
    try {
      await _writeLog(logFile, "Step: Configuring AudioSession for Alarm...");
      
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.sonification,
          usage: AndroidAudioUsage.alarm,
        ),
      ));

      await _writeLog(logFile, "Step: Loading audio source from LOCAL path...");
      final player = AudioPlayer();
      await player.setVolume(1.0);

      // Look for the local file copied in main()
      final directory = await getApplicationDocumentsDirectory();
      final localPath = '${directory.path}/athan_makkah.mp3';
      final audioFile = File(localPath);

      if (await audioFile.exists()) {
        await _writeLog(logFile, "Success: Local audio found at $localPath");
        await player.setAudioSource(AudioSource.file(localPath));
      } else {
        await _writeLog(logFile, "Warning: Local audio NOT found. Falling back to asset.");
        await player.setAudioSource(
          AudioSource.uri(Uri.parse('asset:///assets/audio/athan_makkah.mp3'))
        );
      }
      
      await _writeLog(logFile, "Step: Audio loaded. Starting playback...");
      player.play();
    } catch (e) {
      await _writeLog(logFile, "Error in audio playback: $e");
    }

    // 5. Show Full Screen Notification (The Wake-up Call)
    try {
      await _writeLog(logFile, "Step: Displaying Full Screen Intent notification...");
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'athan_v14_final_channel',
        'Athan Alarm',
        channelDescription: 'Prayer time alerts that wake the screen',
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true, // This triggers the MainActivity launch
        category: AndroidNotificationCategory.alarm,
        ongoing: true,
        autoCancel: false,
        visibility: NotificationVisibility.public,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );

      await notificationsPlugin.show(
        id: 1111,
        title: '🕌 حان وقت الأذان',
        body: 'الله أكبر، الله أكبر',
        notificationDetails: const NotificationDetails(android: androidDetails),
        payload: 'athan_critical_payload',
      );
      await _writeLog(logFile, "Step: Success - Screen wake intent sent.");
    } catch (e) {
      await _writeLog(logFile, "Error in notification display: $e");
    }
  }

  static Future<String> readLogs() async {
    try {
      final file = await _getLogFile();
      if (await file.exists()) {
        return await file.readAsString();
      }
      return "Log file empty or not found.";
    } catch (e) {
      return "Error reading log: $e";
    }
  }

  static Future<void> clearLogs() async {
    try {
      final file = await _getLogFile();
      if (await file.exists()) {
        await file.writeAsString("");
      }
    } catch (e) {
      print("Error clearing log: $e");
    }
  }

  static Future<File> _getLogFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/athan_log.txt');
  }

  static Future<void> _writeLog(File? file, String message) async {
    if (file == null) return;
    final timestamp = DateTime.now().toString();
    await file.writeAsString('[$timestamp] $message\n', mode: FileMode.append);
  }
}
