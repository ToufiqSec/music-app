import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:just_audio/just_audio.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final song = player.currentSong;

    if (song == null) {
      return const Scaffold(
        body: Center(child: Text('No song playing')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              const Spacer(),
              // Album Art
              Center(
                child: Hero(
                  tag: 'album_art_${song.id}',
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.78,
                    height: MediaQuery.of(context).size.width * 0.78,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: song.artUri != null
                          ? CachedNetworkImage(
                              imageUrl: song.artUri!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Icon(
                                Icons.music_note,
                                size: 80,
                                color: AppTheme.secondary,
                              ),
                            )
                          : const Icon(
                              Icons.music_note,
                              size: 80,
                              color: AppTheme.secondary,
                            ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // Title & Artist
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Progress Bar
              ProgressBar(
                progress: player.progress.current,
                buffered: player.progress.buffered,
                total: player.progress.total,
                onSeek: player.seek,
                progressBarColor: AppTheme.primary,
                baseBarColor: AppTheme.darkCard,
                bufferedBarColor: AppTheme.secondary.withValues(alpha: 0.3),
                thumbColor: AppTheme.accent,
                timeLabelTextStyle: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
              // Playback Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.shuffle,
                      color: player.isShuffle ? AppTheme.accent : AppTheme.textSecondary,
                    ),
                    onPressed: player.toggleShuffle,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous, size: 36),
                    onPressed: player.skipPrevious,
                  ),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppTheme.primary, AppTheme.accent],
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        player.isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 34,
                        color: Colors.white,
                      ),
                      onPressed: player.togglePlayPause,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, size: 36),
                    onPressed: player.skipNext,
                  ),
                  IconButton(
                    icon: Icon(
                      player.loopMode == LoopMode.one
                          ? Icons.repeat_one
                          : (player.loopMode == LoopMode.all ? Icons.repeat : Icons.repeat),
                      color: player.loopMode != LoopMode.off
                          ? AppTheme.accent
                          : AppTheme.textSecondary,
                    ),
                    onPressed: player.toggleLoopMode,
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
