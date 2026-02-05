import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:running_playlist_ai/features/bpm_lookup/data/bpm_cache_preferences.dart';
import 'package:running_playlist_ai/features/bpm_lookup/data/getsongbpm_client.dart';
import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_song.dart';
import 'package:running_playlist_ai/features/bpm_lookup/providers/bpm_lookup_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper to create a GetSongBpmClient with a MockClient.
GetSongBpmClient _clientWithMock(
  Future<http.Response> Function(http.Request) handler,
) {
  return GetSongBpmClient(
    apiKey: 'test-key',
    httpClient: MockClient(handler),
  );
}

/// Helper to build a valid API response body for a list of songs.
String _apiResponseBody(List<Map<String, dynamic>> songs) {
  return jsonEncode({'tempo': songs});
}

/// Helper API song JSON.
Map<String, dynamic> _apiSong({
  String id = 's1',
  String title = 'Song',
  String tempo = '170',
  String artist = 'Artist',
}) =>
    {
      'song_id': id,
      'song_title': title,
      'tempo': tempo,
      'artist': {'name': artist},
    };

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // -- BpmLookupState ----------------------------------------------------------

  group('BpmLookupState', () {
    test('default state has empty songs, not loading, no error', () {
      const state = BpmLookupState();
      expect(state.songs, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.targetBpm, isNull);
    });
  });

  // -- BpmLookupNotifier: successful lookups -----------------------------------

  group('BpmLookupNotifier successful lookups', () {
    test('lookupByBpm returns songs from API', () async {
      final client = _clientWithMock((request) async {
        return http.Response(
          _apiResponseBody([_apiSong(title: 'Test Song', tempo: '170')]),
          200,
        );
      });

      final notifier = BpmLookupNotifier(client);
      await notifier.lookupByBpm(170);

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
      expect(notifier.state.targetBpm, equals(170));
      expect(notifier.state.songs, isNotEmpty);
      // Should have songs from exact (170) + half-time (85) queries
      // Both return results since the mock responds to all requests
    });

    test('lookupByBpm sets isLoading to true during fetch', () async {
      var sawLoading = false;

      final client = _clientWithMock((request) async {
        // Verify notifier state during the API call is not easily done
        // because the mock is synchronous. Rely on state transition tests.
        return http.Response(
          _apiResponseBody([_apiSong()]),
          200,
        );
      });

      final notifier = BpmLookupNotifier(client);

      // Add a listener to capture state transitions
      notifier.addListener((state) {
        if (state.isLoading) sawLoading = true;
      });

      await notifier.lookupByBpm(170);
      expect(sawLoading, isTrue);
    });

    test('lookupByBpm assigns correct matchType to songs', () async {
      final client = _clientWithMock((request) async {
        final bpm = request.url.queryParameters['bpm'];
        if (bpm == '170') {
          return http.Response(
            _apiResponseBody([_apiSong(id: 'exact', tempo: '170')]),
            200,
          );
        } else if (bpm == '85') {
          return http.Response(
            _apiResponseBody([_apiSong(id: 'half', tempo: '85')]),
            200,
          );
        }
        return http.Response(_apiResponseBody([]), 200);
      });

      final notifier = BpmLookupNotifier(client);
      await notifier.lookupByBpm(170);

      final exactSong =
          notifier.state.songs.where((s) => s.songId == 'exact').first;
      final halfSong =
          notifier.state.songs.where((s) => s.songId == 'half').first;

      expect(exactSong.matchType, equals(BpmMatchType.exact));
      expect(halfSong.matchType, equals(BpmMatchType.halfTime));
    });
  });

  // -- BpmLookupNotifier: cache-first strategy ---------------------------------

  group('BpmLookupNotifier cache-first', () {
    test('uses cached results instead of making API call', () async {
      // Pre-populate cache for BPM 170
      await BpmCachePreferences.save(170, [
        const BpmSong(
          songId: 'cached',
          title: 'Cached Song',
          artistName: 'A',
          tempo: 170,
        ),
      ]);

      var apiCallCount = 0;
      final client = _clientWithMock((request) async {
        apiCallCount++;
        final bpm = request.url.queryParameters['bpm'];
        // Only the half-time (85) should hit the API
        return http.Response(
          _apiResponseBody([_apiSong(id: 'api-$bpm', tempo: bpm!)]),
          200,
        );
      });

      final notifier = BpmLookupNotifier(client);
      await notifier.lookupByBpm(170);

      // BPM 170 was cached, so only 85 (half-time) should hit the API
      expect(apiCallCount, equals(1));

      // Both cached and API songs should be in results
      final cachedSong =
          notifier.state.songs.where((s) => s.songId == 'cached');
      expect(cachedSong, isNotEmpty);
    });

    test('saves API results to cache for future lookups', () async {
      final client = _clientWithMock((request) async {
        return http.Response(
          _apiResponseBody([_apiSong(id: 'new-song', title: 'New')]),
          200,
        );
      });

      final notifier = BpmLookupNotifier(client);
      await notifier.lookupByBpm(170);

      // Verify cache was populated for BPM 170
      final cached = await BpmCachePreferences.load(170);
      expect(cached, isNotNull);
      expect(cached!.any((s) => s.songId == 'new-song'), isTrue);
    });

    test('second lookup for same BPM uses cache (zero API calls)', () async {
      var apiCallCount = 0;
      final client = _clientWithMock((request) async {
        apiCallCount++;
        return http.Response(
          _apiResponseBody([_apiSong()]),
          200,
        );
      });

      final notifier = BpmLookupNotifier(client);

      // First lookup -- hits API
      await notifier.lookupByBpm(170);
      final firstCallCount = apiCallCount;

      // Second lookup -- should use cache for all BPM values
      apiCallCount = 0;
      await notifier.lookupByBpm(170);

      expect(apiCallCount, equals(0));
      expect(firstCallCount, greaterThan(0));
    });
  });

  // -- BpmLookupNotifier: error handling ---------------------------------------

  group('BpmLookupNotifier error handling', () {
    test('handles BpmApiException with message', () async {
      final client = _clientWithMock((request) async {
        return http.Response('Server Error', 500);
      });

      final notifier = BpmLookupNotifier(client);
      await notifier.lookupByBpm(170);

      expect(notifier.state.error, isNotNull);
      expect(notifier.state.error, contains('Could not fetch songs'));
      expect(notifier.state.songs, isEmpty);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.targetBpm, equals(170));
    });

    test('handles FormatException from invalid JSON', () async {
      final client = _clientWithMock((request) async {
        return http.Response('not json', 200);
      });

      final notifier = BpmLookupNotifier(client);
      await notifier.lookupByBpm(170);

      expect(notifier.state.error, isNotNull);
      expect(notifier.state.error, contains('unexpected data'));
      expect(notifier.state.songs, isEmpty);
    });

    test('handles SocketException for no network', () async {
      final client = GetSongBpmClient(
        apiKey: 'test-key',
        httpClient: MockClient((request) async {
          throw const SocketException('No network');
        }),
      );

      final notifier = BpmLookupNotifier(client);
      await notifier.lookupByBpm(170);

      expect(notifier.state.error, isNotNull);
      expect(notifier.state.error, contains('No internet connection'));
      expect(notifier.state.songs, isEmpty);
    });

    test('handles TimeoutException', () async {
      final client = GetSongBpmClient(
        apiKey: 'test-key',
        httpClient: MockClient((request) async {
          throw TimeoutException('Timed out');
        }),
      );

      final notifier = BpmLookupNotifier(client);
      await notifier.lookupByBpm(170);

      expect(notifier.state.error, isNotNull);
      expect(notifier.state.error, contains('timed out'));
      expect(notifier.state.songs, isEmpty);
    });

    test('handles unexpected exceptions', () async {
      final client = GetSongBpmClient(
        apiKey: 'test-key',
        httpClient: MockClient((request) async {
          throw Exception('Something weird');
        }),
      );

      final notifier = BpmLookupNotifier(client);
      await notifier.lookupByBpm(170);

      expect(notifier.state.error, isNotNull);
      expect(notifier.state.error, contains('unexpected error'));
      expect(notifier.state.songs, isEmpty);
    });

    test('partial cache hit still works when API fails for uncached BPM',
        () async {
      // Cache BPM 170 (exact) but not 85 (half-time)
      await BpmCachePreferences.save(170, [
        const BpmSong(
          songId: 'cached',
          title: 'Cached',
          artistName: 'A',
          tempo: 170,
        ),
      ]);

      // API fails for the uncached BPM 85
      final client = _clientWithMock((request) async {
        return http.Response('Server Error', 500);
      });

      final notifier = BpmLookupNotifier(client);
      await notifier.lookupByBpm(170);

      // Should get an error since the API call for 85 failed
      expect(notifier.state.error, isNotNull);
      expect(notifier.state.songs, isEmpty);
    });
  });

  // -- BpmLookupNotifier.clear -------------------------------------------------

  group('BpmLookupNotifier.clear', () {
    test('resets state to default', () async {
      final client = _clientWithMock((request) async {
        return http.Response(
          _apiResponseBody([_apiSong()]),
          200,
        );
      });

      final notifier = BpmLookupNotifier(client);
      await notifier.lookupByBpm(170);
      expect(notifier.state.songs, isNotEmpty);

      notifier.clear();
      expect(notifier.state.songs, isEmpty);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
      expect(notifier.state.targetBpm, isNull);
    });
  });
}
