import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_constants.dart';

class AthanPlayerService {
  static AthanPlayerService? _instance;
  static AthanPlayerService get instance => _instance ??= AthanPlayerService._();

  AthanPlayerService._();

  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  bool _isMuted = false;
  String? _currentAthanSound;
  String? _preloadedAthanPath;
  DateTime? _triggerTime;

  bool get isPlaying => _isPlaying;
  bool get isMuted => _isMuted;
  String? get currentAthanSound => _currentAthanSound;

  /// Update the current athan sound preference (called by SettingsProvider)
  void updateCurrentAthanSound(String sound) {
    _currentAthanSound = sound;
    debugPrint('🔊 AthanPlayerService updated with sound: $sound');
  }

  /// Initialize the audio player with low latency settings
  Future<void> initialize() async {
    if (_audioPlayer == null) {
      _audioPlayer = AudioPlayer();
      
      // Configure for low latency
      await _audioPlayer!.setPlayerMode(PlayerMode.lowLatency);
      
      // Listen for player completion
      _audioPlayer!.onPlayerComplete.listen((_) {
        _isPlaying = false;
        final completionTime = DateTime.now();
        final duration = _triggerTime != null 
            ? completionTime.difference(_triggerTime!) 
            : Duration.zero;
        debugPrint('🎵 Athan playback completed - Total duration: ${duration.inMilliseconds}ms');
      });
      
      // Load user preferences
      await _loadAthanPreference();
      
      debugPrint('🔧 AudioPlayer initialized with low latency mode');
    }
  }

  /// Preload athan audio for instant playback
  Future<void> preloadAthan(String prayerName) async {
    try {
      await initialize();
      
      final athanPath = _getAthanPath(prayerName);
      final audioSource = AssetSource('sounds/${athanPath.split('sounds/').last}');
      
      await _audioPlayer!.setSource(audioSource);
      _preloadedAthanPath = athanPath;
      
      debugPrint('📦 Preloaded athan: $athanPath');
    } catch (e) {
      debugPrint('❌ Error preloading athan: $e');
    }
  }

  Future<void> playAthan({required String prayerName}) async {
    _triggerTime = DateTime.now();
    debugPrint('⏰ Athan trigger started at: ${_triggerTime!.toIso8601String()}');
    
    try {
      if (_isMuted) {
        debugPrint('🔇 Athan muted - skipping playback');
        return;
      }

      await initialize();
      
      // Determine the athan file to play
      String athanPath = _getAthanPath(prayerName);
      final audioSource = AssetSource('sounds/${athanPath.split('sounds/').last}');
      
      // Stop any currently playing athan
      await stopAthan();
      
      final prepareStartTime = DateTime.now();
      
      // Check if already preloaded
      if (_preloadedAthanPath == athanPath) {
        debugPrint('⚡ Using preloaded audio - instant playback');
      } else {
        // Set source for new audio
        await _audioPlayer!.setSource(audioSource);
        final prepareDuration = DateTime.now().difference(prepareStartTime);
        debugPrint('🔄 Audio prepared in: ${prepareDuration.inMilliseconds}ms');
      }
      
      final playStartTime = DateTime.now();
      
      // Play the athan sound
      await _audioPlayer!.play(audioSource);
      
      final playDuration = DateTime.now().difference(playStartTime);
      final totalDuration = DateTime.now().difference(_triggerTime!);
      
      _isPlaying = true;
      _preloadedAthanPath = athanPath;

      debugPrint('🎵 PLAYBACK STARTED:');
      debugPrint('   ├─ Prayer: $prayerName');
      debugPrint('   ├─ File: $athanPath');
      debugPrint('   ├─ Play call duration: ${playDuration.inMilliseconds}ms');
      debugPrint('   └─ Total delay: ${totalDuration.inMilliseconds}ms');
    } catch (e) {
      final errorDuration = DateTime.now().difference(_triggerTime!);
      debugPrint('❌ Error playing athan: $e');
      debugPrint('❌ Error occurred after: ${errorDuration.inMilliseconds}ms');
      _isPlaying = false;
    }
  }

  Future<void> stopAthan() async {
    try {
      if (_audioPlayer != null) {
        await _audioPlayer!.stop();
        await _audioPlayer!.seek(Duration.zero);
      }
      _isPlaying = false;
      debugPrint('Athan stopped');
    } catch (e) {
      debugPrint('Error stopping athan: $e');
      _isPlaying = false;
    }
  }

  void mute() {
    _isMuted = true;
    stopAthan();
    debugPrint('Athan muted');
  }

  void unmute() {
    _isMuted = false;
    debugPrint('Athan unmuted');
  }

  void dispose() {
    if (_audioPlayer != null) {
      _audioPlayer!.dispose();
      _audioPlayer = null;
    }
  }

  Future<void> _loadAthanPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentAthanSound = prefs.getString(AppConstants.athanSoundKey) ?? AppConstants.defaultAthanSound;
    } catch (e) {
      debugPrint('Error loading athan preference: $e');
      _currentAthanSound = AppConstants.defaultAthanSound;
    }
  }

  String _getAthanPath(String prayerName) {
    // Fajr special logic: always play fajr.mp3 regardless of user settings
    if (prayerName.toLowerCase() == 'fajr') {
      return 'assets/sounds/fajr.mp3';
    }

    // For other prayers, use user's selection
    final selectedSound = _currentAthanSound ?? AppConstants.defaultAthanSound;
    
    switch (selectedSound) {
      case 'makkah':
        return 'assets/sounds/makkah.mp3';
      case 'madinah':
        return 'assets/sounds/madinah.mp3';
      case 'egypt':
        return 'assets/sounds/egypt.mp3';
      case 'silent':
        return 'assets/sounds/default_athan.mp3'; // Fallback for silent
      case 'default':
      default:
        return 'assets/sounds/default_athan.mp3';
    }
  }

  // Legacy method for backward compatibility
  Future<void> playAthanLegacy({String athanPath = 'assets/sounds/default_athan.mp3'}) async {
    _triggerTime = DateTime.now();
    debugPrint('⏰ Legacy athan trigger started at: ${_triggerTime!.toIso8601String()}');
    
    try {
      if (_isMuted) {
        debugPrint('🔇 Athan muted - skipping legacy playback');
        return;
      }

      await initialize();
      
      final audioSource = AssetSource('sounds/${athanPath.split('sounds/').last}');
      
      // Stop any currently playing athan
      await stopAthan();
      
      final playStartTime = DateTime.now();
      
      // Play the athan sound
      await _audioPlayer!.play(audioSource);
      
      final playDuration = DateTime.now().difference(playStartTime);
      final totalDuration = DateTime.now().difference(_triggerTime!);
      
      _isPlaying = true;

      debugPrint('🎵 LEGACY PLAYBACK STARTED:');
      debugPrint('   ├─ File: $athanPath');
      debugPrint('   ├─ Play call duration: ${playDuration.inMilliseconds}ms');
      debugPrint('   └─ Total delay: ${totalDuration.inMilliseconds}ms');
    } catch (e) {
      final errorDuration = DateTime.now().difference(_triggerTime!);
      debugPrint('❌ Error playing legacy athan: $e');
      debugPrint('❌ Error occurred after: ${errorDuration.inMilliseconds}ms');
      _isPlaying = false;
    }
  }
}
