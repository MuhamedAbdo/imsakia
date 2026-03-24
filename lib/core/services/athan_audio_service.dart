import 'dart:async';
import 'dart:developer' as developer;
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AthanAudioService {
  static final AthanAudioService _instance = AthanAudioService._internal();
  factory AthanAudioService() => _instance;
  AthanAudioService._internal();

  AudioPlayer? _player;
  bool _isPlaying = false;
  DateTime? _lastPlayedAt;

  /// Subscription to AudioSession interruption events (phone calls, other media).
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;

  bool get isPlaying => _isPlaying;

  /// Plays the Athan audio asset.
  /// Has a built-in 2-minute debounce to prevent duplicate triggers.
  Future<void> play([String assetPath = 'assets/audio/athan_egypt_ab.mp3']) async {
    // --- Debounce guard (2 minutes) ---
    final now = DateTime.now();
    if (_lastPlayedAt != null &&
        now.difference(_lastPlayedAt!).inSeconds < 120) {
      developer.log(
        '[AthanAudio] Debounce: skipping duplicate play() — last played '
        '${now.difference(_lastPlayedAt!).inSeconds}s ago.',
        name: 'AthanAudioService',
      );
      return;
    }

    // Always stop any previous audio and cancel previous interruption listener.
    await stop();

    try {
      developer.log('[AthanAudio] Starting audio: $assetPath', name: 'AthanAudioService');
      _player = AudioPlayer();

      // ── Audio Focus: stop completely on ANY focus loss (calls, media apps).
      // We configure the AudioSession to use the alarm category so the OS
      // treats this as a high-priority stream that overrides Do Not Disturb.
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.alarm,
          flags: AndroidAudioFlags.audibilityEnforced,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));

      // Cancel any stale subscription.
      await _interruptionSub?.cancel();

      // ── Listen for interruptions (phone calls, navigation, other media).
      // On interruption we do a full STOP — NOT a pause/resume — so the Athan
      // never resumes on its own after a call ends.
      _interruptionSub = session.interruptionEventStream.listen((event) async {
        if (event.begin) {
          developer.log(
            '[AthanAudio] Audio interruption BEGIN (type: ${event.type}) — stopping Athan.',
            name: 'AthanAudioService',
          );
          await _handleForcedStop();
        }
        // We intentionally do nothing on event.begin == false (interruption end)
        // so the Athan does NOT resume after a call.
      });

      // Also stop on natural playback completion.
      _player!.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          developer.log('[AthanAudio] Playback completed naturally.', name: 'AthanAudioService');
          _handleForcedStop();
        }
      });

      await _player!.setAsset(assetPath);
      await _player!.play();
      _isPlaying = true;
      _lastPlayedAt = now;
      developer.log('[AthanAudio] Playback started successfully.', name: 'AthanAudioService');
    } catch (e) {
      developer.log('[AthanAudio] Error during play(): $e', name: 'AthanAudioService');
      await _handleForcedStop();
    }
  }

  /// Called on any forced stop (interruption, error, or natural end).
  /// Kills audio and clears the `athan_is_playing` SharedPreferences flag.
  Future<void> _handleForcedStop() async {
    developer.log('[AthanAudio] _handleForcedStop: clearing audio and athan_is_playing flag.', name: 'AthanAudioService');
    await stop();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('athan_is_playing', false);
    } catch (_) {}
  }

  /// Stops the Athan, cancels the interruption listener, and fully resets the player.
  Future<void> stop() async {
    developer.log('[AthanAudio] stop() called — stopping and clearing cache.', name: 'AthanAudioService');

    // Cancel audio interruption listener first.
    await _interruptionSub?.cancel();
    _interruptionSub = null;

    if (_player != null) {
      try {
        await _player!.stop();
        await _player!.dispose();
        developer.log('[AthanAudio] Player stopped and disposed.', name: 'AthanAudioService');
      } catch (e) {
        developer.log('[AthanAudio] Error during stop/dispose: $e', name: 'AthanAudioService');
      }
    }
    _isPlaying = false;
    _player = null;
  }

  /// Static helper — delegates to instance stop().
  static Future<void> stopAudio() async {
    await AthanAudioService().stop();
  }

  /// Legacy alias kept for compatibility.
  Future<void> dispose() async => stop();
}
