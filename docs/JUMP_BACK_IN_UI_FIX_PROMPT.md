# Fixation Specification & Prompt: "Jump Back In" UI Overhaul

---

### Copy-Paste Prompt for your Coding Agent / Project

```markdown
### Task: Redesign and Clean Up the "Jump Back In" Quick-Pick Section

#### Problem Statement:
The "Jump Back In" section on the home screen (`_buildQuickPickGrid` in `home_screen.dart`) looks crowded, cluttered, and vertically overwhelming:
1. **Vertical bloat (10 items across 5 rows):** The 2-column grid renders 10 items vertically (`mainAxisExtent: 56`, `crossAxisCount: 2`), taking up more than 350dp of vertical height and pushing key content (Recommended Artists, Recently Played) off-screen.
2. **Cramped, truncated titles:** Raw YouTube titles (e.g., *"Best of ATIF ASLAM Songs | Bollywood Romantic Love Songs | Audio Jukebox..."*) get wrapped into a tiny 56dp height and abruptly truncated, creating visual noise.
3. **Flat, rigid container styling:** The cards lack breathing room, modern border radii, and visual hierarchy.

---

#### Requirements & Implementation Details:

1. **Cap Item Count:**
   - Reduce the number of visible items from 10 down to **6 items** (3 rows × 2 columns), identical to Spotify's standard top grid.
   - Example:
     ```dart
     final tracks = (_quickPickTracks.isNotEmpty
             ? _quickPickTracks
             : CuratedTracks.getTracksForFilter(_activeFilter))
         .take(6)
         .toList();
     ```

2. **Clean Raw Video / Audio Titles:**
   - Implement a title sanitizing helper (or use a regex) to strip noisy YouTube suffixes before displaying:
     - Remove text inside brackets `[...]` or parentheses `(...)` like `(Official Video)`, `[HD]`, `(Official Audio)`, `(Remix)`.
     - Remove boilerplate after delimiters like `|`, `-`, or `//` when they contain words like `Jukebox`, `Full Song`, `Audio`, `Bollywood`.
   - Ensure clean 1–2 line display with proper line height:
     ```dart
     String cleanTitle(String rawTitle) {
       var cleaned = rawTitle
           .replaceAll(RegExp(r'\[.*?\]|\(.*?\)', caseSensitive: false), '')
           .split(RegExp(r'\s*[\|\-•]\s*(?:Bollywood|Audio|Jukebox|Official|Full Video).*', caseSensitive: false))
           .first
           .trim();
       return cleaned.isEmpty ? rawTitle : cleaned;
     }
     ```

3. **Improve Tile Proportions & Visual Styling:**
   - Increase `mainAxisExtent` from `56` to `60` or `62` to give the title more breathing room.
   - Adjust `borderRadius` to `BorderRadius.circular(8)` for a modern card feel.
   - Slightly elevate or apply a subtle glassmorphic fill:
     ```dart
     color: isCurrent
         ? AppColors.surface2
         : AppColors.surface1.withOpacity(0.9),
     ```
   - Make artwork square ($60 \times 60$) with rounded left corners matching the tile radius (`BorderRadius.horizontal(left: Radius.circular(8))`).

4. **Add Equalizer / Active Track Visualizer:**
   - When `isCurrent && audioProvider.isPlaying`, keep an animated mini equalizer or playing icon with proper right padding so it doesn't overlap text.

5. **Alternative Layout Option (2-Row Horizontal Swipe):**
   - If preferred over a static 6-tile grid, render the items in a horizontal scrollable grid with 2 rows (`scrollDirection: Axis.horizontal`, height ~130dp), preserving vertical space entirely.
```

---

### Summary of What Changes in `home_screen.dart`

| Attribute | Existing | Fixed (Recommended) |
| :--- | :--- | :--- |
| **Item Count** | 10 items (5 vertical rows) | **6 items (3 rows)** |
| **Grid Extent** | `mainAxisExtent: 56` | `mainAxisExtent: 60` |
| **Title Parsing** | Raw unformatted string | Sanitized via regex |
| **Border Radius** | Sharp / micro radius | `BorderRadius.circular(8)` |
| **Vertical Space** | ~350dp consumed | **~190dp (saves ~160dp)** |
