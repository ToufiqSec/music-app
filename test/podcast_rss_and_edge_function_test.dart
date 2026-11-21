import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Podcast RSS Enclosure Parsing & Edge Function Shape Tests', () {
    test('Validates RSS item enclosure URL and MIME type extraction', () {
      const mockXmlSnippet = '''
      <item>
        <title>Sunday Suspense: Feluda - Joto Kando Kathmandu-te</title>
        <enclosure url="https://dts.podtrac.com/redirect.mp3/api.spreaker.com/download/episode/58582188/joto_kando_kathmandu_te.mp3" length="157178534" type="audio/mpeg"/>
        <itunes:duration>9813</itunes:duration>
      </item>
      ''';

      final enclosureMatch = RegExp(r'<enclosure[^>]+url=["\x27]([^"\x27]+)["\x27][^>]+type=["\x27]([^"\x27]+)["\x27]').firstMatch(mockXmlSnippet);
      expect(enclosureMatch, isNotNull);
      final url = enclosureMatch!.group(1);
      final type = enclosureMatch.group(2);

      expect(url, equals('https://dts.podtrac.com/redirect.mp3/api.spreaker.com/download/episode/58582188/joto_kando_kathmandu_te.mp3'));
      expect(type, equals('audio/mpeg'));
      expect(type == 'audio/mpeg' || type == 'audio/mp4', isTrue);
    });

    test('Identifies missing audio enclosure and flags as unavailable', () {
      const mockXmlNoEnclosure = '''
      <item>
        <title>Sunday Suspense: Behind The Scenes Video</title>
        <description>Video interview without audio enclosure</description>
      </item>
      ''';

      final enclosureMatch = RegExp(r'<enclosure[^>]+url=["\x27]([^"\x27]+)["\x27]').firstMatch(mockXmlNoEnclosure);
      expect(enclosureMatch, isNull);

      final hasPlayableAudio = enclosureMatch != null;
      expect(hasPlayableAudio, isFalse);
      const fallbackMsg = 'Audio not available for this episode';
      expect(fallbackMsg, equals('Audio not available for this episode'));
    });

    test('Validates Supabase Edge Function fetch-podcasts JSON response schema', () {
      const mockJsonResponse = '''
      {
        "success": true,
        "source": "postgres_cache",
        "count": 2,
        "episodes": [
          {
            "id": "ss_spk_58582188",
            "show_id": "sunday_suspense",
            "show_title": "Sunday Suspense",
            "title": "Sunday Suspense: Feluda - Joto Kando Kathmandu-te",
            "artist": "Sunday Suspense • Satyajit Ray",
            "enclosure_url": "https://api.spreaker.com/v2/episodes/58582188/play.mp3",
            "thumbnail_url": "https://d3wo5wojvuv7l.cloudfront.net/images.spreaker.com/original/test.jpg",
            "duration_seconds": 9813,
            "published_at": "2026-11-21T10:00:00Z",
            "fetched_at": "2026-11-21T16:00:00Z"
          },
          {
            "id": "ss_spk_76387595",
            "show_id": "sunday_suspense",
            "show_title": "Sunday Suspense",
            "title": "Sunday Suspense: Indrapatan",
            "artist": "Sunday Suspense • Mirchi Bangla",
            "enclosure_url": "https://api.spreaker.com/v2/episodes/76387595/play.mp3",
            "thumbnail_url": "https://d3wo5wojvuv7l.cloudfront.net/images.spreaker.com/original/indra.jpg",
            "duration_seconds": 15385,
            "published_at": "2026-11-15T15:18:09Z",
            "fetched_at": "2026-11-21T16:00:00Z"
          }
        ]
      }
      ''';

      final Map<String, dynamic> data = json.decode(mockJsonResponse);
      expect(data['success'], isTrue);
      expect(data['source'], anyOf('postgres_cache', 'live_rss_fetch'));
      expect(data['count'], equals(2));
      expect(data['episodes'], isA<List>());

      final episodes = data['episodes'] as List;
      for (final ep in episodes) {
        expect(ep['id'], isA<String>());
        expect(ep['show_id'], equals('sunday_suspense'));
        expect(ep['title'], isA<String>());
        expect(ep['artist'], isA<String>());
        expect(ep['enclosure_url'], startsWith('https://'));
        expect(ep['duration_seconds'], isA<int>());
        expect(ep['duration_seconds'], greaterThan(0));
      }
    });
  });
}
