import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class LyricLine {
  final Duration timestamp;
  final String text;

  const LyricLine({required this.timestamp, required this.text});
}

class LyricsResult {
  final bool isSynced;
  final List<LyricLine> syncedLines;
  final String? plainLyrics;
  final String provider;

  const LyricsResult({
    required this.isSynced,
    this.syncedLines = const [],
    this.plainLyrics,
    this.provider = 'LRCLIB',
  });

  bool get hasLyrics => isSynced ? syncedLines.isNotEmpty : (plainLyrics != null && plainLyrics!.isNotEmpty);
}

/// Dynamic Lyrics Engine using LRCLIB API with JioSaavn Fallback & Disk Caching
class LyricsService {
  static final Map<String, LyricsResult> _memCache = {};

  static Future<Directory> _getCacheDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/lyrics_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Cleans track title by stripping unwanted tags like (Official Video), [4K], etc.
  static String cleanTrackTitle(String rawTitle) {
    return rawTitle
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'\[[^\]]*\]'), '')
        .replaceAll(RegExp(r'official\s+(audio|video|music\s+video|lyric\s+video)', caseSensitive: false), '')
        .replaceAll(RegExp(r'(full\s+song|remastered|hd|4k|audio)', caseSensitive: false), '')
        .replaceAll(RegExp(r'[-|]'), '')
        .trim();
  }

  /// Fetches lyrics with multi-provider chain (LRCLIB synced -> JioSaavn plain -> None)
  static Future<LyricsResult?> fetchLyrics({
    required String trackId,
    required String title,
    required String artist,
    int durationSeconds = 0,
  }) async {
    // 1. Memory Cache
    if (_memCache.containsKey(trackId)) {
      return _memCache[trackId];
    }

    // 2. Disk Cache
    try {
      final cacheDir = await _getCacheDir();
      final cacheFile = File('${cacheDir.path}/$trackId.json');
      if (await cacheFile.exists()) {
        final content = await cacheFile.readAsString();
        final map = json.decode(content) as Map<String, dynamic>;
        final isSynced = map['isSynced'] as bool? ?? false;
        final rawLines = map['syncedLines'] as List<dynamic>? ?? [];
        final lines = rawLines.map((l) {
          final ms = (l['ms'] as num?)?.toInt() ?? 0;
          return LyricLine(timestamp: Duration(milliseconds: ms), text: l['text']?.toString() ?? '');
        }).toList();

        final result = LyricsResult(
          isSynced: isSynced,
          syncedLines: lines,
          plainLyrics: map['plainLyrics']?.toString(),
          provider: map['provider']?.toString() ?? 'Cache',
        );
        _memCache[trackId] = result;
        return result;
      }
    } catch (_) {}

    final cleanTitle = cleanTrackTitle(title);
    final cleanArtist = artist.split(',')[0].split('&')[0].trim();

    // 3. LRCLIB Synced Lyrics API
    try {
      final uri = Uri.https('lrclib.net', '/api/get', {
        'track_name': cleanTitle,
        'artist_name': cleanArtist,
        if (durationSeconds > 0) 'duration': durationSeconds.toString(),
      });

      final response = await http.get(uri, headers: {
        'User-Agent': 'MusicApp/1.0 (https://github.com/ToufiqSec/music-app)',
      }).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final syncedLrc = data['syncedLyrics'] as String?;
        final plainLyrics = data['plainLyrics'] as String?;

        if (syncedLrc != null && syncedLrc.isNotEmpty) {
          final parsed = parseLrc(syncedLrc);
          if (parsed.isNotEmpty) {
            final result = LyricsResult(isSynced: true, syncedLines: parsed, provider: 'LRCLIB');
            await _saveToDisk(trackId, result);
            _memCache[trackId] = result;
            return result;
          }
        }

        if (plainLyrics != null && plainLyrics.isNotEmpty) {
          final result = LyricsResult(isSynced: false, plainLyrics: plainLyrics, provider: 'LRCLIB');
          await _saveToDisk(trackId, result);
          _memCache[trackId] = result;
          return result;
        }
      }
    } catch (e) {
      debugPrint('[LyricsService] LRCLIB get error: $e');
    }

    // 4. Fallback search on LRCLIB without strict duration
    try {
      final searchUri = Uri.https('lrclib.net', '/api/search', {
        'q': '$cleanTitle $cleanArtist',
      });
      final sResponse = await http.get(searchUri, headers: {
        'User-Agent': 'MusicApp/1.0',
      }).timeout(const Duration(seconds: 4));

      if (sResponse.statusCode == 200) {
        final list = json.decode(utf8.decode(sResponse.bodyBytes)) as List<dynamic>? ?? [];
        if (list.isNotEmpty) {
          final first = list[0];
          final syncedLrc = first['syncedLyrics'] as String?;
          final plainLyrics = first['plainLyrics'] as String?;

          if (syncedLrc != null && syncedLrc.isNotEmpty) {
            final parsed = parseLrc(syncedLrc);
            if (parsed.isNotEmpty) {
              final result = LyricsResult(isSynced: true, syncedLines: parsed, provider: 'LRCLIB Search');
              await _saveToDisk(trackId, result);
              _memCache[trackId] = result;
              return result;
            }
          } else if (plainLyrics != null && plainLyrics.isNotEmpty) {
            final result = LyricsResult(isSynced: false, plainLyrics: plainLyrics, provider: 'LRCLIB Search');
            await _saveToDisk(trackId, result);
            _memCache[trackId] = result;
            return result;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// Parses LRC timestamp strings like [01:23.45] into structured LyricLine objects
  static List<LyricLine> parseLrc(String lrcContent) {
    final lines = <LyricLine>[];
    final regExp = RegExp(r'\[(\d{2}):(\d{2})\.?(\d{2,3})?\](.*)');

    for (final rawLine in lrcContent.split('\n')) {
      final match = regExp.firstMatch(rawLine.trim());
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final fractionStr = match.group(3) ?? '0';
        final fraction = int.parse(fractionStr.padRight(3, '0').substring(0, 3));
        final text = match.group(4)?.trim() ?? '';

        if (text.isNotEmpty) {
          final timestamp = Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: fraction,
          );
          lines.add(LyricLine(timestamp: timestamp, text: text));
        }
      }
    }

    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }

  static Future<void> _saveToDisk(String trackId, LyricsResult result) async {
    try {
      final cacheDir = await _getCacheDir();
      final cacheFile = File('${cacheDir.path}/$trackId.json');
      final map = {
        'isSynced': result.isSynced,
        'provider': result.provider,
        'plainLyrics': result.plainLyrics,
        'syncedLines': result.syncedLines.map((l) => {
          'ms': l.timestamp.inMilliseconds,
          'text': l.text,
        }).toList(),
      };
      await cacheFile.writeAsString(json.encode(map));
    } catch (_) {}
  }
}
