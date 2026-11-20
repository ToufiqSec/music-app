import '../models/audiobook_model.dart';
import '../../../features/music/models/music_models.dart';

class SampleAudiobooks {
  static final List<AudiobookModel> books = [
    const AudiobookModel(
      id: 'ab_sherlock',
      title: 'The Adventures of Sherlock Holmes',
      author: 'Arthur Conan Doyle',
      narrator: 'David Clarke',
      coverUrl: 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=500&auto=format&fit=crop',
      description: 'The legendary detective Sherlock Holmes and Dr. Watson investigate twelve perplexing cases in Victorian London.',
      chapters: [
        AudiobookChapter(
          id: 'W_q62wT8fOU',
          title: 'A Scandal in Bohemia',
          chapterNumber: 1,
          durationSeconds: 3240,
        ),
        AudiobookChapter(
          id: 'hH9zM2_d3Z8',
          title: 'The Red-Headed League',
          chapterNumber: 2,
          durationSeconds: 2880,
        ),
        AudiobookChapter(
          id: 'u5GjK3Gj45M',
          title: 'A Case of Identity',
          chapterNumber: 3,
          durationSeconds: 2460,
        ),
        AudiobookChapter(
          id: 'J7kKzF1QJfs',
          title: 'The Boscombe Valley Mystery',
          chapterNumber: 4,
          durationSeconds: 3120,
        ),
      ],
    ),
    const AudiobookModel(
      id: 'ab_gitanjali',
      title: 'Gitanjali: Song Offerings',
      author: 'Rabindranath Tagore',
      narrator: 'Soumitra Chatterjee',
      coverUrl: 'https://images.unsplash.com/photo-1512820790803-83ca734da794?w=500&auto=format&fit=crop',
      description: 'Nobel Prize winning collection of mystical, philosophical, and spiritual poetry translated into lyrical prose.',
      chapters: [
        AudiobookChapter(
          id: '7DqR3zK6b5M',
          title: 'Chapter 1: Thou Hast Made Me Endless',
          chapterNumber: 1,
          durationSeconds: 1800,
        ),
        AudiobookChapter(
          id: 'eY8k1Uq7Y1A',
          title: 'Chapter 2: When Thou Commandest Me to Sing',
          chapterNumber: 2,
          durationSeconds: 1950,
        ),
        AudiobookChapter(
          id: '9qTfKq5Wz5c',
          title: 'Chapter 3: Where the Mind is Without Fear',
          chapterNumber: 3,
          durationSeconds: 2100,
        ),
      ],
    ),
    const AudiobookModel(
      id: 'ab_war_worlds',
      title: 'The War of the Worlds',
      author: 'H.G. Wells',
      narrator: 'Orson Welles Heritage',
      coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&auto=format&fit=crop',
      description: 'Martians invade Earth with heat-rays and towering fighting-machines in the pioneering classic of science fiction.',
      chapters: [
        AudiobookChapter(
          id: 'w9K8s5vL1M8',
          title: 'The Eve of the War',
          chapterNumber: 1,
          durationSeconds: 2700,
        ),
        AudiobookChapter(
          id: 'pM6t8kL1Q5Y',
          title: 'The Falling Star',
          chapterNumber: 2,
          durationSeconds: 2400,
        ),
        AudiobookChapter(
          id: 'r8k9L2m4T1V',
          title: 'On Horsell Common',
          chapterNumber: 3,
          durationSeconds: 2900,
        ),
      ],
    ),
    const AudiobookModel(
      id: 'ab_feluda',
      title: 'The Royal Bengal Mystery',
      author: 'Satyajit Ray',
      narrator: 'Mirchi Audio Classics',
      coverUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=500&auto=format&fit=crop',
      description: 'Pradosh C. Mitter (Feluda) ventures into the forests of Bhutan and North Bengal to decipher a cryptic riddle about buried treasure.',
      chapters: [
        AudiobookChapter(
          id: 'ss_feluda_kathmandu_part1',
          title: 'Part 1: The Cryptic Rhyme',
          chapterNumber: 1,
          durationSeconds: 9813,
          audioUrl: 'https://dts.podtrac.com/redirect.mp3/api.spreaker.com/download/episode/58582188/joto_kando_kathmandu_te.mp3',
        ),
        AudiobookChapter(
          id: 'ss_shonku_baghdad_part2',
          title: 'Part 2: Into the Forest',
          chapterNumber: 2,
          durationSeconds: 3807,
          audioUrl: 'https://dts.podtrac.com/redirect.mp3/api.spreaker.com/download/episode/75550604/baghdad_er_baksho.mp3',
        ),
      ],
    ),
  ];

  static List<YoutubeTrack> getAllChaptersAsTracks() {
    final List<YoutubeTrack> all = [];
    for (final book in books) {
      all.addAll(book.toTrackList());
    }
    return all;
  }
}
