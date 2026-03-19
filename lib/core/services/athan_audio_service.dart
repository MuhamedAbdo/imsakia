import 'dart:developer' as developer;
import 'package:just_audio/just_audio.dart';

class AthanAudioService {
  static final AthanAudioService _instance = AthanAudioService._internal();
  factory AthanAudioService() => _instance;
  AthanAudioService._internal();

  AudioPlayer? _player;
  bool _isPlaying = false;
  DateTime? _lastPlayedAt;

  bool get isPlaying => _isPlaying;

  /// Plays the Athan audio asset.
  /// Has a built-in 2-minute debounce: if audio was started within the last
  /// 120 seconds, the call is silently ignored.
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

    // --- Audio Driver Mutual Exclusion ---
    // Rule: Before starting any new audio, ALWAYS call and await stop()
    // to avoid overlapping and ensure proper Audio Focus.
    developer.log('[AthanAudio] Stopping current playback before starting new: $assetPath', name: 'AthanAudioService');
    await stop();

    try {
      developer.log('[AthanAudio] Starting audio: $assetPath', name: 'AthanAudioService');
      _player ??= AudioPlayer();
      await _player!.setAsset(assetPath);
      _player!.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          developer.log('[AthanAudio] Playback completed naturally.', name: 'AthanAudioService');
          _isPlaying = false;
          _disposePlayer();
        }
      });
      await _player!.play();
      _isPlaying = true;
      _lastPlayedAt = now;
      developer.log('[AthanAudio] Playback started successfully.', name: 'AthanAudioService');
    } catch (e) {
      developer.log('[AthanAudio] Error during play(): $e', name: 'AthanAudioService');
      _isPlaying = false;
      _disposePlayer();
    }
  }

  /// Stops the Athan and fully resets the player.
  Future<void> stop() async {
    developer.log('[AthanAudio] stop() called — stopping and disposing player.', name: 'AthanAudioService');
    if (_player != null) {
      try {
        await _player!.stop();
      } catch (_) {}
    }
    _isPlaying = false;
    await _disposePlayer();
  }

  /// Static method to stop audio from the Background Service isolate.
  /// CAUTION: Does NOT work across isolates. UI must use background service invoke.
  static Future<void> stopAudio() async {
    await AthanAudioService().stop();
  }

  Future<void> _disposePlayer() async {
    if (_player != null) {
      try {
        await _player!.dispose();
      } catch (_) {}
      _player = null;
    }
  }

  /// Legacy alias kept for compatibility — delegates to stop().
  Future<void> dispose() async => stop();
}
