import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/playlist_freshness/domain/playlist_freshness.dart';
import 'package:running_playlist_ai/features/playlist/domain/playlist.dart';
import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_song.dart';

void main() {
  group('FreshnessMode', () {
    test('has keepItFresh value', () {
      expect(FreshnessMode.keepItFresh, isNotNull);
    });

    test('has optimizeForTaste value', () {
      expect(FreshnessMode.optimizeForTaste, isNotNull);
    });

    test('has exactly 2 values', () {
      expect(FreshnessMode.values.length, 2);
    });
  });

  group('PlayHistory.freshnessPenalty', () {
    final now = DateTime(2026, 2, 8, 12, 0);

    test('returns 0 for never-played songs', () {
      final history = PlayHistory(entries: {});
      expect(history.freshnessPenalty('eminem|lose yourself', now: now), 0);
    });

    test('returns -8 for songs played 0-2 days ago', () {
      final history = PlayHistory(entries: {
        'eminem|lose yourself': now.subtract(const Duration(hours: 1)),
      });
      expect(history.freshnessPenalty('eminem|lose yourself', now: now), -8);

      // Also test at exactly 2 days
      final history2 = PlayHistory(entries: {
        'eminem|lose yourself': now.subtract(const Duration(days: 2)),
      });
      expect(history2.freshnessPenalty('eminem|lose yourself', now: now), -8);
    });

    test('returns -5 for songs played 3-6 days ago', () {
      final history = PlayHistory(entries: {
        'eminem|lose yourself': now.subtract(const Duration(days: 3)),
      });
      expect(history.freshnessPenalty('eminem|lose yourself', now: now), -5);

      final history2 = PlayHistory(entries: {
        'eminem|lose yourself': now.subtract(const Duration(days: 6)),
      });
      expect(history2.freshnessPenalty('eminem|lose yourself', now: now), -5);
    });

    test('returns -2 for songs played 7-13 days ago', () {
      final history = PlayHistory(entries: {
        'eminem|lose yourself': now.subtract(const Duration(days: 7)),
      });
      expect(history.freshnessPenalty('eminem|lose yourself', now: now), -2);

      final history2 = PlayHistory(entries: {
        'eminem|lose yourself': now.subtract(const Duration(days: 13)),
      });
      expect(history2.freshnessPenalty('eminem|lose yourself', now: now), -2);
    });

    test('returns 0 for songs played 14+ days ago', () {
      final history = PlayHistory(entries: {
        'eminem|lose yourself': now.subtract(const Duration(days: 14)),
      });
      expect(history.freshnessPenalty('eminem|lose yourself', now: now), 0);

      final history2 = PlayHistory(entries: {
        'eminem|lose yourself': now.subtract(const Duration(days: 28)),
      });
      expect(history2.freshnessPenalty('eminem|lose yourself', now: now), 0);
    });
  });

  group('PlayHistory.recordPlaylist', () {
    test('merges new song entries with existing map', () {
      final now = DateTime(2026, 2, 8, 12, 0);
      final existing = PlayHistory(entries: {
        'survivor|eye of the tiger': DateTime(2026, 2, 5),
      });

      final playlist = Playlist(
        songs: [
          PlaylistSong(
            title: 'Lose Yourself',
            artistName: 'Eminem',
            bpm: 170,
            matchType: BpmMatchType.exact,
            segmentLabel: 'Steady',
            segmentIndex: 0,
          ),
        ],
        totalDurationSeconds: 300,
        createdAt: now,
      );

      final updated = existing.recordPlaylist(playlist);

      // New entry added
      expect(updated.entries['eminem|lose yourself'], now);
      // Existing entry preserved
      expect(
        updated.entries['survivor|eye of the tiger'],
        DateTime(2026, 2, 5),
      );
    });

    test('uses playlist.createdAt as the played date', () {
      final createdAt = DateTime(2026, 2, 7, 14, 30);
      final playlist = Playlist(
        songs: [
          PlaylistSong(
            title: 'Run Boy Run',
            artistName: 'Woodkid',
            bpm: 160,
            matchType: BpmMatchType.exact,
            segmentLabel: 'Steady',
            segmentIndex: 0,
          ),
        ],
        totalDurationSeconds: 240,
        createdAt: createdAt,
      );

      final history = PlayHistory(entries: {}).recordPlaylist(playlist);
      expect(history.entries['woodkid|run boy run'], createdAt);
    });

    test('overrides existing entries for same song', () {
      final oldDate = DateTime(2026, 2, 1);
      final newDate = DateTime(2026, 2, 8);

      final existing = PlayHistory(entries: {
        'eminem|lose yourself': oldDate,
      });

      final playlist = Playlist(
        songs: [
          PlaylistSong(
            title: 'Lose Yourself',
            artistName: 'Eminem',
            bpm: 170,
            matchType: BpmMatchType.exact,
            segmentLabel: 'Steady',
            segmentIndex: 0,
          ),
        ],
        totalDurationSeconds: 300,
        createdAt: newDate,
      );

      final updated = existing.recordPlaylist(playlist);
      expect(updated.entries['eminem|lose yourself'], newDate);
    });
  });

  group('PlayHistory pruning', () {
    test('prunes entries older than 30 days on construction', () {
      final now = DateTime(2026, 2, 8, 12, 0);
      final history = PlayHistory(
        entries: {
          'eminem|lose yourself': now.subtract(const Duration(days: 31)),
          'survivor|eye of the tiger': now.subtract(const Duration(days: 5)),
        },
        now: now,
      );

      expect(history.entries.containsKey('eminem|lose yourself'), false);
      expect(history.entries.containsKey('survivor|eye of the tiger'), true);
    });

    test('keeps entries exactly 30 days old', () {
      final now = DateTime(2026, 2, 8, 12, 0);
      final history = PlayHistory(
        entries: {
          'eminem|lose yourself': now.subtract(const Duration(days: 30)),
        },
        now: now,
      );

      expect(history.entries.containsKey('eminem|lose yourself'), true);
    });
  });
}
