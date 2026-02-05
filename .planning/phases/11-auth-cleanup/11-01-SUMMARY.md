---
phase: 11-auth-cleanup
plan: 01
subsystem: ui
tags: [gorouter, flutter, riverpod, navigation, auth-cleanup]

# Dependency graph
requires:
  - phase: 01-project-foundation
    provides: GoRouter setup and initial home screen
provides:
  - Auth-free router with direct home hub launch
  - Placeholder routes for taste-profile, playlist, playlist-history
  - Home hub with 5 feature navigation buttons
affects: [12-taste-profile, 13-bpm-lookup, 14-playlist-generation, 15-polish]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "_ComingSoonScreen placeholder pattern for unbuilt feature routes"

key-files:
  created: []
  modified:
    - lib/app/router.dart
    - lib/features/home/presentation/home_screen.dart

key-decisions:
  - "Kept ConsumerWidget on HomeScreen despite removing auth ref usage (future-proofs for taste profile state)"
  - "Auth files kept dormant in lib/features/auth/ — not deleted"

patterns-established:
  - "_ComingSoonScreen: private StatelessWidget for placeholder routes, replaced as features ship"

# Metrics
duration: 1min
completed: 2026-02-05
---

# Phase 11 Plan 01: Auth Cleanup Summary

**Removed Spotify auth gate from router and home screen, built 5-button home hub with Coming Soon placeholders for unbuilt features**

## Performance

- **Duration:** 1 min
- **Started:** 2026-02-05T16:15:35Z
- **Completed:** 2026-02-05T16:16:56Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Stripped AuthNotifier class, authNotifierProvider, auth redirects, and /login route from router
- Added three placeholder routes (/taste-profile, /playlist, /playlist-history) with _ComingSoonScreen
- Replaced logout button with three new feature navigation buttons (Taste Profile, Generate Playlist, Playlist History)
- Home screen now serves as central hub with 5 feature buttons
- All auth files remain dormant in lib/features/auth/ for potential future use

## Task Commits

Each task was committed atomically:

1. **Task 1: Simplify router** - `42f345e` (feat)
2. **Task 2: Update home screen** - `0e5cbd3` (feat)

## Files Created/Modified
- `lib/app/router.dart` - Simplified router without auth, with 7 routes including 3 Coming Soon placeholders
- `lib/features/home/presentation/home_screen.dart` - Home hub with 5 feature navigation buttons, no auth UI

## Decisions Made
- Kept HomeScreen as ConsumerWidget (not downgraded to StatelessWidget) to minimize future diff when taste profile state is added
- Auth directory and spotify_constants.dart left untouched as dormant code rather than deleted

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Router has /taste-profile route ready for Phase 12 to replace _ComingSoonScreen with real TasteProfileScreen
- Router has /playlist route ready for Phase 14 to replace with playlist generation screen
- Router has /playlist-history route ready for Phase 14 or 15
- Home screen navigation buttons already wired to correct routes
- AUTH-10 (remove auth gate) and AUTH-11 (home hub navigation) satisfied

---
*Phase: 11-auth-cleanup*
*Completed: 2026-02-05*
