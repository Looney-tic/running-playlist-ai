import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences persistence for dismissed taste suggestions.
///
/// Stores a JSON map of `{suggestionId: evidenceCountAtDismissal}`.
/// The evidence count allows suggestions to resurface when the user
/// accumulates significantly more evidence (delta >= 3).
class TasteSuggestionPreferences {
  static const _key = 'dismissed_taste_suggestions';

  /// Loads the dismissed suggestion map: {suggestionId: evidenceCountAtDismissal}.
  ///
  /// Returns an empty map if no dismissed suggestions exist.
  static Future<Map<String, int>> loadDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return {};
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as int));
  }

  /// Saves the dismissed suggestion map.
  static Future<void> saveDismissed(Map<String, int> dismissed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(dismissed));
  }
}
