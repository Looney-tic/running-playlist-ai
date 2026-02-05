/// Pure Dart half/double-time BPM matching logic. No Flutter dependencies.
///
/// Given a target running cadence BPM, [BpmMatcher] computes which BPM
/// values to query from the GetSongBPM API to find songs that work at
/// exact tempo, half-time, or double-time.
library;

import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_song.dart';

/// Computes BPM values to query for half/double-time matching.
class BpmMatcher {
  /// The maximum BPM value the API is likely to have songs for.
  static const maxQueryBpm = 300;

  /// The minimum BPM value that makes sense to query.
  static const minQueryBpm = 40;

  /// Returns BPM values to query with their match types.
  ///
  /// For a target BPM of 170:
  /// - Exact: query 170
  /// - Half-time: query 85 (170 ~/ 2) -- only if >= [minQueryBpm]
  /// - Double-time: query 340 (170 * 2) -- only if <= [maxQueryBpm]
  ///
  /// ```dart
  /// BpmMatcher.bpmQueries(170); // {170: exact, 85: halfTime}
  /// BpmMatcher.bpmQueries(85);  // {85: exact, 42: halfTime, 170: doubleTime}
  /// BpmMatcher.bpmQueries(120); // {120: exact, 60: halfTime, 240: doubleTime}
  /// ```
  static Map<int, BpmMatchType> bpmQueries(int targetBpm) {
    final queries = <int, BpmMatchType>{
      targetBpm: BpmMatchType.exact,
    };

    final halfBpm = targetBpm ~/ 2;
    if (halfBpm >= minQueryBpm) {
      queries[halfBpm] = BpmMatchType.halfTime;
    }

    final doubleBpm = targetBpm * 2;
    if (doubleBpm <= maxQueryBpm) {
      queries[doubleBpm] = BpmMatchType.doubleTime;
    }

    return queries;
  }
}
