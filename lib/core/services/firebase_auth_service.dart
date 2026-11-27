import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'supabase_service.dart';

/// Central Firebase Authentication Service handling Email/Password & Native Google Sign-In.
class FirebaseAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Web Client ID from google-services.json (client_type: 3) for Google Play Services ID token exchange
  static const String webClientId =
      '286608319896-p37flo65r2q85lvl63rr2p3f18qa42cs.apps.googleusercontent.com';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: webClientId,
    scopes: [
      'email',
      'https://www.googleapis.com/auth/userinfo.profile',
    ],
  );

  static User? get currentUser => _auth.currentUser;
  static bool get isAuthenticated => _auth.currentUser != null;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Native 1-Tap Google Sign-In via Google Play Services on Android
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      debugPrint('[FirebaseAuthService] Initiating native Google Sign-In...');

      // Disconnect previous cached session if any to allow account switching
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      // Trigger Google Play Services native account picker
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('[FirebaseAuthService] User aborted Google Sign-In dialog.');
        return null;
      }

      debugPrint('[FirebaseAuthService] Account selected: ${googleUser.email}. Authenticating...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      debugPrint('[FirebaseAuthService] Firebase Sign-In successful for UID: ${userCredential.user?.uid}');

      // Bridge Google ID token to Supabase so RLS-protected Cloud Sync & Listen Together rooms work
      if (googleAuth.idToken != null && googleAuth.idToken!.isNotEmpty) {
        try {
          await SupabaseService.signInWithGoogleIdToken(
            idToken: googleAuth.idToken!,
            accessToken: googleAuth.accessToken,
          );
        } catch (e) {
          debugPrint('[FirebaseAuthService] Non-fatal Supabase ID token bridge error: $e');
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('[FirebaseAuthService] FirebaseAuthException: [${e.code}] ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[FirebaseAuthService] Unexpected error during Google Sign-In: $e');
      rethrow;
    }
  }

  /// Sign In with Email & Password
  static Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    return await _auth.signInWithEmailAndPassword(
      email: trimmedEmail,
      password: password,
    );
  }

  /// Sign Up with Email & Password
  static Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final trimmedEmail = email.trim();
    final cred = await _auth.createUserWithEmailAndPassword(
      email: trimmedEmail,
      password: password,
    );
    if (displayName != null && displayName.trim().isNotEmpty) {
      await cred.user?.updateDisplayName(displayName.trim());
      await cred.user?.reload();
    }
    return cred;
  }

  /// Send Password Reset Email
  static Future<void> resetPassword(String email) async {
    final trimmedEmail = email.trim();
    await _auth.sendPasswordResetEmail(email: trimmedEmail);
  }

  /// Sign Out from both Firebase, Supabase, and GoogleSignIn
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await SupabaseService.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  /// Update Profile Display Name & Avatar
  static Future<void> updateProfile({String? displayName, String? photoUrl}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (displayName != null && displayName.trim().isNotEmpty) {
      await user.updateDisplayName(displayName.trim());
    }
    if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      await user.updatePhotoURL(photoUrl.trim());
    }
    await user.reload();
  }

  /// Formats user-friendly error messages from FirebaseAuthException
  static String formatErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No user found with this email. Please check your email or sign up.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password. Please try again.';
        case 'email-already-in-use':
          return 'An account already exists with this email address. Please sign in.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'weak-password':
          return 'The password is too weak. Please use at least 6 characters.';
        case 'user-disabled':
          return 'This user account has been disabled.';
        case 'too-many-requests':
          return 'Too many attempts. Access temporarily blocked. Please try again later.';
        case 'operation-not-allowed':
          return 'This sign-in method is not enabled in Firebase Console.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection.';
        case 'account-exists-with-different-credential':
          return 'An account already exists with the same email address using another sign-in method.';
        default:
          return error.message ?? 'Authentication failed. Please try again.';
      }
    }
    final str = error.toString();
    if (str.contains('sign_in_canceled') || str.contains('sign_in_cancelled') || str.contains('aborted')) {
      return 'Google sign-in was canceled.';
    }
    return 'Authentication error: $error';
  }
}
