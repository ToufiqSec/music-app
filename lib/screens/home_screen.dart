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
import 'search_screen.dart';
import 'library_screen.dart';
import 'downloads_screen.dart';

/// Main Discovery Hub and Navigation Shell for Music App.
/// Universal UI Design System: Twilight Calm.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          // L0: Adaptive Base Page Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.pageGradient,
              ),
            ),
          ),

          // L1: Soft Ambient Hero Glow at top 35% with 450ms smooth transition
          Positioned(
            top: -60,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.38,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 0.9,
                  colors: [
                    AppColors.primarySoft.withValues(alpha: 0.18),
                    AppColors.primarySoft.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main Tabs Stack (Keeps state active and prevents playback interrupts)
          Positioned.fill(
            child: IndexedStack(
              index: _currentTabIndex,
              children: [
                _HomeDiscoveryView(
                  onNavigateToSearch: () => setState(() => _currentTabIndex = 1),
                ),
                const SearchScreen(),
                const LibraryScreen(),
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

                // 4-Tab Floating Bottom Navigation Bar
                TwilightBottomNavBar(
                  currentIndex: _currentTabIndex,
                  onTap: (index) => setState(() => _currentTabIndex = index),
                  icons: const [
                    Icons.home_filled,
                    Icons.search_rounded,
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

  const _HomeDiscoveryView({required this.onNavigateToSearch});

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
    final audioProvider = context.watch<AudioProvider>();

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
                      onTap: () => _showProfileDialog(context),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface2,
                          border: Border.all(
                            color: AppColors.primarySoft.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          size: 20,
                          color: AppColors.primarySoft,
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

          // 3. Quick-Pick 2x3 Grid ("Jump Back In")
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Jump Back In',
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

          // 4. Horizontal Card Carousel 1 ("Made For You")
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Made For You',
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
              itemCount: CuratedTracks.madeForYouTracks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final track = CuratedTracks.madeForYouTracks[index];
                return ContentCard(
                  title: track.title,
                  subtitle: track.artist,
                  imageUrl: track.thumbnailUrl,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    audioProvider.playTrack(
                      track,
                      CuratedTracks.madeForYouTracks,
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 28),

          // 5. Horizontal Card Carousel 2 ("Trending & New For You")
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Trending & New For You',
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
              itemCount: CuratedTracks.trendingTracks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final track = CuratedTracks.trendingTracks[index];
                return _buildTrendingCard(context, track, audioProvider);
              },
            ),
          ),

          const SizedBox(height: 28),

          // 6. Horizontal Circle Row ("Your Top Artists")
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Your Top Artists',
              style: AppTextStyles.h3.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 14),

          SizedBox(
            height: 110,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: CuratedTracks.topArtists.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final artist = CuratedTracks.topArtists[index];
                return _buildArtistCircle(artist);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 2x3 Grid of Compact Glass-Tinted Tiles
  Widget _buildQuickPickGrid(
    BuildContext context,
    AudioProvider audioProvider,
  ) {
    final tracks = CuratedTracks.jumpBackInTracks.take(6).toList();

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
  Widget _buildArtistCircle(Map<String, String> artist) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: const [AppShadows.shadowSoft],
            border: Border.all(
              color: AppColors.surface2,
              width: 1.5,
            ),
          ),
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: artist['image']!,
              fit: BoxFit.cover,
              memCacheWidth: 150,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          artist['name']!,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
                leading: const Icon(Icons.favorite_border_rounded, color: AppColors.iconIdle),
                title: Text('Like Song', style: AppTextStyles.bodyMedium),
                onTap: () => Navigator.pop(ctx),
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
        return Container(
          height: 300,
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
              Text('Listening History', style: AppTextStyles.h3),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: CuratedTracks.jumpBackInTracks.take(3).map((t) {
                    return ListTile(
                      leading: const Icon(Icons.music_note, color: AppColors.primarySoft),
                      title: Text(t.title, style: AppTextStyles.bodyMedium),
                      subtitle: Text(t.artist, style: AppTextStyles.caption),
                      onTap: () {
                        Navigator.pop(ctx);
                        audioProvider.playTrack(t);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface1,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.borderLarge,
          ),
          title: Text('Account & Settings', style: AppTextStyles.h3),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personal Music Vault',
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Audio Engine: Multi-Tier Zero-Delay\n• Tier 1: JioSaavn 320kbps DES-ECB\n• Tier 2: YouTube Audio Stream Extractor\n• Tier 3: Local Offline Cache',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Text(
                'Streaming Quality: 320 kbps Lossless\nAds: None (Pure Direct Stream)',
                style: AppTextStyles.caption.copyWith(color: AppColors.primarySoft),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primarySoft,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadii.borderPill,
                ),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Done',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
