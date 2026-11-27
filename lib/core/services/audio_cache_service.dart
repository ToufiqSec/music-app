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
  static const List<String> _supportedExtensions = ['.m4a', '.mp3', '.opus', '.ogg', '.aac', '.wav'];
  static Directory? _cacheDir;
  static Directory? _downloadsDir;
  static final http.Client _sharedClient = http.Client();

  static String _safeFileKey(String trackId) {
    return trackId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  static Future<Directory> getDownloadsDirectory() async {
    if (_downloadsDir != null) return _downloadsDir!;
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/downloads');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _downloadsDir = dir;
    return dir;
  }

  static String _detectAudioExtension(String streamUrl) {
    final lower = streamUrl.toLowerCase();
    for (final ext in _supportedExtensions) {
      if (lower.contains(ext)) {
        return ext;
      }
    }
    return '.m4a';
  }

  static String _stripAudioExtension(String fileName) {
    for (final ext in _supportedExtensions) {
      if (fileName.endsWith(ext)) {
        return fileName.substring(0, fileName.length - ext.length);
      }
    }
    return fileName.replaceAll('.tmp', '');
  }

  static bool _isAudioCacheFile(String path) {
    return _supportedExtensions.any((ext) => path.endsWith(ext));
  }

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

  /// Returns File if track exists in user downloads or temporary cache, else null
  static Future<File?> getCachedTrackFile(String trackId) async {
    final safeKey = _safeFileKey(trackId);
    final downloadsDir = await getDownloadsDirectory();
    for (final ext in _supportedExtensions) {
      final dlFile = File('${downloadsDir.path}/$safeKey$ext');
      if (await dlFile.exists() && await dlFile.length() > 0) {
        return dlFile;
      }
    }

    final dir = await getCacheDirectory();
    for (final ext in _supportedExtensions) {
      final file = File('${dir.path}/$safeKey$ext');
      if (await file.exists() && await file.length() > 0) {
        // Touch file for LRU update asynchronously
        try {
          await file.setLastModified(DateTime.now());
        } catch (_) {}
        return file;
      }
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
    bool isUserDownload = false,
  }) async* {
    if (trackMetadata != null) {
      await TrackMetadataStore.saveTrackMetadata(trackMetadata);
    }

    final dir = isUserDownload ? await getDownloadsDirectory() : await getCacheDirectory();
    final safeKey = _safeFileKey(trackId);
    final ext = _detectAudioExtension(streamUrl);
    final targetFile = File('${dir.path}/$safeKey$ext');
    final tempFile = File('${dir.path}/$safeKey.tmp');

    http.StreamedResponse response;
    try {
      final request = http.Request('GET', Uri.parse(streamUrl));
      response = await _sharedClient.send(request);
    } catch (e) {
      return;
    }

    int totalBytes = response.contentLength ?? 0;
    if (totalBytes <= 0) {
      final headerLen = response.headers['content-length'];
      if (headerLen != null) {
        totalBytes = int.tryParse(headerLen) ?? 0;
      }
    }
    if (totalBytes <= 0) {
      final contentRange = response.headers['content-range'];
      if (contentRange != null) {
        final match = RegExp(r'/(\d+)').firstMatch(contentRange);
        if (match != null) {
          totalBytes = int.tryParse(match.group(1)!) ?? 0;
        }
      }
    }

    // Estimated total bytes if chunked / unknown length (Issue 5.3)
    final estimatedTotal = totalBytes > 0
        ? totalBytes
        : (trackMetadata != null && trackMetadata.durationSeconds > 0
            ? (trackMetadata.durationSeconds * 20000)
            : 5 * 1024 * 1024);

    int bytesReceived = 0;
    double lastYieldedProgress = 0.0;

    final sink = tempFile.openWrite();

    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        bytesReceived += chunk.length;
        if (totalBytes > 0) {
          final p = (bytesReceived / totalBytes).clamp(0.0, 1.0);
          if (p - lastYieldedProgress >= 0.01 || p == 1.0) {
            lastYieldedProgress = p;
            yield p;
          }
        } else {
          // Progress feedback for chunked CDNs without known content-length
          final p = (bytesReceived / estimatedTotal).clamp(0.05, 0.95);
          if (p - lastYieldedProgress >= 0.02) {
            lastYieldedProgress = p;
            yield p;
          }
        }
      }
      await sink.flush();
      await sink.close();

      if (await tempFile.exists()) {
        if (await targetFile.exists()) {
          try {
            await targetFile.delete();
          } catch (_) {}
        }
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
            final trackId = _stripAudioExtension(item.file.uri.pathSegments.last);
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
          .where((f) => _isAudioCacheFile(f.path))
          .map((f) => _stripAudioExtension(f.uri.pathSegments.last))
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
        if (_isAudioCacheFile(f.path)) {
          total += await f.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Calculates total size in megabytes
  static Future<double> getTotalCacheSizeMb() async {
    final bytes = await getCacheSizeBytes();
    return bytes / (1024 * 1024);
  }

  /// Clears all cached tracks asynchronously
  static Future<void> clearCache() async {
    try {
      final dir = await getCacheDirectory();
      final entities = await dir.list().where((e) => e is File).cast<File>().toList();
      for (final f in entities) {
        if (_isAudioCacheFile(f.path) || f.path.endsWith('.tmp')) {
          try {
            await f.delete();
            final trackId = _stripAudioExtension(f.uri.pathSegments.last);
            await TrackMetadataStore.removeTrackMetadata(trackId);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Alias for clearCache
  static Future<void> clearAllCache() async {
    await clearCache();
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
