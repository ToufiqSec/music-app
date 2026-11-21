import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/audio_provider.dart';
import '../core/services/curated_tracks.dart';
import '../features/music/models/music_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_shadows.dart';
import '../theme/app_motion.dart';
import '../widgets/mini_player.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/content_card.dart';
import '../widgets/featured_banner.dart';
import '../widgets/update_dialog.dart';
import '../widgets/twilight_scene_background.dart';
import '../widgets/generated_cover_art.dart';
import '../widgets/cascading_artwork.dart';
import '../core/services/app_update_service.dart';
import 'search_screen.dart';
import 'library_screen.dart';
import 'downloads_screen.dart';
import 'profile_screen.dart';
import 'albums_screen.dart';
import 'artist_onboarding_screen.dart';
import 'mood_hub_screen.dart';
import '../core/services/taste_engine.dart';
import '../core/services/podcast_rss_service.dart';
import '../core/services/home_section_cache_store.dart';
import '../providers/auth_provider.dart';
import '../features/listen_together/widgets/listen_together_button.dart';
import '../core/constants/app_strings.dart';
import '../core/services/greeting_service.dart';
import 'login_screen.dart';

/// Main Discovery Hub and Navigation Shell for Music App.
/// Universal UI Design System: Twilight Calm.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;
  Timer? _periodicUpdateTimer;
  AudioProvider? _audioProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        _audioProvider = context.read<AudioProvider>();
        _audioProvider?.playbackErrorNotifier.addListener(_onPlaybackError);
      }
      await AppUpdateService.getInstalledVersionName();
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        _checkForUpdates(force: false);
      }
      _checkArtistOnboardingOnFirstLaunch();

      // Periodic background check while the app remains open (every 4 hours)
      _periodicUpdateTimer = Timer.periodic(const Duration(hours: 4), (_) {
        _checkForUpdates(force: false);
      });
    });
  }

  void _onPlaybackError() {
    final err = _audioProvider?.playbackErrorNotifier.value;
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err, style: const TextStyle(color: Colors.white, fontSize: 13)),
          backgroundColor: AppColors.surface1,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadii.borderMedium),
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 72.0 + 64.0 + MediaQuery.of(context).padding.bottom + 12.0,
          ),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            textColor: AppColors.primarySoft,
            onPressed: () {
              _audioProvider?.retryCurrentTrack();
            },
          ),
        ),
      );
    }
  }

  Future<void> _checkArtistOnboardingOnFirstLaunch() async {
    await TasteEngine.init();
    if (!TasteEngine.hasCompletedOnboarding && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ArtistOnboardingScreen(isModal: false),
        ),
      );
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _audioProvider?.playbackErrorNotifier.removeListener(_onPlaybackError);
    _periodicUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkForUpdates({bool force = false}) async {
    final updateInfo = await AppUpdateService.checkForUpdate(force: force);
    if (updateInfo != null && mounted) {
      UpdateDialog.show(context, updateInfo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          // L0 & L1: Illustrated Multi-Layered Twilight Mountain Landscape (Issue 2)
          const Positioned.fill(
            child: TwilightSceneBackground(
              mode: TwilightSceneMode.header,
            ),
          ),

          // Main Tabs Stack (5 Tabs - Issue 7)
          Positioned.fill(
            child: IndexedStack(
              index: _currentTabIndex,
              children: [
                _HomeDiscoveryView(
                  onNavigateToSearch: () => setState(() => _currentTabIndex = 1),
                  onNavigateToTab: (idx) => setState(() => _currentTabIndex = idx),
                ),
                const SearchScreen(),
                const MoodHubScreen(),
                LibraryScreen(
                  onNavigateToDownloads: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                    );
                  },
                ),
                const AlbumsScreen(),
              ],
            ),
          ),

          // Docked Mini-Player and Stationary Bottom Navigation Bar pinned to bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Persistent Docked Mini-Player
                const MiniPlayer(),

                // 5-Tab Stationary Bottom Navigation Bar
                TwilightBottomNavBar(
                  currentIndex: _currentTabIndex,
                  onTap: (index) => setState(() => _currentTabIndex = index),
                  icons: const [
                    Icons.home_rounded,
                    Icons.search_rounded,
                    Icons.auto_awesome_rounded,
                    Icons.library_music_rounded,
                    Icons.album_rounded,
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The Main Home Discovery Feed Tab
class _HomeDiscoveryView extends StatefulWidget {
  final VoidCallback onNavigateToSearch;
  final ValueChanged<int> onNavigateToTab;

  const _HomeDiscoveryView({
    required this.onNavigateToSearch,
    required this.onNavigateToTab,
  });

  @override
  State<_HomeDiscoveryView> createState() => _HomeDiscoveryViewState();
}

class _HomeDiscoveryViewState extends State<_HomeDiscoveryView> with WidgetsBindingObserver {
  String _activeFilter = 'All';
  bool _isLoadingContent = false;
  Timer? _greetingRefreshTimer;
  int _contentLoadEpoch = 0;
  String? _lastShownPlaybackError;

  List<YoutubeTrack> _quickPickTracks = [];
  List<YoutubeTrack> _carousel1Tracks = [];
  List<YoutubeTrack> _carousel2Tracks = [];
  List<YoutubeTrack> _carousel3Tracks = [];
  List<YoutubeTrack> _carousel4Tracks = [];
  List<YoutubeTrack> _carousel5Tracks = [];
  List<YoutubeTrack> _carousel6Tracks = [];
  YoutubeTrack _featuredPodcast = CuratedTracks.featuredPodcasts.first;

  final List<String> _filters = [
    'All',
    'Sunday Suspense',
    AppStrings.freshPicksFilterLabel,
    'Podcast',
    'Trending',
    'Chill',
    'Late Night',
    'Workout',
    'Focus',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _quickPickTracks = List.from(CuratedTracks.jumpBackInTracks);
    _carousel1Tracks = List.from(CuratedTracks.madeForYouTracks);
    _carousel2Tracks = List.from(CuratedTracks.trendingTracks);
    _carousel3Tracks = List.from(CuratedTracks.allCatalogTracks.reversed.take(12));
    _carousel4Tracks = List.from(CuratedTracks.workoutTracks + CuratedTracks.trendingTracks);
    _carousel5Tracks = List.from(CuratedTracks.chillTracks + CuratedTracks.lateNightTracks);
    _carousel6Tracks = List.from(CuratedTracks.lateNightTracks + CuratedTracks.chillTracks);

    // Live greeting refresh every minute without restart (Issue 7)
    _greetingRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDynamicContent();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Re-evaluate greeting immediately when app comes to foreground (Issue 7)
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _greetingRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDynamicContent() async {
    if (!mounted) return;

    // Phase 5: 10-Minute Stale-While-Revalidate Cache
    await HomeSectionCacheStore.init();
    final cached = HomeSectionCacheStore.getCached(_activeFilter);
    if (cached != null) {
      if (mounted) {
        setState(() {
          if (cached.quickPicks.isNotEmpty) _quickPickTracks = cached.quickPicks;
          if (cached.carousel1.isNotEmpty) _carousel1Tracks = cached.carousel1;
          if (cached.carousel2.isNotEmpty) _carousel2Tracks = cached.carousel2;
          if (cached.carousel3.isNotEmpty) _carousel3Tracks = cached.carousel3;
          if (cached.carousel4.isNotEmpty) _carousel4Tracks = cached.carousel4;
          if (cached.carousel5.isNotEmpty) _carousel5Tracks = cached.carousel5;
          if (cached.carousel6.isNotEmpty) _carousel6Tracks = cached.carousel6;
          _isLoadingContent = false;
        });
      }
      if (!cached.isExpired) {
        return; // Fresh cache, skip expensive network requests
      }
    } else {
      setState(() => _isLoadingContent = true);
    }

    await TasteEngine.init();
    final audioProvider = context.read<AudioProvider>();
    final favArtists = TasteEngine.favoriteArtists
        .where((a) => !TasteEngine.isBlockedChannelOrLabel(a.name))
        .map((a) => a.name)
        .toList();

    String quickQuery;
    String carousel1Query;
    String carousel2Query;
    String carousel3Query;
    String carousel4Query;
    String carousel5Query;
    String carousel6Query;

    switch (_activeFilter) {
      case 'Sunday Suspense':
        quickQuery = 'Sunday Suspense Feluda Satyajit Ray audio story';
        carousel1Query = 'Sunday Suspense Mirchi Bangla audio stories';
        carousel2Query = 'Sunday Suspense Professor Shonku Satyajit Ray';
        carousel3Query = 'Sunday Suspense Taranath Tantrik Mirchi';
        carousel4Query = 'Sunday Suspense Byomkesh Bakshi audio drama';
        carousel5Query = 'Sunday Suspense Sherlock Holmes Bengali';
        carousel6Query = 'Sunday Suspense horror mystery thrillers';
        break;
      case AppStrings.freshPicksFilterLabel:
      case 'Fresh Picks':
        quickQuery = 'trending hits 2026';
        carousel1Query = 'top 50 billboard hits';
        carousel2Query = 'bollywood top hits';
        carousel3Query = 'new viral songs global';
        carousel4Query = 'punjabi pop hits';
        carousel5Query = 'acoustic relaxing sessions';
        carousel6Query = 'lofi chill beats';
        break;
      case 'Podcast':
        quickQuery = 'Sunday Suspense Feluda Mirchi Bangla audio story';
        carousel1Query = 'Sunday Suspense Mirchi Bangla audio stories';
        carousel2Query = 'top popular hindi podcasts episodes';
        carousel3Query = 'mystery thriller audio drama detective story';
        carousel4Query = 'the ranveer show beerbiceps podcast';
        carousel5Query = 'bengali audio drama natok story';
        carousel6Query = 'horror thriller paranormal suspense audio drama';
        break;
      case 'Trending':
        quickQuery = 'top trending songs hits 2026';
        carousel1Query = 'latest trending top hits';
        carousel2Query = 'viral hits billboard 2026';
        carousel3Query = 'top bollywood punjabi trending';
        carousel4Query = 'global top 50 viral hits';
        carousel5Query = 'viral dance hits electronic';
        carousel6Query = 'trending midnight acoustic vibes';
        break;
      case 'Chill':
        quickQuery = 'acoustic lofi chill relaxing songs';
        carousel1Query = 'soothing acoustic coffeehouse hits';
        carousel2Query = 'lofi chill sunset beats';
        carousel3Query = 'peaceful piano guitar acoustic';
        carousel4Query = 'indie chill acoustic sessions';
        carousel5Query = 'breeze slow reverb relaxing songs';
        carousel6Query = 'chill aesthetic night vibes lofi slow';
        break;
      case 'Late Night':
        quickQuery = 'late night slow reverb melancholy vibes';
        carousel1Query = 'midnight slow ambient acoustic';
        carousel2Query = 'dark pop late night session';
        carousel3Query = 'slowed and reverb late night songs';
        carousel4Query = 'deep midnight melancholic vibes';
        carousel5Query = 'night drive synthwave lofi';
        carousel6Query = 'chill aesthetic night vibes bedroom pop';
        break;
      case 'Workout':
        quickQuery = 'gym workout energy gym motivation tracks';
        carousel1Query = 'high bpm workout running EDM';
        carousel2Query = 'power cardio motivation bass';
        carousel3Query = 'beast mode gym phonk hip hop';
        carousel4Query = 'punjabi workout gym high bass';
        carousel5Query = 'pump up energetic electronic workout';
        carousel6Query = 'post workout calm stretching ambient';
        break;
      case 'Focus':
        quickQuery = 'lofi study focus deep concentration ambient';
        carousel1Query = 'binaural focus ambient study music';
        carousel2Query = 'coding deep work lofi beats';
        carousel3Query = 'peaceful ambient study frequency';
        carousel4Query = 'calm instrumental focus flow';
        carousel5Query = 'deep focus classical piano';
        carousel6Query = 'night study aesthetic lofi rain beats';
        break;
      case 'All':
      default:
        final topArtist = favArtists.isNotEmpty ? favArtists.first : 'Arijit Singh';
        final secondArtist = favArtists.length > 1
            ? favArtists[1]
            : (favArtists.isNotEmpty ? 'Pritam' : 'Shreya Ghoshal');
        final thirdArtist = favArtists.length > 2
            ? favArtists[2]
            : 'Coldplay';

        quickQuery = '$topArtist $secondArtist best hits official';
        carousel1Query = '$topArtist top hit songs';
        carousel2Query = 'top trending hit songs 2026';
        carousel3Query = '$secondArtist iconic hit songs';
        carousel4Query = '$thirdArtist best songs';
        carousel5Query = 'chill acoustic lofi midnight songs';
        carousel6Query = 'chill aesthetic night vibes acoustic lofi';
        break;
    }

    final epoch = ++_contentLoadEpoch;

    try {
      // Parallel stream loading: Each section renders immediately as soon as its data arrives
      audioProvider.musicService.searchTracks(quickQuery).then((res) {
        if (!mounted || epoch != _contentLoadEpoch) return;
        if (res.isNotEmpty) {
          setState(() {
            _quickPickTracks = TasteEngine.rerankSearchResults(res).take(10).toList();
            _isLoadingContent = false;
          });
          _prefetchNextImages(_quickPickTracks, 4);
          _saveCurrentCache();
        }
      }).catchError((_) => <YoutubeTrack>[]);

      audioProvider.musicService.searchTracks(carousel1Query).then((res) {
        if (!mounted || epoch != _contentLoadEpoch) return;
        if (res.isNotEmpty) {
          setState(() {
            _carousel1Tracks = TasteEngine.rerankSearchResults(res).take(20).toList();
            _isLoadingContent = false;
          });
          _prefetchNextImages(_carousel1Tracks, 6);
          _saveCurrentCache();
        }
      }).catchError((_) => <YoutubeTrack>[]);

      PodcastRssService.fetchSundaySuspenseEpisodes(limit: 5).then((res) {
        if (!mounted || epoch != _contentLoadEpoch) return;
        if (res.isNotEmpty) {
          setState(() {
            _featuredPodcast = res.first;
          });
        }
      }).catchError((_) => CuratedTracks.featuredPodcasts);

      audioProvider.musicService.searchTracks(carousel2Query).then((res) {
        if (!mounted || epoch != _contentLoadEpoch) return;
        if (res.isNotEmpty) {
          setState(() {
            _carousel2Tracks = TasteEngine.rerankSearchResults(res).take(20).toList();
          });
          _prefetchNextImages(_carousel2Tracks, 6);
          _saveCurrentCache();
        }
      }).catchError((_) => <YoutubeTrack>[]);

      audioProvider.musicService.searchTracks(carousel3Query).then((res) {
        if (!mounted || epoch != _contentLoadEpoch) return;
        if (res.isNotEmpty) {
          setState(() {
            _carousel3Tracks = TasteEngine.rerankSearchResults(res).take(20).toList();
          });
          _prefetchNextImages(_carousel3Tracks, 6);
          _saveCurrentCache();
        }
      }).catchError((_) => <YoutubeTrack>[]);

      audioProvider.musicService.searchTracks(carousel4Query).then((res) {
        if (!mounted || epoch != _contentLoadEpoch) return;
        if (res.isNotEmpty) {
          setState(() {
            _carousel4Tracks = TasteEngine.rerankSearchResults(res).take(20).toList();
          });
          _prefetchNextImages(_carousel4Tracks, 6);
          _saveCurrentCache();
        }
      }).catchError((_) => <YoutubeTrack>[]);

      audioProvider.musicService.searchTracks(carousel5Query).then((res) {
        if (!mounted || epoch != _contentLoadEpoch) return;
        if (res.isNotEmpty) {
          setState(() {
            _carousel5Tracks = TasteEngine.rerankSearchResults(res).take(20).toList();
          });
          _prefetchNextImages(_carousel5Tracks, 6);
          _saveCurrentCache();
        }
      }).catchError((_) => <YoutubeTrack>[]);

      audioProvider.musicService.searchTracks(carousel6Query).then((res) {
        if (!mounted || epoch != _contentLoadEpoch) return;
        if (res.isNotEmpty) {
          setState(() {
            _carousel6Tracks = TasteEngine.rerankSearchResults(res).take(20).toList();
          });
          _prefetchNextImages(_carousel6Tracks, 6);
          _saveCurrentCache();
        }
      }).catchError((_) => <YoutubeTrack>[]);
    } catch (_) {
      if (mounted && epoch == _contentLoadEpoch) {
        setState(() => _isLoadingContent = false);
      }
    }
  }

  void _saveCurrentCache() {
    HomeSectionCacheStore.save(
      _activeFilter,
      HomeCachedData(
        quickPicks: _quickPickTracks,
        carousel1: _carousel1Tracks,
        carousel2: _carousel2Tracks,
        carousel3: _carousel3Tracks,
        carousel4: _carousel4Tracks,
        carousel5: _carousel5Tracks,
        carousel6: _carousel6Tracks,
        timestamp: DateTime.now(),
      ),
    );
  }

  void _prefetchNextImages(List<YoutubeTrack> tracks, [int count = 6]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final track in tracks.take(count)) {
        final url = track.thumbnailUrl.trim();
        if (url.isNotEmpty) {
          final targetSize = '156x112';
          final cacheKey = 'track:${track.id}:$targetSize';
          try {
            precacheImage(
              CachedNetworkImageProvider(
                url,
                cacheKey: cacheKey,
                maxHeight: 168,
                maxWidth: 234,
              ),
              context,
            );
          } catch (_) {}
        }
      }
    });
  }

  String _getTimeGreeting() {
    return GreetingService.getGreeting();
  }

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.watch<AudioProvider>();
    final authProvider = context.watch<AuthProvider>();

    final errorMsg = audioProvider.playbackErrorMessage;
    if (errorMsg != null && errorMsg.isNotEmpty && errorMsg != _lastShownPlaybackError) {
      _lastShownPlaybackError = errorMsg;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMsg,
                    style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.surface1,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
        audioProvider.clearPlaybackErrorMessage();
      });
    } else if (errorMsg == null && _lastShownPlaybackError != null) {
      _lastShownPlaybackError = null;
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 240),
        children: [
          const SizedBox(height: 12),

          // 1. Top Header Bar (Part B: 44x44dp targets, 8dp spacing, no shrink, full safe area)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getTimeGreeting(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h2.copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ready to stream lossless audio',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textPrimary.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Top Action Group (Profile icon only - Phase 2)
                _buildProfileAvatar(context, authProvider),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Explore Search Bar (Wide bar with rounded corners - Phase 2)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GestureDetector(
              onTap: widget.onNavigateToSearch,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface1.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.surface2,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Search songs, artists, podcasts',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.search_rounded,
                      color: AppColors.iconIdle,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // 2. Filter / Mood Chips (Horizontal Scroll)
          SizedBox(
            height: 38,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = filter == _activeFilter;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _activeFilter = filter);
                    _loadDynamicContent();
                  },
                  child: AnimatedContainer(
                    duration: AppMotion.durationFast,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primarySoft
                          : AppColors.surface1.withValues(alpha: 0.8),
                      borderRadius: AppRadii.borderPill,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primarySoft
                            : AppColors.surface2,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      filter,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // 2.5 Featured Podcast & Audio Story Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: FeaturedBanner(
              title: _featuredPodcast.title,
              metaText: 'PODCAST • ${_featuredPodcast.artist}',
              imageUrl: _featuredPodcast.thumbnailUrl,
              onActionTap: () {
                HapticFeedback.lightImpact();
                audioProvider.playTrack(
                  _featuredPodcast,
                  CuratedTracks.featuredPodcasts,
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // 3. Quick-Pick Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              _activeFilter == 'All' ? 'Jump Back In' : '$_activeFilter Mixes',
              style: AppTextStyles.h3.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildQuickPickGrid(context, audioProvider),
          ),

          const SizedBox(height: 28),

          // 4. Horizontal Circle Row ("Recommended Artists")
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recommended Artists',
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ArtistOnboardingScreen(isModal: true)),
                    );
                    setState(() {});
                  },
                  child: Text(
                    TasteEngine.favoriteArtists.isEmpty ? '+ Pick Taste' : 'Edit',
                    style: AppTextStyles.meta.copyWith(
                      color: AppColors.primarySoft,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          SizedBox(
            height: 110,
            child: _buildArtistCirclesRow(audioProvider),
          ),

          const SizedBox(height: 24),

          // Home Recommendation Sections (Issue 3: 12 Sections in exact order)
          if (_activeFilter == 'All') ...[
            // 1. Recently Played (horizontal scroll - only shown when history exists)
            if (audioProvider.historyTracks.isNotEmpty)
              _buildHomeSection(
                title: 'Recently Played',
                tracks: audioProvider.historyTracks,
                audioProvider: audioProvider,
              ),
            // 2. Recommended Today (horizontal scroll)
            _buildHomeSection(
              title: 'Recommended Today',
              tracks: _carousel1Tracks.isNotEmpty
                  ? _carousel1Tracks
                  : CuratedTracks.madeForYouTracks,
              audioProvider: audioProvider,
            ),
            // Fresh Picks Top Charts (Issue 1)
            _buildHomeSection(
              title: AppStrings.freshPicksSectionTitle,
              tracks: CuratedTracks.freshPicksTracks,
              audioProvider: audioProvider,
            ),
            // 3. Popular Albums and Singles (horizontal scroll)
            _buildHomeSection(
              title: 'Popular Albums and Singles',
              tracks: CuratedTracks.popularAlbumsTracks,
              audioProvider: audioProvider,
            ),
            // 4. More of What You Like (horizontal scroll)
            _buildHomeSection(
              title: 'More of What You Like',
              tracks: _carousel2Tracks.isNotEmpty
                  ? _carousel2Tracks
                  : CuratedTracks.chillTracks,
              audioProvider: audioProvider,
            ),
            // 5. Today's Biggest Hits (horizontal scroll)
            _buildHomeSection(
              title: "Today's Biggest Hits",
              tracks: _carousel3Tracks.isNotEmpty
                  ? _carousel3Tracks
                  : CuratedTracks.trendingTracks,
              audioProvider: audioProvider,
            ),
            // 6. Albums Featuring Songs You Like (horizontal scroll)
            _buildHomeSection(
              title: 'Albums Featuring Songs You Like',
              tracks: CuratedTracks.featuringSongsTracks,
              audioProvider: audioProvider,
            ),
            // 7. Based on Your Recent Listening (horizontal scroll)
            _buildHomeSection(
              title: 'Based on Your Recent Listening',
              tracks: _carousel4Tracks.isNotEmpty
                  ? _carousel4Tracks
                  : CuratedTracks.workoutTracks,
              audioProvider: audioProvider,
            ),
            // 8. More Like Ishq Bulaava Radio (horizontal scroll)
            _buildHomeSection(
              title: 'More Like Ishq Bulaava Radio',
              tracks: CuratedTracks.ishqBulaavaRadioTracks,
              audioProvider: audioProvider,
            ),
            // 9. Happy Hits (horizontal scroll)
            _buildHomeSection(
              title: 'Happy Hits',
              tracks: CuratedTracks.happyHitsTracks,
              audioProvider: audioProvider,
            ),
            // 10. More from A.R. Rahman (horizontal scroll)
            _buildHomeSection(
              title: 'More from A.R. Rahman',
              tracks: CuratedTracks.arRahmanTracks,
              audioProvider: audioProvider,
            ),
            // 11. Your Top Mixes (horizontal scroll)
            _buildHomeSection(
              title: 'Your Top Mixes',
              tracks: _carousel5Tracks.isNotEmpty
                  ? _carousel5Tracks
                  : CuratedTracks.lateNightTracks,
              audioProvider: audioProvider,
            ),
            // 12. More Like Manwa Laage Radio (horizontal scroll)
            _buildHomeSection(
              title: 'More Like Manwa Laage Radio',
              tracks: CuratedTracks.manwaLaageRadioTracks,
              audioProvider: audioProvider,
            ),
          ] else ...[
            // Filter-specific carousels when a mood chip is tapped
            _buildHomeSection(
              title: _getCarousel1Title(),
              tracks: _getCarousel1Tracks(),
              audioProvider: audioProvider,
            ),
            _buildHomeSection(
              title: _getCarousel2Title(),
              tracks: _getCarousel2Tracks(),
              audioProvider: audioProvider,
            ),
            _buildHomeSection(
              title: _getCarousel3Title(),
              tracks: _getCarousel3Tracks(),
              audioProvider: audioProvider,
            ),
            _buildHomeSection(
              title: _getCarousel4Title(),
              tracks: _getCarousel4Tracks(),
              audioProvider: audioProvider,
            ),
            _buildHomeSection(
              title: _getCarousel5Title(),
              tracks: _getCarousel5Tracks(),
              audioProvider: audioProvider,
            ),
            _buildHomeSection(
              title: _getCarousel6Title(),
              tracks: _getCarousel6Tracks(),
              audioProvider: audioProvider,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface2.withValues(alpha: 0.85),
                border: Border.all(
                  color: AppColors.primarySoft.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(BuildContext context, AuthProvider authProvider) {
    const double targetSize = 48.0; // 48dp minimum WCAG AA touch target
    final isAuthenticated = authProvider.isAuthenticated;
    final avatarUrl = authProvider.avatarUrl.trim();
    final displayName = authProvider.displayName.trim();
    final initial = (displayName.isNotEmpty && displayName != 'Guest' && displayName != 'Music Lover')
        ? displayName[0].toUpperCase()
        : (authProvider.email.isNotEmpty && authProvider.email != 'Guest'
            ? authProvider.email[0].toUpperCase()
            : '');

    Widget fallbackContent;
    if (isAuthenticated && initial.isNotEmpty) {
      fallbackContent = Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      );
    } else {
      fallbackContent = const Icon(
        Icons.person_rounded,
        size: 22,
        color: Colors.white,
      );
    }

    Widget content;
    if (isAuthenticated && avatarUrl.isNotEmpty) {
      content = ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl,
          width: targetSize,
          height: targetSize,
          fit: BoxFit.cover,
          placeholder: (_, __) => Center(child: fallbackContent),
          errorWidget: (_, __, ___) => Center(child: fallbackContent),
        ),
      );
    } else {
      content = Center(child: fallbackContent);
    }

    return Semantics(
      button: true,
      label: 'Profile',
      child: Tooltip(
        message: 'Profile',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(targetSize / 2),
            onTap: () {
              if (isAuthenticated) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
            child: Container(
              width: targetSize,
              height: targetSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface2.withValues(alpha: 0.85),
                border: Border.all(
                  color: isAuthenticated
                      ? AppColors.primarySoft.withValues(alpha: 0.7)
                      : AppColors.primarySoft.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeSection({
    required String title,
    required List<YoutubeTrack> tracks,
    required AudioProvider audioProvider,
    String actionLabel = 'See all',
  }) {
    final displayTracks = TasteEngine.deduplicateArtwork(tracks);
    if (displayTracks.isEmpty) {
      return _isLoadingContent ? _buildSkeletonHomeSection(title: title) : const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showSeeAllModal(title, displayTracks, audioProvider);
                },
                behavior: HitTestBehavior.opaque,
                child: Semantics(
                  button: true,
                  label: 'See all $title',
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: Text(
                      actionLabel,
                      style: AppTextStyles.caption.copyWith(
                        color: const Color(0xFFDDD6FE), // WCAG AA compliant contrast (>7:1)
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            cacheExtent: 600.0,
            physics: const BouncingScrollPhysics(),
            itemCount: displayTracks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final track = displayTracks[index];
              return ContentCard(
                key: ValueKey('card_${track.id}'),
                trackId: track.id,
                title: track.title,
                subtitle: track.artist,
                imageUrl: track.thumbnailUrl,
                onTap: () {
                  HapticFeedback.lightImpact();
                  audioProvider.playTrack(track, displayTracks);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildSkeletonHomeSection({required String title}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.h3.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) => SizedBox(
              width: 156,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 156,
                    height: 112,
                    decoration: BoxDecoration(
                      color: AppColors.surface1,
                      borderRadius: AppRadii.borderMedium,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.surface2,
                          AppColors.surface1.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 120,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 80,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.surface2.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  void _showSeeAllModal(String sectionTitle, List<YoutubeTrack> sectionTracks, AudioProvider audioProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          sectionTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.h3,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${sectionTracks.length} tracks',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primarySoft,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          if (sectionTracks.isNotEmpty) {
                            audioProvider.playTrack(sectionTracks.first, sectionTracks);
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.surface2),
                  Expanded(
                    child: ListView.separated(
                      itemCount: sectionTracks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, index) {
                        final t = sectionTracks[index];
                        final isPlayingThis = audioProvider.currentTrack?.id == t.id;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadii.small),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: CascadingArtwork(
                                key: ValueKey('see_all_art_${t.id}'),
                                trackId: t.id,
                                imageUrl: t.thumbnailUrl,
                                title: t.title,
                                artist: t.artist,
                                width: 48,
                                height: 48,
                                borderRadius: BorderRadius.circular(AppRadii.small),
                              ),
                            ),
                          ),
                          title: Text(
                            t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: isPlayingThis ? AppColors.primarySoft : Colors.white,
                              fontWeight: isPlayingThis ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            t.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption,
                          ),
                          trailing: isPlayingThis && audioProvider.isPlaying
                              ? const Icon(Icons.volume_up_rounded, color: AppColors.primarySoft, size: 20)
                              : const Icon(Icons.play_circle_outline_rounded, color: AppColors.iconIdle, size: 22),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            audioProvider.playTrack(t, sectionTracks);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getCarousel1Title() {
    switch (_activeFilter) {
      case 'Sunday Suspense':
        return 'Sunday Suspense: Feluda & Shonku';
      case 'Fresh Picks':
        return 'Top 50 Fresh Picks';
      case 'Podcast':
        return 'Sunday Suspense Audio Stories';
      case 'Trending':
        return 'Trending Hits';
      case 'Chill':
        return 'Chill Acoustic & Lo-Fi';
      case 'Late Night':
        return 'Midnight Sessions';
      case 'Workout':
        return 'High-BPM Energy';
      case 'Focus':
        return 'Deep Work & Study';
      case 'All':
      default:
        final favs = TasteEngine.favoriteArtists.where((a) => !TasteEngine.isBlockedChannelOrLabel(a.name));
        return favs.isNotEmpty ? 'Because You Love ${favs.first.name}' : 'Made For You';
    }
  }

  List<YoutubeTrack> _getCarousel1Tracks() {
    return _carousel1Tracks.isNotEmpty
        ? _carousel1Tracks
        : CuratedTracks.getTracksForFilter(_activeFilter);
  }

  String _getCarousel2Title() {
    switch (_activeFilter) {
      case 'Sunday Suspense':
        return 'Sunday Suspense: Mirchi Audio Stories';
      case 'Fresh Picks':
        return 'Trending Fresh Hits';
      case 'Podcast':
        return 'Popular Podcasts & Talk Shows';
      case 'Trending':
        return 'Viral Charts';
      case 'Chill':
        return 'Mellow Waves';
      case 'Late Night':
        return 'Dark Ambient';
      case 'Workout':
        return 'Cardio Pulse';
      case 'Focus':
        return 'Binaural Focus';
      case 'All':
      default:
        return 'Trending & Viral Hits';
    }
  }

  List<YoutubeTrack> _getCarousel2Tracks() {
    return _carousel2Tracks.isNotEmpty
        ? _carousel2Tracks
        : CuratedTracks.trendingTracks;
  }

  String _getCarousel3Title() {
    switch (_activeFilter) {
      case 'Sunday Suspense':
        return 'Sunday Suspense: Taranath Tantrik';
      case 'Fresh Picks':
        return 'Regional Chartbusters';
      case 'Podcast':
        return 'Mystery & Detective Dramas';
      case 'Trending':
        return 'Regional & Bollywood Chartbusters';
      case 'Chill':
        return 'Peaceful Acoustic & Strings';
      case 'Late Night':
        return 'Slowed & Reverb Sessions';
      case 'Workout':
        return 'Beast Mode Gym Motivation';
      case 'Focus':
        return 'Ambient Lo-Fi Frequency';
      case 'All':
      default:
        final favs = TasteEngine.favoriteArtists.where((a) => !TasteEngine.isBlockedChannelOrLabel(a.name)).toList();
        return favs.length > 1 ? 'Artist Spotlight: ${favs[1].name}' : 'Iconic Melody Hits';
    }
  }

  List<YoutubeTrack> _getCarousel3Tracks() {
    return _carousel3Tracks.isNotEmpty
        ? _carousel3Tracks
        : CuratedTracks.allCatalogTracks.reversed.take(15).toList();
  }

  String _getCarousel4Title() {
    switch (_activeFilter) {
      case 'Sunday Suspense':
        return 'Sunday Suspense: Satyajit Ray Classics';
      case 'Fresh Picks':
        return 'Global Fresh Releases';
      case 'Podcast':
        return 'The Ranveer Show & Talks';
      case 'Trending':
        return 'Global Top 50 Hits';
      case 'Chill':
        return 'Coffeehouse Acoustic';
      case 'Late Night':
        return 'Midnight Melancholy';
      case 'Workout':
        return 'High Bass Power EDM';
      case 'Focus':
        return 'Deep Concentration Flow';
      case 'All':
      default:
        return 'Fresh Discoveries & Releases';
    }
  }

  List<YoutubeTrack> _getCarousel4Tracks() {
    return _carousel4Tracks.isNotEmpty
        ? _carousel4Tracks
        : CuratedTracks.workoutTracks;
  }

  String _getCarousel5Title() {
    switch (_activeFilter) {
      case 'Sunday Suspense':
        return 'Sunday Suspense: Byomkesh Bakshi';
      case 'Fresh Picks':
        return 'Acoustic & Chill Mix';
      case 'Podcast':
        return 'Bengali Audio Natok & Thrillers';
      case 'Trending':
        return 'Party & Dance Floor Hits';
      case 'Chill':
        return 'Sunset Lo-Fi Chill';
      case 'Late Night':
        return 'Night Drive Waves';
      case 'Workout':
        return 'Non-Stop Workout Mix';
      case 'Focus':
        return 'Calm Instrumental Study';
      case 'All':
      default:
        return 'Chill Acoustic & Night Vibes';
    }
  }

  List<YoutubeTrack> _getCarousel5Tracks() {
    return _carousel5Tracks.isNotEmpty
        ? _carousel5Tracks
        : CuratedTracks.chillTracks;
  }

  String _getCarousel6Title() {
    switch (_activeFilter) {
      case 'Sunday Suspense':
        return 'Sunday Suspense: Horror & Paranormal';
      case 'Fresh Picks':
        return 'Party & Dance Fresh Hits';
      case 'Podcast':
        return 'Horror & Paranormal Stories';
      case 'Trending':
        return 'Viral Midnight Hits';
      case 'Chill':
        return 'Chill Aesthetic Night Vibes';
      case 'Late Night':
        return 'Bedroom Pop & Reverb';
      case 'Workout':
        return 'Cool Down & Stretch';
      case 'Focus':
        return 'Night Study & Ambient Flow';
      case 'All':
      default:
        return 'Chill Aesthetic Night Vibes';
    }
  }

  List<YoutubeTrack> _getCarousel6Tracks() {
    return _carousel6Tracks.isNotEmpty
        ? _carousel6Tracks
        : (CuratedTracks.lateNightTracks + CuratedTracks.chillTracks);
  }

  /// 2x5 Grid of Compact Glass-Tinted Tiles
  Widget _buildQuickPickGrid(
    BuildContext context,
    AudioProvider audioProvider,
  ) {
    final tracks = _quickPickTracks.isNotEmpty
        ? _quickPickTracks
        : CuratedTracks.getTracksForFilter(_activeFilter).take(10).toList();

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: tracks.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 56,
      ),
      itemBuilder: (context, index) {
        final track = tracks[index];
        final isCurrent = audioProvider.currentTrack?.id == track.id;

        return GestureDetector(
          key: ValueKey('quick_${track.id}'),
          onTap: () {
            HapticFeedback.lightImpact();
            audioProvider.playTrack(track, tracks);
          },
          child: AnimatedContainer(
            duration: AppMotion.durationFast,
            decoration: BoxDecoration(
              color: isCurrent
                  ? AppColors.surface2
                  : AppColors.surface1.withValues(alpha: 0.85),
              borderRadius: AppRadii.borderSmall,
              border: Border.all(
                color: isCurrent
                    ? AppColors.primarySoft.withValues(alpha: 0.4)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(AppRadii.small),
                  ),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: CascadingArtwork(
                      key: ValueKey('quick_art_${track.id}'),
                      trackId: track.id,
                      imageUrl: track.thumbnailUrl,
                      title: track.title,
                      artist: track.artist,
                      width: 56,
                      height: 56,
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    track.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                      color: isCurrent
                          ? AppColors.primarySoft
                          : AppColors.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (isCurrent && audioProvider.isPlaying)
                  const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Icon(
                      Icons.volume_up_rounded,
                      color: AppColors.primarySoft,
                      size: 18,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Trending Track Card with Artwork, Title, Quality Tag & Action Menu
  Widget _buildTrendingCard(
    BuildContext context,
    YoutubeTrack track,
    AudioProvider audioProvider,
    List<YoutubeTrack> queue,
  ) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              audioProvider.playTrack(
                track,
                queue,
              );
            },
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: AppRadii.borderMedium,
                  child: SizedBox(
                    width: 140,
                    height: 130,
                    child: CachedNetworkImage(
                      imageUrl: track.thumbnailUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 280,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.controlLight,
                      shape: BoxShape.circle,
                      boxShadow: const [AppShadows.shadowSoft],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Color(0xFF1E1B24),
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.cardTitle.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showTrackBottomSheet(context, track, audioProvider),
                child: const Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: AppColors.iconIdle,
                ),
              ),
            ],
          ),
          Text(
            '${track.artist} • 320k',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /// Circular Artist Avatar Item
  Widget _buildArtistCirclesRow(AudioProvider audioProvider) {
    final userFavs = TasteEngine.favoriteArtists
        .where((a) => !TasteEngine.isBlockedChannelOrLabel(a.name))
        .toList();
    final artistsToShow = userFavs.isNotEmpty
        ? userFavs
        : TasteEngine.defaultArtistCatalog
            .where((a) => !TasteEngine.isBlockedChannelOrLabel(a.name))
            .take(16)
            .toList();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      itemCount: artistsToShow.length + 1,
      separatorBuilder: (_, __) => const SizedBox(width: 16),
      itemBuilder: (context, index) {
        if (index == 0) {
          // Add Artist Pill
          return GestureDetector(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ArtistOnboardingScreen(isModal: true)),
              );
              if (mounted) {
                setState(() {});
                _loadDynamicContent();
              }
            },
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface1,
                    border: Border.all(color: AppColors.primarySoft.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(Icons.add_rounded, color: AppColors.primarySoft, size: 28),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  userFavs.isEmpty ? 'Pick Artists' : 'Add More',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          );
        }

        final artist = artistsToShow[index - 1];
        return GestureDetector(
          key: ValueKey('artist_${artist.id}'),
          onTap: () async {
            HapticFeedback.lightImpact();
            final songs = await audioProvider.musicService.searchTracks('${artist.name} top hits');
            if (songs.isNotEmpty) {
              await audioProvider.playTrack(songs.first, songs);
            }
          },
          child: Column(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: artist.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: artist.imageUrl,
                          cacheKey: 'artist:${artist.id}:70x70',
                          fit: BoxFit.cover,
                          memCacheWidth: 140,
                          memCacheHeight: 140,
                          placeholder: (_, __) => _buildArtistAvatarFallback(artist.name),
                          errorWidget: (_, __, ___) => _buildArtistAvatarFallback(artist.name),
                        )
                      : _buildArtistAvatarFallback(artist.name),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 76,
                child: Text(
                  artist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArtistAvatarFallback(String name, {double size = 70, double fontSize = 20}) {
    final clean = name.trim();
    String initials = '?';
    if (clean.isNotEmpty) {
      final parts = clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        initials = parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
      }
    }

    const gradients = [
      [Color(0xFF6366F1), Color(0xFF8B5CF6)], // Indigo - Purple
      [Color(0xFFEC4899), Color(0xFFF43F5E)], // Pink - Rose
      [Color(0xFF06B6D4), Color(0xFF3B82F6)], // Cyan - Blue
      [Color(0xFF10B981), Color(0xFF059669)], // Emerald - Teal
      [Color(0xFFF59E0B), Color(0xFFEF4444)], // Amber - Red
      [Color(0xFF8B5CF6), Color(0xFFD946EF)], // Purple - Fuchsia
      [Color(0xFF3B82F6), Color(0xFF1D4ED8)], // Royal Blue
      [Color(0xFF14B8A6), Color(0xFF0D9488)], // Teal
    ];
    final colorPair = gradients[clean.hashCode.abs() % gradients.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colorPair,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  void _showTrackBottomSheet(
    BuildContext context,
    YoutubeTrack track,
    AudioProvider audioProvider,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadii.xlarge),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.playlist_play_rounded, color: AppColors.primarySoft),
                title: Text('Play Next', style: AppTextStyles.bodyMedium),
                onTap: () {
                  Navigator.pop(ctx);
                  audioProvider.playTrack(track);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_rounded, color: AppColors.iconIdle),
                title: Text('Download Offline', style: AppTextStyles.bodyMedium),
                onTap: () {
                  Navigator.pop(ctx);
                  audioProvider.downloadTrackForOffline(track);
                },
              ),
              ListTile(
                leading: Icon(
                  audioProvider.isTrackLiked(track.id)
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: audioProvider.isTrackLiked(track.id)
                      ? const Color(0xFFE91E63)
                      : AppColors.iconIdle,
                ),
                title: Text(
                  audioProvider.isTrackLiked(track.id) ? 'Unlike Song' : 'Like Song',
                  style: AppTextStyles.bodyMedium,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  audioProvider.toggleFavorite(track);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        audioProvider.isTrackLiked(track.id)
                            ? 'Removed from Liked Songs'
                            : 'Added to Liked Songs',
                        style: AppTextStyles.bodySmall,
                      ),
                      backgroundColor: AppColors.surface1,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHistorySheet(BuildContext context, AudioProvider audioProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final history = audioProvider.historyTracks.isNotEmpty
            ? audioProvider.historyTracks
            : CuratedTracks.jumpBackInTracks;

        return Container(
          height: 340,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadii.xlarge),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Listening History', style: AppTextStyles.h3),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.iconIdle),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final t = history[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: AppRadii.borderSmall,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: CascadingArtwork(
                            key: ValueKey('hist_art_${t.id}'),
                            trackId: t.id,
                            imageUrl: t.thumbnailUrl,
                            title: t.title,
                            artist: t.artist,
                            width: 44,
                            height: 44,
                            borderRadius: AppRadii.borderSmall,
                          ),
                        ),
                      ),
                      title: Text(t.title, style: AppTextStyles.bodyMedium),
                      subtitle: Text(t.artist, style: AppTextStyles.caption),
                      trailing: const Icon(Icons.play_arrow_rounded, color: AppColors.primarySoft),
                      onTap: () {
                        Navigator.pop(ctx);
                        audioProvider.playTrack(t, history);
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
  }
}
