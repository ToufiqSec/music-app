import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  final String latestVersion;
  final int latestVersionCode;
  final String releaseNotes;
  final String apkDownloadUrl;
  final int apkSizeBytes;
  final DateTime publishedAt;
  final String currentVersion;

  const UpdateInfo({
    required this.latestVersion,
    required this.latestVersionCode,
    required this.releaseNotes,
    required this.apkDownloadUrl,
    required this.apkSizeBytes,
    required this.publishedAt,
    required this.currentVersion,
  });

  String get formattedSize {
    if (apkSizeBytes <= 0) return '';
    final mb = apkSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class DownloadProgressState {
  final int bytesDownloaded;
  final int bytesTotal;
  final double progress;
  final String status; // 'downloading', 'completed', 'failed', 'cancelled'
  final String? filePath;
  final String? errorMessage;

  const DownloadProgressState({
    required this.bytesDownloaded,
    required this.bytesTotal,
    required this.progress,
    required this.status,
    this.filePath,
    this.errorMessage,
  });

  String get formattedProgress {
    final curMb = (bytesDownloaded / (1024 * 1024)).toStringAsFixed(1);
    final totMb = (bytesTotal / (1024 * 1024)).toStringAsFixed(1);
    final pct = (progress * 100).toInt();
    return '$pct% ($curMb MB / $totMb MB)';
  }
}

class AppUpdateService {
  static const String githubRepo = 'ToufiqSec/music-app';
  static const MethodChannel _channel =
      MethodChannel('com.toufiqsec.music_app/installer');

  // Configurable snooze duration when user clicks 'Later'
  static const Duration snoozeDuration = Duration(hours: 24);

  // Cached installed version info
  static String? _cachedVersionName;
  static int? _cachedVersionCode;

  // Active download tracking
  static int? _activeDownloadId;
  static Timer? _pollTimer;
  static StreamController<DownloadProgressState>? _progressController;

  /// Returns the dynamically resolved installed version (e.g. 1.0.0) from Android PackageManager.
  static Future<String> getInstalledVersionName() async {
    if (_cachedVersionName != null) return _cachedVersionName!;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getAppVersion');
      if (res != null) {
        _cachedVersionName = res['versionName']?.toString() ?? '1.0.0';
        _cachedVersionCode = (res['versionCode'] as num?)?.toInt() ?? 1;
        return _cachedVersionName!;
      }
    } catch (_) {}
    _cachedVersionName = '1.0.0';
    return _cachedVersionName!;
  }

  /// Returns current version code.
  static Future<int> getInstalledVersionCode() async {
    if (_cachedVersionCode != null) return _cachedVersionCode!;
    await getInstalledVersionName();
    return _cachedVersionCode ?? 1;
  }

  /// Synchronous fallback for display (initialized on launch)
  static String get currentVersionDisplay => _cachedVersionName ?? '1.0.0';
  static String get currentVersion => currentVersionDisplay;

  /// Background, failure-silent check for updates from GitHub Releases.
  /// Set [force] to true when user explicitly taps 'Check for Updates' in Profile Settings.
  static Future<UpdateInfo?> checkForUpdate({bool force = false}) async {
    try {
      final currentVersion = await getInstalledVersionName();

      final url = Uri.parse(
        'https://api.github.com/repos/$githubRepo/releases/latest',
      );

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'MusicApp-InAppUpdater',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final rawTag = data['tag_name']?.toString() ?? '';
      final cleanTag = rawTag.replaceAll(RegExp(r'[^0-9.]'), '');
      if (cleanTag.isEmpty) return null;

      // Check if remote version is strictly newer (or forced by user tap)
      final isNewer = isVersionNewer(cleanTag, currentVersion);
      if (!isNewer && !force) {
        // Clear any old snoozed version since app is now on or above it
        await _clearSnoozedVersion();
        return null;
      }

      // Check snooze unless forced by user click
      if (!force) {
        final isSnoozed = await _isVersionSnoozed(cleanTag);
        if (isSnoozed) return null;
      }

      // Locate release APK asset
      final assets = data['assets'] as List<dynamic>? ?? [];
      final apkAsset = assets.firstWhere(
        (a) => a['name'].toString().toLowerCase().endsWith('.apk'),
        orElse: () => null,
      );

      if (apkAsset == null) return null;

      final downloadUrl = apkAsset['browser_download_url']?.toString() ?? '';
      final size = apkAsset['size'] as int? ?? 0;
      final notes = _cleanReleaseNotes(data['body']?.toString());
      final published = DateTime.tryParse(data['published_at']?.toString() ?? '') ??
          DateTime.now();

      return UpdateInfo(
        latestVersion: cleanTag,
        latestVersionCode: 0,
        releaseNotes: notes,
        apkDownloadUrl: downloadUrl,
        apkSizeBytes: size,
        publishedAt: published,
        currentVersion: currentVersion,
      );
    } catch (e) {
      debugPrint('Silent update check caught: $e');
      return null;
    }
  }

  /// Compares semantic version components numerically.
  /// Handles e.g. 1.0.18 vs 1.0.17 or 1.1 vs 1.0.9.
  static bool isVersionNewer(String remote, String local) {
    try {
      final remoteParts = remote.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      final localParts = local.split('.').map((p) => int.tryParse(p) ?? 0).toList();

      final maxLen = remoteParts.length > localParts.length
          ? remoteParts.length
          : localParts.length;

      for (int i = 0; i < maxLen; i++) {
        final r = i < remoteParts.length ? remoteParts[i] : 0;
        final l = i < localParts.length ? localParts[i] : 0;
        if (r > l) return true;
        if (r < l) return false;
      }
    } catch (_) {}
    return false;
  }

  /// Downloads the APK using Android's native DownloadManager.
  /// Runs as an OS service: survives app switching, screen off, and shows native progress notification.
  static Stream<DownloadProgressState> startDownload(UpdateInfo info) {
    _progressController?.close();
    _progressController = StreamController<DownloadProgressState>.broadcast();
    _pollTimer?.cancel();

    _runDownloadFlow(info);

    return _progressController!.stream;
  }

  static Future<void> _runDownloadFlow(UpdateInfo info) async {
    final fileName = 'music-app-v${info.latestVersion}.apk';

    try {
      final startRes = await _channel.invokeMapMethod<String, dynamic>('startDownload', {
        'url': info.apkDownloadUrl,
        'fileName': fileName,
        'title': 'Music App Update v${info.latestVersion}',
        'description': 'Downloading lossless music player update...',
      });

      if (startRes == null || !startRes.containsKey('downloadId')) {
        // Fallback to Dart stream download if DownloadManager is unavailable
        await _fallbackHttpDownload(info, fileName);
        return;
      }

      final downloadId = (startRes['downloadId'] as num).toInt();
      final expectedPath = startRes['filePath']?.toString();
      _activeDownloadId = downloadId;

      _pollTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) async {
        try {
          final queryRes = await _channel.invokeMapMethod<String, dynamic>('getDownloadProgress', {
            'downloadId': downloadId,
          });

          if (queryRes == null) return;

          final status = queryRes['status']?.toString() ?? 'unknown';
          final bytesDownloaded = (queryRes['bytesDownloaded'] as num?)?.toInt() ?? 0;
          final bytesTotal = (queryRes['bytesTotal'] as num?)?.toInt() ?? info.apkSizeBytes;

          final progress = bytesTotal > 0
              ? (bytesDownloaded / bytesTotal).clamp(0.0, 1.0)
              : 0.0;

          if (status == 'successful') {
            timer.cancel();

            // Verify downloaded file size
            final file = expectedPath != null ? File(expectedPath) : null;
            final fileExists = file != null && await file.exists();
            final actualLength = fileExists ? await file.length() : 0;

            if (fileExists && actualLength > 0) {
              _progressController?.add(DownloadProgressState(
                bytesDownloaded: actualLength,
                bytesTotal: actualLength,
                progress: 1.0,
                status: 'completed',
                filePath: file.path,
              ));
            } else {
              _progressController?.add(const DownloadProgressState(
                bytesDownloaded: 0,
                bytesTotal: 0,
                progress: 0.0,
                status: 'failed',
                errorMessage: 'Downloaded file verification failed. Please retry.',
              ));
            }
          } else if (status == 'failed') {
            timer.cancel();
            _progressController?.add(const DownloadProgressState(
              bytesDownloaded: 0,
              bytesTotal: 0,
              progress: 0.0,
              status: 'failed',
              errorMessage: 'Network interrupted during download. Tap Retry.',
            ));
          } else if (status == 'running' || status == 'pending' || status == 'paused') {
            _progressController?.add(DownloadProgressState(
              bytesDownloaded: bytesDownloaded,
              bytesTotal: bytesTotal,
              progress: progress,
              status: 'downloading',
            ));
          }
        } catch (_) {}
      });
    } catch (e) {
      await _fallbackHttpDownload(info, fileName);
    }
  }

  /// Resilient fallback HTTP downloader with range resume support
  static Future<void> _fallbackHttpDownload(UpdateInfo info, String fileName) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetFile = File('${tempDir.path}/$fileName');
      final tempFile = File('${tempDir.path}/$fileName.part');

      int existingBytes = 0;
      if (await tempFile.exists()) {
        existingBytes = await tempFile.length();
      }

      final request = http.Request('GET', Uri.parse(info.apkDownloadUrl));
      if (existingBytes > 0) {
        request.headers['Range'] = 'bytes=$existingBytes-';
      }

      final response = await http.Client().send(request);
      final isPartial = response.statusCode == 206;
      final totalBytes = isPartial
          ? existingBytes + (response.contentLength ?? 0)
          : (response.contentLength ?? info.apkSizeBytes);

      if (!isPartial && existingBytes > 0) {
        // Server did not support range, restart cleanly
        existingBytes = 0;
        if (await tempFile.exists()) await tempFile.delete();
      }

      final sink = tempFile.openWrite(mode: isPartial ? FileMode.append : FileMode.write);
      int bytesReceived = existingBytes;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        bytesReceived += chunk.length;
        final progress = totalBytes > 0
            ? (bytesReceived / totalBytes).clamp(0.0, 1.0)
            : 0.0;

        _progressController?.add(DownloadProgressState(
          bytesDownloaded: bytesReceived,
          bytesTotal: totalBytes,
          progress: progress,
          status: 'downloading',
        ));
      }

      await sink.flush();
      await sink.close();

      if (await targetFile.exists()) await targetFile.delete();
      await tempFile.rename(targetFile.path);

      _progressController?.add(DownloadProgressState(
        bytesDownloaded: bytesReceived,
        bytesTotal: totalBytes,
        progress: 1.0,
        status: 'completed',
        filePath: targetFile.path,
      ));
    } catch (e) {
      _progressController?.add(const DownloadProgressState(
        bytesDownloaded: 0,
        bytesTotal: 0,
        progress: 0.0,
        status: 'failed',
        errorMessage: 'Download failed. Please check connection and retry.',
      ));
    }
  }

  /// Cancels any active download cleanly
  static Future<void> cancelActiveDownload() async {
    _pollTimer?.cancel();
    if (_activeDownloadId != null) {
      try {
        await _channel.invokeMethod('cancelDownload', {
          'downloadId': _activeDownloadId,
        });
      } catch (_) {}
      _activeDownloadId = null;
    }
    _progressController?.add(const DownloadProgressState(
      bytesDownloaded: 0,
      bytesTotal: 0,
      progress: 0.0,
      status: 'cancelled',
    ));
  }

  /// Checks if Android has granted "Install Unknown Apps" permission
  static Future<bool> canRequestPackageInstalls() async {
    try {
      final res = await _channel.invokeMethod<bool>('canRequestPackageInstalls');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Opens Android Settings screen to allow installing unknown apps
  static Future<void> openInstallPermissionSettings() async {
    try {
      await _channel.invokeMethod('openInstallPermissionSettings');
    } catch (_) {}
  }

  /// Launches the Android native package installer for the downloaded APK
  static Future<bool> installApk(String filePath) async {
    try {
      final result = await _channel.invokeMethod<bool>('installApk', {
        'filePath': filePath,
      });
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Cleans up APK file after install or on error
  static Future<void> deleteApkFile(String filePath) async {
    try {
      await _channel.invokeMethod('deleteFile', {'filePath': filePath});
    } catch (_) {
      try {
        final f = File(filePath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  // --- Later / Snooze State Management ---

  static Future<File> _getSnoozeFile() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return File('${docsDir.path}/update_snooze.json');
  }

  static Future<void> snoozeVersion(String version) async {
    try {
      final file = await _getSnoozeFile();
      final data = {
        'version': version,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await file.writeAsString(json.encode(data));
    } catch (_) {}
  }

  static Future<bool> _isVersionSnoozed(String version) async {
    try {
      final file = await _getSnoozeFile();
      if (!await file.exists()) return false;
      final content = await file.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;
      final snoozedVersion = data['version']?.toString() ?? '';
      final timestamp = data['timestamp'] as int? ?? 0;

      if (snoozedVersion == version) {
        final snoozedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final elapsed = DateTime.now().difference(snoozedTime);
        if (elapsed < snoozeDuration) {
          return true; // Still within snooze window
        }
      }
    } catch (_) {}
    return false;
  }

  static Future<void> _clearSnoozedVersion() async {
    try {
      final file = await _getSnoozeFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  static String _cleanReleaseNotes(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return '• Performance optimizations and bug fixes.\n• Zero-delay lossless audio streaming.\n• In-app update reliability improvements.';
    }
    return raw.trim();
  }
}
