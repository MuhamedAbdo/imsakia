import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:just_audio/just_audio.dart' as ja;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/prayer_times_service.dart';

/// Internal model representing a scheduled Athan event on Windows.
class _ScheduledAthanEvent {
  final int id;
  final String prayerKey;
  final String prayerArabicName;
  final DateTime scheduledTime;
  final bool isTest;

  const _ScheduledAthanEvent({
    required this.id,
    required this.prayerKey,
    required this.prayerArabicName,
    required this.scheduledTime,
    this.isTest = false,
  });
}

/// Independent Windows Desktop Athan Engine.
///
/// Handles:
/// - Reliable background in-process scheduling and audio playback while hidden in System Tray.
/// - Sleep / resume and clock-change detection with automatic recalculation and rescheduling.
/// - Missed event protection (never plays missed Athan events retroactively).
/// - 3-Minute Quick Athan Test with strict scheduling identity isolation.
/// - Robust dual-layer audio playback (primary audioplayers + just_audio fallback) with local file extraction.
/// - Native Windows Toast Notifications.
class WindowsAthanService with ChangeNotifier {
  WindowsAthanService._();
  static final WindowsAthanService instance = WindowsAthanService._();

  static const int testEventId = -999;
  static const String _prefEnabled = 'athan_enabled';

  final ap.AudioPlayer _audioPlayer = ap.AudioPlayer();
  final ja.AudioPlayer _justAudioPlayer = ja.AudioPlayer();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Scheduled prayer events map: id -> event
  final Map<int, _ScheduledAthanEvent> _scheduledPrayers = {};

  // Quick Athan Test isolated state
  _ScheduledAthanEvent? _pendingTestEvent;

  // Heartbeat & scheduling timers
  Timer? _heartbeatTimer;
  DateTime _lastHeartbeat = DateTime.now();

  bool _isInitialized = false;
  bool _isPlaying = false;
  String? _currentPlayingTitle;

  bool get isPlaying => _isPlaying;
  String? get currentPlayingTitle => _currentPlayingTitle;
  bool get isTestScheduled => _pendingTestEvent != null;
  DateTime? get testScheduledTime => _pendingTestEvent?.scheduledTime;

