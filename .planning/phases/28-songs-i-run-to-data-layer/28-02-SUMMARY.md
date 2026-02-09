---
phase: 28-songs-i-run-to-data-layer
plan: 02
subsystem: ui
tags: [flutter, riverpod, go-router, bottom-sheet, running-songs]

# Dependency graph
requires:
  - phase: 28-songs-i-run-to-data-layer
    plan: 01
    provides: RunningSong model, RunningSongNotifier, runningSongProvider
provides:
  - RunningSongsScreen with sorted list view, remove action, and empty state
  - SongTile "Add to Songs I Run To" / "Remove from Songs I Run To" bottom sheet action
  - GoRoute /running-songs in app router
  - Home screen navigation button for Songs I Run To
affects: [playlist-generation, song-curation-ux]

# Tech tracking
tech-stack:
  added: []
  patterns: [running-songs-screen-consumer-widget, bottom-sheet-ref-capture]

key-files:
  created:
    - lib/features/running_songs/presentation/running_songs_screen.dart
  modified:
    - lib/features/playlist/presentation/widgets/song_tile.dart
    - lib/app/router.dart
    - lib/features/home/presentation/home_screen.dart

key-decisions:
  - "Captured WidgetRef before showModalBottomSheet to access providers inside builder closure"
  - "Used sheetContext for Navigator.pop and outer context for ScaffoldMessenger.showSnackBar"

patterns-established:
  - "Bottom sheet ref pattern: capture ref before showModalBottomSheet, use in builder closure"

# Metrics
duration: 3min
completed: 2026-02-09
---

# Phase 28 Plan 02: Songs I Run To UI Layer Summary

**RunningSongsScreen with sorted list/empty state, SongTile add/remove action with SnackBar feedback, /running-songs route, and home screen navigation**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-09T09:52:06Z
- **Completed:** 2026-02-09T09:55:00Z
- **Tasks:** 2
- **Files created:** 1
- **Files modified:** 3

## Accomplishments
- RunningSongsScreen displays songs sorted by most recently added with remove buttons
- Empty state shows heart icon, "No Running Songs Yet" heading, and guidance text
- SongTile bottom sheet toggles between "Add to" and "Remove from Songs I Run To" with SnackBar confirmation
- /running-songs route registered in GoRouter and accessible from home screen

## Task Commits

Each task was committed atomically:

1. **Task 1: RunningSongsScreen with list view, remove action, and empty state** - `ad457b6` (feat)
2. **Task 2: Add-to-running-songs action in SongTile and route/navigation wiring** - `2747353` (feat)

## Files Created/Modified
- `lib/features/running_songs/presentation/running_songs_screen.dart` - Screen with sorted list view, card layout, remove action, and empty state
- `lib/features/playlist/presentation/widgets/song_tile.dart` - Added "Add to Songs I Run To" / "Remove from Songs I Run To" in play options bottom sheet
- `lib/app/router.dart` - Registered /running-songs GoRoute
- `lib/features/home/presentation/home_screen.dart` - Added "Songs I Run To" navigation button with heart icon

## Decisions Made
- Captured WidgetRef before showModalBottomSheet to access providers inside builder closure (bottom sheet runs in different build context)
- Used sheetContext for Navigator.pop and outer context for ScaffoldMessenger.showSnackBar to ensure SnackBar appears on the main scaffold

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 28 complete: data layer + UI layer both shipped
- "Songs I Run To" feature is fully functional end-to-end
- Ready for next phase in v1.4 milestone

## Self-Check: PASSED

All 1 created file and 3 modified files verified present. Both task commits (ad457b6, 2747353) verified in git log.

---
*Phase: 28-songs-i-run-to-data-layer*
*Completed: 2026-02-09*
