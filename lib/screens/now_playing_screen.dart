import 'dart:ui';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/audio_provider.dart';
import '../core/services/audio_cache_service.dart';
import '../features/music/models/music_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_shadows.dart';
import '../theme/app_motion.dart';
import '../widgets/glass_icon_button.dart';
import '../widgets/twilight_scene_background.dart';
import '../widgets/synced_lyrics_view.dart';
import '../widgets/generated_cover_art.dart';

/// Full-Screen Now Playing Sanctuary Player from Universal UI Design System: Twilight Calm.
class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  bool _isDownloaded = false;

  @override
  void initState() {
    super.initState();
    _checkCacheStatus();
  }

  Future<void> _checkCacheStatus() async {
    final track = context.read<AudioProvider>().currentTrack;
    if (track != null) {
      final cached = await AudioCacheService.isTrackCached(track.id);
      if (mounted) {
        setState(() => _isDownloaded = cached);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.read<AudioProvider>();
    final track = audioProvider.currentTrack;

    if (track == null) {
      return Scaffold(
        backgroundColor: AppColors.bgBase,
        body: Center(
          child: Text('No song selected', style: AppTextStyles.bodyMedium),
        ),
      );
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final artSize = (screenWidth * 0.75).clamp(200.0, 320.0);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Stack(
        children: [
          // Ambient Dynamic Blurred Album Art Backdrop (Spotify & YouTube Music Theme)
          Positioned.fill(
            child: track.thumbnailUrl.isNotEmpty
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: track.thumbnailUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 400,
                        errorWidget: (_, __, ___) => const TwilightSceneBackground(
                          mode: TwilightSceneMode.fullBleed,
                        ),
                      ),
                      ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.55),
                                  Colors.black.withValues(alpha: 0.70),
                                  AppColors.bgBase.withValues(alpha: 0.95),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : const TwilightSceneBackground(
                    mode: TwilightSceneMode.fullBleed,
                  ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      // Top Navigation Header (Matching Twilight Reference)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GlassIconButton(
                            icon: Icons.close_rounded,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Like Button
                              Selector<AudioProvider, bool>(
                                selector: (_, ap) => ap.isTrackLiked(track.id),
                                builder: (context, isLiked, _) {
                                  return GlassIconButton(
                                    icon: isLiked
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    iconColor: isLiked
                                        ? AppColors.sunsetPink
                                        : AppColors.iconIdle,
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      audioProvider.toggleFavorite(track);
                                    },
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              // Download Button
                              Selector<AudioProvider, double?>(
                                selector: (_, ap) => ap.downloadProgress[track.id],
                                builder: (context, dlProgress, _) {
                                  return FutureBuilder<bool>(
                                    future: AudioCacheService.isTrackCached(track.id),
                                    builder: (context, snapshot) {
                                      final isCached = snapshot.data ?? false;
                                      return GlassIconButton(
                                        icon: isCached
                                            ? Icons.download_done_rounded
                                            : Icons.download_rounded,
                                        iconColor: isCached
                                            ? AppColors.success
                                            : AppColors.iconIdle,
                                        onTap: () async {
                                          HapticFeedback.lightImpact();
                                          if (!isCached && dlProgress == null) {
                                            await audioProvider.downloadTrackForOffline(track);
                                          }
                                        },
                                      );
                                    },
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              GlassIconButton(
                                icon: Icons.more_horiz_rounded,
                                onTap: () => _showTrackOptions(context, track, audioProvider),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Album Artwork with Ambient Shadow & Crisp Cover Art (Spotify / YouTube Music)
                      Center(
                        child: Hero(
                          tag: 'album_art_${track.id}',
                          child: Container(
                            width: artSize,
                            height: artSize,
                            decoration: BoxDecoration(
                              borderRadius: AppRadii.borderLarge,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.50),
                                  blurRadius: 36,
                                  spreadRadius: 4,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            child: track.thumbnailUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: AppRadii.borderLarge,
                                    child: CachedNetworkImage(
                                      imageUrl: track.thumbnailUrl,
                                      fit: BoxFit.cover,
                                      memCacheWidth: 800,
                                      placeholder: (_, __) => Container(
                                        color: AppColors.surface1,
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.primarySoft,
                                          ),
                                        ),
                                      ),
                                      errorWidget: (_, __, ___) => GeneratedCoverArt(
                                        title: track.title,
                                        artist: track.artist,
                                        thumbnailUrl: track.thumbnailUrl,
                                        durationSeconds: track.durationSeconds,
                                        size: artSize,
                                      ),
                                    ),
                                  )
                                : GeneratedCoverArt(
                                    title: track.title,
                                    artist: track.artist,
                                    thumbnailUrl: track.thumbnailUrl,
                                    durationSeconds: track.durationSeconds,
                                    size: artSize,
                                  ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Track Metadata Row (Title, Artist, Like Heart)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.h2.copyWith(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // High-Res Audio Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: AppRadii.borderSmall,
                              border: Border.all(
                                color: AppColors.primarySoft.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '320K',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primarySoft,
                              ),
                            ),
                          ),

                          // Heart Like Button (Connected directly to AudioProvider)
                          Selector<AudioProvider, bool>(
                            selector: (_, ap) => ap.isTrackLiked(track.id),
                            builder: (context, isLiked, child) {
                              return IconButton(
                                icon: Icon(
                                  isLiked
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_outline_rounded,
                                  color: isLiked
                                      ? AppColors.sunsetPink
                                      : AppColors.iconIdle,
                                  size: 26,
                                ),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  audioProvider.toggleFavorite(track);
                                },
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Audio Scrubber (Progress Bar)
                      Selector<AudioProvider, (Duration, Duration, Duration)>(
                        selector: (_, ap) => (ap.position, ap.bufferedPosition, ap.duration),
                        builder: (context, data, child) {
                          final (pos, buf, dur) = data;
                          return ProgressBar(
                            progress: pos,
                            buffered: buf,
                            total: dur,
                            onSeek: (duration) => audioProvider.seekTo(duration),
                            baseBarColor: AppColors.surface2,
                            bufferedBarColor: AppColors.surface2.withValues(alpha: 0.8),
                            progressBarColor: AppColors.primarySoft,
                            thumbColor: AppColors.textPrimary,
                            thumbGlowColor: AppColors.primarySoft.withValues(alpha: 0.3),
                            thumbRadius: 7.0,
                            barHeight: 4.0,
                            timeLabelTextStyle: AppTextStyles.caption.copyWith(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Main Playback Controls Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Shuffle
                          Selector<AudioProvider, bool>(
                            selector: (_, ap) => ap.isShuffle,
                            builder: (context, isShuffle, child) {
                              return IconButton(
                                icon: Icon(
                                  Icons.shuffle_rounded,
                                  size: 24,
                                  color: isShuffle
                                      ? AppColors.primarySoft
                                      : AppColors.iconIdle,
                                ),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  audioProvider.toggleShuffle();
                                },
                              );
                            },
                          ),

                          // Previous
                          IconButton(
                            icon: const Icon(
                              Icons.skip_previous_rounded,
                              size: 38,
                              color: AppColors.textPrimary,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              audioProvider.playPrevious();
                            },
                          ),

                          // Play / Pause / Buffering Circle
                          Selector<AudioProvider, (bool, bool)>(
                            selector: (_, ap) => (ap.isPlaying, ap.isBuffering),
                            builder: (context, state, child) {
                              final (isPlaying, isBuffering) = state;

                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  audioProvider.togglePlayPause();
                                },
                                child: Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primarySoft.withValues(alpha: 0.4),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: isBuffering
                                        ? const SizedBox(
                                            width: 28,
                                            height: 28,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.8,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Color(0xFF1E1B24),
                                              ),
                                            ),
                                          )
                                        : Icon(
                                            isPlaying
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                            size: 40,
                                            color: const Color(0xFF1E1B24),
                                          ),
                                  ),
                                ),
                              );
                            },
                          ),

                          // Next
                          IconButton(
                            icon: const Icon(
                              Icons.skip_next_rounded,
                              size: 38,
                              color: AppColors.textPrimary,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              audioProvider.playNext();
                            },
                          ),

                          // Repeat
                          Selector<AudioProvider, RepeatMode>(
                            selector: (_, ap) => ap.repeatMode,
                            builder: (context, repeatMode, child) {
                              return IconButton(
                                icon: Icon(
                                  repeatMode == RepeatMode.one
                                      ? Icons.repeat_one_rounded
                                      : Icons.repeat_rounded,
                                  size: 24,
                                  color: repeatMode != RepeatMode.off
                                      ? AppColors.primarySoft
                                      : AppColors.iconIdle,
                                ),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  audioProvider.toggleRepeatMode();
                                },
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Synced Karaoke Lyrics View (Issue 5: fills empty lower area)
                      Container(
                        height: 160,
                        decoration: BoxDecoration(
                          color: AppColors.surface1.withValues(alpha: 0.65),
                          borderRadius: AppRadii.borderLarge,
                          border: Border.all(
                            color: AppColors.primarySoft.withValues(alpha: 0.2),
                            width: 1,
                          ),
                          boxShadow: const [AppShadows.shadowSoft],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: SyncedLyricsView(track: track),
                      ),

                      const SizedBox(height: 12),

                      // Bottom Utilities (Offline Cache Download, Up Next Queue)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0, top: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Download Offline Action
                            Selector<AudioProvider, double?>(
                              selector: (_, ap) => ap.downloadProgress[track.id],
                              builder: (context, downloadProgress, child) {
                                return Row(
                                  children: [
                                    if (downloadProgress != null)
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          value: downloadProgress,
                                          strokeWidth: 2,
                                          valueColor: const AlwaysStoppedAnimation<Color>(
                                            AppColors.primarySoft,
                                          ),
                                        ),
                                      )
                                    else
                                      IconButton(
                                        icon: Icon(
                                          _isDownloaded
                                              ? Icons.check_circle_rounded
                                              : Icons.download_for_offline_outlined,
                                          color: _isDownloaded
                                              ? AppColors.primarySoft
                                              : AppColors.iconIdle,
                                          size: 22,
                                        ),
                                        onPressed: () async {
                                          if (!_isDownloaded) {
                                            HapticFeedback.lightImpact();
                                            await audioProvider.downloadTrackForOffline(track);
                                            setState(() => _isDownloaded = true);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Downloaded "${track.title}" to Offline Vault',
                                                    style: AppTextStyles.bodySmall,
                                                  ),
                                                  backgroundColor: AppColors.surface1,
                                                  duration: const Duration(seconds: 2),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    Text(
                                      _isDownloaded
                                          ? 'Saved Offline'
                                          : (downloadProgress != null
                                              ? '${(downloadProgress * 100).toInt()}%'
                                              : 'Download'),
                                      style: AppTextStyles.caption.copyWith(
                                        color: _isDownloaded
                                            ? AppColors.primarySoft
                                            : AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),

                            // Autoplay Toggle (Issue 8)
                            Selector<AudioProvider, bool>(
                              selector: (_, ap) => ap.autoplayEnabled,
                              builder: (context, autoplayEnabled, child) {
                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    audioProvider.toggleAutoplay();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          !autoplayEnabled
                                              ? 'Autoplay ON: Continuous related audio flow'
                                              : 'Autoplay OFF: Playback stops after queue',
                                          style: AppTextStyles.bodySmall,
                                        ),
                                        backgroundColor: AppColors.surface1,
                                        duration: const Duration(seconds: 1),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: autoplayEnabled
                                          ? AppColors.primarySoft.withValues(alpha: 0.2)
                                          : AppColors.surface1,
                                      borderRadius: AppRadii.borderPill,
                                      border: Border.all(
                                        color: autoplayEnabled
                                            ? AppColors.primarySoft
                                            : AppColors.surface2,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.all_inclusive_rounded,
                                          size: 15,
                                          color: autoplayEnabled ? AppColors.primarySoft : AppColors.iconIdle,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Autoplay',
                                          style: AppTextStyles.caption.copyWith(
                                            color: autoplayEnabled ? Colors.white : AppColors.textMuted,
                                            fontWeight: autoplayEnabled ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                            // Queue / Up Next Sheet Trigger
                            Selector<AudioProvider, int>(
                              selector: (_, ap) => ap.playlistQueue.length,
                              builder: (context, queueLen, child) {
                                return GestureDetector(
                                  onTap: () => _showQueueSheet(context, audioProvider),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface1,
                                      borderRadius: AppRadii.borderPill,
                                      border: Border.all(
                                        color: AppColors.primarySoft.withValues(alpha: 0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.queue_music_rounded,
                                          size: 18,
                                          color: AppColors.primarySoft,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Queue ($queueLen)',
                                          style: AppTextStyles.caption.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
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
        ],
      ),
    );
  }

  Widget _buildArtworkFallback() {
    return Container(
      color: AppColors.surface2,
      child: const Center(
        child: Icon(Icons.music_note_rounded, color: AppColors.primarySoft, size: 64),
      ),
    );
  }

  void _showQueueSheet(BuildContext context, AudioProvider audioProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadii.xlarge),
            ),
            boxShadow: const [AppShadows.shadowFloat],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Playback Queue',
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${audioProvider.playlistQueue.length} Tracks',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.surface2, height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: audioProvider.playlistQueue.length,
                  itemBuilder: (context, index) {
                    final qTrack = audioProvider.playlistQueue[index];
                    final isCurrent = audioProvider.currentTrack?.id == qTrack.id;

                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: AppRadii.borderSmall,
                        child: qTrack.thumbnailUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: qTrack.thumbnailUrl,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                memCacheWidth: 120,
                                errorWidget: (_, __, ___) => GeneratedCoverArt(
                                  title: qTrack.title,
                                  artist: qTrack.artist,
                                  thumbnailUrl: qTrack.thumbnailUrl,
                                  durationSeconds: qTrack.durationSeconds,
                                  size: 44,
                                  borderRadius: AppRadii.borderSmall,
                                ),
                              )
                            : GeneratedCoverArt(
                                title: qTrack.title,
                                artist: qTrack.artist,
                                thumbnailUrl: qTrack.thumbnailUrl,
                                durationSeconds: qTrack.durationSeconds,
                                size: 44,
                                borderRadius: AppRadii.borderSmall,
                              ),
                      ),
                      title: Text(
                        qTrack.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isCurrent
                              ? AppColors.primarySoft
                              : AppColors.textPrimary,
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        qTrack.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: isCurrent
                          ? const Icon(
                              Icons.volume_up_rounded,
                              color: AppColors.primarySoft,
                              size: 20,
                            )
                          : null,
                      onTap: () {
                        audioProvider.playTrack(
                          qTrack,
                          audioProvider.playlistQueue,
                        );
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTrackOptions(BuildContext context, YoutubeTrack track, AudioProvider audioProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadii.xlarge),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded, color: AppColors.primarySoft),
                title: Text('Add to Playlist', style: AppTextStyles.bodyMedium),
                onTap: () {
                  Navigator.pop(context);
                  _showAddToPlaylistSheet(context, track, audioProvider);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded, color: AppColors.iconIdle),
                title: Text('Artist: ${track.artist}', style: AppTextStyles.bodyMedium),
                subtitle: Text('View Discography in Search', style: AppTextStyles.caption),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.high_quality_rounded, color: AppColors.primarySoft),
                title: Text('Audio Quality: 320 kbps (Direct Stream)', style: AppTextStyles.bodyMedium),
                subtitle: Text('Zero re-encoding • Pure AAC/M4A', style: AppTextStyles.caption),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddToPlaylistSheet(BuildContext context, YoutubeTrack track, AudioProvider audioProvider) {
    final playlists = audioProvider.userPlaylists.keys.toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Add to Playlist', style: AppTextStyles.h3),
                    TextButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.primarySoft),
                      label: Text('New', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primarySoft, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showCreatePlaylistDialog(context, track, audioProvider);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (playlists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: Text(
                        'No playlists yet. Tap "New" above to create one!',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                      ),
                    ),
                  )
                else
                  ...playlists.map(
                    (pName) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.playlist_play_rounded, color: AppColors.primarySoft),
                      title: Text(pName, style: AppTextStyles.bodyMedium),
                      onTap: () {
                        Navigator.pop(ctx);
                        audioProvider.addTrackToPlaylist(pName, track);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added to "$pName"'),
                            backgroundColor: AppColors.surface1,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, YoutubeTrack track, AudioProvider audioProvider) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.borderLarge),
        title: Text('New Playlist', style: AppTextStyles.h3),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primarySoft),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTextStyles.bodySmall),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primarySoft,
              shape: RoundedRectangleBorder(borderRadius: AppRadii.borderPill),
            ),
            onPressed: () async {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                await audioProvider.createPlaylist(name);
                await audioProvider.addTrackToPlaylist(name, track);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Created "$name" and added track'),
                      backgroundColor: AppColors.surface1,
                    ),
                  );
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('Create & Add', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
