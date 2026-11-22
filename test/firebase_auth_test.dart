import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/core/services/firebase_auth_service.dart';

void main() {
  group('Firebase Authentication Service Tests', () {
    test('Web Client ID is valid for Google Play Services ID token exchange', () {
      expect(FirebaseAuthService.webClientId, isNotEmpty);
      expect(FirebaseAuthService.webClientId, contains('286608319896'));
      expect(FirebaseAuthService.webClientId, endsWith('.apps.googleusercontent.com'));
    });

    test('Error formatting handles common cancellation and error codes', () {
      expect(
        FirebaseAuthService.formatErrorMessage('User canceled Google Sign-In'),
        equals('Google sign-in was canceled.'),
      );
      expect(
        FirebaseAuthService.formatErrorMessage('sign_in_canceled'),
        equals('Google sign-in was canceled.'),
      );
    });
  });
}
