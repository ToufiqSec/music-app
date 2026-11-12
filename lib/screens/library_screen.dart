import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/audio_provider.dart';
import '../core/services/curated_tracks.dart';
import '../core/services/track_metadata_store.dart';
import '../features/music/models/music_models.dart';
import '../widgets/generated_cover_art.dart';
import '../widgets/twilight_scene_background.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

class LibraryScreen extends StatelessWidget {
  final VoidCallback? onNavigateToDownloads;

  const LibraryScreen({super.key, this.onNavigateToDownloads});

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.read<AudioProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: TwilightSceneBackground(mode: TwilightSceneMode.header),
          ),
          SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: 160, // Clear mini-player & bottom nav
              ),
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
                    _showCreatePlaylistDialog(context, audioProvider);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Top Quick Rows (Liked Songs & Offline Cache)
            Selector<AudioProvider, int>(
              selector: (_, ap) => ap.favoriteIds.length,
              builder: (context, favCount, child) {
                return Row(
                  children: [
                    Expanded(
                      child: _buildQuickCard(
                        title: 'Liked Songs',
                        subtitle: '$favCount Favorites',
                        icon: Icons.favorite_rounded,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF5B4D8A), Color(0xFFC789B8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showFavoritesSheet(context, audioProvider);
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
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),
            Text(
              'Listening History',
              style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),

            // Real Listening History (Zero hardcoding)
            Selector<AudioProvider, List<YoutubeTrack>>(
              selector: (_, ap) => ap.historyTracks,
              builder: (context, history, child) {
                if (history.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surface1.withValues(alpha: 0.5),
                      borderRadius: AppRadii.borderMedium,
                      border: Border.all(color: AppColors.surface2),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.history_rounded, size: 36, color: AppColors.iconIdle),
                        const SizedBox(height: 8),
                        Text(
                          'No listening history yet',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Songs and episodes you play will appear here automatically.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                final displayHistory = history.take(6).toList();

                return Column(
                  children: displayHistory.map((track) {
                    return Selector<AudioProvider, (bool, bool)>(
                      selector: (_, ap) => (
                        ap.currentTrack?.id == track.id,
                        ap.isPlaying,
                      ),
                      builder: (context, state, child) {
                        final (isCurrent, isPlaying) = state;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surface1.withValues(alpha: 0.6),
                            borderRadius: AppRadii.borderMedium,
                            border: isCurrent
                                ? Border.all(color: AppColors.primarySoft.withValues(alpha: 0.5))
                                : null,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            leading: ClipRRect(
                              borderRadius: AppRadii.borderSmall,
                              child: (track.thumbnailUrl.isNotEmpty &&
                                      !track.thumbnailUrl.contains('hqdefault') &&
                                      !track.thumbnailUrl.contains('mqdefault'))
                                  ? CachedNetworkImage(
                                      imageUrl: track.thumbnailUrl,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => GeneratedCoverArt(
                                        title: track.title,
                                        artist: track.artist,
                                        thumbnailUrl: track.thumbnailUrl,
                                        durationSeconds: track.durationSeconds,
                                        size: 44,
                                        borderRadius: AppRadii.borderSmall,
                                      ),
                                    )
                                  : GeneratedCoverArt(
                                      title: track.title,
                                      artist: track.artist,
                                      thumbnailUrl: track.thumbnailUrl,
                                      durationSeconds: track.durationSeconds,
                                      size: 44,
                                      borderRadius: AppRadii.borderSmall,
                                    ),
                            ),
                            title: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: isCurrent ? AppColors.primarySoft : AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                            ),
                            trailing: Icon(
                              isCurrent && isPlaying
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_fill_rounded,
                              color: isCurrent ? AppColors.primarySoft : AppColors.iconIdle,
                              size: 28,
                            ),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              audioProvider.playTrack(track, displayHistory);
                            },
                          ),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Playlists',
                  style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
                ),
                GestureDetector(
                  onTap: () => _showCreatePlaylistDialog(context, audioProvider),
                  child: Text(
                    '+ Create',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primarySoft,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Persistent Playlists
            Selector<AudioProvider, Map<String, List<String>>>(
              selector: (_, ap) => ap.userPlaylists,
              builder: (context, playlists, child) {
                final names = playlists.keys.toList();
                if (names.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface1.withValues(alpha: 0.6),
                      borderRadius: AppRadii.borderMedium,
                    ),
                    child: Center(
                      child: Text(
                        'No custom playlists yet. Tap "+ Create" above!',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                      ),
                    ),
                  );
                }

                return Column(
                  children: names.map((name) {
                    final count = playlists[name]?.length ?? 0;
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
                            Icons.playlist_play_rounded,
                            color: AppColors.primarySoft,
                            size: 26,
                          ),
                        ),
                        title: Text(
                          name,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '$count ${count == 1 ? "Song" : "Songs"}',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.iconIdle,
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showPlaylistSheet(context, name, audioProvider);
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
        ],
      ),
    );
  }

  Widget _buildThumbFallback() {
    return Container(
      width: 44,
      height: 44,
      color: AppColors.surface2,
      child: const Icon(Icons.music_note_rounded, color: AppColors.primarySoft),
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: AppRadii.borderMedium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Colors.white, size: 26),
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

  void _showCreatePlaylistDialog(BuildContext context, AudioProvider audioProvider) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
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
              onPressed: () {
                final name = textController.text.trim();
                if (name.isNotEmpty) {
                  audioProvider.createPlaylist(name);
                }
                Navigator.pop(ctx);
              },
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

  void _showFavoritesSheet(BuildContext context, AudioProvider audioProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return FutureBuilder<List<YoutubeTrack>>(
          future: Future.wait([
            TrackMetadataStore.getAllSavedTracks(),
          ]).then((results) {
            final saved = results[0];
            final setMap = <String, YoutubeTrack>{};
            for (final t in CuratedTracks.allCatalogTracks) {
              setMap[t.id] = t;
            }
            for (final t in audioProvider.historyTracks) {
              setMap[t.id] = t;
            }
            for (final t in saved) {
              setMap[t.id] = t;
            }
            final favIds = audioProvider.favoriteIds;
            return setMap.values.where((t) => favIds.contains(t.id)).toList();
          }),
          builder: (context, snapshot) {
            final favTracks = snapshot.data ?? [];

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
                        Text('Liked Songs (${favTracks.length})', style: AppTextStyles.h3),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.iconIdle),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(color: AppColors.primarySoft),
                        ),
                      )
                    else if (favTracks.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Center(
                          child: Text(
                            'No liked songs yet. Tap the heart icon on any song!',
                            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: favTracks.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final track = favTracks[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: ClipRRect(
                                borderRadius: AppRadii.borderSmall,
                                child: (track.thumbnailUrl.isNotEmpty &&
                                        !track.thumbnailUrl.contains('hqdefault') &&
                                        !track.thumbnailUrl.contains('mqdefault'))
                                    ? CachedNetworkImage(
                                        imageUrl: track.thumbnailUrl,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => GeneratedCoverArt(
                                          title: track.title,
                                          artist: track.artist,
                                          thumbnailUrl: track.thumbnailUrl,
                                          durationSeconds: track.durationSeconds,
                                          size: 44,
                                          borderRadius: AppRadii.borderSmall,
                                        ),
                                      )
                                    : GeneratedCoverArt(
                                        title: track.title,
                                        artist: track.artist,
                                        thumbnailUrl: track.thumbnailUrl,
                                        durationSeconds: track.durationSeconds,
                                        size: 44,
                                        borderRadius: AppRadii.borderSmall,
                                      ),
                              ),
                              title: Text(track.title, style: AppTextStyles.bodyMedium),
                              subtitle: Text(track.artist, style: AppTextStyles.caption),
                              trailing: const Icon(Icons.play_arrow_rounded, color: AppColors.primarySoft),
                              onTap: () {
                                Navigator.pop(ctx);
                                audioProvider.playTrack(track, favTracks);
                              },
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
      },
    );
  }

  void _showPlaylistSheet(BuildContext context, String playlistName, AudioProvider audioProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return FutureBuilder<List<YoutubeTrack>>(
              future: audioProvider.getPlaylistTracks(playlistName),
              builder: (context, snapshot) {
                final tracks = snapshot.data ?? [];

                return Container(
                  height: MediaQuery.of(context).size.height * 0.65,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  playlistName,
                                  style: AppTextStyles.h2.copyWith(fontSize: 22),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${tracks.length} ${tracks.length == 1 ? "track" : "tracks"} in playlist',
                                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE53935)),
                                tooltip: 'Delete Playlist',
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  audioProvider.deletePlaylist(playlistName);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Playlist "$playlistName" deleted'),
                                      backgroundColor: AppColors.surface1,
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: AppColors.iconIdle),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (tracks.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primarySoft,
                              foregroundColor: AppColors.textPrimary,
                              minimumSize: const Size.fromHeight(44),
                              shape: RoundedRectangleBorder(borderRadius: AppRadii.borderPill),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                              Navigator.pop(ctx);
                              audioProvider.playTrack(tracks.first, tracks);
                            },
                          ),
                        ),
                      Expanded(
                        child: snapshot.connectionState == ConnectionState.waiting
                            ? const Center(child: CircularProgressIndicator(color: AppColors.primarySoft))
                            : tracks.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24.0),
                                      child: Text(
                                        'No songs in this playlist.\nUse "⋮" on any track to add it here!',
                                        textAlign: TextAlign.center,
                                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: tracks.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                                    itemBuilder: (context, index) {
                                      final track = tracks[index];
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: ClipRRect(
                                          borderRadius: AppRadii.borderSmall,
                                          child: (track.thumbnailUrl.isNotEmpty &&
                                                  !track.thumbnailUrl.contains('hqdefault') &&
                                                  !track.thumbnailUrl.contains('mqdefault'))
                                              ? CachedNetworkImage(
                                                  imageUrl: track.thumbnailUrl,
                                                  width: 44,
                                                  height: 44,
                                                  fit: BoxFit.cover,
                                                  errorWidget: (_, __, ___) => GeneratedCoverArt(
                                                    title: track.title,
                                                    artist: track.artist,
                                                    thumbnailUrl: track.thumbnailUrl,
                                                    durationSeconds: track.durationSeconds,
                                                    size: 44,
                                                    borderRadius: AppRadii.borderSmall,
                                                  ),
                                                )
                                              : GeneratedCoverArt(
                                                  title: track.title,
                                                  artist: track.artist,
                                                  thumbnailUrl: track.thumbnailUrl,
                                                  durationSeconds: track.durationSeconds,
                                                  size: 44,
                                                  borderRadius: AppRadii.borderSmall,
                                                ),
                                        ),
                                        title: Text(
                                          track.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.bodyMedium,
                                        ),
                                        subtitle: Text(
                                          track.artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.caption,
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: AppColors.iconIdle, size: 20),
                                          onPressed: () async {
                                            await audioProvider.removeTrackFromPlaylist(playlistName, track.id);
                                            setSheetState(() {});
                                          },
                                        ),
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          audioProvider.playTrack(track, tracks);
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
          },
        );
      },
    );
  }
}
