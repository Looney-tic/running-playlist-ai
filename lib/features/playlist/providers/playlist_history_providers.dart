import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/playlist/data/playlist_history_preferences.dart';
import 'package:running_playlist_ai/features/playlist/domain/playlist.dart';

/// Manages the list of saved playlists in history.
///
/// Loads from [PlaylistHistoryPreferences] on construction, provides
/// methods to add and delete playlists, and persists every mutation.
class PlaylistHistoryNotifier extends StateNotifier<List<Playlist>> {
  PlaylistHistoryNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final playlists = await PlaylistHistoryPreferences.load();
    if (playlists != null && mounted) {
      state = playlists;
    }
  }

  /// Adds a playlist to the front of history (newest first) and persists.
  Future<void> addPlaylist(Playlist playlist) async {
    state = [playlist, ...state];
    await PlaylistHistoryPreferences.save(state);
  }

  /// Deletes a playlist by [id] and persists.
  Future<void> deletePlaylist(String id) async {
    state = state.where((p) => p.id != id).toList();
    await PlaylistHistoryPreferences.save(state);
  }
}

/// Provides the playlist history state and notifier.
///
/// Usage:
/// - `ref.watch(playlistHistoryProvider)` for the `List<Playlist>` state
/// - `ref.read(playlistHistoryProvider.notifier).addPlaylist(...)` to add
/// - `ref.read(playlistHistoryProvider.notifier).deletePlaylist(id)` to remove
final playlistHistoryProvider =
    StateNotifierProvider<PlaylistHistoryNotifier, List<Playlist>>((ref) {
  return PlaylistHistoryNotifier();
});
