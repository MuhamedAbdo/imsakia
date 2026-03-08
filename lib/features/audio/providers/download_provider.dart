import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/surah_audio.dart';
import '../models/reciter.dart';

class DownloadProvider with ChangeNotifier {
  final Dio _dio = Dio();
  SharedPreferences? _prefs;

  // Active download progress mappings -> map keys: 'reciterId_surahId'
  final Map<String, double> _downloadProgresses = {};

  // Completed local paths mappings -> map keys: 'reciterId_surahId'
  final Map<String, String> _localPaths = {};

  // Cancel tokens for active downloads
  final Map<String, CancelToken> _cancelTokens = {};

  bool _isDownloadingAll = false;
  bool get isDownloadingAll => _isDownloadingAll;

  DownloadProvider() {
    _initStorage();
  }

  Future<void> _initStorage() async {
    _prefs = await SharedPreferences.getInstance();

    // Load persisted local paths from memory
    final keys = _prefs!.getKeys();
    for (String key in keys) {
      if (key.startsWith('audio_download_')) {
        final path = _prefs!.getString(key);
        if (path != null && File(path).existsSync()) {
          final audioKey = key.replaceFirst('audio_download_', '');
          _localPaths[audioKey] = path;
        } else {
          // If file was deleted outside the app, clean up preferences
          _prefs!.remove(key);
        }
      }
    }
    notifyListeners();
  }

  String _getAudioKey(String reciterId, int surahId) {
    return '${reciterId}_$surahId';
  }

  bool isDownloading(String reciterId, int surahId) {
    return _downloadProgresses.containsKey(_getAudioKey(reciterId, surahId));
  }

  double getProgress(String reciterId, int surahId) {
    return _downloadProgresses[_getAudioKey(reciterId, surahId)] ?? 0.0;
  }

  String? getLocalPath(String reciterId, int surahId) {
    return _localPaths[_getAudioKey(reciterId, surahId)];
  }

  Future<void> downloadSurah(
    SurahAudio surah, {
    required Function() onStart,
    required Function() onSuccess,
    required Function(String error) onError,
  }) async {
    final audioKey = _getAudioKey(surah.reciterId, surah.id);

    if (_downloadProgresses.containsKey(audioKey)) {
      onError("التحميل قيد التقدم بالفعل");
      return;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      // Ensure specific folder mapping
      final audioDir = Directory(
        '${dir.path}/audio_downloads/${surah.reciterId}',
      );
      if (!audioDir.existsSync()) {
        audioDir.createSync(recursive: true);
      }

      final savePath = '${audioDir.path}/${surah.id}.mp3';
      final file = File(savePath);

      // If file already exists and is fully downloaded locally
      // (This serves as a backup check to avoid redundant downloads if SharedPreferences got wiped)
      if (file.existsSync() && _localPaths.containsKey(audioKey)) {
        onSuccess();
        return;
      }

      final cancelToken = CancelToken();
      _cancelTokens[audioKey] = cancelToken;
      _downloadProgresses[audioKey] = 0.0;
      notifyListeners();
      onStart();

      // Download file in chunks without blocking memory frame isolates
      await _dio.download(
        surah.audioUrl,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            _downloadProgresses[audioKey] = received / total;
            notifyListeners();
          }
        },
      );

      // Verify file and mark complete
      if (file.existsSync()) {
        _localPaths[audioKey] = savePath;
        _prefs?.setString('audio_download_$audioKey', savePath);
        _downloadProgresses.remove(audioKey);
        _cancelTokens.remove(audioKey);
        notifyListeners();
        onSuccess();
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        onError("تم إلغاء التحميل");
      } else {
        onError("فشل في تحميل السورة: $e");
      }

      // Cleanup broken downloads instantly
      _cleanupFailedDownload(audioKey, surah.reciterId, surah.id);
    }
  }

  Future<void> cancelDownload(String reciterId, int surahId) async {
    final audioKey = _getAudioKey(reciterId, surahId);
    if (_cancelTokens.containsKey(audioKey)) {
      _cancelTokens[audioKey]!.cancel("Cancelled by user");
      _cleanupFailedDownload(audioKey, reciterId, surahId);
    }
  }

  Future<void> downloadAll(
    Reciter reciter,
    List<SurahAudio> surahs, {
    required Function(String) onStatus,
    required Function() onComplete,
  }) async {
    if (_isDownloadingAll) return;
    _isDownloadingAll = true;
    notifyListeners();

    for (var surah in surahs) {
      if (!_isDownloadingAll) break; // Check if cancelled

      final audioKey = _getAudioKey(reciter.id, surah.id);
      if (_localPaths.containsKey(audioKey)) continue; // Already downloaded

      try {
        final completer = Completer<void>();
        
        await downloadSurah(
          surah,
          onStart: () => onStatus("جاري تحميل سورة ${surah.name}..."),
          onSuccess: () {
            if (!completer.isCompleted) completer.complete();
          },
          onError: (err) {
            onStatus("خطأ في ${surah.name}: $err");
            if (!completer.isCompleted) completer.complete(); // Resilience: continue even on error
          },
        );
        
        await completer.future;
      } catch (e) {
        onStatus("تم تخطي ${surah.name} بسبب خطأ");
        continue;
      }
    }

    _isDownloadingAll = false;
    notifyListeners();
    onComplete();
  }

  void cancelAllDownloads(String reciterId) {
    _isDownloadingAll = false;
    notifyListeners();

    // Cancel all active individual downloads for this reciter
    final keys = _cancelTokens.keys.where((k) => k.startsWith('${reciterId}_')).toList();
    for (var key in keys) {
      _cancelTokens[key]?.cancel("Cancelled bulk download");
      final parts = key.split('_');
      if (parts.length == 2) {
        _cleanupFailedDownload(key, parts[0], int.tryParse(parts[1]) ?? 0);
      }
    }
  }

  Future<void> _cleanupFailedDownload(
    String audioKey,
    String reciterId,
    int surahId,
  ) async {
    try {
      // Remove State
      _downloadProgresses.remove(audioKey);
      _cancelTokens.remove(audioKey);
      notifyListeners();

      // Delete partial corrupted files
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/audio_downloads/$reciterId/$surahId.mp3';
      final file = File(savePath);
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint("Cleanup Error: $e");
    }
  }

  Future<void> deleteDownloadedSurah(String reciterId, int surahId) async {
    final audioKey = _getAudioKey(reciterId, surahId);
    final path = _localPaths[audioKey];

    if (path != null) {
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
      _localPaths.remove(audioKey);
      _prefs?.remove('audio_download_$audioKey');
      notifyListeners();
    }
  }
}
