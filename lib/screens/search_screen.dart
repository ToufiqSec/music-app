import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/audio_provider.dart';
import '../features/music/models/music_models.dart';
import '../widgets/app_search_field.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_shadows.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  bool _isSearching = false;
  String _lastQuery = '';
  List<YoutubeTrack> _searchResults = [];
  String _errorMessage = '';

  // Quick Chips
  final List<String> _quickCategories = [
    'Trending',
    'Romance',
    'Lo-Fi',
    'Acoustic',
    'Chill',
    'Bollywood',
    'EDM',
    'Workout',
  ];
  String? _selectedCategory;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    if (query == _lastQuery) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _executeSearch(query);
    });
  }

  Future<void> _executeSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _lastQuery = '';
        _searchResults = [];
        _errorMessage = '';
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _lastQuery = trimmed;
      _isSearching = true;
      _errorMessage = '';
    });

    try {
      final audioProvider = context.read<AudioProvider>();
      final results = await audioProvider.musicService.searchTracks(trimmed);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = 'Failed to find tracks. Check your network.';
        });
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
    final audioProvider = context.read<AudioProvider>();

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
                          color: isSelected ? AppColors.primarySoft : AppColors.surface2,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // Results / Empty / Loading State
            Expanded(
              child: _isSearching
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primarySoft),
                    )
                  : _errorMessage.isNotEmpty
                      ? Center(
                          child: Text(
                            _errorMessage,
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                          ),
                        )
                      : _searchResults.isEmpty
                          ? _buildEmptyState()
                          : ListView.separated(
                              padding: const EdgeInsets.only(
                                left: 16,
                                right: 16,
                                top: 8,
                                bottom: 160, // Prevents MiniPlayer from obscuring bottom songs
                              ),
                              itemCount: _searchResults.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final track = _searchResults[index];

                                return Selector<AudioProvider, (bool, bool)>(
                                  selector: (_, ap) => (
                                    ap.currentTrack?.id == track.id,
                                    ap.isPlaying,
                                  ),
                                  builder: (context, state, child) {
                                    final (isCurrent, isPlaying) = state;

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.surface1.withValues(alpha: 0.7),
                                        borderRadius: AppRadii.borderMedium,
                                        border: isCurrent
                                            ? Border.all(color: AppColors.primarySoft.withValues(alpha: 0.6))
                                            : null,
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        leading: ClipRRect(
                                          borderRadius: AppRadii.borderSmall,
                                          child: track.thumbnailUrl.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: track.thumbnailUrl,
                                                  width: 48,
                                                  height: 48,
                                                  fit: BoxFit.cover,
                                                  errorWidget: (_, __, ___) => _buildFallbackThumbnail(),
                                                )
                                              : _buildFallbackThumbnail(),
                                        ),
                                        title: Text(
                                          track.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.bodyMedium.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: isCurrent ? AppColors.primarySoft : AppColors.textPrimary,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${track.artist} • ${_formatDuration(track.durationSeconds)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
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
                                                audioProvider.downloadTrackForOffline(track);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Downloading "${track.title}" to Offline Vault',
                                                      style: AppTextStyles.bodySmall,
                                                    ),
                                                    backgroundColor: AppColors.surface1,
                                                    duration: const Duration(seconds: 2),
                                                  ),
                                                );
                                              },
                                            ),
                                            Icon(
                                              isCurrent && isPlaying
                                                  ? Icons.pause_circle_filled_rounded
                                                  : Icons.play_circle_fill_rounded,
                                              size: 32,
                                              color: isCurrent ? AppColors.primarySoft : AppColors.iconIdle,
                                            ),
                                          ],
                                        ),
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          audioProvider.playTrack(track, _searchResults);
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
    );
  }

  Widget _buildFallbackThumbnail() {
    return Container(
      width: 48,
      height: 48,
      color: AppColors.surface2,
      child: const Icon(Icons.music_note_rounded, color: AppColors.primarySoft),
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
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
