import 'dart:convert';

import 'package:running_playlist_ai/features/taste_profile/domain/taste_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistence wrapper for the user's taste profile.
///
/// Stores the [TasteProfile] as a single JSON string in SharedPreferences
/// so it survives app restarts. Uses static methods with async access
/// to the SharedPreferences singleton.
///
/// Follows the same pattern as RunPlanPreferences.
class TasteProfilePreferences {
  static const _key = 'taste_profile';

  /// Loads the saved taste profile, or null if none is stored.
  static Future<TasteProfile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return null;
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return TasteProfile.fromJson(json);
  }

  /// Saves the given taste profile as a JSON string.
  static Future<void> save(TasteProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(profile.toJson());
    await prefs.setString(_key, jsonString);
  }

  /// Removes the stored taste profile.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
