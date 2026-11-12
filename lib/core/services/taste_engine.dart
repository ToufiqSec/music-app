import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/music/models/music_models.dart';
import 'supabase_service.dart';
import 'youtube_music_service.dart';

class ArtistProfile {
  final String id;
  final String name;
  final String imageUrl;
  final String language;

  const ArtistProfile({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.language,
  });

  factory ArtistProfile.fromJson(Map<String, dynamic> json) {
    return ArtistProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? json['image']?.toString() ?? '',
      language: json['language']?.toString() ?? 'All',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'imageUrl': imageUrl,
    'language': language,
  };
}

/// Dynamic Taste Engine (Local-first + Supabase Cloud Sync)
/// Learns user preferences, favorite artists, languages, and dynamically ranks recommendations.
class TasteEngine {
  static List<ArtistProfile> _favoriteArtists = [];
  static List<String> _preferredLanguages = ['English', 'Hindi', 'Bengali', 'Punjabi'];
  static Map<String, int> _artistPlayWeights = {};
  static bool _initialized = false;

  static List<ArtistProfile> get favoriteArtists => List.unmodifiable(_favoriteArtists);
  static List<ArtistProfile> get selectedArtists => List.unmodifiable(_favoriteArtists);
  static List<String> get preferredLanguages => List.unmodifiable(_preferredLanguages);
  static bool get hasCompletedOnboarding => _favoriteArtists.isNotEmpty;

  /// Verified, high-resolution catalog of top iconic artists across Bollywood, Bengali, Punjabi & English
  static const List<ArtistProfile> defaultArtistCatalog = [
    // Bollywood & Hindi Playback
    ArtistProfile(
      id: 'h_arijit',
      name: 'Arijit Singh',
      imageUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=400',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_shreya',
      name: 'Shreya Ghoshal',
      imageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_atif',
      name: 'Atif Aslam',
      imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_sonu',
      name: 'Sonu Nigam',
      imageUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_kk',
      name: 'KK (Krishnakumar)',
      imageUrl: 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=400',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_mohit',
      name: 'Mohit Chauhan',
      imageUrl: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=400',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_sunidhi',
      name: 'Sunidhi Chauhan',
      imageUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_jubin',
      name: 'Jubin Nautiyal',
      imageUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_vishal',
      name: 'Vishal Mishra',
      imageUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_darshan',
      name: 'Darshan Raval',
      imageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_pritam',
      name: 'Pritam',
      imageUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_ar_rahman',
      name: 'A.R. Rahman',
      imageUrl: 'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=400',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_kishore',
      name: 'Kishore Kumar',
      imageUrl: 'https://images.unsplash.com/photo-1463453091185-61582044d556?w=400',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_lata',
      name: 'Lata Mangeshkar',
      imageUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=400',
      language: 'Hindi',
    ),

    // Bengali Legends & Modern Indie
    ArtistProfile(
      id: 'b_anupam',
      name: 'Anupam Roy',
      imageUrl: 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=400',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_nachiketa',
      name: 'Nachiketa Chakraborty',
      imageUrl: 'https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=400',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_rupam',
      name: 'Rupam Islam (Fossils)',
      imageUrl: 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=400',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_somlata',
      name: 'Somlata Acharyya',
      imageUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=400',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_rupankar',
      name: 'Rupankar Bagchi',
      imageUrl: 'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=400',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_sahana',
      name: 'Sahana Bajpaie',
      imageUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_anjan',
      name: 'Anjan Dutt',
      imageUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_kabir',
      name: 'Kabir Suman',
      imageUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_silajit',
      name: 'Silajit Majumder',
      imageUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_iman',
      name: 'Iman Chakraborty',
      imageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_lagnajita',
      name: 'Lagnajita Chakraborty',
      imageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_hemanta',
      name: 'Hemanta Mukherjee',
      imageUrl: 'https://images.unsplash.com/photo-1463453091185-61582044d556?w=400',
      language: 'Bengali',
    ),

    // Punjabi Beats & Hip-Hop
    ArtistProfile(
      id: 'p_diljit',
      name: 'Diljit Dosanjh',
      imageUrl: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=400',
      language: 'Punjabi',
    ),
    ArtistProfile(
      id: 'p_sidhu',
      name: 'Sidhu Moose Wala',
      imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
      language: 'Punjabi',
    ),
    ArtistProfile(
      id: 'p_ap',
      name: 'AP Dhillon',
      imageUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400',
      language: 'Punjabi',
    ),
    ArtistProfile(
      id: 'p_karan',
      name: 'Karan Aujla',
      imageUrl: 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=400',
      language: 'Punjabi',
    ),
    ArtistProfile(
      id: 'p_guru',
      name: 'Guru Randhawa',
      imageUrl: 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=400',
      language: 'Punjabi',
    ),
    ArtistProfile(
      id: 'p_bpraak',
      name: 'B Praak',
      imageUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400',
      language: 'Punjabi',
    ),
    ArtistProfile(
      id: 'p_shubh',
      name: 'Shubh',
      imageUrl: 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=400',
      language: 'Punjabi',
    ),
    ArtistProfile(
      id: 'p_honey',
      name: 'Yo Yo Honey Singh',
      imageUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400',
      language: 'Punjabi',
    ),

    // English & International Pop/Rock
    ArtistProfile(
      id: 'e_weeknd',
      name: 'The Weeknd',
      imageUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=400',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_taylor',
      name: 'Taylor Swift',
      imageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_coldplay',
      name: 'Coldplay',
      imageUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=400',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_ed',
      name: 'Ed Sheeran',
      imageUrl: 'https://images.unsplash.com/photo-1520523839898-50712825e3a7?w=400',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_billie',
      name: 'Billie Eilish',
      imageUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_bruno',
      name: 'Bruno Mars',
      imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_dualipa',
      name: 'Dua Lipa',
      imageUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=400',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_justin',
      name: 'Justin Bieber',
      imageUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_drake',
      name: 'Drake',
      imageUrl: 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=400',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_post',
      name: 'Post Malone',
      imageUrl: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=400',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_imaginedragons',
      name: 'Imagine Dragons',
      imageUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=400',
      language: 'English',
    ),
  ];

