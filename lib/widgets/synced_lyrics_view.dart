import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/audio_provider.dart';
import '../core/services/lyrics_service.dart';
import '../features/music/models/music_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

class SyncedLyricsView extends StatefulWidget {
  final YoutubeTrack track;

  const SyncedLyricsView({super.key, required this.track});

  @override
  State<SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<SyncedLyricsView> {
  final ScrollController _scrollController = ScrollController();
  LyricsResult? _lyricsResult;
  bool _isLoading = true;
  bool _userScrolled = false;
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

    final res = await LyricsService.fetchLyrics(
      trackId: widget.track.id,
      title: widget.track.title,
      artist: widget.track.artist,
      durationSeconds: widget.track.durationSeconds,
    );

    if (mounted) {
      setState(() {
        _lyricsResult = res;
        _isLoading = false;
      });
    }
  }

  int _findActiveIndex(Duration position, List<LyricLine> lines) {
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

    // Approximate offset: index * line height (~48) - half screen height
    final targetOffset = (index * 52.0) - 80.0;
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
              'Finding synced lyrics...',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    if (_lyricsResult == null || !_lyricsResult!.hasLyrics) {
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

    // Fallback: Plain unsynced lyrics
    if (!_lyricsResult!.isSynced) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: AppRadii.borderPill,
                ),
                child: Text(
                  'Plain Lyrics • Sync not available',
                  style: AppTextStyles.meta.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ),
            Text(
              _lyricsResult!.plainLyrics ?? '',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                height: 1.8,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    // Synced Karaoke Lyrics View
    final lines = _lyricsResult!.syncedLines;

    return Selector<AudioProvider, Duration>(
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
                itemCount: lines.length,
                itemBuilder: (context, index) {
                  final line = lines[index];
                  final isActive = index == activeIndex;
                  final isPast = index < activeIndex;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      audioProvider.seek(line.timestamp);
                      setState(() => _userScrolled = false);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      child: Text(
                        line.text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
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
                        boxShadow: const [AppShadows.shadowSoft],
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
    );
  }
}
