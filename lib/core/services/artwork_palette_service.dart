import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Extracted and WCAG AA-contrasted dynamic color palette for Now Playing screen.
class ExtractedPalette {
  final Color dominant;
  final Color backgroundTop;
  final Color backgroundBottom;
  final Color lyricsCardColor;
  final Color headerColor;
  final Color onAccentText;

  const ExtractedPalette({
    required this.dominant,
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.lyricsCardColor,
    required this.headerColor,
    required this.onAccentText,
  });

  static const ExtractedPalette defaultDark = ExtractedPalette(
    dominant: Color(0xFF8B263E), // Deep Coke Studio Crimson
    backgroundTop: Color(0xFF2E141D),
    backgroundBottom: Color(0xFF121212),
    lyricsCardColor: Color(0xFF5A1E2D),
    headerColor: Color(0xFF1E1317),
    onAccentText: Colors.white,
  );
}

/// Service that extracts vibrant dominant colors from artwork and caches them per track.
class ArtworkPaletteService {
  static final Map<String, ExtractedPalette> _cache = {};

  static const List<Color> _vibrantAnchors = [
    Color(0xFF8B1E3F), // Coke Studio Crimson Red
    Color(0xFF6C3483), // Royal Amethyst
    Color(0xFF1E824C), // Deep Emerald
    Color(0xFF1F618D), // Ocean Navy
    Color(0xFFB9770E), // Warm Golden Amber
    Color(0xFF922B21), // Terracotta Rust
    Color(0xFF117A65), // Pine Teal
    Color(0xFF5B2C6F), // Deep Plum
    Color(0xFF283747), // Slate Midnight
    Color(0xFF7D6608), // Olive Bronze
    Color(0xFF78281F), // Maroon Velvet
    Color(0xFF145A32), // Forest Green
  ];

  /// Synchronously returns pre-computed or deterministic fallback palette (0ms delay).
  static ExtractedPalette getPaletteSync(String? trackId, String? title, String? artist) {
    final key = trackId ?? '${title ?? ""}_${artist ?? ""}';
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }
    return _deriveHarmoniousPalette(title ?? '', artist ?? '');
  }

  /// Extracts dominant palette from image URL with local memory caching.
  static Future<ExtractedPalette> getPalette(
    String? trackId,
    String? imageUrl,
    String title,
    String artist,
  ) async {
    final key = trackId ?? '${title}_$artist';
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    final fallback = _deriveHarmoniousPalette(title, artist);
    _cache[key] = fallback;

    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return fallback;
    }

    try {
      final uri = Uri.tryParse(imageUrl);
      if (uri == null) return fallback;

      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        final palette = await _extractFromBytes(res.bodyBytes, fallback);
        _cache[key] = palette;
        return palette;
      }
    } catch (_) {
      // Return cached fallback on network timeout
    }
    return fallback;
  }

  static ExtractedPalette _deriveHarmoniousPalette(String title, String artist) {
    final hash = (title.hashCode.abs() + artist.hashCode.abs() * 31);
    final anchor = _vibrantAnchors[hash % _vibrantAnchors.length];
    return _buildPaletteFromDominant(anchor);
  }

  static Future<ExtractedPalette> _extractFromBytes(
    Uint8List bytes,
    ExtractedPalette fallback,
  ) async {
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 20,
        targetHeight: 20,
      );
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      if (byteData == null) return fallback;

      int bestR = 0, bestG = 0, bestB = 0;
      double highestScore = -1.0;

      for (int i = 0; i < byteData.lengthInBytes; i += 4) {
        final r = byteData.getUint8(i);
        final g = byteData.getUint8(i + 1);
        final b = byteData.getUint8(i + 2);
        final a = byteData.getUint8(i + 3);

        if (a < 128) continue;

        final maxVal = [r, g, b].reduce((curr, next) => curr > next ? curr : next);
        final minVal = [r, g, b].reduce((curr, next) => curr < next ? curr : next);
        final delta = maxVal - minVal;

        // Skip near blacks, whites, and low saturation grays
        final brightness = (r * 0.299 + g * 0.587 + b * 0.114);
        if (brightness < 35 || brightness > 225) continue;
        if (delta < 25) continue;

        // Score based on saturation * pleasant brightness range
        final saturation = delta / maxVal;
        final brightnessScore = 1.0 - (brightness - 120).abs() / 120.0;
        final score = saturation * 1.5 + brightnessScore;

        if (score > highestScore) {
          highestScore = score;
          bestR = r;
          bestG = g;
          bestB = b;
        }
      }

      if (highestScore > 0) {
        final dominant = Color.fromARGB(255, bestR, bestG, bestB);
        return _buildPaletteFromDominant(dominant);
      }
    } catch (_) {
      // Ignore codec errors
    }
    return fallback;
  }

  static ExtractedPalette _buildPaletteFromDominant(Color dominant) {
    // Darken for background top gradient
    final bgTop = Color.lerp(dominant, const Color(0xFF121212), 0.70)!;
    // Darken for card background while keeping vibrant accent tint
    final cardColor = Color.lerp(dominant, const Color(0xFF1E1E1E), 0.45)!;
    // Mini header tinted background
    final headerColor = Color.lerp(dominant, const Color(0xFF121212), 0.85)!;
    final luminance = dominant.computeLuminance();
    final onAccent = luminance > 0.5 ? Colors.black87 : Colors.white;

    return ExtractedPalette(
      dominant: dominant,
      backgroundTop: bgTop,
      backgroundBottom: const Color(0xFF121212),
      lyricsCardColor: cardColor,
      headerColor: headerColor,
      onAccentText: onAccent,
    );
  }
}
