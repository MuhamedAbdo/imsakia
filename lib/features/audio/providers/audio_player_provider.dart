import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:audio_session/audio_session.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/surah_audio.dart';
import '../models/reciter.dart';

class AudioPlayerProvider with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();

  SurahAudio? _currentSurah;
  Reciter? _currentReciter;

  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  SurahAudio? get currentSurah => _currentSurah;
  Reciter? get currentReciter => _currentReciter;

  AudioPlayerProvider() {
    _initAudioSession();
    _setupAudioListeners();
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Handle audio focus interruptions (e.g. phone calls)
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _audioPlayer.setVolume(0.5);
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            pause();
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _audioPlayer.setVolume(1.0);
            break;
          case AudioInterruptionType.pause:
            // Could optionally resume if it was paused specifically by interruption
            break;
          case AudioInterruptionType.unknown:
            break;
        }
      }
    });
  }

  void _setupAudioListeners() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;

      // Manage CPU wakelock to prevent OS from killing background audio
      if (_isPlaying) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }

      notifyListeners();
    });

    _audioPlayer.onPositionChanged.listen((position) {
      _currentPosition = position;
      notifyListeners();
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      _totalDuration = duration;
      notifyListeners();
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      _isPlaying = false;
      _currentPosition = Duration.zero;
      notifyListeners();
    });
  }

  Future<void> playSurah(SurahAudio surah, Reciter reciter) async {
    _currentSurah = surah;
    _currentReciter = reciter;
    notifyListeners();

    // Reset volume mapping
    await _audioPlayer.setVolume(1.0);

    // Prioritize offline files
    if (surah.localPath != null && surah.localPath!.isNotEmpty) {
      await _audioPlayer.play(DeviceFileSource(surah.localPath!));
    } else {
      await _audioPlayer.play(UrlSource(surah.audioUrl));
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> resume() async {
    await _audioPlayer.resume();
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
    _currentPosition = Duration.zero;
    _currentSurah = null;
    _currentReciter = null;
    notifyListeners();
  }

  Future<void> seekBackward10s() async {
    final p = _currentPosition - const Duration(seconds: 10);
    await _audioPlayer.seek(p.isNegative ? Duration.zero : p);
  }

  Future<void> seekForward10s() async {
    final p = _currentPosition + const Duration(seconds: 10);
    await _audioPlayer.seek(p > _totalDuration ? _totalDuration : p);
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
