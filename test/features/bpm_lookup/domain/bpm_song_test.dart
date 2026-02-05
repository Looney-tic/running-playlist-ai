import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/bpm_lookup/'
    'domain/bpm_song.dart';

void main() {
  // -- BpmMatchType enum -------------------------------------------------

  group('BpmMatchType', () {
    test('has exactly 3 values', () {
      expect(BpmMatchType.values.length, equals(3));
    });

    test('fromJson deserializes each value', () {
      for (final type in BpmMatchType.values) {
        expect(BpmMatchType.fromJson(type.name), equals(type));
      }
    });

    test('fromJson throws on invalid name', () {
      expect(
        () => BpmMatchType.fromJson('invalid'),
        throwsA(isA<StateError>()),
      );
    });
  });

  // -- BpmSong.fromApiJson -----------------------------------------------

  group('BpmSong.fromApiJson', () {
    test('parses a complete API response item', () {
      final json = {
        'song_id': 'abc123',
        'song_title': 'Test Song',
        'song_uri': 'https://getsongbpm.com/song/test/abc123',
        'tempo': '170',
        'artist': {
          'id': 'xyz789',
          'name': 'Test Artist',
          'uri': 'https://getsongbpm.com/artist/test/xyz789',
        },
        'album': {
          'title': 'Test Album',
          'uri': 'https://getsongbpm.com/album/test/def456',
        },
      };

      final song = BpmSong.fromApiJson(json);
      expect(song.songId, equals('abc123'));
      expect(song.title, equals('Test Song'));
      expect(song.artistName, equals('Test Artist'));
      expect(song.tempo, equals(170));
      expect(
        song.songUri,
        equals('https://getsongbpm.com/song/test/abc123'),
      );
      expect(
        song.artistUri,
        equals('https://getsongbpm.com/artist/test/xyz789'),
      );
      expect(song.albumTitle, equals('Test Album'));
      expect(song.matchType, equals(BpmMatchType.exact));
    });

    test('parses tempo as string to int', () {
      final json = {
        'song_id': 's1',
        'song_title': 'Song',
        'tempo': '85',
        'artist': {'name': 'A'},
      };
      final song = BpmSong.fromApiJson(json);
      expect(song.tempo, equals(85));
    });

    test('defaults to 0 when tempo is invalid string', () {
      final json = {
        'song_id': 's1',
        'song_title': 'Song',
        'tempo': 'not-a-number',
        'artist': {'name': 'A'},
      };
      final song = BpmSong.fromApiJson(json);
      expect(song.tempo, equals(0));
    });

    test('handles missing optional fields gracefully', () {
      final json = {
        'song_id': 's1',
        'song_title': 'Song',
        'tempo': '120',
        'artist': {'name': 'A'},
      };
      final song = BpmSong.fromApiJson(json);
      expect(song.songUri, isNull);
      expect(song.artistUri, isNull);
      expect(song.albumTitle, isNull);
    });

    test('handles null artist and album gracefully', () {
      final json = {
        'song_id': 's1',
        'song_title': 'Song',
        'tempo': '120',
      };
      final song = BpmSong.fromApiJson(json);
      expect(song.artistName, equals(''));
      expect(song.albumTitle, isNull);
    });

    test('accepts matchType parameter', () {
      final json = {
        'song_id': 's1',
        'song_title': 'Song',
        'tempo': '85',
        'artist': {'name': 'A'},
      };
      final song = BpmSong.fromApiJson(json, matchType: BpmMatchType.halfTime);
      expect(song.matchType, equals(BpmMatchType.halfTime));
    });
  });

  // -- BpmSong.toJson / fromJson round-trip ------------------------------------

  group('BpmSong serialization', () {
    test('toJson -> fromJson round-trip preserves core fields', () {
      const original = BpmSong(
        songId: 'abc',
        title: 'My Song',
        artistName: 'My Artist',
        tempo: 170,
        songUri: 'https://example.com/song',
        artistUri: 'https://example.com/artist',
        albumTitle: 'My Album',
        matchType: BpmMatchType.halfTime,
      );
      final json = original.toJson();
      final restored = BpmSong.fromJson(json);
      expect(restored.songId, equals(original.songId));
      expect(restored.title, equals(original.title));
      expect(restored.artistName, equals(original.artistName));
      expect(restored.tempo, equals(original.tempo));
      expect(restored.songUri, equals(original.songUri));
      expect(restored.artistUri, equals(original.artistUri));
      expect(restored.albumTitle, equals(original.albumTitle));
    });

    test('toJson excludes matchType', () {
      const song = BpmSong(
        songId: 'abc',
        title: 'Song',
        artistName: 'Artist',
        tempo: 170,
        matchType: BpmMatchType.halfTime,
      );
      final json = song.toJson();
      expect(json.containsKey('matchType'), isFalse);
    });

    test('fromJson defaults matchType to exact when key absent', () {
      final json = {
        'songId': 'abc',
        'title': 'Song',
        'artistName': 'Artist',
        'tempo': 170,
      };
      final song = BpmSong.fromJson(json);
      expect(song.matchType, equals(BpmMatchType.exact));
    });

    test('round-trip with null optional fields', () {
      const original = BpmSong(
        songId: 'abc',
        title: 'Song',
        artistName: 'Artist',
        tempo: 120,
      );
      final json = original.toJson();
      final restored = BpmSong.fromJson(json);
      expect(restored.songUri, isNull);
      expect(restored.artistUri, isNull);
      expect(restored.albumTitle, isNull);
    });
  });

  // -- BpmSong.withMatchType ---------------------------------------------

  group('BpmSong.withMatchType', () {
    test('creates copy with new matchType', () {
      const song = BpmSong(
        songId: 'abc',
        title: 'Song',
        artistName: 'Artist',
        tempo: 85,
      );
      final halfTime = song.withMatchType(BpmMatchType.halfTime);
      expect(halfTime.matchType, equals(BpmMatchType.halfTime));
      expect(halfTime.songId, equals('abc'));
      expect(halfTime.title, equals('Song'));
      expect(halfTime.tempo, equals(85));
    });
  });
}
