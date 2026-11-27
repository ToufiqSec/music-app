import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../features/music/models/music_models.dart';
import 'audio_cache_service.dart';
import 'podcast_rss_service.dart';
import 'youtube_music_service.dart';

class PlaybackResolutionResult {
  final String? url;
  final bool isPlayable;
  final String? failureReason;
  final String sourceType; // 'local_cache', 'direct_enclosure', 'youtube_stream', 'fallback_search'

  const PlaybackResolutionResult({
    this.url,
    required this.isPlayable,
    this.failureReason,
    required this.sourceType,
  });

  factory PlaybackResolutionResult.success({
    required String url,
    required String sourceType,
  }) {
    return PlaybackResolutionResult(
      url: url,
      isPlayable: true,
      sourceType: sourceType,
    );
  }

  factory PlaybackResolutionResult.failure(String reason, {String sourceType = 'unknown'}) {
    return PlaybackResolutionResult(
      url: null,
      isPlayable: false,
      failureReason: reason,
      sourceType: sourceType,
    );
  }
}

/// Centralized Audio Playback Resolver (Requirement A2.1 & A5)
/// Handles songs, podcasts, Sunday Sessions, and audiobooks uniformly.
class PlaybackResolver {
  static const List<String> _validAudioExtensions = [
    '.mp3',
    '.m4a',
    '.aac',
    '.ogg',
    '.wav',
    '.flac',
    '.opus',
    '.mp4',
  ];

  /// Determines if an http:// URL is safe to upgrade to https://.
  /// Preserves plain HTTP for localhost, LAN IPs, mDNS, and custom ports (Issue 1.2).
  static bool shouldUpgradeToHttps(String url) {
    final lower = url.trim().toLowerCase();
    if (!lower.startsWith('http://')) return false;

    // Do NOT upgrade localhost or loopback
    if (lower.contains('://localhost') || lower.contains('://127.0.0.1')) {
      return false;
    }
    // Do NOT upgrade private LAN IP addresses (RFC 1918)
    if (RegExp(r'://(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)').hasMatch(lower)) {
      return false;
    }
    // Do NOT upgrade local mDNS / LAN hostnames
    if (lower.contains('.local:') || lower.endsWith('.local') || lower.contains('.lan')) {
      return false;
    }
    // Do NOT upgrade custom non-standard HTTP audio ports (like Icecast/Shoutcast :8000, :8080)
    final uri = Uri.tryParse(url);
    if (uri != null && uri.hasPort && uri.port != 80 && uri.port != 443) {
      return false;
    }

    return true;
  }

  /// Upgrades http:// to https:// safely without breaking LAN / local streams (Requirement A2.2 & Issue 1.2)
  static String upgradeToHttps(String url) {
    final trimmed = url.trim();
    if (shouldUpgradeToHttps(trimmed)) {
      return trimmed.replaceFirst('http://', 'https://');
    }
    return trimmed;
  }

  /// Verifies the URL does not point to an HTML webpage (Requirement A4.2)
  static bool isLikelyWebPage(String url) {
    final lower = url.toLowerCase();
    // Known webpage paths that are not direct audio streams
    if (lower.contains('youtube.com/watch') ||
        lower.contains('youtu.be/') ||
        lower.contains('www.spreaker.com/episode/') ||
        lower.contains('anchor.fm/episodes/') ||
        lower.contains('open.spotify.com/episode/') ||
        lower.contains('spotify.com/episode/')) {
      return true;
    }
    if (lower.endsWith('.html') || lower.endsWith('.htm') || lower.endsWith('.php')) {
      return true;
    }
    return false;
  }

