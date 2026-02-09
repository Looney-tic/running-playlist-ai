import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/running_songs/domain/running_song.dart';
import 'package:running_playlist_ai/features/running_songs/providers/running_song_providers.dart';
import 'package:running_playlist_ai/features/song_feedback/domain/song_feedback.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('RunningSongNotifier lifecycle', () {
    late ProviderContainer container;

    RunningSong _makeSong({
      required String artist,
      required String title,
      int? bpm,
      String? genre,
      RunningSongSource source = RunningSongSource.curated,
    }) {
      final key = SongKey.normalize(artist, title);
      return RunningSong(
        songKey: key,
        artist: artist,
        title: title,
        addedDate: DateTime(2026, 2, 9),
        bpm: bpm,
        genre: genre,
        source: source,
      );
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    Future<RunningSongNotifier> _notifier() async {
      final notifier = container.read(runningSongProvider.notifier);
      await notifier.ensureLoaded();
      return notifier;
    }

    Map<String, RunningSong> _state() {
      return container.read(runningSongProvider);
    }

    test('starts with empty map', () async {
      await _notifier();
      expect(_state(), isEmpty);
    });

    test('add a running song and read it back', () async {
      final notifier = await _notifier();
      final song = _makeSong(
        artist: 'Test Artist',
        title: 'Test Song',
        bpm: 160,
        genre: 'electronic',
      );

      await notifier.addSong(song);

      expect(_state(), hasLength(1));
      expect(
        _state().containsKey(SongKey.normalize('Test Artist', 'Test Song')),
        isTrue,
      );
      final stored = _state().values.first;
      expect(stored.artist, 'Test Artist');
      expect(stored.title, 'Test Song');
      expect(stored.bpm, 160);
      expect(stored.genre, 'electronic');
    });

    test('remove a running song', () async {
      final notifier = await _notifier();
      final song = _makeSong(artist: 'Eminem', title: 'Lose Yourself');

      await notifier.addSong(song);
      expect(_state(), hasLength(1));

      await notifier.removeSong(song.songKey);
      expect(_state(), isEmpty);
    });

    test('containsSong returns correct result', () async {
      final notifier = await _notifier();
      final song = _makeSong(artist: 'Eminem', title: 'Lose Yourself');

      await notifier.addSong(song);

      expect(notifier.containsSong(song.songKey), isTrue);
      expect(
        notifier.containsSong(SongKey.normalize('Other', 'Song')),
        isFalse,
      );
    });

    test('removeSong ignores missing key', () async {
      final notifier = await _notifier();

      // Should not crash.
      await notifier.removeSong('nonexistent|key');
      expect(_state(), isEmpty);
    });
  });

  group('Persistence round-trip', () {
    late ProviderContainer container;

    RunningSong _makeSong({
      required String artist,
      required String title,
      int? bpm,
      String? genre,
    }) {
      final key = SongKey.normalize(artist, title);
      return RunningSong(
        songKey: key,
        artist: artist,
        title: title,
        addedDate: DateTime(2026, 2, 9),
        bpm: bpm,
        genre: genre,
      );
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    Future<RunningSongNotifier> _notifier() async {
      final notifier = container.read(runningSongProvider.notifier);
      await notifier.ensureLoaded();
      return notifier;
    }

    Map<String, RunningSong> _state() {
      return container.read(runningSongProvider);
    }

    test('state survives dispose and reload', () async {
      final notifier = await _notifier();

      await notifier.addSong(
        _makeSong(
          artist: 'Eminem',
          title: 'Lose Yourself',
          bpm: 171,
          genre: 'hip-hop',
        ),
      );
      await notifier.addSong(
        _makeSong(artist: 'Daft Punk', title: 'Around The World'),
      );

      expect(_state(), hasLength(2));

      // Dispose first container.
      container.dispose();

      // Create fresh container -- DO NOT call setMockInitialValues again
      // so SharedPreferences still has the persisted data.
      container = ProviderContainer();
      await _notifier();

      final reloadedState = _state();
      expect(reloadedState, hasLength(2));

      final eminemKey = SongKey.normalize('Eminem', 'Lose Yourself');
      expect(reloadedState.containsKey(eminemKey), isTrue);
      expect(reloadedState[eminemKey]!.bpm, 171);
      expect(reloadedState[eminemKey]!.genre, 'hip-hop');

      final daftPunkKey = SongKey.normalize('Daft Punk', 'Around The World');
      expect(reloadedState.containsKey(daftPunkKey), isTrue);
    });

    test('corrupt entries are skipped on load', () async {
      // Pre-seed SharedPreferences with one valid and one corrupt entry.
      final validSong = RunningSong(
        songKey: SongKey.normalize('Eminem', 'Lose Yourself'),
        artist: 'Eminem',
        title: 'Lose Yourself',
        addedDate: DateTime(2026, 2, 9),
        bpm: 171,
      );
      final preSeeded = jsonEncode({
        validSong.songKey: validSong.toJson(),
        'corrupt|key': 'not a valid json object',
      });

      SharedPreferences.setMockInitialValues({'running_songs': preSeeded});

      // Dispose the existing container (from setUp) and create new one
      // with the seeded values.
      container.dispose();
      container = ProviderContainer();

      await _notifier();
      final state = _state();

      // Only the valid entry should load; corrupt entry silently skipped.
      expect(state, hasLength(1));
      expect(state.containsKey(validSong.songKey), isTrue);
      expect(state[validSong.songKey]!.artist, 'Eminem');
    });

    test('empty state persists as empty', () async {
      await _notifier();
      expect(_state(), isEmpty);

      // Dispose and reload.
      container.dispose();
      container = ProviderContainer();
      await _notifier();

      expect(_state(), isEmpty);
    });
  });

  group('addSongs batch method', () {
    late ProviderContainer container;

    RunningSong _makeSong({
      required String artist,
      required String title,
      RunningSongSource source = RunningSongSource.spotify,
    }) {
      final key = SongKey.normalize(artist, title);
      return RunningSong(
        songKey: key,
        artist: artist,
        title: title,
        addedDate: DateTime(2026, 2, 9),
        source: source,
      );
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    Future<RunningSongNotifier> _notifier() async {
      final notifier = container.read(runningSongProvider.notifier);
      await notifier.ensureLoaded();
      return notifier;
    }

    Map<String, RunningSong> _state() {
      return container.read(runningSongProvider);
    }

    test('addSongs with 3 new songs adds all and returns 3', () async {
      final notifier = await _notifier();
      final songs = [
        _makeSong(artist: 'Eminem', title: 'Lose Yourself'),
        _makeSong(artist: 'The Weeknd', title: 'Blinding Lights'),
        _makeSong(artist: 'Dua Lipa', title: 'Levitating'),
      ];

      final added = await notifier.addSongs(songs);

      expect(added, 3);
      expect(_state(), hasLength(3));
      expect(
        notifier.containsSong(SongKey.normalize('Eminem', 'Lose Yourself')),
        isTrue,
      );
      expect(
        notifier.containsSong(
          SongKey.normalize('The Weeknd', 'Blinding Lights'),
        ),
        isTrue,
      );
      expect(
        notifier.containsSong(SongKey.normalize('Dua Lipa', 'Levitating')),
        isTrue,
      );
    });

    test('addSongs skips existing songs and returns correct count', () async {
      final notifier = await _notifier();

      // Pre-add one song.
      await notifier.addSong(
        _makeSong(artist: 'Eminem', title: 'Lose Yourself'),
      );
      expect(_state(), hasLength(1));

      // Batch add 2 songs where 1 already exists.
      final songs = [
        _makeSong(artist: 'Eminem', title: 'Lose Yourself'), // Duplicate
        _makeSong(artist: 'Dua Lipa', title: 'Levitating'), // New
      ];

      final added = await notifier.addSongs(songs);

      expect(added, 1);
      expect(_state(), hasLength(2));
    });

    test('addSongs with empty list returns 0 and state unchanged', () async {
      final notifier = await _notifier();

      // Pre-add one song so state is non-empty.
      await notifier.addSong(
        _makeSong(artist: 'Eminem', title: 'Lose Yourself'),
      );
      final stateBefore = _state();

      final added = await notifier.addSongs([]);

      expect(added, 0);
      expect(_state(), equals(stateBefore));
    });

    test('addSongs with all duplicates returns 0 and state unchanged',
        () async {
      final notifier = await _notifier();

      // Pre-add songs.
      await notifier.addSong(
        _makeSong(artist: 'Eminem', title: 'Lose Yourself'),
      );
      await notifier.addSong(
        _makeSong(artist: 'Dua Lipa', title: 'Levitating'),
      );
      expect(_state(), hasLength(2));

      // Try to batch add the same songs.
      final songs = [
        _makeSong(artist: 'Eminem', title: 'Lose Yourself'),
        _makeSong(artist: 'Dua Lipa', title: 'Levitating'),
      ];

      final added = await notifier.addSongs(songs);

      expect(added, 0);
      expect(_state(), hasLength(2));
    });
  });
}
