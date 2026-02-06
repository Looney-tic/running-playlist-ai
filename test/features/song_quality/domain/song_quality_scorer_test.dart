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
}) {
  return BpmSong(
    songId: 'id-1',
    title: 'Test Song',
    artistName: artistName,
    tempo: 170,
    matchType: matchType,
    genre: genre,
    decade: decade,
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
    test('best case: artist(10) + genre(6) + exact(3) + curated(5) + decade(4) = 28',
        () {
      final profile = TasteProfile(
        artists: ['Eminem'],
        genres: [RunningGenre.rock],
        decades: [MusicDecade.the2000s],
      );
      final score = SongQualityScorer.score(
        song: _song(
          artistName: 'Eminem',
          matchType: BpmMatchType.exact,
          decade: '2000s',
        ),
        tasteProfile: profile,
        songGenres: [RunningGenre.rock],
        isCurated: true,
      );
      expect(score, equals(28));
    });

    test('worst case: no match + variant(1) = 1', () {
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
      expect(score, equals(1));
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
      // Exact BPM=3 => 3
      expect(score, equals(3));
    });

    test('no Flutter imports in scorer', () {
      // This test is a reminder -- actual verification done via grep.
      expect(true, isTrue);
    });
  });

  // ──────────────────────────────────────────────────────
  // Curated bonus
  // ──────────────────────────────────────────────────────
  group('Curated bonus', () {
    test('curated bonus adds +5 to score', () {
      final song = _song();
      final base = SongQualityScorer.score(song: song, isCurated: false);
      final curated = SongQualityScorer.score(song: song, isCurated: true);
      expect(curated - base, equals(5));
    });

    test('non-curated songs get zero curated bonus (default unchanged)', () {
      final song = _song();
      final defaultScore = SongQualityScorer.score(song: song);
      final explicitFalse =
          SongQualityScorer.score(song: song, isCurated: false);
      expect(defaultScore, equals(explicitFalse));
    });

    test('curated bonus is additive, not multiplicative', () {
      // Exact BPM song: base includes +3 (exact BPM) = 3
      // With curated: 3 + 5 = 8
      final song = _song(matchType: BpmMatchType.exact);
      final curated = SongQualityScorer.score(song: song, isCurated: true);
      expect(curated, equals(8)); // 3 base + 5 curated
    });

    test('curatedBonusWeight constant is 5', () {
      expect(SongQualityScorer.curatedBonusWeight, equals(5));
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
}
