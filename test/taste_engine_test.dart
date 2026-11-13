import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/core/services/taste_engine.dart';
import 'package:music_app/features/music/models/music_models.dart';

void main() {
  group('TasteEngine Unit Tests', () {
    test('isBlockedChannelOrLabel identifies channel and label names', () {
      expect(TasteEngine.isBlockedChannelOrLabel('RB Lyrics'), isTrue);
      expect(TasteEngine.isBlockedChannelOrLabel('Sony Music India'), isTrue);
      expect(TasteEngine.isBlockedChannelOrLabel('T-Series Official'), isTrue);
      expect(TasteEngine.isBlockedChannelOrLabel('Countdown Channel'), isTrue);
      expect(TasteEngine.isBlockedChannelOrLabel('Arijit Singh'), isFalse);
      expect(TasteEngine.isBlockedChannelOrLabel('Taylor Swift'), isFalse);
    });

    test('avoidConsecutiveArtists avoids back-to-back songs from the same artist', () {
      const tracks = [
        YoutubeTrack(id: '1', title: 'Song 1', artist: 'Arijit Singh', durationSeconds: 200, thumbnailUrl: ''),
        YoutubeTrack(id: '2', title: 'Song 2', artist: 'Arijit Singh', durationSeconds: 200, thumbnailUrl: ''),
        YoutubeTrack(id: '3', title: 'Song 3', artist: 'Coldplay', durationSeconds: 200, thumbnailUrl: ''),
        YoutubeTrack(id: '4', title: 'Song 4', artist: 'Arijit Singh', durationSeconds: 200, thumbnailUrl: ''),
        YoutubeTrack(id: '5', title: 'Song 5', artist: 'Taylor Swift', durationSeconds: 200, thumbnailUrl: ''),
      ];

      final interleaved = TasteEngine.avoidConsecutiveArtists(tracks);
      expect(interleaved.length, 5);
      
      // Ensure no two consecutive songs have the exact same primary artist
      for (int i = 0; i < interleaved.length - 1; i++) {
        if (interleaved[i].artist == 'Arijit Singh') {
          expect(interleaved[i + 1].artist != 'Arijit Singh', isTrue);
        }
      }
    });
  });
}
