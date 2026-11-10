import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../../features/music/models/music_models.dart';
import '../../core/services/audio_cache_service.dart';
import '../../core/services/youtube_music_service.dart';
import '../../services/audio_handler.dart';

enum RepeatMode { off, all, one }

class AudioProvider extends ChangeNotifier {
  final MyAudioHandler _audioHandler;
  final YoutubeMusicService _musicService = YoutubeMusicService();

  YoutubeTrack? _currentTrack;
  List<YoutubeTrack> _playlistQueue = [];
  int _currentIndex = -1;

  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isShuffle = false;
  RepeatMode _repeatMode = RepeatMode.off;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _bufferedPosition = Duration.zero;

  // Track pre-fetch flag to avoid duplicate trigger per song
  bool _preFetchedNextTrack = false;
  Timer? _seekDebounceTimer;

  // Download states for offline tracks
  final Map<String, double> _downloadProgress = {};

  AudioProvider(this._audioHandler) {
    _initListeners();
  }

  // Getters
  YoutubeTrack? get currentTrack => _currentTrack;
  List<YoutubeTrack> get playlistQueue => _playlistQueue;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  bool get isShuffle => _isShuffle;
  RepeatMode get repeatMode => _repeatMode;
  Duration get position => _position;
  Duration get duration => _duration;
  Duration get bufferedPosition => _bufferedPosition;
  Map<String, double> get downloadProgress => _downloadProgress;
  YoutubeMusicService get musicService => _musicService;

