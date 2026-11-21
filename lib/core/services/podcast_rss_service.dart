import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../features/music/models/music_models.dart';
import 'curated_tracks.dart';

/// Policy-compliant Podcast RSS & Enclosure Resolver.
/// Resolves podcast audio directly from authorized public RSS feeds and CDN audio enclosures (audio/mpeg).
/// Completely eliminates extraction or re-hosting of YouTube streams for podcasts (Phase 3).
class PodcastRssService {
  static final Map<String, List<YoutubeTrack>> _cache = {};
  static const String _spreakerSundaySuspenseShowId = '6039407';

  /// Fetches real episodes from the Sunday Suspense official Spreaker feed
  static Future<List<YoutubeTrack>> fetchSundaySuspenseEpisodes({int limit = 15}) async {
    final cacheKey = 'ss_$limit';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final uri = Uri.parse('https://api.spreaker.com/v2/shows/$_spreakerSundaySuspenseShowId/episodes?limit=$limit');
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final items = (data['response']?['items'] as List<dynamic>?) ?? [];

        final tracks = items.map<YoutubeTrack>((item) {
          final id = item['episode_id']?.toString() ?? '';
          final title = item['title']?.toString() ?? 'Sunday Suspense Episode';
          final durationMs = (item['duration'] as num?)?.toInt() ?? 0;
          final durationSec = durationMs > 0 ? (durationMs / 1000).round() : 3600;
          final imageUrl = item['image_original_url']?.toString() ?? item['image_url']?.toString() ?? '';
          final playUrl = item['playback_url']?.toString() ?? 'https://api.spreaker.com/v2/episodes/$id/play.mp3';

          return YoutubeTrack(
            id: 'ss_spk_$id',
            title: 'Sunday Suspense: $title',
            artist: 'Sunday Suspense • Mirchi Bangla',
            durationSeconds: durationSec,
            thumbnailUrl: imageUrl.isNotEmpty
                ? imageUrl
                : 'https://d3wo5wojvuv7l.cloudfront.net/t_rss_itunes_square_1400/images.spreaker.com/original/1448de548583885ff422361fdb951f38.jpg',
            audioStreamUrl: playUrl,
          );
        }).toList();

        if (tracks.isNotEmpty) {
          _cache[cacheKey] = tracks;
          return tracks;
        }
      }
    } catch (e) {
      debugPrint('[PodcastRssService] Spreaker fetch error: $e');
    }

    return CuratedTracks.featuredPodcasts;
  }

  /// Resolves the audio enclosure URL for a given podcast query or episode ID
  static Future<String?> resolvePodcastEnclosure(String query) async {
    final clean = query.trim().toLowerCase();
    if (clean.contains('sunday') || clean.contains('suspense') || clean.contains('feluda')) {
      final episodes = await fetchSundaySuspenseEpisodes();
      if (episodes.isNotEmpty) {
        return episodes.first.audioStreamUrl;
      }
    }
    return null;
  }
}
