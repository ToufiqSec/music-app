import '../../features/music/models/music_models.dart';

/// Real, high-bitrate audio streams with album artwork for immediate playback.
class CuratedTracks {
  static final List<YoutubeTrack> jumpBackInTracks = [
    const YoutubeTrack(
      id: 'curated_1',
      title: 'Midnight Reverie',
      artist: 'Aura Bloom',
      durationSeconds: 157,
      thumbnailUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600',
      audioStreamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    ),
    const YoutubeTrack(
      id: 'curated_2',
      title: 'Urban Serenade',
      artist: 'Kairo & The Night',
      durationSeconds: 213,
      thumbnailUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600',
      audioStreamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
    ),
    const YoutubeTrack(
      id: 'curated_3',
      title: 'Celestial Drift',
      artist: 'Solaris Beats',
      durationSeconds: 198,
      thumbnailUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600',
      audioStreamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    ),
    const YoutubeTrack(
      id: 'curated_4',
      title: 'Velvet Horizon',
      artist: 'Lunar Prism',
      durationSeconds: 224,
      thumbnailUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=600',
      audioStreamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
    ),
    const YoutubeTrack(
      id: 'curated_5',
      title: 'Echoes of Autumn',
      artist: 'Maya Sterling',
      durationSeconds: 182,
      thumbnailUrl: 'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?w=600',
      audioStreamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
    ),
    const YoutubeTrack(
      id: 'curated_6',
      title: 'Neon Odyssey',
      artist: 'Vapor Waveform',
      durationSeconds: 240,
      thumbnailUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600',
      audioStreamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',
    ),
  ];

  static final List<YoutubeTrack> madeForYouTracks = [
    const YoutubeTrack(
      id: 'made_1',
      title: 'Twilight Chillout Mix',
      artist: 'Curated by AI • 50 Songs',
      durationSeconds: 3120,
      thumbnailUrl: 'https://images.unsplash.com/photo-1487180144351-b8472da7d491?w=600',
      audioStreamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3',
    ),
    const YoutubeTrack(
      id: 'made_2',
      title: 'Late Night Focus Waves',
      artist: 'Deep Work Radio',
      durationSeconds: 2840,
      thumbnailUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600',
      audioStreamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
    ),
    const YoutubeTrack(
      id: 'made_3',
      title: 'Lo-Fi Sunset Sessions',
      artist: 'Chill Beats Collective',
      durationSeconds: 3400,
      thumbnailUrl: 'https://images.unsplash.com/photo-1445985543470-41fdd6ce388d?w=600',
      audioStreamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3',
    ),
    const YoutubeTrack(
      id: 'made_4',
      title: 'Electronic Pulse',
      artist: 'High Energy Wave',
      durationSeconds: 2900,
      thumbnailUrl: 'https://images.unsplash.com/photo-1511379938547-c1f69419868d?w=600',
      audioStreamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3',
    ),
  ];

  static final List<YoutubeTrack> trendingTracks = [
    const YoutubeTrack(
      id: 'trend_1',
      title: 'Starlight Symphony',
      artist: 'Kygo ft. Sasha',
      durationSeconds: 205,
      thumbnailUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=600',
      audioStreamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-11.mp3',
    ),
    const YoutubeTrack(
      id: 'trend_2',
      title: 'Golden Hour Memories',
      artist: 'The Midnight Valley',
      durationSeconds: 231,
      thumbnailUrl: 'https://images.unsplash.com/photo-1520523839898-50712825e3a7?w=600',
      audioStreamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-12.mp3',
    ),
    const YoutubeTrack(
      id: 'trend_3',
      title: 'Dancing In The Moonlight',
      artist: 'Electra Groove',
      durationSeconds: 194,
      thumbnailUrl: 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=600',
      audioStreamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-13.mp3',
    ),
    const YoutubeTrack(
      id: 'trend_4',
      title: 'Ocean Deep',
      artist: 'Aquatic Soundscape',
      durationSeconds: 218,
      thumbnailUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=600',
      audioStreamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-14.mp3',
    ),
  ];

  static final List<Map<String, String>> topArtists = [
    {
      'name': 'The Weeknd',
      'image': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400',
      'genre': 'R&B / Pop',
    },
    {
      'name': 'Dua Lipa',
      'image': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400',
      'genre': 'Pop Dance',
    },
    {
      'name': 'Post Malone',
      'image': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
      'genre': 'Hip-Hop / Rock',
    },
    {
      'name': 'Billie Eilish',
      'image': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400',
      'genre': 'Alt-Pop',
    },
    {
      'name': 'Coldplay',
      'image': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400',
      'genre': 'Alt Rock',
    },
  ];
}
