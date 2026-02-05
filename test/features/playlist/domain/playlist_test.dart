import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_song.dart';
import 'package:running_playlist_ai/features/playlist/domain/playlist.dart';

void main() {
  // -- PlaylistSong ---------------------------------------------------------

  group('PlaylistSong serialization', () {
    test('toJson -> fromJson round-trip preserves all fields', () {
      const original = PlaylistSong(
        title: 'Test Song',
        artistName: 'Test Artist',
        bpm: 170,
        matchType: BpmMatchType.exact,
        segmentLabel: 'Warm-up',
        segmentIndex: 0,
        songUri: 'https://getsongbpm.com/song/test/abc',
        spotifyUrl:
            'https://open.spotify.com/search/Test%20Song%20Test%20Artist',
        youtubeUrl:
            'https://music.youtube.com/search?q=Test+Song+Test+Artist',
      );

      final json = original.toJson();
      final restored = PlaylistSong.fromJson(json);

      expect(restored.title, equals(original.title));
      expect(restored.artistName, equals(original.artistName));
      expect(restored.bpm, equals(original.bpm));
      expect(restored.matchType, equals(original.matchType));
      expect(restored.segmentLabel, equals(original.segmentLabel));
      expect(restored.segmentIndex, equals(original.segmentIndex));
      expect(restored.songUri, equals(original.songUri));
      expect(restored.spotifyUrl, equals(original.spotifyUrl));
      expect(restored.youtubeUrl, equals(original.youtubeUrl));
    });

    test('toJson -> fromJson with null optional fields', () {
      const original = PlaylistSong(
        title: 'Song',
        artistName: 'Artist',
        bpm: 120,
        matchType: BpmMatchType.halfTime,
        segmentLabel: 'Running',
        segmentIndex: 1,
      );

      final json = original.toJson();
      final restored = PlaylistSong.fromJson(json);

      expect(restored.songUri, isNull);
      expect(restored.spotifyUrl, isNull);
      expect(restored.youtubeUrl, isNull);
    });

    test('toJson includes matchType', () {
      const song = PlaylistSong(
        title: 'Song',
        artistName: 'Artist',
        bpm: 85,
        matchType: BpmMatchType.halfTime,
        segmentLabel: 'Segment 1',
        segmentIndex: 0,
      );
      final json = song.toJson();
      expect(json['matchType'], equals('halfTime'));
    });
  });

  // -- Playlist -------------------------------------------------------------

  group('Playlist serialization', () {
    test('toJson -> fromJson round-trip preserves all fields', () {
      final original = Playlist(
        songs: const [
          PlaylistSong(
            title: 'Song A',
            artistName: 'Artist A',
            bpm: 170,
            matchType: BpmMatchType.exact,
            segmentLabel: 'Running',
            segmentIndex: 0,
          ),
          PlaylistSong(
            title: 'Song B',
            artistName: 'Artist B',
            bpm: 85,
            matchType: BpmMatchType.halfTime,
            segmentLabel: 'Cool-down',
            segmentIndex: 1,
          ),
        ],
        runPlanName: 'My 5K',
        totalDurationSeconds: 1800,
        createdAt: DateTime.utc(2026, 2, 5, 14, 30),
      );

      final json = original.toJson();
      final restored = Playlist.fromJson(json);

      expect(restored.songs.length, equals(2));
      expect(restored.songs[0].title, equals('Song A'));
      expect(restored.songs[1].title, equals('Song B'));
      expect(restored.runPlanName, equals('My 5K'));
      expect(restored.totalDurationSeconds, equals(1800));
      expect(
        restored.createdAt,
        equals(DateTime.utc(2026, 2, 5, 14, 30)),
      );
    });

    test('toJson -> fromJson with null runPlanName', () {
      final original = Playlist(
        songs: const [],
        totalDurationSeconds: 600,
        createdAt: DateTime.utc(2026),
      );

      final json = original.toJson();
      final restored = Playlist.fromJson(json);
      expect(restored.runPlanName, isNull);
    });
  });

  // -- Playlist.toClipboardText ---------------------------------------------

  group('Playlist.toClipboardText', () {
    test('formats playlist with segment headers and song lines', () {
      final playlist = Playlist(
        songs: const [
          PlaylistSong(
            title: 'Song A',
            artistName: 'Artist A',
            bpm: 140,
            matchType: BpmMatchType.exact,
            segmentLabel: 'Warm-up',
            segmentIndex: 0,
          ),
          PlaylistSong(
            title: 'Song B',
            artistName: 'Artist B',
            bpm: 170,
            matchType: BpmMatchType.exact,
            segmentLabel: 'Running',
            segmentIndex: 1,
          ),
          PlaylistSong(
            title: 'Song C',
            artistName: 'Artist C',
            bpm: 170,
            matchType: BpmMatchType.halfTime,
            segmentLabel: 'Running',
            segmentIndex: 1,
          ),
        ],
        runPlanName: 'My 5K',
        totalDurationSeconds: 1800,
        createdAt: DateTime.utc(2026, 2, 5, 14, 30),
      );

      final text = playlist.toClipboardText();

      expect(text, contains('Running Playlist - My 5K'));
      expect(text, contains('--- Warm-up ---'));
      expect(text, contains('Song A - Artist A (140 BPM)'));
      expect(text, contains('--- Running ---'));
      expect(text, contains('Song B - Artist B (170 BPM)'));
      expect(text, contains('Song C - Artist C (170 BPM)'));
    });

    test('uses "My Run" when runPlanName is null', () {
      final playlist = Playlist(
        songs: const [],
        totalDurationSeconds: 600,
        createdAt: DateTime.utc(2026),
      );

      final text = playlist.toClipboardText();
      expect(text, contains('Running Playlist - My Run'));
    });

    test(
      'does not repeat segment header for consecutive songs '
      'in same segment',
      () {
        final playlist = Playlist(
          songs: const [
            PlaylistSong(
              title: 'Song 1',
              artistName: 'A',
              bpm: 170,
              matchType: BpmMatchType.exact,
              segmentLabel: 'Running',
              segmentIndex: 0,
            ),
            PlaylistSong(
              title: 'Song 2',
              artistName: 'B',
              bpm: 170,
              matchType: BpmMatchType.exact,
              segmentLabel: 'Running',
              segmentIndex: 0,
            ),
          ],
          totalDurationSeconds: 600,
          createdAt: DateTime.utc(2026),
        );

        final text = playlist.toClipboardText();
        // 'Running' header should appear only once
        final matches =
            RegExp('--- Running ---').allMatches(text);
        expect(matches.length, equals(1));
      },
    );
  });
}
