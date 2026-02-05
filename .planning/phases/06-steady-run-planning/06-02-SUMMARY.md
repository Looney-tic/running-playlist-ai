---
phase: 06-steady-run-planning
plan: 02
subsystem: run-plan-ui
tags: [ui, providers, persistence, shared-preferences, riverpod]
dependency-graph:
  requires: [06-01, 05-02]
  provides: [run-plan-screen, run-plan-persistence, run-plan-providers]
  affects: [07-xx]
tech-stack:
  added: []
  patterns: [state-notifier, shared-preferences-json, choice-chips, dropdown-pace]
key-files:
  created:
    - lib/features/run_plan/data/run_plan_preferences.dart
    - lib/features/run_plan/providers/run_plan_providers.dart
    - lib/features/run_plan/presentation/run_plan_screen.dart
  modified:
    - lib/app/router.dart
    - lib/features/home/presentation/home_screen.dart
decisions:
  - id: "06-02-single-plan"
    description: "One active run plan at a time, stored as single SharedPreferences key -- sufficient for playlist generation"
  - id: "06-02-stride-integration"
    description: "Run plan screen reads height and calibrated cadence from strideNotifierProvider for BPM calculation"
metrics:
  duration: 5m
  completed: 2026-02-05
---

# Phase 6 Plan 02: Run Plan Screen UI Summary

Persistence, Riverpod providers, and full UI screen for steady run planning with distance/pace input, real-time duration/BPM display, and save to SharedPreferences.

## What Was Built

### RunPlanPreferences (`run_plan_preferences.dart`)
- Static methods: `load()`, `save(RunPlan)`, `clear()`
- Single key `current_run_plan` storing JSON string in SharedPreferences
- Follows StridePreferences pattern exactly

### RunPlanNotifier (`run_plan_providers.dart`)
- `StateNotifier<RunPlan?>` with auto-load from SharedPreferences in constructor
- `setPlan(RunPlan)` sets state and persists
- `clear()` nulls state and removes from storage
- Exported as `runPlanNotifierProvider`

### RunPlanScreen (`run_plan_screen.dart`)
- **Distance selection:** 4 preset ChoiceChips (5K, 10K, Half, Marathon) + custom TextField (0.1-100 km range)
- **Pace input:** Dropdown 3:00-10:00 min/km in 15s increments (reuses StrideScreen pattern)
- **Run summary card:** Real-time computed duration (formatDuration) and target BPM (RunPlanCalculator)
- **Save button:** Creates plan via `RunPlanCalculator.createSteadyPlan()`, persists via notifier, shows snackbar
- **Current plan indicator:** Card showing saved plan distance and pace
- **Stride integration:** Reads height and calibrated cadence from `strideNotifierProvider`

### Router & Navigation
- `/run-plan` route added to GoRouter
- "Plan Run" button added to HomeScreen between Stride Calculator and Log out
- All routes made public (auth guard disabled while Spotify Dashboard blocked)

## Commits

| Commit    | Description                                           |
|-----------|-------------------------------------------------------|
| `5a08e37` | feat(06-02): persistence layer and providers          |
| `c1c20cf` | feat(06-02): run plan screen with UI and navigation   |

## Key Design Decisions

1. **Single active plan:** One `RunPlan` stored in SharedPreferences. Multiple plan history is a Phase 9 concern. Sufficient for Phase 7 playlist generation.

2. **Stride integration:** The run plan screen watches `strideNotifierProvider` to get height and calibrated cadence. If the user has calibrated on the stride screen, that cadence overrides the formula.

3. **Reused patterns:** Same dropdown/chip/persistence patterns as Phase 5 stride screen for consistency.

## Verification Results

- Human-verified: distance chips, pace dropdown, duration/BPM display, save/persist all working
- Auth guard disabled for testing (redirect returns null)
- Navigation from home screen to /run-plan works
- `dart analyze` reports 0 issues
- All existing tests pass

## Deviations from Plan

- Auth guard simplified to `return null` instead of maintaining public route list (Spotify Dashboard blocked indefinitely)

## Next Phase Readiness

- **Phase 7 (Playlist Generation)** can read the active plan via `runPlanNotifierProvider` to get target BPM and duration
- **Phase 8 (Structured Runs)** extends the same screen with segment UI
