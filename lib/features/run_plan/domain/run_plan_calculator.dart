/// Pure Dart computation layer for run plans. No Flutter dependencies.
///
/// Provides static methods for duration calculation, target BPM derivation,
/// and factory methods for creating run plans. Delegates cadence computation
/// to [StrideCalculator] from the stride feature.
library;

import 'package:running_playlist_ai/features/run_plan/domain/run_plan.dart';
import 'package:running_playlist_ai/features/stride/domain/stride_calculator.dart';

class RunPlanCalculator {
  /// Calculates total run duration in seconds.
  ///
  /// Formula: distance * pace * 60, rounded to the nearest integer.
  /// Returns 0 for zero or negative distance or pace.
  static int durationSeconds({
    required double distanceKm,
    required double paceMinPerKm,
  }) {
    if (distanceKm <= 0 || paceMinPerKm <= 0) return 0;
    return (distanceKm * paceMinPerKm * 60).round();
  }

  /// Derives target BPM (cadence) for playlist matching.
  ///
  /// If [calibratedCadence] is provided, it takes priority over the
  /// formula-based calculation. Otherwise, delegates to
  /// [StrideCalculator.calculateCadence].
  static double targetBpm({
    required double paceMinPerKm,
    double? heightCm,
    double? calibratedCadence,
  }) {
    if (calibratedCadence != null) return calibratedCadence;
    return StrideCalculator.calculateCadence(
      paceMinPerKm: paceMinPerKm,
      heightCm: heightCm,
    );
  }

  /// Creates a steady-pace run plan with a single segment.
  ///
  /// The segment duration is calculated from [distanceKm] and
  /// [paceMinPerKm]. The [targetBpm] is used for the segment's
  /// cadence target.
  static RunPlan createSteadyPlan({
    required double distanceKm,
    required double paceMinPerKm,
    required double targetBpm,
    String? name,
  }) {
    final duration = durationSeconds(
      distanceKm: distanceKm,
      paceMinPerKm: paceMinPerKm,
    );

    return RunPlan(
      type: RunType.steady,
      distanceKm: distanceKm,
      paceMinPerKm: paceMinPerKm,
      segments: [
        RunSegment(
          durationSeconds: duration,
          targetBpm: targetBpm,
        ),
      ],
      name: name,
      createdAt: DateTime.now(),
    );
  }

  /// Creates a warm-up/cool-down run plan with 3 segments.
  ///
  /// Segments: warm-up -> main -> cool-down.
  /// The main segment duration is the total run duration minus warm-up
  /// and cool-down, clamped to a minimum of 60 seconds.
  /// Warm-up and cool-down BPMs are derived from [targetBpm] using
  /// the respective fraction parameters (default 0.85).
  static RunPlan createWarmUpCoolDownPlan({
    required double distanceKm,
    required double paceMinPerKm,
    required double targetBpm,
    int warmUpSeconds = 300,
    int coolDownSeconds = 300,
    double warmUpBpmFraction = 0.85,
    double coolDownBpmFraction = 0.85,
    String? name,
  }) {
    final totalDuration = durationSeconds(
      distanceKm: distanceKm,
      paceMinPerKm: paceMinPerKm,
    );

    final mainDuration =
        (totalDuration - warmUpSeconds - coolDownSeconds).clamp(60, totalDuration);

    return RunPlan(
      type: RunType.warmUpCoolDown,
      distanceKm: distanceKm,
      paceMinPerKm: paceMinPerKm,
      segments: [
        RunSegment(
          durationSeconds: warmUpSeconds,
          targetBpm: (targetBpm * warmUpBpmFraction).roundToDouble(),
          label: 'Warm-up',
        ),
        RunSegment(
          durationSeconds: mainDuration,
          targetBpm: targetBpm,
          label: 'Main',
        ),
        RunSegment(
          durationSeconds: coolDownSeconds,
          targetBpm: (targetBpm * coolDownBpmFraction).roundToDouble(),
          label: 'Cool-down',
        ),
      ],
      name: name,
      createdAt: DateTime.now(),
    );
  }

  /// Creates an interval training plan with warm-up, work/rest pairs,
  /// and cool-down segments.
  ///
  /// Structure: [Warm-up, Work 1, Rest 1, ..., Work N, Rest N, Cool-down]
  /// Total segments: 2 + 2 * [intervalCount].
  ///
  /// Work segments use [targetBpm] unchanged. Rest segments use
  /// [targetBpm] * [restBpmFraction] (default 0.80). Warm-up and
  /// cool-down use their respective fraction parameters (default 0.85).
  static RunPlan createIntervalPlan({
    required double distanceKm,
    required double paceMinPerKm,
    required double targetBpm,
    required int intervalCount,
    required int workSeconds,
    required int restSeconds,
    int warmUpSeconds = 300,
    int coolDownSeconds = 300,
    double restBpmFraction = 0.80,
    double warmUpBpmFraction = 0.85,
    double coolDownBpmFraction = 0.85,
    String? name,
  }) {
    final segments = <RunSegment>[
      RunSegment(
        durationSeconds: warmUpSeconds,
        targetBpm: (targetBpm * warmUpBpmFraction).roundToDouble(),
        label: 'Warm-up',
      ),
    ];

    for (var i = 1; i <= intervalCount; i++) {
      segments.add(
        RunSegment(
          durationSeconds: workSeconds,
          targetBpm: targetBpm,
          label: 'Work $i',
        ),
      );
      segments.add(
        RunSegment(
          durationSeconds: restSeconds,
          targetBpm: (targetBpm * restBpmFraction).roundToDouble(),
          label: 'Rest $i',
        ),
      );
    }

    segments.add(
      RunSegment(
        durationSeconds: coolDownSeconds,
        targetBpm: (targetBpm * coolDownBpmFraction).roundToDouble(),
        label: 'Cool-down',
      ),
    );

    return RunPlan(
      type: RunType.interval,
      distanceKm: distanceKm,
      paceMinPerKm: paceMinPerKm,
      segments: segments,
      name: name,
      createdAt: DateTime.now(),
    );
  }
}
