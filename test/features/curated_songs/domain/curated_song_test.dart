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
        'decade': '2000s',
        'durationSeconds': 326,
      };
      final song = CuratedSong.fromJson(json);
      expect(song.title, 'Lose Yourself');
      expect(song.artistName, 'Eminem');
      expect(song.genre, 'hipHop');
      expect(song.bpm, 171);
      expect(song.decade, '2000s');
      expect(song.durationSeconds, 326);
    });

    test('handles null optional fields', () {
      final json = {
        'title': 'Test',
        'artistName': 'Artist',
        'genre': 'pop',
      };
      final song = CuratedSong.fromJson(json);
      expect(song.title, 'Test');
      expect(song.artistName, 'Artist');
      expect(song.genre, 'pop');
      expect(song.bpm, isNull);
      expect(song.decade, isNull);
      expect(song.durationSeconds, isNull);
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
        'decade': '2000s',
        'duration_seconds': 326,
      };
      final song = CuratedSong.fromSupabaseRow(row);
      expect(song.title, 'Lose Yourself');
      expect(song.artistName, 'Eminem');
      expect(song.genre, 'hipHop');
      expect(song.bpm, 171);
      expect(song.decade, '2000s');
      expect(song.durationSeconds, 326);
    });

    test('handles null optional fields in Supabase row', () {
      final row = {
        'title': 'Test',
        'artist_name': 'Artist',
        'genre': 'pop',
      };
      final song = CuratedSong.fromSupabaseRow(row);
      expect(song.bpm, isNull);
      expect(song.decade, isNull);
      expect(song.durationSeconds, isNull);
    });
  });

  // ──────────────────────────────────────────────────────
  // lookupKey
  // ──────────────────────────────────────────────────────
  group('CuratedSong.lookupKey', () {
    test('produces normalized lowercase trimmed artist|title', () {
      const song = CuratedSong(
        title: '  Lose Yourself ',
        artistName: ' Eminem ',
        genre: 'hipHop',
        bpm: 171,
      );
      expect(song.lookupKey, 'eminem|lose yourself');
    });

    test('handles already normalized values', () {
      const song = CuratedSong(
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
      const original = CuratedSong(
        title: 'Lose Yourself',
        artistName: 'Eminem',
        genre: 'hipHop',
        bpm: 171,
        decade: '2000s',
        durationSeconds: 326,
      );
      final roundtripped = CuratedSong.fromJson(original.toJson());
      expect(roundtripped.lookupKey, original.lookupKey);
      expect(roundtripped.bpm, original.bpm);
      expect(roundtripped.decade, original.decade);
      expect(roundtripped.durationSeconds, original.durationSeconds);
      expect(roundtripped.genre, original.genre);
    });

    test('roundtrips with null optionals', () {
      const original = CuratedSong(
        title: 'Test',
        artistName: 'Artist',
        genre: 'pop',
      );
      final roundtripped = CuratedSong.fromJson(original.toJson());
      expect(roundtripped.lookupKey, original.lookupKey);
      expect(roundtripped.bpm, isNull);
      expect(roundtripped.decade, isNull);
      expect(roundtripped.durationSeconds, isNull);
    });

    test('toJson excludes null bpm', () {
      const song = CuratedSong(
        title: 'Test',
        artistName: 'Artist',
        genre: 'pop',
      );
      final json = song.toJson();
      expect(json.containsKey('bpm'), isFalse);
    });
  });
}
