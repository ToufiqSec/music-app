import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../features/music/models/music_models.dart';
import '../core/services/audio_cache_service.dart';
import '../core/services/youtube_music_service.dart';
import '../core/services/track_metadata_store.dart';
import '../core/services/supabase_service.dart';
import '../services/audio_handler.dart';

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
  Timer? _backgroundCacheTimer;

  // Download states for offline tracks
  final Map<String, double> _downloadProgress = {};
  StreamSubscription<double>? _currentDownloadSubscription;

  // Persistent Favorites & Playlists state
  Set<String> _favoriteIds = {};
  List<YoutubeTrack> _historyTracks = [];
  Map<String, List<String>> _userPlaylists = {};

  AudioProvider(this._audioHandler) {
    _initListeners();
    _loadUserLibrary();
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
  Set<String> get favoriteIds => _favoriteIds;
  List<YoutubeTrack> get historyTracks => _historyTracks;
  Map<String, List<String>> get userPlaylists => _userPlaylists;

  bool isTrackLiked(String trackId) => _favoriteIds.contains(trackId);

  Future<void> _loadUserLibrary() async {
    await TrackMetadataStore.init();
    _favoriteIds = await TrackMetadataStore.getFavoriteIds();
    _historyTracks = await TrackMetadataStore.getListeningHistory();
    _userPlaylists = await TrackMetadataStore.getUserPlaylists();
    notifyListeners();

    // If authenticated with Supabase, sync down cloud data to local disk cache
    if (SupabaseService.isAuthenticated) {
      SupabaseService.syncDownAllUserData().then((_) async {
        _favoriteIds = await TrackMetadataStore.getFavoriteIds();
        _historyTracks = await TrackMetadataStore.getListeningHistory();
        _userPlaylists = await TrackMetadataStore.getUserPlaylists();
        notifyListeners();
      });
    }
  }

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

    // Auto-advance or Repeat One loop on completion
    _audioHandler.player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (_repeatMode == RepeatMode.one && _currentTrack != null) {
          seekTo(Duration.zero);
          _audioHandler.play();
        } else {
          playNext();
        }
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
      final url = (nextTrack.audioStreamUrl != null && nextTrack.audioStreamUrl!.isNotEmpty)
          ? nextTrack.audioStreamUrl
          : await _musicService.getAudioStreamUrl(nextTrack.id);
      if (url != null && !await AudioCacheService.isTrackCached(nextTrack.id)) {
        // Pre-cache next track into disk silently with metadata
        AudioCacheService.downloadAndCacheTrack(
          nextTrack.id,
          url,
          trackMetadata: nextTrack,
        ).listen(null, onError: (_) {});
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

    // Record to listening history
    TrackMetadataStore.addToHistory(track).then((_) {
      TrackMetadataStore.getListeningHistory().then((h) {
        _historyTracks = h;
        notifyListeners();
      });
    });
    SupabaseService.syncAddListeningHistory(track).catchError((_) {});

    try {
      // 1. Resolve stream or local file path
      final cached = await AudioCacheService.getCachedTrackFile(track.id);
      String? resolvedUrl;
      if (cached != null) {
        resolvedUrl = cached.path;
      } else if (track.audioStreamUrl != null && track.audioStreamUrl!.isNotEmpty) {
        resolvedUrl = track.audioStreamUrl;
      } else {
        resolvedUrl = await _musicService.getAudioStreamUrl(track.id);
      }

      if (resolvedUrl == null) {
        throw Exception('Unable to resolve audio stream for track ${track.title}');
      }

      // 2. Play immediately via AudioHandler
      await _audioHandler.playTrackUrl(track.toMediaItem(), resolvedUrl);

      // 3. Network protocol check (robust for Windows & Unix)
      // Debounce background caching by 8s so initial stream buffer is never starved
      final isRemote = resolvedUrl.startsWith('http://') || resolvedUrl.startsWith('https://');
      if (isRemote && !await AudioCacheService.isTrackCached(track.id)) {
        _backgroundCacheTimer?.cancel();
        _backgroundCacheTimer = Timer(const Duration(seconds: 8), () async {
          if (_currentTrack?.id == track.id && _isPlaying) {
            _currentDownloadSubscription?.cancel();
            _currentDownloadSubscription = AudioCacheService.downloadAndCacheTrack(
              track.id,
              resolvedUrl!,
              trackMetadata: track,
            ).listen(null, onError: (_) {});
          }
        });
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

  /// Persistent Favorite toggle
  Future<bool> toggleFavorite(YoutubeTrack track) async {
    final result = await TrackMetadataStore.toggleFavorite(track);
    _favoriteIds = await TrackMetadataStore.getFavoriteIds();
    notifyListeners();
    SupabaseService.syncToggleLikedSong(track, result).catchError((_) {});
    return result;
  }

  /// Playlist management
  Future<void> createPlaylist(String name) async {
    await TrackMetadataStore.createPlaylist(name);
    _userPlaylists = await TrackMetadataStore.getUserPlaylists();
    notifyListeners();
    SupabaseService.syncCreatePlaylist(name).catchError((_) {});
  }

  Future<void> addTrackToPlaylist(String playlistName, YoutubeTrack track) async {
    await TrackMetadataStore.addTrackToPlaylist(playlistName, track);
    _userPlaylists = await TrackMetadataStore.getUserPlaylists();
    notifyListeners();
    SupabaseService.syncAddSongToPlaylist(playlistName, track).catchError((_) {});
  }

  Future<void> removeTrackFromPlaylist(String playlistName, String trackId) async {
    await TrackMetadataStore.removeTrackFromPlaylist(playlistName, trackId);
    _userPlaylists = await TrackMetadataStore.getUserPlaylists();
    notifyListeners();
    SupabaseService.syncRemoveSongFromPlaylist(playlistName, trackId).catchError((_) {});
  }

  Future<void> deletePlaylist(String playlistName) async {
    await TrackMetadataStore.deletePlaylist(playlistName);
    _userPlaylists = await TrackMetadataStore.getUserPlaylists();
    notifyListeners();
    SupabaseService.syncDeletePlaylist(playlistName).catchError((_) {});
  }

  Future<void> reloadUserLibrary() async {
    await _loadUserLibrary();
  }

  Future<List<YoutubeTrack>> getPlaylistTracks(String playlistName) async {
    final list = await TrackMetadataStore.getPlaylistTracks(playlistName);
    return list;
  }

  /// Downloads a track for offline storage with progress tracking & metadata preservation
  Future<void> downloadTrackForOffline(YoutubeTrack track) async {
    if (await AudioCacheService.isTrackCached(track.id)) return;

    final streamUrl = (track.audioStreamUrl != null && track.audioStreamUrl!.isNotEmpty)
        ? track.audioStreamUrl
        : await _musicService.getAudioStreamUrl(track.id);
    if (streamUrl == null) return;

    _downloadProgress[track.id] = 0.0;
    notifyListeners();

    AudioCacheService.downloadAndCacheTrack(
      track.id,
      streamUrl,
      trackMetadata: track,
    ).listen(
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
    _backgroundCacheTimer?.cancel();
    _currentDownloadSubscription?.cancel();
    _musicService.dispose();
    super.dispose();
  }
}
