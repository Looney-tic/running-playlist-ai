---
phase: 17-curated-running-songs
plan: 01
subsystem: scoring
tags: [curated-songs, song-quality-scorer, playlist-generator, tdd, domain-model]

# Dependency graph
requires:
  - phase: 16-scoring-foundation
    provides: SongQualityScorer with public weight constants and composite scoring
provides:
  - CuratedSong domain model with dual-format deserialization (camelCase + snake_case)
  - curatedBonusWeight=5 scoring dimension in SongQualityScorer
  - curatedLookupKeys parameter on PlaylistGenerator.generate()
  - Normalized lookup key format for cross-source song matching
affects: [17-02 curated data layer, future scoring tuning]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Dual-format deserialization (fromJson for bundled assets, fromSupabaseRow for Supabase)"
    - "Normalized lookup key (lowercase trimmed artist|title) for cross-source matching"
    - "Additive scoring bonus via optional bool parameter (backward-compatible extension)"

key-files:
  created:
    - lib/features/curated_songs/domain/curated_song.dart
    - test/features/curated_songs/domain/curated_song_test.dart
  modified:
    - lib/features/song_quality/domain/song_quality_scorer.dart
    - test/features/song_quality/domain/song_quality_scorer_test.dart
    - lib/features/playlist/domain/playlist_generator.dart
    - test/features/playlist/domain/playlist_generator_test.dart

key-decisions:
  - "Curated bonus weight is +5 (meaningful but not dominant vs artist match +10)"
  - "Lookup key format is 'artist|title' lowercase trimmed for O(1) Set membership"
  - "Generator receives Set<String> not List<CuratedSong> to stay pure and decoupled"

patterns-established:
  - "Curated bonus as additive scoring dimension: isCurated bool defaults false, all existing callers unaffected"
  - "CuratedSong.lookupKey matches BpmSong normalization for cross-source identification"

# Metrics
duration: 3min
completed: 2026-02-06
---

# Phase 17 Plan 01: Curated Running Songs Domain Layer Summary

**CuratedSong model with dual-format deserialization, +5 curated bonus in SongQualityScorer, and curatedLookupKeys wired into PlaylistGenerator**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-06T07:19:43Z
- **Completed:** 2026-02-06T07:23:06Z
- **Tasks:** 3
- **Files modified:** 6

## Accomplishments
- CuratedSong domain model with fromJson (camelCase), fromSupabaseRow (snake_case), normalized lookupKey, and toJson roundtrip
- SongQualityScorer extended with curatedBonusWeight=5 and isCurated optional parameter (additive, backward-compatible)
- PlaylistGenerator.generate() accepts curatedLookupKeys Set<String> and passes curated status through to scorer
- 14 new tests across 3 test suites, all 300+ existing tests pass (only pre-existing widget_test.dart failure unchanged)

## Task Commits

Each task was committed atomically:

1. **Task 1: TDD CuratedSong model** - `92e5434` (feat)
2. **Task 2: TDD curated bonus in SongQualityScorer** - `6210f04` (feat)
3. **Task 3: Wire curated lookup into PlaylistGenerator** - `016c31b` (feat)

## Files Created/Modified
- `lib/features/curated_songs/domain/curated_song.dart` - CuratedSong model with dual-format deserialization and lookupKey
- `test/features/curated_songs/domain/curated_song_test.dart` - 8 tests for model deserialization and roundtrip
- `lib/features/song_quality/domain/song_quality_scorer.dart` - Added curatedBonusWeight=5, isCurated param, _curatedBonus helper
- `test/features/song_quality/domain/song_quality_scorer_test.dart` - 4 new curated bonus tests (50 total)
- `lib/features/playlist/domain/playlist_generator.dart` - Added curatedLookupKeys param, lookup in _scoreAndRank
- `test/features/playlist/domain/playlist_generator_test.dart` - 2 new curated ranking tests

## Decisions Made
- Curated bonus weight is +5: less than artist match (+10) and genre match (+6) so user taste still dominates, but more than BPM accuracy differential (+2) so curated songs get a noticeable lift
- Generator receives Set<String> curatedLookupKeys, not List<CuratedSong>, keeping the generator pure and decoupled from the curated domain
- Lookup key format is `'artist.toLowerCase().trim()|title.toLowerCase().trim()'` for O(1) membership checks

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Domain layer complete: CuratedSong model, scoring integration, generator wiring all tested
- Ready for Plan 02: data layer (bundled JSON asset, Supabase refresh, cache, provider wiring)
- The curatedLookupKeys parameter is optional, so the app works identically until Plan 02 provides curated data

## Self-Check: PASSED

---
*Phase: 17-curated-running-songs*
*Completed: 2026-02-06*
