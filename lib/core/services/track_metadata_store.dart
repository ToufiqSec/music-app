import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../features/music/models/music_models.dart';

/// Manages offline track metadata and user library state (favorites, playlists, history).
class TrackMetadataStore {
  static const String _metadataFileName = 'track_metadata_vault.json';
  static const String _userLibraryFileName = 'user_library_vault.json';

  static Map<String, YoutubeTrack>? _cachedTracks;
  static Set<String>? _favoriteIds;
  static List<String>? _historyIds;
  static Map<String, List<String>>? _userPlaylists;
  static Map<String, int>? _playbackPositions;

  static Future<File> _getFile(String filename) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final file = File('${docsDir.path}/$filename');
    if (!await file.exists()) {
      await file.create(recursive: true);
      await file.writeAsString('{}');
    }
    return file;
  }

  /// Initialize store into memory
  static Future<void> init() async {
    try {
      final metaFile = await _getFile(_metadataFileName);
      final metaContent = await metaFile.readAsString();
      if (metaContent.trim().isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(metaContent);
        _cachedTracks = decoded.map(
          (k, v) => MapEntry(k, YoutubeTrack.fromJson(Map<String, dynamic>.from(v))),
        );
      } else {
        _cachedTracks = {};
      }
    } catch (_) {
      _cachedTracks = {};
    }

    try {
      final libFile = await _getFile(_userLibraryFileName);
      final libContent = await libFile.readAsString();
      if (libContent.trim().isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(libContent);
        _favoriteIds = Set<String>.from(decoded['favorites'] ?? []);
        _historyIds = List<String>.from(decoded['history'] ?? []);
        _userPlaylists = {};
        if (decoded['playlists'] is Map) {
          final pMap = Map<String, dynamic>.from(decoded['playlists']);
          pMap.forEach((key, val) {
            _userPlaylists![key] = List<String>.from(val ?? []);
          });
        }
        _playbackPositions = {};
        if (decoded['playback_positions'] is Map) {
          final posMap = Map<String, dynamic>.from(decoded['playback_positions']);
          posMap.forEach((key, val) {
            if (val is num) {
              _playbackPositions![key] = val.toInt();
            }
          });
        }
      } else {
        _favoriteIds = {};
        _historyIds = [];
        _userPlaylists = {};
        _playbackPositions = {};
      }
    } catch (_) {
      _favoriteIds = {};
      _historyIds = [];
      _userPlaylists = {};
      _playbackPositions = {};
    }
  }

  /// Saves or updates track metadata permanently
  static Future<void> saveTrackMetadata(YoutubeTrack track) async {
    if (_cachedTracks == null) await init();
    _cachedTracks![track.id] = track;
    try {
      final file = await _getFile(_metadataFileName);
      final mapToSave = _cachedTracks!.map((k, v) => MapEntry(k, v.toJson()));
      await file.writeAsString(jsonEncode(mapToSave));
    } catch (_) {}
  }

  /// Returns track metadata by ID
  static Future<YoutubeTrack?> getTrackMetadata(String trackId) async {
    if (_cachedTracks == null) await init();
    return _cachedTracks![trackId];
  }

  /// Returns all stored tracks
  static Future<List<YoutubeTrack>> getAllSavedTracks() async {
    if (_cachedTracks == null) await init();
    return _cachedTracks!.values.toList();
  }

  /// Deletes track metadata
  static Future<void> removeTrackMetadata(String trackId) async {
    if (_cachedTracks == null) await init();
    _cachedTracks!.remove(trackId);
    try {
      final file = await _getFile(_metadataFileName);
      final mapToSave = _cachedTracks!.map((k, v) => MapEntry(k, v.toJson()));
      await file.writeAsString(jsonEncode(mapToSave));
    } catch (_) {}
  }

  // --- Favorites Management ---
  static Future<Set<String>> getFavoriteIds() async {
    if (_favoriteIds == null) await init();
    return Set<String>.from(_favoriteIds!);
  }

  static Future<bool> isFavorite(String trackId) async {
    if (_favoriteIds == null) await init();
    return _favoriteIds!.contains(trackId);
  }

  static Future<bool> toggleFavorite(YoutubeTrack track) async {
    if (_favoriteIds == null) await init();
    final isFav = _favoriteIds!.contains(track.id);
    if (isFav) {
      _favoriteIds!.remove(track.id);
    } else {
      _favoriteIds!.add(track.id);
      await saveTrackMetadata(track);
    }
    await _saveLibraryVault();
    return !isFav;
  }

  // --- Listening History ---
  static Future<List<YoutubeTrack>> getListeningHistory() async {
    if (_historyIds == null) await init();
    final list = <YoutubeTrack>[];
    for (final id in _historyIds!) {
      if (_cachedTracks != null && _cachedTracks!.containsKey(id)) {
        list.add(_cachedTracks![id]!);
      }
    }
    return list;
  }

  static Future<void> addToHistory(YoutubeTrack track) async {
    if (_historyIds == null) await init();
    await saveTrackMetadata(track);
    _historyIds!.remove(track.id);
    _historyIds!.insert(0, track.id);
    if (_historyIds!.length > 50) {
      _historyIds = _historyIds!.sublist(0, 50);
    }
    await _saveLibraryVault();
  }

  // --- Playlists Management ---
  static Future<Map<String, List<String>>> getUserPlaylists() async {
    if (_userPlaylists == null) await init();
    return Map<String, List<String>>.from(_userPlaylists!);
  }

  static Future<void> createPlaylist(String name) async {
    if (_userPlaylists == null) await init();
    if (!_userPlaylists!.containsKey(name)) {
      _userPlaylists![name] = [];
      await _saveLibraryVault();
    }
  }

  static Future<void> addTrackToPlaylist(String playlistName, YoutubeTrack track) async {
    if (_userPlaylists == null) await init();
    await saveTrackMetadata(track);
    final list = _userPlaylists![playlistName] ?? [];
    if (!list.contains(track.id)) {
      list.add(track.id);
      _userPlaylists![playlistName] = list;
      await _saveLibraryVault();
    }
  }

  static Future<void> removeTrackFromPlaylist(String playlistName, String trackId) async {
    if (_userPlaylists == null) await init();
    final list = _userPlaylists![playlistName];
    if (list != null && list.contains(trackId)) {
      list.remove(trackId);
      _userPlaylists![playlistName] = list;
      await _saveLibraryVault();
    }
  }

  static Future<void> deletePlaylist(String playlistName) async {
    if (_userPlaylists == null) await init();
    if (_userPlaylists!.containsKey(playlistName)) {
      _userPlaylists!.remove(playlistName);
      await _saveLibraryVault();
    }
  }

  static Future<List<YoutubeTrack>> getPlaylistTracks(String playlistName) async {
    if (_userPlaylists == null) await init();
    final trackIds = _userPlaylists![playlistName] ?? [];
    final result = <YoutubeTrack>[];
    for (final id in trackIds) {
      final t = await getTrackMetadata(id);
      if (t != null) {
        result.add(t);
      }
    }
    return result;
  }

  // --- Long Audio Resume Positions ---
  static Future<int> getPlaybackPosition(String trackId) async {
    if (_playbackPositions == null) await init();
    return _playbackPositions![trackId] ?? 0;
  }

  static Future<void> savePlaybackPosition(String trackId, int seconds) async {
    if (_playbackPositions == null) await init();
    _playbackPositions![trackId] = seconds;
    await _saveLibraryVault();
  }

  static Future<void> clearPlaybackPosition(String trackId) async {
    if (_playbackPositions == null) await init();
    if (_playbackPositions!.containsKey(trackId)) {
      _playbackPositions!.remove(trackId);
      await _saveLibraryVault();
    }
  }

  static Future<void> _saveLibraryVault() async {
    try {
      final file = await _getFile(_userLibraryFileName);
      final data = {
        'favorites': _favoriteIds?.toList() ?? [],
        'history': _historyIds ?? [],
        'playlists': _userPlaylists ?? {},
        'playback_positions': _playbackPositions ?? {},
      };
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }
}
