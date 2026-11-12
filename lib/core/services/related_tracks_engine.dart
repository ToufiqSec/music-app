import 'dart:async';
import '../../features/music/models/music_models.dart';
import '../../widgets/generated_cover_art.dart';
import 'youtube_music_service.dart';
import 'taste_engine.dart';

/// Replaceable related-track & autoplay recommendation engine (Issue 8).
/// Dispatches live catalog queries with zero hardcoded tracks or playlists.
/// Guarantees:
/// 1. Content-type continuity (Song -> similar song, Show -> next episode/show).
/// 2. Loop prevention via ring buffer of recently played tracks.
/// 3. Taste weighting from Issue 4 artist preferences.
abstract class IRelatedTracksEngine {
  Future<YoutubeTrack?> findNextRelatedTrack(
    YoutubeTrack currentTrack, {
    Set<String>? excludeIds,
  });
  void markTrackPlayed(String trackId);
}

class RelatedTracksEngine implements IRelatedTracksEngine {
  final YoutubeMusicService _musicService;
  final List<String> _recentHistoryRing = [];
  static const int _maxRingSize = 30;

  // Cached pre-resolved candidate per track ID
  final Map<String, YoutubeTrack> _prefetchedCandidates = {};

  RelatedTracksEngine(this._musicService);

  @override
  void markTrackPlayed(String trackId) {
    _recentHistoryRing.remove(trackId);
    _recentHistoryRing.add(trackId);
    if (_recentHistoryRing.length > _maxRingSize) {
      _recentHistoryRing.removeAt(0);
    }
  }

  /// Returns pre-cached candidate if available, otherwise resolves fresh from live sources
  @override
  Future<YoutubeTrack?> findNextRelatedTrack(
    YoutubeTrack currentTrack, {
    Set<String>? excludeIds,
  }) async {
    // 1. Check if we already prefetched a verified candidate for this track
    if (_prefetchedCandidates.containsKey(currentTrack.id)) {
      final candidate = _prefetchedCandidates.remove(currentTrack.id)!;
      final isExcluded = (excludeIds != null && excludeIds.contains(candidate.id)) ||
          _recentHistoryRing.contains(candidate.id);
      if (!isExcluded) {
        return candidate;
      }
    }

    final effectiveExcludes = <String>{
      currentTrack.id,
      ..._recentHistoryRing,
      if (excludeIds != null) ...excludeIds,
    };

    final type = AudioTypeDetector.detect(
      currentTrack.title,
      currentTrack.artist,
      currentTrack.durationSeconds,
    );

    List<YoutubeTrack> candidates = [];

    // 2. Specialized sequential resolution for Shows, Audiobooks & Podcasts
    if (type == AudioContentType.show ||
        type == AudioContentType.audiobook ||
        type == AudioContentType.podcast) {
      candidates = await _resolveNextEpisodeOrShow(currentTrack, effectiveExcludes);
    }

    // 3. If not a show or no next episode found, resolve music via Artist & Taste Graph
    if (candidates.isEmpty) {
      candidates = await _resolveSimilarMusic(currentTrack, effectiveExcludes);
    }

    if (candidates.isEmpty) return null;

    // Pick top non-excluded candidate
    for (final c in candidates) {
      if (!effectiveExcludes.contains(c.id)) {
        return c;
      }
    }

    return candidates.isNotEmpty ? candidates.first : null;
  }

  /// Pre-resolves and stores next track candidate for zero-delay switch
  Future<void> prefetchForTrack(YoutubeTrack currentTrack) async {
    if (_prefetchedCandidates.containsKey(currentTrack.id)) return;
    final candidate = await findNextRelatedTrack(currentTrack);
    if (candidate != null) {
      _prefetchedCandidates[currentTrack.id] = candidate;
    }
  }

  /// Resolves next episode or series chapter for narrative audio (e.g., Sunday Suspense)
  Future<List<YoutubeTrack>> _resolveNextEpisodeOrShow(
    YoutubeTrack current,
    Set<String> excludes,
  ) async {
    final title = current.title;

    // Try detecting numeric episode / part patterns (e.g. Episode 2, Part 3, Ep 04, #5)
    final epMatch = RegExp(r'(?:episode|part|ep|#)\s*(\d+)', caseSensitive: false).firstMatch(title);
    if (epMatch != null) {
      final currentNum = int.tryParse(epMatch.group(1) ?? '');
      if (currentNum != null) {
        final nextNum = currentNum + 1;
        final baseTitle = title.replaceRange(epMatch.start, epMatch.end, '').trim();
        final query = '${current.artist} $baseTitle Episode $nextNum';
        final results = await _musicService.searchTracks(query);
        final filtered = results.where((t) => !excludes.contains(t.id)).toList();
        if (filtered.isNotEmpty) return filtered;
      }
    }

    // Fallback: search the artist / channel + series for more episodes
    final seriesQuery = '${current.artist} ${current.title.split(RegExp(r'[-:|]')).first.trim()}';
    final results = await _musicService.searchTracks(seriesQuery);
    return results.where((t) => !excludes.contains(t.id)).toList();
  }

  /// Resolves musically similar tracks using Artist, Mood, and Taste Profile
  Future<List<YoutubeTrack>> _resolveSimilarMusic(
    YoutubeTrack current,
    Set<String> excludes,
  ) async {
    // Strategy 1: Artist + Song seed query
    final seedQuery = '${current.artist} ${current.title}';
    var results = await _musicService.searchTracks('$seedQuery similar song');

    // Strategy 2: If few results, query artist radio
    if (results.length < 3) {
      final artistQuery = '${current.artist} best songs';
      final more = await _musicService.searchTracks(artistQuery);
      results = [...results, ...more];
    }

    // Strategy 3: TasteEngine boost
    final tasteArtists = TasteEngine.selectedArtists;
    if (tasteArtists.isNotEmpty) {
      results = TasteEngine.rerankSearchResults(results);
    }

    return results.where((t) => !excludes.contains(t.id)).toList();
  }
}
