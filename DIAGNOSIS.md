# DIAGNOSIS.md - Music App Root Cause Diagnosis (Thumbnail Glitches & Speed)

**Application:** Flutter Mobile Music Streaming App (`com.toufiqsec.music_app` / `ToufiqSec/music-app`)  
**Date:** November 21, 2026  
**Auditor:** Antigravity Coding Agent  
**Prompt Reference:** *Music App: Thumbnail Glitch and Speed Fix Prompt* (Nov 21, 2026)  

---

## Executive Summary

A comprehensive investigation into the root causes of the thumbnail glitches, letter tile fallbacks, and scroll stuttering was conducted across `lib/core/services/curated_tracks.dart`, `lib/core/services/youtube_music_service.dart`, `lib/core/services/taste_engine.dart`, `lib/widgets/cascading_artwork.dart`, `lib/widgets/content_card.dart`, and `lib/screens/home_screen.dart`.

The issues are caused by five interconnected root causes:
1. **Compilation Album/Banner Reuse**: JioSaavn search results return compilation album banners (`Latest-Tollywood-Chartbusters-...-500x500.jpg`, `Trending-Viral-Hits-...-500x500.jpg`) rather than individual song-level art, and `TasteEngine` did not deduplicate shared artwork across carousel songs.
2. **Missing Specific Image Cache Key**: `CachedNetworkImage` in `CascadingArtwork` used the bare image URL without binding to `track:${trackId}:${width}x${height}`, causing card recycling and duplicate URLs to share stale or wrong cached textures.
3. **Widget Recycling State Desynchronization**: `CascadingArtwork` lacked a track-bound key, causing `_CascadingArtworkState` to be reused across horizontal `ListView` items. When `widget.imageUrl` was unchanged or null, `_fallbackIndex` was never reset and in-flight image requests were delivered to recycled cards.
4. **Dead 404 Video IDs & Letter Tile Fallback**: Multiple curated tracks (`Ishq Bulaava`, `Zehnaseeb`, `Samjhawan`, `Ilahi`, `Mast Magan`, `Hasi`, `Manwa Laage`, `Gallan Goodiyaan`, `Dil Bechara`) pointed to dead YouTube video IDs returning HTTP 404 on all 4 thumbnail tiers (`maxresdefault`, `sddefault`, `hqdefault`, `mqdefault`), causing `_CascadingArtworkState` to exhaust candidates and fall back to `_buildFlatAccentPlaceholder()`, which explicitly rendered the purple letter initials tile.
5. **Main Isolate Saturation & Unbounded Image Decodes**: Simultaneous startup searches (8 concurrent HTTP calls) with JSON parsing on the main isolate combined with full-resolution image caching without height constraints caused raster cache thrashing and scroll stutter.

---

## Detailed Root Cause Audit (Phase 0 Requirements)

### 1. Which Image URL is Used? (File & Line Analysis)

* **JioSaavn Compilation Album Banners Passed to Multiple Songs**:
  - **File**: `lib/core/services/youtube_music_service.dart:257-290`
  - **Code**:
    ```dart
    var image = item['image']?.toString();
    if (image != null) {
      image = image.replaceAll('150x150', '500x500');
    }
    ```
  - **Finding**: When querying queries like `'bollywood chartbusters'`, `'punjabi workout gym high bass'`, or `'top trending viral songs'`, JioSaavn returns songs indexed under compilation albums. For example:
    - `"song": "Ammaadi (From \"Hi Nanna\")"` -> receives `https://c.saavncdn.com/294/Latest-Tollywood-Chartbusters-Telugu-2026-20260819181226-500x500.jpg`
    - `"song": "Madhuramu Kadha (From \"The Family Star\")"` -> receives the identical `...Latest-Tollywood-Chartbusters-...` banner!
    - `"song": "White Brown Black"` and `"song": "WOH"` -> receive identical `https://c.saavncdn.com/015/Trending-Viral-Hits-Hindi-2023-20230427144734-500x500.jpg` banner!
    - Songs in "More of What You Like" received identical compilation art for "Lovin" / "MoveMeant" across multiple songs.
  - **Section Impact**: "Based on Your Recent Listening" (`home_screen.dart:771-776`) and "More of What You Like" (`home_screen.dart:749-755`) displayed 3 to 4 songs sharing the exact same playlist/compilation banner.

