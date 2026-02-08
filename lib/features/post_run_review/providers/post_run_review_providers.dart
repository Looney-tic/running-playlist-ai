import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/playlist/domain/playlist.dart';
import 'package:running_playlist_ai/features/playlist/providers/playlist_history_providers.dart';
import 'package:running_playlist_ai/features/post_run_review/data/post_run_review_preferences.dart';

/// Manages the last-reviewed playlist ID, backed by SharedPreferences.
///
/// State is `String?` -- the ID of the most recently reviewed (or skipped)
/// playlist. Null means no playlist has ever been reviewed.
class PostRunReviewNotifier extends StateNotifier<String?> {
  PostRunReviewNotifier() : super(null) {
    _load();
  }

  final Completer<void> _loadCompleter = Completer<void>();

  /// Waits until the initial async load from preferences is complete.
  /// Safe to call multiple times -- returns immediately if already loaded.
  Future<void> ensureLoaded() => _loadCompleter.future;

  Future<void> _load() async {
    try {
      final id = await PostRunReviewPreferences.loadLastReviewedId();
      if (mounted) {
        state = id;
      }
    } finally {
      if (!_loadCompleter.isCompleted) _loadCompleter.complete();
    }
  }

  /// Marks the given [playlistId] as reviewed and persists the change.
  Future<void> markReviewed(String playlistId) async {
    state = playlistId;
    await PostRunReviewPreferences.saveLastReviewedId(playlistId);
  }
}

/// Provides the last-reviewed playlist ID and notifier.
///
/// Watch the state to reactively check if the most recent playlist
/// has been reviewed:
/// ```dart
/// final lastReviewedId = ref.watch(postRunReviewProvider);
/// ```
final postRunReviewProvider =
    StateNotifierProvider<PostRunReviewNotifier, String?>(
  (ref) => PostRunReviewNotifier(),
);

/// Derives the most recent unreviewed playlist, or `null` if none exists.
///
/// Returns null when:
/// - playlist history is empty
/// - the most recent playlist has no ID
/// - the most recent playlist ID matches the last-reviewed ID
final unreviewedPlaylistProvider = Provider<Playlist?>((ref) {
  final playlists = ref.watch(playlistHistoryProvider);
  final lastReviewedId = ref.watch(postRunReviewProvider);

  if (playlists.isEmpty) return null;

  final mostRecent = playlists.first;
  if (mostRecent.id == null) return null;
  if (mostRecent.id == lastReviewedId) return null;

  return mostRecent;
});
