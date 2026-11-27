import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/core/utils/log_sanitizer.dart';

void main() {
  group('LogSanitizer', () {
    test('sanitizeUri strips query parameters and fragments with OAuth codes or tokens', () {
      final uri = Uri.parse('myapp://auth-callback?code=secret_pkce_code_123&state=xyz#access_token=jwt_secret');
      final sanitized = LogSanitizer.sanitizeUri(uri);

      expect(sanitized, equals('myapp://auth-callback'));
      expect(sanitized, isNot(contains('secret_pkce_code_123')));
      expect(sanitized, isNot(contains('jwt_secret')));
    });

    test('sanitizeUrl strips signed query strings from media URLs', () {
      const signed = 'https://rr1---sn-xyz.googlevideo.com/videoplayback?expire=1700000000&sig=ABCDEF12345';
      final sanitized = LogSanitizer.sanitizeUrl(signed);

      expect(sanitized, equals('https://rr1---sn-xyz.googlevideo.com/videoplayback'));
      expect(sanitized, isNot(contains('ABCDEF12345')));
      expect(sanitized, isNot(contains('expire=')));
    });

    test('maskToken masks FCM/auth tokens leaving at most 4 prefix chars', () {
      expect(LogSanitizer.maskToken('fcm_token_9876543210'), equals('fcm_••••'));
      expect(LogSanitizer.maskToken('abc'), equals('••••'));
      expect(LogSanitizer.maskToken(null), equals('<empty>'));
    });
  });
}
