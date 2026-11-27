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
  });
}
