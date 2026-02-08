import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/song_feedback/domain/song_feedback.dart';
import 'package:running_playlist_ai/features/taste_learning/domain/taste_pattern_analyzer.dart';
import 'package:running_playlist_ai/features/taste_learning/domain/taste_suggestion.dart';
import 'package:running_playlist_ai/features/taste_profile/domain/taste_profile.dart';

/// Helper to build a SongFeedback entry.
SongFeedback _fb({
  required String artist,
  required String title,
  required bool isLiked,
}) {
  final key = SongKey.normalize(artist, title);
  return SongFeedback(
    songKey: key,
    isLiked: isLiked,
    feedbackDate: DateTime(2026, 1, 1),
    songTitle: title,
    songArtist: artist,
  );
}

/// Helper to build a feedback map from a list of feedback entries.
Map<String, SongFeedback> _feedbackMap(List<SongFeedback> entries) {
  return {for (final e in entries) e.songKey: e};
}

/// Empty taste profile baseline.
final _emptyProfile = TasteProfile(genres: [], artists: []);

void main() {
  group('TastePatternAnalyzer', () {
    test('empty feedback returns empty suggestions', () {
      final result = TastePatternAnalyzer.analyze(
        feedback: {},
        curatedGenreLookup: {},
        activeProfile: _emptyProfile,
        dismissedSuggestions: {},
      );
      expect(result, isEmpty);
    });

    group('genre detection', () {
      test('detects genre pattern from curated lookup enrichment', () {
        // 5 liked songs, 3 are "rock" in curated lookup
        final fb1 = _fb(artist: 'Band A', title: 'Song 1', isLiked: true);
        final fb2 = _fb(artist: 'Band B', title: 'Song 2', isLiked: true);
        final fb3 = _fb(artist: 'Band C', title: 'Song 3', isLiked: true);
        final fb4 = _fb(artist: 'Band D', title: 'Song 4', isLiked: true);
        final fb5 = _fb(artist: 'Band E', title: 'Song 5', isLiked: true);

        final curatedGenreLookup = {
          fb1.songKey: 'rock',
          fb2.songKey: 'rock',
          fb3.songKey: 'rock',
          fb4.songKey: 'pop',
          fb5.songKey: 'pop',
        };

        final result = TastePatternAnalyzer.analyze(
          feedback: _feedbackMap([fb1, fb2, fb3, fb4, fb5]),
          curatedGenreLookup: curatedGenreLookup,
          activeProfile: _emptyProfile,
          dismissedSuggestions: {},
        );

        expect(result, isNotEmpty);
        final rockSuggestion = result.firstWhere(
          (s) => s.type == SuggestionType.addGenre && s.value == 'rock',
        );
        expect(rockSuggestion.evidenceCount, 3);
        expect(rockSuggestion.confidence, closeTo(0.6, 0.01)); // 3/5
        expect(rockSuggestion.displayText, contains('Rock'));
      });

      test('genre below count threshold (< 3) produces no suggestion', () {
        // 5 liked songs, only 1 is "rock"
        final fb1 = _fb(artist: 'Band A', title: 'Song 1', isLiked: true);
        final fb2 = _fb(artist: 'Band B', title: 'Song 2', isLiked: true);
        final fb3 = _fb(artist: 'Band C', title: 'Song 3', isLiked: true);
        final fb4 = _fb(artist: 'Band D', title: 'Song 4', isLiked: true);
        final fb5 = _fb(artist: 'Band E', title: 'Song 5', isLiked: true);

        final curatedGenreLookup = {
          fb1.songKey: 'rock',
          fb2.songKey: 'pop',
          fb3.songKey: 'pop',
          fb4.songKey: 'pop',
          fb5.songKey: 'pop',
        };

        final result = TastePatternAnalyzer.analyze(
          feedback: _feedbackMap([fb1, fb2, fb3, fb4, fb5]),
          curatedGenreLookup: curatedGenreLookup,
          activeProfile: _emptyProfile,
          dismissedSuggestions: {},
        );

        final rockSuggestions = result.where(
          (s) => s.type == SuggestionType.addGenre && s.value == 'rock',
        );
        expect(rockSuggestions, isEmpty);
      });

      test('genre already in profile produces no suggestion', () {
        final fb1 = _fb(artist: 'Band A', title: 'Song 1', isLiked: true);
        final fb2 = _fb(artist: 'Band B', title: 'Song 2', isLiked: true);
        final fb3 = _fb(artist: 'Band C', title: 'Song 3', isLiked: true);
        final fb4 = _fb(artist: 'Band D', title: 'Song 4', isLiked: true);
        final fb5 = _fb(artist: 'Band E', title: 'Song 5', isLiked: true);

        final curatedGenreLookup = {
          fb1.songKey: 'rock',
          fb2.songKey: 'rock',
          fb3.songKey: 'rock',
          fb4.songKey: 'pop',
          fb5.songKey: 'pop',
        };

        final profileWithRock = TasteProfile(
          genres: [RunningGenre.rock],
          artists: [],
        );

        final result = TastePatternAnalyzer.analyze(
          feedback: _feedbackMap([fb1, fb2, fb3, fb4, fb5]),
          curatedGenreLookup: curatedGenreLookup,
          activeProfile: profileWithRock,
          dismissedSuggestions: {},
        );

        final rockSuggestions = result.where(
          (s) => s.type == SuggestionType.addGenre && s.value == 'rock',
        );
        expect(rockSuggestions, isEmpty);
      });

      test('genre ratio below threshold (< 30%) produces no suggestion', () {
        // 10 liked songs with genre data, 2 in rock (20% < 30%)
        final entries = <SongFeedback>[];
        final lookup = <String, String>{};

        for (var i = 0; i < 10; i++) {
          final fb = _fb(
            artist: 'Artist $i',
            title: 'Track $i',
            isLiked: true,
          );
          entries.add(fb);
          lookup[fb.songKey] = i < 2 ? 'rock' : 'pop';
        }

        final result = TastePatternAnalyzer.analyze(
          feedback: _feedbackMap(entries),
          curatedGenreLookup: lookup,
          activeProfile: _emptyProfile,
          dismissedSuggestions: {},
        );

        final rockSuggestions = result.where(
          (s) => s.type == SuggestionType.addGenre && s.value == 'rock',
        );
        expect(rockSuggestions, isEmpty);
      });

      test('insufficient genre data (< 5 liked with genre) produces no suggestion', () {
        // Only 3 liked songs total with genre data
        final fb1 = _fb(artist: 'Band A', title: 'Song 1', isLiked: true);
        final fb2 = _fb(artist: 'Band B', title: 'Song 2', isLiked: true);
        final fb3 = _fb(artist: 'Band C', title: 'Song 3', isLiked: true);

        final curatedGenreLookup = {
          fb1.songKey: 'rock',
          fb2.songKey: 'rock',
          fb3.songKey: 'rock',
        };

        final result = TastePatternAnalyzer.analyze(
          feedback: _feedbackMap([fb1, fb2, fb3]),
          curatedGenreLookup: curatedGenreLookup,
          activeProfile: _emptyProfile,
          dismissedSuggestions: {},
        );

        final genreSuggestions = result.where(
          (s) => s.type == SuggestionType.addGenre,
        );
        expect(genreSuggestions, isEmpty);
      });
    });

    group('artist detection', () {
      test('detects liked artist pattern (count >= 2)', () {
        final fb1 = _fb(artist: 'Eminem', title: 'Lose Yourself', isLiked: true);
        final fb2 = _fb(artist: 'Eminem', title: 'Till I Collapse', isLiked: true);
        final fb3 = _fb(artist: 'Other', title: 'Song X', isLiked: true);

        final result = TastePatternAnalyzer.analyze(
          feedback: _feedbackMap([fb1, fb2, fb3]),
          curatedGenreLookup: {},
          activeProfile: _emptyProfile,
          dismissedSuggestions: {},
        );

        expect(result, isNotEmpty);
        final eminemSuggestion = result.firstWhere(
          (s) => s.type == SuggestionType.addArtist,
        );
        expect(eminemSuggestion.value, 'Eminem');
        expect(eminemSuggestion.evidenceCount, 2);
        expect(eminemSuggestion.displayText, contains('Eminem'));
      });

      test('artist already in profile produces no suggestion', () {
        final fb1 = _fb(artist: 'Eminem', title: 'Lose Yourself', isLiked: true);
        final fb2 = _fb(artist: 'Eminem', title: 'Till I Collapse', isLiked: true);

        final profileWithEminem = TasteProfile(
          genres: [],
          artists: ['Eminem'],
        );

        final result = TastePatternAnalyzer.analyze(
          feedback: _feedbackMap([fb1, fb2]),
          curatedGenreLookup: {},
          activeProfile: profileWithEminem,
          dismissedSuggestions: {},
        );

        final artistSuggestions = result.where(
          (s) => s.type == SuggestionType.addArtist,
        );
        expect(artistSuggestions, isEmpty);
      });

      test('artist in profile with different case produces no suggestion', () {
        final fb1 = _fb(artist: 'EMINEM', title: 'Lose Yourself', isLiked: true);
        final fb2 = _fb(artist: 'EMINEM', title: 'Till I Collapse', isLiked: true);

        final profileWithEminem = TasteProfile(
          genres: [],
          artists: ['eminem'],
        );

        final result = TastePatternAnalyzer.analyze(
          feedback: _feedbackMap([fb1, fb2]),
          curatedGenreLookup: {},
          activeProfile: profileWithEminem,
          dismissedSuggestions: {},
        );

        final artistSuggestions = result.where(
          (s) => s.type == SuggestionType.addArtist,
        );
        expect(artistSuggestions, isEmpty);
      });
    });

    group('disliked artist detection', () {
      test('detects disliked artist pattern (count >= 2)', () {
        final fb1 = _fb(artist: 'Nickelback', title: 'Song A', isLiked: false);
        final fb2 = _fb(artist: 'Nickelback', title: 'Song B', isLiked: false);
        final fb3 = _fb(artist: 'Good Band', title: 'Song C', isLiked: true);

        final result = TastePatternAnalyzer.analyze(
          feedback: _feedbackMap([fb1, fb2, fb3]),
          curatedGenreLookup: {},
          activeProfile: _emptyProfile,
          dismissedSuggestions: {},
        );

        expect(result, isNotEmpty);
        final nickelbackSuggestion = result.firstWhere(
          (s) => s.type == SuggestionType.removeArtist,
        );
        expect(nickelbackSuggestion.value, 'Nickelback');
        expect(nickelbackSuggestion.evidenceCount, 2);
        expect(nickelbackSuggestion.displayText, contains('Nickelback'));
      });

      test('disliked artist already in profile produces no suggestion', () {
        final fb1 = _fb(artist: 'Nickelback', title: 'Song A', isLiked: false);
        final fb2 = _fb(artist: 'Nickelback', title: 'Song B', isLiked: false);

        final profileWithDisliked = TasteProfile(
          genres: [],
          artists: [],
          dislikedArtists: ['Nickelback'],
        );

        final result = TastePatternAnalyzer.analyze(
          feedback: _feedbackMap([fb1, fb2]),
          curatedGenreLookup: {},
          activeProfile: profileWithDisliked,
          dismissedSuggestions: {},
        );

        final removeSuggestions = result.where(
          (s) => s.type == SuggestionType.removeArtist,
        );
        expect(removeSuggestions, isEmpty);
      });
    });

    group('dismissed suggestion filtering', () {
      test('dismissed suggestion not resurfaced when delta < 3', () {
        final fb1 = _fb(artist: 'Eminem', title: 'Lose Yourself', isLiked: true);
        final fb2 = _fb(artist: 'Eminem', title: 'Till I Collapse', isLiked: true);
        final fb3 = _fb(artist: 'Eminem', title: 'Rap God', isLiked: true);
        final fb4 = _fb(artist: 'Eminem', title: 'Not Afraid', isLiked: true);

        // Dismissed at evidenceCount=3, current is 4 (delta=1 < 3)
        final dismissed = {'addArtist:Eminem': 3};

        final result = TastePatternAnalyzer.analyze(
          feedback: _feedbackMap([fb1, fb2, fb3, fb4]),
          curatedGenreLookup: {},
          activeProfile: _emptyProfile,
          dismissedSuggestions: dismissed,
        );

        final eminemSuggestions = result.where(
          (s) => s.type == SuggestionType.addArtist && s.value == 'Eminem',
        );
        expect(eminemSuggestions, isEmpty);
      });

      test('dismissed suggestion resurfaced when delta >= 3', () {
        final entries = <SongFeedback>[];
        for (var i = 0; i < 6; i++) {
          entries.add(_fb(
            artist: 'Eminem',
            title: 'Track $i',
            isLiked: true,
          ));
        }

        // Dismissed at evidenceCount=3, current is 6 (delta=3 >= 3)
        final dismissed = {'addArtist:Eminem': 3};

        final result = TastePatternAnalyzer.analyze(
          feedback: _feedbackMap(entries),
          curatedGenreLookup: {},
          activeProfile: _emptyProfile,
          dismissedSuggestions: dismissed,
        );

        final eminemSuggestion = result.firstWhere(
          (s) => s.type == SuggestionType.addArtist && s.value == 'Eminem',
        );
        expect(eminemSuggestion.evidenceCount, 6);
      });
    });

    test('max 3 suggestions returned', () {
      // Create enough data for 5+ artist suggestions
      final entries = <SongFeedback>[];
      for (var i = 0; i < 5; i++) {
        final artist = 'Artist $i';
        entries.add(_fb(artist: artist, title: 'Track A', isLiked: true));
        entries.add(_fb(artist: artist, title: 'Track B', isLiked: true));
      }

      final result = TastePatternAnalyzer.analyze(
        feedback: _feedbackMap(entries),
        curatedGenreLookup: {},
        activeProfile: _emptyProfile,
        dismissedSuggestions: {},
      );

      expect(result.length, lessThanOrEqualTo(3));
    });

    test('API-only songs skipped for genre but counted for artist', () {
      // 5 liked songs by same artist, none in curated lookup for genre
      final entries = <SongFeedback>[];
      for (var i = 0; i < 5; i++) {
        entries.add(_fb(
          artist: 'API Artist',
          title: 'API Song $i',
          isLiked: true,
        ));
      }

      // Empty curated lookup -- no genre data available
      final result = TastePatternAnalyzer.analyze(
        feedback: _feedbackMap(entries),
        curatedGenreLookup: {},
        activeProfile: _emptyProfile,
        dismissedSuggestions: {},
      );

      // Should have artist suggestion but no genre suggestion
      final genreSuggestions = result.where(
        (s) => s.type == SuggestionType.addGenre,
      );
      final artistSuggestions = result.where(
        (s) => s.type == SuggestionType.addArtist,
      );
      expect(genreSuggestions, isEmpty);
      expect(artistSuggestions, isNotEmpty);
    });

    test('suggestions sorted by evidence count descending', () {
      // Create artist suggestions with different evidence counts
      final entries = <SongFeedback>[];

      // Artist A: 2 likes
      entries.add(_fb(artist: 'Alpha', title: 'Song 1', isLiked: true));
      entries.add(_fb(artist: 'Alpha', title: 'Song 2', isLiked: true));

      // Artist B: 4 likes
      for (var i = 0; i < 4; i++) {
        entries.add(_fb(artist: 'Bravo', title: 'Track $i', isLiked: true));
      }

      // Artist C: 3 likes
      for (var i = 0; i < 3; i++) {
        entries.add(_fb(artist: 'Charlie', title: 'Piece $i', isLiked: true));
      }

      final result = TastePatternAnalyzer.analyze(
        feedback: _feedbackMap(entries),
        curatedGenreLookup: {},
        activeProfile: _emptyProfile,
        dismissedSuggestions: {},
      );

      expect(result.length, 3);
      expect(result[0].evidenceCount, greaterThanOrEqualTo(result[1].evidenceCount));
      expect(result[1].evidenceCount, greaterThanOrEqualTo(result[2].evidenceCount));
    });
  });
}
