import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

enum AudioContentType {
  song,
  show,
  audiobook,
  podcast,
  live,
}

/// Helper detecting audio content type from metadata and duration
class AudioTypeDetector {
  static AudioContentType detect(String title, String artist, int durationSeconds) {
    final lowerTitle = title.toLowerCase();
    final lowerArtist = artist.toLowerCase();

    if (lowerTitle.contains('audiobook') || lowerTitle.contains('audio book') || lowerTitle.contains('chapter')) {
      return AudioContentType.audiobook;
    }
    if (lowerTitle.contains('suspense') || lowerTitle.contains('drama') || lowerTitle.contains('sunday suspense') || lowerTitle.contains('natok') || lowerTitle.contains('radio show')) {
      return AudioContentType.show;
    }
    if (lowerTitle.contains('podcast') || lowerTitle.contains('episode') || lowerArtist.contains('podcast')) {
      return AudioContentType.podcast;
    }
    if (lowerTitle.contains('live') || lowerTitle.contains('concert') || lowerTitle.contains('unplugged')) {
      return AudioContentType.live;
    }
    if (durationSeconds > 1800) {
      return AudioContentType.podcast;
    }
    return AudioContentType.song;
  }

  static String getBadgeText(AudioContentType type) {
    switch (type) {
      case AudioContentType.show:
        return 'AUDIO SHOW';
      case AudioContentType.audiobook:
        return 'AUDIOBOOK';
      case AudioContentType.podcast:
        return 'PODCAST';
      case AudioContentType.live:
        return 'LIVE CONCERT';
      case AudioContentType.song:
        return '320k HI-RES';
    }
  }

  static IconData getBadgeIcon(AudioContentType type) {
    switch (type) {
      case AudioContentType.show:
        return Icons.theater_comedy_rounded;
      case AudioContentType.audiobook:
        return Icons.menu_book_rounded;
      case AudioContentType.podcast:
        return Icons.podcasts_rounded;
      case AudioContentType.live:
        return Icons.mic_external_on_rounded;
      case AudioContentType.song:
        return Icons.music_note_rounded;
    }
  }
}

/// Branded 1:1 Square Cover Art Engine (Issue 6 Part B)
/// Generates aesthetic, layered Twilight covers for long-form audio & YouTube video thumbnails.
/// Guarantees zero distortion, stable template hashing, and beautiful typography.
class GeneratedCoverArt extends StatelessWidget {
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final int durationSeconds;
  final double size;
  final BorderRadius? borderRadius;

