import 'dart:convert';

import 'package:running_playlist_ai/features/song_feedback/domain/song_feedback.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistence wrapper for song feedback using SharedPreferences.
///
/// Stores a `Map<String, SongFeedback>` keyed by normalized song key
/// (see [SongKey.normalize]). Follows the same static-class pattern
/// as `TasteProfilePreferences`.
class SongFeedbackPreferences {
  static const _key = 'song_feedback';

  /// Loads all persisted song feedback entries.
  ///
  /// Returns an empty map if no feedback has been saved yet.
  /// Corrupt individual entries are silently skipped so one bad
  /// entry does not prevent the rest from loading.
  static Future<Map<String, SongFeedback>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return {};

    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    final result = <String, SongFeedback>{};

    for (final entry in decoded.entries) {
      try {
        result[entry.key] = SongFeedback.fromJson(
          entry.value as Map<String, dynamic>,
        );
      } catch (_) {
        // Skip corrupt entries so one bad record doesn't prevent
        // the rest of the feedback map from loading.
      }
    }

    return result;
  }

  /// Persists the full feedback map to SharedPreferences.
  static Future<void> save(Map<String, SongFeedback> feedback) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      feedback.map((k, v) => MapEntry(k, v.toJson())),
    );
    await prefs.setString(_key, encoded);
  }

  /// Removes all persisted feedback data.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
