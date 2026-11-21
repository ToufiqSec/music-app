import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../features/music/models/music_models.dart';
import '../../widgets/cascading_artwork.dart';
import '../../theme/app_radii.dart';

/// Central Artwork Resolver & Thumbnail Widget (Issue 5).
/// - Enforces HTTPS for all artwork URLs.
/// - Optimizes dimensions (300-500px, avoiding broken maxresdefault 404s).
/// - Provides automatic deterministic fallback via GeneratedCoverArt.
class ArtworkResolver {
  static String resolveArtwork(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    var url = raw.trim();

    // 1. Force HTTPS
    if (url.startsWith('http://')) {
      url = 'https://${url.substring(7)}';
    }

    // 2. YouTube Thumbnail Optimization
    // Avoid unscaled maxresdefault.jpg (1280x720, memory-heavy & frequent 404s). Standardize on mqdefault (320x180) or hqdefault (480x360)
    if (url.contains('ytimg.com') || url.contains('youtube.com')) {
      if (url.contains('/maxresdefault.jpg')) {
        url = url.replaceAll('/maxresdefault.jpg', '/mqdefault.jpg');
      } else if (url.contains('/default.jpg') && !url.contains('/hqdefault.jpg') && !url.contains('/mqdefault.jpg')) {
        url = url.replaceAll('/default.jpg', '/mqdefault.jpg');
      }
    }

    // 3. JioSaavn Thumbnail Optimization
    // Upgrade low-res 50x50 / 150x150 to high-res 500x500
    if (url.contains('jiosaavn') || url.contains('saavncdn')) {
      url = url.replaceAll('50x50', '500x500').replaceAll('150x150', '500x500');
    }

    return url;
  }

  static String resolveTrackArtwork(YoutubeTrack track) {
    final raw = track.thumbnailUrl.isNotEmpty
        ? track.thumbnailUrl
        : (track.thumbnail.isNotEmpty ? track.thumbnail : '');
    return resolveArtwork(raw);
  }
}

/// Unified App Image Thumbnail Widget with error and loading fallbacks (Issue 5).
class AppArtworkImage extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final String artist;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const AppArtworkImage({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.artist,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  factory AppArtworkImage.fromTrack(
    YoutubeTrack track, {
    Key? key,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    return AppArtworkImage(
      key: key,
      imageUrl: track.thumbnailUrl,
      title: track.title,
      artist: track.artist,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(AppRadii.sm);
    return CascadingArtwork(
      imageUrl: imageUrl,
      title: title,
      artist: artist,
      width: width,
      height: height,
      fit: fit,
      borderRadius: effectiveRadius,
    );
  }
}
