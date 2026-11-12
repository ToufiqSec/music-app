import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/audio_provider.dart';
import '../core/services/audio_cache_service.dart';
import '../core/services/track_metadata_store.dart';
import '../core/services/curated_tracks.dart';
import '../features/music/models/music_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../widgets/generated_cover_art.dart';
import '../widgets/twilight_scene_background.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<YoutubeTrack> _downloadedTracks = [];
  int _cacheSizeBytes = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCacheInfo();
  }

  Future<void> _loadCacheInfo() async {
    setState(() => _isLoading = true);
    final ids = await AudioCacheService.getCachedTrackIds();
    final size = await AudioCacheService.getCacheSizeBytes();

    // 1. Check metadata store for dynamically downloaded songs (Search, Playlists, etc.)
    final allSaved = await TrackMetadataStore.getAllSavedTracks();
    final savedMap = {for (final t in allSaved) t.id: t};

    // 2. Check Curated catalog
    final curatedList = [
      ...CuratedTracks.jumpBackInTracks,
      ...CuratedTracks.trendingTracks,
      ...CuratedTracks.madeForYouTracks,
    ];
    for (final t in curatedList) {
      savedMap.putIfAbsent(t.id, () => t);
    }

    // 3. Assemble only tracks that exist on disk
    final List<YoutubeTrack> downloaded = [];
    for (final id in ids) {
      if (savedMap.containsKey(id)) {
        downloaded.add(savedMap[id]!);
      } else {
        // Fallback placeholder with track id if metadata file was wiped
        downloaded.add(
          YoutubeTrack(
            id: id,
            title: 'Offline Track $id',
            artist: 'Saved Audio',
            durationSeconds: 180,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _downloadedTracks = downloaded;
        _cacheSizeBytes = size;
        _isLoading = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Offline Vault',
                        style: AppTextStyles.h1.copyWith(fontSize: 26),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Zero-latency, zero-bandwidth playback',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  if (_downloadedTracks.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.iconIdle),
                      onPressed: () => _confirmClearCache(context),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Storage info bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface1.withValues(alpha: 0.7),
                  borderRadius: AppRadii.borderMedium,
                  border: Border.all(color: AppColors.surface2),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft.withValues(alpha: 0.15),
                        borderRadius: AppRadii.borderSmall,
                      ),
                      child: const Icon(
                        Icons.offline_pin_rounded,
                        color: AppColors.primarySoft,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_downloadedTracks.length} Songs Downloaded',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Using ${_formatBytes(_cacheSizeBytes)} of 1 GB Auto-LRU Disk Vault',
                            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Track List
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.primarySoft),
                      )
                    : _downloadedTracks.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 160), // Space for MiniPlayer
                            itemCount: _downloadedTracks.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final track = _downloadedTracks[index];

                              return Selector<AudioProvider, bool>(
                                selector: (_, ap) =>
                                    ap.currentTrack?.id == track.id && ap.isPlaying,
                                builder: (context, isPlayingThis, child) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.surface1.withValues(alpha: 0.6),
                                      borderRadius: AppRadii.borderMedium,
                                      border: isPlayingThis
                                          ? Border.all(color: AppColors.primarySoft.withValues(alpha: 0.5))
                                          : null,
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      leading: ClipRRect(
                                        borderRadius: AppRadii.borderSmall,
                                        child: (track.thumbnailUrl.isNotEmpty &&
                                                !track.thumbnailUrl.contains('hqdefault') &&
                                                !track.thumbnailUrl.contains('mqdefault'))
                                            ? CachedNetworkImage(
                                                imageUrl: track.thumbnailUrl,
                                                width: 48,
                                                height: 48,
                                                fit: BoxFit.cover,
                                                errorWidget: (_, __, ___) => GeneratedCoverArt(
                                                  title: track.title,
                                                  artist: track.artist,
                                                  thumbnailUrl: track.thumbnailUrl,
                                                  durationSeconds: track.durationSeconds,
                                                  size: 48,
                                                  borderRadius: AppRadii.borderSmall,
                                                ),
                                              )
                                            : GeneratedCoverArt(
                                                title: track.title,
                                                artist: track.artist,
                                                thumbnailUrl: track.thumbnailUrl,
                                                durationSeconds: track.durationSeconds,
                                                size: 48,
                                                borderRadius: AppRadii.borderSmall,
                                              ),
                                      ),
                                      title: Text(
                                        track.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.bodyMedium.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: isPlayingThis ? AppColors.primarySoft : AppColors.textPrimary,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${track.artist} • 0ms Local Playback',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                                      ),
                                      trailing: Icon(
                                        isPlayingThis
                                            ? Icons.pause_circle_filled_rounded
                                            : Icons.play_circle_fill_rounded,
                                        color: isPlayingThis ? AppColors.primarySoft : AppColors.iconIdle,
                                        size: 32,
                                      ),
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        audioProvider.playTrack(track, _downloadedTracks);
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.surface1,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.download_for_offline_rounded,
              size: 36,
              color: AppColors.primarySoft,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your Offline Vault is Empty',
            style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Search and tap download on any song to save it for 0ms offline playback.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  void _confirmClearCache(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.borderLarge),
        title: Text('Clear Offline Vault?', style: AppTextStyles.h3),
        content: Text(
          'This will delete all locally cached music files. Songs can be re-streamed or re-downloaded at any time.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTextStyles.bodySmall),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              shape: RoundedRectangleBorder(borderRadius: AppRadii.borderPill),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await AudioCacheService.clearCache();
              _loadCacheInfo();
            },
            child: Text(
              'Clear All',
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
