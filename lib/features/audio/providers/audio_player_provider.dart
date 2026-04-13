import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audio_session/audio_session.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/surah_audio.dart';
import '../models/reciter.dart';
import '../services/audio_handler.dart';
import 'package:audio_service/audio_service.dart';

class AudioPlayerProvider with ChangeNotifier {
  late final AudioPlayer _audioPlayer;

  SurahAudio? _currentSurah;
  Reciter? _currentReciter;
  List<SurahAudio> _currentPlaylist = [];
  Uri? _localArtUri;

  bool _isPlaying = false;
  bool _isBuffering = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  String? _errorMessage;
  bool _isStopping = false;

  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  SurahAudio? get currentSurah => _currentSurah;
  Reciter? get currentReciter => _currentReciter;
  List<SurahAudio> get currentPlaylist => _currentPlaylist;
  String? get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  AudioPlayerProvider() {
    _audioPlayer = audioHandler?.player ?? AudioPlayer();
    _initAudioSession();
    _setupAudioListeners();
    
    if (audioHandler != null) {
      audioHandler!.onNext = skipToNext;
      audioHandler!.onPrevious = skipToPrevious;
      audioHandler!.onStopCustom = stop;
    }
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

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
      _isBuffering = state.processingState == ProcessingState.buffering || 
                    state.processingState == ProcessingState.loading;

      if (_isPlaying) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }

      if (state.processingState == ProcessingState.completed) {
        _isPlaying = false;
        _currentPosition = Duration.zero;
        notifyListeners();
        skipToNext();
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
    if (surah.audioUrl.isEmpty && (surah.localPath == null || surah.localPath!.isEmpty)) {
      _errorMessage = "التسجيل غير متاح لهذا القارئ";
      notifyListeners();
      return;
    }

    try {
      _errorMessage = null;
      _isBuffering = true;
      notifyListeners();

      // 🛡️ Protection Layer: إذا كان المحرك منشغلاً بالتحميل، نوقفه فوراً وننتظر قليلاً لضمان الاستقرار
      if (_audioPlayer.processingState == ProcessingState.loading || 
          _audioPlayer.processingState == ProcessingState.buffering) {
        await _audioPlayer.stop();
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // 🛑 Mandatory delay to clear Native layer safely
      await _audioPlayer.stop();
      await Future.delayed(const Duration(milliseconds: 200));

      _currentSurah = surah;
      _currentReciter = reciter;
      notifyListeners();

      Uri? artUri = await _getArtUri();
      
      // Update audio_service explicitly
      audioHandler?.setMediaItem(
        id: surah.id.toString(),
        title: "سورة ${surah.name}",
        artist: reciter.name,
        artUri: artUri ?? Uri.parse('https://raw.githubusercontent.com/ryanheise/audio_service/master/example/web/media/art.jpg'),
      );


      await _audioPlayer.setVolume(1.0);

      // 🌍 Play with Smart Retry & User-Agent
      if (surah.localPath != null && surah.localPath!.isNotEmpty) {
        await _audioPlayer.setAudioSource(AudioSource.file(surah.localPath!));
      } else {
        // Prepare rich metadata tag for JustAudio -> AudioService integration
        final tag = MediaItem(
          id: surah.id.toString(),
          album: "قرآن - ${reciter.name}",
          title: "سورة ${surah.name}",
          artist: reciter.name,
          artUri: artUri,
        );
        
        await _invokePlayWithRetry(surah.audioUrl, tag);
      }
      
      await _audioPlayer.play();
      _isBuffering = false;
      notifyListeners();
    } catch (e) {
      debugPrint("Audio Playback Error: $e");
      _errorMessage = "حدث خطأ في الاتصال، يرجى المحاولة مرة أخرى";
      _isBuffering = false;
      stop(); // Non-blocking retry
      notifyListeners();
    }
  }

  Future<void> _invokePlayWithRetry(String url, MediaItem tag, {int retryCount = 0}) async {
    try {
      final source = AudioSource.uri(
        Uri.parse(url),
        headers: {'User-Agent': 'ZadApp/1.0'},
        tag: tag,
      );
      
      await _audioPlayer.setAudioSource(source).timeout(const Duration(seconds: 10));
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains("404") || errorStr.contains("Not Found")) {
        rethrow;
      }

      if (retryCount < 1) {
        debugPrint("Network error detected, retrying... ($e)");
        await Future.delayed(const Duration(milliseconds: 500));
        return await _invokePlayWithRetry(url, tag, retryCount: retryCount + 1);
      }
      rethrow;
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
    if (_isStopping) return;
    _isStopping = true;

    try {
      // 🚨 Non-blocking Stop: نحدث الحالة داخلياً فوراً لتختفي الواجهة
      _isPlaying = false;
      _currentSurah = null;
      _currentReciter = null;
      _currentPosition = Duration.zero;
      notifyListeners();

      // نطلب التوقف في الخلفية دون انتظار Native لضمان عدم حدوث ANR أو Stack Overflow
      _audioPlayer.stop();
      audioHandler?.stop();
    } finally {
      _isStopping = false;
    }
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

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
