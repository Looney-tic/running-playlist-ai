# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-08)

**Core value:** A runner enters their run plan and gets a playlist where every song's beat matches their footstrike cadence
**Current focus:** v1.4 milestone complete -- Spotify playlist import UI shipped

## Current Position

Phase: 33 (sixth of 6 in v1.4) -- Complete
Plan: 02 of 2 complete
Status: v1.4 milestone complete
Last activity: 2026-02-09 -- Completed 33-02-PLAN.md (Spotify playlist import UI screens)

Progress: [##############################] 100% (53/53 plans)

## Performance Metrics

**Velocity:**
- Total plans completed: 53 (8 from v0.1 + 10 from v1.0 + 6 from v1.1 + 6 from v1.2 + 2 quick tasks + 10 from v1.3 + 11 from v1.4)
- Average duration: 5m
- Total execution time: ~3 hours

**By Milestone:**

| Milestone | Phases | Plans | Duration |
|-----------|--------|-------|----------|
| v0.1 | 4 | 8 | ~40m |
| v1.0 | 5 | 10 | ~50m |
| v1.1 | 3 | 6 | ~30m |
| v1.2 | 3 | 6 | ~30m |
| v1.3 | 6 | 10 | ~30m |
| v1.4 | 6 | 11 | ~35m |

## Accumulated Context

### Decisions

Full decision log in PROJECT.md Key Decisions table.

v1.3 decisions archived.

v1.4 decisions:
- Followed SongFeedback pattern exactly for RunningSong feature consistency
- RunningSongSource enum uses orElse fallback to curated for forward-compatibility
- Captured WidgetRef before showModalBottomSheet for provider access inside builder closure
- Used sheetContext for Navigator.pop and outer context for ScaffoldMessenger.showSnackBar
- Running song keys merged via Set.addAll() into liked set for scoring -- idempotent with explicit likes
- Synthetic feedback merge order {...synthetic, ...real} ensures real feedback takes precedence
- Corrected plan test: songBpm 180 at cadence 170 is none (10 > ceil(170*0.05)=9 tolerance)
- BPM chip uses cadence passed as int from parent (provider decoupled from card widget)
- Abstract SongSearchService interface kept despite one-member-abstract lint for Spotify extensibility
- Separate curatedSongsListProvider for search, decoupled from scoring providers
- Used Flutter SDK debounce pattern (Timer+Completer+CancelException) for Autocomplete
- Track _lastQuery in state for options view highlighting since optionsViewBuilder has no direct text access
- SpotifyAuthService uses abstract class (not abstract interface class) matching SongSearchService pattern
- SpotifyCredentials persists codeVerifier per Spotify PKCE requirement for token refresh
- MockSpotifyAuthRepository uses Completer-based lock to prevent concurrent token refreshes
- Adapted plan's API to actual spotify 0.15.0 package (no generateCodeVerifier/pkce constructor)
- Added oauth2 as explicit dependency for AuthorizationCodeGrant type usage
- PKCE verifier managed internally by oauth2 grant, not externally persisted in SpotifyAuthRepository
- Used mock Spotify search service since Dashboard unavailable; real SpotifySongSearchService ready for swap
- Adapted plan's Spotify search API to actual package: BundledPages.first() returns List<Page<dynamic>>
- SongKey.normalize used for composite dedup, consistent with song_feedback and running_song patterns
- SpotifyPlaylistService uses abstract class (not abstract interface class) matching established pattern
- Mock playlist service returned even when disconnected; UI layer gates access
- Real implementation uses bare catch(_) for both Exception and Error types
- addSongs batch method returns int for UI feedback on import count
- Extracted _appBarActions helper to avoid duplicating conditional import button across empty/populated states
- Track selection by index (Set<int>) for simpler state management in playlist tracks screen
- URI-encoded playlist name in query parameter for safe navigation with special characters

### Pending Todos

- **Manual UI verification:** Onboarding flow, empty states, shuffle, profile switching, feedback, taste suggestions, song search, source badges, Spotify playlist import
- **Pre-existing test failure:** widget_test.dart expects "Home Screen" text
- **Pre-existing test failures:** 2 playlist provider error message tests (string mismatch)
- **User setup:** Add GETSONGBPM_API_KEY to .env before runtime API calls

### Blockers/Concerns

- Spotify Developer Dashboard not accepting new app registrations (since Dec 2025)
- Spotify Developer Mode requires Premium account (Feb 2026 policy change)
- Build Spotify phases with mocks; defer live testing to when Dashboard opens

## Session Continuity

Last session: 2026-02-09
Stopped at: v1.4 milestone complete. All 53 plans shipped across v0.1-v1.4.
Resume file: N/A -- milestone complete
