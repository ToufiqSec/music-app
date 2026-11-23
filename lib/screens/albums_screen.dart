import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _CategoryFilter {
  final String label;
  final String icon;
  final String query;

  const _CategoryFilter({
    required this.label,
    required this.icon,
    required this.query,
  });
}

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _filterQuery = '';
  List<AlbumData> _dynamicAlbums = [];
  bool _isLoadingDynamicAlbums = false;
  Timer? _searchDebounce;
  int _selectedCategoryIndex = 0;

  static const List<_CategoryFilter> _categories = [
    _CategoryFilter(label: 'Trending', icon: '🔥', query: 'trending 2026'),
    _CategoryFilter(label: 'Top Hits', icon: '✨', query: 'top hits billboard 2026'),
    _CategoryFilter(label: 'Romantic', icon: '💖', query: 'romantic love hits 2026'),
    _CategoryFilter(label: 'High Energy', icon: '⚡', query: 'punjabi workout party'),
    _CategoryFilter(label: 'Lo-Fi Chill', icon: '🌙', query: 'chill lofi acoustic beats'),
    _CategoryFilter(label: 'Classics', icon: '📻', query: 'retro evergreen bollywood'),
    _CategoryFilter(label: 'My Records', icon: '💿', query: '__playlists__'),
  ];

  @override
  void initState() {
    super.initState();
    _fetchDynamicAlbums(_categories[0].query);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  /// Fetches real trending albums from JioSaavn catalog
  Future<void> _fetchDynamicAlbums(String query) async {
    if (query == '__playlists__') {
      if (mounted) {
        setState(() {
          _dynamicAlbums = [];
          _isLoadingDynamicAlbums = false;
        });
      }
      return;
    }

    setState(() => _isLoadingDynamicAlbums = true);
    final cleanQuery = query.trim().isNotEmpty ? query.trim() : 'trending 2026';

    try {
      final uri = Uri.parse(
        'https://www.jiosaavn.com/api.php?__call=search.getAlbumResults&_format=json&cc=in&n=20&p=1&q=${Uri.encodeComponent(cleanQuery)}',
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

  void _onCategorySelected(int index) {
    if (_selectedCategoryIndex == index) return;
    HapticFeedback.lightImpact();
    setState(() {
      _selectedCategoryIndex = index;
      _filterQuery = '';
      _searchController.clear();
    });
    _fetchDynamicAlbums(_categories[index].query);
  }

  void _onSearchChanged(String val) {
    setState(() => _filterQuery = val.trim());
    _searchDebounce?.cancel();
    if (val.trim().length >= 3) {
      _searchDebounce = Timer(const Duration(milliseconds: 600), () {
        _fetchDynamicAlbums(val.trim());
      });
    } else if (val.trim().isEmpty) {
      _fetchDynamicAlbums(_categories[_selectedCategoryIndex].query);
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

    // If User Selected "My Records" chip, only show user playlists & curated records
    if (_categories[_selectedCategoryIndex].query == '__playlists__') {
      if (albums.isEmpty) {
        albums.addAll(_getCuratedFallbackAlbums());
      }
      return albums;
    }

    // 2. Dynamic Catalog Albums from API
    if (_dynamicAlbums.isNotEmpty) {
      albums.addAll(_dynamicAlbums);
    } else {
      // Curated Fallbacks if API request is pending or offline
      albums.addAll(_getCuratedFallbackAlbums());
    }

    if (_filterQuery.isEmpty) return albums;
    final q = _filterQuery.toLowerCase();
    return albums.where((a) => a.title.toLowerCase().contains(q) || a.artist.toLowerCase().contains(q)).toList();
  }

  List<AlbumData> _getCuratedFallbackAlbums() {
    return [
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
        coverUrl: 'https://i.ytimg.com/vi/yKNxeF4KMsY/hqdefault.jpg',
        trackCount: CuratedTracks.chillTracks.length,
        tracks: CuratedTracks.chillTracks,
      ),
      AlbumData(
        id: 'curated_trending',
        title: 'Top Hits Billboard 2026',
        artist: 'Trending Chartbusters',
        coverUrl: 'https://i.ytimg.com/vi/RLzC55ai0eo/hqdefault.jpg',
        trackCount: CuratedTracks.trendingTracks.length,
        tracks: CuratedTracks.trendingTracks,
      ),
      AlbumData(
        id: 'curated_workout',
        title: 'High Energy Cardio & Bass',
        artist: 'Workout Motivation',
        coverUrl: 'https://c.saavncdn.com/973/Brown-Munde-English-2020-20260520131422-500x500.jpg',
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
    ];
  }

  Future<List<YoutubeTrack>> _loadAlbumTracks(AlbumData album, AudioProvider audio) async {
    List<YoutubeTrack> tracks = List.from(album.tracks);

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

    return tracks;
  }

  void _quickPlayAlbum(AlbumData album, AudioProvider audio) async {
    HapticFeedback.mediumImpact();
    final tracks = await _loadAlbumTracks(album, audio);
    if (tracks.isNotEmpty && mounted) {
      audio.playTrack(tracks.first, tracks);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playing album: ${album.title}'),
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.surface2,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openAlbumDetails(AlbumData album, AudioProvider audio) async {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return FutureBuilder<List<YoutubeTrack>>(
          future: _loadAlbumTracks(album, audio),
          builder: (context, snapshot) {
            final tracks = snapshot.data ?? album.tracks;
            final effectiveCover = album.coverUrl.trim().isNotEmpty
                ? album.coverUrl
                : (tracks.isNotEmpty ? tracks.first.thumbnailUrl : '');

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.82,
              minChildSize: 0.5,
              maxChildSize: 0.96,
              builder: (_, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF13111C),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border.all(color: AppColors.cardBorder, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 36,
                        spreadRadius: 4,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      // Frosted Pill Handle
                      Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Deluxe Header with Artwork & Vinyl Disc Effect
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Vinyl Sleeve Assembly
                            Stack(
                              alignment: Alignment.centerLeft,
                              clipBehavior: Clip.none,
                              children: [
                                // Grooved Vinyl Disc Peeking Behind
                                Positioned(
                                  right: -24,
                                  child: Container(
                                    width: 104,
                                    height: 104,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const RadialGradient(
                                        colors: [
                                          Color(0xFF282535),
                                          Color(0xFF0F0E14),
                                          Color(0xFF282535),
                                          Color(0xFF09080D),
                                        ],
                                        stops: [0.0, 0.45, 0.75, 1.0],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.6),
                                          blurRadius: 10,
                                          offset: const Offset(4, 2),
                                        ),
                                      ],
                                      border: Border.all(color: const Color(0xFF38334A), width: 1.5),
                                    ),
                                    alignment: Alignment.center,
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [AppColors.primary, AppColors.pinkAccent],
                                        ),
                                        border: Border.all(color: Colors.black, width: 2),
                                      ),
                                    ),
                                  ),
                                ),
                                // Album Cover Box
                                Container(
                                  width: 108,
                                  height: 108,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.5),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.3),
                                        blurRadius: 20,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: AppArtworkImage(
                                      key: ValueKey('album_modal_${album.id}'),
                                      trackId: album.id,
                                      imageUrl: effectiveCover,
                                      title: album.title,
                                      artist: album.artist,
                                      width: 108,
                                      height: 108,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 44),

                            // Title & High-Res Metadata
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentTeal.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.accentTeal.withValues(alpha: 0.4), width: 0.8),
                                    ),
                                    child: const Text(
                                      'STUDIO MASTER • LOSSLESS',
                                      style: TextStyle(
                                        color: AppColors.accentTeal,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    album.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.h2.copyWith(fontSize: 17, height: 1.2),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    album.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    snapshot.connectionState == ConnectionState.waiting
                                        ? 'Fetching master tracks...'
                                        : '${tracks.length} tracks • 320kbps CD Quality',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Deluxe Action Buttons: Play All & Shuffle
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: tracks.isNotEmpty
                                    ? () {
                                        Navigator.of(ctx).pop();
                                        audio.playTrack(tracks.first, tracks);
                                      }
                                    : null,
                                child: Container(
                                  height: 46,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [AppColors.primary, AppColors.swarvaViolet],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.45),
                                        blurRadius: 14,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                                      SizedBox(width: 6),
                                      Text(
                                        'Play All',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: tracks.isNotEmpty
                                    ? () {
                                        Navigator.of(ctx).pop();
                                        final shuffled = List<YoutubeTrack>.from(tracks)..shuffle();
                                        audio.playTrack(shuffled.first, shuffled);
                                      }
                                    : null,
                                child: Container(
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: AppColors.surface2,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.cardBorder, width: 1.2),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.shuffle_rounded, color: Colors.white.withValues(alpha: 0.9), size: 20),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Shuffle',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.9),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),

                      // Tracks List
                      Expanded(
                        child: snapshot.connectionState == ConnectionState.waiting
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const CircularProgressIndicator(color: AppColors.primarySoft, strokeWidth: 2.5),
                                    const SizedBox(height: 14),
                                    Text(
                                      'Loading lossless tracklist...',
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                                    ),
                                  ],
                                ),
                              )
                            : tracks.isEmpty
                                ? Center(
                                    child: Text(
                                      'No tracks available for this album.',
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                                    ),
                                  )
                                : ListView.separated(
                                    controller: scrollController,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    itemCount: tracks.length,
                                    separatorBuilder: (_, __) => Divider(
                                      color: Colors.white.withValues(alpha: 0.04),
                                      height: 1,
                                    ),
                                    itemBuilder: (_, i) {
                                      final track = tracks[i];
                                      final isPlayingThis = audio.currentTrack?.id == track.id;

                                      return ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        leading: SizedBox(
                                          width: 32,
                                          alignment: Alignment.center,
                                          child: isPlayingThis
                                              ? const Icon(Icons.equalizer_rounded, color: AppColors.accentTeal, size: 22)
                                              : Text(
                                                  '${i + 1}'.padLeft(2, '0'),
                                                  style: TextStyle(
                                                    color: Colors.white.withValues(alpha: 0.35),
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                        ),
                                        title: Text(
                                          track.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: isPlayingThis ? AppColors.accentTeal : Colors.white,
                                            fontWeight: isPlayingThis ? FontWeight.bold : FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                        subtitle: Text(
                                          track.artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.45),
                                            fontSize: 12,
                                          ),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (track.durationSeconds > 0)
                                              Text(
                                                '${(track.durationSeconds ~/ 60)}:${(track.durationSeconds % 60).toString().padLeft(2, '0')}',
                                                style: TextStyle(
                                                  color: Colors.white.withValues(alpha: 0.35),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: Icon(
                                                isPlayingThis && audio.isPlaying
                                                    ? Icons.pause_circle_filled_rounded
                                                    : Icons.play_circle_fill_rounded,
                                                color: isPlayingThis ? AppColors.accentTeal : AppColors.primarySoft,
                                                size: 28,
                                              ),
                                              onPressed: () {
                                                Navigator.of(ctx).pop();
                                                audio.playTrack(track, tracks);
                                              },
                                            ),
                                          ],
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
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Spotlight Hero Banner showcasing top trending album
  Widget _buildSpotlightHero(BuildContext context, AlbumData heroAlbum, AudioProvider audio) {
    final effectiveCover = heroAlbum.coverUrl.trim().isNotEmpty
        ? heroAlbum.coverUrl
        : (heroAlbum.tracks.isNotEmpty ? heroAlbum.tracks.first.thumbnailUrl : '');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 168,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF26183C),
            Color(0xFF141022),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.primarySoft.withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background Atmosphere Blur Circles
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.18),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Vinyl Sleeve with Grooved Vinyl disc
                Stack(
                  alignment: Alignment.centerLeft,
                  clipBehavior: Clip.none,
                  children: [
                    // Grooved Vinyl Edge
                    Positioned(
                      right: -16,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [
                              Color(0xFF282535),
                              Color(0xFF0F0E14),
                              Color(0xFF282535),
                              Color(0xFF09080D),
                            ],
                            stops: [0.0, 0.45, 0.75, 1.0],
                          ),
                          border: Border.all(color: const Color(0xFF38334A), width: 1.2),
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.swarvaCoral],
                            ),
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                        ),
                      ),
                    ),
                    // Album Cover
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AppArtworkImage(
                          key: ValueKey('hero_spotlight_${heroAlbum.id}'),
                          trackId: heroAlbum.id,
                          imageUrl: effectiveCover,
                          title: heroAlbum.title,
                          artist: heroAlbum.artist,
                          width: 104,
                          height: 104,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 32),

                // Metadata & Quick Actions
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.swarvaCoral.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.swarvaCoral.withValues(alpha: 0.5), width: 0.8),
                            ),
                            child: const Text(
                              '★ SPOTLIGHT',
                              style: TextStyle(
                                color: AppColors.swarvaCoral,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentTeal.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'HI-RES',
                              style: TextStyle(
                                color: AppColors.accentTeal,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        heroAlbum.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        heroAlbum.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _quickPlayAlbum(heroAlbum, audio),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.primary, AppColors.pinkAccent],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                                  SizedBox(width: 4),
                                  Text(
                                    'Play Now',
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _openAlbumDetails(heroAlbum, audio),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                              ),
                              child: const Text(
                                'View',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Category filter pills row
  Widget _buildCategoryPills() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final isSelected = _selectedCategoryIndex == i;

          return GestureDetector(
            onTap: () => _onCategorySelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [AppColors.primary, AppColors.swarvaViolet],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : AppColors.surface1,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primarySoft : AppColors.cardBorder,
                  width: isSelected ? 1.2 : 0.8,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(cat.icon, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(
                    cat.label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Shimmer Skeleton cards displayed while loading
  Widget _buildSkeletonGrid(double cardWidth) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 18,
        childAspectRatio: cardWidth / (cardWidth + 72),
      ),
      itemCount: 4,
      itemBuilder: (_, __) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: cardWidth,
                width: cardWidth,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: const Center(
                  child: Icon(Icons.album_rounded, color: Colors.white12, size: 40),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: cardWidth * 0.7,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: cardWidth * 0.45,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Collector's Edition Vinyl Album Card with Quick-Play overlay
  Widget _buildAlbumCard(BuildContext context, AlbumData album, double cardWidth) {
    final audio = context.read<AudioProvider>();
    final effectiveCover = album.coverUrl.trim().isNotEmpty
        ? album.coverUrl
        : (album.tracks.isNotEmpty ? album.tracks.first.thumbnailUrl : '');

    return GestureDetector(
      key: ValueKey('album_card_${album.id}'),
      onTap: () => _openAlbumDetails(album, audio),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.8), width: 1.1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artwork Box with Vinyl Edge Accent & Quick-Play Overlay
            Stack(
              children: [
                SizedBox(
                  width: cardWidth,
                  height: cardWidth,
                  child: AppArtworkImage(
                    key: ValueKey('album_cover_${album.id}'),
                    trackId: album.id,
                    imageUrl: effectiveCover,
                    title: album.title,
                    artist: album.artist,
                    width: cardWidth,
                    height: cardWidth,
                    fit: BoxFit.cover,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                ),

                // Top-Left Hi-Res Badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: AppColors.accentTeal.withValues(alpha: 0.5), width: 0.6),
                    ),
                    child: const Text(
                      'HI-RES',
                      style: TextStyle(
                        color: AppColors.accentTeal,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                // Floating Glassmorphism Quick-Play Button
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _quickPlayAlbum(album, audio),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.pinkAccent],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ],
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.2),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Metadata
            SizedBox(
              height: 72,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      album.title.isNotEmpty ? album.title : 'Unknown Album',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      album.artist.isNotEmpty ? album.artist : 'Various Artists',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.graphic_eq_rounded, color: AppColors.accentTeal, size: 11),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            album.trackCount > 0 ? '${album.trackCount} tracks • Lossless' : 'Lossless CD Audio',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.accentTeal,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();
    final albums = _getAlbums(audio);
    final bottomInset = 72.0 + 64.0 + MediaQuery.of(context).padding.bottom + 28.0;
    final AlbumData? heroAlbum = albums.isNotEmpty ? albums.first : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(0, 16, 0, bottomInset),
          children: [
            // Top Bar with Liquid Gradient Icon & Profile
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.pinkAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.album_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Albums & Records',
                              style: AppTextStyles.h1.copyWith(fontSize: 20, letterSpacing: -0.3),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accentTeal.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'HI-RES',
                                style: TextStyle(
                                  color: AppColors.accentTeal,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Curated discographies & master records',
                          style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const AppProfileAvatar(),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Search Bar with Frosted Glass Border
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Search master albums, artists or vinyl records...',
                    hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primarySoft, size: 22),
                    suffixIcon: _filterQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, color: AppColors.iconIdle, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : (_isLoadingDynamicAlbums
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primarySoft),
                                ),
                              )
                            : null),
                    filled: true,
                    fillColor: AppColors.surface1,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      borderSide: const BorderSide(color: AppColors.primarySoft, width: 1.4),
                    ),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Genre & Mood Filter Pills
            _buildCategoryPills(),
            const SizedBox(height: 8),

            // Spotlight Hero Showcase (Shown when not searching and albums available)
            if (_filterQuery.isEmpty && heroAlbum != null && !_isLoadingDynamicAlbums)
              _buildSpotlightHero(context, heroAlbum, audio),

            // Section Subheader
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
              child: Row(
                children: [
                  Text(
                    _filterQuery.isNotEmpty
                        ? 'Search Results'
                        : '${_categories[_selectedCategoryIndex].label} Albums',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  if (albums.isNotEmpty)
                    Text(
                      '${albums.length} records',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11.5,
                      ),
                    ),
                ],
              ),
            ),

            // Grid of Albums or Shimmer Loading
            LayoutBuilder(
              builder: (context, constraints) {
                final double screenWidth = MediaQuery.of(context).size.width;
                final double safeWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : screenWidth;
                // 2-column grid with 16px outer padding and 14px cross-axis spacing
                final double cardWidth = ((safeWidth - 46) / 2).clamp(120.0, 260.0);

                if (_isLoadingDynamicAlbums && albums.isEmpty) {
                  return _buildSkeletonGrid(cardWidth);
                }

                // If hero album is shown, display the remaining albums in grid
                final gridAlbums = (_filterQuery.isEmpty && heroAlbum != null && albums.length > 1)
                    ? albums.sublist(1)
                    : albums;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 18,
                    childAspectRatio: cardWidth / (cardWidth + 72),
                  ),
                  itemCount: gridAlbums.length,
                  itemBuilder: (context, index) {
                    final album = gridAlbums[index];
                    return _buildAlbumCard(context, album, cardWidth);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
