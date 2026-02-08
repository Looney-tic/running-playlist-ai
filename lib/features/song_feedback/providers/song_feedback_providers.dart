import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/song_feedback/data/song_feedback_preferences.dart';
import 'package:running_playlist_ai/features/song_feedback/domain/song_feedback.dart';

/// Manages the reactive song feedback state backed by SharedPreferences.
///
/// Holds a `Map<String, SongFeedback>` keyed by normalized song key
/// (see [SongKey.normalize]). Provides O(1) lookup via [getFeedback]
/// and persists all mutations through [SongFeedbackPreferences].
class SongFeedbackNotifier extends StateNotifier<Map<String, SongFeedback>> {
  SongFeedbackNotifier() : super({}) {
    _load();
  }

  final Completer<void> _loadCompleter = Completer<void>();

  /// Waits until the initial async load from preferences is complete.
  /// Safe to call multiple times -- returns immediately if already loaded.
  Future<void> ensureLoaded() => _loadCompleter.future;

  Future<void> _load() async {
    try {
      final feedback = await SongFeedbackPreferences.load();
      if (mounted) {
        state = feedback;
      }
    } finally {
      if (!_loadCompleter.isCompleted) _loadCompleter.complete();
    }
  }

  /// Adds or updates feedback for a song.
  ///
  /// Optimistically updates state first, then persists to storage.
  Future<void> addFeedback(SongFeedback feedback) async {
    state = {...state, feedback.songKey: feedback};
    await SongFeedbackPreferences.save(state);
  }

  /// Removes feedback for the given song key.
  ///
  /// No-op if the key does not exist in state.
  Future<void> removeFeedback(String songKey) async {
    state = Map.from(state)..remove(songKey);
    await SongFeedbackPreferences.save(state);
  }

  /// Returns the feedback for a song key, or `null` if none exists.
  ///
  /// O(1) lookup via the underlying [Map].
  SongFeedback? getFeedback(String songKey) => state[songKey];
}

/// Provides reactive song feedback state as a `Map<String, SongFeedback>`.
///
/// Read the notifier for CRUD operations:
/// ```dart
/// final notifier = ref.read(songFeedbackProvider.notifier);
/// await notifier.addFeedback(feedback);
/// ```
///
/// Watch the state for reactive UI updates:
/// ```dart
/// final feedbackMap = ref.watch(songFeedbackProvider);
/// ```
final songFeedbackProvider =
    StateNotifierProvider<SongFeedbackNotifier, Map<String, SongFeedback>>(
  (ref) => SongFeedbackNotifier(),
);
