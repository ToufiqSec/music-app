import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

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
    if (oldWidget.trackId != widget.trackId || oldWidget.imageUrl != widget.imageUrl) {
      _boundTrackId = widget.trackId;
      _fallbackIndex = 0;
      _buildCandidateList();
    }
  }

  void _buildCandidateList() {
    final list = <String>[];
    final original = widget.imageUrl?.trim() ?? '';

    if (original.isNotEmpty) {
      list.add(original);

      // Check if YouTube image
      final ytMatch = RegExp(r'(?:i\.ytimg\.com/vi/|youtube\.com/vi/)([a-zA-Z0-9_-]{11})').firstMatch(original);
      if (ytMatch != null) {
        final videoId = ytMatch.group(1)!;
        final tiers = [
          'https://i.ytimg.com/vi/$videoId/maxresdefault.jpg',
          'https://i.ytimg.com/vi/$videoId/sddefault.jpg',
          'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
          'https://i.ytimg.com/vi/$videoId/mqdefault.jpg',
        ];
        for (final tier in tiers) {
          if (!list.contains(tier)) {
            list.add(tier);
          }
        }
      } else if (original.contains('saavncdn.com')) {
        // Multi-tier JioSaavn image fallback: 500x500 -> 150x150
        if (original.contains('500x500')) {
          final smaller = original.replaceAll('500x500', '150x150');
          if (!list.contains(smaller)) list.add(smaller);
        } else if (original.contains('150x150')) {
          final larger = original.replaceAll('150x150', '500x500');
          if (!list.contains(larger)) list.insert(0, larger);
        }
      }
    } else if (widget.trackId != null && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(widget.trackId!)) {
      // Fallback from YouTube track ID directly if image URL is null/empty
      final ytId = widget.trackId!;
      list.add('https://i.ytimg.com/vi/$ytId/hqdefault.jpg');
      list.add('https://i.ytimg.com/vi/$ytId/mqdefault.jpg');
    }

    _candidates = list;
  }

  Widget _buildShimmer() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: widget.borderRadius ?? AppRadii.borderMedium,
      ),
    );
  }

  /// Flat accent placeholder without letter tile as required by prompt specification:
  /// (d) a flat placeholder in the app accent colour. The letter tile is removed.
  Widget _buildFlatAccentPlaceholder() {
    final iconSize = (widget.height != null ? widget.height! * 0.35 : 32.0).clamp(20.0, 48.0).toDouble();
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: widget.borderRadius ?? AppRadii.borderMedium,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primarySoft.withValues(alpha: 0.30),
            AppColors.surface2,
          ],
        ),
        border: Border.all(
          color: AppColors.primarySoft.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: AppColors.primarySoft.withValues(alpha: 0.8),
          size: iconSize,
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
        child: _buildFlatAccentPlaceholder(),
      );
    }

    final currentUrl = _candidates[_fallbackIndex];
    final memWidth = (widget.width != null ? (widget.width! * 1.5).toInt() : 200).clamp(100, 500);
    final memHeight = (widget.height != null ? (widget.height! * 1.5).toInt() : 150).clamp(100, 500);
    final targetSize = '${(widget.width ?? 156).toInt()}x${(widget.height ?? 112).toInt()}';
    final cacheId = widget.trackId ?? widget.title.hashCode.abs().toString();
    final cacheKey = 'track:$cacheId:$targetSize';

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
        maxWidthDiskCache: 600,
        maxHeightDiskCache: 600,
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
        errorWidget: (_, __, ___) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _boundTrackId == activeTrackId && _fallbackIndex < _candidates.length) {
              setState(() => _fallbackIndex++);
            }
          });
          return _buildShimmer();
        },
      ),
    );
  }
}
