import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/audiobooks/models/audiobook_model.dart';
import '../providers/audio_provider.dart';
import '../core/services/artwork_resolver.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

class AudiobookDetailsScreen extends StatelessWidget {
  final AudiobookModel book;

  AudiobookDetailsScreen({
    super.key,
    AudiobookModel? book,
    AudiobookModel? audiobook,
  })  : assert(book != null || audiobook != null),
        book = (book ?? audiobook)!;

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.read<AudioProvider>();
    final tracks = book.toTrackList();

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Audiobook', style: AppTextStyles.h3),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
          children: [
            // Cover Art & Header
            Center(
              child: AppArtworkImage(
                imageUrl: book.coverUrl,
                title: book.title,
                artist: book.author,
                width: 170,
                height: 170,
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              book.title,
              textAlign: TextAlign.center,
              style: AppTextStyles.h2.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 4),
            Text(
              'By ${book.author} • Narrated by ${book.narrator}',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              '${book.chapters.length} Chapters • ${_formatDuration(book.totalDurationSeconds)}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.accentTeal, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 18),

            // Play First Chapter Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primarySoft,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 26),
                label: const Text('Play from Beginning', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: () {
                  if (tracks.isNotEmpty) {
                    audio.playTrack(tracks.first, tracks);
                  }
                },
              ),
            ),
            const SizedBox(height: 24),

            // Description
            Text('Overview', style: AppTextStyles.h3.copyWith(fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              book.description,
              style: AppTextStyles.bodySecondary.copyWith(height: 1.4, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Chapters List
            Text('Chapters', style: AppTextStyles.h3.copyWith(fontSize: 16)),
            const SizedBox(height: 10),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: book.chapters.length,
              separatorBuilder: (_, __) => const Divider(color: AppColors.cardBorder, height: 1),
              itemBuilder: (ctx, i) {
                final chapter = book.chapters[i];
                final track = tracks[i];

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surface1,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: Center(
                      child: Text(
                        '${chapter.chapterNumber}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                  title: Text(chapter.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(_formatDuration(chapter.durationSeconds), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.accentTeal, size: 28),
                    onPressed: () => audio.playTrack(track, tracks),
                  ),
                  onTap: () => audio.playTrack(track, tracks),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
