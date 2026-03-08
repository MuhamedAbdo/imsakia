import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';

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
    ),
  );
}

class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player;
  AudioPlayer get player => _player;

  void Function()? onNext;
  void Function()? onPrevious;
  void Function()? onStopCustom;

  MyAudioHandler(this._player) {
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
  Future<void> play() => _player.resume();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
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
