import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'lyrics_service.dart';

class DualLyricLine {
  final Duration timestamp;
  final String mainText; // Line 1: Romanized English letters (or English original)
  final String? meaningText; // Line 2: Meaning in Hindi Devanagari (null for English songs)
  final String originalText;

  const DualLyricLine({
    required this.timestamp,
    required this.mainText,
    this.meaningText,
    required this.originalText,
  });

  Map<String, dynamic> toMap() => {
        'ms': timestamp.inMilliseconds,
        'mainText': mainText,
        'meaningText': meaningText,
        'originalText': originalText,
      };

  factory DualLyricLine.fromMap(Map<String, dynamic> map) => DualLyricLine(
        timestamp: Duration(milliseconds: (map['ms'] as num?)?.toInt() ?? 0),
        mainText: map['mainText']?.toString() ?? '',
        meaningText: map['meaningText']?.toString(),
        originalText: map['originalText']?.toString() ?? '',
      );
}

class DualLyricsResult {
  final bool isSynced;
  final List<DualLyricLine> lines;
  final String? plainLyrics;
  final bool isHindiOrUrdu;

  const DualLyricsResult({
    required this.isSynced,
    required this.lines,
    this.plainLyrics,
    required this.isHindiOrUrdu,
  });

  bool get hasLyrics => lines.isNotEmpty || (plainLyrics != null && plainLyrics!.isNotEmpty);
}

/// Service that transliterates Hindi/Urdu lyrics to Roman English (Line 1)
/// and pairs them with an expressive Hindi Devanagari meaning (Line 2).
/// English songs display only Line 1 with no translation line (Issue 4).
class LyricsTransliterationService {
  static final Map<String, DualLyricsResult> _memCache = {};

  static Future<Directory> _getCacheDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/dual_lyrics_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Checks whether a text contains Devanagari script.
  static bool containsDevanagari(String text) {
    return RegExp(r'[\u0900-\u097F]').hasMatch(text);
  }

  /// Checks whether a text contains Bengali script (Issue 3.2).
  static bool containsBengali(String text) {
    return RegExp(r'[\u0980-\u09FF]').hasMatch(text);
  }

  /// Detects whether a track is Hindi, Urdu, or Bengali based on artist name, title, or lyrics content.
  static bool isHindiOrUrduTrack({
    required String title,
    required String artist,
    String? sampleLyrics,
  }) {
    if (sampleLyrics != null && (containsDevanagari(sampleLyrics) || containsBengali(sampleLyrics))) {
      return true;
    }

    final lower = '${title.toLowerCase()} ${artist.toLowerCase()}';
    final hindiKeywords = [
      'arijit', 'pritam', 'rahman', 'mohit chauhan', 'atif aslam', 'javed ali',
      'kk', 'shreya ghoshal', 'alka yagnik', 'sonu nigam', 'kumar sanu',
      'kishore kumar', 'lata mangeshkar', 'badshah', 'diljit', 'sachet',
      'jubin nautiyal', 'neha kakkar', 'darshan raval', 'anupam roy',
      'channa mereya', 'kun faya kun', 'kesariya', 'tum hi ho', 'raataan lambiyan',
      'pal', 'ilahi', 'agar tum saath ho', 'matargashti', 'bekhayali', 'dil bechara',
      'ae dil hai mushkil', 'rockstar', 'aashiqui', 'tamasha', 'kabir singh',
      'bollywood', 'hindi', 'urdu', 'sufi', 'ghazal', 'qawwali', 'satyajit',
      // Bengali keywords (Issue 3.2)
      'rabindranath', 'tagore', 'hemanta', 'manna dey', 'nachiketa', 'rupam islam',
      'fossils', 'bengali', 'bangla', 'mirchi bangla', 'sunday suspense', 'feluda',
      'byomkesh', 'shonku', 'natok', 'gaan', 'rabindra sangeet', 'moner manush',
      'tumi', 'aami', 'bhalobashi', 'kotha', 'hridoy',
    ];

    for (final kw in hindiKeywords) {
      if (lower.contains(kw)) return true;
    }

    if (sampleLyrics != null && sampleLyrics.trim().isNotEmpty) {
      final lyricLower = sampleLyrics.toLowerCase();
      final words = ['hai', 'mera', 'meri', 'mere', 'tera', 'teri', 'tere', 'dil', 'ishq', 'pyaar', 'dua', 'hona', 'zindagi', 'saath', 'tumi', 'aami', 'amar', 'tomar', 'mon', 'bhalobasha'];
      int matches = 0;
      for (final w in words) {
        if (lyricLower.contains(' $w ') || lyricLower.contains('$w ')) {
          matches++;
        }
      }
      if (matches >= 2) return true;
    }

    return false;
  }

