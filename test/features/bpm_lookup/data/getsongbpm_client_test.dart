import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:running_playlist_ai/features/bpm_lookup/'
    'data/getsongbpm_client.dart';
import 'package:running_playlist_ai/features/bpm_lookup/'
    'domain/bpm_song.dart';

void main() {
  // -- BpmApiException -----------------------------------------------

  group('BpmApiException', () {
    test('toString includes message and status code', () {
      const e = BpmApiException('test error', statusCode: 500);
      expect(e.toString(), contains('test error'));
      expect(e.toString(), contains('500'));
    });

    test('statusCode can be null', () {
      const e = BpmApiException('network error');
      expect(e.statusCode, isNull);
    });
  });

  // -- GetSongBpmClient.fetchSongsByBpm --------------------------

  group('GetSongBpmClient.fetchSongsByBpm', () {
    test('sends correct URL with api_key and bpm params', () async {
      Uri? capturedUri;
      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode({'tempo': <dynamic>[]}),
          200,
        );
      });

      final client = GetSongBpmClient(
        apiKey: 'test-key-123',
        httpClient: mockClient,
      );

      await client.fetchSongsByBpm(170);

      expect(capturedUri, isNotNull);
      expect(capturedUri!.scheme, equals('https'));
      expect(capturedUri!.host, equals('api.getsongbpm.com'));
      expect(capturedUri!.path, equals('/tempo/'));
      expect(capturedUri!.queryParameters['api_key'], equals('test-key-123'));
      expect(capturedUri!.queryParameters['bpm'], equals('170'));
    });

    test('parses API response into BpmSong list', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'tempo': [
              {
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
              },
            ],
          }),
          200,
        );
      });

      final client = GetSongBpmClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      final songs = await client.fetchSongsByBpm(170);
      expect(songs.length, equals(1));
      expect(songs.first.songId, equals('abc123'));
      expect(songs.first.title, equals('Test Song'));
      expect(songs.first.artistName, equals('Test Artist'));
      expect(songs.first.tempo, equals(170));
      expect(songs.first.albumTitle, equals('Test Album'));
      expect(songs.first.matchType, equals(BpmMatchType.exact));
    });

    test('passes matchType to parsed songs', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'tempo': [
              {
                'song_id': 's1',
                'song_title': 'Half Song',
                'tempo': '85',
                'artist': {'name': 'A'},
              },
            ],
          }),
          200,
        );
      });

      final client = GetSongBpmClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      final songs = await client.fetchSongsByBpm(
        85,
        matchType: BpmMatchType.halfTime,
      );
      expect(songs.first.matchType, equals(BpmMatchType.halfTime));
    });

    test('returns empty list when tempo array is empty', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'tempo': <dynamic>[]}),
          200,
        );
      });

      final client = GetSongBpmClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      final songs = await client.fetchSongsByBpm(999);
      expect(songs, isEmpty);
    });

    test('returns empty list when tempo key is missing', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({}), 200);
      });

      final client = GetSongBpmClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      final songs = await client.fetchSongsByBpm(999);
      expect(songs, isEmpty);
    });

    test('throws BpmApiException on non-200 status code', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final client = GetSongBpmClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      expect(
        () => client.fetchSongsByBpm(170),
        throwsA(
          isA<BpmApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            equals(500),
          ),
        ),
      );
    });

    test('throws BpmApiException on 429 rate limit', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Too Many Requests', 429);
      });

      final client = GetSongBpmClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      expect(
        () => client.fetchSongsByBpm(170),
        throwsA(
          isA<BpmApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            equals(429),
          ),
        ),
      );
    });

    test('throws FormatException on invalid JSON response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('not valid json', 200);
      });

      final client = GetSongBpmClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      expect(
        () => client.fetchSongsByBpm(170),
        throwsA(isA<FormatException>()),
      );
    });

    test('parses multiple songs', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'tempo': [
              {
                'song_id': 's1',
                'song_title': 'Song One',
                'tempo': '170',
                'artist': {'name': 'Artist A'},
              },
              {
                'song_id': 's2',
                'song_title': 'Song Two',
                'tempo': '170',
                'artist': {'name': 'Artist B'},
              },
              {
                'song_id': 's3',
                'song_title': 'Song Three',
                'tempo': '170',
                'artist': {'name': 'Artist C'},
              },
            ],
          }),
          200,
        );
      });

      final client = GetSongBpmClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      final songs = await client.fetchSongsByBpm(170);
      expect(songs.length, equals(3));
      expect(songs[0].title, equals('Song One'));
      expect(songs[1].title, equals('Song Two'));
      expect(songs[2].title, equals('Song Three'));
    });
  });
}
