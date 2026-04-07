import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
      androidStopForegroundOnPause: true, // Allow swipe to dismiss when paused
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );
}

class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player;
  final AudioPlayer _athanPlayer = AudioPlayer();
  AudioPlayer get player => _player;

  void Function()? onNext;
  void Function()? onPrevious;
  void Function()? onStopCustom;

  MyAudioHandler(this._player) {
    _athanPlayer.setReleaseMode(ReleaseMode.stop);
    _athanPlayer.setAudioContext(const AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: true,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.alarm,
        audioFocus: AndroidAudioFocus.gainTransientExclusive,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: [
          AVAudioSessionOptions.defaultToSpeaker,
          AVAudioSessionOptions.mixWithOthers,
        ],
      ),
    ));

    _athanPlayer.onPlayerComplete.listen((_) {
       if (mediaItem.value?.id == 'athan_alert') {
          WakelockPlus.disable();
          playbackState.add(playbackState.value.copyWith(
             playing: false,
             processingState: AudioProcessingState.idle,
          ));
          mediaItem.add(null);
       }
    });

    _player.onPlayerStateChanged.listen((state) {
      final playing = state == PlayerState.playing;
      
      playbackState.add(playbackState.value.copyWith(
        playing: playing,
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

    _player.onPositionChanged.listen((position) {
      playbackState.add(playbackState.value.copyWith(updatePosition: position));
    });

    _player.onDurationChanged.listen((duration) {
      final current = mediaItem.value;
      if (current != null) {
        mediaItem.add(current.copyWith(duration: duration));
      }
    });

    _player.onPlayerComplete.listen((_) {
      playbackState.add(playbackState.value.copyWith(
        playing: false,
        updatePosition: Duration.zero,
      ));
      // Auto-next will be handled in the provider, which also listens to onPlayerComplete
    });
  }

  void setMediaItem({
    required String id,
    required String title,
    required String artist,
    required Uri artUri,
  }) {
    mediaItem.add(MediaItem(
      id: id,
      album: "تلاوات القرآن",
      title: title,
      artist: artist,
      artUri: artUri,
    ));
    
    // Ensure the notification appears immediately while buffering
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
       // Always cancel the athan notification (id 888) so it doesn't linger
       try {
         final plugin = FlutterLocalNotificationsPlugin();
         await plugin.cancel(id: 888);
       } catch (_) {}
       return;
    }
  
    if (name == 'playAthan' && extras != null) {
      // 1. Extract values first as requested
      final String path = extras['path'] as String? ?? '';
      final String prayerName = extras['prayerName'] as String? ?? "الصلاة";
      final String title = extras['title'] as String? ?? 'حان الآن موعد أذان $prayerName';
      final String? activeTestKey = extras['activeTestKey'] as String?;
      
      // 2. Stop existing Athan if any
      await _athanPlayer.stop();
      
      // 3. Pause the main player gracefully without breaking queue
      if (_player.state == PlayerState.playing) {
        await _player.pause();
      }
      
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

      // 4. Play from Asset or File
      if (path.startsWith('assets/')) {
        // Audioplayers AssetSource expects path WITHOUT 'assets/' prefix
        final cleanPath = path.replaceFirst('assets/', '');
        return await _athanPlayer.play(AssetSource(cleanPath));
      } else {
        return await _athanPlayer.play(DeviceFileSource(path));
      }
    }
    return super.customAction(name, extras);
  }

  @override
  Future<void> play() => _player.resume();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    if (mediaItem.value?.id == 'athan_alert') {
      await _athanPlayer.stop();
      WakelockPlus.disable();
      playbackState.add(playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
      ));
      mediaItem.add(null);
      return;
    }

    await _player.stop();
    if (onStopCustom != null) onStopCustom!();
    await super.stop();
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
