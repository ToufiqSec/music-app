import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/song_model.dart';
import '../services/audio_handler.dart';

class ProgressBarState {
  final Duration current;
  final Duration buffered;
  final Duration total;

  ProgressBarState({
    required this.current,
    required this.buffered,
    required this.total,
  });
}

class PlayerProvider extends ChangeNotifier {
  final MyAudioHandler _audioHandler;
  final OnAudioQuery _audioQuery = OnAudioQuery();

  List<SongModelItem> _localSongs = [];
  List<SongModelItem> _onlineSongs = [];
  List<SongModelItem> _playlist = [];
  SongModelItem? _currentSong;

  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isShuffle = false;
  LoopMode _loopMode = LoopMode.off;

  ProgressBarState _progress = ProgressBarState(
    current: Duration.zero,
    buffered: Duration.zero,
    total: Duration.zero,
  );

  PlayerProvider(this._audioHandler) {
    _initListeners();
    _loadSampleOnlineSongs();
  }

  // Getters
  List<SongModelItem> get localSongs => _localSongs;
  List<SongModelItem> get onlineSongs => _onlineSongs;
  List<SongModelItem> get playlist => _playlist;
  SongModelItem? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  bool get isShuffle => _isShuffle;
  LoopMode get loopMode => _loopMode;
  ProgressBarState get progress => _progress;

  void _initListeners() {
    // Playback state updates
    _audioHandler.playbackState.listen((playbackState) {
      _isPlaying = playbackState.playing;
      _isLoading = playbackState.processingState == AudioProcessingState.loading ||
          playbackState.processingState == AudioProcessingState.buffering;
      notifyListeners();
    });

    // Current MediaItem updates
    _audioHandler.mediaItem.listen((mediaItem) {
      if (mediaItem != null) {
        _currentSong = SongModelItem.fromMediaItem(mediaItem);
        _progress = ProgressBarState(
          current: _progress.current,
          buffered: _progress.buffered,
          total: mediaItem.duration ?? Duration.zero,
        );
        notifyListeners();
      }
    });

    // Position updates from just_audio
    _audioHandler.player.positionStream.listen((position) {
      _progress = ProgressBarState(
        current: position,
        buffered: _audioHandler.player.bufferedPosition,
        total: _audioHandler.player.duration ?? _progress.total,
      );
      notifyListeners();
    });
  }

  // Request storage / audio permissions and query device files
  Future<void> fetchLocalSongs() async {
    _isLoading = true;
    notifyListeners();

    try {
      bool permissionGranted = false;
      if (await Permission.audio.request().isGranted) {
        permissionGranted = true;
      } else if (await Permission.storage.request().isGranted) {
        permissionGranted = true;
      }

      if (permissionGranted) {
        final songs = await _audioQuery.querySongs(
          sortType: null,
          orderType: OrderType.ASC_OR_SMALLER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );

        _localSongs = songs.map((s) {
          return SongModelItem(
            id: s.id.toString(),
            title: s.title,
            artist: s.artist ?? '<unknown>',
            album: s.album ?? '<unknown>',
            duration: Duration(milliseconds: s.duration ?? 0),
            uri: s.uri ?? '',
            isLocal: true,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Error fetching local songs: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load sample royalty-free streaming tracks
  void _loadSampleOnlineSongs() {
    _onlineSongs = [
      SongModelItem(
        id: 'online_1',
        title: 'Acoustic Breeze',
        artist: 'Benjamin Tissot',
        album: 'Bensound Royalty Free',
        duration: const Duration(minutes: 2, seconds: 37),
        uri: 'https://www.bensound.com/bensound-music/bensound-acousticbreeze.mp3',
        artUri: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500',
        isLocal: false,
      ),
      SongModelItem(
        id: 'online_2',
        title: 'Sunny',
        artist: 'Benjamin Tissot',
        album: 'Bensound Royalty Free',
        duration: const Duration(minutes: 2, seconds: 20),
        uri: 'https://www.bensound.com/bensound-music/bensound-sunny.mp3',
        artUri: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500',
        isLocal: false,
      ),
      SongModelItem(
        id: 'online_3',
        title: 'Creative Minds',
        artist: 'Benjamin Tissot',
        album: 'Bensound Royalty Free',
        duration: const Duration(minutes: 2, seconds: 27),
        uri: 'https://www.bensound.com/bensound-music/bensound-creativeminds.mp3',
        artUri: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500',
        isLocal: false,
      ),
    ];
    notifyListeners();
  }

  // Play a song from a given list
  Future<void> playSong(SongModelItem song, List<SongModelItem> list) async {
    _playlist = list;
    final mediaItems = list.map((s) => s.toMediaItem()).toList();
    final index = list.indexWhere((s) => s.id == song.id);

    _currentSong = song;
    notifyListeners();

    await _audioHandler.setAudioSource(mediaItems, initialIndex: index >= 0 ? index : 0);
    await _audioHandler.play();
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await _audioHandler.pause();
    } else {
      await _audioHandler.play();
    }
  }

  Future<void> seek(Duration position) async {
    await _audioHandler.seek(position);
  }

  Future<void> skipNext() async {
    await _audioHandler.skipToNext();
  }

  Future<void> skipPrevious() async {
    await _audioHandler.skipToPrevious();
  }

  Future<void> toggleShuffle() async {
    _isShuffle = !_isShuffle;
    await _audioHandler.player.setShuffleModeEnabled(_isShuffle);
    notifyListeners();
  }

  Future<void> toggleLoopMode() async {
    if (_loopMode == LoopMode.off) {
      _loopMode = LoopMode.all;
    } else if (_loopMode == LoopMode.all) {
      _loopMode = LoopMode.one;
    } else {
      _loopMode = LoopMode.off;
    }
    await _audioHandler.player.setLoopMode(_loopMode);
    notifyListeners();
  }
}
