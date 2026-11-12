import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/music/models/music_models.dart';
import 'track_metadata_store.dart';

class UserProfileData {
  final String id;
  final String email;
  final String displayName;
  final String avatarUrl;

  const UserProfileData({
    required this.id,
    required this.email,
    required this.displayName,
    required this.avatarUrl,
  });

  factory UserProfileData.fromMap(Map<String, dynamic> map, String fallbackEmail) {
    return UserProfileData(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString() ?? fallbackEmail,
      displayName: map['display_name']?.toString() ??
          (fallbackEmail.contains('@') ? fallbackEmail.split('@')[0] : 'Music Lover'),
      avatarUrl: map['avatar_url']?.toString() ?? '',
    );
  }
}

class UserSettingsData {
  final int searchCacheHours;
  final String audioQuality;
  final bool autoplayEnabled;
  final int crossfadeSeconds;
  final String preferredLyricsScript;

  const UserSettingsData({
    this.searchCacheHours = 6,
    this.audioQuality = '320k',
    this.autoplayEnabled = true,
    this.crossfadeSeconds = 3,
    this.preferredLyricsScript = 'roman',
  });

  factory UserSettingsData.fromMap(Map<String, dynamic> map) {
    return UserSettingsData(
      searchCacheHours: (map['search_cache_hours'] as num?)?.toInt() ?? 6,
      audioQuality: map['audio_quality']?.toString() ?? '320k',
      autoplayEnabled: map['autoplay_enabled'] as bool? ?? true,
      crossfadeSeconds: (map['crossfade_seconds'] as num?)?.toInt() ?? 3,
      preferredLyricsScript: map['preferred_lyrics_script']?.toString() ?? 'roman',
    );
  }

  Map<String, dynamic> toMap() => {
    'search_cache_hours': searchCacheHours,
    'audio_quality': audioQuality,
    'autoplay_enabled': autoplayEnabled,
    'crossfade_seconds': crossfadeSeconds,
    'preferred_lyrics_script': preferredLyricsScript,
    'updated_at': DateTime.now().toIso8601String(),
  };

  UserSettingsData copyWith({
    int? searchCacheHours,
    String? audioQuality,
    bool? autoplayEnabled,
    int? crossfadeSeconds,
    String? preferredLyricsScript,
  }) {
    return UserSettingsData(
      searchCacheHours: searchCacheHours ?? this.searchCacheHours,
      audioQuality: audioQuality ?? this.audioQuality,
      autoplayEnabled: autoplayEnabled ?? this.autoplayEnabled,
      crossfadeSeconds: crossfadeSeconds ?? this.crossfadeSeconds,
      preferredLyricsScript: preferredLyricsScript ?? this.preferredLyricsScript,
    );
  }
}

