import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/music/models/music_models.dart';
import 'supabase_service.dart';
import 'youtube_music_service.dart';

class ArtistProfile {
  final String id;
  final String name;
  final String imageUrl;
  final String language;

  const ArtistProfile({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.language,
  });

  factory ArtistProfile.fromJson(Map<String, dynamic> json) {
    return ArtistProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? json['image']?.toString() ?? '',
      language: json['language']?.toString() ?? 'All',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'imageUrl': imageUrl,
    'language': language,
  };
}

/// Dynamic Taste Engine (Local-first + Supabase Cloud Sync)
/// Learns user preferences, favorite artists, languages, and dynamically ranks recommendations.
class TasteEngine {
  static List<ArtistProfile> _favoriteArtists = [];
  static List<String> _preferredLanguages = ['English', 'Hindi', 'Bengali'];
  static Map<String, int> _artistPlayWeights = {};
  static bool _initialized = false;

  static List<ArtistProfile> get favoriteArtists => List.unmodifiable(_favoriteArtists);
  static List<ArtistProfile> get selectedArtists => List.unmodifiable(_favoriteArtists);
  static List<String> get preferredLanguages => List.unmodifiable(_preferredLanguages);
  static bool get hasCompletedOnboarding => _favoriteArtists.isNotEmpty;

  /// Alias for rerankWithTaste
  static List<YoutubeTrack> rerankSearchResults(List<YoutubeTrack> tracks) => rerankWithTaste(tracks);

