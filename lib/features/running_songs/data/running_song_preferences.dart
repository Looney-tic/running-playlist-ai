import 'dart:convert';

import 'package:running_playlist_ai/features/running_songs/domain/running_song.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistence wrapper for "Songs I Run To" using SharedPreferences.
///
/// Stores a `Map<String, RunningSong>` keyed by normalized song key
/// (see `SongKey.normalize`). Follows the same static-class pattern
/// as `SongFeedbackPreferences`.
class RunningSongPreferences {
  RunningSongPreferences._();

  static const _key = 'running_songs';

  /// Loads all persisted running songs.
  ///
  /// Returns an empty map if no songs have been saved yet.
  /// Corrupt individual entries are silently skipped so one bad
  /// entry does not prevent the rest from loading.
  static Future<Map<String, RunningSong>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return {};

    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    final result = <String, RunningSong>{};

    for (final entry in decoded.entries) {
      try {
        result[entry.key] = RunningSong.fromJson(
          entry.value as Map<String, dynamic>,
        );
      } catch (_) {
        // Skip corrupt entries so one bad record doesn't prevent
        // the rest of the running songs map from loading.
      }
    }

    return result;
  }

  /// Persists the full running songs map to SharedPreferences.
  static Future<void> save(Map<String, RunningSong> songs) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      songs.map((k, v) => MapEntry(k, v.toJson())),
    );
    await prefs.setString(_key, encoded);
  }

  /// Removes all persisted running songs data.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