  Duration? get testRemainingDuration {
    if (_pendingTestEvent == null) return null;
    final diff = _pendingTestEvent!.scheduledTime.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  Future<void> initialize() async {
    if (!Platform.isWindows || _isInitialized) return;
    _isInitialized = true;

    // Listen to primary audio player state
    _audioPlayer.onPlayerComplete.listen((_) {
      debugPrint('[WindowsAthanService] Audio playback completed');
      _isPlaying = false;
      _currentPlayingTitle = null;
      notifyListeners();
    });

    _justAudioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ja.ProcessingState.completed) {
        _isPlaying = false;
        _currentPlayingTitle = null;
        notifyListeners();
      }
    });

    // Start precision heartbeat timer (runs every 5 seconds)
    _startHeartbeat();

    debugPrint('[WindowsAthanService] Initialized successfully');
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _lastHeartbeat = DateTime.now();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final now = DateTime.now();
      final elapsed = now.difference(_lastHeartbeat);
      _lastHeartbeat = now;

      // ── Sleep & Clock-Change Detection ─────────────────────────────────
      // If more than 20 seconds passed in a 5-second interval, the computer
      // was either in Sleep/Hibernate or the system clock jumped.
      if (elapsed.inSeconds > 20) {
        debugPrint(
          '[WindowsAthanService] Sleep / clock change detected (${elapsed.inSeconds}s drift). Triggering recovery...',
        );
        onSystemResumeOrTimeChange();
        return;
      }

      // ── Normal Schedule Tick ──────────────────────────────────────────
      _checkScheduleTick(now);
    });
  }

  /// Called whenever prayer times are calculated by [PrayerTimesService].
  /// Stores future prayer events for the given [dayOffset] (0..14).
  void onPrayerTimesCalculated(
    int dayOffset,
    Map<String, DateTime> prayerTimes,
  ) {
    if (!Platform.isWindows) return;

    final now = DateTime.now();
    final idOffset = dayOffset * 10;

    prayerTimes.forEach((key, time) {
      if (key == 'sunrise') return; // Sunrise does not have an Athan

      final int baseId = _getPrayerBaseId(key);
      final int eventId = baseId + idOffset;

      if (time.isAfter(now)) {
        _scheduledPrayers[eventId] = _ScheduledAthanEvent(
          id: eventId,
          prayerKey: key,
          prayerArabicName: _getPrayerArabicName(key),
          scheduledTime: time,
          isTest: false,
        );
      } else if (dayOffset == 0) {
        // Discard passed event for today
        _scheduledPrayers.remove(eventId);
      }
    });

    debugPrint(
      '[WindowsAthanService] Updated schedule for day $dayOffset. Total scheduled events: ${_scheduledPrayers.length}',
    );
    notifyListeners();
  }

  /// Cancels all prayer alarms (e.g. when global Athan is toggled off).
  void cancelPrayerAlarms() {
    _scheduledPrayers.clear();
    debugPrint('[WindowsAthanService] All prayer alarms cancelled');
    notifyListeners();
  }

  /// Called when the system resumes from Sleep or the clock/timezone changes.
  ///
  /// Guarantees:
  /// - Never plays missed prayer events retroactively.
  /// - Safely cancels any test event that expired during sleep.
  /// - Recalculates and schedules only valid future prayer events.
  void onSystemResumeOrTimeChange() {
    final now = DateTime.now();

    // 1. Check pending test event: if scheduled time passed during sleep, cancel it
    if (_pendingTestEvent != null) {
      if (now.isAfter(_pendingTestEvent!.scheduledTime.add(const Duration(seconds: 60)))) {
        debugPrint(
          '[WindowsAthanService] Pending test athan expired while system was asleep. Discarding.',
        );
        _pendingTestEvent = null;
      }
    }

    // 2. Discard any prayer events that are now in the past
    _scheduledPrayers.removeWhere((id, event) => event.scheduledTime.isBefore(now));

    // 3. Request fresh recalculation from PrayerTimesService for valid future times
    PrayerTimesService.instance.scheduleAllPrayers();

    notifyListeners();
  }

  /// Heartbeat tick checking if any scheduled event has arrived.
  void _checkScheduleTick(DateTime now) {
    // 1. Check isolated Quick Athan Test
    if (_pendingTestEvent != null) {
      final testTime = _pendingTestEvent!.scheduledTime;
      if (now.isAfter(testTime) || now.isAtSameMomentAs(testTime)) {
        final missedDiff = now.difference(testTime).inSeconds;
        final testToExecute = _pendingTestEvent!;
        _pendingTestEvent = null; // Clear pending state immediately

        if (missedDiff <= 60) {
          debugPrint('[WindowsAthanService] Executing scheduled Quick Test Athan');
          _executeAthan(testToExecute);
        } else {
          debugPrint(
            '[WindowsAthanService] Test event missed by ${missedDiff}s (system slept/halted). Discarding.',
          );
        }
        notifyListeners();
      } else {
        // Notify listeners so sidebar countdown updates smoothly
        notifyListeners();
      }
    }

    // 2. Check regular prayer events
    if (_scheduledPrayers.isEmpty) return;

    final eventsToTrigger = <_ScheduledAthanEvent>[];
    final expiredIds = <int>[];

    _scheduledPrayers.forEach((id, event) {
      if (now.isAfter(event.scheduledTime) || now.isAtSameMomentAs(event.scheduledTime)) {
        final missedDiff = now.difference(event.scheduledTime).inSeconds;
        if (missedDiff <= 60) {
          eventsToTrigger.add(event);
        } else {
          debugPrint(
            '[WindowsAthanService] Prayer ${event.prayerArabicName} missed by ${missedDiff}s. Discarding.',
          );
        }
        expiredIds.add(id);
      }
    });

    for (final id in expiredIds) {
      _scheduledPrayers.remove(id);
    }

    for (final event in eventsToTrigger) {
      _executeAthan(event);
    }
  }

  /// Executes Athan playback and displays Windows notification.
  Future<void> _executeAthan(_ScheduledAthanEvent event) async {
    final prefs = await SharedPreferences.getInstance();

    // Verify settings before playback for regular prayers
    if (!event.isTest) {
      final bool globalEnabled = prefs.getBool(_prefEnabled) ?? true;
      final bool prayerEnabled =
          prefs.getBool('${event.prayerKey}_athan_enabled') ?? true;

      if (!globalEnabled || !prayerEnabled) {
        debugPrint(
          '[WindowsAthanService] Athan disabled for ${event.prayerKey}, skipping playback.',
        );
        return;
      }
    }

    // Resolve audio path using selected muezzin with cloud/asset fallback
    final audioPath = await _resolveAthanAudioPath(prefs, event.prayerKey);

    await playAthan(
      path: audioPath,
      prayerKey: event.prayerKey,
      prayerName: event.prayerArabicName,
      isTest: event.isTest,
    );
  }

  /// Plays Athan audio directly through the dedicated Windows audio engine.
  Future<void> playAthan({
    String? path,
    required String prayerKey,
    required String prayerName,
    bool isTest = false,
  }) async {
    if (_isPlaying) {
      debugPrint('[WindowsAthanService] Already playing athan, ignoring duplicate call');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawPath = path ?? await _resolveAthanAudioPath(prefs, prayerKey);

      // Extract to a real local file on Windows disk (guarantees 100% reliable local playback)
      final localFilePath = await _resolveLocalAudioFile(rawPath);

      debugPrint('[WindowsAthanService] Starting playback of: $localFilePath');

      _isPlaying = true;
      _currentPlayingTitle = isTest ? 'اختبار الأذان' : 'أذان $prayerName';
      notifyListeners();

      // Show native Windows Toast Notification
      _showWindowsNotification(
        isTest: isTest,
        prayerName: prayerName,
      );

      // ── Primary Playback via audioplayers (Native Windows Media Foundation) ──
      bool primaryPlayed = false;
      try {
        await _audioPlayer.stop();
        await _audioPlayer.setVolume(1.0);
        await _audioPlayer.setReleaseMode(ap.ReleaseMode.stop);
        await _audioPlayer.play(ap.DeviceFileSource(localFilePath));
        primaryPlayed = true;
        debugPrint('[WindowsAthanService] Primary playback started successfully');
      } catch (e) {
        debugPrint('[WindowsAthanService] Primary audioplayers error: $e');
      }

      // ── Fallback Playback via just_audio if primary fails ──
      if (!primaryPlayed) {
        try {
          debugPrint('[WindowsAthanService] Attempting just_audio fallback...');
          await _justAudioPlayer.stop();
          await _justAudioPlayer.setVolume(1.0);
          await _justAudioPlayer.setFilePath(localFilePath);
          await _justAudioPlayer.play();
          debugPrint('[WindowsAthanService] Fallback just_audio started successfully');
        } catch (e2) {
          debugPrint('[WindowsAthanService] Fallback just_audio error: $e2');
          _isPlaying = false;
          _currentPlayingTitle = null;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[WindowsAthanService] Error in playAthan: $e');
      _isPlaying = false;
      _currentPlayingTitle = null;
      notifyListeners();
    }
  }

  /// Stops Athan playback cleanly.
  Future<void> stopAthan() async {
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    try {
      await _justAudioPlayer.stop();
    } catch (_) {}
    _isPlaying = false;
    _currentPlayingTitle = null;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Quick Athan Test (3 Minutes) - Requirements 4
  // ─────────────────────────────────────────────────────────────────────────

  /// Schedules a test Athan exactly 3 minutes from now.
  ///
  /// Strictly isolated from regular prayer events:
  /// - Uses [testEventId] (-999).
  /// - Never modifies regular prayer alarms or next prayer time.
  /// - Never recurs.
  Future<bool> scheduleQuickTest() async {
    if (isTestScheduled) {
      debugPrint('[WindowsAthanService] Quick test already scheduled');
      return false;
    }

    final now = DateTime.now();
    final scheduledTime = now.add(const Duration(minutes: 3));

    _pendingTestEvent = _ScheduledAthanEvent(
      id: testEventId,
      prayerKey: 'dhuhr', // Uses default regular prayer muezzin
      prayerArabicName: 'اختبار الأذان',
      scheduledTime: scheduledTime,
      isTest: true,
    );

    debugPrint(
      '[WindowsAthanService] Quick test athan scheduled for $scheduledTime (in 3 minutes)',
    );
    notifyListeners();
    return true;
  }

  /// Cancels the pending Quick Athan Test.
  void cancelQuickTest() {
    if (_pendingTestEvent != null) {
      debugPrint('[WindowsAthanService] Quick test athan cancelled by user');
      _pendingTestEvent = null;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Resolves any asset path into a real local file on the Windows filesystem.
  /// This bypasses localhost HTTP proxies and streaming platform channel bottlenecks.
  Future<String> _resolveLocalAudioFile(String path) async {
    // 1. If it's already an absolute file path on disk and exists
    if (path.startsWith('/') || path.contains('\\')) {
      final file = File(path);
      if (await file.exists()) {
        return file.path;
      }
    }

    // 2. If it's a bundled asset (e.g. assets/audio/athan_makkah.mp3)
    try {
      final cleanAssetPath = path.startsWith('assets/') ? path : 'assets/$path';
      final fileName = cleanAssetPath.split('/').last;
      final appDir = await getApplicationSupportDirectory();
      final localFile = File('${appDir.path}/$fileName');

      if (!await localFile.exists() || await localFile.length() == 0) {
        final byteData = await rootBundle.load(cleanAssetPath);
        await localFile.writeAsBytes(
          byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          ),
          flush: true,
        );
        debugPrint(
          '[WindowsAthanService] Extracted asset to local file: ${localFile.path} (${await localFile.length()} bytes)',
        );
      }
      return localFile.path;
    } catch (e) {
      debugPrint('[WindowsAthanService] Failed to extract asset: $e');
      return path;
    }
  }

  Future<String> _resolveAthanAudioPath(
    SharedPreferences prefs,
    String prayerKey,
  ) async {
    final String? customPath = prefs.getString('athan_path_$prayerKey');
    if (customPath != null && customPath.isNotEmpty) {
      if (customPath.startsWith('/') || customPath.contains('\\')) {
        final file = File(customPath);
        if (await file.exists()) {
          return customPath;
        }
      } else {
        return customPath;
      }
    }

    // Default fallback assets
    if (prayerKey == 'fajr') {
      return 'assets/audio/fajr_makkah.mp3';
    }
    return 'assets/audio/athan_makkah.mp3';
  }

  void _showWindowsNotification({
    required bool isTest,
    required String prayerName,
  }) {
    try {
      final int notificationId = isTest ? 9999 : 888;
      final String title = isTest
          ? '🔔 اختبار الأذان (زاد)'
          : '🕌 حان الآن وقت أذان $prayerName';
      final String body = isTest
          ? 'تم تشغيل أذان التجربة المجدول بنجاح'
          : 'الله أكبر، الله أكبر';

      _notificationsPlugin.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          windows: WindowsNotificationDetails(),
        ),
        payload: isTest ? 'athan_test' : 'athan_overlay|$prayerName',
      );
    } catch (e) {
      debugPrint('[WindowsAthanService] Failed to display Windows notification: $e');
    }
  }

  int _getPrayerBaseId(String key) {
    switch (key) {
      case 'fajr':
        return 1;
      case 'dhuhr':
        return 3;
      case 'asr':
        return 4;
      case 'maghrib':
        return 5;
      case 'isha':
        return 6;
      default:
        return 0;
    }
  }

  String _getPrayerArabicName(String key) {
    switch (key) {
      case 'fajr':
        return 'الفجر';
      case 'dhuhr':
        return 'الظهر';
      case 'asr':
        return 'العصر';
      case 'maghrib':
        return 'المغرب';
      case 'isha':
        return 'العشاء';
      default:
        return 'الصلاة';
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _pendingTestEvent = null;
    _scheduledPrayers.clear();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _justAudioPlayer.stop();
    _justAudioPlayer.dispose();
    super.dispose();
  }
}