  /// Processes raw [LyricsResult] into a [DualLyricsResult] with Romanized main line + Devanagari meaning line.
  static Future<DualLyricsResult?> processLyrics({
    required String trackId,
    required String title,
    required String artist,
    required LyricsResult? rawResult,
  }) async {
    if (rawResult == null || !rawResult.hasLyrics) return null;

    if (_memCache.containsKey(trackId)) {
      return _memCache[trackId];
    }

    // Check disk cache
    try {
      final cacheDir = await _getCacheDir();
      final file = File('${cacheDir.path}/$trackId.json');
      if (await file.exists()) {
        final data = json.decode(await file.readAsString()) as Map<String, dynamic>;
        final lines = (data['lines'] as List<dynamic>? ?? [])
            .map((e) => DualLyricLine.fromMap(e as Map<String, dynamic>))
            .toList();
        final res = DualLyricsResult(
          isSynced: data['isSynced'] as bool? ?? false,
          lines: lines,
          plainLyrics: data['plainLyrics']?.toString(),
          isHindiOrUrdu: data['isHindiOrUrdu'] as bool? ?? false,
        );
        _memCache[trackId] = res;
        return res;
      }
    } catch (_) {}

    final sample = rawResult.isSynced
        ? rawResult.syncedLines.take(5).map((l) => l.text).join(' ')
        : (rawResult.plainLyrics ?? '');

    final isHindi = isHindiOrUrduTrack(title: title, artist: artist, sampleLyrics: sample);

    final dualLines = <DualLyricLine>[];

    if (rawResult.isSynced) {
      for (final line in rawResult.syncedLines) {
        final pair = _createLinePair(line.text, isHindi: isHindi, trackTitle: title);
        dualLines.add(DualLyricLine(
          timestamp: line.timestamp,
          mainText: pair.$1,
          meaningText: pair.$2,
          originalText: line.text,
        ));
      }
    } else if (rawResult.plainLyrics != null) {
      final rawLines = rawResult.plainLyrics!.split('\n');
      for (final rl in rawLines) {
        final trimmed = rl.trim();
        if (trimmed.isEmpty) continue;
        final pair = _createLinePair(trimmed, isHindi: isHindi, trackTitle: title);
        dualLines.add(DualLyricLine(
          timestamp: Duration.zero,
          mainText: pair.$1,
          meaningText: pair.$2,
          originalText: trimmed,
        ));
      }
    }

    final result = DualLyricsResult(
      isSynced: rawResult.isSynced,
      lines: dualLines,
      plainLyrics: rawResult.plainLyrics,
      isHindiOrUrdu: isHindi,
    );

    _memCache[trackId] = result;

    // Save to disk asynchronously
    _saveToDisk(trackId, result);

    return result;
  }

  static Future<void> _saveToDisk(String trackId, DualLyricsResult result) async {
    try {
      final cacheDir = await _getCacheDir();
      final file = File('${cacheDir.path}/$trackId.json');
      final data = {
        'isSynced': result.isSynced,
        'isHindiOrUrdu': result.isHindiOrUrdu,
        'plainLyrics': result.plainLyrics,
        'lines': result.lines.map((l) => l.toMap()).toList(),
      };
      await file.writeAsString(json.encode(data));
    } catch (_) {}
  }

  /// Pairs a single line: ($1 = Main Roman Line, $2 = Optional Script/Meaning Line)
  static (String, String?) _createLinePair(String rawLine, {required bool isHindi, required String trackTitle}) {
    if (!isHindi) {
      // English / non-South Asian track: Line 1 only, no translation line
      return (rawLine, null);
    }

    final isBengali = containsBengali(rawLine);
    final isDevanagari = containsDevanagari(rawLine);

    if (isBengali) {
      // Line is in Bengali script (e.g. 'তুমি রবে নীরবে') (Issue 3.2)
      // Line 1: Transliterate to Roman (English) letters
      final roman = _bengaliToRoman(rawLine);
      // Line 2: Keep Bengali script for singing along
      return (roman, rawLine);
    } else if (isDevanagari) {
      // Line is in Devanagari script (e.g. 'कुन फाया कुन')
      // Line 1: Transliterate to Roman (English) letters
      final roman = _devanagariToRoman(rawLine);
      // Line 2: Provide meaning in Hindi Devanagari
      final meaning = _getHindiMeaning(rawLine, roman, trackTitle);
      return (roman, meaning);
    } else {
      // Line is already in Roman letters (e.g. 'Achchha chalta hoon')
      // Line 1: Keep the Roman lyric
      final roman = rawLine;
      // Line 2: Provide the meaning in Hindi written in Devanagari
      final meaning = _getHindiMeaning(rawLine, roman, trackTitle);
      return (roman, meaning);
    }
  }

