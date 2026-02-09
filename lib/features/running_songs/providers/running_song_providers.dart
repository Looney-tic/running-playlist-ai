import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/running_songs/data/running_song_preferences.dart';
import 'package:running_playlist_ai/features/running_songs/domain/running_song.dart';

/// Manages the reactive "Songs I Run To" state backed by SharedPreferences.
///
/// Holds a `Map<String, RunningSong>` keyed by normalized song key
/// (see `SongKey.normalize`). Provides O(1) lookup via [containsSong]
/// and persists all mutations through [RunningSongPreferences].
class RunningSongNotifier extends StateNotifier<Map<String, RunningSong>> {
  RunningSongNotifier() : super({}) {
    _load();
  }

  final Completer<void> _loadCompleter = Completer<void>();

  /// Waits until the initial async load from preferences is complete.
  /// Safe to call multiple times -- returns immediately if already loaded.
  Future<void> ensureLoaded() => _loadCompleter.future;

  Future<void> _load() async {
    try {
      final songs = await RunningSongPreferences.load();
      if (mounted) {
        state = songs;
      }
    } finally {
      if (!_loadCompleter.isCompleted) _loadCompleter.complete();
    }
  }

  /// Adds a song to the "Songs I Run To" collection.
  ///
  /// Optimistically updates state first, then persists to storage.
  Future<void> addSong(RunningSong song) async {
    state = {...state, song.songKey: song};
    await RunningSongPreferences.save(state);
  }

  /// Removes a song from the collection by its normalized song key.
  ///
  /// No-op if the key does not exist in state.
  Future<void> removeSong(String songKey) async {
    state = Map.from(state)..remove(songKey);
    await RunningSongPreferences.save(state);
  }

  /// Adds multiple songs to the collection in a single batch.
  ///
  /// Updates state ONCE and persists ONCE regardless of input size,
  /// unlike calling [addSong] N times which would persist N times.
  /// Songs whose [RunningSong.songKey] already exists in the collection
  /// are silently skipped (deduplication).
  ///
  /// Returns the number of newly added songs.
  Future<int> addSongs(List<RunningSong> songs) async {
    var added = 0;
    final newState = Map<String, RunningSong>.from(state);
    for (final song in songs) {
      if (!newState.containsKey(song.songKey)) {
        newState[song.songKey] = song;
        added++;
      }
    }
    if (added > 0) {
      state = newState;
      await RunningSongPreferences.save(state);
    }
    return added;
  }

  /// Returns whether the collection contains a song with the given key.
  bool containsSong(String songKey) => state.containsKey(songKey);
}

/// Provides reactive "Songs I Run To" state as a `Map<String, RunningSong>`.
///
/// Read the notifier for CRUD operations:
/// ```dart
/// final notifier = ref.read(runningSongProvider.notifier);
/// await notifier.addSong(song);
/// ```
///
/// Watch the state for reactive UI updates:
/// ```dart
/// final songsMap = ref.watch(runningSongProvider);
/// ```
final runningSongProvider =
    StateNotifierProvider<RunningSongNotifier, Map<String, RunningSong>>(
  (ref) => RunningSongNotifier(),
);
