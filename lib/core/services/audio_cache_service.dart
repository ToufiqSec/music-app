import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../features/music/models/music_models.dart';
import 'track_metadata_store.dart';

/// High-performance local disk caching service with progressive chunk downloading,
/// 1GB LRU pruning, and background stream progress tracking.
/// Fully asynchronous I/O to prevent main UI isolate frame drops.
class AudioCacheService {
  static const int maxCacheSizeBytes = 1024 * 1024 * 1024; // 1 GB
  static Directory? _cacheDir;
  static final http.Client _sharedClient = http.Client();

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
      // Touch file for LRU update asynchronously
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
  /// Saves metadata to TrackMetadataStore so it permanently appears in Downloads vault
  static Stream<double> downloadAndCacheTrack(
    String trackId,
    String streamUrl, {
    YoutubeTrack? trackMetadata,
  }) async* {
    if (trackMetadata != null) {
      await TrackMetadataStore.saveTrackMetadata(trackMetadata);
    }

    final dir = await getCacheDirectory();
    final targetFile = File('${dir.path}/$trackId.m4a');
    final tempFile = File('${dir.path}/$trackId.tmp');

    http.StreamedResponse response;
    try {
      final request = http.Request('GET', Uri.parse(streamUrl));
      response = await _sharedClient.send(request);
    } catch (e) {
      return;
    }

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
        // Run asynchronous LRU cache size check
        pruneLruCacheIfNeeded();
      }
    } catch (e) {
      await sink.close();
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  /// Automatically cleans up oldest files asynchronously when total cache exceeds 1 GB
  static Future<void> pruneLruCacheIfNeeded() async {
    try {
      final dir = await getCacheDirectory();
      final entities = await dir.list().where((e) => e is File).cast<File>().toList();

      int totalSize = 0;
      final fileList = <_CacheFileInfo>[];

      for (final file in entities) {
        final length = await file.length();
        totalSize += length;
        final lastModified = await file.lastModified();
        fileList.add(_CacheFileInfo(
          file: file,
          size: length,
          lastModified: lastModified,
        ));
      }

      if (totalSize > maxCacheSizeBytes) {
        fileList.sort((a, b) => a.lastModified.compareTo(b.lastModified));
        int bytesToDelete = totalSize - (maxCacheSizeBytes * 0.8).toInt();
        for (final item in fileList) {
          if (bytesToDelete <= 0) break;
          try {
            await item.file.delete();
            final trackId = item.file.uri.pathSegments.last.replaceAll('.m4a', '');
            await TrackMetadataStore.removeTrackMetadata(trackId);
            bytesToDelete -= item.size;
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Returns all cached track IDs asynchronously
  static Future<List<String>> getCachedTrackIds() async {
    try {
      final dir = await getCacheDirectory();
      final entities = await dir.list().where((e) => e is File).cast<File>().toList();
      return entities
          .where((f) => f.path.endsWith('.m4a'))
          .map((f) => f.uri.pathSegments.last.replaceAll('.m4a', ''))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Calculates total bytes in cache asynchronously without blocking UI thread
  static Future<int> getCacheSizeBytes() async {
    try {
      final dir = await getCacheDirectory();
      final entities = await dir.list().where((e) => e is File).cast<File>().toList();
      int total = 0;
      for (final f in entities) {
        if (f.path.endsWith('.m4a')) {
          total += await f.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Clears all cached tracks asynchronously
  static Future<void> clearCache() async {
    try {
      final dir = await getCacheDirectory();
      final entities = await dir.list().where((e) => e is File).cast<File>().toList();
      for (final f in entities) {
        if (f.path.endsWith('.m4a') || f.path.endsWith('.tmp')) {
          try {
            await f.delete();
            final trackId = f.uri.pathSegments.last.replaceAll('.m4a', '').replaceAll('.tmp', '');
            await TrackMetadataStore.removeTrackMetadata(trackId);
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