  const GeneratedCoverArt({
    super.key,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    this.durationSeconds = 0,
    this.size = 140,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final type = AudioTypeDetector.detect(title, artist, durationSeconds);
    final effectiveRadius = borderRadius ?? AppRadii.borderLarge;

    // Palette variants derived deterministically from artist/channel name hash
    final hash = (artist.hashCode.abs() + title.hashCode.abs()) % _coverPalettes.length;
    final palette = _coverPalettes[hash];

    return ClipRRect(
      borderRadius: effectiveRadius,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: effectiveRadius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: palette.colors,
          ),
          border: Border.all(
            color: AppColors.primarySoft.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Center-cropped blurred thumbnail background (Never stretched)
            if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
              Opacity(
                opacity: 0.38,
                child: CachedNetworkImage(
                  imageUrl: thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox(),
                ),
              ),

            // 2. Artistic Geometric Vignette
            CustomPaint(
              painter: _CoverPatternPainter(seed: hash),
            ),

            // 3. Dark Scrim Gradient for Typographic Readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.65),
                    Colors.black.withValues(alpha: 0.88),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),

            // 4. Content Type Badge at Top
            Positioned(
              top: size * 0.08,
              left: size * 0.08,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: (size * 0.06).clamp(6.0, 10.0),
                  vertical: (size * 0.025).clamp(2.0, 4.0),
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: AppRadii.borderPill,
                  border: Border.all(
                    color: AppColors.primarySoft.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AudioTypeDetector.getBadgeIcon(type),
                      size: (size * 0.08).clamp(10.0, 14.0),
                      color: AppColors.primarySoft,
                    ),
                    SizedBox(width: size * 0.03),
                    Text(
                      AudioTypeDetector.getBadgeText(type),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: (size * 0.065).clamp(8.0, 10.0),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 5. Title & Channel/Author Typography (Center / Bottom)
            Positioned(
              bottom: size * 0.08,
              left: size * 0.08,
              right: size * 0.08,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: (size * 0.10).clamp(11.0, 18.0),
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.8),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: size * 0.03),
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.primarySoft,
                      fontSize: (size * 0.075).clamp(9.0, 13.0),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverPalette {
  final List<Color> colors;
  const _CoverPalette(this.colors);
}

final List<_CoverPalette> _coverPalettes = [
  // Deep Twilight & Violet (Music & Ambience)
  const _CoverPalette([Color(0xFF4A2B78), Color(0xFF1E1438), Color(0xFF0F0B1A)]),
  const _CoverPalette([Color(0xFF6B3A82), Color(0xFF2C1645), Color(0xFF140B22)]),
  const _CoverPalette([Color(0xFF5B327A), Color(0xFF2E1545), Color(0xFF150A21)]),
  const _CoverPalette([Color(0xFF3D1E6D), Color(0xFF220F43), Color(0xFF110724)]),
  
  // Midnight Ocean & Slate (Podcasts & Deep Talks)
  const _CoverPalette([Color(0xFF2E3A6E), Color(0xFF192147), Color(0xFF0D1126)]),
  const _CoverPalette([Color(0xFF3B566E), Color(0xFF1B2C3D), Color(0xFF0D1721)]),
  const _CoverPalette([Color(0xFF254B62), Color(0xFF132836), Color(0xFF09141C)]),
  const _CoverPalette([Color(0xFF1E3A5F), Color(0xFF102035), Color(0xFF08101C)]),

  // Sunset Coral & Rose (Acoustic, Romance, Live)
  const _CoverPalette([Color(0xFF7A365D), Color(0xFF381530), Color(0xFF190918)]),
  const _CoverPalette([Color(0xFF8C3E56), Color(0xFF481C2B), Color(0xFF240E16)]),
  const _CoverPalette([Color(0xFF6E2D52), Color(0xFF351227), Color(0xFF1A0813)]),
  const _CoverPalette([Color(0xFF823963), Color(0xFF3D162F), Color(0xFF1E0A17)]),

  // Forest Pines & Emerald Dusk (Audiobooks & Nature Soundscapes)
  const _CoverPalette([Color(0xFF285E5A), Color(0xFF143330), Color(0xFF091A18)]),
  const _CoverPalette([Color(0xFF214E4A), Color(0xFF102B29), Color(0xFF081615)]),
  const _CoverPalette([Color(0xFF2C5542), Color(0xFF162D23), Color(0xFF0B1712)]),
  const _CoverPalette([Color(0xFF1F443B), Color(0xFF0F241F), Color(0xFF081210)]),

  // Warm Amber & Vintage Leather (Audio Dramas, Suspense, Classic Shows)
  const _CoverPalette([Color(0xFF6E472A), Color(0xFF3B2312), Color(0xFF1C1008)]),
  const _CoverPalette([Color(0xFF5A3922), Color(0xFF2F1D11), Color(0xFF170E08)]),
  const _CoverPalette([Color(0xFF734226), Color(0xFF3C2012), Color(0xFF1E1009)]),
  const _CoverPalette([Color(0xFF633B23), Color(0xFF331D11), Color(0xFF1A0F08)]),

  // Cosmic Lavender & Aurora (Euphoric, Lo-Fi, Modern Hits)
  const _CoverPalette([Color(0xFF56396B), Color(0xFF2B1B36), Color(0xFF160D1B)]),
  const _CoverPalette([Color(0xFF433261), Color(0xFF231934), Color(0xFF110C1A)]),
  const _CoverPalette([Color(0xFF603C78), Color(0xFF311C3E), Color(0xFF180E1F)]),
  const _CoverPalette([Color(0xFF4E2C6A), Color(0xFF271536), Color(0xFF140B1B)]),
];

class _CoverPatternPainter extends CustomPainter {
  final int seed;
  _CoverPatternPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final w = size.width;
    final h = size.height;

    // Stylized concentric circles
    final center = Offset(w * (0.3 + (seed % 4) * 0.1), h * (0.3 + (seed % 3) * 0.1));
    canvas.drawCircle(center, w * 0.25, paint);
    canvas.drawCircle(center, w * 0.45, paint);
    canvas.drawCircle(center, w * 0.65, paint);
  }

  @override
  bool shouldRepaint(covariant _CoverPatternPainter oldDelegate) => false;
}
