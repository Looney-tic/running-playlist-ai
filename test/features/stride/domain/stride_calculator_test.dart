import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/stride/domain/stride_calculator.dart';

void main() {
  // ── paceToSpeed ──────────────────────────────────────────────────────

  group('paceToSpeed', () {
    test('converts 5.0 min/km to ~3.333 m/s', () {
      expect(
        StrideCalculator.paceToSpeed(5.0),
        closeTo(3.333, 0.01),
      );
    });

    test('converts 4.0 min/km to ~4.167 m/s', () {
      expect(
        StrideCalculator.paceToSpeed(4.0),
        closeTo(4.167, 0.01),
      );
    });

    test('converts 6.0 min/km to ~2.778 m/s', () {
      expect(
        StrideCalculator.paceToSpeed(6.0),
        closeTo(2.778, 0.01),
      );
    });

    test('returns 0.0 for zero pace', () {
      expect(StrideCalculator.paceToSpeed(0.0), equals(0.0));
    });

    test('returns 0.0 for negative pace', () {
      expect(StrideCalculator.paceToSpeed(-3.0), equals(0.0));
    });
  });

  // ── strideLengthFromHeight ───────────────────────────────────────────

  group('strideLengthFromHeight', () {
    test('170 cm -> 1.105 m', () {
      expect(
        StrideCalculator.strideLengthFromHeight(170),
        closeTo(1.105, 0.01),
      );
    });

    test('180 cm -> 1.17 m', () {
      expect(
        StrideCalculator.strideLengthFromHeight(180),
        closeTo(1.17, 0.01),
      );
    });

    test('160 cm -> 1.04 m', () {
      expect(
        StrideCalculator.strideLengthFromHeight(160),
        closeTo(1.04, 0.01),
      );
    });
  });

  // ── defaultStrideLengthFromSpeed ─────────────────────────────────────

  group('defaultStrideLengthFromSpeed', () {
    test('3.33 m/s -> ~1.93 m', () {
      expect(
        StrideCalculator.defaultStrideLengthFromSpeed(3.33),
        closeTo(1.932, 0.01),
      );
    });

    test('2.0 m/s -> ~1.4 m', () {
      expect(
        StrideCalculator.defaultStrideLengthFromSpeed(2.0),
        closeTo(1.4, 0.01),
      );
    });

    test('clamps to minimum 1.0 for very slow speeds', () {
      // 0.4 * 0.5 + 0.6 = 0.8 -> clamped to 1.0
      expect(
        StrideCalculator.defaultStrideLengthFromSpeed(0.5),
        equals(1.0),
      );
    });

    test('clamps to maximum 3.0 for extreme speeds', () {
      // 0.4 * 10 + 0.6 = 4.6 -> clamped to 3.0
      expect(
        StrideCalculator.defaultStrideLengthFromSpeed(10.0),
        equals(3.0),
      );
    });
  });

  // ── cadenceFromSpeedAndStride ────────────────────────────────────────

  group('cadenceFromSpeedAndStride', () {
    test('3.33 m/s with 1.105 m stride -> ~362 spm (steps, not strides)',
        () {
      // strideFreq = 3.33 / 1.105 = 3.014
      // cadence = 3.014 * 60 * 2 = 361.6
      final cadence =
          StrideCalculator.cadenceFromSpeedAndStride(3.33, 1.105);
      expect(cadence, closeTo(361.6, 1.0));
      // Must be > 300 to prove *2 is applied (strides->steps)
      expect(cadence, greaterThan(300));
    });

    test('returns 0.0 for zero speed', () {
      expect(
        StrideCalculator.cadenceFromSpeedAndStride(0.0, 1.0),
        equals(0.0),
      );
    });

    test('returns 0.0 for zero stride length', () {
      expect(
        StrideCalculator.cadenceFromSpeedAndStride(3.0, 0.0),
        equals(0.0),
      );
    });

    test('returns 0.0 for negative speed', () {
      expect(
        StrideCalculator.cadenceFromSpeedAndStride(-1.0, 1.0),
        equals(0.0),
      );
    });

    test('returns 0.0 for negative stride', () {
      expect(
        StrideCalculator.cadenceFromSpeedAndStride(3.0, -1.0),
        equals(0.0),
      );
    });
  });

  // ── calculateCadence ─────────────────────────────────────────────────

  group('calculateCadence', () {
    test('5:00 min/km without height returns cadence in 150-200 range', () {
      final cadence =
          StrideCalculator.calculateCadence(paceMinPerKm: 5.0);
      expect(cadence, greaterThanOrEqualTo(150));
      expect(cadence, lessThanOrEqualTo(200));
    });

    test('5:00 min/km with 190cm height differs from no-height', () {
      final withHeight = StrideCalculator.calculateCadence(
          paceMinPerKm: 5.0, heightCm: 190);
      final withoutHeight =
          StrideCalculator.calculateCadence(paceMinPerKm: 5.0);
      expect(withHeight, isNot(equals(withoutHeight)));
    });

    test('very slow pace (9:00) clamps to 150 spm', () {
      final cadence =
          StrideCalculator.calculateCadence(paceMinPerKm: 9.0);
      expect(cadence, equals(150.0));
    });

    test('very fast pace (3:00) clamps to 200 spm', () {
      final cadence =
          StrideCalculator.calculateCadence(paceMinPerKm: 3.0);
      expect(cadence, equals(200.0));
    });

    test('zero pace returns 0.0', () {
      final cadence =
          StrideCalculator.calculateCadence(paceMinPerKm: 0.0);
      expect(cadence, equals(0.0));
    });
  });

  // ── parsePace ────────────────────────────────────────────────────────

  group('parsePace', () {
    test('"5:30" -> 5.5', () {
      expect(parsePace('5:30'), closeTo(5.5, 0.01));
    });

    test('"4:00" -> 4.0', () {
      expect(parsePace('4:00'), closeTo(4.0, 0.01));
    });

    test('"6:45" -> 6.75', () {
      expect(parsePace('6:45'), closeTo(6.75, 0.01));
    });

    test('"abc" -> null', () {
      expect(parsePace('abc'), isNull);
    });

    test('empty string -> null', () {
      expect(parsePace(''), isNull);
    });

    test('"5:60" -> null (seconds >= 60)', () {
      expect(parsePace('5:60'), isNull);
    });

    test('"5" -> null (no colon)', () {
      expect(parsePace('5'), isNull);
    });

    test('"-1:30" -> null (negative minutes)', () {
      expect(parsePace('-1:30'), isNull);
    });
  });

  // ── formatPace ───────────────────────────────────────────────────────

  group('formatPace', () {
    test('5.5 -> "5:30"', () {
      expect(formatPace(5.5), equals('5:30'));
    });

    test('4.0 -> "4:00"', () {
      expect(formatPace(4.0), equals('4:00'));
    });

    test('6.75 -> "6:45"', () {
      expect(formatPace(6.75), equals('6:45'));
    });
  });
}
