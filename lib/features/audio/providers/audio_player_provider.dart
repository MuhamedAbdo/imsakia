import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:audio_session/audio_session.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/surah_audio.dart';
import '../models/reciter.dart';
import 'package:audio_service/audio_service.dart';
import '../services/audio_handler.dart';

class AudioPlayerProvider with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();

  SurahAudio? _currentSurah;
  Reciter? _currentReciter;
  List<SurahAudio> _currentPlaylist = [];

  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  SurahAudio? get currentSurah => _currentSurah;
  Reciter? get currentReciter => _currentReciter;
  List<SurahAudio> get currentPlaylist => _currentPlaylist;

  MyAudioHandler? _audioHandler;

  AudioPlayerProvider() {
    _initAudioSession();
    _setupAudioListeners();
    _initAudioHandler();
  }

  Future<void> _initAudioHandler() async {
    try {
      // audio_service does not have native Windows/Linux implementations yet.
      // We skip initialization on these platforms to prevent MissingPluginException.
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
        return;
      }

      _audioHandler = await AudioService.init(
        builder: () => MyAudioHandler(_audioPlayer),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.yourcompany.imsakia.channel.audio',
          androidNotificationChannelName: 'تلاوات القرآن',
          androidNotificationOngoing: true,
        ),
      );

      _audioHandler!.onNext = skipToNext;
      _audioHandler!.onPrevious = skipToPrevious;
      _audioHandler!.onStopCustom = stop;
    } catch (e) {
      debugPrint("AudioService could not be initialized: $e");
    }
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
      skipToNext(); // Auto-next playback
    });
  }

  void setPlaylist(List<SurahAudio> playlist) {
    _currentPlaylist = playlist;
  }

  Future<void> playSurah(SurahAudio surah, Reciter reciter) async {
    _currentSurah = surah;
    _currentReciter = reciter;
    notifyListeners();

    // Update audio_service metadata
    _audioHandler?.mediaItem.add(MediaItem(
      id: surah.id.toString(),
      album: "تلاوات القرآن",
      title: "سورة ${surah.name}",
      artist: reciter.name,
      artUri: Uri.parse(reciter.serverUrl), // Can be anything, just a placeholder or reciter image
    ));

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
    _audioHandler?.stop();
    notifyListeners();
  }

  Future<void> skipToNext() async {
    if (_currentSurah == null || _currentReciter == null || _currentPlaylist.isEmpty) return;
    
    final currentIndex = _currentPlaylist.indexWhere((s) => s.id == _currentSurah!.id);
    if (currentIndex != -1 && currentIndex + 1 < _currentPlaylist.length) {
      final nextSurah = _currentPlaylist[currentIndex + 1];
      await playSurah(nextSurah, _currentReciter!);
    }
  }

  Future<void> skipToPrevious() async {
    if (_currentSurah == null || _currentReciter == null || _currentPlaylist.isEmpty) return;
    
    if (_currentPosition.inSeconds > 5) {
      // If played for more than 5 seconds, restart current track instead of previous
      await seek(Duration.zero);
      return;
    }

    final currentIndex = _currentPlaylist.indexWhere((s) => s.id == _currentSurah!.id);
    if (currentIndex > 0) {
      final prevSurah = _currentPlaylist[currentIndex - 1];
      await playSurah(prevSurah, _currentReciter!);
    }
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
