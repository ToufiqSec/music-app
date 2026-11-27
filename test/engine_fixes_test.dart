import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/core/services/artwork_resolver.dart';
import 'package:music_app/core/services/blend_playlist_service.dart';
import 'package:music_app/core/services/mood_recommendation_engine.dart';
import 'package:music_app/core/services/playback_resolver.dart';
import 'package:music_app/features/music/models/music_models.dart';

void main() {
  group('MoodRecommendationEngine.avoidConsecutiveSameArtist', () {
    test('separates consecutive tracks from the same artist', () {
      final tracks = [
        const YoutubeTrack(id: '1', title: 'Song A1', artist: 'Arijit Singh', durationSeconds: 200, thumbnailUrl: ''),
        const YoutubeTrack(id: '2', title: 'Song A2', artist: 'Arijit Singh', durationSeconds: 210, thumbnailUrl: ''),
        const YoutubeTrack(id: '3', title: 'Song B1', artist: 'Shreya Ghoshal', durationSeconds: 220, thumbnailUrl: ''),
        const YoutubeTrack(id: '4', title: 'Song A3', artist: 'Arijit Singh', durationSeconds: 230, thumbnailUrl: ''),
        const YoutubeTrack(id: '5', title: 'Song C1', artist: 'KK', durationSeconds: 240, thumbnailUrl: ''),
      ];

      final spaced = MoodRecommendationEngine.avoidConsecutiveSameArtist(tracks);
      expect(spaced.length, tracks.length);
      for (int i = 1; i < spaced.length; i++) {
        expect(
          spaced[i].artist.toLowerCase(),
          isNot(equals(spaced[i - 1].artist.toLowerCase())),
        );
      }
    });
  });

  group('PlaybackResolver URL helpers', () {
    test('upgrades public http URLs to https while preserving LAN/localhost', () {
      expect(
        PlaybackResolver.upgradeToHttps('http://cdn.example.com/track.mp3'),
        'https://cdn.example.com/track.mp3',
      );
      expect(
        PlaybackResolver.upgradeToHttps('http://localhost:8080/stream.mp3'),
        'http://localhost:8080/stream.mp3',
      );
      expect(
        PlaybackResolver.upgradeToHttps('http://192.168.1.50:8000/radio'),
        'http://192.168.1.50:8000/radio',
      );
    });

    test('detects webpage URLs vs direct audio streams', () {
      expect(PlaybackResolver.isLikelyWebPage('https://www.youtube.com/watch?v=abc12345678'), isTrue);
      expect(PlaybackResolver.isLikelyWebPage('https://cdn.example.com/audio/song.mp3'), isFalse);
    });
  });

  group('BlendPlaylistService', () {
    test('exports and parses taste codes accurately', () {
      final code = BlendPlaylistService.exportCurrentUserTasteCode(displayName: 'Alex');
      expect(code.startsWith('SWARVA-BLEND:'), isTrue);

      final parsed = BlendPlaylistService.parseTasteInput(code);
      expect(parsed, isNotNull);
      expect(parsed!.displayName, 'Alex');
      expect(parsed.artists, isNotEmpty);
    });

    test('parses comma-separated artist names as fallback', () {
      final parsed = BlendPlaylistService.parseTasteInput('Arijit Singh, Coldplay, KK');
      expect(parsed, isNotNull);
      expect(parsed!.artists, ['Arijit Singh', 'Coldplay', 'KK']);
    });

    test('computes taste match percentage within 55-99 range', () {
      final high = BlendPlaylistService.computeTasteMatchPercent(
        ['Arijit Singh', 'KK'],
        ['Arijit Singh', 'KK'],
      );
      final low = BlendPlaylistService.computeTasteMatchPercent(
        ['Arijit Singh'],
        ['Metallica'],
      );
      expect(high, 99);
      expect(low, 55);
    });
  });

  group('ArtworkResolver', () {
    test('upgrades JioSaavn 150x150 to 500x500 and forces HTTPS', () {
      expect(
        ArtworkResolver.resolveArtwork('http://c.saavncdn.com/123/song_150x150.jpg'),
        'https://c.saavncdn.com/123/song_500x500.jpg',
      );
    });
  });
}
