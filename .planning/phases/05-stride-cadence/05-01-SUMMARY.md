---
phase: 05-stride-cadence
plan: 01
subsystem: domain
tags: [dart, biomechanics, cadence, stride, tdd, pure-functions]

# Dependency graph
requires:
  - phase: none
    provides: standalone pure computation with no project dependencies
provides:
  - StrideCalculator class with static pure functions for pace-to-cadence conversion
  - parsePace and formatPace helpers for M:SS string handling
  - Tested step-vs-stride correctness (cadence in steps/min, not strides/min)
affects: [05-02 (cadence input UI), 06-playlist-generation (BPM matching from cadence)]

# Tech tracking
tech-stack:
  added: []
  patterns: [pure-domain-logic, static-calculator-class, tdd-red-green]

key-files:
  created:
    - lib/features/stride/domain/stride_calculator.dart
    - test/features/stride/domain/stride_calculator_test.dart
  modified: []

key-decisions:
  - "Test expectations adjusted for clamping boundaries: 15:00 min/km needed for lower clamp, 7:00 min/km with 170cm height for height differentiation test"
  - "No refactor phase needed -- implementation matched research spec exactly"

patterns-established:
  - "Pure domain logic pattern: zero Flutter imports, static methods on calculator class, top-level helpers for parsing"
  - "TDD for domain logic: RED (stub + 33 failing tests) -> GREEN (implement + fix expectations) -> skip REFACTOR (clean already)"

# Metrics
duration: 3min
completed: 2026-02-05
---

# Phase 5 Plan 01: Stride Calculator Domain Logic Summary

**Pure Dart stride/cadence calculator with 33 TDD-driven tests covering pace-to-speed, height-based stride estimation, speed-based fallback, step-vs-stride cadence, 150-200 spm clamping, and M:SS pace parsing**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-05T11:39:43Z
- **Completed:** 2026-02-05T11:42:28Z
- **Tasks:** 1 feature (TDD: RED + GREEN, REFACTOR skipped)
- **Files modified:** 2

## Accomplishments
- StrideCalculator class with 5 static pure functions for running biomechanics computation
- parsePace/formatPace top-level helpers for M:SS string conversion with full validation
- 33 unit tests covering all 7 functions including edge cases (zero, negative, clamping boundaries)
- Step-vs-stride correctness verified: cadence output is in steps/min (stride frequency * 2)
- Zero Flutter dependencies in domain file -- pure Dart only

## Task Commits

Each task was committed atomically:

1. **RED: Failing tests for stride calculator** - `a4839ab` (test)
2. **GREEN: Implement stride calculator domain logic** - `3becc11` (feat)

_REFACTOR phase skipped -- implementation matched research spec, no cleanup needed._

## Files Created/Modified
- `lib/features/stride/domain/stride_calculator.dart` - Pure Dart calculator: paceToSpeed, strideLengthFromHeight, defaultStrideLengthFromSpeed, cadenceFromSpeedAndStride, calculateCadence, parsePace, formatPace
- `test/features/stride/domain/stride_calculator_test.dart` - 33 unit tests grouped by function with edge cases (234 lines)

## Decisions Made

- **Test boundary values adjusted:** Plan specified 9:00 min/km for lower clamp and 5:00 with 190cm for height differentiation, but the formulas produce values that both clamp to 200 or stay above 150 at those inputs. Adjusted to 15:00 min/km (hits 150 clamp) and 7:00 min/km with 170cm (produces meaningfully different clamped vs unclamped values). The implementation is correct per research spec -- only the test inputs needed adjustment.
- **No refactor phase:** Code already clean and minimal from research spec. Doc comments present on all public APIs.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed test expectations for clamping boundary values**
- **Found during:** GREEN phase (test execution)
- **Issue:** Plan-specified test inputs (9:00 min/km for lower clamp, 5:00 with 190cm for height differentiation) did not actually exercise the expected behavior. At 9:00 min/km the natural cadence is ~166 spm (above 150 clamp). At 5:00 min/km both height and no-height paths clamp to 200.
- **Fix:** Changed to 15:00 min/km (natural cadence ~128 spm, clamps to 150) and 7:00 min/km with 170cm (height path clamps to 200, no-height path produces 184 spm -- different values).
- **Files modified:** test/features/stride/domain/stride_calculator_test.dart
- **Verification:** All 33 tests pass with corrected inputs
- **Committed in:** 3becc11 (GREEN phase commit)

---

**Total deviations:** 1 auto-fixed (1 bug in test expectations)
**Impact on plan:** Test expectations corrected to match actual formula behavior. No scope creep. Implementation unchanged.

## Issues Encountered
None -- implementation matched research spec exactly. Only test input values needed adjustment.

## User Setup Required
None -- no external service configuration required.

## Next Phase Readiness
- StrideCalculator is ready for consumption by Phase 5 Plan 02 (cadence input UI)
- All exports available: StrideCalculator class, parsePace(), formatPace()
- Import path: `package:running_playlist_ai/features/stride/domain/stride_calculator.dart`

---
*Phase: 05-stride-cadence*
*Completed: 2026-02-05*
