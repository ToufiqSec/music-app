import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/music/models/music_models.dart';

class CachedQueryResult {
  final List<YoutubeTrack> tracks;
  final DateTime timestamp;

  CachedQueryResult({required this.tracks, required this.timestamp});

  bool isExpired(int cacheHours) {
    final expiryTime = timestamp.add(Duration(hours: cacheHours));
    return DateTime.now().isAfter(expiryTime);
  }
}

/// Persistent local cache store for Search and Mood queries.
/// Ensures 0ms instant repeated searches and resilient offline capability.
class SearchCacheStore {
  static final Map<String, CachedQueryResult> _memoryCache = {};
  static List<String> _recentSearches = [];
  static bool _initialized = false;

  /// Internal Mood Categorization Layer mapping moods to live queries (Global Rule 2)
  static final Map<String, String> moodQueryMap = {
    'Chill': 'chill acoustic peaceful relax vibes',
    'Lo-Fi': 'lofi hip hop beats to study relax',
    'Midnight': 'late night drive ambient synthwave',
    'Romance': 'romantic acoustic love songs melody',
    'Acoustic': 'acoustic unplugged guitar soothing',
    'Bollywood': 'bollywood top trending songs',
    'EDM': 'electronic dance festival hits energy',
    'Workout': 'workout pump gym motivation energy',
    'Focus': 'deep focus ambient study music instrumental',
    'Trending': 'top music hits viral trending',
  };

  static Future<File> _getCacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/search_cache_store.json');
  }

  static Future<File> _getRecentFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/recent_searches.json');
  }

  static Future<void> init() async {
    if (_initialized) return;
    try {
      // 1. Load Recent Searches
      final recentFile = await _getRecentFile();
      if (await recentFile.exists()) {
        final content = await recentFile.readAsString();
        final list = (json.decode(content) as List<dynamic>).map((e) => e.toString()).toList();
        _recentSearches = list;
      }

      // 2. Load Disk Cache
      final cacheFile = await _getCacheFile();
      if (await cacheFile.exists()) {
        final content = await cacheFile.readAsString();
        final map = json.decode(content) as Map<String, dynamic>;
        for (final entry in map.entries) {
          final query = entry.key;
          final data = entry.value as Map<String, dynamic>;
          final timestamp = DateTime.parse(data['timestamp'] as String);
          final rawTracks = data['tracks'] as List<dynamic>? ?? [];
          final tracks = rawTracks.map((t) => YoutubeTrack(
            id: t['id'] ?? '',
            title: t['title'] ?? '',
            artist: t['artist'] ?? '',
            thumbnailUrl: t['thumbnailUrl'] ?? '',
            durationSeconds: (t['durationSeconds'] as num?)?.toInt() ?? 0,
            audioStreamUrl: t['audioStreamUrl'],
          )).where((t) => t.id.isNotEmpty).toList();

          _memoryCache[query.toLowerCase()] = CachedQueryResult(
            tracks: tracks,
            timestamp: timestamp,
          );
        }
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[SearchCacheStore] Init error: $e');
    }
  }

  /// Retrieves cached result for a query
  static CachedQueryResult? getCached(String query) {
    return _memoryCache[query.trim().toLowerCase()];
  }

  /// Saves query results to cache and persists to disk
  static Future<void> putCached(String query, List<YoutubeTrack> tracks) async {
    final cleanQuery = query.trim().toLowerCase();
    _memoryCache[cleanQuery] = CachedQueryResult(
      tracks: tracks,
      timestamp: DateTime.now(),
    );

    // Debounced or async write
    try {
      final cacheFile = await _getCacheFile();
      final mapToSave = <String, dynamic>{};
      for (final entry in _memoryCache.entries) {
        mapToSave[entry.key] = {
          'timestamp': entry.value.timestamp.toIso8601String(),
          'tracks': entry.value.tracks.map((t) => {
            'id': t.id,
            'title': t.title,
            'artist': t.artist,
            'thumbnailUrl': t.thumbnailUrl,
            'durationSeconds': t.durationSeconds,
            'audioStreamUrl': t.audioStreamUrl,
          }).toList(),
        };
      }
      await cacheFile.writeAsString(json.encode(mapToSave));
    } catch (e) {
      debugPrint('[SearchCacheStore] Persist cache error: $e');
    }
  }

  /// Recent Searches List
  static List<String> getRecentSearches() => List.unmodifiable(_recentSearches);

  static Future<void> addRecentSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    _recentSearches.removeWhere((q) => q.toLowerCase() == clean.toLowerCase());
    _recentSearches.insert(0, clean);
    if (_recentSearches.length > 15) {
      _recentSearches = _recentSearches.sublist(0, 15);
    }

    try {
      final file = await _getRecentFile();
      await file.writeAsString(json.encode(_recentSearches));
    } catch (_) {}
  }

  static Future<void> removeRecentSearch(String query) async {
    _recentSearches.removeWhere((q) => q.toLowerCase() == query.trim().toLowerCase());
    try {
      final file = await _getRecentFile();
      await file.writeAsString(json.encode(_recentSearches));
    } catch (_) {}
  }

  static Future<void> clearRecentSearches() async {
    _recentSearches.clear();
    try {
      final file = await _getRecentFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  static Future<void> clearSearchCache() async {
    _memoryCache.clear();
    try {
      final file = await _getCacheFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
