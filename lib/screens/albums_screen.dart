import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/audio_provider.dart';
import '../features/music/models/music_models.dart';
import '../core/crypto/des_ecb.dart';
import '../core/services/curated_tracks.dart';
import '../core/services/artwork_resolver.dart';
import '../widgets/app_profile_avatar.dart';
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
  List<AlbumData> _dynamicAlbums = [];
  bool _isLoadingDynamicAlbums = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _fetchDynamicAlbums('trending 2026');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  /// Fetches real trending albums from JioSaavn catalog
  Future<void> _fetchDynamicAlbums(String query) async {
    setState(() => _isLoadingDynamicAlbums = true);
    final cleanQuery = query.trim().isNotEmpty ? query.trim() : 'trending 2026';

    try {
      final uri = Uri.parse(
        'https://www.jiosaavn.com/api.php?__call=search.getAlbumResults&_format=json&cc=in&n=18&p=1&q=${Uri.encodeComponent(cleanQuery)}',
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>? ?? [];

        final fetched = <AlbumData>[];
        for (final item in results) {
          final rawId = item['albumid']?.toString() ?? '';
          if (rawId.isEmpty) continue;

          final title = _unescapeHtml(item['title']?.toString() ?? item['text']?.toString() ?? 'Album');
          final artist = _unescapeHtml(item['primary_artists']?.toString() ?? item['music']?.toString() ?? 'Various Artists');
          var image = item['image']?.toString() ?? '';
          if (image.contains('150x150')) {
            image = image.replaceAll('150x150', '500x500');
          }

          fetched.add(
            AlbumData(
              id: 'saavn_album_$rawId',
              title: title,
              artist: artist,
              coverUrl: image,
              trackCount: 0, // Loaded dynamically on tap
              tracks: [],
            ),
          );
        }

        if (mounted) {
          setState(() {
            _dynamicAlbums = fetched;
            _isLoadingDynamicAlbums = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('[AlbumsScreen] Failed to fetch dynamic albums: $e');
    }

    if (mounted) {
      setState(() => _isLoadingDynamicAlbums = false);
    }
  }

  void _onSearchChanged(String val) {
    setState(() => _filterQuery = val.trim());
    _searchDebounce?.cancel();
    if (val.trim().length >= 3) {
      _searchDebounce = Timer(const Duration(milliseconds: 600), () {
        _fetchDynamicAlbums(val.trim());
      });
    } else if (val.trim().isEmpty) {
      _fetchDynamicAlbums('trending 2026');
    }
  }

  String _unescapeHtml(String text) {
    return text
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  List<AlbumData> _getAlbums(AudioProvider audio) {
    final List<AlbumData> albums = [];

    // 1. User Created Playlists / Albums
    for (final entry in audio.userPlaylists.entries) {
      final name = entry.key;
      albums.add(
        AlbumData(
          id: 'user_pl_$name',
          title: name,
          artist: 'Personal Playlist',
          coverUrl: '',
          trackCount: entry.value.length,
          tracks: [],
        ),
      );
    }

    // 2. Dynamic Catalog Albums from API
    if (_dynamicAlbums.isNotEmpty) {
      albums.addAll(_dynamicAlbums);
    } else {
      // Curated Fallbacks if API request is pending or offline
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
    }

    if (_filterQuery.isEmpty) return albums;
    final q = _filterQuery.toLowerCase();
    return albums.where((a) => a.title.toLowerCase().contains(q) || a.artist.toLowerCase().contains(q)).toList();
  }

  void _openAlbumDetails(AlbumData album, AudioProvider audio) async {
    List<YoutubeTrack> tracks = List.from(album.tracks);

    // If dynamic JioSaavn album with tracks not yet loaded, fetch them live
    if (tracks.isEmpty && album.id.startsWith('saavn_album_')) {
      final rawAlbumId = album.id.replaceFirst('saavn_album_', '');
      try {
        final uri = Uri.parse(
          'https://www.jiosaavn.com/api.php?__call=content.getAlbumDetails&_format=json&cc=in&albumid=$rawAlbumId',
        );
        final resp = await http.get(uri).timeout(const Duration(seconds: 7));
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body);
          final songs = data['songs'] as List<dynamic>? ?? [];

          for (final s in songs) {
            final encryptedUrl = s['encrypted_media_url'] as String? ?? '';
            final has320 = s['320kbps'] == 'true' || s['320kbps'] == true;
            String? streamUrl;
            if (encryptedUrl.isNotEmpty) {
              streamUrl = DesEcbDecryptor.decryptMediaUrl(encryptedUrl, is320Available: has320);
            }

            final trackId = s['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString();
            final title = _unescapeHtml(s['song']?.toString() ?? s['title']?.toString() ?? 'Unknown Song');
            final artist = _unescapeHtml(s['primary_artists']?.toString() ?? s['singers']?.toString() ?? album.artist);
            final duration = int.tryParse(s['duration']?.toString() ?? '0') ?? 0;
            var image = s['image']?.toString();
            if (image != null && image.contains('150x150')) {
              image = image.replaceAll('150x150', '500x500');
            }

            tracks.add(
              YoutubeTrack(
                id: trackId,
                title: title,
                artist: artist,
                durationSeconds: duration,
                thumbnailUrl: image ?? album.coverUrl,
                audioStreamUrl: streamUrl,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('[AlbumsScreen] Failed to load album tracks: $e');
      }
    } else if (tracks.isEmpty && album.id.startsWith('user_pl_')) {
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
                        key: ValueKey('album_detail_cover_${album.id}'),
                        trackId: album.id,
                        imageUrl: album.coverUrl.trim().isNotEmpty
                            ? album.coverUrl
                            : (album.tracks.isNotEmpty ? album.tracks.first.thumbnailUrl : ''),
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
                            Text(
                              tracks.isNotEmpty ? '${tracks.length} lossless songs' : 'Loading tracks...',
                              style: const TextStyle(color: AppColors.accentTeal, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
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
                          child: CircularProgressIndicator(color: AppColors.primarySoft),
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
    final bottomInset = 72.0 + 64.0 + MediaQuery.of(context).padding.bottom + 28.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
          children: [
            Row(
              children: [
                const Icon(Icons.album_rounded, color: AppColors.accentTeal, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Albums & Collections', style: AppTextStyles.h1.copyWith(fontSize: 22)),
                ),
                const AppProfileAvatar(),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Browse live album charts, compilations, and personal records',
              style: AppTextStyles.bodySecondary.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 18),

            // Search Bar
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search live albums and artists...',
                hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.iconIdle),
                suffixIcon: _isLoadingDynamicAlbums
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primarySoft),
                        ),
                      )
                    : null,
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
              onChanged: _onSearchChanged,
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
                final effectiveCover = album.coverUrl.trim().isNotEmpty
                    ? album.coverUrl
                    : (album.tracks.isNotEmpty ? album.tracks.first.thumbnailUrl : '');
                final trackCountText = album.id.startsWith('saavn_album_')
                    ? 'Lossless CD • Tap to play'
                    : (album.trackCount > 0 ? '${album.trackCount} tracks' : '');
                return GestureDetector(
                  key: ValueKey('album_card_${album.id}'),
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
                            key: ValueKey('album_cover_${album.id}'),
                            trackId: album.id,
                            imageUrl: effectiveCover,
                            title: album.title,
                            artist: album.artist,
                            width: double.infinity,
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          album.title.isNotEmpty ? album.title : 'Unknown Album',
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
                          album.artist.isNotEmpty ? album.artist : 'Various Artists',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          trackCountText,
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
