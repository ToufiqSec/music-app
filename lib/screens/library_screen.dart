import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/audio_provider.dart';
import '../core/services/curated_tracks.dart';
import '../features/music/models/music_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_shadows.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.watch<AudioProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Library',
                  style: AppTextStyles.h1.copyWith(fontSize: 26),
                ),
                IconButton(
                  icon: const Icon(Icons.add_rounded, color: AppColors.iconIdle, size: 28),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _showCreatePlaylistDialog(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Top Quick Rows (Liked Songs & Offline Cache)
            Row(
              children: [
                Expanded(
                  child: _buildQuickCard(
                    title: 'Liked Songs',
                    subtitle: '12 Favorites',
                    icon: Icons.favorite_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5B4D8A), Color(0xFFC789B8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      audioProvider.playTrack(
                        CuratedTracks.jumpBackInTracks.first,
                        CuratedTracks.jumpBackInTracks,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickCard(
                    title: 'Downloads',
                    subtitle: 'Saved Offline',
                    icon: Icons.download_done_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2C3E50), Color(0xFF4CA1AF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      audioProvider.playTrack(
                        CuratedTracks.trendingTracks.first,
                        CuratedTracks.trendingTracks,
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            Text(
              'Recently Played',
              style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),

            // Recent Tracks List
            ...CuratedTracks.jumpBackInTracks.take(4).map((track) {
              final isCurrent = audioProvider.currentTrack?.id == track.id;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppColors.surface2
                      : AppColors.surface1.withValues(alpha: 0.6),
                  borderRadius: AppRadii.borderMedium,
                ),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: AppRadii.borderSmall,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: CachedNetworkImage(
                        imageUrl: track.thumbnailUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 120,
                      ),
                    ),
                  ),
                  title: Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isCurrent
                          ? AppColors.primarySoft
                          : AppColors.textPrimary,
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    track.artist,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: Icon(
                    isCurrent && audioProvider.isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: isCurrent
                        ? AppColors.primarySoft
                        : AppColors.iconIdle,
                    size: 28,
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    audioProvider.playTrack(
                      track,
                      CuratedTracks.jumpBackInTracks,
                    );
                  },
                ),
              );
            }),

            const SizedBox(height: 20),
            Text(
              'Your Playlists',
              style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),

            ..._buildDummyPlaylists(context, audioProvider),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: AppRadii.borderMedium,
          boxShadow: const [AppShadows.shadowSoft],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.cardTitle.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDummyPlaylists(
    BuildContext context,
    AudioProvider audioProvider,
  ) {
    final playlists = [
      {'title': 'Chill Evening Flow', 'count': '24 Songs'},
      {'title': 'Deep Focus & Coding', 'count': '38 Songs'},
      {'title': 'Acoustic Sunday Vibes', 'count': '18 Songs'},
    ];

    return playlists.map((p) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surface1.withValues(alpha: 0.7),
          borderRadius: AppRadii.borderMedium,
        ),
        child: ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: AppRadii.borderSmall,
            ),
            child: const Icon(
              Icons.music_note_rounded,
              color: AppColors.primarySoft,
            ),
          ),
          title: Text(
            p['title']!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            p['count']!,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.iconIdle,
          ),
          onTap: () {
            HapticFeedback.lightImpact();
            audioProvider.playTrack(
              CuratedTracks.madeForYouTracks.first,
              CuratedTracks.madeForYouTracks,
            );
          },
        ),
      );
    }).toList();
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface1,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.borderLarge,
          ),
          title: Text('New Playlist', style: AppTextStyles.h3),
          content: TextField(
            autofocus: true,
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Playlist name',
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadii.borderPill,
                ),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Create',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
