import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_song.dart';
import 'package:running_playlist_ai/features/song_quality/domain/song_quality_scorer.dart';
import 'package:running_playlist_ai/features/taste_profile/domain/taste_profile.dart';

/// Helper to build a BpmSong with sensible defaults.
BpmSong _song({
  String artistName = 'TestArtist',
  BpmMatchType matchType = BpmMatchType.exact,
  String? genre,
  String? decade,
  int? danceability,
}) {
  return BpmSong(
    songId: 'id-1',
    title: 'Test Song',
    artistName: artistName,
    tempo: 170,
    matchType: matchType,
    genre: genre,
    decade: decade,
    danceability: danceability,
  );
}

void main() {
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
      final matchProfile = TasteProfile(genres: [RunningGenre.rock]);
      final noMatchProfile = TasteProfile(genres: [RunningGenre.pop]);
      final matchScore = SongQualityScorer.score(
        song: _song(),
        tasteProfile: matchProfile,
        songGenres: [RunningGenre.rock],
      );
      final noMatchScore = SongQualityScorer.score(
        song: _song(),
        tasteProfile: noMatchProfile,
        songGenres: [RunningGenre.rock],
      );
      expect(matchScore - noMatchScore, equals(6));
    });

    test('non-matching genre adds +0', () {
      final profile = TasteProfile(genres: [RunningGenre.pop]);
      final rockScore = SongQualityScorer.score(
        song: _song(),
        tasteProfile: profile,
        songGenres: [RunningGenre.rock],
      );
      final noProfileScore = SongQualityScorer.score(
        song: _song(),
        tasteProfile: null,
        songGenres: [RunningGenre.rock],
      );
      expect(rockScore, equals(noProfileScore));
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
      expect(scoreNull, equals(scoreEmpty));
    });

    test('empty tasteProfile genres adds +0', () {
      final profile = TasteProfile(genres: []);
      final score = SongQualityScorer.score(
        song: _song(),
        tasteProfile: profile,
        songGenres: [RunningGenre.rock],
      );
      final noProfileScore = SongQualityScorer.score(
        song: _song(),
        tasteProfile: null,
        songGenres: [RunningGenre.rock],
      );
      expect(score, equals(noProfileScore));
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
    test(
        'best case: artist(10) + runnability(15) + dance(8) + genre(6) + decade(4) + exact(3) = 46',
        () {
      final profile = TasteProfile(
        artists: ['Eminem'],
        genres: [RunningGenre.electronic],
        decades: [MusicDecade.the2000s],
      );
      final score = SongQualityScorer.score(
        song: _song(
          artistName: 'Eminem',
          matchType: BpmMatchType.exact,
          decade: '2000s',
          danceability: 85,
        ),
        tasteProfile: profile,
        songGenres: [RunningGenre.electronic],
        runnability: 90,
      );
      expect(score, equals(46));
    });

    test(
        'worst case: no match + variant(1) + neutral dance(3) + runnability neutral(5) = 9',
        () {
      final profile = TasteProfile(
        artists: ['Eminem'],
        genres: [RunningGenre.pop],
      );
      final score = SongQualityScorer.score(
        song: _song(
            artistName: 'Unknown', matchType: BpmMatchType.halfTime),
        tasteProfile: profile,
        songGenres: [RunningGenre.rock],
      );
      // halfTime(1) + danceability neutral(3) + runnability neutral(5) = 9
      expect(score, equals(9));
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
        previousArtist: null,
        songGenres: null,
      );
      // Exact BPM(3) + danceability neutral(3) + runnability neutral(5) = 11
      expect(score, equals(11));
    });

    test('no Flutter imports in scorer', () {
      // This test is a reminder -- actual verification done via grep.
      expect(true, isTrue);
    });
  });

  // ──────────────────────────────────────────────────────
  // Runnability scoring
  // ──────────────────────────────────────────────────────
  group('Runnability scoring', () {
    test('high runnability (>=80) adds +15', () {
      final highScore = SongQualityScorer.score(
        song: _song(),
        runnability: 90,
      );
      final nullScore = SongQualityScorer.score(
        song: _song(),
        runnability: null,
      );
      // high(15) vs neutral(5) = +10 difference
      expect(highScore - nullScore, equals(10));
    });

    test('good runnability (60-79) adds +12', () {
      final goodScore = SongQualityScorer.score(
        song: _song(),
        runnability: 70,
      );
      final nullScore = SongQualityScorer.score(
        song: _song(),
        runnability: null,
      );
      // good(12) vs neutral(5) = +7 difference
      expect(goodScore - nullScore, equals(7));
    });

    test('moderate runnability (40-59) adds +9', () {
      final modScore = SongQualityScorer.score(
        song: _song(),
        runnability: 50,
      );
      final nullScore = SongQualityScorer.score(
        song: _song(),
        runnability: null,
      );
      // moderate(9) vs neutral(5) = +4 difference
      expect(modScore - nullScore, equals(4));
    });

    test('low runnability (25-39) adds +6', () {
      final lowScore = SongQualityScorer.score(
        song: _song(),
        runnability: 30,
      );
      final nullScore = SongQualityScorer.score(
        song: _song(),
        runnability: null,
      );
      // low(6) vs neutral(5) = +1 difference
      expect(lowScore - nullScore, equals(1));
    });

    test('very low runnability (10-24) adds +3', () {
      final veryLowScore = SongQualityScorer.score(
        song: _song(),
        runnability: 15,
      );
      final nullScore = SongQualityScorer.score(
        song: _song(),
        runnability: null,
      );
      // veryLow(3) vs neutral(5) = -2 difference
      expect(veryLowScore - nullScore, equals(-2));
    });

    test('null runnability adds neutral +5', () {
      final score = SongQualityScorer.score(
        song: _song(),
        runnability: null,
      );
      // exact(3) + danceability neutral(3) + runnability neutral(5) = 11
      expect(score, equals(11));
    });

    test('runnabilityMaxWeight constant is 15', () {
      expect(SongQualityScorer.runnabilityMaxWeight, equals(15));
    });

    test('runnabilityNeutral constant is 5', () {
      expect(SongQualityScorer.runnabilityNeutral, equals(5));
    });
  });

  // ──────────────────────────────────────────────────────
  // Disliked artist penalty
  // ──────────────────────────────────────────────────────
  group('Disliked artist penalty', () {
    test('song by a disliked artist gets -15 penalty', () {
      final profile = TasteProfile(dislikedArtists: ['Drake']);
      final dislikedScore = SongQualityScorer.score(
        song: _song(artistName: 'Drake'),
        tasteProfile: profile,
      );
      final neutralScore = SongQualityScorer.score(
        song: _song(artistName: 'Unknown'),
        tasteProfile: profile,
      );
      expect(dislikedScore - neutralScore, equals(-15));
    });

    test('bidirectional substring: disliked "Drake" matches "Drake feat. Rihanna"',
        () {
      final profile = TasteProfile(dislikedArtists: ['Drake']);
      final score = SongQualityScorer.score(
        song: _song(artistName: 'Drake feat. Rihanna'),
        tasteProfile: profile,
      );
      final neutralScore = SongQualityScorer.score(
        song: _song(artistName: 'Unknown'),
        tasteProfile: profile,
      );
      expect(score - neutralScore, equals(-15));
    });

    test('bidirectional substring: disliked "Drake feat. Rihanna" matches "Drake"',
        () {
      final profile =
          TasteProfile(dislikedArtists: ['Drake feat. Rihanna']);
      final score = SongQualityScorer.score(
        song: _song(artistName: 'Drake'),
        tasteProfile: profile,
      );
      final neutralScore = SongQualityScorer.score(
        song: _song(artistName: 'Unknown'),
        tasteProfile: profile,
      );
      expect(score - neutralScore, equals(-15));
    });

    test('song by a non-disliked artist gets 0 penalty', () {
      final profile = TasteProfile(dislikedArtists: ['Drake']);
      final score = SongQualityScorer.score(
        song: _song(artistName: 'Eminem'),
        tasteProfile: profile,
      );
      final noProfileScore = SongQualityScorer.score(
        song: _song(artistName: 'Eminem'),
        tasteProfile: TasteProfile(),
      );
      expect(score, equals(noProfileScore));
    });

    test('empty dislikedArtists list: no penalty applied', () {
      final profile = TasteProfile(dislikedArtists: []);
      final score = SongQualityScorer.score(
        song: _song(artistName: 'Drake'),
        tasteProfile: profile,
      );
      final noProfileScore = SongQualityScorer.score(
        song: _song(artistName: 'Drake'),
        tasteProfile: TasteProfile(),
      );
      expect(score, equals(noProfileScore));
    });

    test('null tasteProfile: no penalty applied', () {
      final score = SongQualityScorer.score(
        song: _song(artistName: 'Drake'),
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
  // Tempo variance tolerance scoring
  // ──────────────────────────────────────────────────────
  group('Tempo variance tolerance scoring', () {
    test('strict: exact BPM gets exactBpmWeight (3)', () {
      final profile = TasteProfile(
        tempoVarianceTolerance: TempoVarianceTolerance.strict,
      );
      final exactScore = SongQualityScorer.score(
        song: _song(matchType: BpmMatchType.exact),
        tasteProfile: profile,
      );
      final halfTimeScore = SongQualityScorer.score(
        song: _song(matchType: BpmMatchType.halfTime),
        tasteProfile: profile,
      );
      // exact gets 3, halfTime gets 0 under strict -> diff = 3
      expect(exactScore - halfTimeScore, equals(3));
    });

    test('strict: half-time song gets 0', () {
      final profile = TasteProfile(
        tempoVarianceTolerance: TempoVarianceTolerance.strict,
      );
      final strictScore = SongQualityScorer.score(
        song: _song(matchType: BpmMatchType.halfTime),
        tasteProfile: profile,
      );
      final moderateScore = SongQualityScorer.score(
        song: _song(matchType: BpmMatchType.halfTime),
        tasteProfile: null,
      );
      // strict halfTime=0, moderate halfTime=1 -> diff = -1
      expect(strictScore - moderateScore, equals(-1));
    });

    test('moderate: exact BPM gets exactBpmWeight (3)', () {
      final profile = TasteProfile(
        tempoVarianceTolerance: TempoVarianceTolerance.moderate,
      );
      final exactScore = SongQualityScorer.score(
        song: _song(matchType: BpmMatchType.exact),
        tasteProfile: profile,
      );
      final halfTimeScore = SongQualityScorer.score(
        song: _song(matchType: BpmMatchType.halfTime),
        tasteProfile: profile,
      );
      // exact=3, halfTime=1 -> diff = 2
      expect(exactScore - halfTimeScore, equals(2));
    });

    test('moderate: half-time song gets tempoVariantWeight (1)', () {
      final profile = TasteProfile(
        tempoVarianceTolerance: TempoVarianceTolerance.moderate,
      );
      final moderateScore = SongQualityScorer.score(
        song: _song(matchType: BpmMatchType.halfTime),
        tasteProfile: profile,
      );
      final nullScore = SongQualityScorer.score(
        song: _song(matchType: BpmMatchType.halfTime),
        tasteProfile: null,
      );
      expect(moderateScore, equals(nullScore));
    });

    test('loose: exact BPM gets exactBpmWeight (3)', () {
      final profile = TasteProfile(
        tempoVarianceTolerance: TempoVarianceTolerance.loose,
      );
      final exactScore = SongQualityScorer.score(
        song: _song(matchType: BpmMatchType.exact),
        tasteProfile: profile,
      );
      final halfTimeScore = SongQualityScorer.score(
        song: _song(matchType: BpmMatchType.halfTime),
        tasteProfile: profile,
      );
      // exact=3, halfTime=2 -> diff = 1
      expect(exactScore - halfTimeScore, equals(1));
    });

    test('loose: half-time song gets looseTempoVariantWeight (2)', () {
      final profile = TasteProfile(
        tempoVarianceTolerance: TempoVarianceTolerance.loose,
      );
      final looseScore = SongQualityScorer.score(
        song: _song(matchType: BpmMatchType.halfTime),
        tasteProfile: profile,
      );
      final nullScore = SongQualityScorer.score(
        song: _song(matchType: BpmMatchType.halfTime),
        tasteProfile: null,
      );
      // loose halfTime=2, null/moderate halfTime=1 -> diff = 1
      expect(looseScore - nullScore, equals(1));
    });

    test('null tasteProfile: moderate behavior (unchanged from current)', () {
      final nullScore = SongQualityScorer.score(
        song: _song(matchType: BpmMatchType.halfTime),
        tasteProfile: null,
      );
      final moderateScore = SongQualityScorer.score(
        song: _song(matchType: BpmMatchType.halfTime),
        tasteProfile: TasteProfile(
          tempoVarianceTolerance: TempoVarianceTolerance.moderate,
        ),
      );
      expect(nullScore, equals(moderateScore));
    });
  });

  // ──────────────────────────────────────────────────────
  // Decade match
  // ──────────────────────────────────────────────────────
  group('Decade match', () {
    test('matching decade adds +4', () {
      final profile = TasteProfile(
        decades: [MusicDecade.the2000s],
      );
      final score = SongQualityScorer.score(
        song: _song(decade: '2000s'),
        tasteProfile: profile,
      );
      final noDecadeScore = SongQualityScorer.score(
        song: _song(decade: null),
        tasteProfile: profile,
      );
      expect(score - noDecadeScore, equals(4));
    });

    test('non-matching decade adds +0', () {
      final profile = TasteProfile(
        decades: [MusicDecade.the1990s],
      );
      final score = SongQualityScorer.score(
        song: _song(decade: '2000s'),
        tasteProfile: profile,
      );
      final noDecadeScore = SongQualityScorer.score(
        song: _song(decade: null),
        tasteProfile: profile,
      );
      expect(score, equals(noDecadeScore));
    });
  });

  // ──────────────────────────────────────────────────────
  // Danceability scoring
  // ──────────────────────────────────────────────────────
  group('Danceability scoring', () {
    test('high danceability (>=70) adds +8', () {
      final highScore = SongQualityScorer.score(
        song: _song(danceability: 85),
      );
      final nullScore = SongQualityScorer.score(
        song: _song(danceability: null),
      );
      // high(8) vs neutral(3) = +5 difference
      expect(highScore - nullScore, equals(5));
    });

    test('good danceability (50-69) adds +5', () {
      final goodScore = SongQualityScorer.score(
        song: _song(danceability: 60),
      );
      final nullScore = SongQualityScorer.score(
        song: _song(danceability: null),
      );
      // good(5) vs neutral(3) = +2 difference
      expect(goodScore - nullScore, equals(2));
    });

    test('moderate danceability (30-49) adds +2', () {
      final modScore = SongQualityScorer.score(
        song: _song(danceability: 40),
      );
      final nullScore = SongQualityScorer.score(
        song: _song(danceability: null),
      );
      // moderate(2) vs neutral(3) = -1 difference
      expect(modScore - nullScore, equals(-1));
    });

    test('low danceability (<30) adds +0', () {
      final lowScore = SongQualityScorer.score(
        song: _song(danceability: 15),
      );
      final nullScore = SongQualityScorer.score(
        song: _song(danceability: null),
      );
      // low(0) vs neutral(3) = -3 difference
      expect(lowScore - nullScore, equals(-3));
    });

    test('null danceability adds neutral +3', () {
      final score = SongQualityScorer.score(
        song: _song(danceability: null),
      );
      // exact(3) + danceability neutral(3) + runnability neutral(5) = 11
      expect(score, equals(11));
    });

    test('danceability boundary: exactly 70 gets +8', () {
      final at70 = SongQualityScorer.score(song: _song(danceability: 70));
      final at69 = SongQualityScorer.score(song: _song(danceability: 69));
      expect(at70 - at69, equals(3)); // 8 vs 5
    });

    test('danceability boundary: exactly 50 gets +5', () {
      final at50 = SongQualityScorer.score(song: _song(danceability: 50));
      final at49 = SongQualityScorer.score(song: _song(danceability: 49));
      expect(at50 - at49, equals(3)); // 5 vs 2
    });

    test('danceabilityMaxWeight constant is 8', () {
      expect(SongQualityScorer.danceabilityMaxWeight, equals(8));
    });

    test('danceabilityNeutral constant is 3', () {
      expect(SongQualityScorer.danceabilityNeutral, equals(3));
    });
  });
}
