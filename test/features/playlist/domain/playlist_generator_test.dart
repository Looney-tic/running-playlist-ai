import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_song.dart';
import 'package:running_playlist_ai/features/playlist/domain/playlist_generator.dart';
import 'package:running_playlist_ai/features/run_plan/domain/run_plan.dart';
import 'package:running_playlist_ai/features/taste_profile/domain/taste_profile.dart';

/// Helper to create a simple BpmSong.
BpmSong _song({
  String id = 's1',
  String title = 'Song',
  String artist = 'Artist',
  int tempo = 170,
  int? danceability,
}) =>
    BpmSong(
      songId: id,
      title: title,
      artistName: artist,
      tempo: tempo,
      danceability: danceability,
    );

void main() {
  // -- Basic generation -----------------------------------------------------

  group('PlaylistGenerator.generate', () {
    test('generates songs for a single-segment steady run', () {
      const plan = RunPlan(
        type: RunType.steady,
        distanceKm: 5,
        paceMinPerKm: 6,
        segments: [
          RunSegment(
            durationSeconds: 1800,
            targetBpm: 170,
            label: 'Running',
          ),
        ],
      );

      final songsByBpm = {
        170: [
          _song(title: 'Song 1'),
          _song(id: 's2', title: 'Song 2'),
          _song(id: 's3', title: 'Song 3'),
          _song(id: 's4', title: 'Song 4'),
          _song(id: 's5', title: 'Song 5'),
          _song(id: 's6', title: 'Song 6'),
          _song(id: 's7', title: 'Song 7'),
          _song(id: 's8', title: 'Song 8'),
          _song(id: 's9', title: 'Song 9'),
          _song(id: 's10', title: 'Song 10'),
        ],
      };

      final playlist = PlaylistGenerator.generate(
        runPlan: plan,
        songsByBpm: songsByBpm,
        random: Random(42),
      );

      // 1800s / 210s = 8.57 -> ceil = 9 songs needed
      expect(playlist.songs.length, equals(9));
      expect(playlist.runPlanName, isNull);
      expect(playlist.totalDurationSeconds, equals(1800));
      expect(
        playlist.songs.every((s) => s.segmentLabel == 'Running'),
        isTrue,
      );
      expect(
        playlist.songs.every((s) => s.segmentIndex == 0),
        isTrue,
      );
    });

    test('generates songs across multiple segments', () {
      const plan = RunPlan(
        type: RunType.warmUpCoolDown,
        distanceKm: 5,
        paceMinPerKm: 6,
        name: 'My 5K',
        segments: [
          RunSegment(
            durationSeconds: 300,
            targetBpm: 140,
            label: 'Warm-up',
          ),
          RunSegment(
            durationSeconds: 1200,
            targetBpm: 170,
            label: 'Running',
          ),
          RunSegment(
            durationSeconds: 300,
            targetBpm: 140,
            label: 'Cool-down',
          ),
        ],
      );

      final songsByBpm = {
        140: List.generate(
          10,
          (i) => _song(id: 'w$i', title: 'Warm $i', tempo: 140),
        ),
        170: List.generate(
          10,
          (i) => _song(id: 'r$i', title: 'Run $i'),
        ),
        70: List.generate(
          5,
          (i) => _song(id: 'h$i', title: 'Half $i', tempo: 70),
        ),
        85: List.generate(
          5,
          (i) => _song(
            id: 'hr$i',
            title: 'HalfRun $i',
            tempo: 85,
          ),
        ),
      };

      final playlist = PlaylistGenerator.generate(
        runPlan: plan,
        songsByBpm: songsByBpm,
        random: Random(42),
      );

      expect(playlist.runPlanName, equals('My 5K'));

      // Verify songs are assigned to correct segments
      final warmUp =
          playlist.songs.where((s) => s.segmentIndex == 0);
      final running =
          playlist.songs.where((s) => s.segmentIndex == 1);
      final coolDown =
          playlist.songs.where((s) => s.segmentIndex == 2);

      expect(warmUp, isNotEmpty);
      expect(running, isNotEmpty);
      expect(coolDown, isNotEmpty);

      expect(
        warmUp.every((s) => s.segmentLabel == 'Warm-up'),
        isTrue,
      );
      expect(
        running.every((s) => s.segmentLabel == 'Running'),
        isTrue,
      );
      expect(
        coolDown.every((s) => s.segmentLabel == 'Cool-down'),
        isTrue,
      );
    });

    test(
      'defaults segment label to "Segment N" when label is null',
      () {
        const plan = RunPlan(
          type: RunType.steady,
          distanceKm: 5,
          paceMinPerKm: 6,
          segments: [
            RunSegment(durationSeconds: 420, targetBpm: 170),
          ],
        );

        final songsByBpm = {
          170: [
            _song(),
            _song(id: 's2'),
            _song(id: 's3'),
          ],
        };

        final playlist = PlaylistGenerator.generate(
          runPlan: plan,
          songsByBpm: songsByBpm,
          random: Random(42),
        );

        expect(
          playlist.songs.first.segmentLabel,
          equals('Segment 1'),
        );
      },
    );

    test('assigns id, distanceKm, and paceMinPerKm from run plan', () {
      const plan = RunPlan(
        type: RunType.steady,
        distanceKm: 5,
        paceMinPerKm: 6,
        segments: [
          RunSegment(
            durationSeconds: 210,
            targetBpm: 170,
            label: 'Running',
          ),
        ],
      );

      final songsByBpm = {
        170: [_song()],
      };

      final playlist = PlaylistGenerator.generate(
        runPlan: plan,
        songsByBpm: songsByBpm,
        random: Random(42),
      );

      expect(playlist.id, isNotNull);
      expect(playlist.id, isNotEmpty);
      expect(playlist.distanceKm, equals(5.0));
      expect(playlist.paceMinPerKm, equals(6.0));
    });

    test('preserves run plan name in playlist', () {
      const plan = RunPlan(
        type: RunType.steady,
        distanceKm: 10,
        paceMinPerKm: 5,
        name: 'Morning 10K',
        segments: [
          RunSegment(durationSeconds: 210, targetBpm: 170),
        ],
      );

      final songsByBpm = {
        170: [_song()],
      };

      final playlist = PlaylistGenerator.generate(
        runPlan: plan,
        songsByBpm: songsByBpm,
        random: Random(42),
      );

      expect(playlist.runPlanName, equals('Morning 10K'));
    });
  });

  // -- Dedup ----------------------------------------------------------------

  group('PlaylistGenerator dedup', () {
    test('does not repeat songs across segments', () {
      const plan = RunPlan(
        type: RunType.warmUpCoolDown,
        distanceKm: 5,
        paceMinPerKm: 6,
        segments: [
          RunSegment(
            durationSeconds: 210,
            targetBpm: 140,
            label: 'Warm-up',
          ),
          RunSegment(
            durationSeconds: 210,
            targetBpm: 140,
            label: 'Cool-down',
          ),
        ],
      );

      // Both segments query BPM 140 -- same pool
      final songsByBpm = {
        140: [
          _song(id: 'a', title: 'Song A', tempo: 140),
          _song(id: 'b', title: 'Song B', tempo: 140),
          _song(id: 'c', title: 'Song C', tempo: 140),
        ],
        70: [
          _song(id: 'd', title: 'Song D', tempo: 70),
        ],
      };

      final playlist = PlaylistGenerator.generate(
        runPlan: plan,
        songsByBpm: songsByBpm,
        random: Random(42),
      );

      // Each segment needs 1 song (210/210=1). With dedup, they
      // must be different.
      final songIds = playlist.songs.map((s) => s.title).toList();
      expect(
        songIds.toSet().length,
        equals(songIds.length),
        reason: 'No duplicate songs across segments',
      );
    });
  });

  // -- Taste filtering ------------------------------------------------------

  group('PlaylistGenerator taste filtering', () {
    test('ranks artist-match songs higher', () {
      const plan = RunPlan(
        type: RunType.steady,
        distanceKm: 5,
        paceMinPerKm: 6,
        segments: [
          RunSegment(
            durationSeconds: 210,
            targetBpm: 170,
            label: 'Run',
          ),
        ],
      );

      const tasteProfile = TasteProfile(
        genres: [RunningGenre.rock],
        artists: ['Eminem'],
      );

      final songsByBpm = {
        170: [
          _song(
            id: 'other1',
            title: 'Other 1',
            artist: 'Unknown Artist',
          ),
          _song(
            id: 'em1',
            title: 'Lose Yourself',
            artist: 'Eminem',
          ),
          _song(
            id: 'other2',
            title: 'Other 2',
            artist: 'Another Artist',
          ),
        ],
      };

      final playlist = PlaylistGenerator.generate(
        runPlan: plan,
        tasteProfile: tasteProfile,
        songsByBpm: songsByBpm,
        random: Random(42),
      );

      // Only 1 song needed (210/210). The Eminem song should be
      // ranked first.
      expect(playlist.songs.length, equals(1));
      expect(playlist.songs.first.artistName, equals('Eminem'));
    });

    test(
      'falls back to unfiltered BPM matches when no taste match',
      () {
        const plan = RunPlan(
          type: RunType.steady,
          distanceKm: 5,
          paceMinPerKm: 6,
          segments: [
            RunSegment(
              durationSeconds: 210,
              targetBpm: 170,
              label: 'Run',
            ),
          ],
        );

        const tasteProfile = TasteProfile(
          genres: [RunningGenre.rock],
          artists: ['Nonexistent Artist'],
        );

        final songsByBpm = {
          170: [
            _song(title: 'Song 1', artist: 'Artist A'),
            _song(id: 's2', title: 'Song 2', artist: 'Artist B'),
          ],
        };

        final playlist = PlaylistGenerator.generate(
          runPlan: plan,
          tasteProfile: tasteProfile,
          songsByBpm: songsByBpm,
          random: Random(42),
        );

        // Should still get a song even though no artist matches
        expect(playlist.songs.length, equals(1));
      },
    );

    test('works with null taste profile', () {
      const plan = RunPlan(
        type: RunType.steady,
        distanceKm: 5,
        paceMinPerKm: 6,
        segments: [
          RunSegment(
            durationSeconds: 210,
            targetBpm: 170,
            label: 'Run',
          ),
        ],
      );

      final songsByBpm = {
        170: [_song(title: 'Song 1')],
      };

      final playlist = PlaylistGenerator.generate(
        runPlan: plan,
        songsByBpm: songsByBpm,
        random: Random(42),
      );

      expect(playlist.songs.length, equals(1));
    });

    test('artist matching is case-insensitive', () {
      const plan = RunPlan(
        type: RunType.steady,
        distanceKm: 5,
        paceMinPerKm: 6,
        segments: [
          RunSegment(
            durationSeconds: 210,
            targetBpm: 170,
            label: 'Run',
          ),
        ],
      );

      // lowercase
      const tasteProfile = TasteProfile(
        artists: ['eminem'],
      );

      final songsByBpm = {
        170: [
          _song(id: 'other', title: 'Other', artist: 'Unknown'),
          // uppercase
          _song(
            id: 'em',
            title: 'Lose Yourself',
            artist: 'EMINEM',
          ),
        ],
      };

      final playlist = PlaylistGenerator.generate(
        runPlan: plan,
        tasteProfile: tasteProfile,
        songsByBpm: songsByBpm,
        random: Random(42),
      );

      expect(
        playlist.songs.first.artistName,
        equals('EMINEM'),
      );
    });
  });

  // -- External links -------------------------------------------------------

  group('PlaylistGenerator external links', () {
    test('each song has Spotify and YouTube URLs', () {
      const plan = RunPlan(
        type: RunType.steady,
        distanceKm: 5,
        paceMinPerKm: 6,
        segments: [
          RunSegment(
            durationSeconds: 210,
            targetBpm: 170,
            label: 'Run',
          ),
        ],
      );

      final songsByBpm = {
        170: [
          _song(
            title: 'My Song',
            artist: 'My Artist',
          ),
        ],
      };

      final playlist = PlaylistGenerator.generate(
        runPlan: plan,
        songsByBpm: songsByBpm,
        random: Random(42),
      );

      final song = playlist.songs.first;
      expect(
        song.spotifyUrl,
        contains('open.spotify.com/search'),
      );
      expect(song.spotifyUrl, contains('My'));
      expect(
        song.youtubeUrl,
        contains('music.youtube.com/search'),
      );
      expect(song.youtubeUrl, contains('My'));
    });
  });

  // -- Edge cases -----------------------------------------------------------

  group('PlaylistGenerator edge cases', () {
    test(
      'returns empty playlist when no songs available '
      'for any segment',
      () {
        const plan = RunPlan(
          type: RunType.steady,
          distanceKm: 5,
          paceMinPerKm: 6,
          segments: [
            RunSegment(
              durationSeconds: 1800,
              targetBpm: 170,
              label: 'Run',
            ),
          ],
        );

        final playlist = PlaylistGenerator.generate(
          runPlan: plan,
          songsByBpm: const {},
          random: Random(42),
        );

        expect(playlist.songs, isEmpty);
      },
    );

    test(
      'handles segment with very short duration (< 1 song)',
      () {
        const plan = RunPlan(
          type: RunType.steady,
          distanceKm: 1,
          paceMinPerKm: 6,
          segments: [
            RunSegment(
              durationSeconds: 60,
              targetBpm: 170,
              label: 'Sprint',
            ),
          ],
        );

        final songsByBpm = {
          170: [_song()],
        };

        final playlist = PlaylistGenerator.generate(
          runPlan: plan,
          songsByBpm: songsByBpm,
          random: Random(42),
        );

        // ceil(60/210) = 1, clamp(1, 1) = 1
        expect(playlist.songs.length, equals(1));
      },
    );

    test(
      'uses half-time songs when exact BPM pool is empty',
      () {
        const plan = RunPlan(
          type: RunType.steady,
          distanceKm: 5,
          paceMinPerKm: 6,
          segments: [
            RunSegment(
              durationSeconds: 210,
              targetBpm: 170,
              label: 'Run',
            ),
          ],
        );

        // No songs at 170, but songs at 85 (half-time of 170)
        final songsByBpm = {
          85: [
            _song(id: 'h1', title: 'Half Song', tempo: 85),
          ],
        };

        final playlist = PlaylistGenerator.generate(
          runPlan: plan,
          songsByBpm: songsByBpm,
          random: Random(42),
        );

        expect(playlist.songs.length, equals(1));
        expect(
          playlist.songs.first.matchType,
          equals(BpmMatchType.halfTime),
        );
      },
    );

    test('prefers exact match over half/double-time', () {
      const plan = RunPlan(
        type: RunType.steady,
        distanceKm: 5,
        paceMinPerKm: 6,
        segments: [
          RunSegment(
            durationSeconds: 210,
            targetBpm: 170,
            label: 'Run',
          ),
        ],
      );

      final songsByBpm = {
        170: [
          _song(id: 'exact', title: 'Exact Song'),
        ],
        85: [
          _song(id: 'half', title: 'Half Song', tempo: 85),
        ],
      };

      final playlist = PlaylistGenerator.generate(
        runPlan: plan,
        songsByBpm: songsByBpm,
        random: Random(42),
      );

      // Only 1 song needed. Exact match scores +3, half-time
      // scores +1.
      expect(playlist.songs.first.title, equals('Exact Song'));
    });

    test('estimatedSongDurationSeconds is 210', () {
      expect(
        PlaylistGenerator.estimatedSongDurationSeconds,
        equals(210),
      );
    });
  });

  // -- Composite scoring (SongQualityScorer integration) --------------------

  group('PlaylistGenerator composite scoring', () {
    test('ranks high-danceability songs above low-danceability songs',
        () {
      const plan = RunPlan(
        type: RunType.steady,
        distanceKm: 5,
        paceMinPerKm: 6,
        segments: [
          RunSegment(
            durationSeconds: 420,
            targetBpm: 170,
            label: 'Running',
          ),
        ],
      );

      final songsByBpm = {
        170: [
          _song(
            id: 'low',
            title: 'Low Dance',
            artist: 'Artist A',
            danceability: 10,
          ),
          _song(
            id: 'high',
            title: 'High Dance',
            artist: 'Artist B',
            danceability: 90,
          ),
        ],
      };

      final playlist = PlaylistGenerator.generate(
        runPlan: plan,
        songsByBpm: songsByBpm,
        random: Random(42),
      );

      // Both songs present (420/210=2). High danceability should
      // rank first.
      expect(playlist.songs.length, equals(2));
      expect(playlist.songs.first.title, equals('High Dance'));
    });

    test('no consecutive same-artist songs in generated playlist',
        () {
      const plan = RunPlan(
        type: RunType.steady,
        distanceKm: 5,
        paceMinPerKm: 6,
        segments: [
          RunSegment(
            durationSeconds: 1050,
            targetBpm: 170,
            label: 'Running',
          ),
        ],
      );

      // One dominant artist with 3 songs, plus 3 different others
      // (enough diversity to ensure interleaving is possible)
      final songsByBpm = {
        170: [
          _song(id: 'd1', title: 'Dom 1', artist: 'Dominant'),
          _song(id: 'd2', title: 'Dom 2', artist: 'Dominant'),
          _song(id: 'd3', title: 'Dom 3', artist: 'Dominant'),
          _song(id: 'o1', title: 'Other 1', artist: 'Other A'),
          _song(id: 'o2', title: 'Other 2', artist: 'Other B'),
          _song(id: 'o3', title: 'Other 3', artist: 'Other C'),
        ],
      };

      final playlist = PlaylistGenerator.generate(
        runPlan: plan,
        songsByBpm: songsByBpm,
        random: Random(42),
      );

      // 1050/210 = 5 songs needed, 6 available
      expect(playlist.songs.length, equals(5));

      // Verify no two consecutive songs by the same artist
      for (var i = 1; i < playlist.songs.length; i++) {
        expect(
          playlist.songs[i].artistName.toLowerCase() !=
              playlist.songs[i - 1].artistName.toLowerCase(),
          isTrue,
          reason:
              'Songs at index ${i - 1} and $i should have '
              'different artists, but both are '
              '"${playlist.songs[i].artistName}"',
        );
      }
    });

    test(
      'warm-up segment prefers lower-danceability songs '
      'over main segment',
      () {
        const plan = RunPlan(
          type: RunType.warmUpCoolDown,
          distanceKm: 5,
          paceMinPerKm: 6,
          segments: [
            RunSegment(
              durationSeconds: 210,
              targetBpm: 170,
              label: 'Warm-up',
            ),
            RunSegment(
              durationSeconds: 210,
              targetBpm: 170,
              label: 'Running',
            ),
          ],
        );

        const tasteProfile = TasteProfile(
          energyLevel: EnergyLevel.intense,
        );

        // Songs with varying danceability. Enough for both segments.
        final songsByBpm = {
          170: [
            _song(
              id: 'chill1',
              title: 'Chill Song',
              artist: 'Artist A',
              danceability: 30,
            ),
            _song(
              id: 'chill2',
              title: 'Chill Song 2',
              artist: 'Artist B',
              danceability: 35,
            ),
            _song(
              id: 'hype1',
              title: 'Hype Song',
              artist: 'Artist C',
              danceability: 85,
            ),
            _song(
              id: 'hype2',
              title: 'Hype Song 2',
              artist: 'Artist D',
              danceability: 90,
            ),
          ],
        };

        final playlist = PlaylistGenerator.generate(
          runPlan: plan,
          tasteProfile: tasteProfile,
          songsByBpm: songsByBpm,
          random: Random(42),
        );

        final warmUpSong = playlist.songs
            .firstWhere((s) => s.segmentLabel == 'Warm-up');
        final runningSong = playlist.songs
            .firstWhere((s) => s.segmentLabel == 'Running');

        // Warm-up overrides to chill energy, so low-danceability
        // songs score higher for energy alignment. The running
        // segment uses 'intense' from tasteProfile, preferring high
        // danceability.
        expect(
          warmUpSong.runningQuality! < runningSong.runningQuality!,
          isTrue,
          reason:
              'Warm-up song (chill energy) should have lower '
              'quality score than running song (intense energy) '
              'because chill-range danceability songs score lower '
              'overall. Warm-up: ${warmUpSong.runningQuality}, '
              'Running: ${runningSong.runningQuality}',
        );
      },
    );
  });

  // -- Curated song ranking ---------------------------------------------------

  group('PlaylistGenerator curated ranking', () {
    test('curated songs rank higher than equivalent non-curated songs', () {
      const plan = RunPlan(
        type: RunType.steady,
        distanceKm: 5,
        paceMinPerKm: 6,
        segments: [
          RunSegment(
            durationSeconds: 420,
            targetBpm: 170,
            label: 'Running',
          ),
        ],
      );

      // Two songs with identical attributes except one is curated
      final songsByBpm = {
        170: [
          _song(
            id: 'normal',
            title: 'Normal Song',
            artist: 'Artist A',
          ),
          _song(
            id: 'curated',
            title: 'Curated Song',
            artist: 'Artist B',
          ),
        ],
      };

      // Mark 'Artist B|Curated Song' as curated via lookupKey
      final curatedLookupKeys = {'artist b|curated song'};

      final playlist = PlaylistGenerator.generate(
        runPlan: plan,
        songsByBpm: songsByBpm,
        curatedLookupKeys: curatedLookupKeys,
        random: Random(42),
      );

      // Both songs selected (420/210=2). Curated song should rank first.
      expect(playlist.songs.length, equals(2));
      expect(playlist.songs.first.title, equals('Curated Song'));
    });

    test('empty curatedLookupKeys produces same results as null', () {
      const plan = RunPlan(
        type: RunType.steady,
        distanceKm: 5,
        paceMinPerKm: 6,
        segments: [
          RunSegment(
            durationSeconds: 210,
            targetBpm: 170,
            label: 'Running',
          ),
        ],
      );

      final songsByBpm = {
        170: [
          _song(id: 'a', title: 'Song A', artist: 'Artist A'),
          _song(id: 'b', title: 'Song B', artist: 'Artist B'),
        ],
      };

      final withEmpty = PlaylistGenerator.generate(
        runPlan: plan,
        songsByBpm: songsByBpm,
        curatedLookupKeys: const {},
        random: Random(42),
      );

      final withNull = PlaylistGenerator.generate(
        runPlan: plan,
        songsByBpm: songsByBpm,
        curatedLookupKeys: null,
        random: Random(42),
      );

      // Same song selected in both cases
      expect(withEmpty.songs.first.title, equals(withNull.songs.first.title));
    });
  });
}
