---
phase: 33-spotify-playlist-import
plan: 02
subsystem: spotify-import-ui
tags: [spotify, playlist, import, flutter, riverpod, go-router, multi-select]

# Dependency graph
requires:
  - phase: 33-spotify-playlist-import
    provides: "SpotifyPlaylistService, SpotifyPlaylistInfo, SpotifyPlaylistTrack, addSongs batch method"
  - phase: 31-spotify-auth
    provides: "SpotifyConnectionStatus, spotifyConnectionStatusSyncProvider"
  - phase: 28-running-songs
    provides: "RunningSong model, RunningSongNotifier, runningSongProvider"
provides:
  - "SpotifyPlaylistsScreen - browsable playlist list with cover images"
  - "SpotifyPlaylistTracksScreen - track selector with multi-select import"
  - "GoRouter routes /spotify-playlists and /spotify-playlists/:id"
  - "Conditional 'Import from Spotify' entry point on Running Songs screen"
affects: [spotify-import-flow, running-songs-screen, user-experience]

# Tech tracking
tech-stack:
  added: []
  patterns: ["ConsumerStatefulWidget with manual loading state for async service calls", "Conditional AppBar actions based on provider state"]

key-files:
  created:
    - lib/features/spotify_import/presentation/spotify_playlists_screen.dart
    - lib/features/spotify_import/presentation/spotify_playlist_tracks_screen.dart
  modified:
    - lib/app/router.dart
    - lib/features/running_songs/presentation/running_songs_screen.dart

key-decisions:
  - "Extracted _appBarActions helper to avoid duplicating conditional import button across empty/populated states"
  - "URI-encoded playlist name in query parameter for safe navigation"
  - "Track selection by index (Set<int>) rather than by ID for simpler state management"
  - "Image.network with errorBuilder fallback to placeholder for broken cover URLs"

patterns-established:
  - "ConsumerStatefulWidget loading pattern: _loading/_error/data state with initState async call"
  - "Conditional AppBar action: watch provider in build, pass status to helper method"

# Metrics
duration: 3min
completed: 2026-02-09
---

# Phase 33 Plan 02: Spotify Playlist Import UI Summary

**Two-screen playlist import flow (browser + multi-select track selector) with GoRouter routes and conditional Running Songs entry point**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-09T12:25:59Z
- **Completed:** 2026-02-09T12:28:44Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- SpotifyPlaylistsScreen with playlist cards showing cover images, names, track counts, and owner info
- SpotifyPlaylistTracksScreen with multi-select checkboxes, already-imported indicators (green check), select all/deselect all, duration formatting, and batch import via addSongs
- GoRouter nested routes for /spotify-playlists and /spotify-playlists/:id with query parameter for playlist name
- Conditional "Import from Spotify" cloud_download button in Running Songs screen AppBar (visible only when Spotify connected)

## Task Commits

Each task was committed atomically:

1. **Task 1: SpotifyPlaylistsScreen and SpotifyPlaylistTracksScreen** - `313d0fe` (feat)
2. **Task 2: Router wiring and Running Songs screen import entry point** - `3bce549` (feat)

## Files Created/Modified
- `lib/features/spotify_import/presentation/spotify_playlists_screen.dart` - Playlist browser screen with cards, cover images, loading/error/empty states
- `lib/features/spotify_import/presentation/spotify_playlist_tracks_screen.dart` - Track selector with checkboxes, already-imported indicators, batch import button
- `lib/app/router.dart` - Added /spotify-playlists and nested :id routes
- `lib/features/running_songs/presentation/running_songs_screen.dart` - Added conditional import button, extracted _appBarActions helper

## Decisions Made
- Extracted `_appBarActions` helper method to share conditional import button logic across both empty-state and populated Scaffold branches
- Used URI encoding for playlist name query parameter (`Uri.encodeComponent`) for safe navigation with special characters
- Track selection stored as `Set<int>` of indices rather than IDs for simpler state management (tracks have no unique ID field)
- `Image.network` uses `errorBuilder` to gracefully fall back to placeholder icons when cover image URLs fail to load

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - UI screens use mock data via MockSpotifyPlaylistService. No external configuration needed.

## Next Phase Readiness
- Full Spotify playlist import flow complete: browse playlists -> select tracks -> import to Songs I Run To
- Phase 33 (final phase of v1.4) is now complete
- All Spotify features (auth, search, playlist import) use mocks; ready for live testing when Spotify Developer Dashboard opens

## Self-Check: PASSED

- All created files exist on disk
- Both task commits (313d0fe, 3bce549) found in git log
- dart analyze passes with no errors or warnings

---
*Phase: 33-spotify-playlist-import*
*Completed: 2026-02-09*
