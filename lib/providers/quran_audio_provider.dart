import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class QuranAudioProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  // المجلد الافتراضي للمقرئ على موقع EveryAyah
  String _currentReciterFolder = 'Abdul_Basit_Murattal_64kbps';
  
  // رقم الآية الحالية (1-based)
  int? _currentPlayingAyaIndex;
  
  // رقم السورة الحالية التي يتم تشغيلها
  int? _currentSuraNumber;

  String get currentReciterFolder => _currentReciterFolder;
  int? get currentPlayingAyaIndex => _currentPlayingAyaIndex;
  int? get currentSuraNumber => _currentSuraNumber;
  AudioPlayer get player => _player;

  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;

  bool _isSingleAyah = false;
  int? _singleAyahNumber;

  QuranAudioProvider() {
    // الاستماع لتغير الآية (Index) في طابور التشغيل
    _player.currentIndexStream.listen((index) {
      if (index != null) {
        if (_isSingleAyah) {
          _currentPlayingAyaIndex = _singleAyahNumber;
        } else {
          // Index يبدأ من 0، والآيات تبدأ من 1
          _currentPlayingAyaIndex = index + 1;
        }
        notifyListeners();
      } else {
        _currentPlayingAyaIndex = null;
        notifyListeners();
      }
    });

    // الاستماع لحالة التشغيل لإعادة التعيين عند الانتهاء
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _currentPlayingAyaIndex = null;
        _currentSuraNumber = null;
        notifyListeners();
      }
    });

    // الاستماع لتغير حالة التشغيل (Play/Pause) لتحديث واجهة المستخدم
    _player.playingStream.listen((playing) {
      notifyListeners();
    });
  }

  /// تغيير المقرئ
  void setReciter(String reciterFolder) {
    _currentReciterFolder = reciterFolder;
    notifyListeners();
  }

  /// تحميل السورة وبدء التشغيل
  Future<void> loadAndPlaySura(int suraNumber, int totalAyahs, {int startAyah = 1}) async {
    try {
      _isSingleAyah = false;
      _currentSuraNumber = suraNumber;
      notifyListeners();

      final List<AudioSource> audioSources = [];
      String suraStr = suraNumber.toString().padLeft(3, '0');
      
      final dir = await getApplicationDocumentsDirectory();

      for (int i = 1; i <= totalAyahs; i++) {
        String ayaStr = i.toString().padLeft(3, '0');
        String fileName = '$suraStr$ayaStr.mp3';
        String localPath = '${dir.path}/$_currentReciterFolder/$fileName';
        String url = 'https://everyayah.com/data/$_currentReciterFolder/$fileName';
        
        if (await File(localPath).exists()) {
          audioSources.add(AudioSource.uri(Uri.file(localPath)));
        } else {
          audioSources.add(AudioSource.uri(Uri.parse(url)));
        }
      }

      // تعيين المصدر للمشغل وبدء التشغيل مع تحديد نقطة البداية
      await _player.setAudioSources(audioSources, initialIndex: startAyah - 1);
      _player.play();
    } catch (e) {
      debugPrint("Error loading sura audio: $e");
    }
  }

  /// تحميل وتشغيل آية واحدة
  Future<void> playSingleAyah(int suraNumber, int ayaNumber) async {
    try {
      _isSingleAyah = true;
      _singleAyahNumber = ayaNumber;
      _currentSuraNumber = suraNumber;
      _currentPlayingAyaIndex = ayaNumber;
      notifyListeners();

      String suraStr = suraNumber.toString().padLeft(3, '0');
      String ayaStr = ayaNumber.toString().padLeft(3, '0');
      String fileName = '$suraStr$ayaStr.mp3';
      
      final dir = await getApplicationDocumentsDirectory();
      String localPath = '${dir.path}/$_currentReciterFolder/$fileName';
      String url = 'https://everyayah.com/data/$_currentReciterFolder/$fileName';

      if (await File(localPath).exists()) {
        await _player.setAudioSource(AudioSource.uri(Uri.file(localPath)));
      } else {
        await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));
      }
      _player.play();
    } catch (e) {
      debugPrint("Error loading single ayah audio: $e");
    }
  }

  /// إيقاف التشغيل
  Future<void> stop() async {
    await _player.stop();
    _currentSuraNumber = null;
    _currentPlayingAyaIndex = null;
    notifyListeners();
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

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
