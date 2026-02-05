---
phase: 06-steady-run-planning
plan: 01
subsystem: run-plan-domain
tags: [domain-model, calculator, tdd, pure-dart]
dependency-graph:
  requires: [05-01]
  provides: [run-plan-model, run-plan-calculator, format-duration]
  affects: [06-02, 07-xx, 08-xx]
tech-stack:
  added: []
  patterns: [segment-based-plan-model, static-calculator, json-serialization]
key-files:
  created:
    - lib/features/run_plan/domain/run_plan.dart
    - lib/features/run_plan/domain/run_plan_calculator.dart
    - test/features/run_plan/domain/run_plan_calculator_test.dart
  modified: []
decisions:
  - id: "06-01-segment-model"
    description: "Segment-based RunPlan model enables future interval/warm-up support without restructuring"
  - id: "06-01-calibrated-override"
    description: "Calibrated cadence always wins over formula-based BPM derivation"
metrics:
  duration: 3m
  completed: 2026-02-05
---

# Phase 6 Plan 01: Run Plan Domain Model and Calculator Summary

Segment-based RunPlan data model with pure Dart calculator: duration from distance*pace, BPM from StrideCalculator with calibrated override, JSON round-trip serialization.

## What Was Built

### RunPlan Data Model (`run_plan.dart`)
- **RunType enum:** `steady`, `warmUpCoolDown`, `interval` -- serializes by name
- **RunSegment class:** `durationSeconds` (int), `targetBpm` (double), optional `label` -- with `toJson`/`fromJson`
- **RunPlan class:** type, distanceKm, paceMinPerKm, segments list, optional name/createdAt -- with `toJson`/`fromJson`
- **Getters:** `totalDurationSeconds` (fold across segments), `totalDurationMinutes`
- **formatDuration helper:** Converts seconds to "MM:SS" or "H:MM:SS" format

### RunPlanCalculator (`run_plan_calculator.dart`)
- **durationSeconds:** `(distance * pace * 60).round()`, returns 0 for invalid inputs
- **targetBpm:** Returns `calibratedCadence` if provided, otherwise delegates to `StrideCalculator.calculateCadence()`
- **createSteadyPlan:** Factory for single-segment steady run plans with auto-generated `createdAt`

### Test Coverage (35 tests)
- 8 duration calculation tests (5K, 10K, half marathon, marathon, edge cases)
- 4 target BPM tests (with/without height, calibrated override)
- 9 steady plan creation tests (type, segments, timestamps, getters)
- 7 serialization tests (round-trip, enum names, null omission, labels)
- 7 formatDuration tests (MM:SS, H:MM:SS, edge cases)

## TDD Execution

| Phase    | Commit    | Description                           |
|----------|-----------|---------------------------------------|
| RED      | `3fd7034` | 35 failing tests (compilation errors) |
| GREEN    | `e5ff3a3` | Implementation passes all 35 tests    |
| REFACTOR | --        | Not needed: code already lint-clean   |

## Key Design Decisions

1. **Segment-based model:** A steady run has exactly 1 segment. This design extends naturally to intervals (Phase 8) without restructuring -- just add more segments with different BPM targets.

2. **Calibrated cadence override:** When the user has calibrated their cadence on the stride screen, that value takes priority over the formula-based calculation. This respects user measurements.

3. **JSON serialization without code-gen:** Hand-written `toJson`/`fromJson` avoids freezed/json_serializable dependency issues with Dart 3.10. Null optional fields are omitted from JSON output.

## Verification Results

- All 35 tests pass
- `dart analyze` reports 0 issues
- Zero Flutter imports in domain layer (confirmed by grep)
- Key link verified: `RunPlanCalculator` imports and calls `StrideCalculator.calculateCadence()`

## Deviations from Plan

None -- plan executed exactly as written.

## Next Phase Readiness

- **06-02 (Run Plan Screen UI)** can now consume `RunPlan`, `RunPlanCalculator`, and `formatDuration`
- **Phase 7 (Playlist Generation)** will use `RunPlan.segments` to match songs by BPM per segment
- **Phase 8 (Intervals)** will create multi-segment plans using the same `RunPlan` model
