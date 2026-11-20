import '../../music/models/music_models.dart';

class AudiobookChapter {
  final String id;
  final String title;
  final int chapterNumber;
  final int durationSeconds;
  final String? audioUrl;

  const AudiobookChapter({
    required this.id,
    required this.title,
    required this.chapterNumber,
    required this.durationSeconds,
    this.audioUrl,
  });

  YoutubeTrack toTrack(AudiobookModel book) {
    return YoutubeTrack(
      id: id,
      title: '$title • ${book.title}',
      artist: '${book.author} (Audiobook)',
      durationSeconds: durationSeconds,
      thumbnailUrl: book.coverUrl,
      audioStreamUrl: audioUrl,
    );
  }
}

class AudiobookModel {
  final String id;
  final String title;
  final String author;
  final String narrator;
  final String coverUrl;
  final String description;
  final List<AudiobookChapter> chapters;

  const AudiobookModel({
    required this.id,
    required this.title,
    required this.author,
    required this.narrator,
    required this.coverUrl,
    required this.description,
    required this.chapters,
  });

  int get totalDurationSeconds =>
      chapters.fold(0, (sum, c) => sum + c.durationSeconds);

  List<YoutubeTrack> toTrackList() {
    return chapters.map((c) => c.toTrack(this)).toList();
  }
}
