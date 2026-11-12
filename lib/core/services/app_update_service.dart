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
    final tot = bytesTotal > 0 ? bytesTotal : 74197766;
    final totMb = (tot / (1024 * 1024)).toStringAsFixed(1);
    final pct = (progress * 100).toInt().clamp(0, 100);
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
  static http.Client? _activeHttpClient;
  static bool _isCancelled = false;

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

  /// Downloads the APK using high-speed in-app HTTP streaming.
  /// Streams directly to local storage with real-time byte counters and progress updates.
  static Stream<DownloadProgressState> startDownload(UpdateInfo info) {
    _progressController?.close();
    _progressController = StreamController<DownloadProgressState>.broadcast();
    _pollTimer?.cancel();
    _isCancelled = false;

    _runDirectHttpDownload(info);

    return _progressController!.stream;
  }

  static Future<void> _runDirectHttpDownload(UpdateInfo info) async {
    final fileName = 'music-app-v${info.latestVersion}.apk';

    try {
      final tempDir = await getTemporaryDirectory();
      final targetFile = File('${tempDir.path}/$fileName');
      final tempFile = File('${tempDir.path}/$fileName.part');

      // Check if target file already exists and is fully downloaded
      if (await targetFile.exists()) {
        final existingTargetLen = await targetFile.length();
        if (info.apkSizeBytes > 0 && existingTargetLen == info.apkSizeBytes) {
          _progressController?.add(DownloadProgressState(
            bytesDownloaded: existingTargetLen,
            bytesTotal: existingTargetLen,
            progress: 1.0,
            status: 'completed',
            filePath: targetFile.path,
          ));
          return;
        }
      }

      int existingBytes = 0;
      if (await tempFile.exists()) {
        existingBytes = await tempFile.length();
      }

      final expectedTotal = info.apkSizeBytes > 0 ? info.apkSizeBytes : 74197766;

      // Initial progress reporting
      _progressController?.add(DownloadProgressState(
        bytesDownloaded: existingBytes,
        bytesTotal: expectedTotal,
        progress: (existingBytes / expectedTotal).clamp(0.0, 1.0),
        status: 'downloading',
      ));

      _activeHttpClient?.close();
      _activeHttpClient = http.Client();

      final request = http.Request('GET', Uri.parse(info.apkDownloadUrl));
      request.followRedirects = true;
      request.maxRedirects = 5;
      request.headers['User-Agent'] =
          'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

      if (existingBytes > 0) {
        request.headers['Range'] = 'bytes=$existingBytes-';
      }

      final response = await _activeHttpClient!.send(request);

      if (_isCancelled) return;

      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception('Server returned HTTP ${response.statusCode}');
      }

      final isPartial = response.statusCode == 206;
      final totalBytes = isPartial
          ? existingBytes + (response.contentLength ?? 0)
          : (response.contentLength ?? expectedTotal);

      if (!isPartial && existingBytes > 0) {
        existingBytes = 0;
        if (await tempFile.exists()) await tempFile.delete();
      }

      final sink = tempFile.openWrite(mode: isPartial ? FileMode.append : FileMode.write);
      int bytesReceived = existingBytes;
      int lastReportTime = 0;

      await for (final chunk in response.stream) {
        if (_isCancelled) {
          await sink.close();
          return;
        }

        sink.add(chunk);
        bytesReceived += chunk.length;

        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastReportTime > 150 || bytesReceived >= totalBytes) {
          lastReportTime = now;
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
      }

      await sink.flush();
      await sink.close();

      if (_isCancelled) return;

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
      if (_isCancelled) return;
      debugPrint('[AppUpdateService] HTTP download error: $e');
      _progressController?.add(DownloadProgressState(
        bytesDownloaded: 0,
        bytesTotal: 0,
        progress: 0.0,
        status: 'failed',
        errorMessage: 'Download error: $e. Tap Retry or Download in Browser.',
      ));
    } finally {
      _activeHttpClient?.close();
      _activeHttpClient = null;
    }
  }

  /// Cancels any active download cleanly
  static Future<void> cancelActiveDownload() async {
    _isCancelled = true;
    _pollTimer?.cancel();
    _activeHttpClient?.close();
    _activeHttpClient = null;
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

  /// Opens the direct APK download URL in the device's external browser (fallback)
  static Future<bool> openInBrowser(String url) async {
    try {
      final res = await _channel.invokeMethod<bool>('openUrl', {'url': url});
      return res ?? false;
    } catch (_) {
      return false;
    }
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
