import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';

class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player;
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
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
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
