---
phase: 02-spotify-authentication
plan: 01
subsystem: auth
tags: [supabase, spotify, oauth, riverpod, go_router, deep-links]

# Dependency graph
requires:
  - phase: 01-project-foundation
    provides: Flutter project with Supabase init, GoRouter, Riverpod
provides:
  - AuthRepository wrapping Supabase OAuth with Spotify provider
  - Riverpod providers for auth state, session, and authentication status
  - Auth-guarded GoRouter with redirect logic and AuthNotifier
  - LoginScreen with Spotify OAuth button
  - HomeScreen with logout functionality
  - Spotify constants (scopes, redirect scheme, redirect URL)
affects: [02-02 platform-config, 03-spotify-api, any-future-auth-dependent-phase]

# Tech tracking
tech-stack:
  added: [flutter_secure_storage]
  patterns: [AuthNotifier+refreshListenable for reactive routing, AuthRepository pattern for Supabase OAuth, platform-aware LaunchMode selection]

key-files:
  created:
    - lib/core/constants/spotify_constants.dart
    - lib/features/auth/data/auth_repository.dart
    - lib/features/auth/providers/auth_providers.dart
    - lib/features/auth/presentation/login_screen.dart
  modified:
    - pubspec.yaml
    - lib/app/router.dart
    - lib/features/home/presentation/home_screen.dart

key-decisions:
  - "AuthNotifier as ChangeNotifier subscribed to onAuthStateChange, used as GoRouter refreshListenable for reactive route guards"
  - "LaunchMode.externalApplication on mobile (never inAppWebView) per research Pitfall 2"
  - "All 6 Spotify scopes requested upfront to avoid re-authentication"
  - "Zero manual navigation after login/logout -- GoRouter redirect handles all routing"

patterns-established:
  - "Auth-reactive routing: AuthNotifier + refreshListenable + redirect function"
  - "Repository pattern: AuthRepository wraps SupabaseClient, injected via Riverpod Provider"
  - "Platform-aware OAuth: kIsWeb conditional for redirectTo and LaunchMode"

# Metrics
duration: 4min
completed: 2026-02-05
---

# Phase 2 Plan 1: Spotify OAuth Dart Layer Summary

**Supabase OAuth with Spotify provider, auth-guarded GoRouter via AuthNotifier+refreshListenable, and reactive login/logout flow with zero manual navigation**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-05T10:48:41Z
- **Completed:** 2026-02-05T10:52:55Z
- **Tasks:** 2/2
- **Files modified:** 7

## Accomplishments

- AuthRepository wrapping Supabase OAuth with platform-aware redirect URLs and launch modes
- Riverpod providers exposing auth state reactively (authRepository, authState stream, currentSession, isAuthenticated)
- GoRouter with AuthNotifier-driven redirect guards: unauthenticated users to /login, authenticated away from /login
- LoginScreen with "Log in with Spotify" button and error handling
- HomeScreen converted to ConsumerWidget with logout button

## Task Commits

Each task was committed atomically:

1. **Task 1: Create auth repository, providers, and constants** - `d79df6e` (feat)
2. **Task 2: Wire auth-guarded router, login screen, and logout** - `5e74456` (feat)

## Files Created/Modified

- `lib/core/constants/spotify_constants.dart` - Spotify OAuth scopes (6 scopes) and redirect URL constants
- `lib/features/auth/data/auth_repository.dart` - AuthRepository: signInWithSpotify(), signOut(), session/auth state access
- `lib/features/auth/providers/auth_providers.dart` - Riverpod providers: authRepository, authState, currentSession, isAuthenticated
- `lib/features/auth/presentation/login_screen.dart` - ConsumerWidget with Spotify login button, error SnackBar
- `lib/app/router.dart` - AuthNotifier + authNotifierProvider + auth redirect logic + /login route
- `lib/features/home/presentation/home_screen.dart` - Converted to ConsumerWidget with logout button
- `pubspec.yaml` - Added flutter_secure_storage dependency

## Decisions Made

- AuthNotifier properly disposes its StreamSubscription via ref.onDispose in provider
- Used `on Exception catch` instead of bare `catch` to satisfy very_good_analysis lint rules
- Doc comments use backtick references for GoRouter instead of `[GoRouter]` brackets to avoid comment_references lint info

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required. (Spotify dashboard and Supabase dashboard configuration is handled in plan 02-02.)

## Next Phase Readiness

- Dart auth layer complete and compiles successfully
- Ready for plan 02-02 which adds platform-specific deep link configuration (Info.plist, AndroidManifest.xml)
- Auth flow cannot be functionally tested until Spotify is configured in Supabase dashboard (plan 02-02/02-03)

---
*Phase: 02-spotify-authentication*
*Completed: 2026-02-05*
