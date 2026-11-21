import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';
import 'cascading_artwork.dart';

class ContentCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback onTap;

  const ContentCard({
    super.key,
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: AppMotion.durationFast,
        curve: Curves.easeOut,
        child: SizedBox(
          width: 156,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: AppRadii.borderMedium,
                child: Container(
                  width: 156,
                  height: 112,
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    borderRadius: AppRadii.borderMedium,
                    border: Border.all(
                      color: AppColors.primarySoft.withValues(alpha: 0.15),
                      width: 1,
                    ),
                    boxShadow: AppShadows.card,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CascadingArtwork(
                        imageUrl: widget.imageUrl,
                        title: widget.title,
                        artist: widget.subtitle,
                        width: 156,
                        height: 112,
                        borderRadius: AppRadii.borderMedium,
                        fit: BoxFit.cover,
                      ),
                      if (_isPressed)
                        Container(color: AppColors.surfaceGlow.withValues(alpha: 0.2)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.cardTitle,
              ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.meta,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
