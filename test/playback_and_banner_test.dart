import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/widgets/generated_cover_art.dart';
import 'package:music_app/core/services/curated_tracks.dart';
import 'package:music_app/core/services/supabase_service.dart';

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
        expect(podcast.durationSeconds, greaterThan(1800)); // > 30 minutes
      }
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
  });
}
