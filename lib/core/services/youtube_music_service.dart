import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../features/music/models/music_models.dart';
import '../crypto/des_ecb.dart';
import 'audio_cache_service.dart';
import 'curated_tracks.dart';

/// Multi-tier music resolver with direct YouTube Music & Spreaker CDN support:
/// Tier 1: JioSaavn direct API with DES-ECB 320kbps CDN decryption (lossless, instant)
/// Tier 2: YouTube & YouTube Music stream extraction (via youtube_explode_dart)
/// Tier 3: Spreaker official CloudFront MP3 CDN for Sunday Suspense / Mirchi Bangla
/// Tier 4: Local offline audio cache
class YoutubeMusicService {
  final YoutubeExplode _yt = YoutubeExplode();
  final Map<String, String> _streamCache = {};
  Timer? _debounceTimer;

  void dispose() {
    _debounceTimer?.cancel();
    _yt.close();
  }

  /// Searches tracks with multi-tier fallback (YouTube Music -> JioSaavn -> YouTube) and deduplication.
  Future<List<YoutubeTrack>> searchTracks(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final results = <YoutubeTrack>[];
    final seenKeys = <String>{};

    final isSundaySuspense = cleanQuery.toLowerCase().contains('suspense') ||
        cleanQuery.toLowerCase().contains('sunday') ||
        cleanQuery.toLowerCase().contains('mirchi') ||
        cleanQuery.toLowerCase().contains('feluda') ||
        cleanQuery.toLowerCase().contains('byomkesh') ||
        cleanQuery.toLowerCase().contains('shonku');

    if (isSundaySuspense) {
      // 1. Prioritize official Spreaker Sunday Suspense episodes (direct playable MP3s)
      try {
        final ssTracks = await searchSundaySuspense(cleanQuery);
        for (final track in ssTracks) {
          final key = track.title.toLowerCase();
          if (!seenKeys.contains(key)) {
            seenKeys.add(key);
            results.add(track);
          }
        }
      } catch (_) {}

      // 2. Supplement from YouTube
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

    final isPodcastOrDrama = cleanQuery.toLowerCase().contains('podcast') ||
        cleanQuery.toLowerCase().contains('audio drama') ||
        cleanQuery.toLowerCase().contains('audio story') ||
        cleanQuery.toLowerCase().contains('natok') ||
        cleanQuery.toLowerCase().contains('talk') ||
        cleanQuery.toLowerCase().contains('episode');

    if (isPodcastOrDrama) {
      // For audio dramas & podcasts, query YouTube directly for full-length episodes
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
    } else {
      // For general music & YouTube Music:
      // First, query JioSaavn for instant lossless 320kbps CDN playback
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

      // Supplement & fallback to YouTube global audio search
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
    }

    return results;
  }

  /// Direct YouTube Music search: retrieves official music audio & tracks from YouTube
  Future<List<YoutubeTrack>> searchYouTubeMusic(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final musicQuery = cleanQuery.toLowerCase().contains('music') ||
            cleanQuery.toLowerCase().contains('song')
        ? cleanQuery
        : '$cleanQuery official audio music';

    final results = await _searchYouTube(musicQuery);
    return results;
  }

  /// Retrieves direct Sunday Suspense episodes from official Spreaker API feeds
  Future<List<YoutubeTrack>> searchSundaySuspense(String query) async {
    final tracks = <YoutubeTrack>[];
    final seenTitles = <String>{};

    // Pre-seed with curated direct episodes
    for (final episode in CuratedTracks.featuredPodcasts) {
      if (episode.title.toLowerCase().contains(query.toLowerCase()) ||
          episode.artist.toLowerCase().contains(query.toLowerCase()) ||
          query.toLowerCase().contains('sunday') ||
          query.toLowerCase().contains('suspense') ||
          query.isEmpty) {
        final key = episode.title.toLowerCase();
        if (!seenTitles.contains(key)) {
          seenTitles.add(key);
          tracks.add(episode);
        }
      }
    }

    // Query live Spreaker show 4852712 & 6039407 for direct CloudFront MP3 streams
    try {
      final showIds = ['4852712', '6039407'];
      for (final showId in showIds) {
        final uri = Uri.parse('https://api.spreaker.com/v2/shows/$showId/episodes?limit=15');
        final response = await http.get(uri).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final items = data['response']?['items'] as List<dynamic>? ?? [];
          for (final item in items) {
            final epId = item['episode_id']?.toString() ?? '';
            final title = item['title']?.toString() ?? 'Sunday Suspense Episode';
            final durationMs = item['duration'] as num? ?? 0;
            final durationSec = (durationMs / 1000).round();
            var imageUrl = item['image_url']?.toString() ?? '';
            if (imageUrl.contains('t_square_limited_160')) {
              imageUrl = imageUrl.replaceAll('t_square_limited_160', 't_rss_itunes_square_1400');
            }
            final playUrl = 'https://api.spreaker.com/v2/episodes/$epId/play.mp3';

            final key = title.toLowerCase();
            if (!seenTitles.contains(key)) {
              seenTitles.add(key);
              tracks.add(YoutubeTrack(
                id: 'ss_spk_$epId',
                title: title.startsWith('Sunday Suspense') ? title : 'Sunday Suspense: $title',
                artist: 'Sunday Suspense • Mirchi Bangla',
                durationSeconds: durationSec > 0 ? durationSec : 3600,
                thumbnailUrl: imageUrl.isNotEmpty
                    ? imageUrl
                    : 'https://d3wo5wojvuv7l.cloudfront.net/t_rss_itunes_square_1400/images.spreaker.com/original/1448de548583885ff422361fdb951f38.jpg',
                audioStreamUrl: playUrl,
              ));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[YoutubeMusicService] Spreaker Sunday Suspense search failed: $e');
    }

    return tracks;
  }

  /// Queries JioSaavn search API and decrypts encrypted_media_url to audio stream.
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
      final has320 = item['320kbps'] == 'true' || item['320kbps'] == true;
      String? streamUrl;
      if (encryptedUrl.isNotEmpty) {
        streamUrl = DesEcbDecryptor.decryptMediaUrl(encryptedUrl, is320Available: has320);
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

    for (final video in searchList.take(12)) {
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

  /// Removes a cached stream URL if it failed during playback
  void invalidateCache(String trackId) {
    _streamCache.remove(trackId);
  }

  /// Resolves the direct playable audio stream URL (with in-memory cache & universal AAC hardware decoding).
  Future<String?> getAudioStreamUrl(
    String trackId, {
    String? fallbackQuery,
    bool forceRefresh = false,
  }) async {
    // -1. Direct enclosure / web URL
    if (trackId.startsWith('http://') || trackId.startsWith('https://')) {
      return trackId;
    }

    // 0. Check local disk cache
    if (!forceRefresh) {
      final cached = await AudioCacheService.getCachedTrackFile(trackId);
      if (cached != null) {
        return cached.path;
      }

      // 1. In-memory stream cache
      if (_streamCache.containsKey(trackId)) {
        return _streamCache[trackId];
      }
    } else {
      _streamCache.remove(trackId);
    }

    // 2. Direct Sunday Suspense episode handling
    if (trackId.startsWith('ss_spk_')) {
      final epId = trackId.replaceFirst('ss_spk_', '');
      final playUrl = 'https://api.spreaker.com/v2/episodes/$epId/play.mp3';
      _streamCache[trackId] = playUrl;
      return playUrl;
    }

    // 3. High-Priority JioSaavn Match (Lossless 320kbps CD Quality, Instant & Unblockable)
    // If fallbackQuery is available, check JioSaavn first to avoid YouTube bot-detection blocks
    if (fallbackQuery != null && fallbackQuery.trim().isNotEmpty) {
      final isDramaOrSunday = fallbackQuery.toLowerCase().contains('suspense') ||
          fallbackQuery.toLowerCase().contains('sunday') ||
          fallbackQuery.toLowerCase().contains('podcast');

      if (!isDramaOrSunday) {
        try {
          final saavnTracks = await _searchJioSaavn(fallbackQuery.trim());
          if (saavnTracks.isNotEmpty && saavnTracks.first.audioStreamUrl != null) {
            final url = saavnTracks.first.audioStreamUrl!;
            _streamCache[trackId] = url;
            debugPrint('[YoutubeMusicService] Resolved lossless JioSaavn stream for "$fallbackQuery"');
            return url;
          }
        } catch (e) {
          debugPrint('[YoutubeMusicService] JioSaavn resolution attempt failed: $e');
        }
      }
    }

    // 4. YouTube Explode stream extraction for valid 11-char YouTube IDs
    final isYouTubeId = RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(trackId);
    if (isYouTubeId) {
      try {
        final manifest = await _yt.videos.streamsClient.getManifest(trackId).timeout(
          const Duration(seconds: 15),
        );
        final audioOnlyStreams = manifest.audioOnly;
        if (audioOnlyStreams.isNotEmpty) {
          // Universal hardware decoding: Prefer MP4 / AAC audio stream
          final aacStreams = audioOnlyStreams.where(
            (s) => s.container.name.toLowerCase() == 'mp4' || s.audioCodec.toLowerCase().contains('mp4a'),
          );
          final selected = aacStreams.isNotEmpty
              ? aacStreams.withHighestBitrate()
              : audioOnlyStreams.withHighestBitrate();
          final url = selected.url.toString();
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
        debugPrint('[YoutubeMusicService] YouTube Explode error for $trackId: $e');
      }
    }

    // 5. Secondary fallback: Search YouTube with official audio query
    if (fallbackQuery != null && fallbackQuery.trim().isNotEmpty) {
      try {
        final cleanFb = fallbackQuery.trim();
        final searchTarget = cleanFb.toLowerCase().contains('official') || cleanFb.toLowerCase().contains('audio')
            ? cleanFb
            : '$cleanFb official audio';

        final fallbackTracks = await _searchYouTube(searchTarget);
        for (final fb in fallbackTracks) {
          if (fb.id == trackId) continue;
          try {
            final fbManifest = await _yt.videos.streamsClient.getManifest(fb.id).timeout(
              const Duration(seconds: 12),
            );
            final audioOnly = fbManifest.audioOnly;
            if (audioOnly.isNotEmpty) {
              final aac = audioOnly.where(
                (s) => s.container.name.toLowerCase() == 'mp4' || s.audioCodec.toLowerCase().contains('mp4a'),
              );
              final selected = aac.isNotEmpty ? aac.withHighestBitrate() : audioOnly.withHighestBitrate();
              final url = selected.url.toString();
              _streamCache[trackId] = url;
              _streamCache[fb.id] = url;
              return url;
            }
            if (fbManifest.muxed.isNotEmpty) {
              final url = fbManifest.muxed.withHighestBitrate().url.toString();
              _streamCache[trackId] = url;
              _streamCache[fb.id] = url;
              return url;
            }
          } catch (_) {
            continue;
          }
        }
      } catch (e) {
        debugPrint('[YoutubeMusicService] Fallback YouTube search failed for $fallbackQuery: $e');
      }
    }

    // 6. Ultimate JioSaavn Fallback for any missed song
    if (fallbackQuery != null && fallbackQuery.trim().isNotEmpty) {
      try {
        final saavnTracks = await _searchJioSaavn(fallbackQuery.trim());
        for (final t in saavnTracks) {
          if (t.audioStreamUrl != null && t.audioStreamUrl!.isNotEmpty) {
            _streamCache[trackId] = t.audioStreamUrl!;
            return t.audioStreamUrl!;
          }
        }
      } catch (_) {}
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
