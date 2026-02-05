import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/bpm_lookup/data/bpm_cache_preferences.dart';
import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_song.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Reset SharedPreferences before each test
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BpmCachePreferences', () {
    test('cacheTtl is 7 days', () {
      expect(BpmCachePreferences.cacheTtl, equals(const Duration(days: 7)));
    });
  });

  group('BpmCachePreferences.save and load', () {
    test('saves and loads songs for a BPM value', () async {
      final songs = [
        const BpmSong(
          songId: 'abc',
          title: 'Song A',
          artistName: 'Artist A',
          tempo: 170,
        ),
        const BpmSong(
          songId: 'def',
          title: 'Song B',
          artistName: 'Artist B',
          tempo: 170,
          albumTitle: 'Album B',
        ),
      ];

      await BpmCachePreferences.save(170, songs);
      final loaded = await BpmCachePreferences.load(170);

      expect(loaded, isNotNull);
      expect(loaded!.length, equals(2));
      expect(loaded[0].songId, equals('abc'));
      expect(loaded[0].title, equals('Song A'));
      expect(loaded[1].songId, equals('def'));
      expect(loaded[1].albumTitle, equals('Album B'));
    });

    test('returns null for uncached BPM', () async {
      final result = await BpmCachePreferences.load(999);
      expect(result, isNull);
    });

    test('caches per BPM value (170 and 85 are separate)', () async {
      final songs170 = [
        const BpmSong(
          songId: 's1',
          title: 'Fast Song',
          artistName: 'A',
          tempo: 170,
        ),
      ];
      final songs85 = [
        const BpmSong(
          songId: 's2',
          title: 'Slow Song',
          artistName: 'B',
          tempo: 85,
        ),
      ];

      await BpmCachePreferences.save(170, songs170);
      await BpmCachePreferences.save(85, songs85);

      final loaded170 = await BpmCachePreferences.load(170);
      final loaded85 = await BpmCachePreferences.load(85);

      expect(loaded170!.first.title, equals('Fast Song'));
      expect(loaded85!.first.title, equals('Slow Song'));
    });

    test('loaded songs default to exact matchType', () async {
      final songs = [
        const BpmSong(
          songId: 'abc',
          title: 'Song',
          artistName: 'Artist',
          tempo: 170,
          matchType: BpmMatchType.halfTime,
        ),
      ];

      await BpmCachePreferences.save(170, songs);
      final loaded = await BpmCachePreferences.load(170);

      // matchType is NOT stored in cache, so loaded songs get default (exact)
      expect(loaded!.first.matchType, equals(BpmMatchType.exact));
    });

    test('preserves optional fields through save/load cycle', () async {
      final songs = [
        const BpmSong(
          songId: 'abc',
          title: 'Song',
          artistName: 'Artist',
          tempo: 120,
          songUri: 'https://example.com/song',
          artistUri: 'https://example.com/artist',
          albumTitle: 'Album',
        ),
      ];

      await BpmCachePreferences.save(120, songs);
      final loaded = await BpmCachePreferences.load(120);

      expect(loaded!.first.songUri, equals('https://example.com/song'));
      expect(loaded.first.artistUri, equals('https://example.com/artist'));
      expect(loaded.first.albumTitle, equals('Album'));
    });

    test('saves empty list without error', () async {
      await BpmCachePreferences.save(200, []);
      final loaded = await BpmCachePreferences.load(200);
      expect(loaded, isNotNull);
      expect(loaded, isEmpty);
    });
  });

  group('BpmCachePreferences.clear', () {
    test('clears a specific BPM entry', () async {
      final songs = [
        const BpmSong(
          songId: 'abc',
          title: 'Song',
          artistName: 'A',
          tempo: 170,
        ),
      ];

      await BpmCachePreferences.save(170, songs);
      await BpmCachePreferences.clear(170);
      final loaded = await BpmCachePreferences.load(170);

      expect(loaded, isNull);
    });

    test('clearing one BPM does not affect another', () async {
      await BpmCachePreferences.save(170, [
        const BpmSong(
          songId: 'a',
          title: 'A',
          artistName: 'A',
          tempo: 170,
        ),
      ]);
      await BpmCachePreferences.save(85, [
        const BpmSong(
          songId: 'b',
          title: 'B',
          artistName: 'B',
          tempo: 85,
        ),
      ]);

      await BpmCachePreferences.clear(170);

      expect(await BpmCachePreferences.load(170), isNull);
      expect(await BpmCachePreferences.load(85), isNotNull);
    });
  });

  group('BpmCachePreferences.clearAll', () {
    test('clears all BPM cache entries', () async {
      await BpmCachePreferences.save(170, [
        const BpmSong(
          songId: 'a',
          title: 'A',
          artistName: 'A',
          tempo: 170,
        ),
      ]);
      await BpmCachePreferences.save(85, [
        const BpmSong(
          songId: 'b',
          title: 'B',
          artistName: 'B',
          tempo: 85,
        ),
      ]);

      await BpmCachePreferences.clearAll();

      expect(await BpmCachePreferences.load(170), isNull);
      expect(await BpmCachePreferences.load(85), isNull);
    });
  });

  group('BpmCachePreferences TTL', () {
    test('returns null and removes entry when cache is expired', () async {
      // Manually write a cache entry with an old timestamp
      final prefs = await SharedPreferences.getInstance();
      final oldDate =
          DateTime.now().subtract(const Duration(days: 8)).toIso8601String();
      final json = '{"cachedAt":"$oldDate","songs":[{"songId":"old","title":"Old Song","artistName":"A","tempo":170}]}';
      await prefs.setString('bpm_cache_170', json);

      final loaded = await BpmCachePreferences.load(170);
      expect(loaded, isNull);

      // Verify the expired entry was cleaned up
      expect(prefs.getString('bpm_cache_170'), isNull);
    });

    test('returns songs when cache is within TTL', () async {
      // Manually write a cache entry with a recent timestamp
      final prefs = await SharedPreferences.getInstance();
      final recentDate =
          DateTime.now().subtract(const Duration(days: 6)).toIso8601String();
      final json = '{"cachedAt":"$recentDate","songs":[{"songId":"new","title":"New Song","artistName":"A","tempo":170}]}';
      await prefs.setString('bpm_cache_170', json);

      final loaded = await BpmCachePreferences.load(170);
      expect(loaded, isNotNull);
      expect(loaded!.first.title, equals('New Song'));
    });
  });
}
