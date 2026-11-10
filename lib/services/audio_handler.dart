import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  MyAudioHandler() {
    _init();
  }

  AudioPlayer get player => _player;

  void _init() {
    // Forward playback events from just_audio to audio_service
    _player.playbackEventStream.listen(_broadcastState);

    // Track position changes
    _player.durationStream.listen((duration) {
      final index = _player.currentIndex;
      final newQueue = queue.value;
      if (index != null && index < newQueue.length && duration != null) {
        final currentItem = newQueue[index];
        mediaItem.add(currentItem.copyWith(duration: duration));
      }
    });

    // Listen for current index changes to update current mediaItem
    _player.currentIndexStream.listen((index) {
      final newQueue = queue.value;
      if (index != null && index < newQueue.length) {
        mediaItem.add(newQueue[index]);
      }
    });
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
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
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ),
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  Future<void> setAudioSource(List<MediaItem> items, {int initialIndex = 0}) async {
    queue.add(items);
    final audioSourceList = ConcatenatingAudioSource(
      children: items.map((item) {
        final uri = item.extras?['uri'] as String? ?? '';
        final isLocal = item.extras?['isLocal'] as bool? ?? false;
        if (isLocal) {
          return AudioSource.uri(Uri.file(uri), tag: item);
        } else {
          return AudioSource.uri(Uri.parse(uri), tag: item);
        }
      }).toList(),
    );

    await _player.setAudioSource(
      audioSourceList,
      initialIndex: initialIndex,
      initialPosition: Duration.zero,
    );
  }
}
