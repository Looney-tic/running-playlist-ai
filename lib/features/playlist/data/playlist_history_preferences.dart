import 'dart:convert';

import 'package:running_playlist_ai/features/playlist/domain/playlist.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistence wrapper for playlist generation history.
///
/// Stores a list of [Playlist] objects as a single JSON-encoded string
/// in SharedPreferences under the key `playlist_history`. The collection
/// is always loaded and saved as a whole (not per-entry).
///
/// Follows the same single-key pattern as `TasteProfilePreferences`.
class PlaylistHistoryPreferences {
  static const _key = 'playlist_history';

  /// Maximum number of playlists to store. Oldest are trimmed on save.
  static const maxHistorySize = 50;

  /// Loads the saved playlist history, or null if none is stored.
  static Future<List<Playlist>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return null;
    final list = jsonDecode(jsonString) as List<dynamic>;
    return list
        .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Saves the given playlist history as a JSON string.
  ///
  /// Trims the list to [maxHistorySize] entries (keeping the first/newest).
  static Future<void> save(List<Playlist> playlists) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = playlists.length > maxHistorySize
        ? playlists.sublist(0, maxHistorySize)
        : playlists;
    final jsonString =
        jsonEncode(trimmed.map((p) => p.toJson()).toList());
    await prefs.setString(_key, jsonString);
  }

  /// Removes the stored playlist history.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