  /// Pre-resolves multi-hop HTTP redirect chains (e.g. Podtrac -> Spreaker -> CloudFront CDN)
  /// into the final direct playable media stream URL so native ExoPlayer / just_audio
  /// does not drop or fail on cross-domain redirect chains.
  static Future<String?> resolveFinalAudioUrl(String url) async {
    final clean = upgradeToHttps(url);
    if (clean.contains('googlevideo.com')) {
      return clean;
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      var currentUri = Uri.parse(clean);

      int redirectCount = 0;
      const maxHops = 10;

      while (redirectCount < maxHops) {
        final request = await client.headUrl(currentUri);
        request.followRedirects = false;
        request.headers.set(
          'User-Agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        );

        final response = await request.close().timeout(const Duration(seconds: 8));

        // If HEAD returns 405 Method Not Allowed or 501 Not Implemented, fallback to GET range bytes=0-0
        if (response.statusCode == HttpStatus.methodNotAllowed || response.statusCode == HttpStatus.notImplemented) {
          final getReq = await client.getUrl(currentUri);
          getReq.followRedirects = false;
          getReq.headers.set(
            'User-Agent',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          );
          getReq.headers.set('Range', 'bytes=0-0');
          final getResp = await getReq.close().timeout(const Duration(seconds: 8));

          if (getResp.statusCode == HttpStatus.movedPermanently ||
              getResp.statusCode == HttpStatus.movedTemporarily ||
              getResp.statusCode == HttpStatus.seeOther ||
              getResp.statusCode == HttpStatus.temporaryRedirect ||
              getResp.statusCode == HttpStatus.permanentRedirect) {
            final location = getResp.headers.value(HttpHeaders.locationHeader);
            if (location != null && location.isNotEmpty) {
              currentUri = currentUri.resolve(location);
              redirectCount++;
              continue;
            }
          }

          if (getResp.statusCode >= 200 && getResp.statusCode < 300) {
            return upgradeToHttps(currentUri.toString());
          }
          return null;
        }

        // Check redirect status
        if (response.statusCode == HttpStatus.movedPermanently ||
            response.statusCode == HttpStatus.movedTemporarily ||
            response.statusCode == HttpStatus.seeOther ||
            response.statusCode == HttpStatus.temporaryRedirect ||
            response.statusCode == HttpStatus.permanentRedirect) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location != null && location.isNotEmpty) {
            currentUri = currentUri.resolve(location);
            redirectCount++;
            continue;
          }
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return upgradeToHttps(currentUri.toString());
        }

        debugPrint('[PlaybackResolver] Candidate URL check returned HTTP ${response.statusCode} for $currentUri');
        return null;
      }

      return upgradeToHttps(currentUri.toString());
    } catch (e) {
      debugPrint('[PlaybackResolver] Error resolving final URL for $url: $e');
      if (url.contains('podtrac.com') ||
          url.contains('spreaker.com/download') ||
          url.contains('chrt.fm') ||
          url.contains('pdst.fm')) {
        return null;
      }
      return url;
    } finally {
      client.close(force: true);
    }
  }

  /// Resolves the audio source into ONE shared function (Requirement A2.1)
  static Future<PlaybackResolutionResult> resolveAudioSource({
    required YoutubeTrack track,
    required YoutubeMusicService musicService,
    bool forceRefresh = false,
  }) async {
    debugPrint('[PlaybackResolver] Resolving track ID: "${track.id}", Title: "${track.title}" (forceRefresh: $forceRefresh)');

    // 1. Local disk cache (fastest, offline-ready)
    try {
      final cachedFile = await AudioCacheService.getCachedTrackFile(track.id);
      if (cachedFile != null && await cachedFile.exists()) {
        debugPrint('[PlaybackResolver] Found in local cache: ${cachedFile.path}');
        return PlaybackResolutionResult.success(
          url: cachedFile.path,
          sourceType: 'local_cache',
        );
      }
    } catch (e) {
      debugPrint('[PlaybackResolver] Local cache check error: $e');
    }

    // 2. Direct Enclosure / AudioStreamUrl (Bypassed if forceRefresh == true to enable fallback recovery)
    if (!forceRefresh) {
      final candidates = <String?>[
        track.audioStreamUrl,
        track.localFilePath,
        if (track.id.startsWith('http://') || track.id.startsWith('https://')) track.id,
      ];

      for (final candidate in candidates) {
        if (candidate != null && candidate.trim().isNotEmpty) {
          var cleanUrl = upgradeToHttps(candidate);

          // Check if candidate points to an HTML webpage rather than an audio stream
          if (isLikelyWebPage(cleanUrl)) {
            debugPrint('[PlaybackResolver] Candidate is a webpage URL: $cleanUrl');
            continue;
          }

          // Validate local file or remote URL with redirect pre-resolution
          if (cleanUrl.startsWith('https://')) {
            final resolvedUrl = await resolveFinalAudioUrl(cleanUrl);
            if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
              debugPrint('[PlaybackResolver] Resolved playable direct stream: $resolvedUrl');
              return PlaybackResolutionResult.success(
                url: resolvedUrl,
                sourceType: 'direct_enclosure',
              );
            } else {
              debugPrint('[PlaybackResolver] Candidate URL unreachable or dead: $cleanUrl');
              continue;
            }
          } else if (File(cleanUrl).existsSync()) {
            return PlaybackResolutionResult.success(
              url: cleanUrl,
              sourceType: 'local_file',
            );
          }
        }
      }
    }

    // 3. Dynamic Service Stream (RSS Podcast Enclosure / YouTube Explode)
    try {
      final fallbackQuery = '${track.title} ${track.artist}'.trim();
      final isPodcast = track.durationSeconds > 1200 ||
          track.title.toLowerCase().contains('podcast') ||
          track.title.toLowerCase().contains('suspense') ||
          track.title.toLowerCase().contains('feluda');

      if (isPodcast) {
        final queryTarget = track.id.startsWith('ss_') ? track.id : track.title;
        final rssUrl = await PodcastRssService.resolvePodcastEnclosure(queryTarget);
        if (rssUrl != null && rssUrl.isNotEmpty) {
          var secureUrl = upgradeToHttps(rssUrl);
          final preResolved = await resolveFinalAudioUrl(secureUrl);
          if (preResolved != null) {
            debugPrint('[PlaybackResolver] Resolved podcast RSS audio enclosure: $preResolved');
            return PlaybackResolutionResult.success(
              url: preResolved,
              sourceType: 'rss_enclosure',
            );
          }
        }
        debugPrint('[PlaybackResolver] Podcast has no direct RSS enclosure; falling back to streaming resolver: "${track.title}"');
      }

      final streamUrl = await musicService.getAudioStreamUrl(
        track.id,
        fallbackQuery: fallbackQuery,
        forceRefresh: forceRefresh,
      );

      if (streamUrl != null && streamUrl.isNotEmpty) {
        var secureUrl = upgradeToHttps(streamUrl);
        if (secureUrl.contains('spreaker.com') || secureUrl.contains('podtrac.com')) {
          final preResolved = await resolveFinalAudioUrl(secureUrl);
          if (preResolved != null) {
            secureUrl = preResolved;
          }
        }
        debugPrint('[PlaybackResolver] Resolved streaming URL: $secureUrl');
        return PlaybackResolutionResult.success(
          url: secureUrl,
          sourceType: 'youtube_stream',
        );
      }
    } catch (e) {
      debugPrint('[PlaybackResolver] Music service resolution failed for ${track.id}: $e');
      return PlaybackResolutionResult.failure(
        'Audio not available for this episode',
        sourceType: 'error',
      );
    }

    debugPrint('[PlaybackResolver] No playable source found for "${track.title}" (ID: ${track.id})');
    return PlaybackResolutionResult.failure(
      'Audio not available for this episode',
      sourceType: 'missing_source',
    );
  }
}