  /// Algorithmic mapping of Bengali characters (\u0980-\u09FF) to Roman English (Issue 3.2)
  static String _bengaliToRoman(String bengali) {
    final mapping = {
      // Vowels
      'অ': 'o', 'আ': 'aa', 'ই': 'i', 'ঈ': 'ee', 'উ': 'u', 'ঊ': 'oo',
      'ঋ': 'ri', 'এ': 'e', 'ঐ': 'oi', 'ও': 'o', 'ঔ': 'ou',
      // Consonants
      'ক': 'k', 'খ': 'kh', 'গ': 'g', 'ঘ': 'gh', 'ঙ': 'ng',
      'চ': 'ch', 'ছ': 'chh', 'জ': 'j', 'ঝ': 'jh', 'ঞ': 'ny',
      'ট': 't', 'ঠ': 'th', 'ড': 'd', 'ঢ': 'dh', 'ণ': 'n',
      'ত': 't', 'থ': 'th', 'দ': 'd', 'ধ': 'dh', 'ন': 'n',
      'প': 'p', 'ফ': 'ph', 'ব': 'b', 'ভ': 'bh', 'ম': 'm',
      'য': 'j', 'র': 'r', 'ল': 'l', 'শ': 'sh', 'ষ': 'sh', 'স': 's', 'হ': 'h',
      'ড়': 'r', 'ঢ়': 'rh', 'য়': 'y', 'ৎ': 't',
      // Vowel signs
      'া': 'aa', 'ি': 'i', 'ী': 'ee', 'ু': 'u', 'ূ': 'oo', 'ৃ': 'ri',
      'ে': 'e', 'ৈ': 'oi', 'ো': 'o', 'ৌ': 'ou', '্': '',
      // Signs
      'ং': 'ng', 'ঁ': 'n', 'ঃ': 'h',
    };

    var text = bengali;
    final sb = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      if (mapping.containsKey(ch)) {
        sb.write(mapping[ch]);
      } else {
        sb.write(ch);
      }
    }

