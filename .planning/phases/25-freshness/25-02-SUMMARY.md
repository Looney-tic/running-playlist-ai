---
phase: 25-freshness
plan: 02
subsystem: domain, providers, ui
tags: [freshness, playlist-generation, riverpod, segmented-button, play-history]

# Dependency graph
requires:
  - phase: 25-freshness
    plan: 01
    provides: PlayHistory domain model, FreshnessMode enum, playHistoryProvider, freshnessModeProvider
  - phase: 23-feedback-wiring
    provides: SongQualityScorer.score isLiked pattern, PlaylistGenerator.generate likedSongKeys
provides:
  - freshnessPenalty parameter in SongQualityScorer.score()
  - playHistory parameter in PlaylistGenerator.generate()
  - Freshness wiring in all 3 generation paths (generate, shuffle, regenerate)
  - Play history recording after each generation
  - Freshness mode toggle UI (SegmentedButton) in playlist screen
affects: [26-taste-learning, playlist-quality, user-experience]

# Tech tracking
tech-stack:
  added: []
  patterns: [freshness penalty integration via optional parameter, mode-gated feature via null return]

key-files:
  created: []
  modified:
    - lib/features/song_quality/domain/song_quality_scorer.dart
    - lib/features/playlist/domain/playlist_generator.dart
    - lib/features/playlist/providers/playlist_providers.dart
    - lib/features/playlist/presentation/playlist_screen.dart

key-decisions:
  - "PlayHistory instantiated inline in _scoreAndRank to keep generator as pure Dart"
  - "_readPlayHistory returns null in optimize-for-taste mode, cleanly disabling freshness"

patterns-established:
  - "Mode-gated scoring: null parameter disables scoring dimension entirely"
  - "Consistent 3-path wiring: all generation methods must wire the same features"

# Metrics
duration: 3min
completed: 2026-02-08
---

# Phase 25 Plan 02: Freshness Integration Summary

**Freshness-aware playlist generation with per-song time-decayed penalties wired into all 3 generation paths and a SegmentedButton mode toggle for keep-it-fresh vs best-taste**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-08T17:01:12Z
- **Completed:** 2026-02-08T17:04:29Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments
- SongQualityScorer.score() accepts freshnessPenalty int parameter (0 or negative)
- PlaylistGenerator.generate() accepts playHistory map and computes per-song penalties via PlayHistory domain model
- All 3 generation paths (generate, shuffle, regenerate) wire freshness consistently: pass playHistory, record after generation
- _readPlayHistory() returns null in optimize-for-taste mode, cleanly disabling freshness penalties
- SegmentedButton toggle between "Keep it Fresh" and "Best Taste" modes in both idle and loaded views

## Task Commits

Each task was committed atomically:

1. **Task 1: Add freshnessPenalty to SongQualityScorer and PlaylistGenerator** - `18dceec` (feat)
2. **Task 2: Wire freshness into all 3 generation paths and record play history** - `7df8986` (feat)
3. **Task 3: Add freshness mode toggle to playlist screen UI** - `a8e9adb` (feat)

## Files Created/Modified
- `lib/features/song_quality/domain/song_quality_scorer.dart` - Added freshnessPenalty parameter to score(), applied after isLiked
- `lib/features/playlist/domain/playlist_generator.dart` - Added playHistory parameter, inline PlayHistory instantiation for penalty computation
- `lib/features/playlist/providers/playlist_providers.dart` - _readPlayHistory helper, freshness wiring in all 3 paths, play history recording
- `lib/features/playlist/presentation/playlist_screen.dart` - _FreshnessToggle widget with SegmentedButton in both views

## Decisions Made
- PlayHistory instantiated inline in _scoreAndRank (lightweight value object, keeps generator as pure Dart)
- _readPlayHistory returns null (not empty map) to cleanly disable freshness penalties in optimize-for-taste mode

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 25 (Playlist Freshness) fully complete: data layer + integration
- FRSH-01 (recording), FRSH-02 (ranking penalty), FRSH-03 (mode toggle) all delivered
- Ready for Phase 26 (Feedback Display) or Phase 27 (Taste Learning)

## Self-Check: PASSED

- All 4 modified files exist on disk
- All 3 task commits verified in git log (18dceec, 7df8986, a8e9adb)

---
*Phase: 25-freshness*
*Completed: 2026-02-08*
