import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audio_service/audio_service.dart';
import 'package:quran/quran.dart' as quran;
import 'package:imsakia/features/audio/services/audio_handler.dart';

class QuranAudioProvider extends ChangeNotifier {
  final AudioPlayer _fallbackPlayer = AudioPlayer();
  AudioPlayer get _player => audioHandler?.player ?? _fallbackPlayer;

  // قائمة أشهر القراء
  static const List<Map<String, String>> reciters = [
    {'name': 'عبد الباسط عبد الصمد (مرتل)', 'folder': 'Abdul_Basit_Murattal_64kbps'},
    {'name': 'مشاري راشد العفاسي', 'folder': 'Alafasy_128kbps'},
    {'name': 'محمود خليل الحصري', 'folder': 'Husary_128kbps'},
    {'name': 'ماهر المعيقلي', 'folder': 'MaherAlMuaiqly128kbps'},
    {'name': 'محمد صديق المنشاوي (مرتل)', 'folder': 'Minshawy_Murattal_128kbps'},
    {'name': 'ياسر الدوسري', 'folder': 'Yaser_Abdullah_Al_Dosari_128kbps'},
  ];

  // المجلد الافتراضي للمقرئ على موقع EveryAyah
  String _currentReciterFolder = 'Abdul_Basit_Murattal_64kbps';
  
  // رقم الآية الحالية (1-based)
  int? _currentPlayingAyaIndex;
  
  // رقم السورة الحالية التي يتم تشغيلها
  int? _currentSuraNumber;

  // Concurrency & generation guards
  int _loadGeneration = 0;
  bool _isLoadingAudio = false;
  int? _lastCompletedSuraHandled;

  String get currentReciterFolder => _currentReciterFolder;
  int? get currentPlayingAyaIndex => _currentPlayingAyaIndex;
  int? get currentSuraNumber => _currentSuraNumber;
  AudioPlayer get player => _player;
  bool get isLoadingAudio => _isLoadingAudio;

  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;

  bool _isSingleAyah = false;
  int? _singleAyahNumber;

  LoopMode _loopMode = LoopMode.off;
  LoopMode get loopMode => _loopMode;

