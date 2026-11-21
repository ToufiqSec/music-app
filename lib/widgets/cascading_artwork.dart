import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// Reliable Artwork Component with multi-tier image fallback:
/// maxresdefault -> sddefault -> hqdefault -> flat accent placeholder.
/// Guarantees that no card or player view is ever blank or text-only.
class CascadingArtwork extends StatefulWidget {
  final String? imageUrl;
  final String title;
  final String artist;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  const CascadingArtwork({
    super.key,
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
  int _fallbackIndex = 0;
  late List<String> _candidates;

  @override
  void initState() {
    super.initState();
    _buildCandidateList();
  }

  @override
  void didUpdateWidget(covariant CascadingArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
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
      }
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

  Widget _buildFlatAccentPlaceholder() {
    final initials = widget.title.isNotEmpty ? widget.title[0].toUpperCase() : '♪';
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
            AppColors.primarySoft.withValues(alpha: 0.35),
            AppColors.surface2,
          ],
        ),
        border: Border.all(
          color: AppColors.primarySoft.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_note_rounded,
              color: AppColors.primarySoft,
              size: (widget.height != null ? widget.height! * 0.3 : 28.0).clamp(18.0, 42.0).toDouble(),
            ),
            const SizedBox(height: 2),
            Text(
              initials,
              style: TextStyle(
                color: Colors.white70,
                fontSize: (widget.height != null ? widget.height! * 0.22 : 16.0).clamp(12.0, 24.0).toDouble(),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
    final memWidth = widget.width != null ? (widget.width! * 2).toInt() : 400;

    return ClipRRect(
      borderRadius: radius,
      child: CachedNetworkImage(
        imageUrl: currentUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        memCacheWidth: memWidth,
        placeholder: (_, __) => _buildShimmer(),
        errorWidget: (_, __, ___) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _fallbackIndex < _candidates.length) {
              setState(() => _fallbackIndex++);
            }
          });
          return _buildShimmer();
        },
      ),
    );
  }
}