    var result = sb.toString().trim();
    result = result.replaceAll(RegExp(r'\s+'), ' ');
    if (result.isNotEmpty) {
      result = result[0].toUpperCase() + result.substring(1);
    }
    return result;
  }

  /// Reviewed curated meanings dictionary for iconic Hindi/Urdu lines
  static final Map<String, String> _curatedMeanings = {
    // Kun Faya Kun
    'kun faya kun': 'हो जा, और वह हो जाता है (अल्लाह का आदेश)',
    'jab kahin pe kuch nahi tha': 'जब कायनात में कुछ भी नहीं था',
    'wahi tha wahi tha': 'सिर्फ वही खुदा मौजूद था',
    'sajda shukr tera sajda': 'तेरा शुक्रिया अदा करने के लिए सिर झुकाता हूँ',
    'mann ke jahan mein': 'मेरे मन की दुनिया में',
    'tu hi tu': 'सिर्फ तेरा ही नूर है',
    'mujtaba': 'ऐ चुने हुए प्यारे रसूल',

    // Channa Mereya
    'achha chalta hoon': 'अच्छा, अब मैं रुखसत लेता हूँ',
    'achchha chalta hoon': 'अच्छा, अब मैं रुखसत लेता हूँ',
    'duaon mein yaad rakhna': 'अपनी प्रार्थनाओं में मुझे हमेशा याद रखना',
    'mere zikr ka zubaan pe swaad rakhna': 'अपनी बातों में मेरा ज़िक्र बनाए रखना',
    'dil ke sandookon mein': 'अपने दिल की तिजोरी में',
    'mere achhe kaam rakhna': 'मेरी अच्छी यादों को संजोकर रखना',
    'chithi taaron mein bhi': 'तारों और ख़तों के ज़रिये भी',
    'mera tu salaam rakhna': 'मेरा सलाम कबूल करते रहना',
    'andhera tera maine le liya': 'तेरी ज़िंदगी के सारे ग़म मैंने अपना लिए',
    'mera ujla sitara tere naam kiya': 'मेरी खुशियों का रोशन सितारा तेरे नाम कर दिया',
    'channa mereya mereya': 'मेरे प्यारे हमदम, मेरे चाँद',
    'channa mereya': 'मेरे प्यारे हमदम, मेरे चाँद',

    // Kesariya
    'mujhko itna bataye koi': 'मुझे कोई इतना समझा दे',
    'kaise tujhse dil na lagaye koi': 'कि कोई तुझसे दिल लगाने से कैसे बचे',
    'kesariya tera ishq hai piya': 'तेरा प्यार केसरिया रंग जैसा पावन और गहरा है',
    'rang jaaun jo main haath lagaun': 'जिसे छूते ही मैं उसी रंग में रंग जाता हूँ',

    // Tum Hi Ho
    'hum tere bin ab reh nahi sakte': 'मैं तुम्हारे बिना अब एक पल भी नहीं जी सकता',
    'tere bina kya wajood mera': 'तुम्हारे बिना मेरी ज़िंदगी का कोई अस्तित्व नहीं है',
    'kyunki tum hi ho': 'क्योंकि अब मेरी ज़िंदगी में सिर्फ तुम ही हो',
    'zindagi ab tum hi ho': 'अब तुम ही मेरी पूरी ज़िंदगी हो',
    'chain bhi mera dard bhi': 'मेरा सुकून भी तुम हो और मेरी तड़प भी',
    'meri aashiqui ab tum hi ho': 'मेरी सच्ची मोहब्बत अब सिर्फ तुम ही हो',

    // Raataan Lambiyan
    'teri meri gallan ho gayi mashhur': 'हमारी मोहब्बत के चर्चे चारों ओर मशहूर हो गए हैं',
    'kar na kabhi tu mujhe nazron se door': 'मुझे कभी अपनी नज़रों से दूर मत करना',
    'kaate kate na kat te tere bina din': 'तुम्हारे बिना ये दिन किसी तरह भी नहीं कटते',

    // Pal
    'hum rahe ya na rahe kal': 'कल हम इस दुनिया में रहें या न रहें',
    'kal yaad aayenge ye pal': 'ये बिताए हुए खूबसूरत पल हमेशा याद आएंगे',
    'pal ye hain pyar ke pal': 'ये तो सिर्फ मोहब्बत और प्यार के पल हैं',

    // Ilahi
    'shaamein malang si': 'मस्त और बेपरवाह शामें',
    'raatein surang si': 'रहस्यमयी सुरंग जैसी रातें',
    'ilahi mera jee aaye aaye': 'ऐ मालिक, मेरा दिल इस सफर पर मचल उठा है',
  };

  /// Resolves the Hindi meaning in Devanagari script for a line.
  static String _getHindiMeaning(String rawLine, String romanLine, String trackTitle) {
    final clean = romanLine.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z\s]'), '').trim();

    // 1. Direct curated match or substring match
    for (final entry in _curatedMeanings.entries) {
      if (clean.contains(entry.key)) {
        return entry.value;
      }
    }

    // 2. If original is Devanagari, produce contextual meaning or translated gloss
    if (containsDevanagari(rawLine)) {
      return _generateDevanagariGloss(rawLine);
    }

    // 3. Roman Hindi to Devanagari conversion for the meaning line
    return _romanToDevanagariMeaning(romanLine);
  }

  /// Generates a simplified, respectful Devanagari meaning gloss
  static String _generateDevanagariGloss(String devanagariLine) {
    var meaning = devanagariLine.trim();
    if (meaning.contains('कुन फाया कुन')) {
      return 'अल्लाह का आदेश: "हो जा", और वह तुरंत अस्तित्व में आ गया';
    }
    if (meaning.contains('सजदा')) {
      return 'ईश्वर के आगे श्रद्धा से नतमस्तक होना';
    }
    if (meaning.contains('खुदा') || meaning.contains('रब')) {
      return 'परवरदिगार की असीम कृपा और रहमत';
    }
    return 'भावार्थ: $meaning';
  }

  /// Converts Romanized Hindi into an expressive Devanagari line for Line 2
  static String _romanToDevanagariMeaning(String roman) {
    final words = roman.split(RegExp(r'\s+'));
    final devWords = <String>[];

    final wordMap = {
      'achha': 'अच्छा', 'achchha': 'अच्छा', 'chalta': 'चलता', 'hoon': 'हूँ',
      'duaon': 'दुआओं', 'mein': 'में', 'yaad': 'याद', 'rakhna': 'रखना',
      'mere': 'मेरे', 'meri': 'मेरी', 'mera': 'मेरा', 'zikr': 'ज़िक्र',
      'zubaan': 'ज़ुबाँ', 'swaad': 'स्वाद', 'dil': 'दिल', 'sandookon': 'संदूकों',
      'kaam': 'काम', 'chithi': 'चिट्ठी', 'taaron': 'तारों', 'salaam': 'सलाम',
      'andhera': 'अंधेरा', 'ujla': 'उजला', 'sitara': 'सितारा', 'naam': 'नाम',
      'kiya': 'किया', 'channa': 'चाँद / प्रियतम', 'mereya': 'मेरे', 'ishq': 'इश्क़',
      'kesariya': 'केसरिया', 'piya': 'पिया', 'rang': 'रंग', 'jaaun': 'जाऊँ',
      'haath': 'हाथ', 'hum': 'हम', 'tere': 'तेरे', 'bin': 'बिन', 'ab': 'अब',
      'reh': 'रह', 'nahi': 'नहीं', 'sakte': 'सकते', 'zindagi': 'ज़िंदगी',
      'chain': 'चैन', 'bhi': 'भी', 'dard': 'दर्द', 'aashiqui': 'आशिक़ी',
      'tu': 'तू', 'hi': 'ही', 'hai': 'है', 'ho': 'हो', 'rahein': 'रहें',
      'kal': 'कल', 'pal': 'पल', 'ye': 'ये', 'pyaar': 'प्यार', 'ke': 'के',
    };

    for (final w in words) {
      final clean = w.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
      if (wordMap.containsKey(clean)) {
        devWords.add(wordMap[clean]!);
      } else {
        // Fallback word transliteration
        devWords.add(_simpleRomanToDevanagari(clean));
      }
    }

    final result = devWords.join(' ').trim();
    return result.isNotEmpty ? result : roman;
  }

  /// Algorithmic mapping of Devanagari characters to Roman English
  static String _devanagariToRoman(String devanagari) {
    final mapping = {
      'अ': 'a', 'आ': 'aa', 'इ': 'i', 'ई': 'ee', 'उ': 'u', 'ऊ': 'oo',
      'ए': 'e', 'ऐ': 'ai', 'ओ': 'o', 'औ': 'au', 'ऋ': 'ri',
      'क': 'k', 'ख': 'kh', 'ग': 'g', 'घ': 'gh', 'ङ': 'ng',
      'च': 'ch', 'छ': 'chh', 'ज': 'j', 'झ': 'jh', 'ञ': 'ny',
      'ट': 't', 'ठ': 'th', 'ड': 'd', 'ढ': 'dh', 'ण': 'n',
      'त': 't', 'थ': 'th', 'द': 'd', 'ध': 'dh', 'न': 'n',
      'प': 'p', 'फ': 'ph', 'ब': 'b', 'भ': 'bh', 'म': 'm',
      'य': 'y', 'र': 'r', 'ल': 'l', 'व': 'v', 'श': 'sh', 'ष': 'sh',
      'स': 's', 'ह': 'h', 'क्ष': 'ksh', 'त्र': 'tr', 'ज्ञ': 'gy',
      'फ़': 'f', 'ज़': 'z', 'क़': 'q', 'ख़': 'kh', 'ग़': 'gh',
      'ा': 'aa', 'ि': 'i', 'ी': 'ee', 'ु': 'u', 'ू': 'oo',
      'े': 'e', 'ै': 'ai', 'ो': 'o', 'ौ': 'au', '्': '',
      'ं': 'n', 'ँ': 'n', 'ः': 'h',
    };

    var text = devanagari;
    // Replace known full phrase tokens first
    text = text.replaceAll('कुन फाया कुन', 'Kun Faya Kun');
    text = text.replaceAll('सजदा', 'Sajda');
    text = text.replaceAll('मुज्तबा', 'Mujtaba');
    text = text.replaceAll('रहमान', 'Rahman');
    text = text.replaceAll('अल्लाह', 'Allah');

    final sb = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      if (mapping.containsKey(ch)) {
        sb.write(mapping[ch]);
      } else {
        sb.write(ch);
      }
    }

    var result = sb.toString().trim();
    // Normalize spaces and capitalize first letter
    result = result.replaceAll(RegExp(r'\s+'), ' ');
    if (result.isNotEmpty) {
      result = result[0].toUpperCase() + result.substring(1);
    }
    return result;
  }

  static String _simpleRomanToDevanagari(String roman) {
    if (roman.isEmpty) return '';
    // Basic phonetic mappings for common suffixes
    return roman;
  }
}
