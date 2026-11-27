import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../core/services/firebase_auth_service.dart';
import '../core/services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  UserProfileData? _profile;
  UserSettingsData _settings = const UserSettingsData();
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<fb.User?>? _authSubscription;

  AuthProvider() {
    _initAuthListener();
  }

  // Getters
  bool get isAuthenticated => FirebaseAuthService.isAuthenticated;
  fb.User? get currentUser => FirebaseAuthService.currentUser;
  UserProfileData? get profile => _profile;
  UserSettingsData get settings => _settings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get displayName {
    final user = currentUser;
    if (user != null && user.displayName != null && user.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim();
    }
    if (_profile != null && _profile!.displayName.trim().isNotEmpty && _profile!.displayName.trim() != 'Music Lover') {
      return _profile!.displayName.trim();
    }
    final em = email;
    if (em.isNotEmpty && em != 'Guest') {
      return em.split('@')[0];
    }
    return 'Music Lover';
  }

  String get email {
    final user = currentUser;
    if (user?.email != null && user!.email!.trim().isNotEmpty) {
      return user.email!.trim();
    }
    if (_profile != null && _profile!.email.trim().isNotEmpty && _profile!.email.trim() != 'Guest') {
      return _profile!.email.trim();
    }
    return 'Guest';
  }

  String get avatarUrl {
    final user = currentUser;
    if (user?.photoURL != null && user!.photoURL!.trim().isNotEmpty) {
      return user.photoURL!.trim();
    }
    final pUrl = _profile?.avatarUrl.trim();
    if (pUrl != null && pUrl.isNotEmpty) return pUrl;
    return '';
  }

  void _initAuthListener() {
    if (isAuthenticated) {
      _loadProfileAndSettings();
    }

    _authSubscription = FirebaseAuthService.authStateChanges.listen((fb.User? user) async {
      debugPrint('[AuthProvider] Firebase Auth State Change: UID = ${user?.uid}, email = ${user?.email}');

      if (user != null) {
        _profile = UserProfileData(
          id: user.uid,
          email: user.email ?? 'Guest',
          displayName: user.displayName ?? (user.email?.split('@')[0] ?? 'Music Lover'),
          avatarUrl: user.photoURL ?? '',
        );

        // Sync with cloud database if available
        try {
          await SupabaseService.syncDownAllUserData();
        } catch (_) {}

        notifyListeners();
      } else {
        _profile = null;
        _settings = const UserSettingsData();
        notifyListeners();
      }
    });
  }

  Future<void> _loadProfileAndSettings() async {
    final user = currentUser;
    if (user != null) {
      _profile = UserProfileData(
        id: user.uid,
        email: user.email ?? 'Guest',
        displayName: user.displayName ?? (user.email?.split('@')[0] ?? 'Music Lover'),
        avatarUrl: user.photoURL ?? '',
      );
    }
    try {
      _settings = await SupabaseService.fetchUserSettings();
    } catch (_) {}
    notifyListeners();
  }

  /// Sign In with Email & Password via Firebase Auth
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final cred = await FirebaseAuthService.signInWithEmail(
        email: email,
        password: password,
      );
      if (cred.user != null) {
        await _loadProfileAndSettings();
        _setLoading(false);
        return true;
      }
      _setError('Login failed. Please check your credentials.');
      return false;
    } catch (e) {
      _setError(FirebaseAuthService.formatErrorMessage(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Sign Up with Email & Password via Firebase Auth
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final cred = await FirebaseAuthService.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      if (cred.user != null) {
        await _loadProfileAndSettings();
        _setLoading(false);
        return true;
      }
      _setError('Registration failed. Please try again.');
      return false;
    } catch (e) {
      _setError(FirebaseAuthService.formatErrorMessage(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Send password reset email via Firebase Auth
  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _clearError();
    try {
      await FirebaseAuthService.resetPassword(email);
      return true;
    } catch (e) {
      _setError(FirebaseAuthService.formatErrorMessage(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Whether Supabase cloud sync / Listen Together has an active authenticated session.
  bool get isCloudSessionSynced => SupabaseService.isAuthenticated;

  /// Native 1-Tap Google Sign-In via Firebase Auth (Google Play Services)
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _clearError();
    try {
      final cred = await FirebaseAuthService.signInWithGoogle();
      if (cred != null && cred.user != null) {
        await SupabaseService.syncFirebaseSession(
          googleIdToken: FirebaseAuthService.lastGoogleIdToken,
          googleAccessToken: FirebaseAuthService.lastGoogleAccessToken,
        );
        await _loadProfileAndSettings();
        _setLoading(false);
        return true;
      }
      // User canceled account picker dialog
      _setLoading(false);
      return false;
    } catch (e) {
      _setError(FirebaseAuthService.formatErrorMessage(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Sign Out via Firebase Auth and Supabase
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await FirebaseAuthService.signOut();
      await SupabaseService.signOut();
      _profile = null;
      _settings = const UserSettingsData();
    } catch (e) {
      debugPrint('[Auth] Sign out error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Update Profile (Display Name & Avatar) via Firebase Auth
  Future<bool> updateProfile({
    required String displayName,
    String? avatarUrl,
  }) async {
    _setLoading(true);
    try {
      await FirebaseAuthService.updateProfile(
        displayName: displayName,
        photoUrl: avatarUrl,
      );
      await _loadProfileAndSettings();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update profile: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update User Settings
  Future<void> updateSettings({
    UserSettingsData? newSettings,
    int? searchCacheHours,
    String? audioQuality,
    bool? autoplay,
    int? crossfadeSeconds,
    String? lyricsScript,
  }) async {
    _settings = newSettings ??
        _settings.copyWith(
          searchCacheHours: searchCacheHours,
          audioQuality: audioQuality,
          autoplayEnabled: autoplay,
          crossfadeSeconds: crossfadeSeconds,
          preferredLyricsScript: lyricsScript,
        );
    notifyListeners();
    try {
      await SupabaseService.updateUserSettings(_settings);
    } catch (_) {}
  }

  /// Force a full cloud re-sync
  Future<void> syncNow() async {
    _setLoading(true);
    try {
      await SupabaseService.syncDownAllUserData();
    } catch (_) {}
    await _loadProfileAndSettings();
    _setLoading(false);
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void _setError(String msg) {
    _errorMessage = msg;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