  void _initListeners() {
    _audioHandler.playbackState.listen((state) {
      _isPlaying = state.playing;
      _isBuffering = state.processingState == AudioProcessingState.buffering ||
          state.processingState == AudioProcessingState.loading;
      notifyListeners();
    });

    _audioHandler.player.positionStream.listen((pos) {
      _position = pos;
      _checkAndPrefetchNextTrack(pos);
      notifyListeners();
    });

    _audioHandler.player.durationStream.listen((dur) {
      if (dur != null) {
        _duration = dur;
        notifyListeners();
      }
    });

    _audioHandler.player.bufferedPositionStream.listen((buffered) {
      _bufferedPosition = buffered;
      notifyListeners();
    });

    // Auto-advance to next track on completion
    _audioHandler.player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        playNext();
      }
    });
  }

  /// Gapless pre-fetching: when current track is at 80% duration, pre-resolve next track.
  void _checkAndPrefetchNextTrack(Duration currentPos) {
    if (_duration.inMilliseconds > 0 && !_preFetchedNextTrack) {
      final progressRatio = currentPos.inMilliseconds / _duration.inMilliseconds;
      if (progressRatio >= 0.80) {
        _preFetchedNextTrack = true;
        _prefetchNextInQueue();
      }
    }
  }

  Future<void> _prefetchNextInQueue() async {
    final nextIdx = _getNextIndex();
    if (nextIdx != null && nextIdx < _playlistQueue.length) {
      final nextTrack = _playlistQueue[nextIdx];
      final url = await _musicService.getAudioStreamUrl(nextTrack.id);
      if (url != null && !await AudioCacheService.isTrackCached(nextTrack.id)) {
        // Pre-cache next track into disk silently
        AudioCacheService.downloadAndCacheTrack(nextTrack.id, url).listen(
          null,
          onError: (_) {},
        );
      }
    }
  }

  int? _getNextIndex() {
    if (_playlistQueue.isEmpty || _currentIndex < 0) return null;
    if (_currentIndex + 1 < _playlistQueue.length) {
      return _currentIndex + 1;
    } else if (_repeatMode == RepeatMode.all) {
      return 0;
    }
    return null;
  }

  int? _getPreviousIndex() {
    if (_playlistQueue.isEmpty || _currentIndex < 0) return null;
    if (_currentIndex - 1 >= 0) {
      return _currentIndex - 1;
    } else if (_repeatMode == RepeatMode.all) {
      return _playlistQueue.length - 1;
    }
    return null;
  }

  /// Plays a track using the multi-tier zero-delay pipeline:
  /// Tier 3: Local cache -> Tier 1: JioSaavn -> Tier 2: YouTube
  Future<void> playTrack(YoutubeTrack track, [List<YoutubeTrack>? queue]) async {
    if (queue != null) {
      _playlistQueue = List.from(queue);
      _currentIndex = _playlistQueue.indexWhere((t) => t.id == track.id);
    } else if (!_playlistQueue.any((t) => t.id == track.id)) {
      _playlistQueue.add(track);
      _currentIndex = _playlistQueue.length - 1;
    }

    _currentTrack = track;
    _preFetchedNextTrack = false;
    _isBuffering = true;
    notifyListeners();

    try {
      // 1. Resolve stream or local file path
      final resolvedUrl = await _musicService.getAudioStreamUrl(track.id);
      if (resolvedUrl == null) {
        throw Exception('Unable to resolve audio stream for track ${track.title}');
      }

      // 2. Play immediately via AudioHandler
      await _audioHandler.playTrackUrl(track.toMediaItem(), resolvedUrl);

      // 3. If playing remote stream, stream-cache in background for future zero-delay offline playback
      if (!resolvedUrl.startsWith('/') && !await AudioCacheService.isTrackCached(track.id)) {
        AudioCacheService.downloadAndCacheTrack(track.id, resolvedUrl).listen(
          null,
          onError: (_) {},
        );
      }
    } catch (e) {
      debugPrint('Playback error: $e');
    } finally {
      _isBuffering = false;
      notifyListeners();
    }
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await _audioHandler.pause();
    } else {
      await _audioHandler.play();
    }
  }

  void seekTo(Duration targetPosition) {
    _position = targetPosition;
    notifyListeners();

    _seekDebounceTimer?.cancel();
    _seekDebounceTimer = Timer(const Duration(milliseconds: 150), () {
      _audioHandler.seek(targetPosition);
    });
  }

  Future<void> playNext() async {
    final nextIdx = _getNextIndex();
    if (nextIdx != null) {
      _currentIndex = nextIdx;
      await playTrack(_playlistQueue[nextIdx]);
    }
  }

  Future<void> playPrevious() async {
    final prevIdx = _getPreviousIndex();
    if (prevIdx != null) {
      _currentIndex = prevIdx;
      await playTrack(_playlistQueue[prevIdx]);
    }
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    if (_isShuffle && _playlistQueue.isNotEmpty) {
      _playlistQueue.shuffle();
      if (_currentTrack != null) {
        _currentIndex = _playlistQueue.indexWhere((t) => t.id == _currentTrack!.id);
      }
    }
    notifyListeners();
  }

  void toggleRepeatMode() {
    if (_repeatMode == RepeatMode.off) {
      _repeatMode = RepeatMode.all;
    } else if (_repeatMode == RepeatMode.all) {
      _repeatMode = RepeatMode.one;
    } else {
      _repeatMode = RepeatMode.off;
    }
    notifyListeners();
  }

  /// Downloads a track for offline storage with progress tracking
  Future<void> downloadTrackForOffline(YoutubeTrack track) async {
    if (await AudioCacheService.isTrackCached(track.id)) return;

    final streamUrl = await _musicService.getAudioStreamUrl(track.id);
    if (streamUrl == null) return;

    _downloadProgress[track.id] = 0.0;
    notifyListeners();

    AudioCacheService.downloadAndCacheTrack(track.id, streamUrl).listen(
      (progress) {
        _downloadProgress[track.id] = progress;
        notifyListeners();
      },
      onDone: () {
        _downloadProgress.remove(track.id);
        notifyListeners();
      },
      onError: (_) {
        _downloadProgress.remove(track.id);
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _seekDebounceTimer?.cancel();
    _musicService.dispose();
    super.dispose();
  }
}
