/// Pure Dart domain model for playlist freshness tracking. No Flutter
/// dependencies.
///
/// [PlayHistory] tracks when songs were last played and computes
/// time-decayed freshness penalties. [FreshnessMode] controls whether
/// the playlist generator prioritises variety or taste quality.
library;

import 'package:running_playlist_ai/features/playlist/domain/playlist.dart';

/// Controls playlist generation strategy for song repetition.
///
/// [keepItFresh] applies freshness penalties to recently-played songs,
/// reducing repetition across consecutive runs. [optimizeForTaste]
/// disables freshness penalties, always picking the highest-scoring songs.
enum FreshnessMode {
  /// Apply freshness penalties to recently-played songs.
  keepItFresh,

  /// Ignore play history; always pick highest-scoring songs.
  optimizeForTaste,
}

/// Immutable play history holding the last-played timestamp for each song.
///
/// Entries older than 30 days are pruned on construction so the history
/// does not grow unbounded. The [freshnessPenalty] method returns a
/// negative int score adjustment based on how recently a song was played:
///
/// | Days since last played | Penalty |
/// |------------------------|---------|
/// | Never played           |  0      |
/// | 0-2 days               | -8      |
/// | 3-6 days               | -5      |
/// | 7-13 days              | -2      |
/// | 14+ days               |  0      |
class PlayHistory {
  /// Creates a [PlayHistory], pruning any entries older than 30 days.
  ///
  /// The optional [now] parameter allows injecting a fixed time for
  /// deterministic testing. Defaults to [DateTime.now].
  PlayHistory({
    required Map<String, DateTime> entries,
    DateTime? now,
  }) : entries = _prune(entries, now ?? DateTime.now());

  /// Song key -> last-played timestamp. Pruned to the last 30 days.
  final Map<String, DateTime> entries;

  static const _pruneThresholdDays = 30;

  static Map<String, DateTime> _prune(
    Map<String, DateTime> raw,
    DateTime now,
  ) {
    final cutoff = now.subtract(const Duration(days: _pruneThresholdDays));
    return Map.fromEntries(
      raw.entries.where((e) => !e.value.isBefore(cutoff)),
    );
  }

  /// Returns a freshness penalty score for the given [songKey].
  ///
  /// Songs not in the history return 0 (no penalty). Recently-played
  /// songs receive increasingly harsh penalties so the playlist generator
  /// can down-rank them in favour of fresh picks.
  int freshnessPenalty(String songKey, {DateTime? now}) {
    final lastPlayed = entries[songKey];
    if (lastPlayed == null) return 0;

    final daysSince = (now ?? DateTime.now()).difference(lastPlayed).inDays;

    if (daysSince <= 2) return -8;
    if (daysSince <= 6) return -5;
    if (daysSince <= 13) return -2;
    return 0;
  }

  /// Records all songs in [playlist] as played at [playlist.createdAt].
  ///
  /// Returns a new [PlayHistory] with merged entries. Existing entries
  /// for the same song key are overwritten with the new timestamp.
  PlayHistory recordPlaylist(Playlist playlist) {
    final merged = Map<String, DateTime>.from(entries);
    for (final song in playlist.songs) {
      merged[song.lookupKey] = playlist.createdAt;
    }
    return PlayHistory(entries: merged);
  }
}
