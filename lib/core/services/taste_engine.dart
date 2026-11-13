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
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/90/Jubin_Nauityal_at_the_Good_Homes_Awards_2015.jpg/500px-Jubin_Nauityal_at_the_Good_Homes_Awards_2015.jpg',
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
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e0/Vishal_Mishra_at_IIFA_2019.jpg/500px-Vishal_Mishra_at_IIFA_2019.jpg',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_darshan',
      name: 'Darshan Raval',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b3/Darshan_Raval_in_2020.jpg/500px-Darshan_Raval_in_2020.jpg',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_anuv_jain',
      name: 'Anuv Jain',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5e/Anuv_Jain_performing_in_2023.jpg/500px-Anuv_Jain_performing_in_2023.jpg',
      language: 'Hindi',
    ),
    ArtistProfile(
      id: 'h_prateek',
      name: 'Prateek Kuhad',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/ae/Prateek_Kuhad_2019.jpg/500px-Prateek_Kuhad_2019.jpg',
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
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/92/Nachiketa_Chakraborty.jpg/500px-Nachiketa_Chakraborty.jpg',
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
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b9/Anjan_Dutt_in_2017_premiere.png/500px-Anjan_Dutt_in_2017_premiere.png',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_kabir',
      name: 'Kabir Suman',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/84/Kabir_Suman_playing_organ.jpg/500px-Kabir_Suman_playing_organ.jpg',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_somlata',
      name: 'Somlata Acharyya',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/90/Somlata_Acharyya_Chowdhury.jpg/500px-Somlata_Acharyya_Chowdhury.jpg',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_rupankar',
      name: 'Rupankar Bagchi',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5e/Rupankar_Bagchi_2016.jpg/500px-Rupankar_Bagchi_2016.jpg',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_iman',
      name: 'Iman Chakraborty',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/Iman_Chakraborty_in_2018.jpg/500px-Iman_Chakraborty_in_2018.jpg',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_lagnajita',
      name: 'Lagnajita Chakraborty',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/23/Lagnajita_Chakraborty.jpg/500px-Lagnajita_Chakraborty.jpg',
      language: 'Bengali',
    ),
    ArtistProfile(
      id: 'b_monali',
      name: 'Monali Thakur',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b5/Monali_Thakur_at_Mirchi_Music_Awards_2014.jpg/500px-Monali_Thakur_at_Mirchi_Music_Awards_2014.jpg',
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
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7a/Sidhu_Moose_Wala_during_the_shooting_of_his_film_Moosa_Jatt_%28cropped%29.jpg/500px-Sidhu_Moose_Wala_during_the_shooting_of_his_film_Moosa_Jatt_%28cropped%29.jpg',
      language: 'Punjabi',
    ),
    ArtistProfile(
      id: 'p_ap',
      name: 'AP Dhillon',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0f/AP_Dhillon_in_2023.jpg/500px-AP_Dhillon_in_2023.jpg',
      language: 'Punjabi',
    ),
    ArtistProfile(
      id: 'p_karan',
      name: 'Karan Aujla',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/36/Karan_Aujla_2021.jpg/500px-Karan_Aujla_2021.jpg',
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
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1a/B_Praak_2020.jpg/500px-B_Praak_2020.jpg',
      language: 'Punjabi',
    ),
    ArtistProfile(
      id: 'p_harrdy',
      name: 'Harrdy Sandhu',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/24/Harrdy_Sandhu_2019.jpg/500px-Harrdy_Sandhu_2019.jpg',
      language: 'Punjabi',
    ),
    ArtistProfile(
      id: 'p_jass',
      name: 'Jass Manak',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/89/Jass_Manak_2020.jpg/500px-Jass_Manak_2020.jpg',
      language: 'Punjabi',
    ),
    ArtistProfile(
      id: 'p_ammy',
      name: 'Ammy Virk',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/78/Ammy_Virk_in_2019.jpg/500px-Ammy_Virk_in_2019.jpg',
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
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f2/Billie_Eilish_at_the_2024_Toronto_International_Film_Festival_%28cropped%29.jpg/500px-Billie_Eilish_at_the_2024_Toronto_International_Film_Festival_%28cropped%29.jpg',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_bruno',
      name: 'Bruno Mars',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b3/Bruno_Mars_2017.jpg/500px-Bruno_Mars_2017.jpg',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_dualipa',
      name: 'Dua Lipa',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/28/Dua_Lipa_2022.jpg/500px-Dua_Lipa_2022.jpg',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_justin',
      name: 'Justin Bieber',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/da/Justin_Bieber_in_2015.jpg/500px-Justin_Bieber_in_2015.jpg',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_drake',
      name: 'Drake',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/28/Drake_July_2016.jpg/500px-Drake_July_2016.jpg',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_post',
      name: 'Post Malone',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/27/Post_Malone_2018.jpg/500px-Post_Malone_2018.jpg',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_imaginedragons',
      name: 'Imagine Dragons',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/90/Imagine_Dragons_2017.jpg/500px-Imagine_Dragons_2017.jpg',
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
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7c/Adele_2016.jpg/500px-Adele_2016.jpg',
      language: 'English',
    ),
    ArtistProfile(
      id: 'e_charlie',
      name: 'Charlie Puth',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9b/Charlie_Puth_2018.jpg/500px-Charlie_Puth_2018.jpg',
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
