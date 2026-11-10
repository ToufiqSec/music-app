import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/audio_provider.dart';
import '../features/music/models/music_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_shadows.dart';
import '../widgets/app_search_field.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<YoutubeTrack> _searchResults = [];
  bool _isLoading = false;
  String _selectedCategory = 'Trending';
  Timer? _debounceTimer;

  final List<String> _quickCategories = [
    'Trending',
    'Lo-Fi',
    'Romance',
    'Acoustic',
    'Hip Hop',
    'Chillout',
    'Electronic',
    'Rock',
  ];

  @override
  void initState() {
    super.initState();
    // Initial fetch for the default category
    _executeSearch('Top Trending Songs');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _executeSearch(query);
    });
  }

  Future<void> _executeSearch(String query) async {
    setState(() => _isLoading = true);
    try {
      final musicService = context.read<AudioProvider>().musicService;
      final results = await musicService.searchTracks(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.watch<AudioProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: AppSearchField(
                controller: _searchController,
                placeholder: 'Search songs, artists, or genres...',
                onChanged: _onQueryChanged,
              ),
            ),

            // Quick Category Chips
            SizedBox(
              height: 46,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                scrollDirection: Axis.horizontal,
                itemCount: _quickCategories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _quickCategories[index];
                  final isSelected = cat == _selectedCategory;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategory = cat);
                      _searchController.text = cat;
                      _executeSearch(cat);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primarySoft : AppColors.surface1,
                        borderRadius: AppRadii.borderPill,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primarySoft
                              : AppColors.surface2,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isSelected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // Main Results or Loading State
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primarySoft,
                        ),
                      ),
                    )
                  : _searchResults.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final track = _searchResults[index];
                            final isPlayingCurrent =
                                audioProvider.currentTrack?.id == track.id;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isPlayingCurrent
                                    ? AppColors.surface2
                                    : AppColors.surface1.withValues(alpha: 0.6),
                                borderRadius: AppRadii.borderMedium,
                                border: Border.all(
                                  color: isPlayingCurrent
                                      ? AppColors.primarySoft.withValues(alpha: 0.4)
                                      : Colors.transparent,
                                  width: 1,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                leading: ClipRRect(
                                  borderRadius: AppRadii.borderSmall,
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    color: AppColors.surface2,
                                    child: track.thumbnailUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: track.thumbnailUrl,
                                            fit: BoxFit.cover,
                                            memCacheWidth: 120,
                                            errorWidget: (_, __, ___) =>
                                                const Icon(
                                              Icons.music_note,
                                              color: AppColors.primarySoft,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.music_note,
                                            color: AppColors.primarySoft,
                                          ),
                                  ),
                                ),
                                title: Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: isPlayingCurrent
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isPlayingCurrent
                                        ? AppColors.primarySoft
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  '${track.artist} • ${_formatDuration(track.durationSeconds)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.download_rounded,
                                        size: 20,
                                        color: AppColors.iconIdle,
                                      ),
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        audioProvider
                                            .downloadTrackForOffline(track);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Downloading "${track.title}" for offline playback',
                                              style: AppTextStyles.bodySmall,
                                            ),
                                            backgroundColor: AppColors.surface1,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                    ),
                                    Icon(
                                      isPlayingCurrent && audioProvider.isPlaying
                                          ? Icons.pause_circle_filled_rounded
                                          : Icons.play_circle_fill_rounded,
                                      size: 32,
                                      color: isPlayingCurrent
                                          ? AppColors.primarySoft
                                          : AppColors.iconIdle,
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  audioProvider.playTrack(
                                    track,
                                    _searchResults,
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
              boxShadow: const [AppShadows.shadowSoft],
            ),
            child: const Icon(
              Icons.search_rounded,
              size: 36,
              color: AppColors.primarySoft,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Explore High-Resolution Audio',
            style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Search over 100M+ ad-free tracks with instant streaming',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
