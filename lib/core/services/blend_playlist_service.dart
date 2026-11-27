import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../features/music/models/music_models.dart';
import 'mood_recommendation_engine.dart';
import 'taste_engine.dart';
import 'youtube_music_service.dart';

class BlendTasteSnapshot {
  final String displayName;
  final List<String> artists;
  final List<String> languages;

  const BlendTasteSnapshot({
    required this.displayName,
    required this.artists,
    this.languages = const [],
  });

  Map<String, dynamic> toJson() => {
        'n': displayName,
        'a': artists,
        'l': languages,
      };

  factory BlendTasteSnapshot.fromJson(Map<String, dynamic> json) {
    return BlendTasteSnapshot(
      displayName: json['n']?.toString() ?? 'Friend',
      artists: (json['a'] as List<dynamic>? ?? []).map((e) => e.toString()).where((e) => e.isNotEmpty).toList(),
      languages: (json['l'] as List<dynamic>? ?? []).map((e) => e.toString()).where((e) => e.isNotEmpty).toList(),
    );
  }
}

class BlendPlaylistResult {
  final String playlistTitle;
  final int matchPercentage;
  final List<YoutubeTrack> tracks;
  final String friendName;

  const BlendPlaylistResult({
    required this.playlistTitle,
    required this.matchPercentage,
    required this.tracks,
    required this.friendName,
  });
}

/// Collaborative Blend Playlist Service (AGENT.md Rule 6).
/// Merges two users' musical tastes, interleaves live tracks, enforces 15+ track minimum
/// and avoids consecutive songs from the same artist.
class BlendPlaylistService {
  static const String _prefix = 'SWARVA-BLEND:';
  static const int _minBlendTracks = 15;

  /// Exports the current user's taste profile as a shareable Blend code.
  static String exportCurrentUserTasteCode({String displayName = 'You'}) {
    final topArtists = TasteEngine.favoriteArtists.map((a) => a.name).take(6).toList();
    if (topArtists.isEmpty) {
      topArtists.addAll(TasteEngine.defaultArtistCatalog.take(4).map((a) => a.name));
    }
    final snapshot = BlendTasteSnapshot(
      displayName: displayName,
      artists: topArtists,
      languages: TasteEngine.preferredLanguages.take(3).toList(),
    );
    final encoded = base64UrlEncode(utf8.encode(json.encode(snapshot.toJson())));
    return '$_prefix$encoded';
  }

  /// Parses either a `SWARVA-BLEND:...` code or a comma-separated list of artist names.
  static BlendTasteSnapshot? parseTasteInput(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith(_prefix)) {
      try {
        final payload = trimmed.substring(_prefix.length).trim();
        final decoded = utf8.decode(base64Url.decode(payload));
        final map = json.decode(decoded) as Map<String, dynamic>;
        final snapshot = BlendTasteSnapshot.fromJson(map);
        if (snapshot.artists.isNotEmpty) return snapshot;
      } catch (e) {
        debugPrint('[BlendPlaylistService] Invalid blend code: $e');
        return null;
      }
    }

    // Fallback: comma-separated artist names (e.g., "Arijit Singh, Coldplay, KK")
    final artists = trimmed
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(6)
        .toList();
    if (artists.isEmpty) return null;

    return BlendTasteSnapshot(
      displayName: artists.first,
      artists: artists,
    );
  }

  /// Computes a deterministic 0-100% musical taste match score between two artist lists.
  static int computeTasteMatchPercent(List<String> userArtists, List<String> friendArtists) {
    final setA = userArtists.map((e) => e.toLowerCase().trim()).where((e) => e.isNotEmpty).toSet();
    final setB = friendArtists.map((e) => e.toLowerCase().trim()).where((e) => e.isNotEmpty).toSet();
    if (setA.isEmpty || setB.isEmpty) return 65;

    final overlap = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    if (union == 0) return 65;

    final jaccard = overlap / union;
    return (55 + (jaccard * 45)).round().clamp(55, 99);
  }

  /// Generates a blended, deduplicated, artist-spaced playlist from two users' tastes.
  static Future<BlendPlaylistResult> generateBlendPlaylist({
    required YoutubeMusicService musicService,
    required BlendTasteSnapshot friendTaste,
    String currentUserName = 'You',
  }) async {
    final myArtists = TasteEngine.favoriteArtists.map((a) => a.name).take(4).toList();
    if (myArtists.isEmpty) {
      myArtists.addAll(['Arijit Singh', 'Pritam', 'The Weeknd']);
    }

    final friendArtists = friendTaste.artists.take(4).toList();
    final matchPct = computeTasteMatchPercent(myArtists, friendArtists);

    // Interleave artist queries from both users and fetch concurrently
    final combinedArtists = <String>[];
    final maxLen = myArtists.length > friendArtists.length ? myArtists.length : friendArtists.length;
    for (int i = 0; i < maxLen; i++) {
      if (i < myArtists.length && !combinedArtists.contains(myArtists[i])) {
        combinedArtists.add(myArtists[i]);
      }
      if (i < friendArtists.length && !combinedArtists.contains(friendArtists[i])) {
        combinedArtists.add(friendArtists[i]);
      }
    }

    final searchFutures = combinedArtists.take(6).map(
          (artist) => musicService.searchTracks('$artist top songs').catchError((_) => <YoutubeTrack>[]),
        );
    final batches = await Future.wait(searchFutures);

    final merged = <YoutubeTrack>[];
    final seenKeys = <String>{};

    // Round-robin merge across artist result lists so both tastes are evenly represented
    int depth = 0;
    bool addedAny = true;
    while (addedAny && merged.length < 25) {
      addedAny = false;
      for (final batch in batches) {
        if (depth < batch.length) {
          addedAny = true;
          final track = batch[depth];
          final key = '${track.title.toLowerCase()}_${track.artist.toLowerCase()}';
          if (!seenKeys.contains(key)) {
            seenKeys.add(key);
            merged.add(track);
          }
        }
      }
      depth++;
    }

    // Enforce minimum 15 tracks if needed
    if (merged.length < _minBlendTracks) {
      try {
        final extra = await musicService.searchTracks('${combinedArtists.first} hits');
        for (final track in extra) {
          final key = '${track.title.toLowerCase()}_${track.artist.toLowerCase()}';
          if (!seenKeys.contains(key)) {
            seenKeys.add(key);
            merged.add(track);
            if (merged.length >= _minBlendTracks) break;
          }
        }
      } catch (_) {}
    }

    final spaced = MoodRecommendationEngine.avoidConsecutiveSameArtist(merged);
    final title = '$currentUserName + ${friendTaste.displayName} Blend';

    return BlendPlaylistResult(
      playlistTitle: title,
      matchPercentage: matchPct,
      tracks: spaced,
      friendName: friendTaste.displayName,
    );
  }
}
