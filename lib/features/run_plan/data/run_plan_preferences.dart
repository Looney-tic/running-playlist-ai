import 'dart:convert';

import 'package:running_playlist_ai/features/run_plan/domain/run_plan.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistence wrapper for the run plan library.
///
/// Stores multiple [RunPlan]s and tracks which one is currently selected.
/// Migrates automatically from the legacy single-plan format.
class RunPlanPreferences {
  static const _plansKey = 'run_plan_library';
  static const _selectedIdKey = 'run_plan_selected_id';

  // Legacy key for migration
  static const _legacyKey = 'current_run_plan';

  /// Loads all saved run plans.
  static Future<List<RunPlan>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();

    // Migrate legacy single plan if present
    final legacyJson = prefs.getString(_legacyKey);
    if (legacyJson != null) {
      final plan = RunPlan.fromJson(
        jsonDecode(legacyJson) as Map<String, dynamic>,
      );
      await saveAll([plan]);
      await prefs.setString(_selectedIdKey, plan.id);
      await prefs.remove(_legacyKey);
      return [plan];
    }

    final jsonString = prefs.getString(_plansKey);
    if (jsonString == null) return [];
    final list = jsonDecode(jsonString) as List<dynamic>;
    return list
        .map((j) => RunPlan.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Loads the selected plan ID, or null.
  static Future<String?> loadSelectedId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedIdKey);
  }

  /// Saves all run plans.
  static Future<void> saveAll(List<RunPlan> plans) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(plans.map((p) => p.toJson()).toList());
    await prefs.setString(_plansKey, jsonString);
  }

  /// Saves the selected plan ID.
  static Future<void> saveSelectedId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_selectedIdKey);
    } else {
      await prefs.setString(_selectedIdKey, id);
    }
  }
}
