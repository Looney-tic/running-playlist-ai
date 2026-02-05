import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_matcher.dart';
import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_song.dart';

void main() {
  group('BpmMatcher', () {
    test('constants are reasonable', () {
      expect(BpmMatcher.maxQueryBpm, equals(300));
      expect(BpmMatcher.minQueryBpm, equals(40));
    });
  });

  group('BpmMatcher.bpmQueries', () {
    test('170 BPM returns exact and half-time, no double-time', () {
      final queries = BpmMatcher.bpmQueries(170);
      expect(queries[170], equals(BpmMatchType.exact));
      expect(queries[85], equals(BpmMatchType.halfTime));
      // 170 * 2 = 340 > maxQueryBpm (300), so no double-time
      expect(queries.containsKey(340), isFalse);
      expect(queries.length, equals(2));
    });

    test('85 BPM returns exact, half-time, and double-time', () {
      final queries = BpmMatcher.bpmQueries(85);
      expect(queries[85], equals(BpmMatchType.exact));
      expect(queries[170], equals(BpmMatchType.doubleTime));
      // 85 ~/ 2 = 42, >= minQueryBpm (40)
      expect(queries[42], equals(BpmMatchType.halfTime));
      expect(queries.length, equals(3));
    });

    test('120 BPM returns exact, half-time, and double-time', () {
      final queries = BpmMatcher.bpmQueries(120);
      expect(queries[120], equals(BpmMatchType.exact));
      expect(queries[60], equals(BpmMatchType.halfTime));
      expect(queries[240], equals(BpmMatchType.doubleTime));
      expect(queries.length, equals(3));
    });

    test('150 BPM returns exact, half-time, and double-time', () {
      final queries = BpmMatcher.bpmQueries(150);
      expect(queries[150], equals(BpmMatchType.exact));
      expect(queries[75], equals(BpmMatchType.halfTime));
      // 150 * 2 = 300, exactly at limit, should be included
      expect(queries[300], equals(BpmMatchType.doubleTime));
      expect(queries.length, equals(3));
    });

    test('70 BPM excludes half-time below minQueryBpm', () {
      final queries = BpmMatcher.bpmQueries(70);
      expect(queries[70], equals(BpmMatchType.exact));
      // 70 ~/ 2 = 35, < minQueryBpm (40), excluded
      expect(queries.containsKey(35), isFalse);
      expect(queries[140], equals(BpmMatchType.doubleTime));
      expect(queries.length, equals(2));
    });

    test('40 BPM at minQueryBpm boundary', () {
      final queries = BpmMatcher.bpmQueries(40);
      expect(queries[40], equals(BpmMatchType.exact));
      // 40 ~/ 2 = 20, < minQueryBpm, excluded
      expect(queries.containsKey(20), isFalse);
      expect(queries[80], equals(BpmMatchType.doubleTime));
      expect(queries.length, equals(2));
    });

    test('always includes exact match', () {
      final queries = BpmMatcher.bpmQueries(200);
      expect(queries[200], equals(BpmMatchType.exact));
    });
  });
}