* **Curated Catalog Image Duplications**:
  - **File**: `lib/core/services/curated_tracks.dart:455-535`
  - **Finding**:
    - `popularAlbumsTracks:461` (`Tum Hi Ho`) and `popularAlbumsTracks:475` (`Ilahi`) both had hardcoded `https://c.saavncdn.com/840/Best-Of-Arijit-Singh-Collection-Of-Romantic-Songs-Hindi-2025-20251203161112-500x500.jpg`.
    - Multiple tracks across `chillTracks`, `workoutTracks`, and `lateNightTracks` shared duplicate URLs.

---

### 2. Image Cache Keys (File & Line Analysis)

* **File**: `lib/widgets/cascading_artwork.dart:152-167`
* **Finding**:
  ```dart
  CachedNetworkImage(
    imageUrl: currentUrl,
    width: widget.width,
    height: widget.height,
    fit: widget.fit,
    memCacheWidth: memWidth,
    placeholder: (_, __) => _buildShimmer(),
    ...
  )
  ```
  `CachedNetworkImage` was invoked with **no explicit `cacheKey` parameter**.
* **Impact**:
  1. Default keying uses only the raw URL string (`currentUrl`). When JioSaavn returned a shared compilation URL or when multiple tracks pointed to the same URL, `CachedNetworkImage` mapped them to the same in-memory texture.
  2. The cache key did not include the track ID or requested size (`track:{trackId}:{size}`).
  3. When an old URL failed or was updated, the cached entry was not cleared or disambiguated.

---

### 3. List Recycling & In-Flight Request Leakage (File & Line Analysis)

* **File**: `lib/screens/home_screen.dart:1036-1049` & `lib/widgets/cascading_artwork.dart:44-50`
* **Finding**:
  1. In `ListView.separated` inside `_buildHomeSection`:
     ```dart
     ContentCard(
       key: ValueKey('${track.id}_$index'),
       title: track.title,
       subtitle: track.artist,
       imageUrl: track.thumbnailUrl,
       ...
     )
     ```
     `ContentCard` passed parameters to `CascadingArtwork` without assigning a key to `CascadingArtwork`.
  2. In `_CascadingArtworkState`:
     ```dart
     @override
     void didUpdateWidget(covariant CascadingArtwork oldWidget) {
       super.didUpdateWidget(oldWidget);
       if (oldWidget.imageUrl != widget.imageUrl) {
         _fallbackIndex = 0;
         _buildCandidateList();
       }
     }
     ```
     When a card was recycled for another track that shared an identical or empty `imageUrl`, `_fallbackIndex` was NOT reset.
  3. Because in-flight asynchronous network fetches were not bound to the active `trackId`, an image fetched for Card A that resolved after Card A was recycled into Card B would paint Card A's image onto Card B.

---

### 4. Why the Letter Tile Shows (File & Line Analysis)

