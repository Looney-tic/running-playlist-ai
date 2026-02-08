import 'package:shared_preferences/shared_preferences.dart';

/// Persists the ID of the last playlist the user reviewed (or skipped).
///
/// Uses a single SharedPreferences key to track whether the most recent
/// playlist has been reviewed, so the home screen can show or hide the
/// post-run review prompt.
class PostRunReviewPreferences {
  static const _key = 'last_reviewed_playlist_id';

  /// Loads the last-reviewed playlist ID, or `null` if none was stored.
  static Future<String?> loadLastReviewedId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  /// Saves the given [playlistId] as the last-reviewed playlist.
  static Future<void> saveLastReviewedId(String playlistId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, playlistId);
  }

  /// Clears the last-reviewed playlist ID.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
