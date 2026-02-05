import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_song.dart';
import 'package:running_playlist_ai/features/playlist/data/playlist_history_preferences.dart';
import 'package:running_playlist_ai/features/playlist/domain/playlist.dart';
import 'package:shared_preferences/shared_preferences.dart';

Playlist _playlist({
  String id = '1',
  String name = 'Test Run',
  double distanceKm = 5.0,
  double paceMinPerKm = 6.0,
}) =>
    Playlist(
      id: id,
      songs: const [
        PlaylistSong(
          title: 'Song A',
          artistName: 'Artist A',
          bpm: 170,
          matchType: BpmMatchType.exact,
          segmentLabel: 'Running',
          segmentIndex: 0,
        ),
      ],
      runPlanName: name,
      totalDurationSeconds: 1800,
      createdAt: DateTime.utc(2026, 2, 5),
      distanceKm: distanceKm,
      paceMinPerKm: paceMinPerKm,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PlaylistHistoryPreferences', () {
    test('load returns null when nothing is stored', () async {
      final result = await PlaylistHistoryPreferences.load();
      expect(result, isNull);
    });

    test('save and load round-trip preserves playlists', () async {
      final playlists = [
        _playlist(id: '1', name: 'Run 1'),
        _playlist(id: '2', name: 'Run 2'),
      ];

      await PlaylistHistoryPreferences.save(playlists);
      final loaded = await PlaylistHistoryPreferences.load();

      expect(loaded, isNotNull);
      expect(loaded!.length, equals(2));
      expect(loaded[0].id, equals('1'));
      expect(loaded[0].runPlanName, equals('Run 1'));
      expect(loaded[0].distanceKm, equals(5.0));
      expect(loaded[0].paceMinPerKm, equals(6.0));
      expect(loaded[0].songs.length, equals(1));
      expect(loaded[1].id, equals('2'));
    });

    test('save trims to maxHistorySize', () async {
      final playlists = List.generate(
        60,
        (i) => _playlist(id: '$i', name: 'Run $i'),
      );

      await PlaylistHistoryPreferences.save(playlists);
      final loaded = await PlaylistHistoryPreferences.load();

      expect(loaded!.length, equals(50));
      expect(loaded.first.id, equals('0'));
      expect(loaded.last.id, equals('49'));
    });

    test('clear removes stored data', () async {
      await PlaylistHistoryPreferences.save([_playlist()]);
      await PlaylistHistoryPreferences.clear();
      final result = await PlaylistHistoryPreferences.load();
      expect(result, isNull);
    });
  });
}
