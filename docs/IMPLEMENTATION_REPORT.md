# Implementation Report: "Jump Back In" UI Overhaul

**Target File:** `lib/screens/home_screen.dart`  
**Target Function:** `_buildQuickPickGrid` (around lines 1526–1620)  
**Status:** Ready to Implement  

---

## 1. Executive Summary & Problem Analysis

During live ADB screen and layout inspection (`ui.xml`), the **"Jump Back In"** quick-pick section on the home screen was found to cause severe visual crowding and screen fatigue:

1. **Excessive Vertical Footprint (10 Tiles / 5 Rows):**
   * Code: `take(10).toList()` with `crossAxisCount: 2`.
   * Occupies ~350dp of vertical space, pushing high-value sections like **Recommended Artists** and **Recently Played** completely off the first screen view.
2. **Cramped 56dp Tile Height:**
   * Each tile is only 56dp tall with an internal 56x56 square thumbnail.
   * Only leaves a narrow horizontal text area for titles.
3. **Unsanitized YouTube Video Titles:**
   * Raw strings like `"Best of ATIF ASLAM Songs | Bollywood Romantic Love Songs | Audio Jukebox | Hindi Hit Songs"` are rendered directly.
   * Titles get abruptly clipped after 2 lines into noisy, incomplete phrases.

---

## 2. Implementation Specifications

### Change 1: Cap Item Count to 6 (2 Columns × 3 Rows)
Replace `.take(10)` with `.take(6)`. This aligns with the Spotify standard, saving ~160dp of vertical space and letting the rest of the feed breathe.

### Change 2: Add Title Sanitization Helper
Add a helper method to clean raw YouTube titles before rendering:
```dart
String _cleanTitle(String rawTitle) {
  return rawTitle
      .replaceAll(RegExp(r'\[.*?\]|\(.*?\)', caseSensitive: false), '')
      .split(RegExp(r'\s*[\|\-•]\s*(?:Bollywood|Audio|Jukebox|Official|Full Video|Remix|Song).*', caseSensitive: false))
      .first
      .trim();
}
```

### Change 3: Expand Tile Proportions & Corner Radii
* Increase `mainAxisExtent` from `56` to `60`.
* Update card `borderRadius` to `BorderRadius.circular(8)`.
* Update artwork `width` and `height` to `60` with matching `BorderRadius.horizontal(left: Radius.circular(8))`.
* Set text `fontSize: 12.5`, `maxLines: 2`, `overflow: TextOverflow.ellipsis`.

---

## 3. Exact Code Replacement Diff

### In `lib/screens/home_screen.dart`:

```dart
<<<<
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
====
  /// Helper to sanitize noisy YouTube titles
  String _cleanTrackTitle(String rawTitle) {
    final cleaned = rawTitle
        .replaceAll(RegExp(r'\[.*?\]|\(.*?\)', caseSensitive: false), '')
        .split(RegExp(r'\s*[\|\-•]\s*(?:Bollywood|Audio|Jukebox|Official|Full Video|Remix|Song).*', caseSensitive: false))
        .first
        .trim();
    return cleaned.isEmpty ? rawTitle : cleaned;
  }

  /// 2x3 Grid of Clean, Balanced Quick-Pick Tiles (Spotify Style)
  Widget _buildQuickPickGrid(
    BuildContext context,
    AudioProvider audioProvider,
  ) {
    // Show maximum 6 items (3 rows x 2 columns) for clean visual density
    final tracks = (_quickPickTracks.isNotEmpty
            ? _quickPickTracks
            : CuratedTracks.getTracksForFilter(_activeFilter))
        .take(6)
        .toList();

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: tracks.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 60, // Expanded height for breathing room
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
              borderRadius: BorderRadius.circular(8),
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
                    left: Radius.circular(8),
                  ),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: CascadingArtwork(
                      key: ValueKey('quick_art_${track.id}'),
                      trackId: track.id,
                      imageUrl: track.thumbnailUrl,
                      title: track.title,
                      artist: track.artist,
                      width: 60,
                      height: 60,
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _cleanTrackTitle(track.title),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                      color: isCurrent
                          ? AppColors.primarySoft
                          : AppColors.textPrimary,
                      fontSize: 12.5,
                      height: 1.2,
                    ),
                  ),
                ),
>>>>
```

---

## 4. Verification Steps Post-Implementation

1. **Hot Reload / Restart:** Reload the app on your Nothing Phone (2a).
2. **Visual Check:**
   * "Jump Back In" section should now only display **6 items** in 3 rows.
   * Titles should be free of noisy tags like `(Official Video)` or `| Audio Jukebox`.
   * **Recommended Artists** should now appear comfortably visible without excessive scrolling.
