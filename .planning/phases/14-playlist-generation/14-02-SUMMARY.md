---
phase: 14-playlist-generation
plan: 02
subsystem: api
tags: [riverpod, state-management, url_launcher, android-manifest, cache]

# Dependency graph
requires:
  - phase: 14-01
    provides: "Playlist, PlaylistSong, PlaylistGenerator, SongLinkBuilder domain models"
  - phase: 13-01
    provides: "GetSongBpmClient, BpmCachePreferences, BpmMatcher, BpmSong"
  - phase: 13-02
    provides: "getSongBpmClientProvider, BpmLookupNotifier pattern"
provides:
  - "PlaylistGenerationNotifier with batch multi-BPM cache-first fetching"
  - "PlaylistGenerationState with idle/loading/loaded/error states"
  - "playlistGenerationProvider wired to getSongBpmClientProvider"
  - "url_launcher as direct dependency in pubspec.yaml"
  - "Android manifest HTTPS intent query for url_launcher"
affects: [14-03, 15-polish]

# Tech tracking
tech-stack:
  added: [url_launcher ^6.3.2]
  patterns: [batch-multi-bpm-fetching, cache-first-with-rate-limiting, pre-populate-shared-preferences-test-pattern]

key-files:
  created:
    - lib/features/playlist/providers/playlist_providers.dart
    - test/features/playlist/providers/playlist_providers_test.dart
  modified:
    - pubspec.yaml
    - pubspec.lock
    - android/app/src/main/AndroidManifest.xml

key-decisions:
  - "PlaylistGenerationNotifier uses GetSongBpmClient + BpmCachePreferences directly (not BpmLookupNotifier) for batch multi-BPM fetching"
  - "Pre-populate SharedPreferences mock values in tests instead of overrideWith + Future.microtask (more reliable timing)"
  - "Eagerly read notifier providers in test container to trigger async _load() before test assertions"
  - "on Exception catch-all instead of bare catch to satisfy very_good_analysis lint"

patterns-established:
  - "Pre-populate SharedPreferences test pattern: set mock values, create container, eagerly read providers, await delay"
  - "Batch BPM fetching: collect unique query BPMs across segments, cache-first with 300ms rate-limit between API calls"

# Metrics
duration: 6min
completed: 2026-02-05
---

# Phase 14 Plan 02: Playlist Generation Providers Summary

**PlaylistGenerationNotifier with batch multi-BPM cache-first fetching, 300ms rate-limit delay, idle/loading/loaded/error states, url_launcher dependency, and Android HTTPS intent query**

## Performance

- **Duration:** 6 min
- **Started:** 2026-02-05T18:24:36Z
- **Completed:** 2026-02-05T18:31:00Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- PlaylistGenerationNotifier orchestrates batch BPM fetching across all unique segment query BPMs, then runs PlaylistGenerator.generate
- Cache-first strategy with 300ms rate-limit delay between uncached API calls
- PlaylistGenerationState with idle/loading/loaded/error factory constructors
- url_launcher added as direct dependency, Android manifest updated with HTTPS intent query
- 9/9 unit tests passing covering state, generation, cache, errors, and clear

## Task Commits

Each task was committed atomically:

1. **Task 1+2: url_launcher, Android manifest, providers, tests** - `1825689` (feat)

**Plan metadata:** (pending)

## Files Created/Modified
- `lib/features/playlist/providers/playlist_providers.dart` - PlaylistGenerationState, PlaylistGenerationNotifier, playlistGenerationProvider
- `test/features/playlist/providers/playlist_providers_test.dart` - 9 unit tests for state, generation, cache, errors, clear
- `pubspec.yaml` - Added url_launcher: ^6.3.2 as direct dependency
- `pubspec.lock` - Updated with url_launcher promotion from transitive
- `android/app/src/main/AndroidManifest.xml` - Added HTTPS VIEW/BROWSABLE intent query

## Decisions Made
- **Direct client usage:** PlaylistGenerationNotifier uses GetSongBpmClient + BpmCachePreferences directly (not through BpmLookupNotifier) for batch multi-BPM fetching control
- **Test pattern:** Pre-populate SharedPreferences mock values and eagerly read notifier providers instead of using overrideWith + Future.microtask (more reliable than the plan's suggested approach)
- **on Exception catch-all:** Used `on Exception` instead of bare `catch` to satisfy very_good_analysis avoid_catches_without_on_clauses lint
- **Removed unused taste_profile domain import:** The notifier reads TasteProfile from its provider, not directly from domain

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Test timing: overrideWith + Future.microtask unreliable**
- **Found during:** Task 2 (test creation)
- **Issue:** Plan's test approach using `overrideWith` with `Future.microtask` to set RunPlan/TasteProfile failed because the microtask and async _load() have unpredictable timing. RunPlanNotifier state was still null when generatePlaylist read it.
- **Fix:** Pre-populate SharedPreferences mock values with serialized RunPlan/TasteProfile JSON before creating ProviderContainer. Eagerly read notifier providers to trigger async _load(). Await 50ms for load to complete.
- **Files modified:** test/features/playlist/providers/playlist_providers_test.dart
- **Verification:** All 9 tests pass consistently
- **Committed in:** 1825689

**2. [Rule 1 - Bug] BpmCachePreferences.save before setMockInitialValues**
- **Found during:** Task 2 (cache test)
- **Issue:** Cache test called BpmCachePreferences.save(170, ...) before _createContainer, but _createContainer calls SharedPreferences.setMockInitialValues which resets the mock instance, clearing the cached data.
- **Fix:** Moved BpmCachePreferences.save call to after container creation (after setMockInitialValues)
- **Files modified:** test/features/playlist/providers/playlist_providers_test.dart
- **Verification:** Cache test passes with apiCallCount == 1
- **Committed in:** 1825689

**3. [Rule 3 - Blocking] Analysis lint fixes for very_good_analysis**
- **Found during:** Task 2 (analysis)
- **Issue:** unused import (taste_profile domain), line length violations, bare catch clause, cascade invocation hints
- **Fix:** Removed unused import, broke long lines, changed `catch (e)` to `on Exception`, used cascade expressions
- **Files modified:** lib/features/playlist/providers/playlist_providers.dart, test/features/playlist/providers/playlist_providers_test.dart
- **Verification:** `dart analyze` reports no issues
- **Committed in:** 1825689

---

**Total deviations:** 3 auto-fixed (2 bugs, 1 blocking)
**Impact on plan:** All auto-fixes necessary for test correctness and lint compliance. No scope creep. Production code matches plan exactly; only test code and lint compliance differ.

## Issues Encountered
- SharedPreferences mock timing required careful orchestration: providers with async _load() in constructors need their mock data populated before container creation and need to be eagerly read to trigger loading

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- PlaylistGenerationNotifier + provider fully wired and tested
- UI layer (Plan 14-03) can now trigger generation via `ref.read(playlistGenerationProvider.notifier).generatePlaylist()` and display results from `ref.watch(playlistGenerationProvider)`
- url_launcher ready for external play links (Spotify/YouTube Music search URLs)
- No blockers for Plan 14-03

---
*Phase: 14-playlist-generation*
*Completed: 2026-02-05*
