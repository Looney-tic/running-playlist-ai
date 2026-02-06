import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/curated_songs/domain/curated_song.dart';

void main() {
  // ──────────────────────────────────────────────────────
  // fromJson (camelCase bundled asset format)
  // ──────────────────────────────────────────────────────
  group('CuratedSong.fromJson', () {
    test('deserializes camelCase JSON with all fields', () {
      final json = {
        'title': 'Lose Yourself',
        'artistName': 'Eminem',
        'genre': 'hipHop',
        'bpm': 171,
        'danceability': 72,
        'energyLevel': 'intense',
      };
      final song = CuratedSong.fromJson(json);
      expect(song.title, 'Lose Yourself');
      expect(song.artistName, 'Eminem');
      expect(song.genre, 'hipHop');
      expect(song.bpm, 171);
      expect(song.danceability, 72);
      expect(song.energyLevel, 'intense');
    });

    test('handles null optional fields', () {
      final json = {
        'title': 'Test',
        'artistName': 'Artist',
        'genre': 'pop',
        'bpm': 140,
      };
      final song = CuratedSong.fromJson(json);
      expect(song.title, 'Test');
      expect(song.artistName, 'Artist');
      expect(song.genre, 'pop');
      expect(song.bpm, 140);
      expect(song.danceability, isNull);
      expect(song.energyLevel, isNull);
    });
  });

  // ──────────────────────────────────────────────────────
  // fromSupabaseRow (snake_case format)
  // ──────────────────────────────────────────────────────
  group('CuratedSong.fromSupabaseRow', () {
    test('deserializes snake_case Supabase row', () {
      final row = {
        'title': 'Lose Yourself',
        'artist_name': 'Eminem',
        'genre': 'hipHop',
        'bpm': 171,
        'danceability': 72,
        'energy_level': 'intense',
      };
      final song = CuratedSong.fromSupabaseRow(row);
      expect(song.title, 'Lose Yourself');
      expect(song.artistName, 'Eminem');
      expect(song.genre, 'hipHop');
      expect(song.bpm, 171);
      expect(song.danceability, 72);
      expect(song.energyLevel, 'intense');
    });

    test('handles null optional fields in Supabase row', () {
      final row = {
        'title': 'Test',
        'artist_name': 'Artist',
        'genre': 'pop',
        'bpm': 140,
      };
      final song = CuratedSong.fromSupabaseRow(row);
      expect(song.danceability, isNull);
      expect(song.energyLevel, isNull);
    });
  });

  // ──────────────────────────────────────────────────────
  // lookupKey
  // ──────────────────────────────────────────────────────
  group('CuratedSong.lookupKey', () {
    test('produces normalized lowercase trimmed artist|title', () {
      final song = CuratedSong(
        title: '  Lose Yourself ',
        artistName: ' Eminem ',
        genre: 'hipHop',
        bpm: 171,
      );
      expect(song.lookupKey, 'eminem|lose yourself');
    });

    test('handles already normalized values', () {
      final song = CuratedSong(
        title: 'run',
        artistName: 'foo fighters',
        genre: 'rock',
        bpm: 165,
      );
      expect(song.lookupKey, 'foo fighters|run');
    });
  });

  // ──────────────────────────────────────────────────────
  // toJson roundtrip
  // ──────────────────────────────────────────────────────
  group('CuratedSong.toJson', () {
    test('roundtrips through fromJson(toJson())', () {
      final original = CuratedSong(
        title: 'Lose Yourself',
        artistName: 'Eminem',
        genre: 'hipHop',
        bpm: 171,
        danceability: 72,
        energyLevel: 'intense',
      );
      final roundtripped = CuratedSong.fromJson(original.toJson());
      expect(roundtripped.lookupKey, original.lookupKey);
      expect(roundtripped.bpm, original.bpm);
      expect(roundtripped.danceability, original.danceability);
      expect(roundtripped.energyLevel, original.energyLevel);
      expect(roundtripped.genre, original.genre);
    });

    test('roundtrips with null optionals', () {
      final original = CuratedSong(
        title: 'Test',
        artistName: 'Artist',
        genre: 'pop',
        bpm: 140,
      );
      final roundtripped = CuratedSong.fromJson(original.toJson());
      expect(roundtripped.lookupKey, original.lookupKey);
      expect(roundtripped.bpm, original.bpm);
      expect(roundtripped.danceability, isNull);
      expect(roundtripped.energyLevel, isNull);
    });
  });
}
