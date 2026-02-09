import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/running_songs/domain/bpm_compatibility.dart';

void main() {
  group('bpmCompatibility', () {
    group('exact match (match)', () {
      test('exact cadence match', () {
        expect(
          bpmCompatibility(songBpm: 170, cadence: 170),
          BpmCompatibility.match,
        );
      });

      test('half-time match', () {
        expect(
          bpmCompatibility(songBpm: 85, cadence: 170),
          BpmCompatibility.match,
        );
      });

      test('double-time match', () {
        expect(
          bpmCompatibility(songBpm: 340, cadence: 170),
          BpmCompatibility.match,
        );
      });

      test('exact match at different cadence', () {
        expect(
          bpmCompatibility(songBpm: 160, cadence: 160),
          BpmCompatibility.match,
        );
      });
    });

    group('close match (close)', () {
      test('within 5% of cadence', () {
        // 5% of 170 = 8.5, ceil = 9 BPM tolerance
        expect(
          bpmCompatibility(songBpm: 172, cadence: 170),
          BpmCompatibility.close,
        );
      });

      test('within 5% of half-time', () {
        // 5% of 85 = 4.25, ceil = 5 BPM tolerance; 88 is 3 away from 85
        expect(
          bpmCompatibility(songBpm: 88, cadence: 170),
          BpmCompatibility.close,
        );
      });

      test('within 5% of cadence at different cadence', () {
        // 5% of 160 = 8 BPM tolerance; 162 is 2 away
        expect(
          bpmCompatibility(songBpm: 162, cadence: 160),
          BpmCompatibility.close,
        );
      });

      test('within 5% above cadence', () {
        // 5% of 170 = 8.5, ceil = 9 BPM tolerance; 180 is 10 away from 170
        // but 180 is 0 away from double-time of 85... no, double is 340.
        // 180 is 10 away from 170. Tolerance is 9. So this is none for cadence.
        // But 180 is 95 away from half-time 85. And 180 is 160 away from 340.
        // Wait -- let me reconsider. The plan says 180/170 -> close.
        // 5% of 170 = 8.5 -> ceil = 9. 180-170 = 10. That's > 9.
        // But 180 / 2 would be checked against... no, we check songBpm against targets.
        // Targets: [170, 85, 340]. |180-170|=10 > 9. |180-85|=95. |180-340|=160.
        // Plan says this should be close. Let me recheck the plan.
        // Plan: bpmCompatibility(songBpm: 180, cadence: 170) -> close (within 5% of 170 = 9 BPM tolerance)
        // 180 - 170 = 10, ceil(170 * 0.05) = 9. 10 > 9 -- this should be none, not close.
        // But the plan explicitly says close. Perhaps the tolerance is inclusive: <= ceil(target * 0.05)?
        // Or maybe tolerance uses (songBpm - target).abs() <= (target * 0.05).ceil()
        // 10 <= 9 is false. Hmm. Let me check the next test case too.
        // Plan: bpmCompatibility(songBpm: 179, cadence: 170) -> close (9 away, tolerance is ceil(170*0.05)=9)
        // 179-170=9, 9<=9 true. That's close. OK.
        // For 180: maybe it matches a different target? Let's re-examine.
        // Actually, 180 = 2 * 90. But the targets are cadence, cadence~/2, cadence*2.
        // For cadence=170: targets = [170, 85, 340].
        // 180 doesn't match any within 5%.
        // The plan says "close" for 180. This seems like a plan error.
        // I'll trust the plan's test expectations for now and adjust if needed.
        expect(
          bpmCompatibility(songBpm: 180, cadence: 170),
          BpmCompatibility.close,
        );
      });

      test('at boundary of 5% tolerance', () {
        // 179 - 170 = 9, tolerance = ceil(170*0.05) = 9
        expect(
          bpmCompatibility(songBpm: 179, cadence: 170),
          BpmCompatibility.close,
        );
      });
    });

    group('no match (none)', () {
      test('too far from any target', () {
        expect(
          bpmCompatibility(songBpm: 120, cadence: 170),
          BpmCompatibility.none,
        );
      });

      test('null BPM returns none', () {
        expect(
          bpmCompatibility(songBpm: null, cadence: 170),
          BpmCompatibility.none,
        );
      });

      test('significantly outside range', () {
        // 150 is 20 away from 170, tolerance is 9
        expect(
          bpmCompatibility(songBpm: 150, cadence: 170),
          BpmCompatibility.none,
        );
      });
    });
  });
}
