import 'dart:ui';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/audio_provider.dart';
import '../core/services/audio_cache_service.dart';
import '../core/services/artwork_palette_service.dart';
import '../core/services/lyrics_service.dart';
import '../core/services/lyrics_transliteration_service.dart';
import '../core/services/taste_engine.dart';
import '../core/utils/numeric_utils.dart';
import '../features/music/models/music_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../widgets/cascading_artwork.dart';

/// Premium Spotify-style Full-Screen Now Playing Screen
/// Incorporates dynamic artwork color palette, 10-section layout,
/// synced lyrics card, sticky mini header, and artist exploration.
class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showMiniHeader = false;
  bool _bioExpanded = false;
  bool _showPromoSlot = true;
  bool _showHindiLyrics = false;

  // Dynamic Palette State
  ExtractedPalette _palette = ExtractedPalette.defaultDark;
  String? _paletteTrackId;

  // Synced Lyrics State
  DualLyricsResult? _dualLyrics;
  bool _isLoadingLyrics = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTrackData();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final shouldShow = offset > 240;
    if (shouldShow != _showMiniHeader) {
      setState(() => _showMiniHeader = shouldShow);
    }
  }

  void _loadTrackData() {
    final audio = context.read<AudioProvider>();
    final track = audio.currentTrack;
    if (track == null) return;

    if (_paletteTrackId != track.id) {
      _paletteTrackId = track.id;
      // 1. Instant synchronous fallback palette
      _palette = ArtworkPaletteService.getPaletteSync(track.id, track.title, track.artist);
      setState(() {});

      // 2. Asynchronous vibrant extraction from cover art
      ArtworkPaletteService.getPalette(
        track.id,
        track.thumbnailUrl,
        track.title,
        track.artist,
      ).then((p) {
        if (mounted && _paletteTrackId == track.id) {
          setState(() => _palette = p);
        }
      });

      // 3. Load synced lyrics
      _fetchLyrics(track);
    }
  }

  Future<void> _fetchLyrics(YoutubeTrack track) async {
    setState(() => _isLoadingLyrics = true);
    final raw = await LyricsService.fetchLyrics(
      trackId: track.id,
      title: track.title,
      artist: track.artist,
      durationSeconds: safeDuration(track.durationSeconds, fallback: 240),
    );

    final dual = await LyricsTransliterationService.processLyrics(
      trackId: track.id,
      title: track.title,
      artist: track.artist,
      rawResult: raw,
    );

    if (mounted && _paletteTrackId == track.id) {
      setState(() {
        _dualLyrics = dual;
        _isLoadingLyrics = false;
      });
    }
  }

  bool _isUrduOrArabic(String text) {
    return RegExp(r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]').hasMatch(text);
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();
    final track = audio.currentTrack;

    if (track == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Center(
          child: Text(
            'No song currently playing',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    if (_paletteTrackId != track.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadTrackData());
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final heroSize = (screenWidth - 48.0).clamp(240.0, 360.0);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          // Dynamic Atmospheric Gradient Backdrop (Animated over 400ms)
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _palette.backgroundTop,
                  _palette.backgroundBottom,
                  const Color(0xFF121212),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),

          // Main Scrollable Now Playing Content
          SafeArea(
            bottom: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // Top Navigation Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 32),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Column(
                        children: [
                          Text(
                            'PLAYING FROM PLAYLIST',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.album != null && track.album!.isNotEmpty ? track.album! : 'Twilight Mix',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 24),
                        onPressed: () => _showTrackOptions(context, track, audio),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // SECTION 1: HERO ARTWORK
                  Center(
                    child: Container(
                      key: ValueKey('now_playing_hero_${track.id}'),
                      width: heroSize,
                      height: heroSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.65),
                            blurRadius: 36,
                            offset: const Offset(0, 16),
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: _palette.dominant.withValues(alpha: 0.25),
                            blurRadius: 40,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CascadingArtwork(
                              key: ValueKey('hero_art_${track.id}'),
                              trackId: track.id,
                              imageUrl: track.thumbnailUrl,
                              title: track.title,
                              artist: track.artist,
                              width: heroSize,
                              height: heroSize,
                              borderRadius: BorderRadius.circular(12),
                              fit: BoxFit.cover,
                            ),
                            // Subtle Series / Live Badge Overlay
                            Positioned(
                              bottom: 12,
                              left: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // SECTION 2: TITLE ROW (With Library Add Circle)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFFB3B3B3),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Selector<AudioProvider, bool>(
                        selector: (_, ap) => ap.isTrackLiked(track.id),
                        builder: (context, isLiked, _) {
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              audio.toggleFavorite(track);
                            },
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isLiked ? const Color(0xFF1DB954) : Colors.transparent,
                                border: Border.all(
                                  color: isLiked ? const Color(0xFF1DB954) : const Color(0xFFB3B3B3),
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                isLiked ? Icons.check_rounded : Icons.add_rounded,
                                color: isLiked ? Colors.black : Colors.white,
                                size: 22,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // SECTION 3: PROGRESS BAR (Isolated Rebuild with Safe Math)
                  const _AudioProgressBar(),

                  const SizedBox(height: 16),

                  // SECTION 4: MAIN CONTROLS & UTILITIES ROW
                  _buildMainControls(audio),

                  const SizedBox(height: 24),

                  // SECTION 5: SYNCED LYRICS CARD
                  _buildLyricsCard(context, track, audio),

                  const SizedBox(height: 24),

                  // SECTION 6: ADVERTISEMENT / PROMO SLOT
                  if (_showPromoSlot) _buildPromoSlot(),

                  if (_showPromoSlot) const SizedBox(height: 24),

                  // SECTION 7: ABOUT THE ARTIST
                  _buildArtistCard(track),

                  const SizedBox(height: 24),

                  // SECTION 8: CREDITS
                  _buildCreditsSection(context, track),

                  const SizedBox(height: 24),

                  // SECTION 9: EXPLORE CAROUSEL
                  _buildExploreCarousel(context, track, audio),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),

          // SECTION 10: STICKY MINI HEADER (Animated Slide + Fade)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildStickyMiniHeader(context, track, audio),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 4: CONTROLS BUILDER
  // ===========================================================================
  Widget _buildMainControls(AudioProvider audio) {
    return Column(
      children: [
        // Primary Playback Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Shuffle
            Selector<AudioProvider, bool>(
              selector: (_, ap) => ap.isShuffle,
              builder: (context, isShuffle, _) {
                return IconButton(
                  icon: Icon(
                    Icons.shuffle_rounded,
                    size: 26,
                    color: isShuffle ? const Color(0xFF1DB954) : const Color(0xFFB3B3B3),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    audio.toggleShuffle();
                  },
                );
              },
            ),

            // Previous
            IconButton(
              icon: const Icon(Icons.skip_previous_rounded, size: 38, color: Colors.white),
              onPressed: () {
                HapticFeedback.lightImpact();
                audio.playPrevious();
              },
            ),

            // Play / Pause Large White Circle Button
            Selector<AudioProvider, (bool, bool)>(
              selector: (_, ap) => (ap.isPlaying, ap.isBuffering),
              builder: (context, state, _) {
                final (isPlaying, isBuffering) = state;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    audio.togglePlayPause();
                  },
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: isBuffering
                          ? const SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.8,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                            )
                          : Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 38,
                              color: Colors.black,
                            ),
                    ),
                  ),
                );
              },
            ),

            // Next
            IconButton(
              icon: const Icon(Icons.skip_next_rounded, size: 38, color: Colors.white),
              onPressed: () {
                HapticFeedback.lightImpact();
                audio.playNext();
              },
            ),

            // Sleep Timer / Repeat Toggle
            Selector<AudioProvider, (RepeatMode, bool)>(
              selector: (_, ap) => (ap.repeatMode, ap.hasActiveSleepTimer),
              builder: (context, data, _) {
                final (repeat, hasTimer) = data;
                final isTimerActive = hasTimer;
                return IconButton(
                  icon: Icon(
                    isTimerActive ? Icons.timer_rounded : Icons.repeat_rounded,
                    size: 26,
                    color: (repeat != RepeatMode.off || isTimerActive)
                        ? const Color(0xFF1DB954)
                        : const Color(0xFFB3B3B3),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _showSleepTimerDialog(context, audio);
                  },
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Secondary Utilities Row (Device, Share, Queue)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Device / Cast Badge
            Row(
              children: [
                const Icon(Icons.speaker_group_outlined, size: 18, color: Color(0xFF1DB954)),
                const SizedBox(width: 6),
                Text(
                  'Lossless Stream • 320 kbps',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),

            Row(
              children: [
                // Share
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 20, color: Color(0xFFB3B3B3)),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    final current = audio.currentTrack;
                    if (current != null) {
                      Clipboard.setData(ClipboardData(text: 'Listening to "${current.title}" by ${current.artist} on Music App'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Song link copied to clipboard'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                ),

                // Queue Trigger with count badge
                GestureDetector(
                  onTap: () => _showQueueSheet(context, audio),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.queue_music_rounded, size: 18, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          '${audio.playlistQueue.length}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // SECTION 5: SYNCED LYRICS CARD
  // ===========================================================================
  Widget _buildLyricsCard(BuildContext context, YoutubeTrack track, AudioProvider audio) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _palette.lyricsCardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Lyrics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_dualLyrics != null && _dualLyrics!.isHindiOrUrdu)
                GestureDetector(
                  onTap: () => setState(() => _showHindiLyrics = !_showHindiLyrics),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _showHindiLyrics ? 'Roman Lyrics' : 'Hindi Meaning',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          if (_isLoadingLyrics)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 36.0),
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            )
          else if (_dualLyrics == null || !_dualLyrics!.hasLyrics)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text(
                  'Lyrics not available for this track',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                ),
              ),
            )
          else
            Selector<AudioProvider, Duration>(
              selector: (_, ap) => ap.position,
              builder: (context, position, _) {
                final lines = _dualLyrics!.lines;
                final activeIdx = _findActiveLyricIndex(position, lines);

                // Show 5 lines centered around active line
                final startIdx = (activeIdx - 2).clamp(0, lines.length - 1);
                final endIdx = (activeIdx + 3).clamp(0, lines.length);
                final previewLines = lines.sublist(startIdx, endIdx);

                return Column(
                  children: previewLines.map((line) {
                    final isCurrent = lines.indexOf(line) == activeIdx;
                    final displayText = (_showHindiLyrics && line.meaningText != null)
                        ? line.meaningText!
                        : line.mainText;
                    final isUrdu = _isUrduOrArabic(displayText);

                    return GestureDetector(
                      onTap: () => audio.seekTo(line.timestamp),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7.0),
                        child: Text(
                          displayText,
                          textAlign: TextAlign.center,
                          textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
                          style: TextStyle(
                            color: isCurrent ? Colors.white : Colors.white.withValues(alpha: 0.45),
                            fontSize: isCurrent ? 18 : 15,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                            height: 1.6,
                            decoration: isCurrent ? TextDecoration.underline : TextDecoration.none,
                            decorationColor: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

          const SizedBox(height: 16),

          // White Pill "Show lyrics" button (Opens Full Screen Lyrics)
          GestureDetector(
            onTap: () => _openFullScreenLyrics(context, track, audio),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Show lyrics',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _findActiveLyricIndex(Duration position, List<DualLyricLine> lines) {
    if (lines.isEmpty) return 0;
    for (int i = lines.length - 1; i >= 0; i--) {
      if (position >= lines[i].timestamp) {
        return i;
      }
    }
    return 0;
  }

  // ===========================================================================
  // SECTION 6: ADVERTISEMENT / PROMO SLOT (Internal Content Only)
  // ===========================================================================
  Widget _buildPromoSlot() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PROMOTED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showPromoSlot = false),
                child: Icon(Icons.close_rounded, size: 16, color: Colors.white.withValues(alpha: 0.6)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _palette.dominant.withValues(alpha: 0.7),
                    const Color(0xFF121212),
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 36),
                  SizedBox(width: 12),
                  Text(
                    'Twilight Studio Master\nLossless 320 kbps Streaming',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Ultra-low latency audio with zero compression.',
                  style: TextStyle(color: Color(0xFFB3B3B3), fontSize: 12),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Listen now',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 7: ABOUT THE ARTIST
  // ===========================================================================
  Widget _buildArtistCard(YoutubeTrack track) {
    final artistProfile = TasteEngine.getArtistProfile(track.artist, fallbackImage: track.thumbnailUrl);
    final isFollowed = TasteEngine.isArtistFavorite(artistProfile.name);
    final listenerCount = '${((track.artist.hashCode.abs() % 35 + 10) / 10).toStringAsFixed(1)}M';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About the artist',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Wide Artist Photo Banner with Gradient Overlay
              SizedBox(
                height: 180,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (artistProfile.imageUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: artistProfile.imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(color: _palette.dominant),
                      )
                    else
                      Container(color: _palette.dominant),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            const Color(0xFF1E1E1E).withValues(alpha: 0.95),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  artistProfile.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.verified_rounded, color: Color(0xFF1DB954), size: 18),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$listenerCount monthly listeners',
                              style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 13),
                            ),
                          ],
                        ),

                        // Follow / Following Pill Button (Optimistic update)
                        GestureDetector(
                          onTap: () async {
                            HapticFeedback.selectionClick();
                            final newState = await TasteEngine.toggleArtist(artistProfile);
                            setState(() {});
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(newState ? 'Following ${artistProfile.name}' : 'Unfollowed ${artistProfile.name}'),
                                  duration: const Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              color: isFollowed ? Colors.transparent : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isFollowed ? const Color(0xFFB3B3B3) : Colors.white,
                              ),
                            ),
                            child: Text(
                              isFollowed ? 'Following' : 'Follow',
                              style: TextStyle(
                                color: isFollowed ? Colors.white : Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Bio with Expandable "see more" link
                    Text(
                      _bioExpanded
                          ? '${artistProfile.name} is a celebrated vocal powerhouse known for iconic studio tracks, soul-stirring live performances, and multi-platinum records across South Asian and international charts.'
                          : '${artistProfile.name} is a celebrated vocal powerhouse known for iconic studio tracks...',
                      style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => setState(() => _bioExpanded = !_bioExpanded),
                      child: Text(
                        _bioExpanded ? 'see less' : 'see more',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SECTION 8: CREDITS
  // ===========================================================================
  Widget _buildCreditsSection(BuildContext context, YoutubeTrack track) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Credits',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () => _showAllCreditsSheet(context, track),
                child: const Text(
                  'Show all',
                  style: TextStyle(color: Color(0xFF1DB954), fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCreditRow(track.artist, 'Main Artist, Vocals', hasFollow: true),
          const SizedBox(height: 12),
          _buildCreditRow('Original Composition', 'Composer & Author'),
          const SizedBox(height: 12),
          _buildCreditRow('Twilight Sound Labs', 'Producer, Audio Engineering'),
        ],
      ),
    );
  }

  Widget _buildCreditRow(String name, String role, {bool hasFollow = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            Text(role, style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 12)),
          ],
        ),
        if (hasFollow)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFB3B3B3)),
            ),
            child: const Text('Follow', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  void _showAllCreditsSheet(BuildContext context, YoutubeTrack track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Credits', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildCreditRow(track.artist, 'Primary Performer & Vocalist'),
              const Divider(color: Colors.white12, height: 24),
              _buildCreditRow('Coke Studio & Artists', 'Lyricist & Music Arrangement'),
              const Divider(color: Colors.white12, height: 24),
              _buildCreditRow('Master Lossless 320 kbps', 'Mixing & Audio Mastering'),
              const Divider(color: Colors.white12, height: 24),
              _buildCreditRow('Twilight Calm Platform', 'Digital Audio Distribution'),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // SECTION 9: EXPLORE CAROUSEL
  // ===========================================================================
  Widget _buildExploreCarousel(BuildContext context, YoutubeTrack track, AudioProvider audio) {
    final exploreCards = [
      {'title': 'Songs by ${track.artist}', 'query': '${track.artist} top songs'},
      {'title': 'More from Coke Studio', 'query': 'Coke Studio Season trending songs'},
      {'title': 'Similar to ${track.title}', 'query': '${track.title} similar song'},
      {'title': 'Top Chartbusters', 'query': 'trending hits billboard 2026'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Explore ${track.artist}',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: exploreCards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (ctx, i) {
              final card = exploreCards[i];
              return GestureDetector(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  final songs = await audio.musicService.searchTracks(card['query']!);
                  if (songs.isNotEmpty) {
                    await audio.playTrack(songs.first, songs);
                  }
                },
                child: Container(
                  width: 140,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CascadingArtwork(
                        key: ValueKey('explore_art_${card['query']}'),
                        trackId: track.id,
                        imageUrl: track.thumbnailUrl,
                        title: card['title']!,
                        artist: track.artist,
                        width: 140,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 10,
                        right: 10,
                        child: Text(
                          card['title']!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SECTION 10: STICKY MINI HEADER (Animated Slide & Fade)
  // ===========================================================================
  Widget _buildStickyMiniHeader(BuildContext context, YoutubeTrack track, AudioProvider audio) {
    return AnimatedSlide(
      offset: _showMiniHeader ? Offset.zero : const Offset(0, -1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _showMiniHeader ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          decoration: BoxDecoration(
            color: _palette.headerColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 28),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFB3B3B3),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Selector<AudioProvider, bool>(
                        selector: (_, ap) => ap.isTrackLiked(track.id),
                        builder: (context, isLiked, _) {
                          return IconButton(
                            icon: Icon(
                              isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: isLiked ? const Color(0xFF1DB954) : Colors.white70,
                              size: 22,
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              audio.toggleFavorite(track);
                            },
                          );
                        },
                      ),
                      Selector<AudioProvider, bool>(
                        selector: (_, ap) => ap.isPlaying,
                        builder: (context, isPlaying, _) {
                          return IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              audio.togglePlayPause();
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Thin Progress Line along bottom edge
                Selector<AudioProvider, (Duration, Duration)>(
                  selector: (_, ap) => (ap.position, ap.duration),
                  builder: (context, data, _) {
                    final (pos, dur) = data;
                    final progress = safeProgress(pos.inMilliseconds, dur.inMilliseconds);
                    return LinearProgressIndicator(
                      value: progress,
                      minHeight: 2.0,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1DB954)),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // FULL SCREEN LYRICS MODAL VIEW
  // ===========================================================================
  void _openFullScreenLyrics(BuildContext context, YoutubeTrack track, AudioProvider audio) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.60,
          maxChildSize: 0.98,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: _palette.lyricsCardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  Expanded(
                    child: _dualLyrics == null || !_dualLyrics!.hasLyrics
                        ? const Center(
                            child: Text('Lyrics not available', style: TextStyle(color: Colors.white70)),
                          )
                        : Selector<AudioProvider, Duration>(
                            selector: (_, ap) => ap.position,
                            builder: (context, pos, _) {
                              final lines = _dualLyrics!.lines;
                              final active = _findActiveLyricIndex(pos, lines);

                              return ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                itemCount: lines.length,
                                itemBuilder: (context, index) {
                                  final line = lines[index];
                                  final isCurrent = index == active;
                                  final text = (_showHindiLyrics && line.meaningText != null)
                                      ? line.meaningText!
                                      : line.mainText;
                                  final isUrdu = _isUrduOrArabic(text);

                                  return GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      audio.seekTo(line.timestamp);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                                      child: Text(
                                        text,
                                        textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
                                        style: TextStyle(
                                          color: isCurrent ? Colors.white : Colors.white.withValues(alpha: 0.40),
                                          fontSize: isCurrent ? 24 : 18,
                                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                          height: 1.6,
                                          decoration: isCurrent ? TextDecoration.underline : TextDecoration.none,
                                          decorationColor: Colors.white.withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ),
                                  );
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
  }

  // ===========================================================================
  // SLEEP TIMER & QUEUE SHEETS
  // ===========================================================================
  void _showSleepTimerDialog(BuildContext context, AudioProvider audio) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sleep Timer', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('15 Minutes', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    audio.setSleepTimer(15);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  title: const Text('30 Minutes', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    audio.setSleepTimer(30);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  title: const Text('45 Minutes', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    audio.setSleepTimer(45);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  title: const Text('60 Minutes', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    audio.setSleepTimer(60);
                    Navigator.pop(ctx);
                  },
                ),
                if (audio.hasActiveSleepTimer)
                  ListTile(
                    title: const Text('Turn Off Timer', style: TextStyle(color: Colors.redAccent)),
                    onTap: () {
                      audio.cancelSleepTimer();
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQueueSheet(BuildContext context, AudioProvider audioProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.70,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Queue', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('${audioProvider.playlistQueue.length} Tracks', style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 13)),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: audioProvider.playlistQueue.length,
                  itemBuilder: (context, index) {
                    final qTrack = audioProvider.playlistQueue[index];
                    final isCurrent = audioProvider.currentTrack?.id == qTrack.id;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: CascadingArtwork(
                            key: ValueKey('queue_art_${qTrack.id}'),
                            trackId: qTrack.id,
                            imageUrl: qTrack.thumbnailUrl,
                            title: qTrack.title,
                            artist: qTrack.artist,
                            width: 44,
                            height: 44,
                          ),
                        ),
                      ),
                      title: Text(
                        qTrack.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrent ? const Color(0xFF1DB954) : Colors.white,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        qTrack.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 12),
                      ),
                      trailing: isCurrent
                          ? const Icon(Icons.volume_up_rounded, color: Color(0xFF1DB954), size: 20)
                          : null,
                      onTap: () {
                        audioProvider.playTrack(qTrack, audioProvider.playlistQueue);
                        Navigator.pop(context);
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

  void _showTrackOptions(BuildContext context, YoutubeTrack track, AudioProvider audioProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded, color: Colors.white),
                title: const Text('Add to Playlist', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showAddToPlaylistSheet(context, track, audioProvider);
                },
              ),
              ListTile(
                leading: const Icon(Icons.high_quality_rounded, color: Color(0xFF1DB954)),
                title: const Text('Audio Quality: Ultra Lossless (320 kbps)', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Direct Master Stream • Pure CD Quality', style: TextStyle(color: Color(0xFFB3B3B3), fontSize: 12)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddToPlaylistSheet(BuildContext context, YoutubeTrack track, AudioProvider audioProvider) {
    final playlists = audioProvider.userPlaylists.keys.toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add to Playlist', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (playlists.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(child: Text('No playlists created yet', style: TextStyle(color: Color(0xFFB3B3B3)))),
                  )
                else
                  ...playlists.map(
                    (pName) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.playlist_play_rounded, color: Color(0xFF1DB954)),
                      title: Text(pName, style: const TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(ctx);
                        audioProvider.addTrackToPlaylist(pName, track);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added to "$pName"'), duration: const Duration(seconds: 1)),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Dedicated Audio Progress Bar widget with isolated rebuild and safe math.
class _AudioProgressBar extends StatelessWidget {
  const _AudioProgressBar();

  String _formatTime(Duration duration) {
    final totalSec = safeInt(duration.inSeconds, fallback: 0);
    if (totalSec <= 0) return '0:00';
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.read<AudioProvider>();

    return Selector<AudioProvider, (Duration, Duration, Duration)>(
      selector: (_, ap) => (ap.position, ap.bufferedPosition, ap.duration),
      builder: (context, data, _) {
        final (pos, buf, dur) = data;
        final safeTotalMs = safeInt(dur.inMilliseconds, fallback: 0);
        final safePosMs = safeInt(pos.inMilliseconds, fallback: 0);
        final safeBufMs = safeInt(buf.inMilliseconds, fallback: 0);

        final totalDuration = safeTotalMs > 0 ? Duration(milliseconds: safeTotalMs) : Duration.zero;
        final position = safePosMs > 0 ? Duration(milliseconds: safePosMs.clamp(0, safeTotalMs > 0 ? safeTotalMs : safePosMs)) : Duration.zero;
        final buffered = safeBufMs > 0 ? Duration(milliseconds: safeBufMs.clamp(0, safeTotalMs > 0 ? safeTotalMs : safeBufMs)) : Duration.zero;

        return ProgressBar(
          progress: position,
          buffered: buffered,
          total: totalDuration,
          onSeek: totalDuration.inSeconds > 0 ? (d) => audio.seekTo(d) : null,
          baseBarColor: Colors.white.withValues(alpha: 0.18),
          bufferedBarColor: Colors.white.withValues(alpha: 0.35),
          progressBarColor: Colors.white,
          thumbColor: Colors.white,
          thumbGlowColor: Colors.white.withValues(alpha: 0.25),
          thumbRadius: 5.5,
          barHeight: 3.5,
          timeLabelTextStyle: const TextStyle(
            color: Color(0xFFB3B3B3),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        );
      },
    );
  }
}
