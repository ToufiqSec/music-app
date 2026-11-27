import 'package:flutter_test/flutter_test.dart';

String cleanTrackTitle(String rawTitle) {
  final cleaned = rawTitle
      .replaceAll(RegExp(r'\[.*?\]|\(.*?\)', caseSensitive: false), '')
      .split(RegExp(r'\s*[\|•]\s*.*|\s+-\s+(?:Bollywood|Audio|Jukebox|Official|Full Video|Remix|Song).*', caseSensitive: false))
      .first
      .trim();
  return cleaned.isEmpty ? rawTitle : cleaned;
}

void main() {
  group('Jump Back In Title Sanitization Tests', () {
    test('Cleans noisy YouTube title tags and Jukebox suffixes', () {
      const raw1 = 'Best of ATIF ASLAM Songs | Bollywood Romantic Love Songs | Audio Jukebox | Hindi Hit Songs';
      expect(cleanTrackTitle(raw1), 'Best of ATIF ASLAM Songs');

      const raw2 = 'Kesariya (From "Brahmastra") [Official Video] | Arijit Singh';
      expect(cleanTrackTitle(raw2), 'Kesariya');

      const raw3 = 'Ilahi - Full Video Song | Yeh Jawaani Hai Deewani';
      expect(cleanTrackTitle(raw3), 'Ilahi');

      const raw4 = 'Channa Mereya • Audio Jukebox';
      expect(cleanTrackTitle(raw4), 'Channa Mereya');
    });

    test('Preserves clean titles without unwanted alteration', () {
      const clean = 'Tum Hi Ho';
      expect(cleanTrackTitle(clean), 'Tum Hi Ho');

      const clean2 = 'Zehnaseeb';
      expect(cleanTrackTitle(clean2), 'Zehnaseeb');
    });
  });
}
