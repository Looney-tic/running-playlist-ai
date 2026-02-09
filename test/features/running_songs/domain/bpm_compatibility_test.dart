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

      test('just outside 5% tolerance', () {
        // 180 - 170 = 10, tolerance = ceil(170*0.05) = 9; 10 > 9
        expect(
          bpmCompatibility(songBpm: 180, cadence: 170),
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