* **File**: `lib/core/services/curated_tracks.dart:538-620` & `lib/widgets/cascading_artwork.dart:91-145`
* **Finding**:
  1. The hardcoded YouTube video IDs in `curated_tracks.dart` returned HTTP 404 on `i.ytimg.com`:
     - `Ishq Bulaava`: `xW4Xq5uE9eI` -> HTTP 404 (on `hqdefault`, `maxresdefault`, `sddefault`, `mqdefault`)
     - `Zehnaseeb`: `8vK8ZqGvU_A` -> HTTP 404
     - `Samjhawan`: `H2f7MZUsvVE` -> HTTP 404
     - `Ilahi`: `6wZZ4b9A-g8` (Happy Hits first card) -> HTTP 404
     - `Mast Magan`: `b87dE8g3cXE` -> HTTP 404
     - `Hasi (Acoustic)`: `gP_GqX7s3Y8` -> HTTP 404
     - `Manwa Laage`: `d8ItEhzs88g` -> HTTP 404
     - `Raabta`: `o_B4yVjH9l4` -> HTTP 404
     - `Enna Sona`: `of3tW2iZk7c` -> HTTP 404
     - `Gallan Goodiyaan`: `7DYyFOU8Nfg` -> HTTP 404
     - `Dil Bechara`: `mUvG965iVlY` -> HTTP 404
  2. In `lib/widgets/cascading_artwork.dart:140-145`:
     ```dart
     if (_candidates.isEmpty || _fallbackIndex >= _candidates.length) {
       return ClipRRect(
         borderRadius: radius,
         child: _buildFlatAccentPlaceholder(),
       );
     }
     ```
  3. In `lib/widgets/cascading_artwork.dart:91-134`:
     ```dart
     Widget _buildFlatAccentPlaceholder() {
       final initials = widget.title.isNotEmpty ? widget.title[0].toUpperCase() : '♪';
       ...
       Icon(Icons.music_note_rounded, ...),
       Text(initials, ...)
     ```
     `_buildFlatAccentPlaceholder()` directly renders the purple box with the music-note icon and the letter initial ("I", "Z", "S").
  4. The prompt requires: "The letter tile is removed. Fallback order for a song: (a) its own thumbnail at the best size; (b) the same thumbnail at a smaller size; (c) its own album cover if the album ID matches; (d) a flat placeholder in the app accent colour."

---

### 5. Thread & I/O Bottlenecks (File & Line Analysis)

* **File**: `lib/screens/home_screen.dart:380-438`
* **Finding**:
  1. `_loadDynamicContent` initiated 8 concurrent network searches via `Future.wait` across 3 stages.
  2. Each search completed JSON deserialization directly on the main isolate.
  3. In `lib/widgets/cascading_artwork.dart:148`:
     `final memWidth = widget.width != null ? (widget.width! * 2).toInt() : 400;`
     `memCacheHeight` was not constrained, allowing non-square or high-res images to allocate unneeded bitmap buffers on the GPU.
  4. In `ListView.separated` inside `_buildHomeSection`, no `cacheExtent` was configured and no prefetching (`precacheImage`) was performed for off-screen cards. When the user scrolled quickly, the UI thread blocked on decoding new images simultaneously.

---

## Action Plan by Phase

* **Phase 1: One Song, One Image**
  - Update `curated_tracks.dart` with verified, 200 OK individual album covers from official Saavn CDN (`Hasee Toh Phasee`, `Humpty Sharma Ki Dulhania`, `Yeh Jawaani Hai Deewani`, `2 States`, `Hamari Adhuri Kahani`, `Happy New Year`, `Agent Vinod`, `OK Jaanu`, `Dil Dhadakne Do`, `Dil Bechara`, `Aashiqui 2`).
  - Enforce one-song-one-image deduplication in `TasteEngine.rerankSearchResults`: drop duplicate artwork URLs so no compilation banner ever repeats in a carousel.
  - Upgrade `CascadingArtwork` to accept `trackId`, generate cache key `track:${trackId}:${targetSize}`, reset fallback state on widget recycling, and eliminate the letter tile fallback in favor of a clean accent placeholder.
  - Use stable track keys (`ValueKey(track.id)`) across cards.

* **Phase 2: Speed and Smoothness**
  - Add `memCacheWidth: 200` and `memCacheHeight: 144` to downscale decoding to exact card display dimensions.
  - Implement off-screen image prefetching with `precacheImage` for adjacent cards in `_buildHomeSection`.
  - Add skeleton placeholders for loading sections.
  - Ensure 10-minute home section cache revalidates smoothly in background.

* **Phase 3: Tests and Proof**
  - Add unit tests verifying unique track ID to image binding, cache key structure, duplicate image prevention in carousels, and 200 OK statuses for all curated tracks.
