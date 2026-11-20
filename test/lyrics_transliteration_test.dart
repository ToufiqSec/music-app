import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/core/services/lyrics_service.dart';
import 'package:music_app/core/services/lyrics_transliteration_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Lyrics Transliteration & Hindi Meaning Tests (Issue 4)', () {
    test('Devanagari-lyric song (Kun Faya Kun) shows Roman on Line 1 and Hindi meaning on Line 2', () async {
      const rawLrc = '[00:15.00] कुन फाया कुन\n[00:20.00] जब कहीं पे कुछ नहीं था\n[00:25.00] सजदा शुक्र तेरा सजदा';
      final rawResult = LyricsResult(
        isSynced: true,
        syncedLines: LyricsService.parseLrc(rawLrc),
        provider: 'Test',
      );

      final dual = await LyricsTransliterationService.processLyrics(
        trackId: 'test_kun_faya_kun',
        title: 'Kun Faya Kun',
        artist: 'A.R. Rahman, Mohit Chauhan, Javed Ali',
        rawResult: rawResult,
      );

      expect(dual, isNotNull);
      expect(dual!.isHindiOrUrdu, isTrue);
      expect(dual.lines.isNotEmpty, isTrue);

      final line1 = dual.lines[0];
      // Line 1 must be in Roman (English) letters
      expect(LyricsTransliterationService.containsDevanagari(line1.mainText), isFalse);
      expect(line1.mainText.toLowerCase().contains('kun faya kun'), isTrue);

      // Line 2 must be the Hindi meaning in Devanagari
      expect(line1.meaningText, isNotNull);
      expect(LyricsTransliterationService.containsDevanagari(line1.meaningText!), isTrue);
    });

    test('Hindi song with Roman original lyrics (Channa Mereya) shows Hindi meaning on Line 2', () async {
      const rawLrc = '[00:10.00] Achchha chalta hoon\n[00:15.00] Duaon mein yaad rakhna\n[00:20.00] Channa mereya mereya';
      final rawResult = LyricsResult(
        isSynced: true,
        syncedLines: LyricsService.parseLrc(rawLrc),
        provider: 'Test',
      );

      final dual = await LyricsTransliterationService.processLyrics(
        trackId: 'test_channa_mereya',
        title: 'Channa Mereya',
        artist: 'Arijit Singh, Pritam',
        rawResult: rawResult,
      );

      expect(dual, isNotNull);
      expect(dual!.isHindiOrUrdu, isTrue);

      final line1 = dual.lines[0];
      // Line 1 is the Roman lyric
      expect(line1.mainText.toLowerCase().contains('achchha chalta hoon'), isTrue);

      // Line 2 must contain Hindi Devanagari meaning
      expect(line1.meaningText, isNotNull);
      expect(LyricsTransliterationService.containsDevanagari(line1.meaningText!), isTrue);

      final line2 = dual.lines[1];
      expect(line2.mainText.toLowerCase().contains('duaon mein yaad rakhna'), isTrue);
      expect(line2.meaningText, isNotNull);
      expect(LyricsTransliterationService.containsDevanagari(line2.meaningText!), isTrue);
    });

    test('English song (Blinding Lights) shows only original lyric with no translation line', () async {
      const rawLrc = "[00:12.00] I've been on my own for long enough\n[00:16.00] I said, ooh, I'm blinded by the lights";
      final rawResult = LyricsResult(
        isSynced: true,
        syncedLines: LyricsService.parseLrc(rawLrc),
        provider: 'Test',
      );

      final dual = await LyricsTransliterationService.processLyrics(
        trackId: 'test_blinding_lights',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        rawResult: rawResult,
      );

      expect(dual, isNotNull);
      expect(dual!.isHindiOrUrdu, isFalse);

      final line1 = dual.lines[0];
      expect(line1.mainText, contains("I've been on my own"));
      // Line 2 must be null (no translation line for English songs)
      expect(line1.meaningText, isNull);
    });
  });
}
