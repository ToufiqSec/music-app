import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/features/music/models/music_models.dart';
import 'package:music_app/widgets/generated_cover_art.dart';
import 'package:music_app/core/services/curated_tracks.dart';
import 'package:music_app/core/services/supabase_service.dart';
import 'package:music_app/core/services/playback_resolver.dart';
import 'package:music_app/core/services/youtube_music_service.dart';

void main() {
  group('Podcast & Music Playback Tests', () {
    test('AudioTypeDetector correctly identifies podcasts, shows, and songs', () {
      expect(
        AudioTypeDetector.detect('Sunday Suspense: Feluda', 'Mirchi', 3800),
        AudioContentType.show,
      );

      expect(
        AudioTypeDetector.detect('The Ranveer Show Episode 120', 'BeerBiceps', 4200),
        AudioContentType.podcast,
      );

      expect(
        AudioTypeDetector.detect('Kesariya', 'Arijit Singh', 268),
        AudioContentType.song,
      );
    });

    test('CuratedTracks contains verified featured podcasts with non-empty thumbnails and durations', () {
      expect(CuratedTracks.featuredPodcasts.isNotEmpty, isTrue);
      for (final podcast in CuratedTracks.featuredPodcasts) {
        expect(podcast.id.isNotEmpty, isTrue);
        expect(podcast.title.isNotEmpty, isTrue);
        expect(podcast.thumbnailUrl.startsWith('https://'), isTrue);
        expect(podcast.durationSeconds, greaterThan(1200)); // > 20 minutes
      }
    });

    test('PlaybackResolver upgrades http to https safely and preserves LAN/localhost HTTP', () {
      expect(
        PlaybackResolver.upgradeToHttps('http://example.com/audio.mp3'),
        'https://example.com/audio.mp3',
      );
      expect(
        PlaybackResolver.upgradeToHttps('https://example.com/audio.mp3'),
        'https://example.com/audio.mp3',
      );
      // Preserves LAN / local HTTP addresses (Issue 1.2)
      expect(
        PlaybackResolver.upgradeToHttps('http://localhost:8000/stream.mp3'),
        'http://localhost:8000/stream.mp3',
      );
      expect(
        PlaybackResolver.upgradeToHttps('http://192.168.1.100:8080/audio.aac'),
        'http://192.168.1.100:8080/audio.aac',
      );
      expect(
        PlaybackResolver.upgradeToHttps('http://10.0.0.5/music.mp3'),
        'http://10.0.0.5/music.mp3',
      );
    });

    test('PlaybackResolver correctly identifies web pages and rejects non-audio enclosures', () {
      expect(PlaybackResolver.isLikelyWebPage('https://www.youtube.com/watch?v=12345'), isTrue);
      expect(PlaybackResolver.isLikelyWebPage('https://youtu.be/12345'), isTrue);
      expect(PlaybackResolver.isLikelyWebPage('https://www.spreaker.com/episode/feluda-test--12345'), isTrue);
      expect(PlaybackResolver.isLikelyWebPage('https://anchor.fm/episodes/my-podcast-123'), isTrue);
      expect(PlaybackResolver.isLikelyWebPage('https://example.com/index.html'), isTrue);
      expect(PlaybackResolver.isLikelyWebPage('https://d1bxy2pveef3fq.cloudfront.net/episodes/original/123.mp3'), isFalse);
      expect(PlaybackResolver.isLikelyWebPage('https://dts.podtrac.com/redirect.mp3/example.mp3'), isFalse);
    });

    test('YoutubeMusicService.cleanFallbackQuery strips parentheticals and audio tags cleanly', () {
      expect(
        YoutubeMusicService.cleanFallbackQuery('Channa Mereya (Ae Dil Hai Mushkil) [Official Video]'),
        'Channa Mereya',
      );
      expect(
        YoutubeMusicService.cleanFallbackQuery('Sunday Suspense - Feluda - Kathmandu (Mirchi Bangla)'),
        'Sunday Suspense Feluda Kathmandu',
      );
    });

    test('UserProfileData parses and falls back to user email cleanly', () {
      final p1 = UserProfileData.fromMap({'id': 'u1', 'email': 'test@example.com', 'display_name': 'Tester'}, 'fallback@example.com');
      expect(p1.email, 'test@example.com');
      expect(p1.displayName, 'Tester');

      final p2 = UserProfileData.fromMap({'id': 'u2', 'email': '', 'display_name': ''}, 'fallback@example.com');
      expect(p2.email, 'fallback@example.com');
      expect(p2.displayName, 'fallback');

      final p3 = UserProfileData.fromMap({'id': 'u3'}, 'user123@domain.org');
      expect(p3.email, 'user123@domain.org');
      expect(p3.displayName, 'user123');
    });

    test('YoutubeTrack.fromJson safely parses integer IDs and numbers without throwing TypeErrors', () {
      final jsonWithInts = {
        'id': 987654321,
        'title': 'Test Song',
        'artist': 'Test Artist',
        'durationSeconds': 240,
        'thumbnailUrl': 'https://example.com/art.jpg',
      };
      final track = YoutubeTrack.fromJson(jsonWithInts);
      expect(track.id, '987654321');
      expect(track.title, 'Test Song');
      expect(track.durationSeconds, 240);
    });

    test('Fresh Picks contains verified valid tracks and thumbnail URLs', () {
      expect(CuratedTracks.freshPicksTracks.isNotEmpty, isTrue);
      final tauba = CuratedTracks.freshPicksTracks.firstWhere((t) => t.title == 'Tauba Tauba');
      expect(tauba.id, 'RLzC55ai0eo');
      expect(tauba.thumbnailUrl.contains('RLzC55ai0eo'), isTrue);

      final illuminati = CuratedTracks.freshPicksTracks.firstWhere((t) => t.title == 'Illuminati');
      expect(illuminati.id, 'tOM-nWPcR4U');

      final dieWithASmile = CuratedTracks.freshPicksTracks.firstWhere((t) => t.title == 'Die With A Smile');
      expect(dieWithASmile.id, 'bESGLojNYSo');
    });

    test('Featured Podcasts contains direct playable RSS enclosures', () {
      expect(CuratedTracks.featuredPodcasts.isNotEmpty, isTrue);
      final feluda = CuratedTracks.featuredPodcasts.firstWhere((t) => t.id == 'ss_feluda_kathmandu');
      expect(feluda.audioStreamUrl, isNotNull);
      expect(feluda.audioStreamUrl!.startsWith('https://'), isTrue);
      expect(feluda.audioStreamUrl!.contains('.mp3'), isTrue);
    });
  });
}
