import 'dart:io';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

@pragma('vm:entry-point')
class AthanService {
  static AudioPlayer? _player;

  @pragma('vm:entry-point')
  static void athanCallback() async {
    // 1. Force the CPU to wake up IMMEDIATELY (Priority 1)
    try {
      await WakelockPlus.enable();
    } catch (_) {
    }

    // 2. Clear pre-existing audio if any (Double Athan protection)
    if (_player != null) {
      try {
        await _player!.stop();
        await _player!.dispose();
        _player = null;
      } catch (_) {
        // Silently fail as it's just cleanup
      }
    }

    // 3. Ensure isolate and bindings are ready
    try {
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();
    } catch (_) {
    }
    
    // 4. Logging Setup
    File? logFile;
    try {
      logFile = await _getLogFile();
      await _writeLog(logFile, "--- [Background] Athan Isolate Started ---");
    } catch (_) {
    }

    final FlutterLocalNotificationsPlugin notificationsPlugin =
        FlutterLocalNotificationsPlugin();

    // 5. Initialize Notifications
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

    // 6. SHOW EMERGENCY NOTIFICATION (Native Bridge for Strict Flags)
    try {
      await _writeLog(logFile, "Step: Invoking Native Emergency Notification...");
      const nativeChannel = MethodChannel('imsakia/notifications');
      await nativeChannel.invokeMethod('showNativeEmergencyNotification', {
        'title': '🕌 حان وقت الأذان',
        'body': 'الله أكبر، الله أكبر',
      });
      await _writeLog(logFile, "Step: Success - Native Emergency Notification triggered.");
    } catch (e) {
      await _writeLog(logFile, "Error in native notification: $e");
    }

    // 7. Play Athan Audio IMMEDIATELY (Backup Isolate Playback)
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
      await session.setActive(true);

      await _writeLog(logFile, "Step: Loading audio source from LOCAL path...");
      _player = AudioPlayer();
      await _player!.setVolume(1.0);
      await _player!.setLoopMode(LoopMode.off);

      // Look for the local file copied in main()
      final directory = await getApplicationDocumentsDirectory();
      final localPath = '${directory.path}/athan_makkah.mp3';
      final audioFile = File(localPath);

      if (await audioFile.exists()) {
        await _writeLog(logFile, "Success: Local audio found at $localPath");
        await _player!.setAudioSource(AudioSource.file(localPath));
      } else {
        await _writeLog(logFile, "Warning: Local audio NOT found. Falling back to asset.");
        await _player!.setAudioSource(
          AudioSource.uri(Uri.parse('asset:///assets/audio/athan_makkah.mp3'))
        );
      }
      
      await _writeLog(logFile, "Step: Audio loaded. Starting playback...");
      await _player!.play();
      
      // Cleanup after playback finishes
      try {
        await _player?.stop();
        await _player?.dispose();
        _player = null;
      } catch (_) {
        // Silently fail
      }
      
      // Clean up the 777 test alarm
      await AndroidAlarmManager.cancel(777);
      await _writeLog(logFile, "Step: Playback finished and cleanup complete.");
    } catch (e) {
      await _writeLog(logFile, "Error in audio playback block: $e");
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
    } catch (_) {
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
