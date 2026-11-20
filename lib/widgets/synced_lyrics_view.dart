import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/audio_provider.dart';
import '../core/services/lyrics_service.dart';
import '../core/services/lyrics_transliteration_service.dart';
import '../features/music/models/music_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_shadows.dart';

class SyncedLyricsView extends StatefulWidget {
  final YoutubeTrack track;

  const SyncedLyricsView({super.key, required this.track});

  @override
  State<SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<SyncedLyricsView> {
  final ScrollController _scrollController = ScrollController();
  DualLyricsResult? _dualResult;
  bool _isLoading = true;
  bool _userScrolled = false;
  bool _showOriginalScript = false;
  Timer? _resumeAutoScrollTimer;
  int _lastActiveIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  @override
  void didUpdateWidget(covariant SyncedLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != widget.track.id) {
      _loadLyrics();
    }
  }

  @override
  void dispose() {
    _resumeAutoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLyrics() async {
    setState(() {
      _isLoading = true;
      _userScrolled = false;
      _lastActiveIndex = -1;
    });

    final rawRes = await LyricsService.fetchLyrics(
      trackId: widget.track.id,
      title: widget.track.title,
      artist: widget.track.artist,
      durationSeconds: widget.track.durationSeconds,
    );

    final dualRes = await LyricsTransliterationService.processLyrics(
      trackId: widget.track.id,
      title: widget.track.title,
      artist: widget.track.artist,
      rawResult: rawRes,
    );

    if (mounted) {
      setState(() {
        _dualResult = dualRes;
        _isLoading = false;
      });
    }
  }

  int _findActiveIndex(Duration position, List<DualLyricLine> lines) {
    if (lines.isEmpty) return -1;
    for (int i = lines.length - 1; i >= 0; i--) {
      if (position >= lines[i].timestamp) {
        return i;
      }
    }
    return 0;
  }

  void _scrollToActiveIndex(int index) {
    if (_userScrolled || !_scrollController.hasClients || index < 0) return;

    // Approximate offset: index * line height (~68 for dual lines) - half screen height
    final targetOffset = (index * 68.0) - 80.0;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.read<AudioProvider>();

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(color: AppColors.primarySoft, strokeWidth: 2),
            ),
            const SizedBox(height: 12),
            Text(
              'Finding synced lyrics & translations...',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    if (_dualResult == null || !_dualResult!.hasLyrics) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lyrics_outlined, color: AppColors.iconIdle, size: 36),
            const SizedBox(height: 10),
            Text(
              'Lyrics not available for this track',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Enjoy the pure lossless audio stream',
              style: AppTextStyles.meta.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    final lines = _dualResult!.lines;
    final isHindi = _dualResult!.isHindiOrUrdu;

    return Column(
      children: [
        // Top Script Toggle (Issue 4 Optional Requirement)
        if (isHindi)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _showOriginalScript = !_showOriginalScript);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surface2.withValues(alpha: 0.8),
                      borderRadius: AppRadii.borderPill,
                      border: Border.all(
                        color: AppColors.primarySoft.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showOriginalScript ? Icons.translate_rounded : Icons.subtitles_rounded,
                          size: 13,
                          color: AppColors.primarySoft,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _showOriginalScript ? 'Show Roman + Meaning' : 'Show Original Script',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primarySoft,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Main Lyrics Area
        Expanded(
          child: Selector<AudioProvider, Duration>(
            selector: (_, ap) => ap.position,
            builder: (context, pos, child) {
              final activeIndex = _findActiveIndex(pos, lines);

              if (activeIndex != _lastActiveIndex) {
                _lastActiveIndex = activeIndex;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToActiveIndex(activeIndex);
                });
              }

              return Stack(
                children: [
                  NotificationListener<ScrollNotification>(
                    onNotification: (scrollInfo) {
                      if (scrollInfo is UserScrollNotification) {
                        setState(() => _userScrolled = true);
                        _resumeAutoScrollTimer?.cancel();
                        _resumeAutoScrollTimer = Timer(const Duration(seconds: 4), () {
                          if (mounted) setState(() => _userScrolled = false);
                        });
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                      itemCount: lines.length,
                      itemBuilder: (context, index) {
                        final line = lines[index];
                        final isActive = index == activeIndex;
                        final isPast = index < activeIndex;

                        final displayText = _showOriginalScript ? line.originalText : line.mainText;
                        final meaningText = _showOriginalScript ? null : line.meaningText;

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            audioProvider.seekTo(line.timestamp);
                            setState(() => _userScrolled = false);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Line 1: Romanized English letters (Issue 4 Line 1)
                                Text(
                                  displayText,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.lyricsRoman.copyWith(
                                    fontSize: isActive ? 20 : 15,
                                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                    color: isActive
                                        ? Colors.white
                                        : isPast
                                            ? AppColors.textMuted
                                            : AppColors.textSecondary.withValues(alpha: 0.7),
                                    shadows: isActive
                                        ? [
                                            Shadow(
                                              color: AppColors.primarySoft.withValues(alpha: 0.8),
                                              blurRadius: 16,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),

                                // Line 2: Meaning in Hindi Devanagari (Issue 4 Line 2 - Smaller, lighter style)
                                if (meaningText != null && meaningText.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    meaningText,
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.lyricsDevanagari.copyWith(
                                      fontSize: isActive ? 13 : 11,
                                      fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
                                      color: isActive
                                          ? AppColors.primarySoft.withValues(alpha: 0.95)
                                          : AppColors.textMuted.withValues(alpha: 0.75),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // "Resume Sync" Floating Button when user manually scrolled
                  if (_userScrolled)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _userScrolled = false);
                            _scrollToActiveIndex(activeIndex);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: AppRadii.borderPill,
                              border: Border.all(color: AppColors.primarySoft.withValues(alpha: 0.5)),
                              boxShadow: [AppShadows.shadowSoft],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.sync_rounded, color: AppColors.primarySoft, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  'Resume Sync',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.primarySoft,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
