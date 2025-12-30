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

  bool get isPlaying => _isPlaying;
  bool get isMuted => _isMuted;
  String? get currentAthanSound => _currentAthanSound;

  Future<void> playAthan({required String prayerName}) async {
    try {
      if (_isMuted) return;

      // Initialize AudioPlayer if needed
      if (_audioPlayer == null) {
        _audioPlayer = AudioPlayer();
        // Listen for player completion
        _audioPlayer!.onPlayerComplete.listen((_) {
          _isPlaying = false;
          debugPrint('Athan playback completed');
        });
      }

      // Load user's athan preference
      await _loadAthanPreference();

      // Determine the athan file to play
      String athanPath = _getAthanPath(prayerName);

      // Stop any currently playing athan
      await stopAthan();

      // Play the athan sound
      await _audioPlayer!.play(AssetSource('sounds/${athanPath.split('sounds/').last}'));
      
      _isPlaying = true;

      debugPrint('Playing athan for $prayerName: $athanPath');
    } catch (e) {
      debugPrint('Error playing athan: $e');
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
    try {
      if (_isMuted) return;

      // Initialize AudioPlayer if needed
      if (_audioPlayer == null) {
        _audioPlayer = AudioPlayer();
        // Listen for player completion
        _audioPlayer!.onPlayerComplete.listen((_) {
          _isPlaying = false;
          debugPrint('Athan playback completed');
        });
      }

      // Stop any currently playing athan
      await stopAthan();

      // Play the athan sound
      await _audioPlayer!.play(AssetSource('sounds/${athanPath.split('sounds/').last}'));
      
      _isPlaying = true;

      debugPrint('Athan started playing: $athanPath');
    } catch (e) {
      debugPrint('Error playing athan: $e');
      _isPlaying = false;
    }
  }
}
