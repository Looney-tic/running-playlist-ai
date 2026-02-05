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

  // ── createWarmUpCoolDownPlan ──────────────────────────────────────────

  group('RunPlanCalculator.createWarmUpCoolDownPlan', () {
    test('creates plan with RunType.warmUpCoolDown', () {
      final plan = RunPlanCalculator.createWarmUpCoolDownPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
      );
      expect(plan.type, equals(RunType.warmUpCoolDown));
    });

    test('creates plan with exactly 3 segments', () {
      final plan = RunPlanCalculator.createWarmUpCoolDownPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
      );
      expect(plan.segments.length, equals(3));
    });

    test('5km @ 6:00/km, 170 BPM -> warm-up 300s @ 145 BPM', () {
      final plan = RunPlanCalculator.createWarmUpCoolDownPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
      );
      final warmUp = plan.segments[0];
      expect(warmUp.durationSeconds, equals(300));
      expect(warmUp.targetBpm, equals(145.0));
      expect(warmUp.label, equals('Warm-up'));
    });

    test('5km @ 6:00/km, 170 BPM -> main 1200s @ 170 BPM', () {
      final plan = RunPlanCalculator.createWarmUpCoolDownPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
      );
      final main = plan.segments[1];
      // Total = 1800s, main = 1800 - 300 - 300 = 1200
      expect(main.durationSeconds, equals(1200));
      expect(main.targetBpm, equals(170.0));
      expect(main.label, equals('Main'));
    });

    test('5km @ 6:00/km, 170 BPM -> cool-down 300s @ 145 BPM', () {
      final plan = RunPlanCalculator.createWarmUpCoolDownPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
      );
      final coolDown = plan.segments[2];
      expect(coolDown.durationSeconds, equals(300));
      expect(coolDown.targetBpm, equals(145.0));
      expect(coolDown.label, equals('Cool-down'));
    });

    test('custom warm-up and cool-down durations', () {
      final plan = RunPlanCalculator.createWarmUpCoolDownPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
        warmUpSeconds: 600,
        coolDownSeconds: 600,
      );
      expect(plan.segments[0].durationSeconds, equals(600));
      // Main = 1800 - 600 - 600 = 600
      expect(plan.segments[1].durationSeconds, equals(600));
      expect(plan.segments[2].durationSeconds, equals(600));
    });

    test('short run clamps main segment to 60s minimum', () {
      // 1km @ 5:00/km = 300s total, warmUp=180+coolDown=180 = 360 > 300
      final plan = RunPlanCalculator.createWarmUpCoolDownPlan(
        distanceKm: 1.0,
        paceMinPerKm: 5.0,
        targetBpm: 170.0,
        warmUpSeconds: 180,
        coolDownSeconds: 180,
      );
      expect(plan.segments[1].durationSeconds, equals(60));
    });

    test('plan stores distanceKm and paceMinPerKm', () {
      final plan = RunPlanCalculator.createWarmUpCoolDownPlan(
        distanceKm: 10.0,
        paceMinPerKm: 5.5,
        targetBpm: 175.0,
      );
      expect(plan.distanceKm, equals(10.0));
      expect(plan.paceMinPerKm, equals(5.5));
    });

    test('plan stores optional name', () {
      final plan = RunPlanCalculator.createWarmUpCoolDownPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
        name: 'Morning warm-up run',
      );
      expect(plan.name, equals('Morning warm-up run'));
    });

    test('plan has createdAt timestamp', () {
      final before = DateTime.now();
      final plan = RunPlanCalculator.createWarmUpCoolDownPlan(
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

    test('totalDurationSeconds equals sum of all segments', () {
      final plan = RunPlanCalculator.createWarmUpCoolDownPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
      );
      final segmentSum = plan.segments.fold(
        0,
        (sum, s) => sum + s.durationSeconds,
      );
      expect(plan.totalDurationSeconds, equals(segmentSum));
      // 300 + 1200 + 300 = 1800
      expect(plan.totalDurationSeconds, equals(1800));
    });

    test('warm-up BPM fraction applied correctly with roundToDouble', () {
      // 160 * 0.85 = 136.0 (exact)
      final plan = RunPlanCalculator.createWarmUpCoolDownPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 160.0,
      );
      expect(plan.segments[0].targetBpm, equals(136.0));
    });

    test('custom BPM fractions override defaults', () {
      final plan = RunPlanCalculator.createWarmUpCoolDownPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
        warmUpBpmFraction: 0.75,
        coolDownBpmFraction: 0.70,
      );
      // 170 * 0.75 = 127.5 -> roundToDouble() = 128.0
      expect(plan.segments[0].targetBpm, equals(128.0));
      // 170 * 0.70 = 119.0 (exact)
      expect(plan.segments[2].targetBpm, equals(119.0));
    });

    test('JSON round-trip preserves all fields', () {
      final original = RunPlanCalculator.createWarmUpCoolDownPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
        name: 'Test round-trip',
      );
      final json = original.toJson();
      final restored = RunPlan.fromJson(json);
      expect(restored.type, equals(RunType.warmUpCoolDown));
      expect(restored.distanceKm, equals(original.distanceKm));
      expect(restored.paceMinPerKm, equals(original.paceMinPerKm));
      expect(restored.name, equals(original.name));
      expect(restored.segments.length, equals(3));
      for (var i = 0; i < 3; i++) {
        expect(
          restored.segments[i].durationSeconds,
          equals(original.segments[i].durationSeconds),
        );
        expect(
          restored.segments[i].targetBpm,
          equals(original.segments[i].targetBpm),
        );
        expect(
          restored.segments[i].label,
          equals(original.segments[i].label),
        );
      }
      expect(
        restored.createdAt?.toIso8601String(),
        equals(original.createdAt?.toIso8601String()),
      );
    });

    test('clamped main does not affect warm-up and cool-down segments', () {
      // 1km @ 5:00/km = 300s, warmUp=180, coolDown=180 -> main clamped to 60
      final plan = RunPlanCalculator.createWarmUpCoolDownPlan(
        distanceKm: 1.0,
        paceMinPerKm: 5.0,
        targetBpm: 170.0,
        warmUpSeconds: 180,
        coolDownSeconds: 180,
      );
      expect(plan.segments[0].durationSeconds, equals(180));
      expect(plan.segments[0].label, equals('Warm-up'));
      expect(plan.segments[2].durationSeconds, equals(180));
      expect(plan.segments[2].label, equals('Cool-down'));
    });
  });

  // ── createIntervalPlan ──────────────────────────────────────────────

  group('RunPlanCalculator.createIntervalPlan', () {
    test('creates plan with RunType.interval', () {
      final plan = RunPlanCalculator.createIntervalPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
        intervalCount: 4,
        workSeconds: 120,
        restSeconds: 60,
      );
      expect(plan.type, equals(RunType.interval));
    });

    test('4 intervals -> 10 segments (1+4+4+1)', () {
      final plan = RunPlanCalculator.createIntervalPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
        intervalCount: 4,
        workSeconds: 120,
        restSeconds: 60,
      );
      expect(plan.segments.length, equals(10));
    });

    test('3 intervals -> 8 segments (1+3+3+1)', () {
      final plan = RunPlanCalculator.createIntervalPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
        intervalCount: 3,
        workSeconds: 90,
        restSeconds: 90,
      );
      expect(plan.segments.length, equals(8));
    });

    test('warm-up segment is first with correct BPM', () {
      final plan = RunPlanCalculator.createIntervalPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
        intervalCount: 4,
        workSeconds: 120,
        restSeconds: 60,
      );
      final warmUp = plan.segments[0];
      expect(warmUp.durationSeconds, equals(300));
      expect(warmUp.targetBpm, equals(145.0));
      expect(warmUp.label, equals('Warm-up'));
    });

    test('cool-down segment is last with correct BPM', () {
      final plan = RunPlanCalculator.createIntervalPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
        intervalCount: 4,
        workSeconds: 120,
        restSeconds: 60,
      );
      final coolDown = plan.segments.last;
      expect(coolDown.durationSeconds, equals(300));
      expect(coolDown.targetBpm, equals(145.0));
      expect(coolDown.label, equals('Cool-down'));
    });

    test('work segments have target BPM and correct labels', () {
      final plan = RunPlanCalculator.createIntervalPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
        intervalCount: 4,
        workSeconds: 120,
        restSeconds: 60,
      );
      // Work segments are at indices 1, 3, 5, 7
      for (var i = 0; i < 4; i++) {
        final work = plan.segments[1 + i * 2];
        expect(work.durationSeconds, equals(120));
        expect(work.targetBpm, equals(170.0));
        expect(work.label, equals('Work ${i + 1}'));
      }
    });

    test('rest segments have 80% BPM and correct labels', () {
      final plan = RunPlanCalculator.createIntervalPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
        intervalCount: 4,
        workSeconds: 120,
        restSeconds: 60,
      );
      // Rest segments are at indices 2, 4, 6, 8
      // 170 * 0.80 = 136.0
      for (var i = 0; i < 4; i++) {
        final rest = plan.segments[2 + i * 2];
        expect(rest.durationSeconds, equals(60));
        expect(rest.targetBpm, equals(136.0));
        expect(rest.label, equals('Rest ${i + 1}'));
      }
    });

    test('plan stores distanceKm and paceMinPerKm', () {
      final plan = RunPlanCalculator.createIntervalPlan(
        distanceKm: 10.0,
        paceMinPerKm: 5.5,
        targetBpm: 175.0,
        intervalCount: 3,
        workSeconds: 90,
        restSeconds: 90,
      );
      expect(plan.distanceKm, equals(10.0));
      expect(plan.paceMinPerKm, equals(5.5));
    });

    test('plan stores optional name', () {
      final plan = RunPlanCalculator.createIntervalPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
        intervalCount: 4,
        workSeconds: 120,
        restSeconds: 60,
        name: 'Speed intervals',
      );
      expect(plan.name, equals('Speed intervals'));
    });

    test('plan has createdAt timestamp', () {
      final before = DateTime.now();
      final plan = RunPlanCalculator.createIntervalPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
        intervalCount: 4,
        workSeconds: 120,
        restSeconds: 60,
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

    test('totalDurationSeconds equals warmUp + N*(work+rest) + coolDown', () {
      final plan = RunPlanCalculator.createIntervalPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
        intervalCount: 4,
        workSeconds: 120,
        restSeconds: 60,
      );
      // 300 + 4*(120+60) + 300 = 300 + 720 + 300 = 1320
      expect(plan.totalDurationSeconds, equals(1320));
    });

    test('custom warm-up and cool-down durations', () {
      final plan = RunPlanCalculator.createIntervalPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
        intervalCount: 2,
        workSeconds: 120,
        restSeconds: 60,
        warmUpSeconds: 600,
        coolDownSeconds: 600,
      );
      expect(plan.segments[0].durationSeconds, equals(600));
      expect(plan.segments.last.durationSeconds, equals(600));
    });

    test('custom BPM fractions override defaults', () {
      final plan = RunPlanCalculator.createIntervalPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
        intervalCount: 2,
        workSeconds: 120,
        restSeconds: 60,
        warmUpBpmFraction: 0.75,
        coolDownBpmFraction: 0.70,
        restBpmFraction: 0.60,
      );
      // Warm-up: 170 * 0.75 = 127.5 -> 128.0
      expect(plan.segments[0].targetBpm, equals(128.0));
      // Cool-down: 170 * 0.70 = 119.0
      expect(plan.segments.last.targetBpm, equals(119.0));
      // Rest: 170 * 0.60 = 102.0
      expect(plan.segments[2].targetBpm, equals(102.0));
    });

    test('JSON round-trip preserves all fields including labels', () {
      final original = RunPlanCalculator.createIntervalPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
        intervalCount: 3,
        workSeconds: 90,
        restSeconds: 90,
        name: 'Interval round-trip',
      );
      final json = original.toJson();
      final restored = RunPlan.fromJson(json);
      expect(restored.type, equals(RunType.interval));
      expect(restored.distanceKm, equals(original.distanceKm));
      expect(restored.paceMinPerKm, equals(original.paceMinPerKm));
      expect(restored.name, equals(original.name));
      expect(restored.segments.length, equals(original.segments.length));
      for (var i = 0; i < original.segments.length; i++) {
        expect(
          restored.segments[i].durationSeconds,
          equals(original.segments[i].durationSeconds),
        );
        expect(
          restored.segments[i].targetBpm,
          equals(original.segments[i].targetBpm),
        );
        expect(
          restored.segments[i].label,
          equals(original.segments[i].label),
        );
      }
      expect(
        restored.createdAt?.toIso8601String(),
        equals(original.createdAt?.toIso8601String()),
      );
    });

    test('segment order: warm-up, work/rest pairs, cool-down', () {
      final plan = RunPlanCalculator.createIntervalPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
        intervalCount: 2,
        workSeconds: 120,
        restSeconds: 60,
      );
      // Expected: [Warm-up, Work 1, Rest 1, Work 2, Rest 2, Cool-down]
      expect(plan.segments[0].label, equals('Warm-up'));
      expect(plan.segments[1].label, equals('Work 1'));
      expect(plan.segments[2].label, equals('Rest 1'));
      expect(plan.segments[3].label, equals('Work 2'));
      expect(plan.segments[4].label, equals('Rest 2'));
      expect(plan.segments[5].label, equals('Cool-down'));
    });

    test('rest after last work before cool-down', () {
      final plan = RunPlanCalculator.createIntervalPlan(
        distanceKm: 5.0,
        paceMinPerKm: 6.0,
        targetBpm: 170.0,
        intervalCount: 3,
        workSeconds: 90,
        restSeconds: 90,
      );
      // Second-to-last segment should be Rest 3
      final secondToLast = plan.segments[plan.segments.length - 2];
      expect(secondToLast.label, equals('Rest 3'));
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
