import 'dart:convert';

import 'package:running_playlist_ai/features/run_plan/domain/run_plan.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistence wrapper for the current run plan.
///
/// Stores the active [RunPlan] as a JSON string in SharedPreferences
/// so it survives app restarts. Uses static methods with async access
/// to the SharedPreferences singleton.
///
/// Follows the same pattern as StridePreferences.
class RunPlanPreferences {
  static const _key = 'current_run_plan';

  /// Loads the saved run plan, or null if none is stored.
  static Future<RunPlan?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return null;
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return RunPlan.fromJson(json);
  }

  /// Saves the given run plan as a JSON string.
  static Future<void> save(RunPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(plan.toJson());
    await prefs.setString(_key, jsonString);
  }

  /// Removes the stored run plan.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
