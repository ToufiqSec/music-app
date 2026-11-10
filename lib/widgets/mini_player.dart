import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/player_provider.dart';
import '../screens/now_playing_screen.dart';
import '../theme/app_theme.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final song = player.currentSong;

    if (song == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
        );
      },
      child: Container(
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            Hero(
              tag: 'album_art_${song.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 44,
                  height: 44,
                  color: AppTheme.darkCard,
                  child: song.artUri != null
                      ? CachedNetworkImage(
                          imageUrl: song.artUri!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.music_note,
                            color: AppTheme.secondary,
                          ),
                        )
                      : const Icon(
                          Icons.music_note,
                          color: AppTheme.secondary,
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Song Title & Artist
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Play / Pause Button
            IconButton(
              icon: Icon(
                player.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                size: 36,
                color: AppTheme.primary,
              ),
              onPressed: player.togglePlayPause,
            ),
            // Next Button
            IconButton(
              icon: const Icon(Icons.skip_next, size: 28, color: AppTheme.textPrimary),
              onPressed: player.skipNext,
            ),
          ],
        ),
      ),
    );
  }
}
