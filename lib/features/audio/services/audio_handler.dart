import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

MyAudioHandler? audioHandler;

Future<void> initAudioService() async {
  if (audioHandler != null) return;

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) return;

  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.ryanheise.bg_audio.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}

class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  final _player = AudioPlayer();
  bool _isTransitioning = false;

  void Function()? onNext;
  void Function()? onPrevious;
  void Function()? onStopCustom;

  MyAudioHandler() {
    // حل مشكلة Bad state: استبدال pipe بـ listen لتحديث الحالة بمرونة
    _player.playbackEventStream.map(_transformEvent).listen((state) {
      playbackState.add(state);
    });

    // مراقبة انتهاء السورة للانتقال التلقائي مع تسلسل آمن
    _player.processingStateStream.listen((state) {
      debugPrint('[AudioHandler] State Changed to: $state');
      if (state == ProcessingState.completed && !_isTransitioning) {
        if (onNext != null) {
          _isTransitioning = true;
          debugPrint('[AudioHandler] Triggering Next Track (Safe Mode)');
          // استخدام Future.microtask لتجنب حظر الحلقة البرمجية
          Future.microtask(() async {
            onNext!();
            await Future.delayed(const Duration(milliseconds: 600));
            _isTransitioning = false;
          });
        } else {
          stop();
        }
      }
    });

    // معالجة أخطاء المشغل (قاعدة الـ 98% للملفات غير المكتملة)
    _player.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace st) {
        if (e is PlayerException) {
          debugPrint('just_audio error: ${e.message}');
          final duration = _player.duration;
          final position = _player.position;
          if (duration != null && duration.inMilliseconds > 0) {
            final percent = position.inMilliseconds / duration.inMilliseconds;
            // إذا انقطع الاتصال في النهاية، نعتبرها سورة مكتملة وننتقل للتالي
            if (percent > 0.98 &&
                e.message?.contains("Connection closed") == true && 
                !_isTransitioning) {
              _isTransitioning = true;
              debugPrint("Connection closed near end, skipping to next (Safe Mode).");
              if (onNext != null) {
                Future.microtask(() async {
                  onNext!();
                  await Future.delayed(const Duration(milliseconds: 600));
                  _isTransitioning = false;
                });
              }
            }
          }
        }
      },
    );
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState] ?? AudioProcessingState.idle,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  /// تنقية حالة المشغل قبل تحميل ملف جديد لمنع التجميد
  Future<void> _prepareForNewSource() async {
    debugPrint('[AudioHandler] Preparing for new source...');
    try {
      if (_player.playing) {
        await _player.stop();
      }
    } catch (e) {
      debugPrint('[AudioHandler] Error in _prepareForNewSource: $e');
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    // تحديث الحالة يدوياً عند التوقف
    playbackState.add(
      playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
      ),
    );
    if (onStopCustom != null) onStopCustom!();
    return super.stop();
  }

  @override
  Future<void> skipToNext() async => onNext?.call();

  @override
  Future<void> skipToPrevious() async => onPrevious?.call();

  /// Handle Quran (URL/File)
  Future<void> playFromUrl(String url) async {
    try {
      await _prepareForNewSource();
      await _player.setUrl(url);
      await _player.play();
    } catch (e) {
      debugPrint("Error playing URL: $e");
    }
  }

  Future<void> playFromFile(String path) async {
    try {
      await _prepareForNewSource();
      await _player.setFilePath(path);
      await _player.play();
    } catch (e) {
      debugPrint("Error playing file: $e");
    }
  }

  /// Handle Radio (ICY/HLS streams)
  Future<void> playRadio(String url) async {
    try {
      await _prepareForNewSource();
      await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));
      await _player.play();
    } catch (e) {
      debugPrint("Error playing radio: $e");
    }
  }

  /// Handle Adhan (Assets)
  Future<void> playAsset(String assetPath) async {
    try {
      await _prepareForNewSource();
      await _player.setAsset(assetPath);
      await _player.play();
    } catch (e) {
      debugPrint("Error playing asset: $e");
    }
  }

  void setMediaItem({
    required String id,
    required String title,
    required String artist,
    required Uri artUri,
    String? album,
  }) {
    mediaItem.add(
      MediaItem(
        id: id,
        album: album ?? "مكتبة الصوتيات",
        title: title,
        artist: artist,
        artUri: artUri,
        duration: _player.duration,
      ),
    );
  }

  AudioPlayer get player => _player;
}
