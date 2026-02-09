/// BPM compatibility classification relative to a user's running cadence.
///
/// Used to show visual indicators on running song cards:
/// - [match] (green): exact, half-time, or double-time BPM
/// - [close] (amber): within 5% of a target BPM
/// - [none] (gray): no meaningful BPM relationship
enum BpmCompatibility {
  /// Exact match to cadence, half-time, or double-time.
  match,

  /// Within 5% of cadence, half-time, or double-time.
  close,

  /// No meaningful BPM relationship to cadence.
  none,
}

/// Computes how well [songBpm] matches the runner's [cadence].
///
/// Returns [BpmCompatibility.none] when [songBpm] is null (unknown BPM).
/// Checks exact match first, then 5% tolerance, against the cadence
/// and its half-time and double-time variants.
BpmCompatibility bpmCompatibility({
  required int? songBpm,
  required int cadence,
}) {
  if (songBpm == null) return BpmCompatibility.none;

  final targets = [cadence, cadence ~/ 2, cadence * 2];

  // First pass: check exact match against each target.
  for (final target in targets) {
    if (songBpm == target) return BpmCompatibility.match;
  }

  // Second pass: check within 5% tolerance of each target.
  for (final target in targets) {
    final tolerance = (target * 0.05).ceil();
    if ((songBpm - target).abs() <= tolerance) return BpmCompatibility.close;
  }

  return BpmCompatibility.none;
}
