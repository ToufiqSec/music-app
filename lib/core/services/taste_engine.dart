import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
  static final Map<String, int> _sessionArtistBoosts = {};
  static final Set<String> _dislikedTrackIds = {};
  static final Set<String> _dislikedArtists = {};
  static bool _initialized = false;

  static List<ArtistProfile> get favoriteArtists => List.unmodifiable(_favoriteArtists);
  static List<ArtistProfile> get selectedArtists => List.unmodifiable(_favoriteArtists);
  static List<String> get preferredLanguages => List.unmodifiable(_preferredLanguages);
  static bool get hasCompletedOnboarding => _favoriteArtists.isNotEmpty;

  /// Checks if a string is a known record label or YouTube channel rather than an artist.
  static bool isBlockedChannelOrLabel(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.isEmpty) return true;
    const blockedKeywords = [
      'lyrics',
      'records',
      'music india',
      'music company',
      'official',
      'countdown',
      't-series',
      'vevo',
      'zee music',
      'tips official',
      'yrf',
      'yash raj',
      'saregama',
      'speed records',
      'white hill',
      'geet mp3',
      'svf',
      'audio',
      'channel',
      'production',
      'studio',
      'vibe',
      'bass',
    ];
    return blockedKeywords.any((b) => lower.contains(b));
  }

  /// Verified, high-resolution catalog of top iconic artists with REAL 500x500 CDN portraits.
  static const List<ArtistProfile> defaultArtistCatalog = [
    // Bollywood & Hindi Playback
    ArtistProfile(
      id: 'h_arijit',
      name: 'Arijit Singh',
      imageUrl: 'https://c.saavncdn.com/artists/Arijit_Singh_500x500.jpg',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_shreya',
      name: 'Shreya Ghoshal',
      imageUrl: 'https://c.saavncdn.com/artists/Shreya_Ghoshal_500x500.jpg',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_atif',
      name: 'Atif Aslam',
      imageUrl: 'https://c.saavncdn.com/artists/Atif_Aslam_500x500.jpg',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_sonu',
      name: 'Sonu Nigam',
      imageUrl: 'https://c.saavncdn.com/artists/Sonu_Nigam_500x500.jpg',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_kk',
      name: 'KK',
      imageUrl: 'https://c.saavncdn.com/artists/KK_500x500.jpg',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_mohit',
      name: 'Mohit Chauhan',
      imageUrl: 'https://c.saavncdn.com/artists/Mohit_Chauhan_500x500.jpg',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_sunidhi',
      name: 'Sunidhi Chauhan',
      imageUrl: 'https://c.saavncdn.com/artists/Sunidhi_Chauhan_500x500.jpg',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_jubin',
      name: 'Jubin Nautiyal',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/9031b483049b5551abcb11529873b4f6/1000x1000-000000-80-0-0.jpg',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_kishore',
      name: 'Kishore Kumar',
      imageUrl: 'https://c.saavncdn.com/artists/Kishore_Kumar_500x500.jpg',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_lata',
      name: 'Lata Mangeshkar',
      imageUrl: 'https://c.saavncdn.com/artists/Lata_Mangeshkar_500x500.jpg',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_ar_rahman',
      name: 'A.R. Rahman',
      imageUrl: 'https://c.saavncdn.com/artists/AR_Rahman_500x500.jpg',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_kumar_sanu',
      name: 'Kumar Sanu',
      imageUrl: 'https://c.saavncdn.com/artists/Kumar_Sanu_500x500.jpg',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_alka_yagnik',
      name: 'Alka Yagnik',
      imageUrl: 'https://c.saavncdn.com/artists/Alka_Yagnik_500x500.jpg',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_badshah',
      name: 'Badshah',
      imageUrl: 'https://c.saavncdn.com/artists/Badshah_500x500.jpg',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_neha_kakkar',
      name: 'Neha Kakkar',
      imageUrl: 'https://c.saavncdn.com/artists/Neha_Kakkar_500x500.jpg',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_vishal',
      name: 'Vishal Mishra',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/6125247795ee1f0b64253a1e993e7b0e/1000x1000-000000-80-0-0.jpg',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_darshan',
      name: 'Darshan Raval',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/9428424029a929927b7081b70d3a0fc6/1000x1000-000000-80-0-0.jpg',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_anuv_jain',
      name: 'Anuv Jain',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/eb0c0e91c8ad621b41178e0d66c81057/1000x1000-000000-80-0-0.jpg',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_prateek',
      name: 'Prateek Kuhad',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/7f69b3905ae630b3f7bcd826bd2dc46f/1000x1000-000000-80-0-0.jpg',
      language: 'Hindi',
    ),

    // Bengali Legends & Modern Indie
    ArtistProfile(
      id: 'b_anupam',
      name: 'Anupam Roy',
      imageUrl: 'https://c.saavncdn.com/artists/Anupam_Roy_500x500.jpg',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_nachiketa',
      name: 'Nachiketa Chakraborty',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/cabc7990aaf4b70bc31b3afded26646a/1000x1000-000000-80-0-0.jpg',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_rupam',
      name: 'Rupam Islam (Fossils)',
      imageUrl: 'https://c.saavncdn.com/artists/Rupam_Islam_500x500.jpg',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_hemanta',
      name: 'Hemanta Mukherjee',
      imageUrl: 'https://c.saavncdn.com/artists/Hemant_Kumar_500x500.jpg',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_manna_dey',
      name: 'Manna Dey',
      imageUrl: 'https://c.saavncdn.com/artists/Manna_Dey_500x500.jpg',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_shaan',
      name: 'Shaan',
      imageUrl: 'https://c.saavncdn.com/artists/Shaan_500x500.jpg',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_anjan',
      name: 'Anjan Dutt',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/32b8921d94a153c511263215af53c45c/1000x1000-000000-80-0-0.jpg',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_kabir',
      name: 'Kabir Suman',
      imageUrl: 'https://is1-ssl.mzstatic.com/image/thumb/Music128/v4/e1/f5/20/e1f5208c-233c-7c2d-efb1-416673e3b2f7/191773326364.jpg/600x600bb.jpg',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_somlata',
      name: 'Somlata Acharyya',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/5d189c37432cf62d8426fb8fdecc8e67/1000x1000-000000-80-0-0.jpg',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_rupankar',
      name: 'Rupankar Bagchi',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/d166830cbad55c6b5847273cc06735b6/1000x1000-000000-80-0-0.jpg',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_iman',
      name: 'Iman Chakraborty',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/9d70214ccae8b4360305d324088cdba7/1000x1000-000000-80-0-0.jpg',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_lagnajita',
      name: 'Lagnajita Chakraborty',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/4c23c0c1f093f6856eba122542309500/1000x1000-000000-80-0-0.jpg',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_monali',
      name: 'Monali Thakur',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/baf2fd45c36240e33c9fa5c81ee7bc82/1000x1000-000000-80-0-0.jpg',
      language: 'Bengali',
    ),

    // Punjabi Beats & Hip-Hop
    ArtistProfile(
      id: 'p_diljit',
      name: 'Diljit Dosanjh',
      imageUrl: 'https://c.saavncdn.com/artists/Diljit_Dosanjh_500x500.jpg',
      language: 'Punjabi',
    ),
    ArtistProfile(
      id: 'p_sidhu',
      name: 'Sidhu Moose Wala',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/f559ebe3851db26a6a47a76b1d95748f/1000x1000-000000-80-0-0.jpg',
      language: 'Punjabi',
    ),
    ArtistProfile(
      id: 'p_ap',
      name: 'AP Dhillon',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/52594ac9fa763dc163ed13d21cb130ec/1000x1000-000000-80-0-0.jpg',
      language: 'Punjabi',
    ),
    ArtistProfile(
      id: 'p_karan',
      name: 'Karan Aujla',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/a91a1d5ea91e85e4f0966569b50e8d6a/1000x1000-000000-80-0-0.jpg',
      language: 'Punjabi',
    ),
    ArtistProfile(
      id: 'p_guru',
      name: 'Guru Randhawa',
      imageUrl: 'https://c.saavncdn.com/artists/Guru_Randhawa_500x500.jpg',
      language: 'Punjabi',
    ),
    ArtistProfile(
      id: 'p_bpraak',
      name: 'B Praak',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/efe513aabaa0a94c4db307ac3431b833/1000x1000-000000-80-0-0.jpg',
      language: 'Punjabi',
    ),
    ArtistProfile(
      id: 'p_harrdy',
      name: 'Harrdy Sandhu',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/738cdc5b00f71b067fb3e0b0fe52e783/1000x1000-000000-80-0-0.jpg',
      language: 'Punjabi',
    ),
    ArtistProfile(
      id: 'p_jass',
      name: 'Jass Manak',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/4844200d1bbd953d966fbb906bbf2340/1000x1000-000000-80-0-0.jpg',
      language: 'Punjabi',
    ),
    ArtistProfile(
      id: 'p_ammy',
      name: 'Ammy Virk',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/9fe16f6f33ec30a63d504e0012de05bb/1000x1000-000000-80-0-0.jpg',
      language: 'Punjabi',
    ),

    // English & International Pop/Rock
    ArtistProfile(
      id: 'e_weeknd',
      name: 'The Weeknd',
      imageUrl: 'https://c.saavncdn.com/artists/The_Weeknd_500x500.jpg',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_taylor',
      name: 'Taylor Swift',
      imageUrl: 'https://c.saavncdn.com/artists/Taylor_Swift_500x500.jpg',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_ed',
      name: 'Ed Sheeran',
      imageUrl: 'https://c.saavncdn.com/artists/Ed_Sheeran_500x500.jpg',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_coldplay',
      name: 'Coldplay',
      imageUrl: 'https://c.saavncdn.com/artists/Coldplay_500x500.jpg',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_billie',
      name: 'Billie Eilish',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/8eab1a9a644889aabaca1e193e05f984/1000x1000-000000-80-0-0.jpg',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_bruno',
      name: 'Bruno Mars',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/90f0b5b11df4f87ee878f38569b5995b/1000x1000-000000-80-0-0.jpg',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_dualipa',
      name: 'Dua Lipa',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/877872aaf75694f11d53c318700ab2b5/1000x1000-000000-80-0-0.jpg',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_justin',
      name: 'Justin Bieber',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/fe097f693cebf1f882e3da79e99e3bf9/1000x1000-000000-80-0-0.jpg',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_drake',
      name: 'Drake',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/eb0ed5b21d1ea5af021fc074ded0e91f/1000x1000-000000-80-0-0.jpg',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_post',
      name: 'Post Malone',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/a5a8cca44e7eab2db7d44e039bed2574/1000x1000-000000-80-0-0.jpg',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_imaginedragons',
      name: 'Imagine Dragons',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/1ba025c23cae3dee14b51152990285fc/1000x1000-000000-80-0-0.jpg',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_eminem',
      name: 'Eminem',
      imageUrl: 'https://c.saavncdn.com/artists/Eminem_500x500.jpg',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_adele',
      name: 'Adele',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/5e22b1d2569cf1ea763b09ff3c978a50/1000x1000-000000-80-0-0.jpg',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_charlie',
      name: 'Charlie Puth',
      imageUrl: 'https://cdn-images.dzcdn.net/images/artist/03a74f573792d5e693427cf34ee03ebf/1000x1000-000000-80-0-0.jpg',
      language: 'English',
    ),
  ];

  static List<YoutubeTrack> rerankSearchResults(List<YoutubeTrack> tracks) =>
      deduplicateArtwork(avoidConsecutiveArtists(rerankWithTaste(tracks)));

  /// Enforces ONE SONG, ONE IMAGE:
  /// Prevents playlist/compilation banners from repeating across multiple songs in the same carousel.
  static List<YoutubeTrack> deduplicateArtwork(List<YoutubeTrack> tracks) {
    if (tracks.isEmpty) return tracks;
    final seenUrls = <String>{};
    final seenIds = <String>{};
    final result = <YoutubeTrack>[];

    for (final track in tracks) {
      if (seenIds.contains(track.id)) continue;
      seenIds.add(track.id);

      final rawUrl = track.thumbnailUrl.trim().toLowerCase();
      // Normalize sizes and query params so 150x150 and 500x500 of the same compilation are caught
      final normalizedUrl = rawUrl
          .replaceAll('150x150', 'size')
          .replaceAll('500x500', 'size')
          .split('?')
          .first;

      if (normalizedUrl.isNotEmpty && seenUrls.contains(normalizedUrl)) {
        // Shared banner detected! Check if track has a 11-char YouTube ID that can provide its own unique thumbnail
        if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(track.id)) {
          final uniqueYtThumb = 'https://i.ytimg.com/vi/${track.id}/hqdefault.jpg';
          final normalizedYt = uniqueYtThumb.toLowerCase();
          if (!seenUrls.contains(normalizedYt)) {
            seenUrls.add(normalizedYt);
            result.add(track.copyWith(thumbnailUrl: uniqueYtThumb));
            continue;
          }
        }
        // Otherwise skip duplicate compilation/album banner so no banner repeats across songs
        continue;
      }

      if (normalizedUrl.isNotEmpty) {
        seenUrls.add(normalizedUrl);
      }
      result.add(track);
    }
    return result;
  }

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
        _favoriteArtists = artistsRaw
            .map((a) => ArtistProfile.fromJson(a as Map<String, dynamic>))
            .where((a) => !isBlockedChannelOrLabel(a.name))
            .toList();

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
          _favoriteArtists = artistsRaw
              .map((a) => ArtistProfile.fromJson(a as Map<String, dynamic>))
              .where((a) => !isBlockedChannelOrLabel(a.name))
              .toList();
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

  static ArtistProfile getArtistProfile(String artistName, {String? fallbackImage}) {
    final cleanName = artistName.trim();
    if (cleanName.isEmpty) {
      return const ArtistProfile(id: 'unknown', name: 'Unknown Artist', imageUrl: '', language: 'All');
    }
    final lower = cleanName.toLowerCase();

    // Check user favorites
    for (final a in _favoriteArtists) {
      if (a.name.toLowerCase() == lower) return a;
    }
    // Check default catalog
    for (final a in defaultArtistCatalog) {
      if (a.name.toLowerCase() == lower || lower.contains(a.name.toLowerCase())) {
        return a;
      }
    }
    // Return dynamically generated profile
    return ArtistProfile(
      id: 'dynamic_${cleanName.hashCode.abs()}',
      name: cleanName,
      imageUrl: fallbackImage ?? '',
      language: 'All',
    );
  }

  static Future<void> recordPlaySignal(String artistName) async {
    final clean = _extractPrimaryArtist(artistName);
    if (clean.isEmpty) return;

    _artistPlayWeights[clean] = (_artistPlayWeights[clean] ?? 0) + 1;
    _sessionArtistBoosts[clean] = ((_sessionArtistBoosts[clean] ?? 0) + 3).clamp(-30, 40);
    await _persistLocal();
  }

  /// Records a short skip (<15s) as a mild current-session negative signal
  /// without erasing long-term preferences.
  static void recordSkipSignal(YoutubeTrack track, Duration playedDuration) {
    if (playedDuration.inSeconds >= 15) return;
    final clean = _extractPrimaryArtist(track.artist);
    if (clean.isEmpty) return;
    _sessionArtistBoosts[clean] = ((_sessionArtistBoosts[clean] ?? 0) - 4).clamp(-30, 40);
  }

  /// Explicit positive feedback ("More like this")
  static Future<void> recordMoreLikeThis(YoutubeTrack track) async {
    _dislikedTrackIds.remove(track.id);
    final clean = _extractPrimaryArtist(track.artist);
    if (clean.isEmpty) return;
    _dislikedArtists.remove(clean);
    _artistPlayWeights[clean] = (_artistPlayWeights[clean] ?? 0) + 3;
    _sessionArtistBoosts[clean] = ((_sessionArtistBoosts[clean] ?? 0) + 12).clamp(-30, 40);
    await _persistLocal();
  }

  /// Explicit negative feedback ("Less like this")
  static void recordLessLikeThis(YoutubeTrack track) {
    _dislikedTrackIds.add(track.id);
    final clean = _extractPrimaryArtist(track.artist);
    if (clean.isNotEmpty) {
      _sessionArtistBoosts[clean] = ((_sessionArtistBoosts[clean] ?? 0) - 15).clamp(-30, 40);
    }
  }

  /// Explicit dismissal ("Not interested")
  static void recordNotInterested(YoutubeTrack track) {
    _dislikedTrackIds.add(track.id);
    final clean = _extractPrimaryArtist(track.artist);
    if (clean.isNotEmpty) {
      _dislikedArtists.add(clean);
    }
  }

  static void clearSessionIntent() {
    _sessionArtistBoosts.clear();
  }

  static List<YoutubeTrack> rerankWithTaste(List<YoutubeTrack> tracks) {
    final filtered = tracks.where((t) {
      if (_dislikedTrackIds.contains(t.id)) return false;
      final primary = _extractPrimaryArtist(t.artist);
      if (_dislikedArtists.contains(primary)) return false;
      return true;
    }).toList();

    if (_favoriteArtists.isEmpty && _artistPlayWeights.isEmpty && _sessionArtistBoosts.isEmpty) {
      return avoidConsecutiveArtists(filtered);
    }

    final favoriteNames = _favoriteArtists.map((a) => a.name.toLowerCase()).toSet();
    final scoredList = List<YoutubeTrack>.from(filtered);

    scoredList.sort((a, b) {
      int scoreA = 0;
      int scoreB = 0;

      final artistALower = a.artist.toLowerCase();
      final artistBLower = b.artist.toLowerCase();
      final primaryA = _extractPrimaryArtist(a.artist);
      final primaryB = _extractPrimaryArtist(b.artist);

      if (favoriteNames.any((fav) => artistALower.contains(fav))) scoreA += 50;
      if (favoriteNames.any((fav) => artistBLower.contains(fav))) scoreB += 50;

      scoreA += (_artistPlayWeights[primaryA] ?? _artistPlayWeights[artistALower] ?? 0).clamp(0, 20);
      scoreB += (_artistPlayWeights[primaryB] ?? _artistPlayWeights[artistBLower] ?? 0).clamp(0, 20);

      // Layer 2: current-session intent boost/penalty
      scoreA += _sessionArtistBoosts[primaryA] ?? 0;
      scoreB += _sessionArtistBoosts[primaryB] ?? 0;

      return scoreB.compareTo(scoreA);
    });

    return avoidConsecutiveArtists(scoredList);
  }

  /// Avoids consecutive tracks from the same artist to ensure diverse playback flow
  static List<YoutubeTrack> avoidConsecutiveArtists(List<YoutubeTrack> tracks) {
    if (tracks.length <= 1) return tracks;
    final List<YoutubeTrack> result = [];
    final List<YoutubeTrack> pool = List.from(tracks);

    String? lastArtist;
    while (pool.isNotEmpty) {
      int targetIdx = pool.indexWhere((t) {
        final currentArtist = _extractPrimaryArtist(t.artist);
        return lastArtist == null || currentArtist != lastArtist;
      });

      if (targetIdx == -1) {
        result.addAll(pool);
        break;
      }

      final chosen = pool.removeAt(targetIdx);
      result.add(chosen);
      lastArtist = _extractPrimaryArtist(chosen.artist);
    }
    return result;
  }

  static String _extractPrimaryArtist(String fullArtist) {
    final lower = fullArtist.trim().toLowerCase();
    return lower.split(RegExp(r'[,&/]')).first.trim();
  }

  /// Live search for ANY artist online with real official portrait resolution
  static Future<ArtistProfile?> searchArtistLive(YoutubeMusicService musicService, String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || isBlockedChannelOrLabel(trimmed)) return null;

    // 1. Wikipedia PageImages API (real high-res official portraits)
    try {
      final wikiUrl = Uri.parse(
        'https://en.wikipedia.org/w/api.php?action=query&titles=${Uri.encodeComponent(trimmed)}&prop=pageimages&format=json&pithumbsize=500',
      );
      final wikiRes = await http.get(wikiUrl, headers: {
        'User-Agent': 'MusicApp/1.0 (contact: support@musicapp.com)'
      }).timeout(const Duration(seconds: 4));

      if (wikiRes.statusCode == 200) {
        final data = json.decode(wikiRes.body) as Map<String, dynamic>;
        final pages = data['query']?['pages'] as Map<String, dynamic>?;
        if (pages != null && pages.isNotEmpty) {
          final firstPage = pages.values.first as Map<String, dynamic>;
          final thumb = firstPage['thumbnail']?['source']?.toString();
          if (thumb != null && thumb.isNotEmpty) {
            return ArtistProfile(
              id: 'custom_${trimmed.hashCode.abs()}',
              name: trimmed,
              imageUrl: thumb,
              language: 'All',
            );
          }
        }
      }
    } catch (_) {}

    // 2. Try JioSaavn CDN
    try {
      final saavnSlug = trimmed.replaceAll(' ', '_');
      final saavnUrl = 'https://c.saavncdn.com/artists/${saavnSlug}_500x500.jpg';
      final headRes = await http.head(Uri.parse(saavnUrl)).timeout(const Duration(seconds: 3));
      if (headRes.statusCode == 200) {
        return ArtistProfile(
          id: 'custom_${trimmed.hashCode.abs()}',
          name: trimmed,
          imageUrl: saavnUrl,
          language: 'All',
        );
      }
    } catch (_) {}

    // 3. Fallback to YouTube track thumbnail
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
      imageUrl: '',
      language: 'All',
    );
  }
}
