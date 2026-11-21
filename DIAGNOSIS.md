# DIAGNOSIS.md - Music App Comprehensive Bug Diagnosis

**Application:** Flutter Mobile Music Streaming App (`com.toufiqsec.music_app`)  
**Date:** November 21, 2026  
**Auditor:** Antigravity Coding Agent  

---

### Issue 1: Many Songs Have No Thumbnail (Text-Only Cards in Fresh Picks)
* **Target Files:**
  - `lib/core/services/curated_tracks.dart:711-733`
  - `lib/widgets/content_card.dart:92-105`
  - `lib/widgets/generated_cover_art.dart:154-162`
* **Root Cause:**
  1. The hardcoded YouTube video IDs in `freshPicksTracks` (`vxX1WjS2N2M` for Tauba Tauba, `toE_rM_f_4A` for Illuminati, and `kPa7bsKwL-8` for Die With A Smile) return HTTP 404 Not Found on `i.ytimg.com/vi/<id>/hqdefault.jpg`.
  2. In `ContentCard`, `CachedNetworkImage` failed on 404 and fell back to `_buildDesignedPlaceholder()`, which called `GeneratedCoverArt` without an image URL or cascading fallback, rendering a text-only card.
* **Fix Plan:**
  - Update `freshPicksTracks` with verified, permanent video IDs (`RLzC55ai0eo` for Tauba Tauba, `tOM-nWPcR4U` for Illuminati, `bESGLojNYSo` for Die With A Smile).
  - Implement thumbnail resolution fallback cascade: `maxresdefault.jpg` -> `sddefault.jpg` -> `hqdefault.jpg` -> placeholder.

---

### Issue 2: Header Has Two Extra Icons (Search & History)
* **Target File:**
  - `lib/screens/home_screen.dart:493-512`
* **Root Cause:**
  `_HomeDiscoveryViewState` renders `_buildHeaderIconButton` with `Icons.history_rounded` and `Icons.search_rounded` in the top right action group, duplicating the search bar immediately below and the bottom navigation search tab.
* **Fix Plan:**
  Remove the two extra icon buttons. Retain only `_buildProfileAvatar(context, authProvider)` with WCAG AA compliance (min 48x48dp target). Ensure history is accessible in Library and Profile.

---

### Issue 3: Bottom Navigation is Plain
* **Target File:**
  - `lib/widgets/bottom_nav_bar.dart:24-106`
  - `lib/screens/home_screen.dart:130-155`
* **Root Cause:**
  `TwilightBottomNavBar` is docked directly to the bottom edge without a floating inset, uses an un-animated static background box for active items, and lacks accessible labels or minimum 48dp touch targets.
* **Fix Plan:**
  Redesign into a floating rounded bar with bottom margin, backdrop blur filter, animated gliding pill background behind the active tab (250ms ease-out curve), and larger icons with semantic labels.

---

### Issue 4: Podcast Audio Silent (Sunday Suspense: Feluda)
* **Target Files:**
  - `lib/screens/home_screen.dart:352-366`
  - `lib/core/services/curated_tracks.dart:413-421`
  - `lib/core/services/playback_resolver.dart:228-268`
* **Root Cause:**
  In `home_screen.dart:352-366`, `_loadDynamicContent()` runs `searchTracks('Sunday Suspense Feluda Mirchi Bangla audio stories official')` and overwrites `_featuredPodcast` with an unplayable YouTube video track (`audioStreamUrl: null`). When played, YouTube Explode fails due to YouTube embedding restrictions on long narrative audio, resulting in silent failure.
* **Fix Plan:**
  - Preserve the verified RSS enclosure URL (`https://dts.podtrac.com/redirect.mp3/api.spreaker.com/download/episode/58582188/joto_kando_kathmandu_te.mp3`) for `_featuredPodcast`.
  - Add a dedicated RSS podcast episode resolver and parser that streams public `audio/mpeg` enclosures without touching YouTube streams.

---

### Issue 5: YouTube Music Red Icon & Branding
* **Target Files:**
  - `lib/screens/home_screen.dart:194, 260-262`
  - `lib/core/constants/app_strings.dart:4-19`
* **Root Cause:**
  Legacy references to 'YouTube Music' remain in filter conditions and comments.
* **Fix Plan:**
  Ensure 100% clean UI branding: neutral labels like "Fresh Picks", "Top Charts", and no third-party YouTube red badges or logos.

---

### Issue 6: App is Slow, Glitches, and Heavy Startup Work
* **Target File:**
  - `lib/screens/home_screen.dart:347-405`
* **Root Cause:**
  Startup launches up to 8 separate external search queries across three stages without a 10-minute time-to-live cache, flooding the network and causing UI rebuilds.
* **Fix Plan:**
  Implement a 10-minute cache layer for home sections (`HomeSectionCacheStore`). On startup, render cached data immediately, then revalidate in the background.

---

### Issue 7: Search Bar Template Text ("Find the key to balance...")
* **Target File:**
  - `lib/screens/home_screen.dart:538`
* **Root Cause:**
  Placeholder string in `_buildExploreSearchBar` is hardcoded to `'Find the key to balance, songs, artists...'`.
* **Fix Plan:**
  Replace with `'Search songs, artists, podcasts'`.

---

### Issue 8: Header Icons Low Contrast & Faint "See all"
* **Target Files:**
  - `lib/screens/home_screen.dart:816-840, 969-985`
  - `lib/theme/app_colors.dart:30-45`
* **Root Cause:**
  "See all" uses `AppColors.primarySoft` (`#A28BFE`) without sufficient contrast ratio against dark cards, and tap padding is under 48dp.
* **Fix Plan:**
  Upgrade contrast to high-legibility light lavender (`#DDD6FE`, contrast > 7:1) with a 48x48dp minimum touch target.

---

### Issue 9: Google Sign-In Error 400: redirect_uri_mismatch
* **Target File:**
  - `lib/core/services/supabase_service.dart:185-203`
* **Root Cause:**
  Google Cloud Console OAuth 2.0 Web Client does not have `https://wcztbsbcfjoxlypghjil.supabase.co/auth/v1/callback` added to Authorized redirect URIs. Additionally, native Android SHA-1 fingerprint has not been registered in Google Cloud Console.
* **Fix Plan:**
  Document exact values for Google Cloud Console:
  - Package: `com.toufiqsec.music_app`
  - Supabase Callback: `https://wcztbsbcfjoxlypghjil.supabase.co/auth/v1/callback`
  - App Scheme: `io.supabase.musicapp://login-callback`
  Provide an in-app diagnostics screen explaining configuration status.

---

### Issue 10: Player Artwork & Hindi Lyrics Translation
* **Target Files:**
  - `lib/screens/now_playing_screen.dart:140-200`
  - `lib/widgets/synced_lyrics_view.dart:60-120`
  - `lib/core/services/lyrics_transliteration_service.dart:120-180`
* **Root Cause:**
  Dual lyrics translation requires a reliable line-by-line fallback when LRCLIB does not supply native Hindi transliterations.
* **Fix Plan:**
  Ensure the playing track artwork is dynamically tied to `audioProvider.currentTrack`, and provide translated subtitles for lyrics lines.
