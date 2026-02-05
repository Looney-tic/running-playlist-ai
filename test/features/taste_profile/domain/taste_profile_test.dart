import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/taste_profile/domain/taste_profile.dart';

void main() {
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

    test('fromJson throws on invalid name', () {
      expect(
        () => EnergyLevel.fromJson('invalid'),
        throwsA(isA<StateError>()),
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

    test('fromJson throws on invalid name', () {
      expect(
        () => RunningGenre.fromJson('invalid'),
        throwsA(isA<StateError>()),
      );
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

  // -- TasteProfile default constructor ---------------------------------------

  group('TasteProfile defaults', () {
    test('default constructor has empty genres', () {
      const profile = TasteProfile();
      expect(profile.genres, isEmpty);
    });

    test('default constructor has empty artists', () {
      const profile = TasteProfile();
      expect(profile.artists, isEmpty);
    });

    test('default constructor has balanced energy level', () {
      const profile = TasteProfile();
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
      const profile = TasteProfile(energyLevel: EnergyLevel.chill);
      final json = profile.toJson();
      expect(json['energyLevel'], equals('chill'));
    });

    test('round-trip with empty genres and artists', () {
      const original = TasteProfile();
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
