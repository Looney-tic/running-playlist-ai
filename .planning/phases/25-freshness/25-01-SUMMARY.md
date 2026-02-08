---
phase: 25-freshness
plan: 01
subsystem: domain
tags: [freshness, play-history, tdd, riverpod, shared-preferences]

# Dependency graph
requires:
  - phase: 22-feedback-data
    provides: SongKey.normalize, SongFeedbackNotifier pattern
  - phase: 05-playlist-model
    provides: Playlist, PlaylistSong with lookupKey
provides:
  - PlayHistory domain model with time-decayed freshnessPenalty
  - FreshnessMode enum (keepItFresh, optimizeForTaste)
  - PlayHistoryPreferences and FreshnessPreferences persistence
  - playHistoryProvider and freshnessModeProvider Riverpod providers
affects: [25-02-freshness-integration, playlist-generation, song-scoring]

# Tech tracking
tech-stack:
  added: []
  patterns: [time-decayed penalty tiers, Completer-based ensureLoaded notifier]

key-files:
  created:
    - lib/features/playlist_freshness/domain/playlist_freshness.dart
    - lib/features/playlist_freshness/data/playlist_freshness_preferences.dart
    - lib/features/playlist_freshness/providers/playlist_freshness_providers.dart
    - test/features/playlist_freshness/domain/playlist_freshness_test.dart
  modified: []

key-decisions:
  - "5-tier penalty decay: 0/-8/-5/-2/0 for never/0-2d/3-6d/7-13d/14+d"
  - "30-day auto-prune on PlayHistory construction keeps storage bounded"

patterns-established:
  - "Time-decayed penalty scoring: tiered int returns based on day ranges"
  - "PlayHistory constructor pruning: entries cleaned on every construction"

# Metrics
duration: 3min
completed: 2026-02-08
---

# Phase 25 Plan 01: Freshness Data Layer Summary

**PlayHistory domain model with 5-tier time-decayed freshnessPenalty scoring, SharedPreferences persistence, and Riverpod providers following SongFeedbackNotifier pattern**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-08T16:56:32Z
- **Completed:** 2026-02-08T16:59:11Z
- **Tasks:** 4 (TDD RED/GREEN + persistence + providers)
- **Files created:** 4

## Accomplishments
- PlayHistory with freshnessPenalty returning 0/-8/-5/-2/0 across 5 time tiers
- recordPlaylist merging song entries from Playlist using lookupKey and createdAt
- 30-day auto-pruning on PlayHistory construction
- FreshnessMode enum with keepItFresh/optimizeForTaste values
- Full persistence layer for both PlayHistory and FreshnessMode
- Completer-based providers following established SongFeedbackNotifier pattern
- 13 TDD tests covering all penalty tiers, merge behavior, and pruning

## Task Commits

Each task was committed atomically:

1. **Task 1: RED - Failing tests** - `61fce55` (test)
2. **Task 2: GREEN - Domain model** - `ae41762` (feat)
3. **Task 3: Persistence layer** - `64f1223` (feat)
4. **Task 4: Providers** - `b972321` (feat)

_TDD RED->GREEN confirmed: tests failed at 61fce55, all passed at ae41762_

## Files Created/Modified
- `lib/features/playlist_freshness/domain/playlist_freshness.dart` - PlayHistory model with freshnessPenalty and FreshnessMode enum
- `lib/features/playlist_freshness/data/playlist_freshness_preferences.dart` - SharedPreferences persistence for PlayHistory and FreshnessMode
- `lib/features/playlist_freshness/providers/playlist_freshness_providers.dart` - PlayHistoryNotifier, FreshnessModeNotifier, and providers
- `test/features/playlist_freshness/domain/playlist_freshness_test.dart` - 13 unit tests for domain model

## Decisions Made
- 5-tier penalty decay (0/-8/-5/-2/0) matching the plan specification exactly
- 30-day prune threshold uses `isBefore(cutoff)` so entries exactly 30 days old are preserved
- PlayHistory entries stored as ISO 8601 strings in JSON for human-readable persistence

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- PlayHistory and FreshnessMode domain models ready for integration into SongQualityScorer
- playHistoryProvider ready for Plan 02 to wire into playlist generation pipeline
- freshnessModeProvider ready for Plan 02 to add UI toggle

## Self-Check: PASSED

- All 4 created files exist on disk
- All 4 task commits verified in git log (61fce55, ae41762, 64f1223, b972321)

---
*Phase: 25-freshness*
*Completed: 2026-02-08*
