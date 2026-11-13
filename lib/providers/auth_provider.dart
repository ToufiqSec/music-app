import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  UserProfileData? _profile;
  UserSettingsData _settings = const UserSettingsData();
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<AuthState>? _authSubscription;

  AuthProvider() {
    _initAuthListener();
  }

  // Getters
  bool get isAuthenticated => SupabaseService.isAuthenticated;
  User? get currentUser => SupabaseService.currentUser;
  UserProfileData? get profile => _profile;
  UserSettingsData get settings => _settings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get displayName =>
      _profile?.displayName.isNotEmpty == true ? _profile!.displayName : 'Music Lover';
  String get email {
    if (_profile != null && _profile!.email.trim().isNotEmpty && _profile!.email.trim() != 'Guest') {
      return _profile!.email.trim();
    }
    final user = currentUser;
    if (user?.email != null && user!.email!.trim().isNotEmpty) {
      return user.email!.trim();
    }
    final metaEmail = user?.userMetadata?['email']?.toString();
    final trimmedMeta = metaEmail?.trim();
    if (trimmedMeta != null && trimmedMeta.isNotEmpty) {
      return trimmedMeta;
    }
    return 'Guest';
  }
  String get avatarUrl => _profile?.avatarUrl ?? (currentUser?.userMetadata?['avatar_url']?.toString() ?? '');

  void _initAuthListener() {
    // Read initial state
    if (isAuthenticated) {
      _loadProfileAndSettings();
    }

    _authSubscription = SupabaseService.authStateChanges.listen((data) async {
      final AuthChangeEvent event = data.event;
      debugPrint('[Auth State Change] Event: $event');

      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
        final user = SupabaseService.currentUser;
        if (user != null) {
          final metaUserEmail = user.userMetadata?['email']?.toString();
          final userEmail = user.email?.trim() ?? metaUserEmail?.trim();
          if (userEmail != null && userEmail.isNotEmpty) {
            try {
              await SupabaseService.client.from('profiles').upsert({
                'id': user.id,
                'email': userEmail,
                'display_name': user.userMetadata?['full_name'] ??
                    user.userMetadata?['name'] ??
                    userEmail.split('@')[0],
                'updated_at': DateTime.now().toIso8601String(),
              });
            } catch (e) {
              debugPrint('[AuthProvider] Profile sync on auth change: $e');
            }
          }
        }
        await _loadProfileAndSettings();
        await SupabaseService.syncDownAllUserData();
      } else if (event == AuthChangeEvent.signedOut) {
        _profile = null;
        _settings = const UserSettingsData();
        notifyListeners();
      }
    });
  }

  Future<void> _loadProfileAndSettings() async {
    _profile = await SupabaseService.fetchProfile();
    _settings = await SupabaseService.fetchUserSettings();
    notifyListeners();
  }

  /// Sign In with Email & Password
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final response = await SupabaseService.signInWithEmail(
        email: email,
        password: password,
      );
      if (response.user != null) {
        await _loadProfileAndSettings();
        _setLoading(false);
        return true;
      }
      _setError('Login failed. Please check your credentials.');
      return false;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('An unexpected error occurred during login.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Sign Up with Email & Password
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final response = await SupabaseService.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      if (response.user != null) {
        await _loadProfileAndSettings();
        _setLoading(false);
        return true;
      }
      _setError('Registration failed. Please try again.');
      return false;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('An unexpected error occurred during registration.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Continue with Google OAuth
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _clearError();
    try {
      final started = await SupabaseService.signInWithGoogle();
      return started;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Google sign-in could not be completed.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Sign Out
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await SupabaseService.signOut();
      _profile = null;
      _settings = const UserSettingsData();
    } catch (e) {
      debugPrint('[Auth] Sign out error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Update Profile (Display Name & Avatar)
  Future<bool> updateProfile({
    required String displayName,
    String? avatarUrl,
  }) async {
    _setLoading(true);
    try {
      await SupabaseService.updateProfile(
        displayName: displayName,
        avatarUrl: avatarUrl,
      );
      _profile = await SupabaseService.fetchProfile();
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
    await SupabaseService.updateUserSettings(_settings);
  }

  /// Force a full cloud re-sync
  Future<void> syncNow() async {
    _setLoading(true);
    await SupabaseService.syncDownAllUserData();
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
