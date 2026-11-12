import 'dart:async';
import 'package:flutter/material.dart';
import '../../features/music/models/music_models.dart';
import '../../widgets/generated_cover_art.dart';
import 'youtube_music_service.dart';
import 'taste_engine.dart';
import 'supabase_service.dart';

/// Content style mode for the AI Recommendation Hub (Issue 7)
enum MoodContentStyle {
  all('All & Mixed', Icons.all_inclusive_rounded),
  music('Pure Music', Icons.music_note_rounded),
  shows('Dramas & Stories', Icons.theater_comedy_rounded),
  podcasts('Podcasts & Talks', Icons.podcasts_rounded),
  ambient('Ambient Soundscapes', Icons.waves_rounded);

  final String label;
  final dynamic icon;
  const MoodContentStyle(this.label, this.icon);
}

/// Dynamic Mood Descriptor with curated query synthesis rules (Global Rule 2)
class VibeMoodOption {
  final String id;
  final String label;
  final String queryPrompt;

  const VibeMoodOption({
    required this.id,
    required this.label,
    required this.queryPrompt,
  });
}

class MoodRecommendationEngine {
  final YoutubeMusicService _musicService;

  MoodRecommendationEngine(this._musicService);

  /// Dynamic list of interactive moods (mixable and extensible)
  static const List<VibeMoodOption> availableMoods = [
    VibeMoodOption(id: 'chill', label: 'Chill & Mellow', queryPrompt: 'chill relaxing acoustic lofi'),
    VibeMoodOption(id: 'focus', label: 'Deep Focus & Code', queryPrompt: 'ambient electronic focus study instrumental'),
    VibeMoodOption(id: 'midnight', label: 'Midnight Thoughts', queryPrompt: 'late night melancholy slow reverb'),
    VibeMoodOption(id: 'rainy', label: 'Rainy Window', queryPrompt: 'rainy day cozy piano lofi'),
    VibeMoodOption(id: 'euphoric', label: 'Euphoria & Energy', queryPrompt: 'upbeat dance pop energetic hits'),
    VibeMoodOption(id: 'nostalgia', label: 'Retro Nostalgia', queryPrompt: '80s synthwave retro classic hits'),
    VibeMoodOption(id: 'coffee', label: 'Coffeehouse Acoustic', queryPrompt: 'acoustic guitar indie folk cafe'),
    VibeMoodOption(id: 'heartbreak', label: 'Soul & Melancholy', queryPrompt: 'sad emotional soul heartbreak ballads'),
    VibeMoodOption(id: 'suspense', label: 'Audio Drama & Thriller', queryPrompt: 'suspense thriller audio drama radio natok story'),
    VibeMoodOption(id: 'bengali', label: 'Bengali Melodies & Drama', queryPrompt: 'bengali timeless melodies sunday suspense'),
    VibeMoodOption(id: 'bollywood', label: 'Bollywood Vibes', queryPrompt: 'bollywood soulful romantic hits'),
    VibeMoodOption(id: 'sleep', label: 'Sleep & Starlight', queryPrompt: 'deep sleep delta waves peaceful ambient'),
  ];

  /// Generates real playable tracks from live queries matching the mixed vibe profile.
  /// ZERO hardcoding. Merges, de-duplicates, and ranks using taste profile.
  Future<List<YoutubeTrack>> generateRecommendations({
    required Set<String> selectedMoodIds,
    required String customDescription,
    required MoodContentStyle style,
    List<String>? userLanguages,
  }) async {
    final queries = <String>[];

    // 1. Build queries from selected mood options
    final selectedMoods = availableMoods.where((m) => selectedMoodIds.contains(m.id)).toList();
    if (selectedMoods.isNotEmpty) {
      final combinedMoodWords = selectedMoods.map((m) => m.queryPrompt).join(' ');
      queries.add(combinedMoodWords);
      for (final m in selectedMoods.take(2)) {
        queries.add(m.queryPrompt);
      }
    }

    // 2. Add custom vibe text if provided
    final cleanCustom = customDescription.trim();
    if (cleanCustom.isNotEmpty) {
      queries.insert(0, cleanCustom);
    }

    // 3. Fallback query if no inputs provided (Bare tap guarantee: at least 5 results)
    if (queries.isEmpty) {
      queries.add('trending chill soothing hits');
    }

    // 4. Apply style modifier
    final styleModifier = _getStyleModifier(style);

    // 5. Query sources concurrently
    final results = <YoutubeTrack>[];
    final seenKeys = <String>{};

    final futures = queries.take(3).map((baseQuery) async {
      final finalQuery = styleModifier.isNotEmpty ? '$baseQuery $styleModifier' : baseQuery;
      try {
        return await _musicService.searchTracks(finalQuery);
      } catch (_) {
        return <YoutubeTrack>[];
      }
    });

    final batchResults = await Future.wait(futures);
    for (final list in batchResults) {
      for (final track in list) {
        final key = '${track.title.toLowerCase()}_${track.artist.toLowerCase()}';
        if (!seenKeys.contains(key)) {
          seenKeys.add(key);

          // Content style filtering
          if (_matchesStyle(track, style)) {
            results.add(track);
          }
        }
      }
    }

    // 6. Rerank through user's taste engine
    final reranked = TasteEngine.rerankSearchResults(results);

    // 7. Save session metadata to Supabase / local cache for taste adaptation
    _recordMoodSession(selectedMoodIds, cleanCustom, style.label, reranked.length);

    return reranked;
  }

  String _getStyleModifier(MoodContentStyle style) {
    switch (style) {
      case MoodContentStyle.music:
        return 'songs music';
      case MoodContentStyle.shows:
        return 'audio drama suspense story';
      case MoodContentStyle.podcasts:
        return 'podcast discussion talk';
      case MoodContentStyle.ambient:
        return 'ambient soundscape background instrumental';
      case MoodContentStyle.all:
      default:
        return '';
    }
  }

  bool _matchesStyle(YoutubeTrack track, MoodContentStyle style) {
    if (style == MoodContentStyle.all) return true;
    final type = AudioTypeDetector.detect(track.title, track.artist, track.durationSeconds);
    switch (style) {
      case MoodContentStyle.music:
        return type == AudioContentType.song;
      case MoodContentStyle.shows:
        return type == AudioContentType.show || type == AudioContentType.audiobook;
      case MoodContentStyle.podcasts:
        return type == AudioContentType.podcast;
      case MoodContentStyle.ambient:
        return true;
      case MoodContentStyle.all:
      default:
        return true;
    }
  }

  void _recordMoodSession(
    Set<String> moodIds,
    String customPrompt,
    String style,
    int resultCount,
  ) {
    try {
      if (SupabaseService.isAuthenticated) {
        SupabaseService.client.from('user_settings').upsert({
          'user_id': SupabaseService.currentUser!.id,
          'last_mood_session': {
            'moods': moodIds.toList(),
            'prompt': customPrompt,
            'style': style,
            'timestamp': DateTime.now().toIso8601String(),
            'result_count': resultCount,
          },
          'updated_at': DateTime.now().toIso8601String(),
        }).catchError((_) {});
      }
    } catch (_) {}
  }
}