/// Central Supabase service handling Auth, Cloud Sync, and RLS interactions.
class SupabaseService {
  static const String supabaseUrl = 'https://pxyyzwxvqrbedvlbtltq.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_e4yvzhY8U_VRIzpsuhSOiA_MdfAafUm';

  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser => client.auth.currentUser;
  static bool get isAuthenticated => currentUser != null;

  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  /// Initializes Supabase in main.dart
  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        debug: kDebugMode,
      );
      debugPrint('[Supabase] Initialized successfully. Auth user: ${currentUser?.email}');
    } catch (e) {
      debugPrint('[Supabase] Init error: $e');
    }
  }

  // --- AUTHENTICATION ---

  static Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: displayName != null && displayName.isNotEmpty
          ? {'full_name': displayName.trim(), 'name': displayName.trim()}
          : null,
    );
    if (response.user != null) {
      await syncDownAllUserData();
    }
    return response;
  }

  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    if (response.user != null) {
      await syncDownAllUserData();
    }
    return response;
  }

  static Future<bool> signInWithGoogle() async {
    try {
      return await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.musicapp://login-callback',
      );
    } catch (e) {
      debugPrint('[Supabase] Google OAuth Error: $e');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  // --- PROFILES ---

  static Future<UserProfileData?> fetchProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final res = await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (res != null) {
        return UserProfileData.fromMap(res, user.email ?? '');
      }

      // If profile row was not yet created by trigger, create it now
      final newProfile = {
        'id': user.id,
        'email': user.email ?? '',
        'display_name': user.userMetadata?['full_name'] ??
            user.userMetadata?['name'] ??
            (user.email?.split('@')[0] ?? 'Music Lover'),
        'avatar_url': user.userMetadata?['avatar_url'] ?? '',
      };
      await client.from('profiles').upsert(newProfile);
      return UserProfileData.fromMap(newProfile, user.email ?? '');
    } catch (e) {
      debugPrint('[Supabase] Error fetching profile: $e');
      return UserProfileData(
        id: user.id,
        email: user.email ?? '',
        displayName: user.email?.split('@')[0] ?? 'Music Lover',
        avatarUrl: '',
      );
    }
  }

  static Future<void> updateProfile({
    required String displayName,
    String? avatarUrl,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final updates = {
      'display_name': displayName.trim(),
      if (avatarUrl != null) 'avatar_url': avatarUrl.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    await client.from('profiles').update(updates).eq('id', user.id);
  }

  // --- USER SETTINGS ---

  static Future<UserSettingsData> fetchUserSettings() async {
    final user = currentUser;
    if (user == null) return const UserSettingsData();

    try {
      final res = await client
          .from('user_settings')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (res != null) {
        return UserSettingsData.fromMap(res);
      }

      // Initialize defaults in Supabase if missing
      const defaults = UserSettingsData();
      final map = defaults.toMap();
      map['user_id'] = user.id;
      await client.from('user_settings').upsert(map);
      return defaults;
    } catch (e) {
      debugPrint('[Supabase] Error fetching settings: $e');
      return const UserSettingsData();
    }
  }

  static Future<void> updateUserSettings(UserSettingsData settings) async {
    final user = currentUser;
    if (user == null) return;

    try {
      final map = settings.toMap();
      map['user_id'] = user.id;
      await client.from('user_settings').upsert(map);
    } catch (e) {
      debugPrint('[Supabase] Error updating settings: $e');
    }
  }

  // --- CLOUD SYNC: RESTORE ON REINSTALL & NEW DEVICE ---

  /// Downloads all remote data (Playlists, Liked Songs, History, Settings, Taste)
  /// and merges into TrackMetadataStore local disk cache for 0ms access.
  static Future<void> syncDownAllUserData() async {
    final user = currentUser;
    if (user == null) return;

    try {
      debugPrint('[Supabase Sync] Restoring user cloud data...');

      // 1. Sync Liked Songs
      final likedRes = await client
          .from('liked_songs')
          .select()
          .eq('user_id', user.id);

      for (final row in likedRes) {
        final track = YoutubeTrack(
          id: row['track_id']?.toString() ?? '',
          title: row['title']?.toString() ?? '',
          artist: row['artist']?.toString() ?? '',
          thumbnailUrl: row['thumbnail_url']?.toString() ?? '',
          durationSeconds: (row['duration_seconds'] as num?)?.toInt() ?? 0,
        );
        if (track.id.isNotEmpty) {
          await TrackMetadataStore.saveTrackMetadata(track);
          final favIds = await TrackMetadataStore.getFavoriteIds();
          if (!favIds.contains(track.id)) {
            await TrackMetadataStore.toggleFavorite(track);
          }
        }
      }

      // 2. Sync Playlists & Songs
      final playlistsRes = await client
          .from('playlists')
          .select()
          .eq('user_id', user.id);

      for (final pRow in playlistsRes) {
        final pId = pRow['id']?.toString();
        final pName = pRow['name']?.toString() ?? '';
        if (pName.isNotEmpty) {
          await TrackMetadataStore.createPlaylist(pName);

          if (pId != null) {
            final pSongsRes = await client
                .from('playlist_songs')
                .select()
                .eq('playlist_id', pId);

            for (final sRow in pSongsRes) {
              final track = YoutubeTrack(
                id: sRow['track_id']?.toString() ?? '',
                title: sRow['title']?.toString() ?? '',
                artist: sRow['artist']?.toString() ?? '',
                thumbnailUrl: sRow['thumbnail_url']?.toString() ?? '',
                durationSeconds: (sRow['duration_seconds'] as num?)?.toInt() ?? 0,
              );
              if (track.id.isNotEmpty) {
                await TrackMetadataStore.addTrackToPlaylist(pName, track);
              }
            }
          }
        }
      }

      // 3. Sync Listening History
      final historyRes = await client
          .from('listening_history')
          .select()
          .eq('user_id', user.id)
          .order('played_at', ascending: false)
          .limit(30);

      for (final hRow in historyRes) {
        final track = YoutubeTrack(
          id: hRow['track_id']?.toString() ?? '',
          title: hRow['title']?.toString() ?? '',
          artist: hRow['artist']?.toString() ?? '',
          thumbnailUrl: hRow['thumbnail_url']?.toString() ?? '',
          durationSeconds: (hRow['duration_seconds'] as num?)?.toInt() ?? 0,
        );
        if (track.id.isNotEmpty) {
          await TrackMetadataStore.addToHistory(track);
        }
      }

      debugPrint('[Supabase Sync] Cloud restore completed successfully.');
    } catch (e) {
      debugPrint('[Supabase Sync] Sync down error: $e');
    }
  }

  // --- CLOUD SYNC: UPLOAD LOCAL MUTATIONS TO SUPABASE ---

  static Future<void> syncToggleLikedSong(YoutubeTrack track, bool isLiked) async {
    final user = currentUser;
    if (user == null) return;

    try {
      if (isLiked) {
        await client.from('liked_songs').upsert({
          'user_id': user.id,
          'track_id': track.id,
          'title': track.title,
          'artist': track.artist,
          'thumbnail_url': track.thumbnailUrl,
          'duration_seconds': track.durationSeconds,
          'liked_at': DateTime.now().toIso8601String(),
        });
      } else {
        await client
            .from('liked_songs')
            .delete()
            .eq('user_id', user.id)
            .eq('track_id', track.id);
      }
    } catch (e) {
      debugPrint('[Supabase Sync] Like sync error: $e');
    }
  }

  static Future<void> syncCreatePlaylist(String name) async {
    final user = currentUser;
    if (user == null) return;

    try {
      await client.from('playlists').insert({
        'user_id': user.id,
        'name': name.trim(),
      });
    } catch (e) {
      debugPrint('[Supabase Sync] Playlist create sync error: $e');
    }
  }

  static Future<void> syncDeletePlaylist(String name) async {
    final user = currentUser;
    if (user == null) return;

    try {
      await client
          .from('playlists')
          .delete()
          .eq('user_id', user.id)
          .eq('name', name.trim());
    } catch (e) {
      debugPrint('[Supabase Sync] Playlist delete sync error: $e');
    }
  }

  static Future<void> syncAddSongToPlaylist(String playlistName, YoutubeTrack track) async {
    final user = currentUser;
    if (user == null) return;

    try {
      // Find or create playlist id
      var pRes = await client
          .from('playlists')
          .select('id')
          .eq('user_id', user.id)
          .eq('name', playlistName.trim())
          .maybeSingle();

      String? playlistId = pRes?['id']?.toString();
      if (playlistId == null) {
        final inserted = await client.from('playlists').insert({
          'user_id': user.id,
          'name': playlistName.trim(),
        }).select('id').single();
        playlistId = inserted['id']?.toString();
      }

      if (playlistId != null) {
        await client.from('playlist_songs').upsert({
          'playlist_id': playlistId,
          'user_id': user.id,
          'track_id': track.id,
          'title': track.title,
          'artist': track.artist,
          'thumbnail_url': track.thumbnailUrl,
          'duration_seconds': track.durationSeconds,
          'added_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('[Supabase Sync] Add song to playlist sync error: $e');
    }
  }

  static Future<void> syncRemoveSongFromPlaylist(String playlistName, String trackId) async {
    final user = currentUser;
    if (user == null) return;

    try {
      final pRes = await client
          .from('playlists')
          .select('id')
          .eq('user_id', user.id)
          .eq('name', playlistName.trim())
          .maybeSingle();

      final playlistId = pRes?['id']?.toString();
      if (playlistId != null) {
        await client
            .from('playlist_songs')
            .delete()
            .eq('playlist_id', playlistId)
            .eq('track_id', trackId);
      }
    } catch (e) {
      debugPrint('[Supabase Sync] Remove song from playlist sync error: $e');
    }
  }

  static Future<void> syncAddListeningHistory(YoutubeTrack track) async {
    final user = currentUser;
    if (user == null) return;

    try {
      await client.from('listening_history').insert({
        'user_id': user.id,
        'track_id': track.id,
        'title': track.title,
        'artist': track.artist,
        'thumbnail_url': track.thumbnailUrl,
        'duration_seconds': track.durationSeconds,
        'played_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[Supabase Sync] History sync error: $e');
    }
  }

  static Future<void> syncTasteProfile({
    List<Map<String, dynamic>>? favoriteArtists,
    List<String>? favoriteLanguages,
    Map<String, dynamic>? tasteSignals,
  }) async {
    final user = currentUser;
    if (user == null) return;

    try {
      final updates = <String, dynamic>{
        'user_id': user.id,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (favoriteArtists != null) updates['favorite_artists'] = favoriteArtists;
      if (favoriteLanguages != null) updates['favorite_languages'] = favoriteLanguages;
      if (tasteSignals != null) updates['taste_signals'] = tasteSignals;

      await client.from('user_taste_profile').upsert(updates);
    } catch (e) {
      debugPrint('[Supabase Sync] Taste profile sync error: $e');
    }
  }
}
