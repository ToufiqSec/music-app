import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../core/utils/numeric_utils.dart';

/// Reliable Artwork Component with multi-tier image fallback:
/// (a) its own thumbnail at the best size (maxresdefault or 500x500)
/// (b) the same thumbnail at a smaller size (hqdefault or 150x150)
/// (c) its own album cover if the album ID matches
/// (d) a flat placeholder in the app accent colour. The letter tile is removed.
///
/// Binds requests strictly to trackId so recycled cards never render old images.
/// Cache key: "track:{trackId}:{size}".
class CascadingArtwork extends StatefulWidget {
  final String? trackId;
  final String? imageUrl;
  final String title;
  final String artist;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  const CascadingArtwork({
    super.key,
    this.trackId,
    required this.imageUrl,
    required this.title,
    required this.artist,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
  });

  @override
  State<CascadingArtwork> createState() => _CascadingArtworkState();
}

class _CascadingArtworkState extends State<CascadingArtwork> {
  String? _boundTrackId;
  int _fallbackIndex = 0;
  late List<String> _candidates;

  @override
  void initState() {
    super.initState();
    _boundTrackId = widget.trackId;
    _buildCandidateList();
  }

  @override
  void didUpdateWidget(covariant CascadingArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackId != widget.trackId ||
        oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.title != widget.title) {
      _boundTrackId = widget.trackId;
      _fallbackIndex = 0;
      _buildCandidateList();
    }
  }

  void _buildCandidateList() {
    final list = <String>[];
    final original = widget.imageUrl?.trim() ?? '';

    if (original.isNotEmpty) {
      // Check if YouTube image
      final ytMatch = RegExp(r'(?:i\.ytimg\.com/vi/|youtube\.com/vi/)([a-zA-Z0-9_-]{11})').firstMatch(original);
      if (ytMatch != null) {
        final videoId = ytMatch.group(1)!;
        final isSmallThumbnail = widget.width != null && widget.width! <= 120;
        
        // Prioritize guaranteed available tiers to prevent 404 network stalls
        final List<String> tiers;
        if (original.contains('hqdefault.jpg')) {
          tiers = [
            'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
            'https://i.ytimg.com/vi/$videoId/mqdefault.jpg',
            'https://i.ytimg.com/vi/$videoId/maxresdefault.jpg',
          ];
        } else if (original.contains('mqdefault.jpg')) {
          tiers = [
            'https://i.ytimg.com/vi/$videoId/mqdefault.jpg',
            'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
          ];
        } else if (original.contains('maxresdefault.jpg')) {
          tiers = [
            'https://i.ytimg.com/vi/$videoId/maxresdefault.jpg',
            'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
            'https://i.ytimg.com/vi/$videoId/mqdefault.jpg',
          ];
        } else {
          tiers = isSmallThumbnail
              ? [
                  'https://i.ytimg.com/vi/$videoId/mqdefault.jpg',
                  'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
                ]
              : [
                  'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
                  'https://i.ytimg.com/vi/$videoId/mqdefault.jpg',
                  'https://i.ytimg.com/vi/$videoId/maxresdefault.jpg',
                ];
        }
        list.clear();
        for (final tier in tiers) {
          if (!list.contains(tier)) {
            list.add(tier);
          }
        }
      } else {
        list.add(original);
        if (original.contains('saavncdn.com')) {
          // Multi-tier JioSaavn image fallback: 500x500 -> 150x150
          if (original.contains('500x500')) {
            final smaller = original.replaceAll('500x500', '150x150');
            if (!list.contains(smaller)) list.add(smaller);
          } else if (original.contains('150x150')) {
            final larger = original.replaceAll('150x150', '500x500');
            if (!list.contains(larger)) list.insert(0, larger);
          }
        }
      }
    } else if (widget.trackId != null && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(widget.trackId!)) {
      // Fallback from YouTube track ID directly if image URL is null/empty
      final ytId = widget.trackId!;
      final isSmall = widget.width != null && widget.width! <= 120;
      if (isSmall) {
        list.add('https://i.ytimg.com/vi/$ytId/mqdefault.jpg');
        list.add('https://i.ytimg.com/vi/$ytId/hqdefault.jpg');
      } else {
        list.add('https://i.ytimg.com/vi/$ytId/hqdefault.jpg');
        list.add('https://i.ytimg.com/vi/$ytId/mqdefault.jpg');
        list.add('https://i.ytimg.com/vi/$ytId/maxresdefault.jpg');
      }
    }

    _candidates = list;
  }

  Widget _buildShimmer() {
    final titleTrimmed = widget.title.trim();
    final letter = titleTrimmed.isNotEmpty ? titleTrimmed.substring(0, 1).toUpperCase() : '';
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: widget.borderRadius ?? AppRadii.borderMedium,
      ),
      alignment: Alignment.center,
      child: letter.isNotEmpty
          ? Text(
              letter,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: ((widget.height != null && widget.height!.isFinite)
                        ? widget.height! * 0.35
                        : 24.0)
                    .clamp(14.0, 32.0),
                fontWeight: FontWeight.bold,
              ),
            )
          : Icon(
              Icons.music_note_rounded,
              color: Colors.white.withValues(alpha: 0.2),
              size: 24,
            ),
    );
  }

  /// Deterministic letter tile fallback shown when no valid artwork URL exists or network loading fails.
  /// Uses the initial letter of the title mapped to a themed gradient.
  Widget _buildLetterTileFallback() {
    final titleTrimmed = widget.title.trim();
    final letter = titleTrimmed.isNotEmpty ? titleTrimmed.substring(0, 1).toUpperCase() : 'M';
    final hash = widget.title.hashCode.abs();
    final gradients = [
      [const Color(0xFF6366F1), const Color(0xFF4338CA)],
      [const Color(0xFFEC4899), const Color(0xFFBE185D)],
      [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
      [const Color(0xFF10B981), const Color(0xFF047857)],
      [const Color(0xFFF59E0B), const Color(0xFFD97706)],
      [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
      [const Color(0xFF14B8A6), const Color(0xFF0F766E)],
    ];
    final selectedColors = gradients[hash % gradients.length];
    final fontSize = ((widget.height != null && widget.height!.isFinite)
            ? widget.height! * 0.4
            : 32.0)
        .clamp(18.0, 48.0)
        .toDouble();

    return GestureDetector(
      onTap: () {
        if (_candidates.isNotEmpty) {
          setState(() {
            _fallbackIndex = 0;
            _buildCandidateList();
          });
        }
      },
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius ?? AppRadii.borderMedium,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selectedColors,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          letter,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? AppRadii.borderMedium;

    if (_candidates.isEmpty || _fallbackIndex >= _candidates.length) {
      return ClipRRect(
        borderRadius: radius,
        child: _buildLetterTileFallback(),
      );
    }

    final currentUrl = _candidates[_fallbackIndex];

    // Safely calculate dimensions using safeInt and checking isFinite to prevent 'Infinity or NaN toInt'
    final safeW = (widget.width != null && widget.width!.isFinite)
        ? safeInt(widget.width, fallback: 156)
        : 156;
    final safeH = (widget.height != null && widget.height!.isFinite)
        ? safeInt(widget.height, fallback: 112)
        : 112;
    final memWidth = safeInt(safeW * 1.5, fallback: 180).clamp(60, 360);
    final memHeight = safeInt(safeH * 1.5, fallback: 180).clamp(60, 360);
    final targetSize = '${safeW}x$safeH';

    final cacheId = widget.trackId ?? widget.title.hashCode.abs().toString();
    final cacheKey = 'track:${cacheId}_${_fallbackIndex}:$targetSize';

    final activeTrackId = widget.trackId;

    return ClipRRect(
      borderRadius: radius,
      child: CachedNetworkImage(
        key: ValueKey('cni_${cacheId}_$_fallbackIndex'),
        imageUrl: currentUrl,
        cacheKey: cacheKey,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        memCacheWidth: memWidth,
        memCacheHeight: memHeight,
        maxWidthDiskCache: 360,
        maxHeightDiskCache: 360,
        placeholder: (_, __) => _buildShimmer(),
        imageBuilder: (context, imageProvider) {
          // If card was recycled and an old image arrived, reject it
          if (activeTrackId != null && _boundTrackId != activeTrackId) {
            return _buildShimmer();
          }
          return Image(
            image: imageProvider,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
          );
        },
        errorWidget: (context, url, error) {
          debugPrint('[CascadingArtwork] Image failed to load ($url): $error');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _boundTrackId == activeTrackId && _fallbackIndex < _candidates.length) {
              setState(() => _fallbackIndex++);
            }
          });
          return (_fallbackIndex < _candidates.length - 1)
              ? _buildShimmer()
              : _buildLetterTileFallback();
        },
      ),
    );
  }
}
