import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/core/services/app_update_service.dart';

void main() {
  group('AppUpdateService', () {
    test('formatDownloadError hides raw SocketException and returns network guidance', () {
      const rawSocketError = SocketException(
        'Connection refused',
        osError: OSError('Connection refused', 111),
        port: 46226,
      );

      final message = AppUpdateService.formatDownloadError(rawSocketError);

      expect(message, contains('Network connection failed'));
      expect(message, contains('VPN'));
      expect(message, isNot(contains('SocketException')));
      expect(message, isNot(contains('46226')));
      expect(message, isNot(contains('errno')));
    });

    test('formatDownloadError handles TimeoutException, HTTP 404, and generic errors cleanly', () {
      final timeoutMsg = AppUpdateService.formatDownloadError(TimeoutException('timed out'));
      expect(timeoutMsg, contains('Download timed out'));

      final notFoundMsg = AppUpdateService.formatDownloadError(Exception('Server returned HTTP 404'));
      expect(notFoundMsg, contains('not found on server'));

      final genericMsg = AppUpdateService.formatDownloadError(Exception('Unexpected failure'));
      expect(genericMsg, contains('Download could not complete'));
      expect(genericMsg, isNot(contains('Exception:')));
    });

    test('isVersionNewer compares semantic versions accurately', () {
      expect(AppUpdateService.isVersionNewer('1.0.113', '1.0.112'), isTrue);
      expect(AppUpdateService.isVersionNewer('1.0.113', '1.0.113'), isFalse);
      expect(AppUpdateService.isVersionNewer('1.0.112', '1.0.113'), isFalse);
      expect(AppUpdateService.isVersionNewer('1.1.0', '1.0.999'), isTrue);
    });

    test('selectPreferredApkAsset prefers swarva-release.apk over generic/older names', () {
      final assets = [
        {'name': 'music-app-v1.0.114.apk', 'browser_download_url': 'https://example.com/a.apk', 'size': 100},
        {'name': 'swarva-release.apk', 'browser_download_url': 'https://example.com/s.apk', 'size': 100},
        {'name': 'checksums.sha256', 'browser_download_url': 'https://example.com/c.txt', 'size': 10},
      ];
      final chosen = AppUpdateService.selectPreferredApkAsset(assets);
      expect(chosen?['name'], equals('swarva-release.apk'));
    });

    test('parseSha256ForAsset and verifyFileIntegrity validate SHA-256 digests', () async {
      final dir = await Directory.systemTemp.createTemp('swarva_update_test_');
      try {
        final file = File('${dir.path}/swarva-release.apk');
        await file.writeAsString('test-apk-payload');
        // sha256('test-apk-payload') =
        const expectedHash = 'a8b0993e8e6e2ee9e6c1a8ef45b8f64be8a5df5cbdc3cd7d346b9aa90211634c';
        // Let's also test parseSha256ForAsset format:
        final manifest = '$expectedHash  swarva-release.apk\n'
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef  other.apk\n';
        expect(AppUpdateService.parseSha256ForAsset(manifest, 'swarva-release.apk'), equals(expectedHash));

        // Mismatched hash must fail verification
        final badOk = await AppUpdateService.verifyFileIntegrity(
          file,
          expectedBytes: await file.length(),
          expectedSha256: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        );
        expect(badOk, isFalse);
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
