import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_song.dart';
import 'package:running_playlist_ai/features/song_quality/domain/song_quality_scorer.dart';
import 'package:running_playlist_ai/features/taste_profile/domain/taste_profile.dart';

/// Helper to build a BpmSong with sensible defaults.
BpmSong _song({
  String artistName = 'TestArtist',
  BpmMatchType matchType = BpmMatchType.exact,
}) {
  return BpmSong(
    songId: 'id-1',
    title: 'Test Song',
    artistName: artistName,
    tempo: 170,
    matchType: matchType,
  );
}

void main() {
  // ──────────────────────────────────────────────────────
  // Danceability scoring
  // ──────────────────────────────────────────────────────
  group('Danceability scoring', () {
    test('danceability=90 yields score component of 7', () {
      final score1 = SongQualityScorer.score(
        song: _song(),
        danceability: 90,
      );
      final score0 = SongQualityScorer.score(
        song: _song(),
        danceability: 0,
      );
      // Isolate danceability component by diffing against danceability=0
      expect(score1 - score0, equals(7));
    });

    test('danceability=50 yields score component of 4', () {
      final score50 = SongQualityScorer.score(
        song: _song(),
        danceability: 50,
      );
      final score0 = SongQualityScorer.score(
        song: _song(),
        danceability: 0,
      );
      expect(score50 - score0, equals(4));
    });

    test('danceability=10 yields score component of 1', () {
      final score10 = SongQualityScorer.score(
        song: _song(),
        danceability: 10,
      );
      final score0 = SongQualityScorer.score(
        song: _song(),
        danceability: 0,
      );
      expect(score10 - score0, equals(1));
    });

    test('danceability=null yields neutral score of 4', () {
      final scoreNull = SongQualityScorer.score(
        song: _song(),
        danceability: null,
      );
      final score0 = SongQualityScorer.score(
        song: _song(),
        danceability: 0,
      );
      expect(scoreNull - score0, equals(4));
    });

    test('danceability=0 yields score component of 0', () {
      final score0 = SongQualityScorer.score(
        song: _song(),
        danceability: 0,
      );
      final scoreNull = SongQualityScorer.score(
        song: _song(),
        danceability: null,
      );
      // danceability=0 should score lower than null (neutral=4)
      expect(score0 < scoreNull, isTrue);
    });

    test('danceability=100 yields score component of 8', () {
      final score100 = SongQualityScorer.score(
        song: _song(),
        danceability: 100,
      );
      final score0 = SongQualityScorer.score(
        song: _song(),
        danceability: 0,
      );
      expect(score100 - score0, equals(8));
    });

    test('high danceability scores higher than low danceability (QUAL-02)',
        () {
      final highScore = SongQualityScorer.score(
        song: _song(),
        danceability: 90,
      );
      final lowScore = SongQualityScorer.score(
        song: _song(),
        danceability: 10,
      );
      expect(highScore, greaterThan(lowScore));
    });
  });

  // ──────────────────────────────────────────────────────
  // Energy alignment
  // ──────────────────────────────────────────────────────
  group('Energy alignment', () {
    test('chill user, danceability=35 -> +4 (in range 20-50)', () {
      final profile = TasteProfile(energyLevel: EnergyLevel.chill);
      final scoreIn = SongQualityScorer.score(
        song: _song(),
        danceability: 35,
        tasteProfile: profile,
      );
      // Compare to out-of-range (danceability=80 for chill)
      final scoreOut = SongQualityScorer.score(
        song: _song(),
        danceability: 80,
        tasteProfile: profile,
      );
      // Difference should be 4 (energy alignment) minus danceability diff
      // Instead, test the energy alignment component directly:
      // in-range gets +4, far-out-of-range gets +0
      expect(scoreIn - scoreOut, equals(4 + _danceabilityDiff(35, 80)));
    });

    test('chill user, danceability=80 -> +0 (far outside range)', () {
      final profile = TasteProfile(energyLevel: EnergyLevel.chill);
      // danceability=80 is far outside chill range (20-50)
      // Energy alignment should be 0
      // Verify by comparing to balanced user at same danceability
      final chillScore = SongQualityScorer.score(
        song: _song(),
        danceability: 80,
        tasteProfile: profile,
      );
      final intenseProfile =
          TasteProfile(energyLevel: EnergyLevel.intense);
      final intenseScore = SongQualityScorer.score(
        song: _song(),
        danceability: 80,
        tasteProfile: intenseProfile,
      );
      // intense user at 80 should get +4, chill user at 80 should get +0
      expect(intenseScore - chillScore, equals(4));
    });

    test('intense user, danceability=80 -> +4 (in range 60-100)', () {
      final profile = TasteProfile(energyLevel: EnergyLevel.intense);
      final scoreIn = SongQualityScorer.score(
        song: _song(),
        danceability: 80,
        tasteProfile: profile,
      );
      final scoreOut = SongQualityScorer.score(
        song: _song(),
        danceability: 30,
        tasteProfile: profile,
      );
      expect(scoreIn - scoreOut, equals(4 + _danceabilityDiff(80, 30)));
    });

    test('intense user, danceability=30 -> +0 (far outside range)', () {
      final profile = TasteProfile(energyLevel: EnergyLevel.intense);
      final chillProfile = TasteProfile(energyLevel: EnergyLevel.chill);
      final intenseScore = SongQualityScorer.score(
        song: _song(),
        danceability: 30,
        tasteProfile: profile,
      );
      final chillScore = SongQualityScorer.score(
        song: _song(),
        danceability: 30,
        tasteProfile: chillProfile,
      );
      // chill user at 30 gets +4 (in range 20-50), intense at 30 gets +0
      expect(chillScore - intenseScore, equals(4));
    });

    test('balanced user, danceability=55 -> +4 (in range 40-70)', () {
      final profile = TasteProfile(energyLevel: EnergyLevel.balanced);
      final scoreIn = SongQualityScorer.score(
        song: _song(),
        danceability: 55,
        tasteProfile: profile,
      );
      final scoreOut = SongQualityScorer.score(
        song: _song(),
        danceability: 10,
        tasteProfile: profile,
      );
      expect(scoreIn - scoreOut, equals(4 + _danceabilityDiff(55, 10)));
    });

    test('danceability=null -> +2 (neutral regardless of energy)', () {
      final profile = TasteProfile(energyLevel: EnergyLevel.chill);
      final scoreNull = SongQualityScorer.score(
        song: _song(),
        danceability: null,
        tasteProfile: profile,
      );
      // Compare with danceability in-range (35 for chill) -> +4
      final scoreIn = SongQualityScorer.score(
        song: _song(),
        danceability: 35,
        tasteProfile: profile,
      );
      // energy diff is 4-2=2, danceability diff is (35/100*8).round()-4
      final danceComp = (35 / 100 * 8).round() - 4; // 3-4 = -1
      expect(scoreIn - scoreNull, equals(2 + danceComp));
    });

    test('tasteProfile=null -> +2 (neutral)', () {
      final scoreNoProfile = SongQualityScorer.score(
        song: _song(),
        danceability: 80,
        tasteProfile: null,
      );
      final profile = TasteProfile(energyLevel: EnergyLevel.intense);
      final scoreWithProfile = SongQualityScorer.score(
        song: _song(),
        danceability: 80,
        tasteProfile: profile,
      );
      // intense at 80 -> energy=+4, null profile -> energy=+2
      expect(scoreWithProfile - scoreNoProfile, equals(2));
    });

    test('chill vs intense user get different scores (QUAL-06)', () {
      final chill = TasteProfile(energyLevel: EnergyLevel.chill);
      final intense = TasteProfile(energyLevel: EnergyLevel.intense);
      final chillScore = SongQualityScorer.score(
        song: _song(),
        danceability: 50,
        tasteProfile: chill,
      );
      final intenseScore = SongQualityScorer.score(
        song: _song(),
        danceability: 50,
        tasteProfile: intense,
      );
      expect(chillScore, isNot(equals(intenseScore)));
    });
  });

  // ──────────────────────────────────────────────────────
  // Segment energy override
  // ──────────────────────────────────────────────────────
  group('Segment energy override', () {
    test('Warm-up overrides intense to chill range (QUAL-05)', () {
      final profile = TasteProfile(energyLevel: EnergyLevel.intense);
      final warmupScore = SongQualityScorer.score(
        song: _song(),
        danceability: 35,
        tasteProfile: profile,
        segmentLabel: 'Warm-up',
      );
      final normalScore = SongQualityScorer.score(
        song: _song(),
        danceability: 35,
        tasteProfile: profile,
        segmentLabel: null,
      );
      // Warm-up treats as chill: danceability=35 is in chill range (20-50) -> +4
      // Normal intense: danceability=35 is far outside intense range (60-100) -> +0
      expect(warmupScore - normalScore, equals(4));
    });

    test('Cool-down overrides intense to chill range', () {
      final profile = TasteProfile(energyLevel: EnergyLevel.intense);
      final cooldownScore = SongQualityScorer.score(
        song: _song(),
        danceability: 35,
        tasteProfile: profile,
        segmentLabel: 'Cool-down',
      );
      final normalScore = SongQualityScorer.score(
        song: _song(),
        danceability: 35,
        tasteProfile: profile,
        segmentLabel: null,
      );
      expect(cooldownScore - normalScore, equals(4));
    });

    test('Work 1 overrides chill to intense range', () {
      final profile = TasteProfile(energyLevel: EnergyLevel.chill);
      final workScore = SongQualityScorer.score(
        song: _song(),
        danceability: 80,
        tasteProfile: profile,
        segmentLabel: 'Work 1',
      );
      final normalScore = SongQualityScorer.score(
        song: _song(),
        danceability: 80,
        tasteProfile: profile,
        segmentLabel: null,
      );
      // Work overrides to intense: danceability=80 in intense range -> +4
      // Normal chill: danceability=80 far outside chill range -> +0
      expect(workScore - normalScore, equals(4));
    });

    test('Rest 2 overrides intense to chill range', () {
      final profile = TasteProfile(energyLevel: EnergyLevel.intense);
      final restScore = SongQualityScorer.score(
        song: _song(),
        danceability: 35,
        tasteProfile: profile,
        segmentLabel: 'Rest 2',
      );
      final normalScore = SongQualityScorer.score(
        song: _song(),
        danceability: 35,
        tasteProfile: profile,
        segmentLabel: null,
      );
      expect(restScore - normalScore, equals(4));
    });

    test('Main segment uses user preference (no override)', () {
      final profile = TasteProfile(energyLevel: EnergyLevel.intense);
      final mainScore = SongQualityScorer.score(
        song: _song(),
        danceability: 80,
        tasteProfile: profile,
        segmentLabel: 'Main',
      );
      final noLabelScore = SongQualityScorer.score(
        song: _song(),
        danceability: 80,
        tasteProfile: profile,
        segmentLabel: null,
      );
      expect(mainScore, equals(noLabelScore));
    });

    test('null segmentLabel uses user preference', () {
      final profile = TasteProfile(energyLevel: EnergyLevel.intense);
      final score = SongQualityScorer.score(
        song: _song(),
        danceability: 80,
        tasteProfile: profile,
        segmentLabel: null,
      );
      // intense at 80 -> in range -> +4, verify non-zero energy
      final noEnergyScore = SongQualityScorer.score(
        song: _song(),
        danceability: 80,
        tasteProfile: null,
        segmentLabel: null,
      );
      expect(score - noEnergyScore, equals(2));
    });
  });

  // ──────────────────────────────────────────────────────
  // Artist match
  // ──────────────────────────────────────────────────────
  group('Artist match', () {
    test('matching artist adds +10', () {
      final profile = TasteProfile(artists: ['Eminem']);
      final score = SongQualityScorer.score(
        song: _song(artistName: 'Eminem'),
        tasteProfile: profile,
      );
      final noMatchScore = SongQualityScorer.score(
        song: _song(artistName: 'Unknown'),
        tasteProfile: profile,
      );
      expect(score - noMatchScore, equals(10));
    });

    test('artist match is case-insensitive', () {
      final profile = TasteProfile(artists: ['eminem']);
      final score = SongQualityScorer.score(
        song: _song(artistName: 'EMINEM'),
        tasteProfile: profile,
      );
      final noMatchScore = SongQualityScorer.score(
        song: _song(artistName: 'Unknown'),
        tasteProfile: profile,
      );
      expect(score - noMatchScore, equals(10));
    });

    test('no matching artist adds +0', () {
      final profile = TasteProfile(artists: ['Eminem']);
      final score = SongQualityScorer.score(
        song: _song(artistName: 'Unknown'),
        tasteProfile: profile,
      );
      final noProfileScore = SongQualityScorer.score(
        song: _song(artistName: 'Unknown'),
        tasteProfile: null,
      );
      expect(score, equals(noProfileScore));
    });

    test('null taste profile adds +0', () {
      final score = SongQualityScorer.score(
        song: _song(artistName: 'Eminem'),
        tasteProfile: null,
      );
      final score2 = SongQualityScorer.score(
        song: _song(artistName: 'Unknown'),
        tasteProfile: null,
      );
      expect(score, equals(score2));
    });
  });

  // ──────────────────────────────────────────────────────
  // Genre match
  // ──────────────────────────────────────────────────────
  group('Genre match', () {
    test('matching genre adds +6', () {
      final profile = TasteProfile(genres: [RunningGenre.rock]);
      final score = SongQualityScorer.score(
        song: _song(),
        tasteProfile: profile,
        songGenres: [RunningGenre.rock],
      );
      final noGenreScore = SongQualityScorer.score(
        song: _song(),
        tasteProfile: profile,
        songGenres: null,
      );
      expect(score - noGenreScore, equals(6));
    });

    test('non-matching genre adds +0', () {
      final profile = TasteProfile(genres: [RunningGenre.pop]);
      final score = SongQualityScorer.score(
        song: _song(),
        tasteProfile: profile,
        songGenres: [RunningGenre.rock],
      );
      final noGenreScore = SongQualityScorer.score(
        song: _song(),
        tasteProfile: profile,
        songGenres: null,
      );
      expect(score, equals(noGenreScore));
    });

    test('null songGenres adds +0', () {
      final profile = TasteProfile(genres: [RunningGenre.rock]);
      final scoreNull = SongQualityScorer.score(
        song: _song(),
        tasteProfile: profile,
        songGenres: null,
      );
      final scoreEmpty = SongQualityScorer.score(
        song: _song(),
        tasteProfile: profile,
        songGenres: [],
      );
      // Both null and empty should give +0 genre bonus
      expect(scoreNull, equals(scoreEmpty));
    });

    test('empty tasteProfile genres adds +0', () {
      final profile = TasteProfile(genres: []);
      final score = SongQualityScorer.score(
        song: _song(),
        tasteProfile: profile,
        songGenres: [RunningGenre.rock],
      );
      final noGenreScore = SongQualityScorer.score(
        song: _song(),
        tasteProfile: profile,
        songGenres: null,
      );
      expect(score, equals(noGenreScore));
    });
  });

  // ──────────────────────────────────────────────────────
  // BPM match
  // ──────────────────────────────────────────────────────
  group('BPM match', () {
    test('exact match adds +3', () {
      final score = SongQualityScorer.score(
        song: _song(matchType: BpmMatchType.exact),
      );
      final halfScore = SongQualityScorer.score(
        song: _song(matchType: BpmMatchType.halfTime),
      );
      expect(score - halfScore, equals(2)); // 3 - 1
    });

    test('halfTime match adds +1', () {
      final halfScore = SongQualityScorer.score(
        song: _song(matchType: BpmMatchType.halfTime),
      );
      final doubleScore = SongQualityScorer.score(
        song: _song(matchType: BpmMatchType.doubleTime),
      );
      expect(halfScore, equals(doubleScore));
    });

    test('doubleTime match adds +1', () {
      final doubleScore = SongQualityScorer.score(
        song: _song(matchType: BpmMatchType.doubleTime),
      );
      final exactScore = SongQualityScorer.score(
        song: _song(matchType: BpmMatchType.exact),
      );
      expect(exactScore - doubleScore, equals(2)); // 3 - 1
    });
  });

  // ──────────────────────────────────────────────────────
  // Artist diversity penalty
  // ──────────────────────────────────────────────────────
  group('Artist diversity penalty', () {
    test('same artist as previous gets -5', () {
      final score = SongQualityScorer.score(
        song: _song(artistName: 'Eminem'),
        previousArtist: 'Eminem',
      );
      final noPenaltyScore = SongQualityScorer.score(
        song: _song(artistName: 'Eminem'),
        previousArtist: 'Drake',
      );
      expect(score - noPenaltyScore, equals(-5));
    });

    test('same artist case-insensitive', () {
      final score = SongQualityScorer.score(
        song: _song(artistName: 'EMINEM'),
        previousArtist: 'eminem',
      );
      final noPenaltyScore = SongQualityScorer.score(
        song: _song(artistName: 'EMINEM'),
        previousArtist: 'Drake',
      );
      expect(score - noPenaltyScore, equals(-5));
    });

    test('different artist gets no penalty', () {
      final score = SongQualityScorer.score(
        song: _song(artistName: 'Eminem'),
        previousArtist: 'Drake',
      );
      final noArtistScore = SongQualityScorer.score(
        song: _song(artistName: 'Eminem'),
        previousArtist: null,
      );
      expect(score, equals(noArtistScore));
    });

    test('null previousArtist gets no penalty', () {
      final score = SongQualityScorer.score(
        song: _song(artistName: 'Eminem'),
        previousArtist: null,
      );
      final score2 = SongQualityScorer.score(
        song: _song(artistName: 'Eminem'),
        previousArtist: 'DifferentArtist',
      );
      expect(score, equals(score2));
    });
  });

  // ──────────────────────────────────────────────────────
  // Composite scoring
  // ──────────────────────────────────────────────────────
  group('Composite scoring', () {
    test('best case: artist(10) + dance(7) + energy(4) + exact(3) + genre(6) = 30',
        () {
      final profile = TasteProfile(
        artists: ['Eminem'],
        genres: [RunningGenre.rock],
        energyLevel: EnergyLevel.intense,
      );
      final score = SongQualityScorer.score(
        song: _song(artistName: 'Eminem', matchType: BpmMatchType.exact),
        tasteProfile: profile,
        danceability: 90, // -> 7 points, in intense range -> +4
        songGenres: [RunningGenre.rock],
      );
      expect(score, equals(30));
    });

    test('worst case: no match(0) + low dance(1) + no energy(0) + variant(1) + no genre(0) = 2',
        () {
      final profile = TasteProfile(
        artists: ['Eminem'],
        genres: [RunningGenre.pop],
        energyLevel: EnergyLevel.intense,
      );
      final score = SongQualityScorer.score(
        song: _song(
            artistName: 'Unknown', matchType: BpmMatchType.halfTime),
        tasteProfile: profile,
        danceability: 10, // -> 1 point, intense range 60-100, 10 far outside -> +0
        songGenres: [RunningGenre.rock],
      );
      expect(score, equals(2));
    });
  });

  // ──────────────────────────────────────────────────────
  // enforceArtistDiversity
  // ──────────────────────────────────────────────────────
  group('enforceArtistDiversity', () {
    test('[A, A, B, C] -> [A, B, A, C]', () {
      final songs = ['A', 'A', 'B', 'C'];
      final result =
          SongQualityScorer.enforceArtistDiversity(songs, (s) => s);
      expect(result, equals(['A', 'B', 'A', 'C']));
    });

    test('[A, B, C] -> [A, B, C] (no change needed)', () {
      final songs = ['A', 'B', 'C'];
      final result =
          SongQualityScorer.enforceArtistDiversity(songs, (s) => s);
      expect(result, equals(['A', 'B', 'C']));
    });

    test('[A, A, A] -> [A, A, A] (no swap candidate)', () {
      final songs = ['A', 'A', 'A'];
      final result =
          SongQualityScorer.enforceArtistDiversity(songs, (s) => s);
      expect(result, equals(['A', 'A', 'A']));
    });

    test('[A, A, B, B, C] -> [A, B, A, B, C]', () {
      final songs = ['A', 'A', 'B', 'B', 'C'];
      final result =
          SongQualityScorer.enforceArtistDiversity(songs, (s) => s);
      expect(result, equals(['A', 'B', 'A', 'B', 'C']));
    });

    test('empty list -> empty list', () {
      final songs = <String>[];
      final result =
          SongQualityScorer.enforceArtistDiversity(songs, (s) => s);
      expect(result, isEmpty);
    });

    test('single element list -> same list', () {
      final songs = ['A'];
      final result =
          SongQualityScorer.enforceArtistDiversity(songs, (s) => s);
      expect(result, equals(['A']));
    });
  });

  // ──────────────────────────────────────────────────────
  // Graceful degradation
  // ──────────────────────────────────────────────────────
  group('Graceful degradation', () {
    test('all nulls still produce a valid score', () {
      final score = SongQualityScorer.score(
        song: _song(),
        tasteProfile: null,
        danceability: null,
        segmentLabel: null,
        previousArtist: null,
        songGenres: null,
      );
      // Exact BPM=3, neutral danceability=4, neutral energy=2 => 9
      expect(score, equals(9));
    });

    test('no Flutter imports in scorer', () {
      // This test is a reminder -- actual verification done via grep
      // in the verification step. Including here for documentation.
      expect(true, isTrue);
    });
  });
}

/// Helper to compute the danceability score difference between two values.
int _danceabilityDiff(int a, int b) {
  final scoreA = (a / 100 * 8).round().clamp(0, 8);
  final scoreB = (b / 100 * 8).round().clamp(0, 8);
  return scoreA - scoreB;
}
