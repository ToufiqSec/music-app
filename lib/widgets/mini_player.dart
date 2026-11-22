import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/music/models/music_models.dart';
import '../providers/audio_provider.dart';
import '../screens/now_playing_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_motion.dart';
import 'cascading_artwork.dart';

/// Premium Glassmorphism Docked Mini-Player inspired by the Reference UI.
/// Floats with liquid frosted glass, glowing borders, and high-contrast control accents.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.read<AudioProvider>();

    return Selector<AudioProvider, (YoutubeTrack?, bool, bool)>(
      selector: (_, ap) => (
        ap.currentTrack,
        ap.isPlaying,
        ap.isBuffering,
      ),
      builder: (context, data, child) {
        final (track, isPlaying, isBuffering) = data;

        if (track == null) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xE6191724), // #191724 with 90% opacity
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: 16,
                        spreadRadius: -2,
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1.2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Liquid Top Accent Specular Highlight
                      Positioned(
                        top: 0,
                        left: 20,
                        right: 20,
                        height: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.35),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Progress Bar Along Top
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 2.5,
                        child: Selector<AudioProvider, double>(
                          selector: (_, ap) => (ap.duration.inMilliseconds > 0)
                              ? (ap.position.inMilliseconds / ap.duration.inMilliseconds).clamp(0.0, 1.0)
                              : 0.0,
                          builder: (_, progress, __) => LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.transparent,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.pinkAccent,
                            ),
                          ),
                        ),
                      ),

                      // Main Content Row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Row(
                          children: [
                            // Album Artwork Thumbnail
                            Hero(
                              tag: 'album_art_${track.id}',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: CascadingArtwork(
                                    key: ValueKey('mini_art_${track.id}'),
                                    trackId: track.id,
                                    imageUrl: track.thumbnailUrl,
                                    title: track.title,
                                    artist: track.artist,
                                    width: 48,
                                    height: 48,
                                    borderRadius: BorderRadius.circular(12),
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
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isBuffering ? 'Buffering audio...' : track.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isBuffering ? AppColors.pinkAccent : AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: isBuffering ? FontWeight.w500 : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Mini Equalizer Indicator
                            if (isPlaying)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: _MiniEqualizerBar(),
                              ),

                            // Circular Play / Pause Hero Button (Soft White / Cream Glow from Reference UI)
                            GestureDetector(
                              onTap: () => audioProvider.togglePlayPause(),
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.pinkAccent.withValues(alpha: 0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: isBuffering
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              Color(0xFF0B0A12),
                                            ),
                                          ),
                                        )
                                      : Icon(
                                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                          color: const Color(0xFF0B0A12),
                                          size: 26,
                                        ),
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
      builder: (_, __) {
        final val = _animController.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _bar(8 + val * 8),
            const SizedBox(width: 2.5),
            _bar(16 - val * 7),
            const SizedBox(width: 2.5),
            _bar(10 + val * 6),
          ],
        );
      },
    );
  }

  Widget _bar(double height) {
    return Container(
      width: 2.8,
      height: height.clamp(4.0, 16.0),
      decoration: BoxDecoration(
        color: AppColors.pinkAccent,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
