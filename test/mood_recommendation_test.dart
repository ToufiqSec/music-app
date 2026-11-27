import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/core/services/curated_tracks.dart';
import 'package:music_app/core/services/mood_recommendation_engine.dart';
import 'package:music_app/features/music/models/music_models.dart';

void main() {
  group('MoodRecommendationEngine 15-track minimum', () {
    test('minRecommendedTracks constant is 15 per AGENT.md', () {
      expect(MoodRecommendationEngine.minRecommendedTracks, equals(15));
    });

    test('ensureMinimumTracks tops up lists shorter than 15 using fallbackPool without duplicates', () {
      final initial = List.generate(
        5,
        (i) => YoutubeTrack(
          id: 'init_$i',
          title: 'Initial Song $i',
          artist: 'Artist $i',
          durationSeconds: 200,
        ),
      );

      final result = MoodRecommendationEngine.ensureMinimumTracks(
        initial,
        fallbackPool: CuratedTracks.allCatalogTracks,
      );

      expect(result.length, greaterThanOrEqualTo(15));

      final keys = result.map((t) => '${t.title.toLowerCase()}_${t.artist.toLowerCase()}').toSet();
      expect(keys.length, equals(result.length));
    });
  });
}
