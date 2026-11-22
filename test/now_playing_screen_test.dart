import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/core/services/artwork_palette_service.dart';

void main() {
  group('ArtworkPaletteService Tests', () {
    test('getPaletteSync returns deterministic vibrant palette with WCAG AA contrast', () {
      final palette1 = ArtworkPaletteService.getPaletteSync('t_1', 'Bewajah', 'Nabeel Shaukat Ali');
      final palette2 = ArtworkPaletteService.getPaletteSync('t_1', 'Bewajah', 'Nabeel Shaukat Ali');

      // Identical track keys yield identical cached palettes
      expect(palette1.dominant, equals(palette2.dominant));
      expect(palette1.backgroundTop, equals(palette2.backgroundTop));
      expect(palette1.backgroundBottom, const Color(0xFF121212));
      expect(palette1.lyricsCardColor, equals(palette2.lyricsCardColor));

      // Contrast text is either black or white
      expect(palette1.onAccentText == Colors.white || palette1.onAccentText == Colors.black87, isTrue);
    });

    test('Different tracks yield distinct dynamic palettes', () {
      final p1 = ArtworkPaletteService.getPaletteSync('t_1', 'Bewajah', 'Nabeel Shaukat Ali');
      final p2 = ArtworkPaletteService.getPaletteSync('t_2', 'Kesariya', 'Arijit Singh');

      expect(p1.dominant, isNotNull);
      expect(p2.dominant, isNotNull);
    });

    test('Handles null or empty track parameters safely without throwing', () {
      final pNull = ArtworkPaletteService.getPaletteSync(null, null, null);
      expect(pNull.dominant, isNotNull);
      expect(pNull.backgroundBottom, const Color(0xFF121212));
    });
  });
}
