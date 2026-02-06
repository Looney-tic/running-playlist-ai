---
phase: 17-curated-running-songs
plan: 02
subsystem: data
tags: [curated-songs, supabase, shared-preferences, bundled-asset, riverpod, playlist-generation]

# Dependency graph
requires:
  - phase: 17-curated-running-songs (plan 01)
    provides: CuratedSong domain model, +5 curated bonus in SongQualityScorer, curatedLookupKeys param on PlaylistGenerator
provides:
  - 300 curated running songs as bundled JSON asset covering all 15 RunningGenre values
  - CuratedSongRepository with three-tier loading (cache -> Supabase -> bundled)
  - curatedLookupKeysProvider FutureProvider for Riverpod state management
  - Full data flow wiring from bundled JSON -> repository -> provider -> generator -> scorer
affects: [18-final-polish, future curated dataset expansion via Supabase]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Three-tier data loading: SharedPreferences cache (24h TTL) -> Supabase remote fetch -> bundled asset fallback"
    - "Catch-all error handling for Supabase (AssertionError is Error, not Exception)"
    - "FutureProvider auto-caching for session-scoped async data"

key-files:
  created:
    - assets/curated_songs.json
    - lib/features/curated_songs/data/curated_song_repository.dart
    - lib/features/curated_songs/providers/curated_song_providers.dart
  modified:
    - pubspec.yaml
    - lib/features/playlist/providers/playlist_providers.dart

key-decisions:
  - "Catch-all for Supabase: Supabase.instance throws AssertionError (Error) when not initialized, requiring catch(_) instead of on Exception"
  - "300 songs with 20 per genre: exceeds 200-minimum with even distribution across all 15 RunningGenre values"
  - "BPM range 89-200: some genres (latin, funk, rnb) naturally have lower BPMs for running"

patterns-established:
  - "Curated data as graceful enhancement: try/catch around curated loading means playlist generation never fails due to curated data issues"
  - "Bundled asset as ultimate fallback: app always has curated data even on first offline launch"

# Metrics
duration: 8min
completed: 2026-02-06
---

# Phase 17 Plan 02: Curated Songs Data Layer Summary

**300 curated running songs bundled as JSON asset, CuratedSongRepository with cache/Supabase/bundled three-tier loading, and full provider wiring into PlaylistGenerationNotifier**

## Performance

- **Duration:** 8 min
- **Started:** 2026-02-06T07:25:15Z
- **Completed:** 2026-02-06T07:34:10Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments
- 300 curated running songs across all 15 RunningGenre values (20 per genre) with BPM, danceability, and energy metadata
- CuratedSongRepository with three-tier loading: SharedPreferences cache (24h TTL), Supabase remote fetch, bundled JSON asset fallback
- Full data flow wired: bundled JSON -> CuratedSongRepository -> curatedLookupKeysProvider -> PlaylistGenerationNotifier -> PlaylistGenerator.generate() -> SongQualityScorer (+5 bonus)
- All 300 existing tests pass (only pre-existing widget_test.dart failure)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create curated song dataset and asset declaration** - `44cd6ee` (feat)
2. **Task 2: Create CuratedSongRepository with three-tier loading** - `ee5b0f6` (feat)
3. **Task 3: Wire curated data into playlist generation provider** - `b279a40` (feat)

## Files Created/Modified
- `assets/curated_songs.json` - 300 curated running songs across 15 genres with BPM 89-200
- `pubspec.yaml` - Added curated_songs.json asset declaration
- `lib/features/curated_songs/data/curated_song_repository.dart` - Three-tier loading repository (cache -> Supabase -> bundled)
- `lib/features/curated_songs/providers/curated_song_providers.dart` - FutureProvider exposing Set<String> lookup keys
- `lib/features/playlist/providers/playlist_providers.dart` - PlaylistGenerationNotifier loads curated keys before generation

## Decisions Made
- Catch-all for Supabase errors: `Supabase.instance` throws `AssertionError` (an `Error`, not `Exception`) when not initialized, so catch clauses must use `catch(_)` with documented ignore to ensure graceful degradation
- 300 songs with exactly 20 per genre provides even coverage and exceeds the 200-minimum requirement
- BPM range 89-200 accommodates genres that naturally have lower running-suitable BPMs (latin, funk, rnb)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed Supabase.instance AssertionError not caught by `on Exception`**
- **Found during:** Task 3 (wire curated data into playlist generation)
- **Issue:** `Supabase.instance` throws `_AssertionError` (extends `Error`, not `Exception`) when Supabase is not initialized. The `on Exception` catch clause did not catch it, causing 3 test failures.
- **Fix:** Changed catch clauses to `catch(_)` with `// ignore: avoid_catches_without_on_clauses` and documented reason in both `curated_song_repository.dart` and `playlist_providers.dart`
- **Files modified:** `lib/features/curated_songs/data/curated_song_repository.dart`, `lib/features/playlist/providers/playlist_providers.dart`
- **Verification:** All 9 playlist_providers_test.dart tests pass; 300 total tests pass
- **Committed in:** `b279a40` (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Essential fix for correct error handling. Without this, Supabase not being initialized would crash playlist generation instead of gracefully degrading.

## Issues Encountered
None beyond the deviation documented above.

## User Setup Required

External Supabase tables require manual configuration for remote curated song updates (CURA-03). See plan frontmatter `user_setup` section:
- Create `curated_songs` table with columns: id, title, artist_name, genre, bpm, danceability, energy_level, created_at
- Create `curated_songs_version` table with columns: id, version, updated_at
- Enable RLS with SELECT-only policy for anon role

Note: The app works fully without Supabase setup -- it falls back to the bundled JSON asset.

## Next Phase Readiness
- All CURA requirements complete: bundled dataset (CURA-01), scoring integration (CURA-02), Supabase refresh (CURA-03), extensible structure (CURA-04)
- Ready for Phase 18: Final Polish
- Curated songs are a boost, never a blocker -- the app works identically without Supabase configuration

## Self-Check: PASSED

---
*Phase: 17-curated-running-songs*
*Completed: 2026-02-06*
