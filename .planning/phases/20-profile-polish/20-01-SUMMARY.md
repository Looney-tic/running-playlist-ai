---
phase: 20-profile-polish
plan: 01
subsystem: domain-models
tags: [enum-safety, deserialization, resilience, tdd]
dependency-graph:
  requires: []
  provides:
    - Safe enum deserializers with orElse fallbacks across all domain models
    - tryFromJson pattern for list-based enum parsing (RunningGenre, MusicDecade)
    - Corrupt profile/plan resilience in preferences loading
  affects:
    - 20-02 (profile polish UI -- builds on safe domain models)
    - Any future enum additions (pattern is established)
tech-stack:
  added: []
  patterns:
    - "orElse fallback on all enum fromJson methods"
    - "tryFromJson returning null for list filtering"
    - "try-catch per entry in preferences loadAll"
key-files:
  created:
    - test/features/run_plan/domain/run_plan_test.dart
  modified:
    - lib/features/taste_profile/domain/taste_profile.dart
    - lib/features/run_plan/domain/run_plan.dart
    - lib/features/bpm_lookup/domain/bpm_song.dart
    - lib/features/taste_profile/data/taste_profile_preferences.dart
    - lib/features/run_plan/data/run_plan_preferences.dart
    - test/features/taste_profile/domain/taste_profile_test.dart
    - test/features/bpm_lookup/domain/bpm_song_test.dart
decisions:
  - id: D20-01-01
    decision: "RunningGenre/MusicDecade use tryFromJson+whereType for list parsing rather than fromJson with fallback"
    rationale: "Filtering out unknown values is more correct than silently mapping them to a default genre/decade"
  - id: D20-01-02
    decision: "EnergyLevel falls back to balanced, RunType to steady, BpmMatchType to exact"
    rationale: "These are the safest neutral defaults that produce functional behavior"
metrics:
  duration: 4m
  completed: 2026-02-06
---

# Phase 20 Plan 01: Safe Enum Deserialization Summary

Hardened all enum deserializers with orElse fallbacks and filtered list parsing to survive corrupt or future-version JSON data without crashing.

## What Was Done

### TDD RED Phase
- Added failing tests for all enum fallback cases: EnergyLevel, RunningGenre, RunType, BpmMatchType
- Added tests for new tryFromJson methods on RunningGenre and MusicDecade
- Added integration tests for TasteProfile.fromJson handling unknown genres, decades, and energy levels
- Added tests for BpmSong.fromJson handling unknown matchType values
- Created new test file: run_plan_test.dart

### TDD GREEN Phase
1. **EnergyLevel.fromJson** -- added `orElse: () => EnergyLevel.balanced`
2. **RunningGenre.fromJson** -- added `orElse: () => RunningGenre.pop`
3. **RunningGenre.tryFromJson** -- new static method returning `null` for unknown values
4. **MusicDecade.tryFromJson** -- new static method returning `null` for unknown values (fromJson already had orElse)
5. **RunType.fromJson** -- added `orElse: () => RunType.steady`
6. **BpmMatchType.fromJson** -- added `orElse: () => BpmMatchType.exact`
7. **TasteProfile.fromJson** -- genres list now uses `tryFromJson + whereType<RunningGenre>()` to filter unknowns
8. **TasteProfile.fromJson** -- decades list now uses `tryFromJson + whereType<MusicDecade>()` to filter unknowns
9. **TasteProfilePreferences.loadAll** -- wrapped each profile parse in try-catch, skips corrupt entries
10. **RunPlanPreferences.loadAll** -- wrapped each plan parse in try-catch, skips corrupt entries

### TDD REFACTOR Phase
No refactoring needed -- implementation was already minimal and consistent.

## Task Commits

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| RED | Failing tests for enum fallback safety | d165f2b | taste_profile_test.dart, run_plan_test.dart, bpm_song_test.dart |
| GREEN | Implement safe enum deserializers | fc916cc | taste_profile.dart, run_plan.dart, bpm_song.dart, *_preferences.dart |

## Verification

- `dart analyze` on all 3 domain files: no issues found
- `flutter test` on all 3 test files: 93/93 tests passed
- New fallback tests cover: unknown enum values, empty strings, mixed valid/invalid JSON, full profile parsing

## Decisions Made

1. **D20-01-01:** RunningGenre and MusicDecade use `tryFromJson` + `whereType` for list parsing rather than `fromJson` with fallback. This filters out unknown values rather than silently mapping them to defaults.

2. **D20-01-02:** Scalar enum fallbacks chosen as the safest neutral defaults: EnergyLevel -> balanced, RunType -> steady, BpmMatchType -> exact. These produce functional (not broken) behavior.

## Deviations from Plan

None -- plan executed exactly as written.

## Next Phase Readiness

- All enum deserializers are now safe for forward/backward compatibility
- Preferences loading survives corrupt individual entries
- Ready for 20-02 (profile polish UI work)

## Self-Check: PASSED
