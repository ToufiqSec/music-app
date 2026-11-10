import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// High-performance local disk caching service with progressive chunk downloading,
/// 1GB LRU pruning, and background stream progress tracking.
class AudioCacheService {
  static const int maxCacheSizeBytes = 1024 * 1024 * 1024; // 1 GB
  static Directory? _cacheDir;

  static Future<Directory> getCacheDirectory() async {
    if (_cacheDir != null) return _cacheDir!;
    final docsDir = await getApplicationDocumentsDirectory();
    final cache = Directory('${docsDir.path}/music_cache');
    if (!await cache.exists()) {
      await cache.create(recursive: true);
    }
    _cacheDir = cache;
    return cache;
  }

  /// Returns File if track exists on disk, else null
  static Future<File?> getCachedTrackFile(String trackId) async {
    final dir = await getCacheDirectory();
    final file = File('${dir.path}/$trackId.m4a');
    if (await file.exists() && await file.length() > 0) {
      // Touch file for LRU update
      try {
        await file.setLastModified(DateTime.now());
      } catch (_) {}
      return file;
    }
    return null;
  }

  /// Checks if a track is cached locally
  static Future<bool> isTrackCached(String trackId) async {
    final file = await getCachedTrackFile(trackId);
    return file != null;
  }

  /// Downloads an audio stream in the background with progress callback
  static Stream<double> downloadAndCacheTrack(String trackId, String streamUrl) async* {
    final dir = await getCacheDirectory();
    final targetFile = File('${dir.path}/$trackId.m4a');
    final tempFile = File('${dir.path}/$trackId.tmp');

    final request = http.Request('GET', Uri.parse(streamUrl));
    final response = await http.Client().send(request);

    final contentLength = response.contentLength ?? 0;
    int bytesReceived = 0;

    final sink = tempFile.openWrite();

    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        bytesReceived += chunk.length;
        if (contentLength > 0) {
          yield bytesReceived / contentLength;
        }
      }
      await sink.flush();
      await sink.close();

      if (await tempFile.exists()) {
        await tempFile.rename(targetFile.path);
        yield 1.0;
        // Run LRU cache size check
        pruneLruCacheIfNeeded();
      }
    } catch (e) {
      await sink.close();
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    }
  }

  /// Automatically cleans up oldest files when total cache exceeds 1 GB
  static Future<void> pruneLruCacheIfNeeded() async {
    try {
      final dir = await getCacheDirectory();
      final entities = dir.listSync().whereType<File>().toList();

      int totalSize = 0;
      final fileList = <_CacheFileInfo>[];

      for (final file in entities) {
        final length = file.lengthSync();
        totalSize += length;
        fileList.add(_CacheFileInfo(
          file: file,
          size: length,
          lastModified: file.lastModifiedSync(),
        ));
      }

      if (totalSize > maxCacheSizeBytes) {
        // Sort by last modified ascending (oldest first)
        fileList.sort((a, b) => a.lastModified.compareTo(b.lastModified));

        int bytesToDelete = totalSize - (maxCacheSizeBytes * 0.8).toInt(); // target 80% capacity
        for (final item in fileList) {
          if (bytesToDelete <= 0) break;
          try {
            item.file.deleteSync();
            bytesToDelete -= item.size;
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Returns all cached track IDs by inspecting filenames in cache directory
  static Future<List<String>> getCachedTrackIds() async {
    try {
      final dir = await getCacheDirectory();
      final entities = dir.listSync().whereType<File>().toList();
      return entities
          .where((f) => f.path.endsWith('.m4a'))
          .map((f) => f.uri.pathSegments.last.replaceAll('.m4a', ''))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Calculates total bytes in cache
  static Future<int> getCacheSizeBytes() async {
    try {
      final dir = await getCacheDirectory();
      final entities = dir.listSync().whereType<File>().toList();
      int total = 0;
      for (final f in entities) {
        if (f.path.endsWith('.m4a')) {
          total += f.lengthSync();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Clears all cached tracks
  static Future<void> clearCache() async {
    try {
      final dir = await getCacheDirectory();
      final entities = dir.listSync().whereType<File>().toList();
      for (final f in entities) {
        if (f.path.endsWith('.m4a') || f.path.endsWith('.tmp')) {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}

class _CacheFileInfo {
  final File file;
  final int size;
  final DateTime lastModified;

  _CacheFileInfo({
    required this.file,
    required this.size,
    required this.lastModified,
  });
}
