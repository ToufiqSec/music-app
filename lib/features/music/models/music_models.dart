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

  String get thumbnail => thumbnailUrl;

  const YoutubeTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.durationSeconds,
    this.thumbnailUrl = '',
    this.audioStreamUrl,
    this.isDownloaded = false,
    this.localFilePath,
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
    );
  }
}
