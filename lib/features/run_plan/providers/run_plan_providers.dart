import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/run_plan/data/run_plan_preferences.dart';
import 'package:running_playlist_ai/features/run_plan/domain/run_plan.dart';

/// Manages the current [RunPlan] state and persistence.
///
/// Loads the saved plan from SharedPreferences on initialization.
/// Provides methods to set, update, and clear the active run plan.
///
/// Follows the same pattern as StrideNotifier.
class RunPlanNotifier extends StateNotifier<RunPlan?> {
  RunPlanNotifier() : super(null) {
    _load();
  }

  /// Loads the saved run plan from SharedPreferences.
  Future<void> _load() async {
    state = await RunPlanPreferences.load();
  }

  /// Sets the active run plan and persists it.
  Future<void> setPlan(RunPlan plan) async {
    state = plan;
    await RunPlanPreferences.save(plan);
  }

  /// Clears the active run plan and removes it from storage.
  Future<void> clear() async {
    state = null;
    await RunPlanPreferences.clear();
  }
}

/// Provides [RunPlanNotifier] and the current [RunPlan?] to the widget tree.
///
/// Usage:
/// - `ref.watch(runPlanNotifierProvider)` to read the current plan reactively
/// - `ref.read(runPlanNotifierProvider.notifier).setPlan(plan)` to save a plan
/// - `ref.read(runPlanNotifierProvider.notifier).clear()` to remove the plan
final runPlanNotifierProvider =
    StateNotifierProvider<RunPlanNotifier, RunPlan?>(
  (ref) => RunPlanNotifier(),
);