  QuranAudioProvider() {
    _initReciter();

    // الاستماع لتغير الآية (Index) في طابور التشغيل
    _player.currentIndexStream.listen((index) {
      if (_isLoadingAudio) return;
      if (index != null) {
        if (_isSingleAyah) {
          _currentPlayingAyaIndex = _singleAyahNumber;
        } else {
          // Index يبدأ من 0، والآيات تبدأ من 1
          _currentPlayingAyaIndex = index + 1;
        }
        _updateBackgroundMediaItem();
        notifyListeners();
      } else {
        _currentPlayingAyaIndex = null;
        notifyListeners();
      }
    });

    // ربط أزرار التحكم في شاشة القفل للإنتقال للآية التالية/السابقة
    audioHandler?.onNext = () {
      if (_player.hasNext) _player.seekToNext();
    };
    audioHandler?.onPrevious = () {
      if (_player.hasPrevious) _player.seekToPrevious();
    };

    // الاستماع لحالة التشغيل لإعادة التعيين عند الانتهاء أو الانتقال للسورة التالية
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (!_isLoadingAudio &&
            !_isSingleAyah &&
            _currentSuraNumber != null &&
            _currentSuraNumber! < 114) {
          final completedSura = _currentSuraNumber!;
          if (_lastCompletedSuraHandled == completedSura) {
            return;
          }
          _lastCompletedSuraHandled = completedSura;
          final nextSura = completedSura + 1;
          final totalAyahs = quran.getVerseCount(nextSura);
          loadAndPlaySura(nextSura, totalAyahs);
        } else if (!_isLoadingAudio) {
          _currentPlayingAyaIndex = null;
          _currentSuraNumber = null;
          _lastCompletedSuraHandled = null;
          notifyListeners();
        }
      }
    });

    // الاستماع لتغير حالة التشغيل (Play/Pause) لتحديث واجهة المستخدم
    _player.playingStream.listen((playing) {
      notifyListeners();
    });
  }

  bool _isCancellationException(Object e) {
    if (e is PlatformException) {
      final code = e.code.toLowerCase();
      final msg = (e.message ?? '').toLowerCase();
      return code == 'abort' ||
          msg.contains('abort') ||
          msg.contains('loading interrupted') ||
          msg.contains('interrupted');
    }
    final str = e.toString().toLowerCase();
    return str.contains('loading interrupted') ||
        str.contains('abort') ||
        str.contains('interrupted');
  }

  Future<void> _initReciter() async {
    final prefs = await SharedPreferences.getInstance();
    final savedFolder = prefs.getString('quran_reciter_folder');
    if (savedFolder != null) {
      _currentReciterFolder = savedFolder;
      notifyListeners();
    }
  }

  void _updateBackgroundMediaItem() {
    if (audioHandler == null || _currentSuraNumber == null) return;
    
    final reciterName = reciters.firstWhere(
      (r) => r['folder'] == _currentReciterFolder, 
      orElse: () => reciters.first
    )['name'];
    
    final suraName = quran.getSurahNameArabic(_currentSuraNumber!);
    final ayah = _currentPlayingAyaIndex ?? 1;

    audioHandler!.mediaItem.add(MediaItem(
      id: '${_currentReciterFolder}_${_currentSuraNumber}_$ayah',
      title: 'سورة $suraName',
      album: 'القرآن الكريم',
      artist: reciterName,
      displayDescription: 'الآية رقم $ayah',
    ));
  }

  /// تغيير المقرئ
  Future<void> changeReciter(String reciterFolder) async {
    if (_currentReciterFolder == reciterFolder) return;
    
    _loadGeneration++;
    _isLoadingAudio = false;
    _lastCompletedSuraHandled = null;
    _currentReciterFolder = reciterFolder;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('quran_reciter_folder', reciterFolder);
    
    // إذا كان يعمل حاليا نقوم بالإيقاف المؤقت بدون هدم المشغل على ويندوز
    if (_player.playing) {
      await _player.pause();
    }
    _currentSuraNumber = null;
    _currentPlayingAyaIndex = null;
    notifyListeners();
  }

  /// تحميل السورة وبدء التشغيل
  Future<void> loadAndPlaySura(int suraNumber, int totalAyahs, {int startAyah = 1}) async {
    // Guard against concurrent overlapping loads for the same or different Surah
    if (_isLoadingAudio) {
      return;
    }

    final gen = ++_loadGeneration;
    _isLoadingAudio = true;
    _isSingleAyah = false;
    notifyListeners();

    try {
      // Pause cleanly instead of calling stop() to prevent tearing down native player on Windows
      if (_player.playing) {
        await _player.pause();
      }

      await _player.setVolume(1.0);

      final List<AudioSource> audioSources = [];
      String suraStr = suraNumber.toString().padLeft(3, '0');
      
      final dir = await getApplicationDocumentsDirectory();

      for (int i = 1; i <= totalAyahs; i++) {
        if (gen != _loadGeneration) return;
        String ayaStr = i.toString().padLeft(3, '0');
        String fileName = '$suraStr$ayaStr.mp3';
        String localPath = '${dir.path}/$_currentReciterFolder/$fileName';
        String url = 'https://everyayah.com/data/$_currentReciterFolder/$fileName';
        
        if (await File(localPath).exists()) {
          audioSources.add(AudioSource.file(localPath));
        } else {
          audioSources.add(AudioSource.uri(Uri.parse(url)));
        }
      }

      if (gen != _loadGeneration) return;

      // تعيين المصدر للمشغل وبدء التشغيل مع تحديد نقطة البداية
      await _player.setAudioSources(audioSources, initialIndex: startAyah - 1);
      
      if (gen != _loadGeneration) return;

      // Publish active track state only after source is successfully loaded
      _currentSuraNumber = suraNumber;
      _currentPlayingAyaIndex = startAyah;
      _lastCompletedSuraHandled = null;
      _isLoadingAudio = false;
      _updateBackgroundMediaItem();
      notifyListeners();

      await _player.play();

      // Windows retry guard: ensure playback has engaged on Windows Desktop where WinRT can drop play() during state transitions
      if (!kIsWeb && Platform.isWindows && gen == _loadGeneration && !_player.playing) {
        for (int retry = 0; retry < 3; retry++) {
          await Future.delayed(const Duration(milliseconds: 200));
          if (gen != _loadGeneration || _player.playing) break;
          await _player.play();
        }
      }
    } catch (e) {
      if (_isCancellationException(e)) {
        debugPrint("Expected playback load cancellation: $e");
      } else {
        debugPrint("Error loading sura audio: $e");
        if (gen == _loadGeneration) {
          _isLoadingAudio = false;
          _currentPlayingAyaIndex = null;
          _currentSuraNumber = null;
          notifyListeners();
        }
      }
    } finally {
      if (gen == _loadGeneration && _isLoadingAudio) {
        _isLoadingAudio = false;
        notifyListeners();
      }
    }
  }

  /// تحميل وتشغيل آية واحدة
  Future<void> playSingleAyah(int suraNumber, int ayaNumber) async {
    if (_isLoadingAudio) return;

    final gen = ++_loadGeneration;
    _isLoadingAudio = true;
    _lastCompletedSuraHandled = null;
    notifyListeners();

    try {
      if (_player.playing) {
        await _player.pause();
      }

      await _player.setVolume(1.0);

      String suraStr = suraNumber.toString().padLeft(3, '0');
      String ayaStr = ayaNumber.toString().padLeft(3, '0');
      String fileName = '$suraStr$ayaStr.mp3';
      
      final dir = await getApplicationDocumentsDirectory();
      String localPath = '${dir.path}/$_currentReciterFolder/$fileName';
      String url = 'https://everyayah.com/data/$_currentReciterFolder/$fileName';

      final AudioSource source;
      if (await File(localPath).exists()) {
        source = AudioSource.file(localPath);
      } else {
        source = AudioSource.uri(Uri.parse(url));
      }

      if (gen != _loadGeneration) return;

      await _player.setAudioSource(source);

      if (gen != _loadGeneration) return;

      _isSingleAyah = true;
      _singleAyahNumber = ayaNumber;
      _currentSuraNumber = suraNumber;
      _currentPlayingAyaIndex = ayaNumber;
      _isLoadingAudio = false;
      _updateBackgroundMediaItem();
      notifyListeners();

      await _player.play();

      if (!kIsWeb && Platform.isWindows && gen == _loadGeneration && !_player.playing) {
        for (int retry = 0; retry < 3; retry++) {
          await Future.delayed(const Duration(milliseconds: 200));
          if (gen != _loadGeneration || _player.playing) break;
          await _player.play();
        }
      }
    } catch (e) {
      if (_isCancellationException(e)) {
        debugPrint("Expected single ayah playback cancellation: $e");
      } else {
        debugPrint("Error loading single ayah audio: $e");
        if (gen == _loadGeneration) {
          _isLoadingAudio = false;
          _currentPlayingAyaIndex = null;
          _currentSuraNumber = null;
          notifyListeners();
        }
      }
    } finally {
      if (gen == _loadGeneration && _isLoadingAudio) {
        _isLoadingAudio = false;
        notifyListeners();
      }
    }
  }

  /// إيقاف التشغيل
  Future<void> stop() async {
    _loadGeneration++;
    _isLoadingAudio = false;
    _lastCompletedSuraHandled = null;
    await _player.stop();
    _currentSuraNumber = null;
    _currentPlayingAyaIndex = null;
    notifyListeners();
  }
  
  /// إيقاف التشغيل وإنهاء خدمة الخلفية
  Future<void> stopAndKillService() async {
    await stop();
    await audioHandler?.stop();
  }
  
  /// تحميل السورة (Offline Mode)
  Future<void> downloadSura(int suraNumber, int totalAyahs) async {
    if (_isDownloading) return;

    _isDownloading = true;
    _downloadProgress = 0.0;
    notifyListeners();

    try {
      final dir = await getApplicationDocumentsDirectory();
      final dio = Dio();
      String suraStr = suraNumber.toString().padLeft(3, '0');
      
      final reciterDir = Directory('${dir.path}/$_currentReciterFolder');
      if (!await reciterDir.exists()) {
        await reciterDir.create(recursive: true);
      }

      for (int i = 1; i <= totalAyahs; i++) {
        String ayaStr = i.toString().padLeft(3, '0');
        String fileName = '$suraStr$ayaStr.mp3';
        String localPath = '${reciterDir.path}/$fileName';
        String url = 'https://everyayah.com/data/$_currentReciterFolder/$fileName';
        
        if (!await File(localPath).exists()) {
          await dio.download(url, localPath);
        }
        
        _downloadProgress = i / totalAyahs;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error downloading sura: $e");
    } finally {
      _isDownloading = false;
      notifyListeners();
    }
  }

  /// التحقق من أن السورة محملة بالكامل
  Future<bool> isSuraDownloaded(int suraNumber, int totalAyahs) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      String suraStr = suraNumber.toString().padLeft(3, '0');
      final reciterDir = Directory('${dir.path}/$_currentReciterFolder');
      
      if (!await reciterDir.exists()) return false;

      for (int i = 1; i <= totalAyahs; i++) {
        String ayaStr = i.toString().padLeft(3, '0');
        String fileName = '$suraStr$ayaStr.mp3';
        String localPath = '${reciterDir.path}/$fileName';
        if (!await File(localPath).exists()) {
          return false;
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// حذف ملفات السورة المحملة
  Future<void> deleteSuraAudio(int suraNumber, int totalAyahs) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      String suraStr = suraNumber.toString().padLeft(3, '0');
      final reciterDir = Directory('${dir.path}/$_currentReciterFolder');
      
      if (!await reciterDir.exists()) return;

      for (int i = 1; i <= totalAyahs; i++) {
        String ayaStr = i.toString().padLeft(3, '0');
        String fileName = '$suraStr$ayaStr.mp3';
        String localPath = '${reciterDir.path}/$fileName';
        final file = File(localPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error deleting sura audio: $e");
    }
  }
  
  /// الإيقاف المؤقت
  Future<void> pause() async {
    await _player.pause();
  }

  /// إعداد وضع التكرار
  Future<void> setRepeatMode(LoopMode mode) async {
    _loopMode = mode;
    await _player.setLoopMode(mode);
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
