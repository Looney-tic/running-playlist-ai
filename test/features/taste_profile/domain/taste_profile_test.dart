import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/taste_profile/domain/taste_profile.dart';

void main() {
  // -- VocalPreference enum ---------------------------------------------------

  group('VocalPreference', () {
    test('has exactly 3 values', () {
      expect(VocalPreference.values.length, equals(3));
    });

    test('fromJson deserializes noPreference', () {
      expect(
        VocalPreference.fromJson('noPreference'),
        equals(VocalPreference.noPreference),
      );
    });

    test('fromJson deserializes preferVocals', () {
      expect(
        VocalPreference.fromJson('preferVocals'),
        equals(VocalPreference.preferVocals),
      );
    });

    test('fromJson deserializes preferInstrumental', () {
      expect(
        VocalPreference.fromJson('preferInstrumental'),
        equals(VocalPreference.preferInstrumental),
      );
    });

    test('fromJson with unknown string falls back to noPreference', () {
      expect(
        VocalPreference.fromJson('unknownValue'),
        equals(VocalPreference.noPreference),
      );
    });
  });

  // -- TempoVarianceTolerance enum --------------------------------------------

  group('TempoVarianceTolerance', () {
    test('has exactly 3 values', () {
      expect(TempoVarianceTolerance.values.length, equals(3));
    });

    test('fromJson deserializes strict', () {
      expect(
        TempoVarianceTolerance.fromJson('strict'),
        equals(TempoVarianceTolerance.strict),
      );
    });

    test('fromJson deserializes moderate', () {
      expect(
        TempoVarianceTolerance.fromJson('moderate'),
        equals(TempoVarianceTolerance.moderate),
      );
    });

    test('fromJson deserializes loose', () {
      expect(
        TempoVarianceTolerance.fromJson('loose'),
        equals(TempoVarianceTolerance.loose),
      );
    });

    test('fromJson with unknown string falls back to moderate', () {
      expect(
        TempoVarianceTolerance.fromJson('unknownValue'),
        equals(TempoVarianceTolerance.moderate),
      );
    });
  });

  // -- EnergyLevel enum -------------------------------------------------------

  group('EnergyLevel', () {
    test('has exactly 3 values', () {
      expect(EnergyLevel.values.length, equals(3));
    });

    test('fromJson deserializes each value', () {
      for (final level in EnergyLevel.values) {
        expect(EnergyLevel.fromJson(level.name), equals(level));
      }
    });

    test('fromJson with unknown string falls back to balanced', () {
      expect(
        EnergyLevel.fromJson('superHigh'),
        equals(EnergyLevel.balanced),
      );
    });

    test('fromJson with empty string falls back to balanced', () {
      expect(
        EnergyLevel.fromJson(''),
        equals(EnergyLevel.balanced),
      );
    });
  });

  // -- RunningGenre enum ------------------------------------------------------

  group('RunningGenre', () {
    test('has exactly 15 values', () {
      expect(RunningGenre.values.length, equals(15));
    });

    test('each value has a non-empty displayName', () {
      for (final genre in RunningGenre.values) {
        expect(genre.displayName, isNotEmpty);
      }
    });

    test('fromJson deserializes each value', () {
      for (final genre in RunningGenre.values) {
        expect(RunningGenre.fromJson(genre.name), equals(genre));
      }
    });

    test('fromJson with unknown string falls back to pop', () {
      expect(
        RunningGenre.fromJson('countryRock'),
        equals(RunningGenre.pop),
      );
    });

    test('tryFromJson returns value for known genre', () {
      expect(
        RunningGenre.tryFromJson('pop'),
        equals(RunningGenre.pop),
      );
    });

    test('tryFromJson returns value for each known genre', () {
      for (final genre in RunningGenre.values) {
        expect(RunningGenre.tryFromJson(genre.name), equals(genre));
      }
    });

    test('tryFromJson returns null for unknown genre', () {
      expect(RunningGenre.tryFromJson('countryRock'), isNull);
    });

    test('tryFromJson returns null for empty string', () {
      expect(RunningGenre.tryFromJson(''), isNull);
    });

    test('specific display names are correct', () {
      expect(RunningGenre.hipHop.displayName, equals('Hip-Hop / Rap'));
      expect(
        RunningGenre.drumAndBass.displayName,
        equals('Drum & Bass'),
      );
      expect(RunningGenre.rnb.displayName, equals('R&B / Soul'));
      expect(RunningGenre.kPop.displayName, equals('K-Pop'));
    });
  });

  // -- MusicDecade enum -------------------------------------------------------

  group('MusicDecade', () {
    test('tryFromJson returns value for known decade', () {
      expect(
        MusicDecade.tryFromJson('the2010s'),
        equals(MusicDecade.the2010s),
      );
    });

    test('tryFromJson returns value for each known decade', () {
      for (final decade in MusicDecade.values) {
        expect(MusicDecade.tryFromJson(decade.name), equals(decade));
      }
    });

    test('tryFromJson returns null for unknown decade', () {
      expect(MusicDecade.tryFromJson('the2030s'), isNull);
    });

    test('tryFromJson returns null for empty string', () {
      expect(MusicDecade.tryFromJson(''), isNull);
    });
  });

  // -- TasteProfile backward-compatible fromJson ------------------------------

  group('TasteProfile backward-compatible fromJson', () {
    test('JSON with only original 3 fields deserializes successfully', () {
      final json = {
        'genres': ['pop', 'rock'],
        'artists': ['Dua Lipa'],
        'energyLevel': 'balanced',
      };
      final profile = TasteProfile.fromJson(json);
      expect(profile.genres, equals([RunningGenre.pop, RunningGenre.rock]));
      expect(profile.artists, equals(['Dua Lipa']));
      expect(profile.energyLevel, equals(EnergyLevel.balanced));
    });

    test('missing vocalPreference defaults to noPreference', () {
      final json = {
        'genres': <String>[],
        'artists': <String>[],
        'energyLevel': 'balanced',
      };
      final profile = TasteProfile.fromJson(json);
      expect(profile.vocalPreference, equals(VocalPreference.noPreference));
    });

    test('missing tempoVarianceTolerance defaults to moderate', () {
      final json = {
        'genres': <String>[],
        'artists': <String>[],
        'energyLevel': 'balanced',
      };
      final profile = TasteProfile.fromJson(json);
      expect(
        profile.tempoVarianceTolerance,
        equals(TempoVarianceTolerance.moderate),
      );
    });

    test('missing dislikedArtists defaults to empty list', () {
      final json = {
        'genres': <String>[],
        'artists': <String>[],
        'energyLevel': 'balanced',
      };
      final profile = TasteProfile.fromJson(json);
      expect(profile.dislikedArtists, isEmpty);
    });
  });

  // -- TasteProfile fromJson with all fields ----------------------------------

  group('TasteProfile fromJson with all fields', () {
    test('JSON with all 6 fields deserializes correctly', () {
      final json = {
        'genres': ['pop'],
        'artists': ['Dua Lipa'],
        'energyLevel': 'intense',
        'vocalPreference': 'preferVocals',
        'tempoVarianceTolerance': 'strict',
        'dislikedArtists': ['Drake', 'Pitbull'],
      };
      final profile = TasteProfile.fromJson(json);
      expect(profile.genres, equals([RunningGenre.pop]));
      expect(profile.artists, equals(['Dua Lipa']));
      expect(profile.energyLevel, equals(EnergyLevel.intense));
      expect(
        profile.vocalPreference,
        equals(VocalPreference.preferVocals),
      );
      expect(
        profile.tempoVarianceTolerance,
        equals(TempoVarianceTolerance.strict),
      );
      expect(profile.dislikedArtists, equals(['Drake', 'Pitbull']));
    });
  });

  // -- TasteProfile fromJson enum fallback safety -----------------------------

  group('TasteProfile fromJson enum fallback safety', () {
    test('unknown energyLevel falls back to balanced', () {
      final json = {
        'genres': ['pop'],
        'artists': <String>[],
        'energyLevel': 'superHigh',
      };
      final profile = TasteProfile.fromJson(json);
      expect(profile.energyLevel, equals(EnergyLevel.balanced));
    });

    test('unknown genre in list is filtered out', () {
      final json = {
        'genres': ['pop', 'countryRock', 'rock'],
        'artists': <String>[],
        'energyLevel': 'balanced',
      };
      final profile = TasteProfile.fromJson(json);
      expect(
        profile.genres,
        equals([RunningGenre.pop, RunningGenre.rock]),
      );
    });

    test('all unknown genres results in empty list', () {
      final json = {
        'genres': ['countryRock', 'tranceCore'],
        'artists': <String>[],
        'energyLevel': 'balanced',
      };
      final profile = TasteProfile.fromJson(json);
      expect(profile.genres, isEmpty);
    });

    test('unknown decade in list is filtered out', () {
      final json = {
        'genres': <String>[],
        'artists': <String>[],
        'energyLevel': 'balanced',
        'decades': ['the2010s', 'the2030s', 'the1990s'],
      };
      final profile = TasteProfile.fromJson(json);
      expect(
        profile.decades,
        equals([MusicDecade.the2010s, MusicDecade.the1990s]),
      );
    });

    test('all unknown decades results in empty list', () {
      final json = {
        'genres': <String>[],
        'artists': <String>[],
        'energyLevel': 'balanced',
        'decades': ['the2030s', 'the2040s'],
      };
      final profile = TasteProfile.fromJson(json);
      expect(profile.decades, isEmpty);
    });

    test('mixed valid and invalid fields all degrade gracefully', () {
      final json = {
        'genres': ['pop', 'futureGenre'],
        'artists': ['Artist A'],
        'energyLevel': 'unknownLevel',
        'vocalPreference': 'unknownPref',
        'tempoVarianceTolerance': 'unknownTolerance',
        'decades': ['the1980s', 'futureDecade'],
      };
      final profile = TasteProfile.fromJson(json);
      expect(profile.genres, equals([RunningGenre.pop]));
      expect(profile.artists, equals(['Artist A']));
      expect(profile.energyLevel, equals(EnergyLevel.balanced));
      expect(profile.vocalPreference, equals(VocalPreference.noPreference));
      expect(
        profile.tempoVarianceTolerance,
        equals(TempoVarianceTolerance.moderate),
      );
      expect(profile.decades, equals([MusicDecade.the1980s]));
    });
  });

  // -- TasteProfile toJson roundtrip with new fields --------------------------

  group('TasteProfile toJson roundtrip with new fields', () {
    test('toJson includes new fields', () {
      final profile = TasteProfile(
        genres: [RunningGenre.pop],
        artists: ['Dua Lipa'],
        energyLevel: EnergyLevel.balanced,
        vocalPreference: VocalPreference.preferInstrumental,
        tempoVarianceTolerance: TempoVarianceTolerance.loose,
        dislikedArtists: ['Drake'],
      );
      final json = profile.toJson();
      expect(json['vocalPreference'], equals('preferInstrumental'));
      expect(json['tempoVarianceTolerance'], equals('loose'));
      expect(json['dislikedArtists'], equals(['Drake']));
    });

    test('fromJson(toJson) roundtrips correctly', () {
      final original = TasteProfile(
        genres: [RunningGenre.pop, RunningGenre.rock],
        artists: ['Dua Lipa', 'The Weeknd'],
        energyLevel: EnergyLevel.intense,
        vocalPreference: VocalPreference.preferVocals,
        tempoVarianceTolerance: TempoVarianceTolerance.strict,
        dislikedArtists: ['Drake', 'Pitbull'],
      );
      final restored = TasteProfile.fromJson(original.toJson());
      expect(restored.genres, equals(original.genres));
      expect(restored.artists, equals(original.artists));
      expect(restored.energyLevel, equals(original.energyLevel));
      expect(restored.vocalPreference, equals(original.vocalPreference));
      expect(
        restored.tempoVarianceTolerance,
        equals(original.tempoVarianceTolerance),
      );
      expect(restored.dislikedArtists, equals(original.dislikedArtists));
    });
  });

  // -- TasteProfile copyWith for new fields -----------------------------------

  group('TasteProfile copyWith for new fields', () {
    test('copies vocalPreference only', () {
      final original = TasteProfile();
      final copied = original.copyWith(
        vocalPreference: VocalPreference.preferVocals,
      );
      expect(copied.vocalPreference, equals(VocalPreference.preferVocals));
      expect(
        copied.tempoVarianceTolerance,
        equals(TempoVarianceTolerance.moderate),
      );
      expect(copied.dislikedArtists, isEmpty);
    });

    test('copies tempoVarianceTolerance only', () {
      final original = TasteProfile();
      final copied = original.copyWith(
        tempoVarianceTolerance: TempoVarianceTolerance.strict,
      );
      expect(copied.vocalPreference, equals(VocalPreference.noPreference));
      expect(
        copied.tempoVarianceTolerance,
        equals(TempoVarianceTolerance.strict),
      );
      expect(copied.dislikedArtists, isEmpty);
    });

    test('copies dislikedArtists only', () {
      final original = TasteProfile();
      final copied = original.copyWith(
        dislikedArtists: ['Drake', 'Pitbull'],
      );
      expect(copied.vocalPreference, equals(VocalPreference.noPreference));
      expect(
        copied.tempoVarianceTolerance,
        equals(TempoVarianceTolerance.moderate),
      );
      expect(copied.dislikedArtists, equals(['Drake', 'Pitbull']));
    });
  });

  // -- TasteProfile default constructor ---------------------------------------

  group('TasteProfile defaults', () {
    test('default constructor has empty genres', () {
      final profile = TasteProfile();
      expect(profile.genres, isEmpty);
    });

    test('default constructor has empty artists', () {
      final profile = TasteProfile();
      expect(profile.artists, isEmpty);
    });

    test('default constructor has balanced energy level', () {
      final profile = TasteProfile();
      expect(profile.energyLevel, equals(EnergyLevel.balanced));
    });
  });

  // -- TasteProfile serialization ---------------------------------------------

  group('TasteProfile serialization', () {
    test('toJson -> fromJson round-trip preserves all fields', () {
      final original = TasteProfile(
        genres: [
          RunningGenre.pop,
          RunningGenre.hipHop,
          RunningGenre.electronic,
        ],
        artists: ['Dua Lipa', 'The Weeknd'],
        energyLevel: EnergyLevel.intense,
      );
      final json = original.toJson();
      final restored = TasteProfile.fromJson(json);
      expect(restored.genres, equals(original.genres));
      expect(restored.artists, equals(original.artists));
      expect(restored.energyLevel, equals(original.energyLevel));
    });

    test('toJson stores genre enum names, not display names', () {
      final profile = TasteProfile(
        genres: [RunningGenre.hipHop, RunningGenre.drumAndBass],
      );
      final json = profile.toJson();
      final genreList = json['genres'] as List<dynamic>;
      expect(genreList, contains('hipHop'));
      expect(genreList, contains('drumAndBass'));
      expect(genreList, isNot(contains('Hip-Hop / Rap')));
    });

    test('toJson stores energy level enum name', () {
      final profile = TasteProfile(energyLevel: EnergyLevel.chill);
      final json = profile.toJson();
      expect(json['energyLevel'], equals('chill'));
    });

    test('round-trip with empty genres and artists', () {
      final original = TasteProfile();
      final json = original.toJson();
      final restored = TasteProfile.fromJson(json);
      expect(restored.genres, isEmpty);
      expect(restored.artists, isEmpty);
      expect(restored.energyLevel, equals(EnergyLevel.balanced));
    });

    test('round-trip with max 5 genres', () {
      final original = TasteProfile(
        genres: [
          RunningGenre.pop,
          RunningGenre.rock,
          RunningGenre.edm,
          RunningGenre.house,
          RunningGenre.latin,
        ],
      );
      final json = original.toJson();
      final restored = TasteProfile.fromJson(json);
      expect(restored.genres.length, equals(5));
      expect(restored.genres, equals(original.genres));
    });

    test('round-trip with max 10 artists', () {
      final artists = List.generate(10, (i) => 'Artist $i');
      final original = TasteProfile(artists: artists);
      final json = original.toJson();
      final restored = TasteProfile.fromJson(json);
      expect(restored.artists.length, equals(10));
      expect(restored.artists, equals(artists));
    });

    test('artists with special characters survive round-trip', () {
      final original = TasteProfile(
        artists: ['AC/DC', "Guns N' Roses", 'Beyonce'],
      );
      final json = original.toJson();
      final restored = TasteProfile.fromJson(json);
      expect(restored.artists, equals(original.artists));
    });
  });

  // -- TasteProfile copyWith --------------------------------------------------

  group('TasteProfile copyWith', () {
    test('copies genres only', () {
      final original = TasteProfile(
        genres: [RunningGenre.pop],
        artists: ['Artist'],
        energyLevel: EnergyLevel.intense,
      );
      final copied = original.copyWith(
        genres: [RunningGenre.rock, RunningGenre.edm],
      );
      expect(
        copied.genres,
        equals([RunningGenre.rock, RunningGenre.edm]),
      );
      expect(copied.artists, equals(['Artist']));
      expect(copied.energyLevel, equals(EnergyLevel.intense));
    });

    test('copies artists only', () {
      final original = TasteProfile(
        genres: [RunningGenre.pop],
        artists: ['Old Artist'],
        energyLevel: EnergyLevel.chill,
      );
      final copied = original.copyWith(artists: ['New Artist']);
      expect(copied.genres, equals([RunningGenre.pop]));
      expect(copied.artists, equals(['New Artist']));
      expect(copied.energyLevel, equals(EnergyLevel.chill));
    });

    test('copies energy level only', () {
      final original = TasteProfile(
        genres: [RunningGenre.pop],
        energyLevel: EnergyLevel.chill,
      );
      final copied = original.copyWith(
        energyLevel: EnergyLevel.intense,
      );
      expect(copied.genres, equals([RunningGenre.pop]));
      expect(copied.energyLevel, equals(EnergyLevel.intense));
    });

    test('no arguments returns equivalent profile', () {
      final original = TasteProfile(
        genres: [RunningGenre.pop],
        artists: ['Artist'],
        energyLevel: EnergyLevel.intense,
      );
      final copied = original.copyWith();
      expect(copied.genres, equals(original.genres));
      expect(copied.artists, equals(original.artists));
      expect(copied.energyLevel, equals(original.energyLevel));
    });
  });
}
