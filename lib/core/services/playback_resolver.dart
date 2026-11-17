import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../features/music/models/music_models.dart';
import 'audio_cache_service.dart';
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

  /// Upgrades http:// to https:// (Requirement A2.2)
  static String upgradeToHttps(String url) {
    final trimmed = url.trim();
    if (trimmed.startsWith('http://')) {
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

  /// Resolves the audio source into ONE shared function (Requirement A2.1)
  static Future<PlaybackResolutionResult> resolveAudioSource({
    required YoutubeTrack track,
    required YoutubeMusicService musicService,
    bool forceRefresh = false,
  }) async {
    debugPrint('[PlaybackResolver] Resolving track ID: "${track.id}", Title: "${track.title}"');

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

    // 2. Direct Enclosure / AudioStreamUrl
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

        // Validate local file or remote URL
        if (cleanUrl.startsWith('https://')) {
          debugPrint('[PlaybackResolver] Resolved playable direct stream: $cleanUrl');
          return PlaybackResolutionResult.success(
            url: cleanUrl,
            sourceType: 'direct_enclosure',
          );
        } else if (File(cleanUrl).existsSync()) {
          return PlaybackResolutionResult.success(
            url: cleanUrl,
            sourceType: 'local_file',
          );
        }
      }
    }

    // 3. Dynamic Service Stream (YouTube Explode / Fallback Search)
    try {
      final fallbackQuery = '${track.title} ${track.artist}'.trim();
      final streamUrl = await musicService.getAudioStreamUrl(
        track.id,
        fallbackQuery: fallbackQuery,
        forceRefresh: forceRefresh,
      );

      if (streamUrl != null && streamUrl.isNotEmpty) {
        final secureUrl = upgradeToHttps(streamUrl);
        debugPrint('[PlaybackResolver] Resolved streaming URL: $secureUrl');
        return PlaybackResolutionResult.success(
          url: secureUrl,
          sourceType: 'youtube_stream',
        );
      }
    } catch (e) {
      debugPrint('[PlaybackResolver] Music service resolution failed for ${track.id}: $e');
      return PlaybackResolutionResult.failure(
        'Resolution exception: $e',
        sourceType: 'error',
      );
    }

    debugPrint('[PlaybackResolver] No playable source found for "${track.title}" (ID: ${track.id})');
    return PlaybackResolutionResult.failure(
      'No playable stream found for this item',
      sourceType: 'missing_source',
    );
  }
}
