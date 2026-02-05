---
phase: 05-stride-cadence
plan: 02
subsystem: presentation
tags: [riverpod, shared-preferences, ui, stride, cadence, go-router]

# Dependency graph
requires:
  - phase: 05-01
    provides: StrideCalculator, parsePace, formatPace
provides:
  - StrideNotifier + StrideState for stride/cadence state management
  - StridePreferences for persistent height and calibration storage
  - StrideScreen with pace dropdown, height slider, calibration flow, cadence display
  - /stride route in GoRouter
  - Navigation from home screen to stride screen
affects: [06-steady-run-planning (cadence output for BPM matching)]

# Tech tracking
tech-stack:
  added: [shared_preferences]
  patterns: [state-notifier, shared-preferences-persistence, dropdown-pace-input]

key-files:
  created:
    - lib/features/stride/providers/stride_providers.dart
    - lib/features/stride/data/stride_preferences.dart
    - lib/features/stride/presentation/stride_screen.dart
  modified:
    - lib/app/router.dart
    - lib/features/home/presentation/home_screen.dart
    - lib/features/stride/domain/stride_calculator.dart
    - test/features/stride/domain/stride_calculator_test.dart

key-decisions:
  - "Step/stride formula corrected: height*0.65 returns step length, cadenceFromSpeedAndStride *2 removed, defaultStrideLengthFromSpeed recalibrated to 0.26*speed+0.25"
  - "Pace input changed from TextFormField to dropdown (3:00-10:00 in 15s increments) per user feedback"
  - "/stride route made public (no auth guard) while Spotify auth is blocked"

patterns-established:
  - "SharedPreferences persistence pattern: static methods, store doubles, remove key for null"
  - "StateNotifier with async init: load from preferences in constructor, persist on mutation"
  - "Dropdown for constrained numeric input instead of free-text M:SS parsing"

# Metrics
duration: 6min
completed: 2026-02-05
---

# Phase 5 Plan 02: Stride Screen UI Summary

**Riverpod state management, SharedPreferences persistence, and full stride calculator UI with pace dropdown, height slider, calibration flow, and real-time cadence display**

## Performance

- **Duration:** 6 min
- **Started:** 2026-02-05
- **Completed:** 2026-02-05
- **Tasks:** 2 auto + 1 checkpoint (approved with fixes)
- **Files modified:** 7

## Accomplishments
- StridePreferences class persists height and calibration to SharedPreferences
- StrideState/StrideNotifier with reactive cadence computation via StrideCalculator
- StrideScreen with pace dropdown (3:00-10:00), height slider (140-210cm), calibration section
- Real-time cadence display updates as pace/height change
- Calibration overrides formula; clear calibration restores it
- /stride route registered in GoRouter, navigation button on home screen
- Domain formula corrected during checkpoint (step/stride inconsistency fixed)

## Task Commits

1. **Persistence, providers, route wiring** - `658f7e2` (feat)
2. **Stride screen UI + home navigation** - `73925ad` (feat)
3. **Domain fix + dropdown + auth bypass** - `7a1778a` (fix, post-checkpoint)

## Deviations from Plan

### Post-Checkpoint Fixes

**1. [Critical] Step/stride formula inconsistency**
- **Found during:** Human verification (cadence always showed 200 spm)
- **Root cause:** strideLengthFromHeight returns step length (~1.1m for 170cm) but cadenceFromSpeedAndStride multiplied by 2 assuming stride length input. All paces faster than 5:40 clamped to 200.
- **Fix:** Removed *2 from cadenceFromSpeedAndStride, recalibrated defaultStrideLengthFromSpeed from 0.4*speed+0.6 to 0.26*speed+0.25 (step length). Updated all 33 tests.
- **Result:** 5:30/km now shows ~175 spm, changes are visible across full pace range

**2. [UX] Pace input changed to dropdown**
- **Found during:** Human verification (user couldn't figure out M:SS text input)
- **Fix:** Replaced TextFormField with DropdownButton, options from 3:00-10:00 in 15s increments
- **Result:** One-tap pace selection, immediate cadence update

**3. [Testing] /stride route made public**
- **Found during:** Human verification (auth blocked, couldn't reach stride screen)
- **Fix:** Added /stride to public routes in router redirect logic
- **Note:** Temporary while Spotify auth is blocked. Will be re-evaluated when Phase 2 completes.

## Issues Encountered
- Spotify auth blocked all routes, preventing stride screen testing. Workaround: made /stride public.
- Step/stride formula bug was in the research-specified code, not an implementation error. The research treated height*0.65 as stride length when it's actually step length.

## User Setup Required
None.

## Next Phase Readiness
- strideNotifierProvider exposes cadence for consumption by Phase 6 (steady run planning)
- StrideCalculator.calculateCadence available as pure function for BPM target calculation
