import 'package:audio_service/audio_service.dart';

/// Core Music Track Model representing both online streamable & locally cached tracks.
class YoutubeTrack {
  final String id;
  final String title;
  final String artist;
  final int durationSeconds;
  final String thumbnailUrl;
  final String? audioStreamUrl;
  final bool isDownloaded;
  final String? localFilePath;
  final String? album;
  final String? composer;

  String get thumbnail => thumbnailUrl;

  /// Identifies the source provider for honest UI labelling (Problem 1 & 3).
  String get sourceProvider {
    if (localFilePath != null && localFilePath!.isNotEmpty) return 'Local';
    if (id.startsWith('ss_') || (audioStreamUrl?.contains('spreaker.com') ?? false)) return 'Podcast';
    if (id.startsWith('ab_')) return 'Audiobook';
    if (audioStreamUrl != null &&
        (audioStreamUrl!.contains('saavncdn.com') || audioStreamUrl!.contains('jiosaavn'))) {
      return 'JioSaavn';
    }
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id)) return 'YouTube';
    if (audioStreamUrl != null && audioStreamUrl!.isNotEmpty) return 'Direct';
    return 'Catalog';
  }

  /// Honest playability check: distinguishes streamable/local items from dead or webpage links.
  bool get isLikelyPlayable {
    if (localFilePath != null && localFilePath!.isNotEmpty) return true;
    final url = audioStreamUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      final lower = url.toLowerCase();
      if (lower.endsWith('.html') || lower.endsWith('.htm') || lower.contains('youtube.com/watch')) {
        return false;
      }
      return true;
    }
    if (id.startsWith('ss_spk_') || RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id)) return true;
    return id.isNotEmpty && !id.startsWith('unavailable_');
  }

  const YoutubeTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.durationSeconds,
    this.thumbnailUrl = '',
    this.audioStreamUrl,
    this.isDownloaded = false,
    this.localFilePath,
    this.album,
    this.composer,
  });

  YoutubeTrack copyWith({
    String? id,
    String? title,
    String? artist,
    int? durationSeconds,
    String? thumbnailUrl,
    String? audioStreamUrl,
    bool? isDownloaded,
    String? localFilePath,
    String? album,
    String? composer,
  }) {
    return YoutubeTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      audioStreamUrl: audioStreamUrl ?? this.audioStreamUrl,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      localFilePath: localFilePath ?? this.localFilePath,
      album: album ?? this.album,
      composer: composer ?? this.composer,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'durationSeconds': durationSeconds,
      'thumbnailUrl': thumbnailUrl,
      'audioStreamUrl': audioStreamUrl,
      'isDownloaded': isDownloaded,
      'localFilePath': localFilePath,
      'album': album,
      'composer': composer,
    };
  }

  factory YoutubeTrack.fromJson(Map<String, dynamic> json) {
    return YoutubeTrack(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Unknown Title',
      artist: json['artist']?.toString() ?? 'Unknown Artist',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      thumbnailUrl: json['thumbnailUrl']?.toString() ?? '',
      audioStreamUrl: json['audioStreamUrl']?.toString(),
      isDownloaded: json['isDownloaded'] as bool? ?? false,
      localFilePath: json['localFilePath']?.toString(),
      album: json['album']?.toString(),
      composer: json['composer']?.toString(),
    );
  }

  MediaItem toMediaItem() {
    return MediaItem(
      id: id,
      title: title,
      artist: artist,
      duration: Duration(seconds: durationSeconds),
      artUri: thumbnailUrl.isNotEmpty ? Uri.tryParse(thumbnailUrl) : null,
      extras: {
        'audioStreamUrl': audioStreamUrl,
        'localFilePath': localFilePath,
        'isDownloaded': isDownloaded,
        'album': album,
        'composer': composer,
      },
    );
  }

  factory YoutubeTrack.fromMediaItem(MediaItem item) {
    return YoutubeTrack(
      id: item.id,
      title: item.title,
      artist: item.artist ?? 'Unknown Artist',
      durationSeconds: item.duration?.inSeconds ?? 0,
      thumbnailUrl: item.artUri?.toString() ?? '',
      audioStreamUrl: item.extras?['audioStreamUrl'] as String?,
      isDownloaded: item.extras?['isDownloaded'] as bool? ?? false,
      localFilePath: item.extras?['localFilePath'] as String?,
      album: item.extras?['album'] as String?,
      composer: item.extras?['composer'] as String?,
    );
  }
}