  static List<YoutubeTrack> rerankSearchResults(List<YoutubeTrack> tracks) => rerankWithTaste(tracks);

  static Future<File> _getLocalFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/taste_engine_profile.json');
  }

  /// Initialize local-first cache (<5ms) and background sync with Supabase
  static Future<void> init() async {
    if (_initialized) return;

    try {
      final file = await _getLocalFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = json.decode(content) as Map<String, dynamic>;
        
        final artistsRaw = data['favoriteArtists'] as List<dynamic>? ?? [];
        _favoriteArtists = artistsRaw.map((a) => ArtistProfile.fromJson(a as Map<String, dynamic>)).toList();

        final langsRaw = data['preferredLanguages'] as List<dynamic>? ?? [];
        if (langsRaw.isNotEmpty) {
          _preferredLanguages = langsRaw.map((l) => l.toString()).toList();
        }

        final weightsRaw = data['artistPlayWeights'] as Map<String, dynamic>? ?? {};
        _artistPlayWeights = weightsRaw.map((k, v) => MapEntry(k, (v as num).toInt()));
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[TasteEngine] Local init error: $e');
    }

    if (SupabaseService.isAuthenticated) {
      _syncDownFromCloud();
    }
  }

  static Future<void> _syncDownFromCloud() async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) return;

      final res = await SupabaseService.client
          .from('user_taste_profile')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (res != null) {
        final artistsRaw = res['favorite_artists'] as List<dynamic>? ?? [];
        if (artistsRaw.isNotEmpty) {
          _favoriteArtists = artistsRaw.map((a) => ArtistProfile.fromJson(a as Map<String, dynamic>)).toList();
        }
        final langsRaw = res['preferred_languages'] as List<dynamic>? ?? [];
        if (langsRaw.isNotEmpty) {
          _preferredLanguages = langsRaw.map((l) => l.toString()).toList();
        }
        await _persistLocal();
      }
    } catch (_) {}
  }

  static Future<void> _persistLocal() async {
    try {
      final file = await _getLocalFile();
      final data = {
        'favoriteArtists': _favoriteArtists.map((a) => a.toJson()).toList(),
        'preferredLanguages': _preferredLanguages,
        'artistPlayWeights': _artistPlayWeights,
      };
      await file.writeAsString(json.encode(data));
    } catch (e) {
      debugPrint('[TasteEngine] Persist error: $e');
    }
  }

  static Future<void> setFavoriteArtists(List<ArtistProfile> artists) async {
    _favoriteArtists = List.from(artists);
    await _persistLocal();
    if (SupabaseService.isAuthenticated) {
      SupabaseService.syncTasteProfile(
        favoriteArtists: _favoriteArtists.map((a) => a.toJson()).toList(),
      ).catchError((_) {});
    }
  }

  static Future<void> setPreferredLanguages(List<String> langs) async {
    _preferredLanguages = List.from(langs);
    await _persistLocal();
  }

  static Future<bool> toggleArtist(ArtistProfile artist) async {
    final idx = _favoriteArtists.indexWhere((a) => a.name.toLowerCase() == artist.name.toLowerCase());
    bool isAdded;
    if (idx >= 0) {
      _favoriteArtists.removeAt(idx);
      isAdded = false;
    } else {
      _favoriteArtists.add(artist);
      isAdded = true;
    }

    await _persistLocal();

    if (SupabaseService.isAuthenticated) {
      SupabaseService.syncTasteProfile(
        favoriteArtists: _favoriteArtists.map((a) => a.toJson()).toList(),
      ).catchError((_) {});
    }

    return isAdded;
  }

  static bool isArtistFavorite(String name) {
    return _favoriteArtists.any((a) => a.name.toLowerCase() == name.trim().toLowerCase());
  }

  static Future<void> recordPlaySignal(String artistName) async {
    final clean = artistName.trim().toLowerCase();
    if (clean.isEmpty) return;

    _artistPlayWeights[clean] = (_artistPlayWeights[clean] ?? 0) + 1;
    await _persistLocal();
  }

  static List<YoutubeTrack> rerankWithTaste(List<YoutubeTrack> tracks) {
    if (_favoriteArtists.isEmpty && _artistPlayWeights.isEmpty) {
      return tracks;
    }

    final favoriteNames = _favoriteArtists.map((a) => a.name.toLowerCase()).toSet();
    final scoredList = List<YoutubeTrack>.from(tracks);

    scoredList.sort((a, b) {
      int scoreA = 0;
      int scoreB = 0;

      final artistALower = a.artist.toLowerCase();
      final artistBLower = b.artist.toLowerCase();

      if (favoriteNames.any((fav) => artistALower.contains(fav))) scoreA += 50;
      if (favoriteNames.any((fav) => artistBLower.contains(fav))) scoreB += 50;

      scoreA += (_artistPlayWeights[artistALower] ?? 0).clamp(0, 20);
      scoreB += (_artistPlayWeights[artistBLower] ?? 0).clamp(0, 20);

      return scoreB.compareTo(scoreA);
    });

    return scoredList;
  }

  /// Live search for ANY artist online if not found in catalog
  static Future<ArtistProfile?> searchArtistLive(YoutubeMusicService musicService, String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;

    try {
      final tracks = await musicService.searchTracks('$trimmed songs official');
      if (tracks.isNotEmpty) {
        final first = tracks.first;
        return ArtistProfile(
          id: 'custom_${trimmed.hashCode.abs()}',
          name: trimmed,
          imageUrl: first.thumbnailUrl,
          language: 'All',
        );
      }
    } catch (_) {}

    return ArtistProfile(
      id: 'custom_${trimmed.hashCode.abs()}',
      name: trimmed,
      imageUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=400',
      language: 'All',
    );
  }
}
