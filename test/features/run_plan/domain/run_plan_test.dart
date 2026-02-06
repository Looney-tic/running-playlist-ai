import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/run_plan/domain/run_plan.dart';

void main() {
  // -- RunType enum -----------------------------------------------------------

  group('RunType', () {
    test('has exactly 3 values', () {
      expect(RunType.values.length, equals(3));
    });

    test('fromJson deserializes each value', () {
      for (final type in RunType.values) {
        expect(RunType.fromJson(type.name), equals(type));
      }
    });

    test('fromJson with unknown string falls back to steady', () {
      expect(
        RunType.fromJson('fartlek'),
        equals(RunType.steady),
      );
    });

    test('fromJson with empty string falls back to steady', () {
      expect(
        RunType.fromJson(''),
        equals(RunType.steady),
      );
    });
  });

  // -- RunPlan.fromJson with unknown RunType ----------------------------------

  group('RunPlan.fromJson enum fallback safety', () {
    test('unknown RunType falls back to steady', () {
      final json = {
        'type': 'fartlek',
        'distanceKm': 5.0,
        'paceMinPerKm': 5.5,
        'segments': [
          {'durationSeconds': 1800, 'targetBpm': 170.0},
        ],
      };
      final plan = RunPlan.fromJson(json);
      expect(plan.type, equals(RunType.steady));
      expect(plan.distanceKm, equals(5.0));
    });

    test('valid RunType still works', () {
      final json = {
        'type': 'interval',
        'distanceKm': 5.0,
        'paceMinPerKm': 5.5,
        'segments': [
          {'durationSeconds': 1800, 'targetBpm': 170.0},
        ],
      };
      final plan = RunPlan.fromJson(json);
      expect(plan.type, equals(RunType.interval));
    });
  });

  // -- RunPlan serialization --------------------------------------------------

  group('RunPlan serialization', () {
    test('toJson -> fromJson round-trip preserves all fields', () {
      final original = RunPlan(
        type: RunType.warmUpCoolDown,
        distanceKm: 10.0,
        paceMinPerKm: 6.0,
        segments: [
          const RunSegment(
            durationSeconds: 300,
            targetBpm: 150.0,
            label: 'Warm-up',
          ),
          const RunSegment(
            durationSeconds: 2400,
            targetBpm: 170.0,
            label: 'Main',
          ),
          const RunSegment(
            durationSeconds: 300,
            targetBpm: 150.0,
            label: 'Cool-down',
          ),
        ],
        name: 'Morning Run',
      );
      final json = original.toJson();
      final restored = RunPlan.fromJson(json);
      expect(restored.type, equals(original.type));
      expect(restored.distanceKm, equals(original.distanceKm));
      expect(restored.paceMinPerKm, equals(original.paceMinPerKm));
      expect(restored.segments.length, equals(3));
      expect(restored.name, equals('Morning Run'));
    });
  });
}
