# DIAGNOSIS.md: Root Cause Analysis for Song Thumbnail Glitch & Speed Issues

Date: Nov 21, 2026  
Application: Flutter Music Streaming App (`ToufiqSec/music-app`)

---

## 1. Root Cause Analysis (Phase 0)

### 1.1 Shared Playlist/Compilation Album Banners on Individual Songs
* **Files**: [lib/screens/home_screen.dart:372, 1030-1096](file:///c:/Users/lutfa/OneDrive/Desktop/Project%201/lib/screens/home_screen.dart#L1030-L1096), [lib/core/services/youtube_music_service.dart:258-290](file:///c:/Users/lutfa/OneDrive/Desktop/Project%201/lib/core/services/youtube_music_service.dart#L258-L290), [lib/core/services/taste_engine.dart:430-463](file:///c:/Users/lutfa/OneDrive/Desktop/Project%201/lib/core/services/taste_engine.dart#L430-L463)
* **Actual Cause**:
  1. In `home_screen.dart:372`, `carousel4Query` queried `'$thirdArtist chartbusters songs'` and `carousel2Query` queried `'top trending viral songs 2026'`. JioSaavn indexes popular songs under compilation albums (e.g., *Friday Chartbusters*, *Latest Tollywood Chartbusters*, *1 Min Insta Viral Mix*, *Trending Viral Hits*, *Lovin*). JioSaavn's API returns the compilation album cover as `item['image']` for every single track in that compilation.
  2. While `TasteEngine.deduplicateArtwork` existed, `home_screen.dart:_buildHomeSection` (lines 1030–1096) rendered `tracks` directly without calling `TasteEngine.deduplicateArtwork(tracks)`. As a result, 3 to 4 songs in the same carousel displayed the exact same compilation cover.
  3. Furthermore, previous builds persisted these compilation tracks into `home_sections_cache.json` on user devices, causing old shared banners to persist upon app relaunch.
* **Resolution**:
  - Sanitized search queries to search for individual artist hit songs rather than compilation albums (`$thirdArtist best songs`, `top trending hit songs 2026`).
  - Added mandatory `TasteEngine.deduplicateArtwork(tracks)` inside `_buildHomeSection`, guaranteeing that no two cards in any horizontal carousel can share the same artwork URL.
  - Upgraded `TasteEngine.deduplicateArtwork` to normalize URLs across resolution variants (`150x150` vs `500x500`) and replace duplicate tracks with unique YouTube thumbnails (`https://i.ytimg.com/vi/${track.id}/hqdefault.jpg`) when available.
  - Added `await HomeSectionCacheStore.clear()` during app bootstrap in `main.dart:122` to wipe stale caches on app launch.

---

### 1.2 Letter Tile Glitch ("I", "Z", etc.)
* **Files**: [lib/widgets/generated_cover_art.dart:106-265](file:///c:/Users/lutfa/OneDrive/Desktop/Project%201/lib/widgets/generated_cover_art.dart#L106-L265), [lib/screens/home_screen.dart:1265, 1409](file:///c:/Users/lutfa/OneDrive/Desktop/Project%201/lib/screens/home_screen.dart#L1265), [lib/screens/search_screen.dart:525, 748](file:///c:/Users/lutfa/OneDrive/Desktop/Project%201/lib/screens/search_screen.dart#L748), [lib/screens/library_screen.dart:183, 524, 677](file:///c:/Users/lutfa/OneDrive/Desktop/Project%201/lib/screens/library_screen.dart#L183)
* **Actual Cause**:
  `GeneratedCoverArt` rendered a purple gradient container with a badge and the track title. When `CachedNetworkImage` threw a 404 error (due to dead YouTube video IDs or `maxresdefault.jpg` missing on older videos), widgets throughout the app fell back to `GeneratedCoverArt`. This resulted in the user seeing a purple tile with a music-note icon and the first letter of the song's title ("I" for Ilahi / Ishq Bulaava, "Z" for Zehnaseeb).
* **Resolution**:
  - Replaced all raw `CachedNetworkImage` + `GeneratedCoverArt` widgets across `home_screen.dart`, `search_screen.dart`, `library_screen.dart`, `downloads_screen.dart`, `mood_hub_screen.dart`, `room_screen.dart`, `mini_player.dart`, and `now_playing_screen.dart` with `CascadingArtwork`.
  - In `CascadingArtwork`, the letter tile has been removed. It follows the strict fallback specification:
    1. Own thumbnail at best size (`hqdefault.jpg` or `500x500`)
    2. Own thumbnail at smaller size (`mqdefault.jpg` or `150x150`)
    3. Own track ID fallback
    4. Flat accent placeholder in app accent color (`AppColors.primarySoft` and `AppColors.surface2` with music note icon, zero text/initials).

---

### 1.3 Song Cards Showing Text Only with No Image
* **Files**: [lib/core/services/curated_tracks.dart:40-790](file:///c:/Users/lutfa/OneDrive/Desktop/Project%201/lib/core/services/curated_tracks.dart#L40-L790), [lib/widgets/cascading_artwork.dart:73-84, 175, 205-212](file:///c:/Users/lutfa/OneDrive/Desktop/Project%201/lib/widgets/cascading_artwork.dart#L73-L84)
* **Actual Cause**:
  1. 22 curated tracks in `CuratedTracks` pointed to dead YouTube video IDs returning HTTP 404 on `hqdefault.jpg`.
  2. In `CascadingArtwork`, candidate tiers previously started with `maxresdefault.jpg` (which returns HTTP 404 for 90% of non-1080p music video uploads).
  3. When an image failed, `errorWidget` returned `_buildShimmer()`, while `cacheKey` lacked the fallback index (`track:$cacheId:$targetSize`). This caused CachedNetworkImage to stay stuck on the failed disk cache entry, rendering a dark blank box with text only below it.
* **Resolution**:
  - Replaced all 22 dead tracks in `curated_tracks.dart` with verified 500x500 JioSaavn CDN artwork and working stream IDs.
  - Corrected *Samjhawan* to official JioSaavn track ID `DMoLdwJ7` and dedicated high-res cover art.
  - Updated `CascadingArtwork` candidate list to prioritize `hqdefault.jpg` (guaranteed 200 OK) before `mqdefault.jpg` and `maxresdefault.jpg`.
  - Enhanced cache key to `'track:${cacheId}_${_fallbackIndex}:$targetSize'`, eliminating cache collision across retry attempts.

---

### 1.4 List Recycling & Image Bleed Prevention
* **Files**: [lib/widgets/cascading_artwork.dart:48, 194-197](file:///c:/Users/lutfa/OneDrive/Desktop/Project%201/lib/widgets/cascading_artwork.dart#L194-L197), [lib/widgets/content_card.dart:69](file:///c:/Users/lutfa/OneDrive/Desktop/Project%201/lib/widgets/content_card.dart#L69), [lib/screens/home_screen.dart:1098](file:///c:/Users/lutfa/OneDrive/Desktop/Project%201/lib/screens/home_screen.dart#L1098)
* **Actual Cause**:
  In horizontal and vertical scroll views, recycled card widgets could receive an asynchronous image callback from a previous track if not strictly bound to the current track ID.
* **Resolution**:
  - Bound `_boundTrackId` inside `CascadingArtwork`. In `imageBuilder`, if `_boundTrackId != activeTrackId`, the image is rejected and discarded.
  - Used stable keys (`ValueKey('card_${track.id}')` and `ValueKey('art_${widget.trackId}')`) in all list item builders to prevent widget confusion during scrolling.

---

### 1.5 Scrolling Slowness & Stutter
* **Files**: [lib/widgets/cascading_artwork.dart:171-172, 188-191](file:///c:/Users/lutfa/OneDrive/Desktop/Project%201/lib/widgets/cascading_artwork.dart#L188-L191), [lib/screens/home_screen.dart:381-450, 1091](file:///c:/Users/lutfa/OneDrive/Desktop/Project%201/lib/screens/home_screen.dart#L1091)
* **Actual Cause**:
  Full-size 1080p and 500x500 images were being decoded into RAM unconstrained, causing memory spikes and GPU thrashing on mid-range devices.
* **Resolution**:
  - Added bounded memory decoding constraints: `memCacheWidth: 234` and `memCacheHeight: 168` (1.5x of display size).
  - Configured `cacheExtent: 600.0` for horizontal carousels to prefetch textures off-screen.
  - Implemented parallel section stream loading (`.then()`) so sections render progressively as data arrives, with skeleton placeholders while loading.
