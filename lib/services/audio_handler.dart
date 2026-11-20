import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../core/services/playback_resolver.dart';

/// Background Audio Handler using audio_service and just_audio.
class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  MyAudioHandler() {
    _init();
  }

  AudioPlayer get player => _player;

  void _init() {
    _player.playbackEventStream.listen(_broadcastState);

    _player.durationStream.listen((duration) {
      final index = _player.currentIndex;
      final newQueue = queue.value;
      if (index != null && index < newQueue.length && duration != null) {
        final currentItem = newQueue[index];
        mediaItem.add(currentItem.copyWith(duration: duration));
      }
    });

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
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState] ?? AudioProcessingState.idle,
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

  Future<void> Function()? onSkipToNext;
  Future<void> Function()? onSkipToPrevious;

  @override
  Future<void> skipToNext() async {
    if (onSkipToNext != null) {
      await onSkipToNext!();
    } else {
      await _player.seekToNext();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (onSkipToPrevious != null) {
      await onSkipToPrevious!();
    } else {
      await _player.seekToPrevious();
    }
  }

  /// Play a single direct stream or local file
  Future<void> playTrackUrl(MediaItem item, String resolvedUrl) async {
    mediaItem.add(item);
    queue.add([item]);

    // Reset player before setting source to prevent native abortion / socket lock (Requirement A2.3)
    try {
      if (_player.playing) {
        await _player.pause();
      }
      await _player.stop();
    } catch (_) {}

    try {
      var safeUrl = PlaybackResolver.upgradeToHttps(resolvedUrl.trim());

      final isRemote = safeUrl.startsWith('http://') || safeUrl.startsWith('https://');
      if (!isRemote && File(safeUrl).existsSync()) {
        await _player.setFilePath(safeUrl);
      } else {
        // Pre-resolve multi-hop redirect podcast enclosures if passed directly
        if (isRemote && (safeUrl.contains('podtrac.com') || safeUrl.contains('spreaker.com'))) {
          final preResolved = await PlaybackResolver.resolveFinalAudioUrl(safeUrl);
          if (preResolved != null && preResolved.isNotEmpty) {
            safeUrl = preResolved;
          }
        }

        final isYouTubeStream = safeUrl.contains('googlevideo.com') ||
            safeUrl.contains('youtube.com') ||
            safeUrl.contains('youtu.be');

        final headers = <String, String>{
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        };
        // Only set Referer for YouTube servers to avoid CORS/403 blocks on podcast and audio drama CDNs
        if (isYouTubeStream) {
          headers['Referer'] = 'https://www.youtube.com/';
        }

        await _player.setUrl(
          safeUrl,
          headers: headers,
        ).timeout(const Duration(seconds: 30));
      }
      // Guarantee full audible volume immediately
      await _player.setVolume(1.0);
      await _player.play();
    } catch (e) {
      await _player.stop();
      rethrow;
    }
  }

  /// Smoothly fades volume up or down over [duration] to prevent harsh audio pops or clicks (Issue 8)
  Future<void> fadeVolume(double targetVolume, Duration duration) async {
    final startVolume = _player.volume;
    final delta = targetVolume - startVolume;
    if (delta.abs() < 0.01 || duration.inMilliseconds <= 0) {
      await _player.setVolume(targetVolume);
      return;
    }

    const steps = 15;
    final stepDuration = Duration(milliseconds: duration.inMilliseconds ~/ steps);
    for (int i = 1; i <= steps; i++) {
      final v = (startVolume + (delta * (i / steps))).clamp(0.0, 1.0);
      await _player.setVolume(v);
      await Future.delayed(stepDuration);
    }
    await _player.setVolume(targetVolume);
  }
}
