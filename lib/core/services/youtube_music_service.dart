import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../features/music/models/music_models.dart';
import '../crypto/des_ecb.dart';
import 'audio_cache_service.dart';

/// Multi-tier music resolver:
/// Tier 1: JioSaavn direct API with DES-ECB 320kbps CDN decryption
/// Tier 2: YouTube audio-only stream extraction (via youtube_explode_dart)
/// Tier 3: Local offline audio cache
class YoutubeMusicService {
  final YoutubeExplode _yt = YoutubeExplode();
  final Map<String, String> _streamCache = {};
  Timer? _debounceTimer;

  void dispose() {
    _debounceTimer?.cancel();
    _yt.close();
  }

  /// Searches tracks with multi-tier fallback (JioSaavn -> YouTube) and deduplication.
  Future<List<YoutubeTrack>> searchTracks(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final results = <YoutubeTrack>[];
    final seenKeys = <String>{};

    // Tier 1: JioSaavn Search API
    try {
      final saavnTracks = await _searchJioSaavn(cleanQuery);
      for (final track in saavnTracks) {
        final key = '${track.title.toLowerCase()}_${track.artist.toLowerCase()}';
        if (!seenKeys.contains(key)) {
          seenKeys.add(key);
          results.add(track);
        }
      }
    } catch (_) {}

    // Tier 2 Supplement & Universal Fallback: Regular YouTube Global Audio Search
    // Unlocks long-tail content: Audio dramas (Sunday Suspense), podcasts, stories, audiobooks, foreign languages
    try {
      final ytTracks = await _searchYouTube(cleanQuery);
      for (final track in ytTracks) {
        final key = '${track.title.toLowerCase()}_${track.artist.toLowerCase()}';
        if (!seenKeys.contains(key)) {
          seenKeys.add(key);
          results.add(track);
        }
      }
    } catch (_) {}

    return results;
  }

  /// Queries JioSaavn search API and decrypts encrypted_media_url to 320kbps audio.
  Future<List<YoutubeTrack>> _searchJioSaavn(String query) async {
    final uri = Uri.parse(
      'https://www.jiosaavn.com/api.php?__call=search.getResults&_format=json&_marker=0&cc=in&n=15&p=1&q=${Uri.encodeComponent(query)}',
    );

    final response = await http.get(uri, headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept': 'application/json',
    }).timeout(const Duration(seconds: 6));

    if (response.statusCode != 200) return [];

    final data = json.decode(response.body);
    final resultsList = data['results'] as List<dynamic>? ?? [];

    final tracks = <YoutubeTrack>[];
    for (final item in resultsList) {
      final encryptedUrl = item['encrypted_media_url'] as String? ?? '';
      String? streamUrl;
      if (encryptedUrl.isNotEmpty) {
        streamUrl = DesEcbDecryptor.decryptMediaUrl(encryptedUrl);
      }

      final id = item['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString();
      final title = _unescapeHtml(item['song']?.toString() ?? item['title']?.toString() ?? 'Unknown Song');
      final artist = _unescapeHtml(item['primary_artists']?.toString() ?? item['singers']?.toString() ?? 'Various Artists');
      final duration = int.tryParse(item['duration']?.toString() ?? '0') ?? 0;
      var image = item['image']?.toString();
      if (image != null) {
        image = image.replaceAll('150x150', '500x500');
      }

      if (streamUrl != null) {
        _streamCache[id] = streamUrl;
      }

      tracks.add(YoutubeTrack(
        id: id,
        title: title,
        artist: artist,
        durationSeconds: duration,
        thumbnailUrl: image ?? '',
        audioStreamUrl: streamUrl,
      ));
    }

    return tracks;
  }

  /// Extracts pure audio tracks from YouTube without webviews or video ads.
  Future<List<YoutubeTrack>> _searchYouTube(String query) async {
    final searchList = await _yt.search.search(query).timeout(const Duration(seconds: 8));
    final tracks = <YoutubeTrack>[];

    for (final video in searchList.take(10)) {
      final id = video.id.value;
      final duration = video.duration?.inSeconds ?? 0;

      tracks.add(YoutubeTrack(
        id: id,
        title: video.title,
        artist: video.author,
        durationSeconds: duration,
        thumbnailUrl: video.thumbnails.highResUrl,
        audioStreamUrl: null, // Resolved on-demand via getAudioStreamUrl
      ));
    }

    return tracks;
  }

  /// Resolves the direct playable audio stream URL (with in-memory cache & highest bitrate extraction).
  Future<String?> getAudioStreamUrl(String trackId) async {
    // 0. Check local disk cache
    final cached = await AudioCacheService.getCachedTrackFile(trackId);
    if (cached != null) {
      return cached.path;
    }

    // 1. In-memory stream cache
    if (_streamCache.containsKey(trackId)) {
      return _streamCache[trackId];
    }

    // 2. YouTube Explode stream extraction for YouTube IDs
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(trackId).timeout(
        const Duration(seconds: 8),
      );
      final audioOnlyStreams = manifest.audioOnly;
      if (audioOnlyStreams.isNotEmpty) {
        final bestAudio = audioOnlyStreams.withHighestBitrate();
        final url = bestAudio.url.toString();
        _streamCache[trackId] = url;
        return url;
      }
      // Fallback: Check muxed streams if audioOnly is empty
      if (manifest.muxed.isNotEmpty) {
        final bestMuxed = manifest.muxed.withHighestBitrate();
        final url = bestMuxed.url.toString();
        _streamCache[trackId] = url;
        return url;
      }
    } catch (e) {
      debugPrint('[YoutubeMusicService] getAudioStreamUrl error for $trackId: $e');
    }

    return null;
  }

  String _unescapeHtml(String text) {
    return text
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }
}

