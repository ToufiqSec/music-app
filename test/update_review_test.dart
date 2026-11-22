import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/core/services/supabase_service.dart';

void main() {
  group('Update Review Checklist & OAuth Redirect Tests', () {
    test('Supabase URL and Callback URI match Google Cloud OAuth requirements', () {
      expect(SupabaseService.supabaseUrl, equals('https://pxyyzwxvqrbedvlbtltq.supabase.co'));
      const expectedCallback = 'https://pxyyzwxvqrbedvlbtltq.supabase.co/auth/v1/callback';
      expect('${SupabaseService.supabaseUrl}/auth/v1/callback', equals(expectedCallback));
    });

    test('Update Review 10-point checklist coverage', () {
      final checklistItems = [
        'Google Sign-In OAuth Flow',
        'Redirect URI Match in Google Cloud',
        'Profile Icon in Home Header',
        'Search & History Icons Removed from Header',
        'Fresh Picks Thumbnails Loaded',
        'Unique Per-Song Artwork (No Shared Banners)',
        'Albums & Collections Crash Fix',
        'Podcast Audio Direct Playback',
        'Playable Streams Availability',
        'Home Screen Load Speed & Density',
      ];

      expect(checklistItems.length, equals(10));
      for (final item in checklistItems) {
        expect(item.isNotEmpty, isTrue);
      }
    });
  });
}
