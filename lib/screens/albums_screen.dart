import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/audio_provider.dart';
import '../features/music/models/music_models.dart';
import '../core/services/curated_tracks.dart';
import '../core/services/artwork_resolver.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

class AlbumData {
  final String id;
  final String title;
  final String artist;
  final String coverUrl;
  final int trackCount;
  final List<YoutubeTrack> tracks;

  const AlbumData({
    required this.id,
    required this.title,
    required this.artist,
    required this.coverUrl,
    required this.trackCount,
    required this.tracks,
  });
}

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filterQuery = '';

  List<AlbumData> _getAlbums(AudioProvider audio) {
    final List<AlbumData> albums = [];

    // 1. User Created Playlists / Albums
    for (final entry in audio.userPlaylists.entries) {
      final name = entry.key;
      albums.add(
        AlbumData(
          id: 'user_pl_$name',
          title: name,
          artist: 'Personal Album',
          coverUrl: '',
          trackCount: entry.value.length,
          tracks: [],
        ),
      );
    }

    // 2. Curated Albums & Compilations
    albums.addAll([
      AlbumData(
        id: 'curated_midnight',
        title: 'Midnight Melancholy',
        artist: 'Various Artists • Late Night Session',
        coverUrl: 'https://i.ytimg.com/vi/aJOTlE1K90k/hqdefault.jpg',
        trackCount: CuratedTracks.lateNightTracks.length,
        tracks: CuratedTracks.lateNightTracks,
      ),
      AlbumData(
        id: 'curated_sunset',
        title: 'Sunset Acoustic Vibes',
        artist: 'Acoustic Sessions 2026',
        coverUrl: 'https://i.ytimg.com/vi/1poi0oK3W6U/hqdefault.jpg',
        trackCount: CuratedTracks.chillTracks.length,
        tracks: CuratedTracks.chillTracks,
      ),
      AlbumData(
        id: 'curated_trending',
        title: 'Top Hits Billboard 2026',
        artist: 'Trending Chartbusters',
        coverUrl: 'https://i.ytimg.com/vi/IltsbcL43dA/hqdefault.jpg',
        trackCount: CuratedTracks.trendingTracks.length,
        tracks: CuratedTracks.trendingTracks,
      ),
      AlbumData(
        id: 'curated_workout',
        title: 'High Energy Cardio & Bass',
        artist: 'Workout Motivation',
        coverUrl: 'https://i.ytimg.com/vi/sCbv_VIdy3A/hqdefault.jpg',
        trackCount: CuratedTracks.workoutTracks.length,
        tracks: CuratedTracks.workoutTracks,
      ),
      AlbumData(
        id: 'curated_focus',
        title: 'Deep Focus & Lo-Fi Beats',
        artist: 'Study Frequency',
        coverUrl: 'https://i.ytimg.com/vi/5qap5aO4i9A/hqdefault.jpg',
        trackCount: CuratedTracks.focusTracks.length,
        tracks: CuratedTracks.focusTracks,
      ),
    ]);

    if (_filterQuery.isEmpty) return albums;
    final q = _filterQuery.toLowerCase();
    return albums.where((a) => a.title.toLowerCase().contains(q) || a.artist.toLowerCase().contains(q)).toList();
  }

  void _openAlbumDetails(AlbumData album, AudioProvider audio) async {
    List<YoutubeTrack> tracks = album.tracks;
    if (tracks.isEmpty && album.id.startsWith('user_pl_')) {
      tracks = await audio.getPlaylistTracks(album.title);
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      AppArtworkImage(
                        imageUrl: album.coverUrl,
                        title: album.title,
                        artist: album.artist,
                        width: 72,
                        height: 72,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(album.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.h3),
                            const SizedBox(height: 4),
                            Text(album.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySecondary),
                            const SizedBox(height: 4),
                            Text('${tracks.length} songs', style: const TextStyle(color: AppColors.accentTeal, fontSize: 12)),
                          ],
                        ),
                      ),
                      if (tracks.isNotEmpty)
                        IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: AppColors.primarySoft),
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            audio.playTrack(tracks.first, tracks);
                          },
                        ),
                    ],
                  ),
                ),
                const Divider(color: AppColors.cardBorder, height: 1),
                Expanded(
                  child: tracks.isEmpty
                      ? const Center(
                          child: Text('No tracks in this album yet', style: TextStyle(color: AppColors.textSecondary)),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: tracks.length,
                          itemBuilder: (_, i) {
                            final track = tracks[i];
                            return ListTile(
                              leading: Text('${i + 1}', style: const TextStyle(color: AppColors.textTertiary, fontWeight: FontWeight.bold)),
                              title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                              subtitle: Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              trailing: IconButton(
                                icon: const Icon(Icons.play_circle_outline_rounded, color: AppColors.accentTeal),
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  audio.playTrack(track, tracks);
                                },
                              ),
                              onTap: () {
                                Navigator.of(ctx).pop();
                                audio.playTrack(track, tracks);
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();
    final albums = _getAlbums(audio);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
          children: [
            Row(
              children: [
                const Icon(Icons.album_rounded, color: AppColors.accentTeal, size: 28),
                const SizedBox(width: 10),
                Text('Albums & Collections', style: AppTextStyles.h1.copyWith(fontSize: 24)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Browse albums, compilations, and personal records',
              style: AppTextStyles.bodySecondary.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 18),

            // Search Bar
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search albums and artists...',
                hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.iconIdle),
                filled: true,
                fillColor: AppColors.surface1,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
              ),
              onChanged: (val) => setState(() => _filterQuery = val.trim()),
            ),
            const SizedBox(height: 20),

            // Grid of Albums
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.78,
              ),
              itemCount: albums.length,
              itemBuilder: (ctx, i) {
                final album = albums[i];
                return GestureDetector(
                  onTap: () => _openAlbumDetails(album, audio),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surface1,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AppArtworkImage(
                            imageUrl: album.coverUrl,
                            title: album.title,
                            artist: album.artist,
                            width: double.infinity,
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          album.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          album.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${album.trackCount} tracks',
                          style: const TextStyle(
                            color: AppColors.accentTeal,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
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
    );
  }
}
