import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/music/models/music_models.dart';

class HomeCachedData {
  final List<YoutubeTrack> quickPicks;
  final List<YoutubeTrack> carousel1;
  final List<YoutubeTrack> carousel2;
  final List<YoutubeTrack> carousel3;
  final List<YoutubeTrack> carousel4;
  final List<YoutubeTrack> carousel5;
  final List<YoutubeTrack> carousel6;
  final DateTime timestamp;

  const HomeCachedData({
    required this.quickPicks,
    required this.carousel1,
    required this.carousel2,
    required this.carousel3,
    required this.carousel4,
    required this.carousel5,
    required this.carousel6,
    required this.timestamp,
  });

  bool get isExpired {
    // 10-minute time-to-live cache (Phase 5)
    return DateTime.now().difference(timestamp) > const Duration(minutes: 10);
  }
}

/// 10-Minute Cache Store for Home Sections (Phase 5).
/// Enables instantaneous cold start (<2 seconds) with stale-while-revalidate pattern.
class HomeSectionCacheStore {
  static final Map<String, HomeCachedData> _memoryCache = {};
  static bool _initialized = false;

  static Future<File> _getCacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/home_sections_cache.json');
  }

  static Future<void> init() async {
    if (_initialized) return;
    try {
      final file = await _getCacheFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final rawMap = json.decode(content) as Map<String, dynamic>;

        for (final entry in rawMap.entries) {
          final filter = entry.key;
          final data = entry.value as Map<String, dynamic>;
          final timestamp = DateTime.parse(data['timestamp'] as String);

          List<YoutubeTrack> parseList(dynamic raw) {
            if (raw is! List) return [];
            return raw.map((item) => YoutubeTrack.fromJson(item as Map<String, dynamic>)).toList();
          }

          _memoryCache[filter] = HomeCachedData(
            quickPicks: parseList(data['quickPicks']),
            carousel1: parseList(data['carousel1']),
            carousel2: parseList(data['carousel2']),
            carousel3: parseList(data['carousel3']),
            carousel4: parseList(data['carousel4']),
            carousel5: parseList(data['carousel5']),
            carousel6: parseList(data['carousel6']),
            timestamp: timestamp,
          );
        }
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[HomeSectionCacheStore] Init error: $e');
    }
  }

  static HomeCachedData? getCached(String filter) {
    return _memoryCache[filter];
  }

  static Future<void> save(String filter, HomeCachedData data) async {
    _memoryCache[filter] = data;

    try {
      final file = await _getCacheFile();
      final mapToSave = <String, dynamic>{};

      for (final entry in _memoryCache.entries) {
        List<Map<String, dynamic>> serializeList(List<YoutubeTrack> tracks) {
          return tracks.map((t) => t.toJson()).toList();
        }

        mapToSave[entry.key] = {
          'timestamp': entry.value.timestamp.toIso8601String(),
          'quickPicks': serializeList(entry.value.quickPicks),
          'carousel1': serializeList(entry.value.carousel1),
          'carousel2': serializeList(entry.value.carousel2),
          'carousel3': serializeList(entry.value.carousel3),
          'carousel4': serializeList(entry.value.carousel4),
          'carousel5': serializeList(entry.value.carousel5),
          'carousel6': serializeList(entry.value.carousel6),
        };
      }

      await file.writeAsString(json.encode(mapToSave));
    } catch (e) {
      debugPrint('[HomeSectionCacheStore] Persist error: $e');
    }
  }

  static Future<void> clear() async {
    _memoryCache.clear();
    try {
      final file = await _getCacheFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
