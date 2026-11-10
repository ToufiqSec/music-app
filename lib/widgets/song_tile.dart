import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song_model.dart';
import '../theme/app_theme.dart';

class SongTile extends StatelessWidget {
  final SongModelItem song;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;

  const SongTile({
    super.key,
    required this.song,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 50,
          height: 50,
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
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isCurrent ? AppTheme.primary : AppTheme.textPrimary,
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
        ),
      ),
      trailing: isCurrent && isPlaying
          ? const Icon(Icons.graphic_eq, color: AppTheme.accent)
          : Text(
              _formatDuration(song.duration),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
