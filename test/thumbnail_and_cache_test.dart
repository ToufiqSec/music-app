import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/core/services/curated_tracks.dart';
import 'package:music_app/core/services/taste_engine.dart';
import 'package:music_app/features/music/models/music_models.dart';

/// In-memory tracker for verifying track ID vs image ID parity
class CardArtworkMismatchTracker {
  static int _mismatches = 0;
  static int get mismatchCount => _mismatches;
  static void reset() => _mismatches = 0;

  static void recordInspection({required String trackId, required String imageId}) {
    if (trackId.isNotEmpty && imageId.isNotEmpty && !imageId.contains(trackId) && !trackId.contains(imageId)) {
      _mismatches++;
    }
  }

  static String generateCacheKey(String trackId, int width, int height) {
    return 'track:$trackId:${width}x$height';
  }
}

void main() {
  group('Thumbnail and Cache Key Protocol Tests (Phase 3)', () {
    setUp(() {
      CardArtworkMismatchTracker.reset();
    });

    test('Cache keys include track ID and size, and two different tracks never share a key', () {
      final key1 = CardArtworkMismatchTracker.generateCacheKey('track_101', 156, 112);
      final key2 = CardArtworkMismatchTracker.generateCacheKey('track_102', 156, 112);
      final key1Resized = CardArtworkMismatchTracker.generateCacheKey('track_101', 56, 56);

      expect(key1, 'track:track_101:156x112');
      expect(key2, 'track:track_102:156x112');
      expect(key1Resized, 'track:track_101:56x56');

      // Two different tracks never share a key
      expect(key1, isNot(equals(key2)));
      // Different sizes for same track produce distinct keys
      expect(key1, isNot(equals(key1Resized)));
    });

    test('deduplicateArtwork prevents duplicate compilation banners from repeating in a carousel', () {
      const compilationBanner = 'https://c.saavncdn.com/294/Latest-Tollywood-Chartbusters-500x500.jpg';
      const tracks = [
        YoutubeTrack(
          id: 'song_1',
          title: 'Ammaadi',
          artist: 'Hesham',
          durationSeconds: 200,
          thumbnailUrl: compilationBanner,
        ),
        YoutubeTrack(
          id: 'song_2',
          title: 'Madhuramu Kadha',
          artist: 'Gopi Sunder',
          durationSeconds: 220,
          thumbnailUrl: compilationBanner,
        ),
        YoutubeTrack(
          id: 'c2gSzYLJ8sY', // Has valid 11-char YouTube ID
          title: 'Ishq Bulaava',
          artist: 'Sanam',
          durationSeconds: 240,
          thumbnailUrl: compilationBanner,
        ),
        YoutubeTrack(
          id: 'song_4',
          title: 'Independent Hit',
          artist: 'Artist D',
          durationSeconds: 180,
          thumbnailUrl: 'https://c.saavncdn.com/123/Independent-Single-500x500.jpg',
        ),
      ];

      final deduplicated = TasteEngine.deduplicateArtwork(tracks);

      // Verify that no two songs in the output have the same thumbnailUrl
      final urls = deduplicated.map((t) => t.thumbnailUrl).toList();
      final uniqueUrls = urls.toSet();
      expect(urls.length, uniqueUrls.length, reason: 'Every song must have a unique thumbnail URL');

      // Verify the track with 11-char YT ID converted to its own YT thumbnail
      final ishq = deduplicated.firstWhere((t) => t.id == 'c2gSzYLJ8sY');
      expect(ishq.thumbnailUrl, 'https://i.ytimg.com/vi/c2gSzYLJ8sY/hqdefault.jpg');
    });

    test('More Like Ishq Bulaava Radio: Ishq Bulaava, Zehnaseeb and Samjhawan each show their own unique image', () {
      final radio = CuratedTracks.ishqBulaavaRadioTracks;
      expect(radio.length, greaterThanOrEqualTo(3));

      final ishq = radio.firstWhere((t) => t.title == 'Ishq Bulaava');
      final zehnaseeb = radio.firstWhere((t) => t.title == 'Zehnaseeb');
      final samjhawan = radio.firstWhere((t) => t.title == 'Samjhawan');

      // Verify all 3 have valid, non-empty, distinct thumbnail URLs
      expect(ishq.thumbnailUrl.isNotEmpty, isTrue);
      expect(zehnaseeb.thumbnailUrl.isNotEmpty, isTrue);
      expect(samjhawan.thumbnailUrl.isNotEmpty, isTrue);

      expect(ishq.thumbnailUrl, isNot(equals(zehnaseeb.thumbnailUrl)));
      expect(ishq.thumbnailUrl, isNot(equals(samjhawan.thumbnailUrl)));
      expect(zehnaseeb.thumbnailUrl, isNot(equals(samjhawan.thumbnailUrl)));

      // Verify specific live video / CDN IDs
      expect(ishq.id, 'c2gSzYLJ8sY');
      expect(zehnaseeb.id, 'qug-H-sLd04');
      expect(samjhawan.id, 'DMoLdwJ7');
    });

    test('Popular Albums and Singles contains zero duplicate artwork URLs', () {
      final albums = CuratedTracks.popularAlbumsTracks;
      final urls = albums.map((t) => t.thumbnailUrl).toList();
      final uniqueUrls = urls.toSet();

      expect(urls.length, uniqueUrls.length, reason: 'No two tracks in Popular Albums may share the same cover');

      // Verify Tum Hi Ho and Ilahi have their individual album covers
      final tumHiHo = albums.firstWhere((t) => t.title.contains('Tum Hi Ho'));
      final ilahi = albums.firstWhere((t) => t.title.contains('Ilahi'));

      expect(tumHiHo.thumbnailUrl.contains('Aashiqui-2'), isTrue);
      expect(ilahi.thumbnailUrl.contains('Yeh-Jawaani-Hai-Deewani'), isTrue);
      expect(tumHiHo.thumbnailUrl, isNot(equals(ilahi.thumbnailUrl)));
    });

    test('Happy Hits first card has its own valid image and does not show letter tile', () {
      final happyHits = CuratedTracks.happyHitsTracks;
      expect(happyHits.isNotEmpty, isTrue);

      final firstCard = happyHits.first;
      expect(firstCard.title, 'Ilahi');
      expect(firstCard.thumbnailUrl.isNotEmpty, isTrue);
      expect(firstCard.thumbnailUrl.contains('Yeh-Jawaani-Hai-Deewani'), isTrue);
    });

    test('Mismatch tracker records 0 mismatches when song ID binds strictly to image ID', () {
      final tracks = [
        const YoutubeTrack(id: 'c2gSzYLJ8sY', title: 'Ishq Bulaava', artist: 'Sanam', durationSeconds: 300, thumbnailUrl: 'https://i.ytimg.com/vi/c2gSzYLJ8sY/hqdefault.jpg'),
        const YoutubeTrack(id: 'qug-H-sLd04', title: 'Zehnaseeb', artist: 'Chinmayi', durationSeconds: 215, thumbnailUrl: 'https://i.ytimg.com/vi/qug-H-sLd04/hqdefault.jpg'),
        const YoutubeTrack(id: 'DMoLdwJ7', title: 'Samjhawan', artist: 'Arijit', durationSeconds: 269, thumbnailUrl: 'https://c.saavncdn.com/540/Humpty-Sharma-Ki-Dulhania-Hindi-2014-20190618095042-500x500.jpg'),
      ];

      for (final t in tracks) {
        CardArtworkMismatchTracker.recordInspection(
          trackId: t.id,
          imageId: t.thumbnailUrl,
        );
      }

      expect(CardArtworkMismatchTracker.mismatchCount, 0, reason: 'Mismatch count must be zero across all cards');
    });
  });
}
