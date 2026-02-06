import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:running_playlist_ai/features/bpm_lookup/data/bpm_cache_preferences.dart';
import 'package:running_playlist_ai/features/bpm_lookup/data/getsongbpm_client.dart';
import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_song.dart';
import 'package:running_playlist_ai/features/bpm_lookup/providers/bpm_lookup_providers.dart';
import 'package:running_playlist_ai/features/playlist/providers/playlist_providers.dart';
import 'package:running_playlist_ai/features/run_plan/domain/run_plan.dart';
import 'package:running_playlist_ai/features/run_plan/providers/run_plan_providers.dart';
import 'package:running_playlist_ai/features/taste_profile/domain/taste_profile.dart';
import 'package:running_playlist_ai/features/taste_profile/providers/taste_profile_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Builds a valid API response body.
String _apiResponseBody(List<Map<String, dynamic>> songs) {
  return jsonEncode({'tempo': songs});
}

/// Creates a ProviderContainer with overrides for testing.
///
/// Pre-populates SharedPreferences with run plan and taste profile
/// data, then eagerly reads the providers to trigger their async
/// `_load()` calls. Waits for loading to complete.
Future<ProviderContainer> _createContainer({
  required GetSongBpmClient client,
  RunPlan? runPlan,
  TasteProfile? tasteProfile,
}) async {
  final mockValues = <String, Object>{};

  if (runPlan != null) {
    mockValues['current_run_plan'] =
        jsonEncode(runPlan.toJson());
  }
  if (tasteProfile != null) {
    mockValues['taste_profile'] =
        jsonEncode(tasteProfile.toJson());
  }

  SharedPreferences.setMockInitialValues(mockValues);

  // Create container and eagerly read providers to trigger their
  // constructors (which start async _load() from SharedPreferences)
  final container = ProviderContainer(
    overrides: [
      getSongBpmClientProvider.overrideWithValue(client),
    ],
  )
    ..read(runPlanNotifierProvider)
    ..read(tasteProfileNotifierProvider);

  // Allow the async _load() calls to complete
  await Future<void>.delayed(const Duration(milliseconds: 50));

  return container;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // -- PlaylistGenerationState ------------------------------------------------

  group('PlaylistGenerationState', () {
    test('idle state has no playlist, not loading, no error', () {
      const state = PlaylistGenerationState.idle();
      expect(state.playlist, isNull);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('loading state has isLoading true', () {
      const state = PlaylistGenerationState.loading();
      expect(state.isLoading, isTrue);
      expect(state.playlist, isNull);
      expect(state.error, isNull);
    });

    test('error state has error message', () {
      const state =
          PlaylistGenerationState.error('Something went wrong');
      expect(state.error, equals('Something went wrong'));
      expect(state.isLoading, isFalse);
      expect(state.playlist, isNull);
    });
  });

  // -- PlaylistGenerationNotifier: no run plan --------------------------------

  group('PlaylistGenerationNotifier without run plan', () {
    test('produces error when no run plan is saved', () async {
      final client = GetSongBpmClient(
        apiKey: 'test-key',
        httpClient: MockClient(
          (r) async => http.Response(_apiResponseBody([]), 200),
        ),
      );

      final container = await _createContainer(client: client);

      final notifier =
          container.read(playlistGenerationProvider.notifier);
      await notifier.generatePlaylist();

      final state = container.read(playlistGenerationProvider);
      expect(state.error, contains('No run plan'));
      expect(state.playlist, isNull);
    });
  });

  // -- PlaylistGenerationNotifier: successful generation ----------------------

  group('PlaylistGenerationNotifier successful generation', () {
    test('generates playlist from run plan and API songs',
        () async {
      final client = GetSongBpmClient(
        apiKey: 'test-key',
        httpClient: MockClient((request) async {
          final bpm = request.url.queryParameters['bpm'];
          return http.Response(
            _apiResponseBody([
              _apiSong(
                id: 'song-$bpm',
                title: 'Song at $bpm',
                tempo: bpm!,
              ),
            ]),
            200,
          );
        }),
      );

      final runPlan = RunPlan(
        type: RunType.steady,
        distanceKm: 5,
        paceMinPerKm: 6,
        name: 'Test Run',
        segments: [
          RunSegment(
            durationSeconds: 210,
            targetBpm: 170,
            label: 'Running',
          ),
        ],
      );

      final container = await _createContainer(
        client: client,
        runPlan: runPlan,
      );

      final notifier =
          container.read(playlistGenerationProvider.notifier);
      await notifier.generatePlaylist();

      final state = container.read(playlistGenerationProvider);
      expect(state.error, isNull);
      expect(state.isLoading, isFalse);
      expect(state.playlist, isNotNull);
      expect(state.playlist!.songs, isNotEmpty);
      expect(
        state.playlist!.runPlanName,
        equals('Test Run'),
      );
    });

    test('uses cache when songs are pre-cached', () async {
      var apiCallCount = 0;
      final client = GetSongBpmClient(
        apiKey: 'test-key',
        httpClient: MockClient((request) async {
          apiCallCount++;
          final bpm = request.url.queryParameters['bpm'];
          return http.Response(
            _apiResponseBody([
              _apiSong(id: 'api-$bpm', tempo: bpm!),
            ]),
            200,
          );
        }),
      );

      final runPlan = RunPlan(
        type: RunType.steady,
        distanceKm: 5,
        paceMinPerKm: 6,
        segments: [
          RunSegment(
            durationSeconds: 210,
            targetBpm: 170,
            label: 'Running',
          ),
        ],
      );

      final container = await _createContainer(
        client: client,
        runPlan: runPlan,
      );

      // Pre-populate cache for BPM 170 AFTER container
      // creation (which calls setMockInitialValues)
      await BpmCachePreferences.save(170, [
        const BpmSong(
          songId: 'cached',
          title: 'Cached Song',
          artistName: 'Cached Artist',
          tempo: 170,
        ),
      ]);

      final notifier =
          container.read(playlistGenerationProvider.notifier);
      await notifier.generatePlaylist();

      // BPM 170 was cached, so only half-time (85) hits API
      // (170 is cached, 85 is not, 340 > maxQueryBpm)
      expect(apiCallCount, equals(1));

      final state = container.read(playlistGenerationProvider);
      expect(state.playlist, isNotNull);
    });
  });

  // -- PlaylistGenerationNotifier: error handling ---

  group('PlaylistGenerationNotifier error handling', () {
    test('handles API error with user-friendly message',
        () async {
      final client = GetSongBpmClient(
        apiKey: 'test-key',
        httpClient: MockClient(
          (r) async => http.Response('Server Error', 500),
        ),
      );

      final runPlan = RunPlan(
        type: RunType.steady,
        distanceKm: 5,
        paceMinPerKm: 6,
        segments: [
          RunSegment(
            durationSeconds: 210,
            targetBpm: 170,
            label: 'Running',
          ),
        ],
      );

      final container = await _createContainer(
        client: client,
        runPlan: runPlan,
      );

      final notifier =
          container.read(playlistGenerationProvider.notifier);
      await notifier.generatePlaylist();

      final state = container.read(playlistGenerationProvider);
      expect(state.error, isNotNull);
      expect(state.error, contains('Could not fetch songs'));
      expect(state.playlist, isNull);
    });

    test('handles SocketException for no network', () async {
      final client = GetSongBpmClient(
        apiKey: 'test-key',
        httpClient: MockClient(
          (r) async =>
              throw const SocketException('No network'),
        ),
      );

      final runPlan = RunPlan(
        type: RunType.steady,
        distanceKm: 5,
        paceMinPerKm: 6,
        segments: [
          RunSegment(
            durationSeconds: 210,
            targetBpm: 170,
            label: 'Running',
          ),
        ],
      );

      final container = await _createContainer(
        client: client,
        runPlan: runPlan,
      );

      final notifier =
          container.read(playlistGenerationProvider.notifier);
      await notifier.generatePlaylist();

      final state = container.read(playlistGenerationProvider);
      expect(state.error, contains('No internet connection'));
    });
  });

  // -- PlaylistGenerationNotifier: clear ---

  group('PlaylistGenerationNotifier.clear', () {
    test('resets state to idle', () async {
      final client = GetSongBpmClient(
        apiKey: 'test-key',
        httpClient: MockClient((request) async {
          final bpm = request.url.queryParameters['bpm'];
          return http.Response(
            _apiResponseBody([
              _apiSong(id: 'song-$bpm', tempo: bpm!),
            ]),
            200,
          );
        }),
      );

      final runPlan = RunPlan(
        type: RunType.steady,
        distanceKm: 5,
        paceMinPerKm: 6,
        segments: [
          RunSegment(
            durationSeconds: 210,
            targetBpm: 170,
            label: 'Running',
          ),
        ],
      );

      final container = await _createContainer(
        client: client,
        runPlan: runPlan,
      );

      final notifier =
          container.read(playlistGenerationProvider.notifier);
      await notifier.generatePlaylist();

      // State should have a playlist
      expect(
        container.read(playlistGenerationProvider).playlist,
        isNotNull,
      );

      // Clear should reset to idle
      notifier.clear();
      final state = container.read(playlistGenerationProvider);
      expect(state.playlist, isNull);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });
  });
}
