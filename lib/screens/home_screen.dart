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
import '../widgets/update_dialog.dart';
import '../widgets/twilight_scene_background.dart';
import '../core/services/app_update_service.dart';
import 'search_screen.dart';
import 'library_screen.dart';
import 'downloads_screen.dart';
import 'profile_screen.dart';
import 'artist_onboarding_screen.dart';
import 'mood_hub_screen.dart';
import '../core/services/taste_engine.dart';
import '../providers/auth_provider.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
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

  Future<void> _checkArtistOnboardingOnFirstLaunch() async {
    await TasteEngine.init();
    if (!TasteEngine.hasCompletedOnboarding && mounted) {
      // First-launch onboarding check (Issue 4)
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ArtistOnboardingScreen(isModal: false),
        ),
      );
    }
  }

  @override
  void dispose() {
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
                  onNavigateToDownloads: () => setState(() => _currentTabIndex = 4),
                ),
                const DownloadsScreen(),
              ],
            ),
          ),

          // Docked Mini-Player and Floating Navigation Bar pinned to bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Persistent Docked Mini-Player
                const MiniPlayer(),

                // 5-Tab Floating Bottom Navigation Bar (Issue 7 Step 1)
                TwilightBottomNavBar(
                  currentIndex: _currentTabIndex,
                  onTap: (index) => setState(() => _currentTabIndex = index),
                  icons: const [
                    Icons.home_filled,
                    Icons.search_rounded,
                    Icons.auto_awesome_rounded,
                    Icons.library_music_rounded,
                    Icons.cloud_download_rounded,
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

class _HomeDiscoveryViewState extends State<_HomeDiscoveryView> {
  String _activeFilter = 'All';

  final List<String> _filters = [
    'All',
    'Trending',
    'Chill',
    'Late Night',
    'Workout',
    'Focus',
    'Liked Songs',
    'Downloaded',
  ];

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.read<AudioProvider>();
    final authProvider = context.watch<AuthProvider>();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 160),
        children: [
          const SizedBox(height: 12),

          // 1. Top Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _getTimeGreeting(),
                          style: AppTextStyles.h2.copyWith(fontSize: 22),
                        ),
                        const SizedBox(width: 8),
                        // Status Pill ("Hi-Res • Ad-Free")
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface1,
                            borderRadius: AppRadii.borderPill,
                            border: Border.all(
                              color: AppColors.primarySoft.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4CAF50),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Hi-Res • Ad-Free',
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ready to stream lossless audio',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

                // Top Action Buttons (Search, History, Profile)
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.iconIdle,
                        size: 24,
                      ),
                      onPressed: widget.onNavigateToSearch,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.history_rounded,
                        color: AppColors.iconIdle,
                        size: 24,
                      ),
                      onPressed: () => _showHistorySheet(context, audioProvider),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ProfileScreen()),
                        );
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface2,
                          border: Border.all(
                            color: authProvider.isAuthenticated
                                ? AppColors.success.withValues(alpha: 0.6)
                                : AppColors.primarySoft.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: authProvider.isAuthenticated && authProvider.displayName.isNotEmpty
                              ? Text(
                                  authProvider.displayName[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : const Icon(
                                  Icons.person_rounded,
                                  size: 20,
                                  color: AppColors.primarySoft,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

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
                    if (filter == 'Liked Songs') {
                      widget.onNavigateToTab(3); // Jump to Library (Tab 3 in 5-tab shell)
                    } else if (filter == 'Downloaded') {
                      widget.onNavigateToTab(4); // Jump to Downloads (Tab 4 in 5-tab shell)
                    }
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

          // 4. Horizontal Card Carousel 1
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getCarousel1Title(),
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'See all',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primarySoft,
                    fontWeight: FontWeight.w600,
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
              itemCount: _getCarousel1Tracks().length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final track = _getCarousel1Tracks()[index];
                return ContentCard(
                  title: track.title,
                  subtitle: track.artist,
                  imageUrl: track.thumbnailUrl,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    audioProvider.playTrack(
                      track,
                      _getCarousel1Tracks(),
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 28),

          // 5. Horizontal Card Carousel 2
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getCarousel2Title(),
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Explore',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primarySoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 200,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _getCarousel2Tracks().length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final track = _getCarousel2Tracks()[index];
                return _buildTrendingCard(context, track, audioProvider);
              },
            ),
          ),

          const SizedBox(height: 28),

          // 6. Horizontal Circle Row ("Recommended Artists" - Issue 4)
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
        ],
      ),
    );
  }

  String _getCarousel1Title() {
    switch (_activeFilter) {
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
        return 'Made For You';
    }
  }

  List<YoutubeTrack> _getCarousel1Tracks() {
    switch (_activeFilter) {
      case 'Trending':
        return CuratedTracks.trendingTracks;
      case 'Chill':
        return CuratedTracks.chillTracks;
      case 'Late Night':
        return CuratedTracks.lateNightTracks;
      case 'Workout':
        return CuratedTracks.workoutTracks;
      case 'Focus':
        return CuratedTracks.focusTracks;
      case 'All':
      default:
        return CuratedTracks.madeForYouTracks;
    }
  }

  String _getCarousel2Title() {
    switch (_activeFilter) {
      case 'Trending':
        return 'Viral Today';
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
        return 'Trending & New For You';
    }
  }

  List<YoutubeTrack> _getCarousel2Tracks() {
    switch (_activeFilter) {
      case 'Trending':
        return CuratedTracks.madeForYouTracks;
      case 'Chill':
        return CuratedTracks.madeForYouTracks;
      case 'Late Night':
        return CuratedTracks.chillTracks;
      case 'Workout':
        return CuratedTracks.trendingTracks;
      case 'Focus':
        return CuratedTracks.chillTracks;
      case 'All':
      default:
        return CuratedTracks.trendingTracks;
    }
  }

  /// 2x3 Grid of Compact Glass-Tinted Tiles
  Widget _buildQuickPickGrid(
    BuildContext context,
    AudioProvider audioProvider,
  ) {
    final tracks = CuratedTracks.getTracksForFilter(_activeFilter).take(6).toList();

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
                    child: CachedNetworkImage(
                      imageUrl: track.thumbnailUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 120,
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
                CuratedTracks.trendingTracks,
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
    final userFavs = TasteEngine.favoriteArtists;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      itemCount: userFavs.length + 1,
      separatorBuilder: (_, __) => const SizedBox(width: 16),
      itemBuilder: (context, index) {
        if (index == 0) {
          // Add Artist Pill
          return GestureDetector(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ArtistOnboardingScreen(isModal: true)),
              );
              setState(() {});
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
                  'Add More',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          );
        }

        final artist = userFavs[index - 1];
        return GestureDetector(
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
                          fit: BoxFit.cover,
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

  Widget _buildArtistAvatarFallback(String name) {
    return Container(
      color: AppColors.surface2,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'A',
          style: const TextStyle(color: AppColors.primarySoft, fontWeight: FontWeight.bold, fontSize: 20),
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
                        child: t.thumbnailUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: t.thumbnailUrl,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  width: 44,
                                  height: 44,
                                  color: AppColors.surface2,
                                  child: const Icon(Icons.music_note, color: AppColors.primarySoft),
                                ),
                              )
                            : Container(
                                width: 44,
                                height: 44,
                                color: AppColors.surface2,
                                child: const Icon(Icons.music_note, color: AppColors.primarySoft),
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
