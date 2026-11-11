import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/audio_provider.dart';
import '../screens/now_playing_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_shadows.dart';
import '../theme/app_motion.dart';

/// Docked Mini-Player adhering to the Twilight Calm design system.
/// Pinned cleanly immediately above the floating Bottom Navigation Bar.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.read<AudioProvider>();

    return Selector<AudioProvider, (YoutubeTrack?, bool, bool, Duration, Duration)>(
      selector: (_, ap) => (
        ap.currentTrack,
        ap.isPlaying,
        ap.isBuffering,
        ap.position,
        ap.duration,
      ),
      builder: (context, data, child) {
        final (track, isPlaying, isBuffering, position, duration) = data;

        if (track == null) {
          return const SizedBox.shrink();
        }

        final progress = (duration.inMilliseconds > 0)
            ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const NowPlayingScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: AppMotion.curveEmphasizedDecelerate,
                );
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                );
              },
            ),
          );
        },
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.surface1.withValues(alpha: 0.95),
            borderRadius: AppRadii.borderMedium,
            boxShadow: const [AppShadows.shadowSoft],
            border: Border.all(
              color: AppColors.primarySoft.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: AppRadii.borderMedium,
            child: Stack(
              children: [
                // Live progress bar along top edge
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 2.5,
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primarySoft,
                    ),
                  ),
                ),

                // Main Content Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Row(
                    children: [
                      // Album Artwork Thumbnail
                      Hero(
                        tag: 'album_art_${track.id}',
                        child: ClipRRect(
                          borderRadius: AppRadii.borderSmall,
                          child: Container(
                            width: 44,
                            height: 44,
                            color: AppColors.surface2,
                            child: track.thumbnailUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: track.thumbnailUrl,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 120,
                                    errorWidget: (_, __, ___) => const Icon(
                                      Icons.music_note,
                                      color: AppColors.primarySoft,
                                      size: 22,
                                    ),
                                  )
                                : const Icon(
                                    Icons.music_note,
                                    color: AppColors.primarySoft,
                                    size: 22,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Track Title & Artist
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Equalizer mini indicator if playing
                      if (isPlaying)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: _MiniEqualizerBar(),
                        ),

                      // Play / Pause Button with Buffering indicator
                      GestureDetector(
                        onTap: () => audioProvider.togglePlayPause(),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: isBuffering
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primarySoft,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: AppColors.iconActive,
                                    size: 24,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Next Track Button
                      IconButton(
                        icon: const Icon(
                          Icons.skip_next_rounded,
                          color: AppColors.iconIdle,
                          size: 26,
                        ),
                        onPressed: () => audioProvider.playNext(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  },
);
  }
}

class _MiniEqualizerBar extends StatefulWidget {
  @override
  State<_MiniEqualizerBar> createState() => _MiniEqualizerBarState();
}

class _MiniEqualizerBarState extends State<_MiniEqualizerBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        final val = _animController.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 2.5,
              height: 6 + (val * 10),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 2),
            Container(
              width: 2.5,
              height: 14 - (val * 8),
              decoration: BoxDecoration(
                color: AppColors.sunsetPink,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 2),
            Container(
              width: 2.5,
              height: 8 + (val * 6),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        );
      },
    );
  }
}
