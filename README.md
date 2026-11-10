# Music App (Flutter Mobile)

A production-ready Flutter mobile music application supporting both **local device audio playback** and **online streaming**, built with **Provider** state management, background playback service, and a modular architecture ready for custom UI integration.

## Features

- **Dual Audio Sources**:
  - **Online Streaming**: Stream tracks directly via URL with instant buffering and duration tracking.
  - **Local Audio Library**: Scans device audio files (`.mp3`, `.m4a`, `.wav`) using `on_audio_query` with runtime storage permissions.
- **Background & Lock Screen Playback**:
  - Seamless background audio via `just_audio` and `audio_service`.
  - Native lock screen notification controls (Play, Pause, Next, Previous, Seek).
- **Playback Controls**:
  - Play, Pause, Seek, Next, Previous.
  - Loop modes (`LoopMode.off`, `LoopMode.all`, `LoopMode.one`).
  - Shuffle toggle.
- **UI Architecture**:
  - Persistent **MiniPlayer** docked at the bottom.
  - Full-screen **NowPlayingScreen** with album artwork, interactive progress bar, and controls.
  - Tabbed **HomeScreen** (Streams, Local Music, Playlists).
  - Modular theme tokens in `lib/theme/app_theme.dart` designed to easily drop in custom UI designs.

## Architecture

```text
lib/
├── main.dart                  # App bootstrap, AudioService initialization, Provider root
├── models/
│   └── song_model.dart        # Unified Song data model (compatible with MediaItem & on_audio_query)
├── services/
│   └── audio_handler.dart     # AudioService background daemon integrating just_audio
├── providers/
│   └── player_provider.dart   # Central ChangeNotifier managing playback state, queue, & permissions
├── screens/
│   ├── home_screen.dart       # Main tabbed view (Streams, Local, Playlists)
│   └── now_playing_screen.dart# Full-screen player with album art & progress slider
├── widgets/
│   ├── mini_player.dart       # Bottom persistent mini-player
│   └── song_tile.dart         # Reusable track tile widget
└── theme/
    └── app_theme.dart         # Design tokens (colors, dark theme, typography)
```

## Getting Started

1. Ensure Flutter is installed on your machine (`flutter --version`).
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run on your connected device or emulator:
   ```bash
   flutter run
   ```
