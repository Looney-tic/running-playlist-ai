import 'dart:convert';

import 'package:running_playlist_ai/features/playlist_freshness/domain/playlist_freshness.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistence wrapper for [PlayHistory] using SharedPreferences.
///
/// Stores entries as a JSON object where keys are normalized song keys
/// and values are ISO 8601 date strings. Follows the same static-class
/// pattern as `SongFeedbackPreferences`.
class PlayHistoryPreferences {
  static const _key = 'play_history';

  /// Loads persisted play history entries.
  ///
  /// Returns an empty [PlayHistory] if no data has been saved yet.
  /// Corrupt individual entries are silently skipped so one bad record
  /// does not prevent the rest from loading.
  static Future<PlayHistory> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return PlayHistory(entries: {});

    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    final entries = <String, DateTime>{};

    for (final entry in decoded.entries) {
      try {
        entries[entry.key] = DateTime.parse(entry.value as String);
      } catch (_) {
        // Skip corrupt entries so one bad record doesn't prevent
        // the rest of the history from loading.
      }
    }

    return PlayHistory(entries: entries);
  }

  /// Persists the full play history to SharedPreferences.
  static Future<void> save(PlayHistory history) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      history.entries.map(
        (key, dateTime) => MapEntry(key, dateTime.toIso8601String()),
      ),
    );
    await prefs.setString(_key, encoded);
  }

  /// Removes all persisted play history data.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// Persistence wrapper for [FreshnessMode] using SharedPreferences.
///
/// Stores the mode as a plain string (`'keepItFresh'` or
/// `'optimizeForTaste'`). Defaults to [FreshnessMode.keepItFresh]
/// when no preference has been saved.
class FreshnessPreferences {
  static const _modeKey = 'freshness_mode';

  /// Loads the persisted freshness mode.
  ///
  /// Returns [FreshnessMode.keepItFresh] when no preference exists
  /// or when the stored value doesn't match any known mode.
  static Future<FreshnessMode> loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_modeKey);
    if (value == null) return FreshnessMode.keepItFresh;

    return FreshnessMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => FreshnessMode.keepItFresh,
    );
  }

  /// Persists the freshness mode.
  static Future<void> saveMode(FreshnessMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
  }
}
