---
phase: 08-structured-run-types
plan: 01
subsystem: domain
tags: [dart, tdd, run-plan, intervals, warm-up, cadence, bpm]

# Dependency graph
requires:
  - phase: 06-steady-run-planning
    provides: RunPlan/RunSegment model, RunPlanCalculator with createSteadyPlan
provides:
  - createWarmUpCoolDownPlan factory method (3-segment plans)
  - createIntervalPlan factory method (N*2+2 segment plans)
  - BPM fraction logic for warm-up/cool-down/rest segments
affects: [08-02 (UI for structured run types), 07 (playlist generation per segment)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "BPM fraction derivation: targetBpm * fraction rounded via roundToDouble()"
    - "Main segment clamping: min 60s when warm-up+cool-down exceed total duration"
    - "Interval segment ordering: warm-up, N*(work+rest), cool-down"

key-files:
  created: []
  modified:
    - lib/features/run_plan/domain/run_plan_calculator.dart
    - test/features/run_plan/domain/run_plan_calculator_test.dart

key-decisions:
  - "Rest after every work segment including last (avoids large BPM jump from work to cool-down)"
  - "roundToDouble() for all derived BPMs (matches Dart numeric precision conventions)"

patterns-established:
  - "Factory method pattern: static methods on RunPlanCalculator return RunPlan instances"
  - "Segment labeling: human-readable labels (Warm-up, Main, Work N, Rest N, Cool-down) for UI display"

# Metrics
duration: 3min
completed: 2026-02-05
---

# Phase 8 Plan 1: Structured Run Types Domain Summary

**TDD-driven createWarmUpCoolDownPlan (3-segment) and createIntervalPlan (N*2+2 segment) factory methods with 32 new tests on RunPlanCalculator**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-05T15:09:52Z
- **Completed:** 2026-02-05T15:12:24Z
- **Tasks:** 2 (RED + GREEN TDD cycle)
- **Files modified:** 2

## Accomplishments
- createWarmUpCoolDownPlan produces 3-segment plans (warm-up, main, cool-down) with configurable BPM fractions and duration clamping
- createIntervalPlan produces warm-up + N*(work+rest) + cool-down plans with labeled segments and BPM derivation
- 32 new tests covering segment structure, BPM fractions, edge cases, custom params, and JSON round-trips
- All 67 tests pass (35 existing + 32 new) -- zero regressions

## Task Commits

Each task was committed atomically:

1. **Task 1: RED - Failing tests for both factories** - `f0f45c1` (test)
2. **Task 2: GREEN - Implement both factory methods** - `bd0b7dd` (feat)

No refactor phase needed -- implementation is minimal and follows existing createSteadyPlan pattern.

## Files Created/Modified
- `lib/features/run_plan/domain/run_plan_calculator.dart` - Added createWarmUpCoolDownPlan and createIntervalPlan static factory methods (+117 lines)
- `test/features/run_plan/domain/run_plan_calculator_test.dart` - Added 32 tests for both factories (+484 lines, now 834 total)

## Decisions Made
- Rest segment after every work interval (including the last) before cool-down -- avoids jarring BPM jump from work directly to cool-down pace
- roundToDouble() for all derived BPMs -- consistent with Dart numeric precision and produces clean values (e.g., 170*0.85 = 145.0)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Domain logic complete for all 3 run types (steady, warm-up/cool-down, interval)
- Plan 02 (UI) can now call these factory methods to create structured plans
- RunPlan model already supports multi-segment plans -- no model changes needed

---
*Phase: 08-structured-run-types*
*Completed: 2026-02-05*
