---
phase: 33-spotify-playlist-import
plan: 01
subsystem: spotify-import
tags: [spotify, playlist, riverpod, batch-import, oauth-scopes]

# Dependency graph
requires:
  - phase: 31-spotify-auth
    provides: "SpotifyAuthService, SpotifyConnectionStatus, spotifyConnectionStatusSyncProvider"
  - phase: 28-running-songs
    provides: "RunningSong model, RunningSongNotifier, RunningSongPreferences"
provides:
  - "SpotifyPlaylistService abstract interface (getUserPlaylists, getPlaylistTracks)"
  - "SpotifyPlaylistInfo and SpotifyPlaylistTrack data classes"
  - "MockSpotifyPlaylistService with 5 playlists and per-playlist tracks"
  - "RealSpotifyPlaylistService using spotify 0.15.0 API"
  - "spotifyPlaylistServiceProvider wired with connection status"
  - "RunningSongNotifier.addSongs() batch method"
  - "OAuth scopes with playlist-read-private and playlist-read-collaborative"
affects: [33-02-PLAN, spotify-import-ui, playlist-tracks-screen]

# Tech tracking
tech-stack:
  added: []
  patterns: ["SpotifyPlaylistService mock-first pattern matching SongSearchService/SpotifyAuthService"]

key-files:
  created:
    - lib/features/spotify_import/domain/spotify_playlist_service.dart
    - lib/features/spotify_import/data/mock_spotify_playlist_service.dart
    - lib/features/spotify_import/data/real_spotify_playlist_service.dart
    - lib/features/spotify_import/providers/spotify_import_providers.dart
    - test/features/spotify_import/domain/spotify_playlist_service_test.dart
  modified:
    - lib/core/constants/spotify_constants.dart
    - lib/features/running_songs/providers/running_song_providers.dart
    - test/features/running_songs/running_song_lifecycle_test.dart

key-decisions:
  - "Used abstract class (not abstract interface class) matching SongSearchService pattern"
  - "Mock service always returned (even when disconnected) since UI layer gates access"
  - "catch(_) used for real implementation to catch both Exception and Error (Supabase AssertionError pattern)"
  - "addSongs batch method updates state once and persists once for O(1) writes"

patterns-established:
  - "SpotifyPlaylistService: abstract service + mock + real implementation + provider (same as SongSearchService, SpotifyAuthService)"
  - "Batch addSongs: single state update + single persist for bulk operations"

# Metrics
duration: 4min
completed: 2026-02-09
---

# Phase 33 Plan 01: Spotify Playlist Import Service Summary

**SpotifyPlaylistService domain layer with mock/real implementations, batch addSongs on RunningSongNotifier, and OAuth playlist scopes**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-09T12:19:32Z
- **Completed:** 2026-02-09T12:24:00Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- SpotifyPlaylistService abstract interface with getUserPlaylists() and getPlaylistTracks() following established mock-first pattern
- MockSpotifyPlaylistService with 5 realistic playlists, per-playlist tracks (8-10 each), curated catalog overlaps for dedup testing
- RealSpotifyPlaylistService using spotify 0.15.0 package API with graceful degradation (catch-all returning empty lists)
- RunningSongNotifier.addSongs() batch method: single state update + single persist, deduplication, returns added count
- OAuth scopes updated with playlist-read-private and playlist-read-collaborative

## Task Commits

Each task was committed atomically:

1. **Task 1: SpotifyPlaylistService interface, data classes, mock, real implementation, and provider** - `018efbc` (feat)
2. **Task 2: Add batch addSongs method to RunningSongNotifier** - `7ca72fc` (feat)

## Files Created/Modified
- `lib/features/spotify_import/domain/spotify_playlist_service.dart` - SpotifyPlaylistInfo, SpotifyPlaylistTrack data classes and SpotifyPlaylistService abstract interface
- `lib/features/spotify_import/data/mock_spotify_playlist_service.dart` - Mock with 5 playlists, per-playlist tracks, curated overlaps
- `lib/features/spotify_import/data/real_spotify_playlist_service.dart` - Real Spotify API implementation with graceful degradation
- `lib/features/spotify_import/providers/spotify_import_providers.dart` - spotifyPlaylistServiceProvider reading connection status
- `lib/core/constants/spotify_constants.dart` - Added playlist-read-private and playlist-read-collaborative scopes
- `lib/features/running_songs/providers/running_song_providers.dart` - Added addSongs(List) batch method
- `test/features/spotify_import/domain/spotify_playlist_service_test.dart` - 12 tests for mock service and data classes
- `test/features/running_songs/running_song_lifecycle_test.dart` - 4 new addSongs batch tests

## Decisions Made
- Used `abstract class` (not `abstract interface class`) matching the SongSearchService and SpotifyAuthService pattern for Riverpod 2.x compatibility
- Mock service returned even when disconnected -- UI layer gates access based on connection status, keeping provider simple
- Real implementation uses bare `catch(_)` (not `on Exception catch(_)`) to catch both Exception and Error types per project convention (Supabase AssertionError pattern)
- addSongs batch method returns int (count of added) for UI feedback on import results

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required. OAuth scope change will take effect on next Spotify reconnect (existing tokens need disconnect + reconnect for new scopes).

## Next Phase Readiness
- Domain layer complete, ready for Plan 02 UI screens (SpotifyPlaylistsScreen, SpotifyPlaylistTracksScreen)
- spotifyPlaylistServiceProvider available for widget tree consumption
- addSongs batch method available for multi-select import from Plan 02
- Mock data includes curated catalog overlaps for dedup testing in Plan 02

---
*Phase: 33-spotify-playlist-import*
*Completed: 2026-02-09*
