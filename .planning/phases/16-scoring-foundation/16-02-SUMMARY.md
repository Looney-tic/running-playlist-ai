---
phase: 16-scoring-foundation
plan: 02
subsystem: playlist-generation
tags: [scoring, danceability, artist-diversity, playlist-generator, quality-scoring]

# Dependency graph
requires:
  - phase: 16-scoring-foundation/01
    provides: SongQualityScorer with composite scoring and enforceArtistDiversity
provides:
  - PlaylistGenerator delegates scoring to SongQualityScorer
  - BpmSong with optional danceability field (API + cache roundtrip)
  - PlaylistSong with runningQuality and isEnriched metadata
  - Artist diversity enforcement in generated playlists
  - Segment-aware energy scoring (warm-up=chill, sprint=intense)
affects: [17-taste-enhancement, 18-quality-verification]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Scorer delegation: PlaylistGenerator calls SongQualityScorer.score() for each candidate"
    - "Post-selection diversity: enforceArtistDiversity runs after scoring and selection"
    - "Forward-compatible model fields: nullable fields with JSON conditional serialization"

key-files:
  created: []
  modified:
    - lib/features/bpm_lookup/domain/bpm_song.dart
    - lib/features/playlist/domain/playlist.dart
    - lib/features/playlist/domain/playlist_generator.dart
    - test/features/bpm_lookup/domain/bpm_song_test.dart
    - test/features/playlist/domain/playlist_generator_test.dart

key-decisions:
  - "Danceability parsed as int? from API JSON (handles string or int) -- forward-compatible with endpoint availability"
  - "runningQuality stored on PlaylistSong for future UI display, isEnriched flag distinguishes real vs neutral danceability scores"
  - "Artist diversity enforcement applied post-selection (not during scoring) to preserve rank stability"
  - "Provider layer unchanged -- SongQualityScorer invoked inside PlaylistGenerator, not injected from outside"

patterns-established:
  - "Quality metadata on PlaylistSong: runningQuality + isEnriched pattern for UI quality indicators"
  - "Segment label forwarding: generator passes segment labels through to scorer for energy override"

# Metrics
duration: 5min
completed: 2026-02-05
---

# Phase 16 Plan 02: Scorer Integration Summary

**PlaylistGenerator delegates all scoring to SongQualityScorer with danceability-aware ranking, artist diversity enforcement, and segment-aware energy overrides**

## Performance

- **Duration:** 5 min
- **Started:** 2026-02-05T22:02:36Z
- **Completed:** 2026-02-05T22:07:09Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments
- BpmSong model extended with optional danceability field that parses from API and roundtrips through cache
- PlaylistSong model extended with runningQuality (composite score) and isEnriched (danceability data presence) metadata
- PlaylistGenerator refactored to delegate all scoring to SongQualityScorer, removing inline score constants
- enforceArtistDiversity called on selected songs per segment, preventing consecutive same-artist
- Warm-up/cool-down segments automatically get chill energy scoring via segment label override
- All 286 tests pass (only pre-existing widget_test.dart failure remains)

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend BpmSong and PlaylistSong models with quality fields** - `e1daede` (feat)
2. **Task 2: Integrate SongQualityScorer into PlaylistGenerator** - `a01079d` (feat)
3. **Task 3: Wire scoring through PlaylistGenerationNotifier provider** - no code changes needed (verification-only task, pipeline confirmed working)

## Files Created/Modified
- `lib/features/bpm_lookup/domain/bpm_song.dart` - Added optional danceability field with API parsing, cache serialization, and withMatchType preservation
- `lib/features/playlist/domain/playlist.dart` - Added optional runningQuality and isEnriched fields to PlaylistSong with JSON serialization
- `lib/features/playlist/domain/playlist_generator.dart` - Replaced inline scoring with SongQualityScorer delegation, added enforceArtistDiversity, passes segmentLabel and runningQuality
- `test/features/bpm_lookup/domain/bpm_song_test.dart` - Added 8 danceability tests (API parsing, serialization roundtrip, withMatchType)
- `test/features/playlist/domain/playlist_generator_test.dart` - Added 3 composite scoring tests (danceability ranking, artist diversity, warm-up energy)

## Decisions Made
- Danceability parsed from API JSON using int.tryParse on toString() to handle both string and int values from the API
- runningQuality stored as int? on PlaylistSong -- null for playlists generated before scoring was introduced (backward compatible)
- isEnriched serialized with `if (isEnriched)` conditional to keep JSON clean for non-enriched playlists
- Provider layer left unchanged since SongQualityScorer is invoked inside PlaylistGenerator, not injected externally
- Artist diversity test adjusted to ensure sufficient swap candidates (3 dominant + 3 others for 5-song playlist)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed doc comment references to unimported types**
- **Found during:** Task 1 (model extensions)
- **Issue:** Doc comments used `[SongQualityScorer]` bracket syntax in files that don't import the scorer, causing analyzer info warnings
- **Fix:** Changed bracket references to plain text references
- **Files modified:** lib/features/bpm_lookup/domain/bpm_song.dart, lib/features/playlist/domain/playlist.dart
- **Verification:** `flutter analyze` shows zero issues on both files
- **Committed in:** e1daede (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Trivial doc comment fix. No scope creep.

## Issues Encountered
- Artist diversity test initially failed with 4 dominant artist songs and only 2 alternatives in a 6-song playlist -- the enforceArtistDiversity algorithm cannot interleave when dominant songs outnumber alternatives. Adjusted test to use 3 dominant + 3 others for a 5-song playlist, which is a realistic scenario where diversity enforcement succeeds.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Scoring foundation complete: SongQualityScorer created (16-01) and integrated into PlaylistGenerator (16-02)
- All QUAL requirements active at runtime: danceability scoring, energy alignment, segment-aware energy, artist diversity
- Ready for Phase 17 (Taste Enhancement) which can leverage quality metadata for UI display
- Danceability data availability depends on GetSongBPM API endpoint -- currently parses but may receive null at runtime

## Self-Check: PASSED

---
*Phase: 16-scoring-foundation*
*Completed: 2026-02-05*
