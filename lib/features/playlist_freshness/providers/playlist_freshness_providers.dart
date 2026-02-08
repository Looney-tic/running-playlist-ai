import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/playlist/domain/playlist.dart';
import 'package:running_playlist_ai/features/playlist_freshness/data/playlist_freshness_preferences.dart';
import 'package:running_playlist_ai/features/playlist_freshness/domain/playlist_freshness.dart';

/// Manages reactive [PlayHistory] state backed by SharedPreferences.
///
/// Loads persisted history on construction and provides
/// [recordPlaylist] to append new entries after playlist generation.
/// Follows the same Completer-based [ensureLoaded] pattern as
/// `SongFeedbackNotifier`.
class PlayHistoryNotifier extends StateNotifier<PlayHistory> {
  PlayHistoryNotifier() : super(PlayHistory(entries: {})) {
    _load();
  }

  final Completer<void> _loadCompleter = Completer<void>();

  /// Waits until the initial async load from preferences is complete.
  /// Safe to call multiple times -- returns immediately if already loaded.
  Future<void> ensureLoaded() => _loadCompleter.future;

  Future<void> _load() async {
    try {
      final history = await PlayHistoryPreferences.load();
      if (mounted) {
        state = history;
      }
    } finally {
      if (!_loadCompleter.isCompleted) _loadCompleter.complete();
    }
  }

  /// Records all songs in [playlist] as played and persists the update.
  ///
  /// Optimistically updates state first, then writes to storage.
  Future<void> recordPlaylist(Playlist playlist) async {
    state = state.recordPlaylist(playlist);
    await PlayHistoryPreferences.save(state);
  }
}

/// Manages reactive [FreshnessMode] state backed by SharedPreferences.
///
/// Loads persisted mode on construction and provides [setMode] to
/// toggle between freshness strategies. Follows the same
/// Completer-based [ensureLoaded] pattern as `SongFeedbackNotifier`.
class FreshnessModeNotifier extends StateNotifier<FreshnessMode> {
  FreshnessModeNotifier() : super(FreshnessMode.keepItFresh) {
    _load();
  }

  final Completer<void> _loadCompleter = Completer<void>();

  /// Waits until the initial async load from preferences is complete.
  /// Safe to call multiple times -- returns immediately if already loaded.
  Future<void> ensureLoaded() => _loadCompleter.future;

  Future<void> _load() async {
    try {
      final mode = await FreshnessPreferences.loadMode();
      if (mounted) {
        state = mode;
      }
    } finally {
      if (!_loadCompleter.isCompleted) _loadCompleter.complete();
    }
  }

  /// Updates the freshness mode and persists the change.
  ///
  /// Optimistically updates state first, then writes to storage.
  Future<void> setMode(FreshnessMode mode) async {
    state = mode;
    await FreshnessPreferences.saveMode(mode);
  }
}

/// Provides reactive [PlayHistory] state.
///
/// Read the notifier for mutations:
/// ```dart
/// final notifier = ref.read(playHistoryProvider.notifier);
/// await notifier.recordPlaylist(playlist);
/// ```
///
/// Watch the state for reactive access:
/// ```dart
/// final history = ref.watch(playHistoryProvider);
/// final penalty = history.freshnessPenalty(songKey);
/// ```
final playHistoryProvider =
    StateNotifierProvider<PlayHistoryNotifier, PlayHistory>(
  (ref) => PlayHistoryNotifier(),
);

/// Provides reactive [FreshnessMode] state.
///
/// Read the notifier to change mode:
/// ```dart
/// final notifier = ref.read(freshnessModeProvider.notifier);
/// await notifier.setMode(FreshnessMode.optimizeForTaste);
/// ```
///
/// Watch the state for reactive UI updates:
/// ```dart
/// final mode = ref.watch(freshnessModeProvider);
/// ```
final freshnessModeProvider =
    StateNotifierProvider<FreshnessModeNotifier, FreshnessMode>(
  (ref) => FreshnessModeNotifier(),
);
