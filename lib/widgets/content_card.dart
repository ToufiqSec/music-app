import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';
import 'generated_cover_art.dart';

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

class _ContentCardState extends State<ContentCard> with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Widget _buildShimmerSkeleton() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: AppRadii.borderMedium,
            gradient: LinearGradient(
              begin: Alignment(-1.5 + (_shimmerController.value * 3), -0.3),
              end: Alignment(0.5 + (_shimmerController.value * 3), 0.3),
              colors: [
                AppColors.surface1,
                AppColors.surface2,
                AppColors.surface1,
              ],
              stops: const [0.1, 0.5, 0.9],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesignedPlaceholder() {
    return GeneratedCoverArt(
      title: widget.title,
      artist: widget.subtitle,
      size: 156,
      borderRadius: AppRadii.borderMedium,
    );
  }

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
                      if (widget.imageUrl != null && widget.imageUrl!.trim().isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: widget.imageUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 400,
                          placeholder: (_, __) => _buildShimmerSkeleton(),
                          errorWidget: (_, __, ___) => _buildDesignedPlaceholder(),
                        )
                      else
                        _buildDesignedPlaceholder(),
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
