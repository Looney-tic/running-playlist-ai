---
phase: 13-bpm-data-pipeline
plan: 01
subsystem: api
tags: [http, bpm, getsongbpm, domain-model, api-client]

# Dependency graph
requires:
  - phase: 01-project-foundation
    provides: Flutter project structure, pubspec.yaml, macOS entitlements
provides:
  - BpmSong domain model with API and cache serialization
  - BpmMatchType enum for exact/half/double-time classification
  - BpmMatcher for computing half/double-time BPM query values
  - GetSongBpmClient HTTP client for GetSongBPM API
  - BpmApiException for typed error handling
  - macOS network.client entitlement for outbound HTTP
affects: [13-02-cache-providers, 14-playlist-generation]

# Tech tracking
tech-stack:
  added: [http ^1.6.0]
  patterns: [http.Client injection for testability, MockClient in tests, pure Dart domain models]

key-files:
  created:
    - lib/features/bpm_lookup/domain/bpm_song.dart
    - lib/features/bpm_lookup/domain/bpm_matcher.dart
    - lib/features/bpm_lookup/data/getsongbpm_client.dart
    - test/features/bpm_lookup/domain/bpm_song_test.dart
    - test/features/bpm_lookup/domain/bpm_matcher_test.dart
    - test/features/bpm_lookup/data/getsongbpm_client_test.dart
  modified:
    - pubspec.yaml
    - pubspec.lock
    - macos/Runner/DebugProfile.entitlements
    - macos/Runner/Release.entitlements
    - .env

key-decisions:
  - "toJson excludes matchType to avoid cache key collisions (per RESEARCH.md Pitfall 5)"
  - "BpmMatcher bounds: minQueryBpm=40, maxQueryBpm=300 for practical API coverage"
  - "http.Client constructor injection pattern for testability with MockClient"

patterns-established:
  - "Pure Dart domain models: no Flutter imports in domain layer"
  - "http.Client injection: production code accepts optional Client, tests inject MockClient"
  - "BpmApiException: typed exception for API error handling"

# Metrics
duration: 4min
completed: 2026-02-05
---

# Phase 13 Plan 01: BPM Data Pipeline Foundation Summary

**BpmSong/BpmMatcher domain models, GetSongBpmClient HTTP client with MockClient injection, and 33 unit tests covering API parsing, half/double-time matching, and error handling**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-05T17:22:38Z
- **Completed:** 2026-02-05T17:26:42Z
- **Tasks:** 3
- **Files modified:** 10

## Accomplishments
- BpmSong model with dual factories: fromApiJson (API response with string tempo, nested objects) and fromJson (cache format); toJson deliberately excludes matchType to prevent cache collisions
- BpmMatcher.bpmQueries computes exact/half/double-time BPM values with 40-300 bounds, enabling half-time song discovery (e.g., 85 BPM songs for 170 cadence)
- GetSongBpmClient with http.Client injection, 10s timeout, BpmApiException on non-200 responses, and correct URL construction for api.getsongbpm.com/tempo/
- 33 unit tests all passing with zero analyzer warnings

## Task Commits

Each task was committed atomically:

1. **Task 1: Add http dependency and macOS network entitlements** - `f07cde5` (chore)
2. **Task 2: Create BpmSong model, BpmMatchType enum, and BpmMatcher** - `ff7dcd3` (feat)
3. **Task 3: Create GetSongBpmClient and all unit tests** - `4491615` (feat)

## Files Created/Modified
- `lib/features/bpm_lookup/domain/bpm_song.dart` - BpmSong model and BpmMatchType enum with fromJson/fromApiJson/toJson/withMatchType
- `lib/features/bpm_lookup/domain/bpm_matcher.dart` - BpmMatcher.bpmQueries static method for half/double-time computation
- `lib/features/bpm_lookup/data/getsongbpm_client.dart` - GetSongBpmClient HTTP client and BpmApiException
- `test/features/bpm_lookup/domain/bpm_song_test.dart` - 14 tests for BpmMatchType enum, BpmSong factories, serialization, withMatchType
- `test/features/bpm_lookup/domain/bpm_matcher_test.dart` - 8 tests for BpmMatcher constants and bpmQueries boundary conditions
- `test/features/bpm_lookup/data/getsongbpm_client_test.dart` - 11 tests for URL construction, response parsing, error handling
- `pubspec.yaml` - Added http ^1.6.0 dependency
- `macos/Runner/DebugProfile.entitlements` - Added com.apple.security.network.client
- `macos/Runner/Release.entitlements` - Added com.apple.security.network.client
- `.env` - Added GETSONGBPM_API_KEY= placeholder (gitignored)

## Decisions Made
- toJson excludes matchType per RESEARCH.md Pitfall 5: match type is contextual (depends on current target BPM vs cached song BPM), so storing it would create cache key collisions. Assigned at load time by the lookup notifier instead.
- BpmMatcher bounds set to minQueryBpm=40, maxQueryBpm=300 for practical API coverage range.
- http.Client constructor injection pattern chosen for testability: production creates default Client, tests inject MockClient.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed analyzer warnings for lint compliance**
- **Found during:** Task 3 (unit tests)
- **Issue:** very_good_analysis flagged inference_failure_on_collection_literal on empty list literals, lines_longer_than_80_chars on imports/comments, comment_references on MockClient doc reference, and avoid_redundant_argument_values on default matchType
- **Fix:** Added `<dynamic>[]` type annotation, split long imports with string concatenation, shortened comment dividers, changed `[MockClient]` to backtick-quoted, removed redundant `matchType: BpmMatchType.exact` argument
- **Files modified:** getsongbpm_client.dart, getsongbpm_client_test.dart, bpm_song_test.dart
- **Verification:** `dart analyze` reports zero issues
- **Committed in:** 4491615 (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (1 bug - lint compliance)
**Impact on plan:** Minor formatting fixes for strict linting. No scope creep.

## Issues Encountered
- `.env` is gitignored (expected for secrets), so the GETSONGBPM_API_KEY placeholder edit was applied locally but not committed. Users must manually add this key to their `.env`.

## User Setup Required
- Add a valid GetSongBPM API key to `.env` as `GETSONGBPM_API_KEY=your-key-here` before Plan 13-02 integration testing.

## Next Phase Readiness
- Domain models and API client ready for Plan 13-02 (cache layer + providers)
- Plan 13-02 will build SharedPreferences cache, cache-first lookup notifier, and Riverpod providers on top of these foundations
- No blockers -- all production and test code compiles and passes

---
*Phase: 13-bpm-data-pipeline*
*Completed: 2026-02-05*
