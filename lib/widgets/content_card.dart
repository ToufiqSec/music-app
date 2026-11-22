import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import 'cascading_artwork.dart';

/// Premium Glassmorphic Album & Music Card matching Reference Design.
/// Features high-gloss finish, specular top highlight, and floating circular play button.
class ContentCard extends StatefulWidget {
  final String? trackId;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback onTap;

  const ContentCard({
    super.key,
    this.trackId,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    required this.onTap,
  });

  @override
  State<ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends State<ContentCard> {
  bool _isPressed = false;

  String _cleanTitle(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'\[.*?\]|\(.*?\)', caseSensitive: false), '')
        .split(RegExp(r'\s*[\|\-•]\s*(?:Bollywood|Audio|Jukebox|Official|Full Video|Remix|Song).*', caseSensitive: false))
        .first
        .trim();
    return cleaned.isEmpty ? raw : cleaned;
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = _cleanTitle(widget.title);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: AppMotion.durationFast,
        curve: Curves.easeOut,
        child: Container(
          width: 148,
          height: 182,
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _isPressed
                  ? AppColors.pinkAccent.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.12),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
              if (_isPressed)
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 16,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Top Artwork Cover
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 122,
                  child: CascadingArtwork(
                    key: ValueKey('art_${widget.trackId ?? widget.title}'),
                    trackId: widget.trackId,
                    imageUrl: widget.imageUrl,
                    title: widget.title,
                    artist: widget.subtitle,
                    width: 148,
                    height: 122,
                    borderRadius: BorderRadius.zero,
                    fit: BoxFit.cover,
                  ),
                ),

                // Liquid Bottom Glass Panel
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 60,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xCC191724),
                          Color(0xF2191724),
                        ],
                      ),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Title & Artist Text
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Floating Circular White Play Button
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.pinkAccent.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Color(0xFF0B0A12),
                              size: 19,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Top Specular Highlight Edge
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 1,
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
