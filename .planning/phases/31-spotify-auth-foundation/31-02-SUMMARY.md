---
phase: 31-spotify-auth-foundation
plan: 02
subsystem: auth
tags: [spotify, oauth, pkce, riverpod, settings-ui, flutter]

# Dependency graph
requires:
  - phase: 31-01
    provides: "SpotifyAuthService interface, SpotifyTokenStorage, MockSpotifyAuthRepository"
provides:
  - "SpotifyAuthRepository: real PKCE OAuth implementation scaffold using spotify package"
  - "spotifyAuthServiceProvider: Riverpod provider returning mock by default (swappable to real)"
  - "spotifyConnectionStatusProvider: reactive stream of SpotifyConnectionStatus"
  - "spotifyConnectionStatusSyncProvider: synchronous status snapshot for UI"
  - "Settings screen with Spotify connect/disconnect section"
  - "spotifyClientIdKey and spotifyCallbackUrl constants"
affects: [spotify-search, spotify-playlist-export, deep-link-handling]

# Tech tracking
tech-stack:
  added: [spotify ^0.15.0, oauth2 ^2.0.5]
  patterns: [pkce-oauth-scaffold, provider-chain-pattern, switch-expression-ui-states]

key-files:
  created:
    - lib/features/spotify_auth/data/spotify_auth_repository.dart
    - lib/features/spotify_auth/providers/spotify_auth_providers.dart
  modified:
    - lib/core/constants/spotify_constants.dart
    - lib/features/settings/presentation/settings_screen.dart
    - pubspec.yaml
    - .env

key-decisions:
  - "Adapted plan's API calls to match actual spotify 0.15.0 package (no SpotifyApi.generateCodeVerifier or SpotifyApiCredentials.pkce)"
  - "Added oauth2 as explicit dependency since SpotifyAuthRepository imports oauth2.AuthorizationCodeGrant directly"
  - "PKCE code verifier managed internally by oauth2 AuthorizationCodeGrant rather than externally persisted"
  - "Used switch expression for clean connection state UI rendering in settings"
  - "WidgetRef captured from ConsumerWidget build for use in disconnect dialog"

patterns-established:
  - "Provider chain: SettingsScreen -> spotifyConnectionStatusSyncProvider -> spotifyConnectionStatusProvider -> spotifyAuthServiceProvider -> MockSpotifyAuthRepository"
  - "Switch expression pattern for exhaustive enum state UI"
  - "Disconnect confirmation dialog pattern with dialogContext vs outer context"

# Metrics
duration: 5min
completed: 2026-02-09
---

# Phase 31 Plan 02: Spotify Auth Wiring Summary

**Spotify PKCE auth repository scaffold with Riverpod providers and Settings UI for connect/disconnect flow using spotify 0.15.0 package**

## Performance

- **Duration:** 5 min
- **Started:** 2026-02-09T11:10:39Z
- **Completed:** 2026-02-09T11:16:08Z
- **Tasks:** 2
- **Files created:** 2
- **Files modified:** 4

## Accomplishments
- SpotifyAuthRepository implementing full PKCE flow scaffold (connect, handleCallback, disconnect, getAccessToken, restoreSession) using the `spotify` package's AuthorizationCodeGrant
- Three Riverpod providers wiring mock auth to UI with reactive status stream and synchronous snapshot
- Settings screen with Spotify connection card showing dynamic state (disconnected/connecting/connected/error) with appropriate actions
- spotify and oauth2 packages added to pubspec.yaml; SPOTIFY_CLIENT_ID placeholder in .env; spotifyCallbackUrl and spotifyClientIdKey in constants

## Task Commits

Each task was committed atomically:

1. **Task 1: Add spotify package, create real SpotifyAuthRepository scaffold, and Riverpod providers** - `231aa13` (feat)
2. **Task 2: Build Settings screen with Spotify connect/disconnect UI** - `dad2e9a` (feat)

## Files Created/Modified
- `lib/features/spotify_auth/data/spotify_auth_repository.dart` - Real PKCE OAuth implementation scaffold using spotify package
- `lib/features/spotify_auth/providers/spotify_auth_providers.dart` - Three Riverpod providers for auth service and connection status
- `lib/core/constants/spotify_constants.dart` - Added spotifyClientIdKey and spotifyCallbackUrl constants
- `lib/features/settings/presentation/settings_screen.dart` - Replaced placeholder with Spotify connection management UI
- `pubspec.yaml` - Added spotify ^0.15.0 and oauth2 ^2.0.5 dependencies
- `.env` - Added SPOTIFY_CLIENT_ID placeholder (gitignored)

## Decisions Made
- Adapted plan's SpotifyApi.generateCodeVerifier() and SpotifyApiCredentials.pkce() calls to use actual spotify 0.15.0 API (authorizationCodeGrant with internal PKCE verifier generation)
- Added oauth2 as explicit pubspec dependency since SpotifyAuthRepository uses oauth2.AuthorizationCodeGrant type directly
- codeVerifier not externally persisted in SpotifyAuthRepository -- the oauth2 package manages it internally within the grant lifecycle
- Used switch expression (Dart 3) for exhaustive SpotifyConnectionStatus UI rendering
- Captured WidgetRef from ConsumerWidget build for provider access inside disconnect dialog builder

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Adapted to actual spotify package API**
- **Found during:** Task 1 (SpotifyAuthRepository creation)
- **Issue:** Plan referenced `SpotifyApi.generateCodeVerifier()` and `SpotifyApiCredentials.pkce()` which don't exist in spotify 0.15.0
- **Fix:** Used `SpotifyApi.authorizationCodeGrant(credentials)` which creates oauth2.AuthorizationCodeGrant with internal PKCE verifier; used `SpotifyApiCredentials(clientId, null)` for PKCE (null secret)
- **Files modified:** lib/features/spotify_auth/data/spotify_auth_repository.dart
- **Verification:** dart analyze passes with no errors; full build succeeds
- **Committed in:** 231aa13 (Task 1 commit)

**2. [Rule 3 - Blocking] Added oauth2 as explicit dependency**
- **Found during:** Task 1 (SpotifyAuthRepository creation)
- **Issue:** `depend_on_referenced_packages` lint: importing oauth2 directly without it being an explicit dependency
- **Fix:** Ran `flutter pub add oauth2` to add as direct dependency in pubspec.yaml
- **Files modified:** pubspec.yaml, pubspec.lock
- **Verification:** dart analyze passes with no issues
- **Committed in:** 231aa13 (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Both fixes necessary to use the actual spotify package API correctly. No scope creep -- same functionality achieved via different API surface.

## Issues Encountered
None beyond the API mismatch documented above.

## User Setup Required
None - mock implementation is default. SPOTIFY_CLIENT_ID in .env is a placeholder for when Developer Dashboard opens.

## Next Phase Readiness
- Phase 31 (Spotify Auth Foundation) is complete
- SpotifyAuthService interface + MockSpotifyAuthRepository active for development
- SpotifyAuthRepository scaffold ready to swap in when real Spotify credentials available
- Settings UI ready to manage Spotify connection state
- Provider chain wired: UI -> providers -> mock service -> token storage
- All 17 existing tests still pass

## Self-Check: PASSED

All 5 files exist. Both commit hashes (231aa13, dad2e9a) verified in git log.

---
*Phase: 31-spotify-auth-foundation*
*Completed: 2026-02-09*