  static Future<File> _getLocalFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/taste_engine_profile.json');
  }

  /// Initialize local-first cache (<5ms) and background sync with Supabase
  static Future<void> init() async {
    if (_initialized) return;

    try {
      final file = await _getLocalFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = json.decode(content) as Map<String, dynamic>;
        
        final artistsRaw = data['favoriteArtists'] as List<dynamic>? ?? [];
        _favoriteArtists = artistsRaw.map((a) => ArtistProfile.fromJson(a as Map<String, dynamic>)).toList();

        final langsRaw = data['preferredLanguages'] as List<dynamic>? ?? [];
        _preferredLanguages = langsRaw.map((l) => l.toString()).toList();

        final weightsRaw = data['artistPlayWeights'] as Map<String, dynamic>? ?? {};
        _artistPlayWeights = weightsRaw.map((k, v) => MapEntry(k, (v as num).toInt()));
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[TasteEngine] Local init error: $e');
    }

    // Background sync from Supabase if authenticated
    if (SupabaseService.isAuthenticated) {
      _syncDownFromCloud();
    }
  }

  static Future<void> _syncDownFromCloud() async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) return;

      final res = await SupabaseService.client
          .from('user_taste_profile')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (res != null) {
        final artistsJson = res['favorite_artists'] as List<dynamic>? ?? [];
        final cloudArtists = artistsJson.map((a) => ArtistProfile.fromJson(Map<String, dynamic>.from(a as Map))).toList();

        final langsJson = res['favorite_languages'] as List<dynamic>? ?? [];
        final cloudLangs = langsJson.map((l) => l.toString()).toList();

        if (cloudArtists.isNotEmpty) {
          _favoriteArtists = cloudArtists;
        }
        if (cloudLangs.isNotEmpty) {
          _preferredLanguages = cloudLangs;
        }

        await _persistLocal();
      }
    } catch (e) {
      debugPrint('[TasteEngine] Cloud sync down error: $e');
    }
  }

  static Future<void> _persistLocal() async {
    try {
      final file = await _getLocalFile();
      final data = {
        'favoriteArtists': _favoriteArtists.map((a) => a.toJson()).toList(),
        'preferredLanguages': _preferredLanguages,
        'artistPlayWeights': _artistPlayWeights,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await file.writeAsString(json.encode(data));
    } catch (e) {
      debugPrint('[TasteEngine] Persist error: $e');
    }
  }

  /// Sets user favorite artists and syncs immediately to Supabase
  static Future<void> setFavoriteArtists(List<ArtistProfile> artists) async {
    _favoriteArtists = List.from(artists);
    await _persistLocal();

    if (SupabaseService.isAuthenticated) {
      SupabaseService.syncTasteProfile(
        favoriteArtists: _favoriteArtists.map((a) => a.toJson()).toList(),
        favoriteLanguages: _preferredLanguages,
      ).catchError((_) {});
    }
  }

  /// Toggle an individual artist
  static Future<bool> toggleArtist(ArtistProfile artist) async {
    final idx = _favoriteArtists.indexWhere((a) => a.name.toLowerCase() == artist.name.toLowerCase());
    bool isAdded;
    if (idx >= 0) {
      _favoriteArtists.removeAt(idx);
      isAdded = false;
    } else {
      _favoriteArtists.add(artist);
      isAdded = true;
    }

    await _persistLocal();

    if (SupabaseService.isAuthenticated) {
      SupabaseService.syncTasteProfile(
        favoriteArtists: _favoriteArtists.map((a) => a.toJson()).toList(),
      ).catchError((_) {});
    }

    return isAdded;
  }

  static bool isArtistFavorite(String name) {
    return _favoriteArtists.any((a) => a.name.toLowerCase() == name.trim().toLowerCase());
  }

  /// Records a play signal to increase weight for that artist
  static Future<void> recordPlaySignal(String artistName) async {
    final clean = artistName.trim().toLowerCase();
    if (clean.isEmpty) return;

    _artistPlayWeights[clean] = (_artistPlayWeights[clean] ?? 0) + 1;
    await _persistLocal();
  }

  /// Reranks search results or recommendations so favorite & highly-played artists appear first
  static List<YoutubeTrack> rerankWithTaste(List<YoutubeTrack> tracks) {
    if (_favoriteArtists.isEmpty && _artistPlayWeights.isEmpty) {
      return tracks;
    }

    final favoriteNames = _favoriteArtists.map((a) => a.name.toLowerCase()).toSet();
    final scoredList = List<YoutubeTrack>.from(tracks);

    scoredList.sort((a, b) {
      int scoreA = 0;
      int scoreB = 0;

      final artistALower = a.artist.toLowerCase();
      final artistBLower = b.artist.toLowerCase();

      // Priority 1: Picked Favorite Artist (+50 score)
      if (favoriteNames.any((fav) => artistALower.contains(fav))) scoreA += 50;
      if (favoriteNames.any((fav) => artistBLower.contains(fav))) scoreB += 50;

      // Priority 2: Play Frequency Weight (+1 per play, up to 20)
      scoreA += (_artistPlayWeights[artistALower] ?? 0).clamp(0, 20);
      scoreB += (_artistPlayWeights[artistBLower] ?? 0).clamp(0, 20);

      return scoreB.compareTo(scoreA);
    });

    return scoredList;
  }

  /// Dynamic live popular artist queries for the Onboarding grid across English, Hindi, Bengali (Zero Hardcoding)
  static Future<List<ArtistProfile>> fetchPopularArtistsPool(YoutubeMusicService musicService, {String language = 'All'}) async {
    final pool = <ArtistProfile>[];
    final seen = <String>{};

    final queries = <String, String>{
      'English': 'top worldwide singers pop rock artist',
      'Hindi': 'top bollywood singers arijit shreya playback artists',
      'Bengali': 'bengali top artists anupam arijit nachiketa shreya',
    };

    final selectedQueries = (language == 'All')
        ? queries.entries
        : queries.entries.where((e) => e.key.toLowerCase() == language.toLowerCase());

    for (final entry in selectedQueries) {
      final lang = entry.key;
      final query = entry.value;

      try {
        final tracks = await musicService.searchTracks(query);
        for (final t in tracks) {
          final cleanArtist = t.artist.split(',')[0].split('&')[0].trim();
          if (cleanArtist.isNotEmpty && cleanArtist.length > 2 && !seen.contains(cleanArtist.toLowerCase())) {
            seen.add(cleanArtist.toLowerCase());
            pool.add(ArtistProfile(
              id: 'artist_${cleanArtist.hashCode.abs()}',
              name: cleanArtist,
              imageUrl: t.thumbnailUrl,
              language: lang,
            ));
          }
        }
      } catch (_) {}
    }

    return pool;
  }
}
