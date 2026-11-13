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
        height: 112,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: AppRadii.borderLarge,
          color: AppColors.surface1,
          boxShadow: const [AppShadows.shadowSoft],
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
                decoration: const BoxDecoration(
                  gradient: AppColors.cardImageOverlay,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.cardTitle,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          metaText.toUpperCase(),
                          style: AppTextStyles.meta,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onActionTap,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [AppShadows.shadowSoft],
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        size: 20,
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
