---
phase: quick-3
plan: 01
subsystem: frontend
tags: [bugfix, ux, polish]
dependency-graph:
  requires: []
  provides: [race-condition-fix, debug-logging, visual-hierarchy, spm-terminology]
  affects: [onboarding, playlist, home, run-plan, settings]
tech-stack:
  added: []
  patterns: [ensureLoaded-before-mutations, debug-logging-in-catch-alls]
key-files:
  created: []
  modified:
    - lib/features/onboarding/presentation/onboarding_screen.dart
    - lib/features/curated_songs/data/curated_song_repository.dart
    - lib/features/playlist/providers/playlist_providers.dart
    - lib/features/playlist/presentation/playlist_screen.dart
    - lib/features/home/presentation/home_screen.dart
    - lib/features/run_plan/presentation/run_plan_screen.dart
    - lib/features/settings/presentation/settings_screen.dart
decisions: []
metrics:
  duration: 4m
  completed: 2026-02-09
---

# Quick Task 3: Fix All Frontend Bugs and UX Issues Summary

Fix 3 P0 bugs (onboarding race condition, curated song loading diagnostics, error swallowing), 1 P1 display issue, and 5 P2/P3 polish issues across 7 files with zero new lint errors.

## What Changed

### Task 1: Fix P0 onboarding race condition (c8cd450)
- Added `ensureLoaded()` calls for tasteProfileLibraryProvider and runPlanLibraryProvider at the start of `_finishOnboarding()`, before `addProfile()`/`addPlan()` calls
- This prevents the background `_load()` from overwriting freshly created onboarding data
- Changed onboarding summary from "Target BPM" / "bpm" to "Target Cadence" / "spm"

### Task 2: Fix P0 curated songs asset loading + error logging (402d1f6)
- Wrapped `CuratedSongRepository._loadBundledAsset()` in try/catch with `debugPrint` for web loading failure diagnostics
- Added `debugPrint` error logging with stack traces to `generatePlaylist()` and `regeneratePlaylist()` catch-all blocks (previously silently swallowed all errors)

### Task 3: Fix cadence nudge icons on playlist screen (2f455c5)
- Replaced duplicate `Icons.remove`/`Icons.add` with distinct directional icons:
  - -3 spm: `keyboard_double_arrow_left`
  - -1 spm: `chevron_left`
  - +1 spm: `chevron_right`
  - +3 spm: `keyboard_double_arrow_right`
- Unified all icon sizes to 20

### Task 4: Redesign home screen with visual hierarchy (f3080d5)
- Replaced flat list of 7 `ElevatedButton.icon` with structured layout
- Primary action: full-width `FilledButton.icon` for "Generate Playlist"
- Configuration section: Card with ListTiles for Stride Calculator, My Runs, Taste Profiles
- Library section: Card with ListTiles for Playlist History, Song Feedback, Songs I Run To
- Applied same distinct directional icons to home screen cadence nudge controls

### Task 5: Standardize spm terminology + default distance (cefaa64)
- Changed all user-facing cadence displays in run_plan_screen from "bpm" to "spm"
- Changed "Target BPM" label to "Target Cadence"
- Changed segment timeline tooltips from "bpm" to "spm"
- Pre-selected 5K distance (`_selectedPresetIndex = 0`, `_selectedDistance = 5.0`) so Save button is enabled on screen load

### Task 6: Add About section to Settings screen (251fe19)
- Added `_AboutSection` widget below Spotify section
- Shows app name ("Running Playlist AI"), version ("1.0.0"), and description
- Styled with `surfaceContainerHighest` background matching Spotify section

## Deviations from Plan

None - plan executed exactly as written.

## Verification

- `dart analyze lib/` shows 0 errors, 0 warnings (71 pre-existing info-level lints)
- All 7 modified files pass individual analysis
