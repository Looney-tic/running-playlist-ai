---
phase: 23-feedback-ui-scoring
plan: 01
subsystem: domain
tags: [song-quality-scorer, playlist-generator, liked-song-boost, disliked-filter, feedback-aware]

# Dependency graph
requires:
  - phase: 22-feedback-data-layer
    provides: SongKey.normalize(), SongFeedback model, SongFeedbackNotifier, BpmSong.lookupKey
provides:
  - SongQualityScorer.score(isLiked:) liked-song scoring dimension (+5)
  - PlaylistGenerator.generate(dislikedSongKeys:, likedSongKeys:) feedback-aware generation
  - PlaylistSong.lookupKey getter for feedback matching
  - PlaylistGenerationNotifier feedback wiring across all 3 generation paths
affects: [23-02-feedback-ui, 24-playlist-freshness, 27-taste-learning]

# Tech tracking
tech-stack:
  added: []
  patterns: [feedback-aware-scoring, hard-filter-disliked, liked-boost-ranking]

key-files:
  created: []
  modified:
    - lib/features/playlist/domain/playlist.dart
    - lib/features/song_quality/domain/song_quality_scorer.dart
    - lib/features/playlist/domain/playlist_generator.dart
    - lib/features/playlist/providers/playlist_providers.dart
    - test/features/song_quality/domain/song_quality_scorer_test.dart
    - test/features/playlist/domain/playlist_generator_test.dart

key-decisions:
  - "likedSongWeight = 5 ensures liked songs rank higher but cannot overcome large quality gaps (proven by test)"
  - "Disliked songs hard-filtered (removed from candidates) rather than soft-penalized (scoring only)"

patterns-established:
  - "Feedback sets split via _readFeedbackSets() helper returning named record (disliked:, liked:)"
  - "All 3 generation paths (generate, shuffle, regenerate) must be updated together for consistency"

# Metrics
duration: 4min
completed: 2026-02-08
---

# Phase 23 Plan 01: Feedback-Aware Scoring & Filtering Summary

**Liked-song scoring boost (+5) in SongQualityScorer, disliked-song hard-filter in PlaylistGenerator, and feedback wiring across all three playlist generation paths via TDD**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-08T15:52:21Z
- **Completed:** 2026-02-08T15:56:38Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Added `isLiked` optional parameter to `SongQualityScorer.score()` with +5 boost, proven by test to not override quality gaps
- Added `dislikedSongKeys` hard-filter and `likedSongKeys` boost pass-through in `PlaylistGenerator.generate()`
- Added `PlaylistSong.lookupKey` getter delegating to `SongKey.normalize()`
- Wired `songFeedbackProvider` into all 3 generation paths (generate, shuffle, regenerate) in `PlaylistGenerationNotifier`
- 5 new tests: 3 scorer liked-boost tests + 2 generator filter/rank tests, all passing

## Task Commits

Each task was committed atomically:

1. **Task 1: TDD -- Liked-song scoring boost and disliked hard-filter** - `f2d4c94` (feat)
2. **Task 2: Wire feedback into PlaylistGenerationNotifier** - `2fca78d` (feat)

## Files Created/Modified
- `lib/features/playlist/domain/playlist.dart` - Added PlaylistSong.lookupKey getter
- `lib/features/song_quality/domain/song_quality_scorer.dart` - Added likedSongWeight constant and isLiked parameter to score()
- `lib/features/playlist/domain/playlist_generator.dart` - Added dislikedSongKeys hard-filter and likedSongKeys boost in generate()/_scoreAndRank()
- `lib/features/playlist/providers/playlist_providers.dart` - Added _readFeedbackSets() helper and wired feedback into all 3 generation methods
- `test/features/song_quality/domain/song_quality_scorer_test.dart` - 3 new liked-song boost tests
- `test/features/playlist/domain/playlist_generator_test.dart` - 2 new disliked-filter and liked-ranking tests

## Decisions Made
- `likedSongWeight = 5` chosen to provide meaningful ranking boost without overpowering quality dimensions (max quality is 46, so +5 cannot overcome a song with 10+ more quality points)
- Disliked songs are hard-filtered (completely removed from candidate pool) rather than soft-penalized via scoring, ensuring they never appear regardless of pool size

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Feedback-aware generation pipeline complete, ready for Plan 02 (Feedback UI)
- All existing tests pass (60 scorer + 21 generator = 81 total, backward compatible)
- SongQualityScorer max score updated to 51 (46 + 5 when liked) in doc comments

---
*Phase: 23-feedback-ui-scoring*
*Completed: 2026-02-08*
