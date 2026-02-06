import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/run_plan/data/run_plan_preferences.dart';
import 'package:running_playlist_ai/features/run_plan/domain/run_plan.dart';

/// State holding all saved plans and which one is selected.
class RunPlanLibraryState {
  const RunPlanLibraryState({
    this.plans = const [],
    this.selectedId,
  });

  final List<RunPlan> plans;
  final String? selectedId;

  /// The currently selected plan, or null if none is selected.
  RunPlan? get selectedPlan {
    if (selectedId == null) return plans.isNotEmpty ? plans.first : null;
    return plans
        .cast<RunPlan?>()
        .firstWhere((p) => p!.id == selectedId, orElse: () => null);
  }
}

/// Manages the run plan library: multiple saved plans + selection.
class RunPlanLibraryNotifier extends StateNotifier<RunPlanLibraryState> {
  RunPlanLibraryNotifier() : super(const RunPlanLibraryState()) {
    _load();
  }

  final Completer<void> _loadCompleter = Completer<void>();

  /// Waits until the initial async load from preferences is complete.
  /// Safe to call multiple times -- returns immediately if already loaded.
  Future<void> ensureLoaded() => _loadCompleter.future;

  Future<void> _load() async {
    try {
      final plans = await RunPlanPreferences.loadAll();
      final selectedId = await RunPlanPreferences.loadSelectedId();
      state = RunPlanLibraryState(plans: plans, selectedId: selectedId);
    } finally {
      if (!_loadCompleter.isCompleted) _loadCompleter.complete();
    }
  }

  /// Adds a new plan and selects it.
  Future<void> addPlan(RunPlan plan) async {
    final updated = [...state.plans, plan];
    state = RunPlanLibraryState(plans: updated, selectedId: plan.id);
    await RunPlanPreferences.saveAll(updated);
    await RunPlanPreferences.saveSelectedId(plan.id);
  }

  /// Selects a plan by ID.
  Future<void> selectPlan(String id) async {
    state = RunPlanLibraryState(plans: state.plans, selectedId: id);
    await RunPlanPreferences.saveSelectedId(id);
  }

  /// Deletes a plan by ID. If it was selected, selects the first remaining.
  Future<void> deletePlan(String id) async {
    final updated = state.plans.where((p) => p.id != id).toList();
    final newSelectedId = state.selectedId == id
        ? (updated.isNotEmpty ? updated.first.id : null)
        : state.selectedId;
    state = RunPlanLibraryState(plans: updated, selectedId: newSelectedId);
    await RunPlanPreferences.saveAll(updated);
    await RunPlanPreferences.saveSelectedId(newSelectedId);
  }
}

/// Provides the run plan library (all saved plans + selection).
final runPlanLibraryProvider =
    StateNotifierProvider<RunPlanLibraryNotifier, RunPlanLibraryState>(
  (ref) => RunPlanLibraryNotifier(),
);

/// Convenience: provides the currently selected [RunPlan?].
///
/// This replaces the old `runPlanNotifierProvider` for read-only access.
/// Widgets that just need the active plan can watch this.
final runPlanNotifierProvider = Provider<RunPlan?>((ref) {
  return ref.watch(runPlanLibraryProvider).selectedPlan;
});
