---
phase: 13-bpm-data-pipeline
plan: 02
subsystem: data
tags: [shared-preferences, cache, riverpod, state-notifier, dotenv, bpm]

# Dependency graph
requires:
  - phase: 13-bpm-data-pipeline (plan 01)
    provides: BpmSong, BpmMatchType, BpmMatcher, GetSongBpmClient, BpmApiException
provides:
  - BpmCachePreferences with per-BPM SharedPreferences cache and 7-day TTL
  - BpmLookupState and BpmLookupNotifier with cache-first multi-BPM strategy
  - getSongBpmClientProvider (reads API key from dotenv)
  - bpmLookupProvider (StateNotifierProvider for reactive BPM lookup)
affects: [14-playlist-generation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Cache-first strategy: check SharedPreferences before API call"
    - "Contextual matchType assignment: raw songs cached, matchType applied at load time"
    - "Multi-BPM query merging: exact + half/double-time results combined"
    - "Comprehensive error handling with 5 distinct exception types"

key-files:
  created:
    - lib/features/bpm_lookup/data/bpm_cache_preferences.dart
    - lib/features/bpm_lookup/providers/bpm_lookup_providers.dart
    - test/features/bpm_lookup/data/bpm_cache_preferences_test.dart
    - test/features/bpm_lookup/providers/bpm_lookup_providers_test.dart
  modified: []

key-decisions:
  - "matchType excluded from cache; assigned at load time via withMatchType to avoid cache key collisions"
  - "Cache keyed by queried BPM (not target BPM) so 85 BPM songs are cached once and reused for both 85-direct and 170-halfTime lookups"
  - "getSongBpmClientProvider reads API key from dotenv.env with empty string fallback"

patterns-established:
  - "Cache-first StateNotifier: check local cache, fall back to API, save to cache, merge results"
  - "Provider chain: bpmLookupProvider -> getSongBpmClientProvider -> dotenv API key"

# Metrics
duration: 3min
completed: 2026-02-05
---

# Phase 13 Plan 02: BPM Cache & Lookup Provider Summary

**SharedPreferences BPM cache with 7-day TTL, cache-first BpmLookupNotifier merging exact + half-time queries, and bpmLookupProvider wired to dotenv API key**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-05T17:28:44Z
- **Completed:** 2026-02-05T17:31:23Z
- **Tasks:** 2
- **Files created:** 4

## Accomplishments
- BpmCachePreferences with per-BPM keys, 7-day TTL, and auto-cleanup of expired entries
- BpmLookupNotifier with cache-first strategy: checks cache before API, saves results for future lookups
- Multi-BPM query orchestration via BpmMatcher with contextual matchType assignment
- Comprehensive error handling for SocketException, TimeoutException, BpmApiException, FormatException, and catch-all
- 28 new unit tests (12 cache + 16 notifier), 59 total across Phase 13

## Task Commits

Each task was committed atomically:

1. **Task 1: Create BpmCachePreferences and its unit tests** - `8d63da6` (feat)
2. **Task 2: Create BpmLookupState, BpmLookupNotifier, provider, and unit tests** - `7a4f109` (feat)

## Files Created/Modified
- `lib/features/bpm_lookup/data/bpm_cache_preferences.dart` - Per-BPM SharedPreferences cache with 7-day TTL, save/load/clear/clearAll
- `lib/features/bpm_lookup/providers/bpm_lookup_providers.dart` - BpmLookupState, BpmLookupNotifier (cache-first), getSongBpmClientProvider, bpmLookupProvider
- `test/features/bpm_lookup/data/bpm_cache_preferences_test.dart` - 12 tests: save/load, TTL expiry, per-BPM isolation, clear, clearAll
- `test/features/bpm_lookup/providers/bpm_lookup_providers_test.dart` - 16 tests: successful lookups, cache-first behavior, error handling, clear

## Decisions Made
- matchType excluded from cache and assigned at load time via `withMatchType()` -- prevents cache key collisions where the same song at BPM 85 could be exact (when target=85) or halfTime (when target=170)
- Cache keyed by queried BPM (e.g., `bpm_cache_85`) not target BPM -- allows cache reuse across different target lookups
- `getSongBpmClientProvider` reads from `dotenv.env['GETSONGBPM_API_KEY']` with empty string fallback (no crash if key missing)
- Catch-all `catch (e)` in notifier for truly unexpected exceptions produces generic user-facing message

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no new external service configuration required. (API key setup noted in 13-01.)

## Next Phase Readiness
- Phase 13 complete: BPM data pipeline fully operational (domain models, API client, cache, state management, providers)
- Phase 14 (playlist generation) can call `ref.read(bpmLookupProvider.notifier).lookupByBpm(targetBpm)` to discover songs by BPM with automatic caching and error handling
- All Phase 13 requirements satisfied: BPM-10 (API discovery), BPM-11 (caching), BPM-12 (half/double-time), BPM-13 (error handling)
- User must add `GETSONGBPM_API_KEY` to `.env` before runtime API calls work

---
*Phase: 13-bpm-data-pipeline*
*Completed: 2026-02-05*
