import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/curated_songs/domain/curated_song.dart';
import 'package:running_playlist_ai/features/song_search/domain/song_search_service.dart';

void main() {
  /// Small fixture list used across most tests.
  final fixture = [
    const CuratedSong(
      title: 'Lose Yourself',
      artistName: 'Eminem',
      genre: 'hip_hop',
      bpm: 171,
    ),
    const CuratedSong(
      title: 'Running Up That Hill',
      artistName: 'Kate Bush',
      genre: 'synth_pop',
      bpm: 108,
    ),
    const CuratedSong(
      title: "Don't Stop Me Now",
      artistName: 'Queen',
      genre: 'classic_rock',
      bpm: 156,
    ),
    const CuratedSong(
      title: 'Blinding Lights',
      artistName: 'The Weeknd',
      genre: 'synth_pop',
      bpm: 171,
    ),
    const CuratedSong(
      title: 'Stronger',
      artistName: 'Kanye West',
      genre: 'hip_hop',
      bpm: 104,
    ),
    const CuratedSong(
      title: 'Run the World',
      artistName: 'Beyonce',
      genre: 'pop',
      bpm: 127,
    ),
  ];

  late CuratedSongSearchService service;

  setUp(() {
    service = CuratedSongSearchService(fixture);
  });

  group('CuratedSongSearchService', () {
    test('empty query returns empty list', () async {
      final results = await service.search('');
      expect(results, isEmpty);
    });

    test('single character query returns empty list', () async {
      final results = await service.search('a');
      expect(results, isEmpty);
    });

    test('query matching one title returns that song', () async {
      final results = await service.search('Blinding');
      expect(results, hasLength(1));
      expect(results.first.title, 'Blinding Lights');
      expect(results.first.artist, 'The Weeknd');
    });

    test('query matching artist returns that song', () async {
      final results = await service.search('Eminem');
      expect(results, hasLength(1));
      expect(results.first.title, 'Lose Yourself');
    });

    test('case-insensitive match works', () async {
      final results = await service.search('LOSE');
      expect(results, hasLength(1));
      expect(results.first.title, 'Lose Yourself');
    });

    test('query matching nothing returns empty list', () async {
      final results = await service.search('zzzzz');
      expect(results, isEmpty);
    });

    test('results capped at 20 when more matches exist', () async {
      // Build a list of 25 songs all containing "run" in title
      final bigList = List.generate(
        25,
        (i) => CuratedSong(
          title: 'Run Song $i',
          artistName: 'Artist $i',
          genre: 'pop',
          bpm: 150,
        ),
      );
      final bigService = CuratedSongSearchService(bigList);
      final results = await bigService.search('Run');
      expect(results, hasLength(20));
    });

    test('partial substring match works', () async {
      final results = await service.search('run');
      // Matches: "Running Up That Hill" (title contains 'run')
      // and "Run the World" (title contains 'run')
      expect(results, hasLength(2));
      final titles = results.map((r) => r.title).toSet();
      expect(titles, contains('Running Up That Hill'));
      expect(titles, contains('Run the World'));
    });

    test('both title and artist matches appear in results', () async {
      // "west" matches Kanye West (artist) but no titles
      // Add a song with "west" in title to test both paths
      final extendedFixture = [
        ...fixture,
        const CuratedSong(
          title: 'West Coast',
          artistName: 'Lana Del Rey',
          genre: 'indie',
          bpm: 100,
        ),
      ];
      final extService = CuratedSongSearchService(extendedFixture);
      final results = await extService.search('west');
      expect(results, hasLength(2));
      final titles = results.map((r) => r.title).toSet();
      expect(titles, contains('Stronger')); // Kanye West (artist match)
      expect(titles, contains('West Coast')); // title match
    });

    test('source field is curated for all results', () async {
      final results = await service.search('run');
      expect(results, isNotEmpty);
      for (final result in results) {
        expect(result.source, 'curated');
      }
    });
  });
}
