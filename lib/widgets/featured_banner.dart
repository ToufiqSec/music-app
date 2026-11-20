import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_shadows.dart';

/// Featured wide banner from Section 7 of Universal UI Design System: Twilight Calm.
class FeaturedBanner extends StatelessWidget {
  final String title;
  final String metaText;
  final String? imageUrl;
  final VoidCallback onActionTap;

  const FeaturedBanner({
    super.key,
    required this.title,
    required this.metaText,
    this.imageUrl,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onActionTap,
      child: Container(
        height: 154,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: AppRadii.borderLarge,
          color: AppColors.surface1,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: AppRadii.borderLarge,
          child: Stack(
            children: [
              if (imageUrl != null)
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(color: AppColors.surface1),
                  ),
                ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.30),
                        Colors.black.withValues(alpha: 0.88),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            metaText.toUpperCase(),
                            style: AppTextStyles.meta.copyWith(
                              color: AppColors.primarySoft,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.cardTitle.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: onActionTap,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primarySoft.withValues(alpha: 0.60),
                              blurRadius: 18,
                              spreadRadius: 2,
                              offset: const Offset(0, 2),
                            ),
                            AppShadows.shadowSoft,
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 26,
                          color: AppColors.textOnLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
}
}
