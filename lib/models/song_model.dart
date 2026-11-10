import 'package:audio_service/audio_service.dart';

class SongModelItem {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String uri;
  final String? artUri;
  final bool isLocal;

  SongModelItem({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.uri,
    this.artUri,
    this.isLocal = false,
  });

  MediaItem toMediaItem() {
    return MediaItem(
      id: id,
      album: album,
      title: title,
      artist: artist,
      duration: duration,
      artUri: artUri != null ? Uri.tryParse(artUri!) : null,
      extras: {
        'uri': uri,
        'isLocal': isLocal,
      },
    );
  }

  factory SongModelItem.fromMediaItem(MediaItem mediaItem) {
    return SongModelItem(
      id: mediaItem.id,
      title: mediaItem.title,
      artist: mediaItem.artist ?? 'Unknown Artist',
      album: mediaItem.album ?? 'Unknown Album',
      duration: mediaItem.duration ?? Duration.zero,
      uri: mediaItem.extras?['uri'] ?? '',
      artUri: mediaItem.artUri?.toString(),
      isLocal: mediaItem.extras?['isLocal'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'durationMs': duration.inMilliseconds,
      'uri': uri,
      'artUri': artUri,
      'isLocal': isLocal,
    };
  }

  factory SongModelItem.fromMap(Map<String, dynamic> map) {
    return SongModelItem(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Unknown Title',
      artist: map['artist'] ?? 'Unknown Artist',
      album: map['album'] ?? 'Unknown Album',
      duration: Duration(milliseconds: map['durationMs'] ?? 0),
      uri: map['uri'] ?? '',
      artUri: map['artUri'],
      isLocal: map['isLocal'] ?? false,
    );
  }
}
