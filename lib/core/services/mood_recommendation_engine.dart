import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

class VibeMixResult {
  final String companionMessage;
  final List<YoutubeTrack> tracks;

  const VibeMixResult({
    required this.companionMessage,
    required this.tracks,
  });
}

class MoodRecommendationEngine {
  final YoutubeMusicService _musicService;

  // Configurable Groq AI Provider (Never hardcoded; loaded via env, Supabase, or settings)
  static const String _envGroqKey = String.fromEnvironment('GROQ_API_KEY');
  static String _runtimeApiKey = _envGroqKey;

  static String get groqApiKey => _runtimeApiKey;
  static set groqApiKey(String key) => _runtimeApiKey = key.trim();
  static bool get hasGroqKey => _runtimeApiKey.isNotEmpty;
  static const String groqModel = 'llama-3.3-70b-versatile';
  static const String groqEndpoint = 'https://api.groq.com/openai/v1/chat/completions';

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

  /// Generates real playable tracks using Groq AI inference with instant fallback to dynamic query synthesis.
  /// ZERO hardcoding. Merges, de-duplicates, and ranks using taste profile.
  Future<VibeMixResult> generateRecommendations({
    required Set<String> selectedMoodIds,
    required String customDescription,
    required MoodContentStyle style,
    List<String>? userLanguages,
  }) async {
    String companionMessage = 'Tuned directly into your emotional frequency.';
    final queries = <String>[];

    // 1. Try Groq AI Inference
    if (groqApiKey.isNotEmpty) {
      try {
        final aiResult = await _queryGroqAI(
          selectedMoodIds: selectedMoodIds,
          customDescription: customDescription,
          style: style,
        ).timeout(const Duration(seconds: 4));

        if (aiResult != null && aiResult.queries.isNotEmpty) {
          companionMessage = aiResult.message;
          queries.addAll(aiResult.queries);
        }
      } catch (_) {
        // Quiet fallback to rule-based synthesis
      }
    }

    // 2. Fallback / Supplement: Dynamic query synthesis
    if (queries.isEmpty) {
      final selectedMoods = availableMoods.where((m) => selectedMoodIds.contains(m.id)).toList();
      if (selectedMoods.isNotEmpty) {
        final combinedMoodWords = selectedMoods.map((m) => m.queryPrompt).join(' ');
        queries.add(combinedMoodWords);
        for (final m in selectedMoods.take(2)) {
          queries.add(m.queryPrompt);
        }
      }

      final cleanCustom = customDescription.trim();
      if (cleanCustom.isNotEmpty) {
        queries.insert(0, cleanCustom);
      }

      if (queries.isEmpty) {
        queries.add('trending chill soothing hits');
      }
    }

    // 3. Apply style modifier
    final styleModifier = _getStyleModifier(style);

    // 4. Query sources concurrently
    final results = <YoutubeTrack>[];
    final seenKeys = <String>{};

    final futures = queries.take(4).map((baseQuery) async {
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
          if (_matchesStyle(track, style)) {
            results.add(track);
          }
        }
      }
    }

    // 5. Rerank through user's taste engine
    final reranked = TasteEngine.rerankSearchResults(results);

    // 6. Save session metadata to Supabase / local cache for taste adaptation
    _recordMoodSession(selectedMoodIds, customDescription.trim(), style.label, reranked.length);

    return VibeMixResult(
      companionMessage: companionMessage,
      tracks: reranked,
    );
  }

  /// Calls Groq API with specialist companion system prompt
  Future<({String message, List<String> queries})?> _queryGroqAI({
    required Set<String> selectedMoodIds,
    required String customDescription,
    required MoodContentStyle style,
  }) async {
    final moods = selectedMoodIds.join(', ');
    final tasteArtists = TasteEngine.favoriteArtists.map((a) => a.name).take(4).join(', ');

    final systemPrompt = '''
You are the user's audio companion inside a personal music app: part music therapist, part curator, part close friend with great taste.
Your task is to understand the user's feelings and recommend real audio tracks, audio dramas, stories, and podcasts.
Output strictly valid JSON with this format:
{
  "companionMessage": "1-2 warm empathetic sentences explaining what you picked",
  "suggestions": [
    {"searchQuery": "song or show title with artist name for search", "type": "song|show|podcast"}
  ]
}
''';

    final userPrompt = '''
Current feelings: $moods
Personal description: $customDescription
Content preference: ${style.label}
Favorite artists: $tasteArtists
Recommend 5 to 7 real audio picks.
''';

    final response = await http.post(
      Uri.parse(groqEndpoint),
      headers: {
        'Authorization': 'Bearer $groqApiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': groqModel,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': 0.7,
        'response_format': {'type': 'json_object'},
      }),
    );

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body);
    final content = data['choices']?[0]?['message']?['content']?.toString() ?? '';
    if (content.isEmpty) return null;

    final parsed = jsonDecode(content);
    final msg = parsed['companionMessage']?.toString() ?? 'Curated for your state of mind.';
    final suggestions = parsed['suggestions'] as List<dynamic>? ?? [];

    final qList = <String>[];
    for (final s in suggestions) {
      if (s is Map && s['searchQuery'] != null) {
        qList.add(s['searchQuery'].toString());
      }
    }

    return (message: msg, queries: qList);
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
