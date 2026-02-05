---
phase: 15-playlist-history
plan: 01
subsystem: playlist-history-data
tags: [playlist, persistence, SharedPreferences, StateNotifier, auto-save]
depends_on:
  requires: [14-01, 14-02]
  provides: [Playlist model with id/distanceKm/paceMinPerKm, PlaylistHistoryPreferences, PlaylistHistoryNotifier, auto-save hook]
  affects: [15-02]
tech-stack:
  added: []
  patterns: [single-key-list SharedPreferences storage, fire-and-forget auto-save with unawaited()]
key-files:
  created:
    - lib/features/playlist/data/playlist_history_preferences.dart
    - lib/features/playlist/providers/playlist_history_providers.dart
    - test/features/playlist/data/playlist_history_preferences_test.dart
    - test/features/playlist/providers/playlist_history_providers_test.dart
  modified:
    - lib/features/playlist/domain/playlist.dart
    - lib/features/playlist/domain/playlist_generator.dart
    - lib/features/playlist/providers/playlist_providers.dart
    - test/features/playlist/domain/playlist_test.dart
    - test/features/playlist/domain/playlist_generator_test.dart
decisions:
  - "Playlist.id is nullable String? for backward compat with old JSON"
  - "toJson conditionally includes id, distanceKm, paceMinPerKm (null fields omitted)"
  - "Auto-save uses unawaited() -- fire-and-forget after UI state is set"
  - "History capped at 50 playlists, trimmed on save (oldest dropped)"
  - "Single-key JSON list pattern (not prefix-per-entry) for bounded playlist history"
metrics:
  duration: 3m
  completed: 2026-02-05
---

# Phase 15 Plan 01: Playlist History Data Layer Summary

**One-liner:** Extended Playlist model with id/distanceKm/paceMinPerKm, SharedPreferences persistence for history list, StateNotifier provider, and auto-save hook in generation flow.

## What Was Done

### Task 1: Extend Playlist model and PlaylistGenerator (5324b53)
- Added `id` (String?), `distanceKm` (double?), `paceMinPerKm` (double?) fields to `Playlist`
- Updated `fromJson` with null-safe parsing for backward compatibility
- Updated `toJson` to conditionally include new fields (null fields omitted)
- Updated `PlaylistGenerator.generate()` to populate all three fields from `RunPlan`
- Added 4 new tests: round-trip with history fields, backward compat, null omission, generator field assignment

### Task 2: Persistence, provider, auto-save hook (4e4eaf6)
- Created `PlaylistHistoryPreferences` with single-key JSON list storage (`playlist_history` key)
- Implemented `maxHistorySize = 50` cap with trimming on save
- Created `PlaylistHistoryNotifier` extending `StateNotifier<List<Playlist>>` with async load, add, delete
- Created `playlistHistoryProvider` as `StateNotifierProvider`
- Added auto-save hook in `PlaylistGenerationNotifier.generatePlaylist()` using `unawaited()`
- Added 4 preference tests (null load, round-trip, trim, clear) and 4 notifier tests (empty start, add, delete, persistence reload)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed 3 static analysis warnings**
- `comment_references`: Changed `[TasteProfilePreferences]` to backtick-quoted in doc comment (not imported)
- `directives_ordering`: Reordered imports alphabetically in `playlist_providers.dart`
- `unawaited_futures`: Wrapped auto-save call in `unawaited()` to satisfy very_good_analysis lint

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| `unawaited()` for auto-save | UI state is already updated; persistence is fire-and-forget. Avoids blocking the generation completion flow. |
| Nullable `id` field | Backward compatibility with any JSON that lacks the field (defensive, even though no pre-existing history data exists) |
| Single-key list storage | Playlist history is always loaded as a whole for display, unlike BPM cache which is accessed per-key. Follows TasteProfilePreferences pattern. |

## Verification Results

- `flutter test test/features/playlist/` -- 49 tests, all passing
- `flutter analyze lib/features/playlist/` -- 0 issues

## Next Phase Readiness

Plan 15-02 can proceed immediately. It has:
- `PlaylistHistoryNotifier` and `playlistHistoryProvider` ready for UI binding
- `Playlist.id` for detail screen navigation via path parameter
- `Playlist.distanceKm` and `Playlist.paceMinPerKm` for history list subtitle display
- Auto-save already wired -- playlists will appear in history after generation
