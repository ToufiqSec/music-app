import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../features/music/models/music_models.dart';
import 'curated_tracks.dart';
import 'supabase_service.dart';

/// Policy-compliant Podcast RSS & Enclosure Resolver.
/// Resolves podcast audio directly from authorized public RSS feeds, cached via Supabase Edge Function
/// in Postgres with a 6-hour TTL, streaming direct audio enclosures (audio/mpeg).
/// Completely eliminates extraction or re-hosting of YouTube streams for podcasts (Phase 3).
class PodcastRssService {
  static final Map<String, List<YoutubeTrack>> _cache = {};
  static const String _edgeFunctionUrl = '${SupabaseService.supabaseUrl}/functions/v1/fetch-podcasts';

  /// Fetches real episodes from the Supabase Edge Function & Postgres cache
  static Future<List<YoutubeTrack>> fetchSundaySuspenseEpisodes({int limit = 15, bool forceRefresh = false}) async {
    final cacheKey = 'ss_${limit}_$forceRefresh';
    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    // 1. Try Supabase Edge Function (server-side RSS parsing + 6-hour Postgres cache)
    try {
      final uri = Uri.parse('$_edgeFunctionUrl?limit=$limit${forceRefresh ? '&force=true' : ''}');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final items = (data['episodes'] as List<dynamic>?) ?? [];

        final tracks = _mapEpisodesToTracks(items);
        if (tracks.isNotEmpty) {
          _cache[cacheKey] = tracks;
          debugPrint('[PodcastRssService] Fetched ${tracks.length} episodes via Supabase Edge Function (${data['source']})');
          return tracks;
        }
      }
    } catch (e) {
      debugPrint('[PodcastRssService] Edge Function fetch error: $e. Falling back to direct database read...');
    }

    // 2. Direct Supabase Postgres query fallback
    try {
      final rows = await SupabaseService.client
          .from('podcast_episodes')
          .select('*')
          .eq('show_id', 'sunday_suspense')
          .order('published_at', ascending: false)
          .limit(limit);

      final tracks = _mapEpisodesToTracks(rows);
      if (tracks.isNotEmpty) {
        _cache[cacheKey] = tracks;
        debugPrint('[PodcastRssService] Loaded ${tracks.length} episodes directly from Postgres table');
        return tracks;
      }
    } catch (e) {
      debugPrint('[PodcastRssService] Direct Postgres read error: $e');
    }

    // 3. Fallback to curated tracks catalog if offline
    return CuratedTracks.featuredPodcasts;
  }

  static List<YoutubeTrack> _mapEpisodesToTracks(List<dynamic> items) {
    return items.map<YoutubeTrack>((item) {
      final id = item['id']?.toString() ?? '';
      final title = item['title']?.toString() ?? 'Sunday Suspense Episode';
      final durationSec = (item['duration_seconds'] as num?)?.toInt() ?? 3600;
      final imageUrl = item['thumbnail_url']?.toString() ?? '';
      final enclosureUrl = item['enclosure_url']?.toString();

      return YoutubeTrack(
        id: id,
        title: title,
        artist: item['artist']?.toString() ?? 'Sunday Suspense • Mirchi Bangla',
        durationSeconds: durationSec,
        thumbnailUrl: imageUrl.isNotEmpty
            ? imageUrl
            : 'https://d3wo5wojvuv7l.cloudfront.net/t_rss_itunes_square_1400/images.spreaker.com/original/1448de548583885ff422361fdb951f38.jpg',
        audioStreamUrl: enclosureUrl,
      );
    }).toList();
  }

  /// Resolves the audio enclosure URL for a given podcast query or episode ID
  static Future<String?> resolvePodcastEnclosure(String query) async {
    final clean = query.trim().toLowerCase();
    final episodes = await fetchSundaySuspenseEpisodes(limit: 25);
    if (episodes.isEmpty) return null;

    // Direct ID match
    for (final ep in episodes) {
      if (ep.id.toLowerCase() == clean && ep.audioStreamUrl != null && ep.audioStreamUrl!.isNotEmpty) {
        return ep.audioStreamUrl;
      }
    }

    // Keyword match
    for (final ep in episodes) {
      if ((ep.title.toLowerCase().contains(clean) || clean.contains(ep.title.toLowerCase())) &&
          ep.audioStreamUrl != null &&
          ep.audioStreamUrl!.isNotEmpty) {
        return ep.audioStreamUrl;
      }
    }

    // Return first episode enclosure if broad Sunday Suspense query
    if (clean.contains('sunday') || clean.contains('suspense') || clean.contains('feluda')) {
      final firstWithAudio = episodes.firstWhere(
        (ep) => ep.audioStreamUrl != null && ep.audioStreamUrl!.isNotEmpty,
        orElse: () => episodes.first,
      );
      return firstWithAudio.audioStreamUrl;
    }

    return null;
  }
}
