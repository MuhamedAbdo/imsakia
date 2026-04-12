import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../services/prayer_times_service.dart';

MyAudioHandler? audioHandler;

Future<void> initAudioService() async {
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    return;
  }
  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(AudioPlayer()),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.ryanheise.bg_audio.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );
}

class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player;
  final AudioPlayer _athanPlayer = AudioPlayer();
  AudioPlayer get player => _player;
  bool _isStopping = false;

  void Function()? onNext;
  void Function()? onPrevious;
  void Function()? onStopCustom;

  MyAudioHandler(this._player) {
    // 🛡️ Athan Player Initialization (Session config handled in playAthan)

    // Handle Athan Completion
    _athanPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mediaItem.value?.id == 'athan_alert') {
          WakelockPlus.disable();
          playbackState.add(playbackState.value.copyWith(
            playing: false,
            processingState: AudioProcessingState.idle,
          ));
          mediaItem.add(null);
          PrayerTimesService.instance.updateWidgetData();
        }
      }
    });

    // 🎵 Main Player State Listeners
    _player.playerStateStream.listen((state) {
      final playing = state.playing;
      final processingState = {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[state.processingState]!;

      playbackState.add(playbackState.value.copyWith(
        playing: playing,
        processingState: processingState,
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.stop,
          MediaAction.playPause,
        },
      ));
    });

    _player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(updatePosition: position));
    });

    _player.durationStream.listen((duration) {
      final current = mediaItem.value;
      if (current != null && duration != null) {
        mediaItem.add(current.copyWith(duration: duration));
      }
    });

    _player.playbackEventStream.listen((event) {}, onError: (Object e, StackTrace st) {
      if (e is PlayerException) {
        debugPrint('JustAudio PlayerException: ${e.message}');
      } else {
        debugPrint('JustAudio Error: $e');
      }
    });
  }

  void setMediaItem({
    required String id,
    required String title,
    required String artist,
    required Uri artUri,
  }) async {
    // 🛡️ تصفير مشغل الأذان عند البدء في السور لضمان تحرير الموارد
    _athanPlayer.stop();

    // 📻 Configure session for music playback
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    mediaItem.add(MediaItem(
      id: id,
      album: "تلاوات القرآن",
      title: title,
      artist: artist,
      artUri: artUri,
    ));
    
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.buffering,
      playing: true,
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.pause,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
    ));
  }

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'stopAthan') {
       if (mediaItem.value?.id == 'athan_alert') {
         await stop();
       }
        try {
          final plugin = FlutterLocalNotificationsPlugin();
          await plugin.cancel(id: 888);
          await PrayerTimesService.instance.updateWidgetData();
        } catch (_) {}
        return;
    }
  
    if (name == 'playAthan' && extras != null) {
      final String path = extras['path'] as String? ?? '';
      final String prayerName = extras['prayerName'] as String? ?? "الصلاة";
      final String title = extras['title'] as String? ?? 'حان الآن موعد أذان $prayerName';
      final String? activeTestKey = extras['activeTestKey'] as String?;
      
      // 🛡️ إيقاف كافة المحركات (Stop وليس Pause) لضمان تحرير الموارد في شاومي
      _athanPlayer.stop();
      _player.stop();
      
      // 🚨 Configure session for Alarm (High priority)
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.sonification,
          usage: AndroidAudioUsage.alarm,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientExclusive,
        androidWillPauseWhenDucked: true,
      ));

      WakelockPlus.enable();

      mediaItem.add(MediaItem(
        id: 'athan_alert',
        album: "تنبيه الأذان",
        title: title,
        artist: "زاد",
        extras: {'activeTestKey': activeTestKey}, 
      ));
      
      playbackState.add(playbackState.value.copyWith(
        playing: true,
        processingState: AudioProcessingState.ready,
        controls: [MediaControl.stop],
        systemActions: const {MediaAction.stop},
      ));

      if (path.startsWith('assets/')) {
        await _athanPlayer.setAudioSource(AudioSource.asset(path));
      } else {
        await _athanPlayer.setAudioSource(AudioSource.file(path));
      }
      return await _athanPlayer.play();
    }
    return super.customAction(name, extras);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    if (_isStopping) return;
    _isStopping = true;

    try {
      // 1️⃣ تحديث الحالة فوراً للواجهة (UI First)
      playbackState.add(playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
      ));

      // 2️⃣ إيقاف المحركات بدون انتظار (Non-blocking)
      _player.stop(); // Non-blocking
      _athanPlayer.stop(); // Non-blocking
      
      if (mediaItem.value?.id == 'athan_alert') {
        WakelockPlus.disable();
      }

      mediaItem.add(null);
      if (onStopCustom != null) onStopCustom!();
      
      // ✅ ملاحظة: لا نستدعي super.stop() هنا لمنع الـ Stack Overflow المتكرر
    } finally {
      _isStopping = false;
    }
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (onNext != null) onNext!();
  }

  @override
  Future<void> skipToPrevious() async {
    if (onPrevious != null) onPrevious!();
  }
}
