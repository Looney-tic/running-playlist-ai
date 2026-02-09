import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/running_songs/domain/running_song.dart';

void main() {
  group('RunningSong', () {
    RunningSong _makeSong({
      int? bpm = 150,
      String? genre = 'hip-hop',
      RunningSongSource source = RunningSongSource.curated,
    }) {
      return RunningSong(
        songKey: 'eminem|lose yourself',
        artist: 'Eminem',
        title: 'Lose Yourself',
        addedDate: DateTime(2026, 2, 9),
        bpm: bpm,
        genre: genre,
        source: source,
      );
    }

    test('toJson/fromJson round-trip preserves all fields', () {
      final original = _makeSong(
        bpm: 171,
        genre: 'hip-hop',
        source: RunningSongSource.spotify,
      );
      final json = original.toJson();
      final restored = RunningSong.fromJson(json);

      expect(restored.songKey, original.songKey);
      expect(restored.artist, original.artist);
      expect(restored.title, original.title);
      expect(restored.addedDate, original.addedDate);
      expect(restored.bpm, original.bpm);
      expect(restored.genre, original.genre);
      expect(restored.source, original.source);
    });

    test('toJson/fromJson round-trip with optional fields null', () {
      final original = _makeSong(bpm: null, genre: null);
      final json = original.toJson();
      final restored = RunningSong.fromJson(json);

      expect(restored.songKey, original.songKey);
      expect(restored.artist, original.artist);
      expect(restored.title, original.title);
      expect(restored.addedDate, original.addedDate);
      expect(restored.bpm, isNull);
      expect(restored.genre, isNull);
      expect(restored.source, RunningSongSource.curated);
    });

    test('RunningSongSource falls back to curated for unknown value', () {
      final json = {
        'songKey': 'test|song',
        'artist': 'Test',
        'title': 'Song',
        'addedDate': '2026-02-09T00:00:00.000',
        'source': 'unknown_future_value',
      };
      final song = RunningSong.fromJson(json);
      expect(song.source, RunningSongSource.curated);
    });

    test('toJson excludes null optional fields', () {
      final song = _makeSong(bpm: null, genre: null);
      final json = song.toJson();

      expect(json.containsKey('bpm'), isFalse);
      expect(json.containsKey('genre'), isFalse);
      // Required fields still present.
      expect(json.containsKey('songKey'), isTrue);
      expect(json.containsKey('artist'), isTrue);
      expect(json.containsKey('title'), isTrue);
      expect(json.containsKey('addedDate'), isTrue);
      expect(json.containsKey('source'), isTrue);
    });

    test('toJson includes non-null optional fields', () {
      final song = _makeSong(bpm: 171, genre: 'hip-hop');
      final json = song.toJson();

      expect(json.containsKey('bpm'), isTrue);
      expect(json['bpm'], 171);
      expect(json.containsKey('genre'), isTrue);
      expect(json['genre'], 'hip-hop');
    });
  });
}
