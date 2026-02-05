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
}
