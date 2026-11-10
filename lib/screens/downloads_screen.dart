import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/audio_provider.dart';
import '../core/services/audio_cache_service.dart';
import '../core/services/curated_tracks.dart';
import '../features/music/models/music_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<String> _cachedTrackIds = [];
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
    if (mounted) {
      setState(() {
        _cachedTrackIds = ids;
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
    final audioProvider = context.watch<AudioProvider>();

    // Match cached IDs with our curated catalog
    final allTracks = [
      ...CuratedTracks.jumpBackInTracks,
      ...CuratedTracks.trendingTracks,
      ...CuratedTracks.madeForYouTracks,
    ];

    final downloadedTracks = allTracks.where(
      (t) => _cachedTrackIds.contains(t.id),
    ).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Offline Vault',
                    style: AppTextStyles.h1.copyWith(fontSize: 26),
                  ),
                  if (_cachedTrackIds.isNotEmpty)
                    TextButton.icon(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.sunsetPink,
                        size: 20,
                      ),
                      label: Text(
                        'Clear',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.sunsetPink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        await AudioCacheService.clearCache();
                        _loadCacheInfo();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // Storage Info Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: AppRadii.borderMedium,
                  border: Border.all(
                    color: AppColors.primarySoft.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.offline_pin_rounded,
                      color: AppColors.primarySoft,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_cachedTrackIds.length} Songs Downloaded • ${_formatBytes(_cacheSizeBytes)} of Cache',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Track List or Empty State
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primarySoft,
                          ),
                        ),
                      )
                    : downloadedTracks.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            itemCount: downloadedTracks.length,
                            itemBuilder: (context, index) {
                              final track = downloadedTracks[index];
                              final isCurrent =
                                  audioProvider.currentTrack?.id == track.id;

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
                                      fontWeight: isCurrent
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${track.artist} • 0ms Direct Disk Audio',
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
                                      downloadedTracks,
                                    );
                                  },
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
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
            decoration: BoxDecoration(
              color: AppColors.surface1,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.download_for_offline_outlined,
              size: 36,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Offline Songs Yet',
            style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap the download icon on any track to save it\nfor instant offline listening with zero internet',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
