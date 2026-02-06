import 'dart:convert';

import 'package:running_playlist_ai/features/taste_profile/domain/taste_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistence wrapper for the taste profile library.
///
/// Stores multiple [TasteProfile]s and tracks which one is currently selected.
/// Migrates automatically from the legacy single-profile format.
class TasteProfilePreferences {
  static const _profilesKey = 'taste_profile_library';
  static const _selectedIdKey = 'taste_profile_selected_id';

  // Legacy key for migration
  static const _legacyKey = 'taste_profile';

  /// Loads all saved taste profiles.
  static Future<List<TasteProfile>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();

    // Migrate legacy single profile if present
    final legacyJson = prefs.getString(_legacyKey);
    if (legacyJson != null) {
      final profile = TasteProfile.fromJson(
        jsonDecode(legacyJson) as Map<String, dynamic>,
      );
      await saveAll([profile]);
      await prefs.setString(_selectedIdKey, profile.id);
      await prefs.remove(_legacyKey);
      return [profile];
    }

    final jsonString = prefs.getString(_profilesKey);
    if (jsonString == null) return [];
    final list = jsonDecode(jsonString) as List<dynamic>;
    final profiles = <TasteProfile>[];
    for (final j in list) {
      try {
        profiles.add(TasteProfile.fromJson(j as Map<String, dynamic>));
      } catch (_) {
        // Skip corrupt profiles so one bad entry doesn't prevent
        // the rest of the library from loading.
      }
    }
    return profiles;
  }

  /// Loads the selected profile ID, or null.
  static Future<String?> loadSelectedId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedIdKey);
  }

  /// Saves all taste profiles.
  static Future<void> saveAll(List<TasteProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString =
        jsonEncode(profiles.map((p) => p.toJson()).toList());
    await prefs.setString(_profilesKey, jsonString);
  }

  /// Saves the selected profile ID.
  static Future<void> saveSelectedId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_selectedIdKey);
    } else {
      await prefs.setString(_selectedIdKey, id);
    }
  }

  /// Legacy methods for backward compatibility during transition.
  static Future<TasteProfile?> load() async {
    final profiles = await loadAll();
    if (profiles.isEmpty) return null;
    final selectedId = await loadSelectedId();
    if (selectedId != null) {
      final match = profiles.cast<TasteProfile?>().firstWhere(
            (p) => p!.id == selectedId,
            orElse: () => null,
          );
      if (match != null) return match;
    }
    return profiles.first;
  }

  static Future<void> save(TasteProfile profile) async {
    final profiles = await loadAll();
    final index = profiles.indexWhere((p) => p.id == profile.id);
    if (index >= 0) {
      profiles[index] = profile;
    } else {
      profiles.add(profile);
    }
    await saveAll(profiles);
    await saveSelectedId(profile.id);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profilesKey);
    await prefs.remove(_selectedIdKey);
    await prefs.remove(_legacyKey);
  }
}
