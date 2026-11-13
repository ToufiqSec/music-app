import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/audio_provider.dart';
import '../providers/auth_provider.dart';
import '../features/music/models/music_models.dart';
import '../widgets/app_search_field.dart';
import '../widgets/generated_cover_art.dart';
import '../core/services/search_cache_store.dart';
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
  bool _isShowingCached = false;
  bool _isOfflineNotice = false;

  // Real Dynamic Mood Chips (Global Rule 2: App's own categorization layer)
  final List<String> _quickCategories = [
    'Trending',
    'Chill',
    'Lo-Fi',
    'Midnight',
    'Romance',
    'Acoustic',
    'Bollywood',
    'EDM',
    'Workout',
    'Focus',
  ];
  String? _selectedCategory;
  int _selectedFilterIndex = 0;
  final List<String> _contentFilterTabs = [
    'All',
    'Songs',
    'Shows & Drama',
    'Podcasts',
    'Audiobooks',
    'Videos',
  ];

  List<YoutubeTrack> get _filteredResults {
    if (_selectedFilterIndex == 0) return _searchResults;
    return _searchResults.where((track) {
      final type = AudioTypeDetector.detect(track.title, track.artist, track.durationSeconds);
      switch (_selectedFilterIndex) {
        case 1: // Songs
          return type == AudioContentType.song;
        case 2: // Shows & Drama
          return type == AudioContentType.show;
        case 3: // Podcasts
          return type == AudioContentType.podcast;
        case 4: // Audiobooks
          return type == AudioContentType.audiobook;
        case 5: // Videos
          return track.thumbnailUrl.contains('ytimg.com') || track.thumbnailUrl.contains('youtube.com');
        default:
          return true;
      }
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    SearchCacheStore.init().then((_) {
      if (mounted) setState(() {});
    });
  }

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

  /// Executes live search with multi-tier cache check & quiet background refresh
  Future<void> _executeSearch(String query, {bool isMood = false}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _lastQuery = '';
        _searchResults = [];
        _errorMessage = '';
        _isSearching = false;
        _selectedCategory = null;
        _isShowingCached = false;
        _isOfflineNotice = false;
      });
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final cacheHours = authProvider.settings.searchCacheHours;

    final targetQuery = isMood
        ? (SearchCacheStore.moodQueryMap[trimmed] ?? trimmed)
        : trimmed;

    setState(() {
      _lastQuery = trimmed;
      _isSearching = true;
      _errorMessage = '';
      _isOfflineNotice = false;
    });

    // 1. Check local persistent cache first (<5ms instant response)
    final cached = SearchCacheStore.getCached(targetQuery);
    if (cached != null && cached.tracks.isNotEmpty) {
      setState(() {
        _searchResults = cached.tracks;
        _isShowingCached = true;
        _isSearching = false;
      });

      // If cache is still within validity period, we are done
      if (!cached.isExpired(cacheHours)) {
        return;
      }
      // If expired, continue to background quiet refresh
    }

    // 2. Query Music Service (JioSaavn + YouTube Live Pipeline)
    try {
      final audioProvider = context.read<AudioProvider>();
      final results = await audioProvider.musicService.searchTracks(targetQuery);

      if (results.isNotEmpty) {
        // Update persistent cache
        await SearchCacheStore.putCached(targetQuery, results);
      }

      if (mounted) {
        setState(() {
          if (results.isNotEmpty || _searchResults.isEmpty) {
            _searchResults = results;
          }
          _isSearching = false;
          _isShowingCached = false;
          _isOfflineNotice = false;
        });

        if (!isMood && results.isNotEmpty) {
          SearchCacheStore.addRecentSearch(trimmed);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          if (_searchResults.isNotEmpty) {
            // Keep showing cached results with offline hint
            _isOfflineNotice = true;
            _errorMessage = '';
          } else {
            _errorMessage = 'Network offline. Showing available offline vault.';
          }
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
    final hasActiveQuery = _searchController.text.trim().isNotEmpty || _selectedCategory != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Search Input Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: AppSearchField(
                controller: _searchController,
                placeholder: 'Search songs, artists, or genres...',
                onChanged: (q) {
                  setState(() => _selectedCategory = null);
                  _onQueryChanged(q);
                },
              ),
            ),

            // 2. Real Working Mood Chips (Live categorized queries)
            SizedBox(
              height: 44,
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
                      setState(() {
                        _selectedCategory = cat;
                        _searchController.clear();
                      });
                      _executeSearch(cat, isMood: true);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [AppColors.primary, AppColors.primarySoft],
                              )
                            : null,
                        color: isSelected ? null : AppColors.surface1,
                        borderRadius: AppRadii.borderPill,
                        border: Border.all(
                          color: isSelected ? AppColors.primarySoft : AppColors.surface2,
                          width: 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        cat,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // 3. Content Type Filter Tabs (Issue 6 Part A) - Visible when searching
            if (hasActiveQuery && _searchResults.isNotEmpty)
              Container(
                height: 38,
                margin: const EdgeInsets.only(bottom: 6),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _contentFilterTabs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, idx) {
                    final tab = _contentFilterTabs[idx];
                    final isSelected = idx == _selectedFilterIndex;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedFilterIndex = idx);
                        if (idx > 0 && _lastQuery.trim().isNotEmpty) {
                          final currentFiltered = _filteredResults;
                          if (currentFiltered.isEmpty) {
                            final tabKeyword = tab.toLowerCase().replaceAll('&', '').trim();
                            _executeSearch('$_lastQuery $tabKeyword');
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primarySoft.withValues(alpha: 0.25) : AppColors.surface1,
                          borderRadius: AppRadii.borderPill,
                          border: Border.all(
                            color: isSelected ? AppColors.primarySoft : AppColors.surface2,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          tab,
                          style: AppTextStyles.caption.copyWith(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // 4. Offline / Cached status subtle banner
            if (_isOfflineNotice)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: AppRadii.borderSmall,
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: AppColors.warning, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Offline Mode • Showing cached results',
                      style: AppTextStyles.meta.copyWith(color: AppColors.warning),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 6),

            // 4. Main Body: Results or Rich Empty State
            Expanded(
              child: _isSearching && _searchResults.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primarySoft),
                    )
                  : !hasActiveQuery
                      ? _buildRichEmptyState(audioProvider)
                      : _searchResults.isEmpty
                          ? Center(
                              child: Text(
                                _errorMessage.isNotEmpty ? _errorMessage : 'No matching tracks found.',
                                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                              ),
                            )
                          : _buildResultsList(audioProvider),
            ),
          ],
        ),
      ),
    );
  }

  /// Results list with 160 bottom padding to avoid floating nav bar
  Widget _buildResultsList(AudioProvider audioProvider) {
    final list = _filteredResults;
    if (list.isEmpty) {
      final tabName = _contentFilterTabs[_selectedFilterIndex];
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 48,
                color: AppColors.iconIdle.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 12),
              Text(
                'No items found in $tabName tab.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
              if (_lastQuery.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surface2,
                    foregroundColor: AppColors.primarySoft,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    side: BorderSide(color: AppColors.primarySoft.withValues(alpha: 0.5)),
                  ),
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: Text('Search "$_lastQuery $tabName"'),
                  onPressed: () {
                    final tabKeyword = tabName.toLowerCase().replaceAll('&', '').trim();
                    _executeSearch('$_lastQuery $tabKeyword');
                  },
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: 160,
      ),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final track = list[index];
        final type = AudioTypeDetector.detect(track.title, track.artist, track.durationSeconds);

        return Selector<AudioProvider, (bool, bool)>(
          selector: (_, ap) => (
            ap.currentTrack?.id == track.id,
            ap.isPlaying,
          ),
          builder: (context, state, child) {
            final (isCurrent, isPlaying) = state;

            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: AppRadii.borderMedium,
                border: Border.all(
                  color: isCurrent
                      ? AppColors.primarySoft.withValues(alpha: 0.7)
                      : AppColors.surface2,
                  width: 1,
                ),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
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
                    fontWeight: FontWeight.w600,
                    color: isCurrent ? AppColors.primarySoft : AppColors.textPrimary,
                  ),
                ),
                subtitle: Row(
                  children: [
                    if (type != AudioContentType.song) ...[
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft.withValues(alpha: 0.2),
                          borderRadius: AppRadii.borderSmall,
                        ),
                        child: Text(
                          AudioTypeDetector.getBadgeText(type),
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primarySoft,
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        '${track.artist} • ${_formatDuration(track.durationSeconds)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
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
                            behavior: SnackBarBehavior.floating,
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
                  if (_searchController.text.trim().isNotEmpty) {
                    SearchCacheStore.addRecentSearch(_searchController.text.trim());
                  }
                  audioProvider.playTrack(track, _searchResults);
                },
              ),
            );
          },
        );
      },
    );
  }

  /// Rich Empty State: Displays Recent Searches & Account Recommendations (Issue 3)
  Widget _buildRichEmptyState(AudioProvider audio) {
    final recent = SearchCacheStore.getRecentSearches();
    final history = audio.historyTracks;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 160),
      children: [
        // 1. Recent Searches Section
        if (recent.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: AppTextStyles.sectionTitle.copyWith(fontSize: 16),
              ),
              TextButton(
                onPressed: () async {
                  await SearchCacheStore.clearRecentSearches();
                  setState(() {});
                },
                child: Text(
                  'Clear All',
                  style: AppTextStyles.meta.copyWith(color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: recent.map((query) {
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: AppRadii.borderPill,
                  border: Border.all(color: AppColors.surface2),
                ),
                child: InkWell(
                  borderRadius: AppRadii.borderPill,
                  onTap: () {
                    _searchController.text = query;
                    _executeSearch(query);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history_rounded, size: 14, color: AppColors.iconIdle),
                        const SizedBox(width: 6),
                        Text(
                          query,
                          style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () async {
                            await SearchCacheStore.removeRecentSearch(query);
                            setState(() {});
                          },
                          child: const Icon(Icons.close_rounded, size: 14, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],

        // 2. Taste-Based Recommendations Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recommended for You',
              style: AppTextStyles.sectionTitle.copyWith(fontSize: 16),
            ),
            const Icon(Icons.auto_awesome_rounded, color: AppColors.primarySoft, size: 18),
          ],
        ),
        const SizedBox(height: 12),

        if (history.isNotEmpty)
          ...history.take(6).map((track) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: AppRadii.borderMedium,
                border: Border.all(color: AppColors.surface2),
              ),
              child: ListTile(
                dense: true,
                leading: ClipRRect(
                  borderRadius: AppRadii.borderSmall,
                  child: track.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: track.thumbnailUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => GeneratedCoverArt(
                            title: track.title,
                            artist: track.artist,
                            thumbnailUrl: track.thumbnailUrl,
                            durationSeconds: track.durationSeconds,
                            size: 40,
                            borderRadius: AppRadii.borderSmall,
                          ),
                        )
                      : GeneratedCoverArt(
                          title: track.title,
                          artist: track.artist,
                          thumbnailUrl: track.thumbnailUrl,
                          durationSeconds: track.durationSeconds,
                          size: 40,
                          borderRadius: AppRadii.borderSmall,
                        ),
                ),
                title: Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
                trailing: const Icon(Icons.play_arrow_rounded, color: AppColors.primarySoft),
                onTap: () => audio.playTrack(track),
              ),
            );
          })
        else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: AppRadii.borderLarge,
              border: Border.all(color: AppColors.surface2),
            ),
            child: Column(
              children: [
                const Icon(Icons.headphones_rounded, color: AppColors.primarySoft, size: 36),
                const SizedBox(height: 10),
                Text(
                  'Start Listening to Build Your Taste',
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap any mood above or search an artist to discover personalized high-res music.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
      ],
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
}
