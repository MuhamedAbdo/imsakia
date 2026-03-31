import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audio_session/audio_session.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/surah_audio.dart';
import '../models/reciter.dart';
import '../services/audio_handler.dart';

class AudioPlayerProvider with ChangeNotifier {
  MyAudioHandler? get _handler => audioHandler;
  AudioPlayer get _audioPlayer => _handler!.player;

  SurahAudio? _currentSurah;
  Reciter? _currentReciter;
  List<SurahAudio> _currentPlaylist = [];
  Uri? _localArtUri;

  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  double _volume = 1.0;
  Timer? _volumeDebounce;

  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  SurahAudio? get currentSurah => _currentSurah;
  Reciter? get currentReciter => _currentReciter;
  List<SurahAudio> get currentPlaylist => _currentPlaylist;
  double get volume => _volume;

  AudioPlayerProvider() {
    _loadVolume();
    _initAudioSession();
    _setupAudioListeners();
    
    if (audioHandler != null) {
      audioHandler!.onNext = skipToNext;
      audioHandler!.onPrevious = skipToPrevious;
      audioHandler!.onStopCustom = stop;
    }
  }

  Future<void> _loadVolume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('settings');
      if (raw != null) {
        final settings = jsonDecode(raw) as Map<String, dynamic>;
        _volume = (settings['athanVolume'] as num?)?.toDouble() ?? 1.0;
        await _audioPlayer.setVolume(_volume);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading volume: $e');
    }
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Handle audio focus interruptions
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
            break;
          case AudioInterruptionType.unknown:
            break;
        }
      }
    });
  }

  void _setupAudioListeners() {
    _audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;

      if (_isPlaying) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }

      notifyListeners();
    });

    _audioPlayer.positionStream.listen((position) {
      _currentPosition = position;
      notifyListeners();
    });

    _audioPlayer.durationStream.listen((duration) {
      _totalDuration = duration ?? Duration.zero;
      notifyListeners();
    });
  }

  void setPlaylist(List<SurahAudio> playlist) {
    _currentPlaylist = playlist;
  }

  Future<void> playSurah(SurahAudio surah, Reciter reciter) async {
    _currentSurah = surah;
    _currentReciter = reciter;
    notifyListeners();

    Uri? artUri = await _getArtUri();
    
    audioHandler?.setMediaItem(
      id: surah.id.toString(),
      title: "سورة ${surah.name}",
      artist: reciter.name,
      artUri: artUri ?? Uri.parse('https://raw.githubusercontent.com/ryanheise/audio_service/master/example/web/media/art.jpg'),
    );

    await _audioPlayer.setVolume(_volume);

    try {
      if (surah.localPath != null && surah.localPath!.isNotEmpty) {
        await _handler?.playFromFile(surah.localPath!);
      } else {
        await _handler?.playFromUrl(surah.audioUrl);
      }
    } catch (e) {
      debugPrint("Error playing audio: $e");
    }
  }

  Future<Uri?> _getArtUri() async {
    if (_localArtUri != null) return _localArtUri;
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final file = File('${docDir.path}/app_logo.png');
      
      if (!await file.exists()) {
        final byteData = await rootBundle.load('assets/images/quranlogo.png');
        await file.writeAsBytes(byteData.buffer.asUint8List(
          byteData.offsetInBytes, byteData.lengthInBytes));
      }
      
      _localArtUri = Uri.file(file.path);
      return _localArtUri;
    } catch (e) {
      debugPrint('Error loading local artUri: $e');
      return null;
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> resume() async {
    await _audioPlayer.play();
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

  Future<void> setVolume(double value) async {
    _volume = value;
    await _audioPlayer.setVolume(value);
    notifyListeners();
    // Persistence is handled by SettingsProvider when called in conjunction 
    // or we could save directly here if needed.
    // The Slider in SettingsScreen calls both to avoid redundant saves while
    // maintaining state consistency.
  }

  @override
  void dispose() {
    _volumeDebounce?.cancel();
    // If we use handler's player, we shouldn't dispose it here if it's shared
    // but typically Provider dispose means app/feature is closing
    if (audioHandler == null) {
      _audioPlayer.dispose();
    }
    super.dispose();
  }
}
