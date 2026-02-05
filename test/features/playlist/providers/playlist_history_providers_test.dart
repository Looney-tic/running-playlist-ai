import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_song.dart';
import 'package:running_playlist_ai/features/playlist/domain/playlist.dart';
import 'package:running_playlist_ai/features/playlist/providers/playlist_history_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Playlist _playlist({
  String id = '1',
  String name = 'Test Run',
}) =>
    Playlist(
      id: id,
      songs: const [
        PlaylistSong(
          title: 'Song',
          artistName: 'Artist',
          bpm: 170,
          matchType: BpmMatchType.exact,
          segmentLabel: 'Running',
          segmentIndex: 0,
        ),
      ],
      runPlanName: name,
      totalDurationSeconds: 1800,
      createdAt: DateTime.utc(2026, 2, 5),
      distanceKm: 5.0,
      paceMinPerKm: 6.0,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PlaylistHistoryNotifier', () {
    test('starts with empty list', () {
      final container = ProviderContainer();
      final state = container.read(playlistHistoryProvider);
      expect(state, isEmpty);
    });

    test('addPlaylist prepends to list and persists', () async {
      final container = ProviderContainer();
      final notifier =
          container.read(playlistHistoryProvider.notifier);

      await notifier.addPlaylist(_playlist(id: '1', name: 'Run 1'));
      await notifier.addPlaylist(_playlist(id: '2', name: 'Run 2'));

      final state = container.read(playlistHistoryProvider);
      expect(state.length, equals(2));
      expect(state[0].id, equals('2'));
      expect(state[1].id, equals('1'));
    });

    test('deletePlaylist removes by id and persists', () async {
      final container = ProviderContainer();
      final notifier =
          container.read(playlistHistoryProvider.notifier);

      await notifier.addPlaylist(_playlist(id: '1'));
      await notifier.addPlaylist(_playlist(id: '2'));
      await notifier.deletePlaylist('1');

      final state = container.read(playlistHistoryProvider);
      expect(state.length, equals(1));
      expect(state[0].id, equals('2'));
    });

    test('loads persisted playlists on construction', () async {
      // First: save some playlists via a notifier
      final container1 = ProviderContainer();
      final notifier1 =
          container1.read(playlistHistoryProvider.notifier);
      await notifier1.addPlaylist(_playlist(id: '1', name: 'Saved'));

      // Second: create new container (simulates app restart)
      final container2 = ProviderContainer();
      // Read the notifier to trigger construction
      container2.read(playlistHistoryProvider.notifier);
      // Wait for async _load() to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container2.read(playlistHistoryProvider);
      expect(state.length, equals(1));
      expect(state[0].runPlanName, equals('Saved'));
    });
  });
}
