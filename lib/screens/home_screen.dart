import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../widgets/mini_player.dart';
import '../widgets/song_tile.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Preload local songs on start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlayerProvider>().fetchLocalSongs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<PlayerProvider>().fetchLocalSongs();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: const [
                _OnlineStreamsTab(),
                _LocalMusicTab(),
                _PlaylistsTab(),
              ],
            ),
          ),
          const MiniPlayer(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.cloud_outlined),
            activeIcon: Icon(Icons.cloud),
            label: 'Streams',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_outlined),
            activeIcon: Icon(Icons.folder),
            label: 'Local Music',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.queue_music_outlined),
            activeIcon: Icon(Icons.queue_music),
            label: 'Playlists',
          ),
        ],
      ),
    );
  }
}

class _OnlineStreamsTab extends StatelessWidget {
  const _OnlineStreamsTab();

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final songs = player.onlineSongs;

    return ListView.builder(
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        final isCurrent = player.currentSong?.id == song.id;
        return SongTile(
          song: song,
          isCurrent: isCurrent,
          isPlaying: player.isPlaying,
          onTap: () => player.playSong(song, songs),
        );
      },
    );
  }
}

class _LocalMusicTab extends StatelessWidget {
  const _LocalMusicTab();

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final songs = player.localSongs;

    if (player.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (songs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.music_off_outlined, size: 64, color: AppTheme.textSecondary),
              const SizedBox(height: 16),
              const Text(
                'No local audio files found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Allow storage permissions or add MP3s to your device storage.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Scan Storage Again'),
                onPressed: () => player.fetchLocalSongs(),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        final isCurrent = player.currentSong?.id == song.id;
        return SongTile(
          song: song,
          isCurrent: isCurrent,
          isPlaying: player.isPlaying,
          onTap: () => player.playSong(song, songs),
        );
      },
    );
  }
}

class _PlaylistsTab extends StatelessWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.playlist_play, size: 64, color: AppTheme.secondary),
          SizedBox(height: 12),
          Text(
            'Custom Playlists',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6),
          Text(
            'Ready to integrate with your custom UI design!',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
