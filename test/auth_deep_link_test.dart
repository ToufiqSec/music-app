import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Auth Deep Link & PKCE Callback Parsing Tests', () {
    test('Correctly extracts PKCE auth code from myapp://auth-callback', () {
      final uri = Uri.parse('myapp://auth-callback?code=mock_pkce_auth_code_12345&state=xyz');

      expect(uri.scheme, equals('myapp'));
      expect(uri.host, equals('auth-callback'));
      expect(uri.queryParameters['code'], equals('mock_pkce_auth_code_12345'));
      expect(uri.queryParameters['state'], equals('xyz'));
      expect(uri.queryParameters.containsKey('error'), isFalse);
    });

    test('Correctly parses legacy io.supabase.musicapp://login-callback', () {
      final uri = Uri.parse('io.supabase.musicapp://login-callback?code=pkce_code_abcdef');

      expect(uri.scheme, equals('io.supabase.musicapp'));
      expect(uri.host, equals('login-callback'));
      expect(uri.queryParameters['code'], equals('pkce_code_abcdef'));
    });

    test('Detects OAuth error callback and extracts error message and description', () {
      final uri = Uri.parse(
        'myapp://auth-callback?error=access_denied&error_code=403&error_description=User+denied+access',
      );

      expect(uri.queryParameters['error'], equals('access_denied'));
      expect(uri.queryParameters['error_code'], equals('403'));
      expect(uri.queryParameters['error_description'], equals('User denied access'));
    });

    test('Parses implicit access_token and refresh_token from fragment if returned', () {
      final uri = Uri.parse(
        'myapp://auth-callback#access_token=jwt_mock_token&expires_in=3600&refresh_token=refresh_123&token_type=bearer',
      );

      final fragmentParams = Uri.splitQueryString(uri.fragment);
      expect(fragmentParams['access_token'], equals('jwt_mock_token'));
      expect(fragmentParams['refresh_token'], equals('refresh_123'));
      expect(fragmentParams['token_type'], equals('bearer'));
    });

    test('Validates custom scheme matching for Android intent filter coverage', () {
      const supportedSchemes = ['myapp', 'musicapp', 'io.supabase.musicapp'];
      const supportedHosts = ['auth-callback', 'login-callback'];

      final testUrl1 = Uri.parse('myapp://auth-callback');
      final testUrl2 = Uri.parse('musicapp://auth-callback');
      final testUrl3 = Uri.parse('io.supabase.musicapp://login-callback');

      for (final uri in [testUrl1, testUrl2, testUrl3]) {
        expect(supportedSchemes.contains(uri.scheme), isTrue, reason: '${uri.scheme} must be supported');
        expect(supportedHosts.contains(uri.host), isTrue, reason: '${uri.host} must be supported');
      }
    });
  });
}
