import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
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
  final String? expectedSha256;
  final String? apkAssetName;

  const UpdateInfo({
    required this.latestVersion,
    required this.latestVersionCode,
    required this.releaseNotes,
    required this.apkDownloadUrl,
    required this.apkSizeBytes,
    required this.publishedAt,
    required this.currentVersion,
    this.expectedSha256,
    this.apkAssetName,
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
  static HttpClient? _activeIoClient;
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

      // Locate preferred release APK asset & optional SHA-256 manifest
      final assets = data['assets'] as List<dynamic>? ?? [];
      final apkAsset = selectPreferredApkAsset(assets);

      if (apkAsset == null) return null;

      final assetName = apkAsset['name']?.toString() ?? '';
      final downloadUrl = apkAsset['browser_download_url']?.toString() ?? '';
      final size = apkAsset['size'] as int? ?? 0;
      String? expectedSha256;

      final checksumAsset = assets.cast<dynamic>().firstWhere(
        (a) => a['name']?.toString().toLowerCase() == 'checksums.sha256',
        orElse: () => null,
      );
      if (checksumAsset != null) {
        final checksumUrl = checksumAsset['browser_download_url']?.toString() ?? '';
        if (checksumUrl.isNotEmpty) {
          try {
            final cResp = await http
                .get(Uri.parse(checksumUrl))
                .timeout(const Duration(seconds: 6));
            if (cResp.statusCode == 200) {
              expectedSha256 = parseSha256ForAsset(cResp.body, assetName);
            }
          } catch (_) {}
        }
      }

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
        expectedSha256: expectedSha256,
        apkAssetName: assetName,
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

      // Check if target file already exists and passes size + SHA-256 verification
      if (await targetFile.exists()) {
        final ok = await verifyFileIntegrity(
          targetFile,
          expectedBytes: info.apkSizeBytes,
          expectedSha256: info.expectedSha256,
        );
        if (ok) {
          final existingTargetLen = await targetFile.length();
          _progressController?.add(DownloadProgressState(
            bytesDownloaded: existingTargetLen,
            bytesTotal: existingTargetLen,
            progress: 1.0,
            status: 'completed',
            filePath: targetFile.path,
          ));
          return;
        } else {
          await targetFile.delete().catchError((_) => targetFile);
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

      _activeIoClient?.close(force: true);
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15)
        ..idleTimeout = const Duration(seconds: 5);
      _activeIoClient = client;

      final response = await _openDownloadStreamWithRedirects(
        client: client,
        initialUri: Uri.parse(info.apkDownloadUrl),
        rangeStart: existingBytes,
      );

      if (_isCancelled) return;

      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception('Server returned HTTP ${response.statusCode}');
      }

      final isPartial = response.statusCode == 206;
      final contentLength = response.contentLength >= 0 ? response.contentLength : null;
      final totalBytes = isPartial
          ? existingBytes + (contentLength ?? 0)
          : (contentLength ?? expectedTotal);

      if (!isPartial && existingBytes > 0) {
        existingBytes = 0;
        if (await tempFile.exists()) await tempFile.delete();
      }

      final sink = tempFile.openWrite(mode: isPartial ? FileMode.append : FileMode.write);
      int bytesReceived = existingBytes;
      int lastReportTime = 0;

      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
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

      final verified = await verifyFileIntegrity(
        targetFile,
        expectedBytes: info.apkSizeBytes,
        expectedSha256: info.expectedSha256,
      );
      if (!verified) {
        await targetFile.delete().catchError((_) => targetFile);
        throw Exception('APK integrity verification failed');
      }

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
        errorMessage: formatDownloadError(e),
      ));
    } finally {
      _activeIoClient?.close(force: true);
      _activeIoClient = null;
    }
  }

  /// Opens the APK stream using a fresh system-default [HttpClient], explicitly
  /// following GitHub cross-host redirects without reusing stale sockets.
  static Future<HttpClientResponse> _openDownloadStreamWithRedirects({
    required HttpClient client,
    required Uri initialUri,
    required int rangeStart,
    int maxRedirects = 8,
  }) async {
    var currentUri = initialUri;
    for (int hop = 0; hop <= maxRedirects; hop++) {
      if (_isCancelled) {
        throw Exception('Download cancelled');
      }
      final req = await client.getUrl(currentUri).timeout(const Duration(seconds: 20));
      req.followRedirects = false;
      req.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      );
      if (rangeStart > 0) {
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=$rangeStart-');
      }

      final resp = await req.close().timeout(const Duration(seconds: 20));
      if (resp.statusCode == HttpStatus.movedPermanently ||
          resp.statusCode == HttpStatus.movedTemporarily ||
          resp.statusCode == HttpStatus.seeOther ||
          resp.statusCode == HttpStatus.temporaryRedirect ||
          resp.statusCode == HttpStatus.permanentRedirect) {
        final location = resp.headers.value(HttpHeaders.locationHeader);
        await resp.drain<void>().catchError((_) {});
        if (location == null || location.isEmpty) {
          throw Exception('Server returned redirect without Location header');
        }
        currentUri = currentUri.resolve(location);
        continue;
      }
      return resp;
    }
    throw Exception('Too many redirects while downloading update');
  }

  /// Maps raw network/HTTP exceptions to a readable user-facing message.
  @visibleForTesting
  static String formatDownloadError(Object error) {
    final msg = error.toString();
    if (error is SocketException ||
        error is HandshakeException ||
        msg.contains('SocketException') ||
        msg.contains('Connection refused') ||
        msg.contains('Failed host lookup') ||
        msg.contains('Network is unreachable') ||
        msg.contains('Connection reset')) {
      return 'Network connection failed. Check your internet or VPN settings, then tap Retry or Download in Browser.';
    }
    if (error is TimeoutException || msg.contains('TimeoutException') || msg.contains('timed out')) {
      return 'Download timed out. Check your internet connection and tap Retry or Download in Browser.';
    }
    if (msg.contains('HTTP 404')) {
      return 'Update file not found on server. Try again later or Download in Browser.';
    }
    if (msg.contains('HTTP ')) {
      return 'Server error while downloading update. Tap Retry or Download in Browser.';
    }
    if (msg.contains('integrity verification failed')) {
      return 'Downloaded update failed integrity verification. Tap Retry or Download in Browser.';
    }
    return 'Download could not complete. Check your connection and tap Retry or Download in Browser.';
  }

  /// Selects the preferred Android release APK asset, prioritizing Swarva branding.
  @visibleForTesting
  static Map<String, dynamic>? selectPreferredApkAsset(List<dynamic> assets) {
    final apkAssets = assets
        .whereType<Map<String, dynamic>>()
        .where((a) => a['name'].toString().toLowerCase().endsWith('.apk'))
        .toList();
    if (apkAssets.isEmpty) return null;

    for (final preferred in const ['swarva-release.apk', 'music-app-release.apk']) {
      for (final a in apkAssets) {
        if (a['name'].toString().toLowerCase() == preferred) return a;
      }
    }
    for (final a in apkAssets) {
      if (a['name'].toString().toLowerCase().startsWith('swarva-')) return a;
    }
    return apkAssets.first;
  }

  /// Extracts a 64-char SHA-256 hex digest for [assetName] from a `checksums.sha256` file.
  @visibleForTesting
  static String? parseSha256ForAsset(String checksumsBody, String assetName) {
    final target = assetName.trim().toLowerCase();
    for (final rawLine in checksumsBody.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final match = RegExp(r'^([a-fA-F0-9]{64})\s+\*?(.+)$').firstMatch(line);
      if (match != null) {
        final hash = match.group(1)!.toLowerCase();
        final file = match.group(2)!.trim().toLowerCase();
        if (file == target || file.endsWith('/$target')) {
          return hash;
        }
      }
    }
    return null;
  }

  /// Verifies that [file] exists, is non-empty, matches [expectedBytes] (when > 0),
  /// and matches [expectedSha256] (when provided).
  @visibleForTesting
  static Future<bool> verifyFileIntegrity(
    File file, {
    int? expectedBytes,
    String? expectedSha256,
  }) async {
    if (!await file.exists()) return false;
    final len = await file.length();
    if (len <= 0) return false;
    if (expectedBytes != null && expectedBytes > 0 && len != expectedBytes) {
      return false;
    }
    if (expectedSha256 != null && expectedSha256.trim().isNotEmpty) {
      final digest = await sha256.bind(file.openRead()).first;
      if (digest.toString().toLowerCase() != expectedSha256.trim().toLowerCase()) {
        return false;
      }
    }
    return true;
  }

  /// Cancels any active download cleanly
  static Future<void> cancelActiveDownload() async {
    _isCancelled = true;
    _pollTimer?.cancel();
    _activeIoClient?.close(force: true);
    _activeIoClient = null;
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
