import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/run_plan/domain/run_plan.dart';
import 'package:running_playlist_ai/features/run_plan/domain/run_plan_calculator.dart';
import 'package:running_playlist_ai/features/stride/domain/stride_calculator.dart';

void main() {
  // ── durationSeconds ────────────────────────────────────────────────────

  group('RunPlanCalculator.durationSeconds', () {
    test('5 km at 6:00/km -> 1800 seconds', () {
      expect(
        RunPlanCalculator.durationSeconds(
            distanceKm: 5.0, paceMinPerKm: 6.0),
        equals(1800),
      );
    });

    test('10 km at 5:30/km -> 3300 seconds', () {
      expect(
        RunPlanCalculator.durationSeconds(
            distanceKm: 10.0, paceMinPerKm: 5.5),
        equals(3300),
      );
    });

    test('half marathon at 5:00/km -> 6330 seconds', () {
      expect(
        RunPlanCalculator.durationSeconds(
            distanceKm: 21.1, paceMinPerKm: 5.0),
        equals(6330),
      );
    });

    test('marathon at 5:00/km -> 12659 seconds (rounding)', () {
      expect(
        RunPlanCalculator.durationSeconds(
            distanceKm: 42.195, paceMinPerKm: 5.0),
        equals(12659),
      );
    });

    test('zero distance -> 0', () {
      expect(
        RunPlanCalculator.durationSeconds(
            distanceKm: 0.0, paceMinPerKm: 5.0),
        equals(0),
      );
    });

    test('zero pace -> 0', () {
      expect(
        RunPlanCalculator.durationSeconds(
            distanceKm: 5.0, paceMinPerKm: 0.0),
        equals(0),
      );
    });

    test('negative distance -> 0', () {
      expect(
        RunPlanCalculator.durationSeconds(
            distanceKm: -1.0, paceMinPerKm: 5.0),
        equals(0),
      );
    });

    test('negative pace -> 0', () {
      expect(
        RunPlanCalculator.durationSeconds(
            distanceKm: 5.0, paceMinPerKm: -2.0),
        equals(0),
      );
    });
  });

  // ── targetBpm ──────────────────────────────────────────────────────────

  group('RunPlanCalculator.targetBpm', () {
    test('delegates to StrideCalculator with height', () {
      final expected = StrideCalculator.calculateCadence(
        paceMinPerKm: 5.0,
        heightCm: 170,
      );
      expect(
        RunPlanCalculator.targetBpm(
            paceMinPerKm: 5.0, heightCm: 170),
        equals(expected),
      );
    });

    test('delegates to StrideCalculator without height', () {
      final expected = StrideCalculator.calculateCadence(
        paceMinPerKm: 6.0,
      );
      expect(
        RunPlanCalculator.targetBpm(paceMinPerKm: 6.0),
        equals(expected),
      );
    });

    test('calibrated cadence overrides formula', () {
      expect(
        RunPlanCalculator.targetBpm(
          paceMinPerKm: 5.0,
          calibratedCadence: 175.0,
        ),
        equals(175.0),
      );
    });

    test('calibrated cadence overrides even with height', () {
      expect(
        RunPlanCalculator.targetBpm(
          paceMinPerKm: 5.0,
          heightCm: 170,
          calibratedCadence: 162.0,
        ),
        equals(162.0),
      );
    });
  });

  // ── createSteadyPlan ──────────────────────────────────────────────────

  group('RunPlanCalculator.createSteadyPlan', () {
    test('creates plan with RunType.steady', () {
      final plan = RunPlanCalculator.createSteadyPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
      );
      expect(plan.type, equals(RunType.steady));
    });

    test('creates plan with exactly 1 segment', () {
      final plan = RunPlanCalculator.createSteadyPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
      );
      expect(plan.segments.length, equals(1));
    });

    test('segment has correct durationSeconds', () {
      final plan = RunPlanCalculator.createSteadyPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
      );
      expect(plan.segments.first.durationSeconds, equals(1800));
    });

    test('segment has correct targetBpm', () {
      final plan = RunPlanCalculator.createSteadyPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
      );
      expect(plan.segments.first.targetBpm, equals(170.0));
    });

    test('plan stores distanceKm and paceMinPerKm', () {
      final plan = RunPlanCalculator.createSteadyPlan(
        distanceKm: 10.0,
        paceMinPerKm: 5.5,
        targetBpm: 175.0,
      );
      expect(plan.distanceKm, equals(10.0));
      expect(plan.paceMinPerKm, equals(5.5));
    });

    test('plan stores optional name', () {
      final plan = RunPlanCalculator.createSteadyPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
        name: 'Morning 5K',
      );
      expect(plan.name, equals('Morning 5K'));
    });

    test('plan has createdAt timestamp', () {
      final before = DateTime.now();
      final plan = RunPlanCalculator.createSteadyPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
      );
      final after = DateTime.now();
      expect(plan.createdAt, isNotNull);
      expect(
        plan.createdAt!.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        plan.createdAt!.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('totalDurationSeconds returns sum of segments', () {
      final plan = RunPlanCalculator.createSteadyPlan(
        distanceKm: 10.0,
        paceMinPerKm: 5.5,
        targetBpm: 175.0,
      );
      expect(plan.totalDurationSeconds, equals(3300));
    });

    test('totalDurationMinutes returns duration in minutes', () {
      final plan = RunPlanCalculator.createSteadyPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
      );
      expect(plan.totalDurationMinutes, equals(30.0));
    });
  });

  // ── RunPlan/RunSegment serialization ───────────────────────────────────

  group('RunPlan serialization', () {
    test('toJson -> fromJson round-trip preserves all fields', () {
      final original = RunPlanCalculator.createSteadyPlan(
        distanceKm: 10.0,
        paceMinPerKm: 5.5,
        targetBpm: 175.0,
        name: 'Morning Run',
      );
      final json = original.toJson();
      final restored = RunPlan.fromJson(json);
      expect(restored.type, equals(original.type));
      expect(restored.distanceKm, equals(original.distanceKm));
      expect(restored.paceMinPerKm, equals(original.paceMinPerKm));
      expect(restored.name, equals(original.name));
      expect(restored.segments.length, equals(original.segments.length));
      expect(
        restored.segments.first.durationSeconds,
        equals(original.segments.first.durationSeconds),
      );
      expect(
        restored.segments.first.targetBpm,
        equals(original.segments.first.targetBpm),
      );
      expect(
        restored.createdAt?.toIso8601String(),
        equals(original.createdAt?.toIso8601String()),
      );
    });

    test('RunType serializes by name', () {
      final plan = RunPlanCalculator.createSteadyPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
      );
      final json = plan.toJson();
      expect(json['type'], equals('steady'));
    });

    test('RunType.warmUpCoolDown serializes correctly', () {
      final plan = RunPlan(
        type: RunType.warmUpCoolDown,
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        segments: [],
      );
      final json = plan.toJson();
      expect(json['type'], equals('warmUpCoolDown'));
      final restored = RunPlan.fromJson(json);
      expect(restored.type, equals(RunType.warmUpCoolDown));
    });

    test('RunType.interval serializes correctly', () {
      final plan = RunPlan(
        type: RunType.interval,
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        segments: [],
      );
      final json = plan.toJson();
      expect(json['type'], equals('interval'));
      final restored = RunPlan.fromJson(json);
      expect(restored.type, equals(RunType.interval));
    });

    test('null optional fields omitted from JSON', () {
      final plan = RunPlan(
        type: RunType.steady,
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        segments: [
          RunSegment(durationSeconds: 1800, targetBpm: 170.0),
        ],
      );
      final json = plan.toJson();
      expect(json.containsKey('name'), isFalse);
      expect(json.containsKey('createdAt'), isFalse);
    });

    test('null segment label omitted from JSON', () {
      final segment = RunSegment(durationSeconds: 1800, targetBpm: 170.0);
      final json = segment.toJson();
      expect(json.containsKey('label'), isFalse);
    });

    test('segment with label serializes correctly', () {
      final segment = RunSegment(
        durationSeconds: 300,
        targetBpm: 160.0,
        label: 'Warm-up',
      );
      final json = segment.toJson();
      expect(json['label'], equals('Warm-up'));
      final restored = RunSegment.fromJson(json);
      expect(restored.label, equals('Warm-up'));
    });
  });

  // ── formatDuration ────────────────────────────────────────────────────

  group('formatDuration', () {
    test('1800 -> "30:00"', () {
      expect(formatDuration(1800), equals('30:00'));
    });

    test('3661 -> "1:01:01"', () {
      expect(formatDuration(3661), equals('1:01:01'));
    });

    test('90 -> "1:30"', () {
      expect(formatDuration(90), equals('1:30'));
    });

    test('0 -> "0:00"', () {
      expect(formatDuration(0), equals('0:00'));
    });

    test('3600 -> "1:00:00"', () {
      expect(formatDuration(3600), equals('1:00:00'));
    });

    test('59 -> "0:59"', () {
      expect(formatDuration(59), equals('0:59'));
    });

    test('12659 -> "3:30:59"', () {
      expect(formatDuration(12659), equals('3:30:59'));
    });
  });
}
