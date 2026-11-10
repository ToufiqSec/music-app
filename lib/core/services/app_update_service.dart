import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  final String latestVersion;
  final String releaseNotes;
  final String apkDownloadUrl;
  final int apkSizeBytes;
  final DateTime publishedAt;

  const UpdateInfo({
    required this.latestVersion,
    required this.releaseNotes,
    required this.apkDownloadUrl,
    required this.apkSizeBytes,
    required this.publishedAt,
  });

  String get formattedSize {
    if (apkSizeBytes <= 0) return '';
    final mb = apkSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class AppUpdateService {
  // Current app version (Matches pubspec.yaml version)
  static const String currentVersion = '1.0.0';
  static const String githubRepo = 'ToufiqSec/music-app';
  static const MethodChannel _channel =
      MethodChannel('com.toufiqsec.music_app/installer');

  /// Queries GitHub Releases API to see if a newer APK is available.
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final url = Uri.parse(
        'https://api.github.com/repos/$githubRepo/releases/latest',
      );
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'MusicApp-Updater',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final rawTag = data['tag_name']?.toString() ?? '';
      final cleanTag = rawTag.replaceAll(RegExp(r'[^0-9.]'), '');
      if (cleanTag.isEmpty) return null;

      if (_isVersionNewer(cleanTag, currentVersion)) {
        final assets = data['assets'] as List<dynamic>? ?? [];
        // Find release APK asset
        final apkAsset = assets.firstWhere(
          (a) => a['name'].toString().toLowerCase().endsWith('.apk'),
          orElse: () => null,
        );

        if (apkAsset != null) {
          final downloadUrl = apkAsset['browser_download_url']?.toString() ?? '';
          final size = apkAsset['size'] as int? ?? 0;
          final notes = data['body']?.toString() ?? 'Bug fixes and performance improvements.';
          final published = DateTime.tryParse(data['published_at']?.toString() ?? '') ??
              DateTime.now();

          return UpdateInfo(
            latestVersion: cleanTag,
            releaseNotes: notes,
            apkDownloadUrl: downloadUrl,
            apkSizeBytes: size,
            publishedAt: published,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Downloads the APK with a live progress stream (0.0 to 1.0) and prompts the native installer on completion.
  static Stream<double> downloadAndInstall(UpdateInfo updateInfo) async* {
    final tempDir = await getTemporaryDirectory();
    final updateFile = File('${tempDir.path}/music_app_update.apk');

    if (await updateFile.exists()) {
      await updateFile.delete();
    }

    final request = http.Request('GET', Uri.parse(updateInfo.apkDownloadUrl));
    final response = await http.Client().send(request);

    final contentLength = response.contentLength ?? updateInfo.apkSizeBytes;
    int bytesReceived = 0;

    final sink = updateFile.openWrite();

    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        bytesReceived += chunk.length;
        if (contentLength > 0) {
          yield (bytesReceived / contentLength).clamp(0.0, 1.0);
        }
      }
      await sink.flush();
      await sink.close();

      yield 1.0;

      // Trigger native Android package installer
      await installApk(updateFile.path);
    } catch (e) {
      await sink.close();
      if (await updateFile.exists()) {
        await updateFile.delete();
      }
      rethrow;
    }
  }

  /// Directly calls MainActivity to launch Android's package installer over the existing app.
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

  /// Compares semantic versions (e.g. 1.0.1 > 1.0.0).
  static bool _isVersionNewer(String remote, String local) {
    try {
      final remoteParts = remote.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      final localParts = local.split('.').map((p) => int.tryParse(p) ?? 0).toList();

      final length = remoteParts.length > localParts.length
          ? remoteParts.length
          : localParts.length;

      for (int i = 0; i < length; i++) {
        final r = i < remoteParts.length ? remoteParts[i] : 0;
        final l = i < localParts.length ? localParts[i] : 0;
        if (r > l) return true;
        if (r < l) return false;
      }
    } catch (_) {}
    return false;
  }
}
