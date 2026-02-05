# Phase 2: Spotify Authentication - Research

**Researched:** 2026-02-05
**Domain:** Supabase OAuth with Spotify provider, Flutter deep linking, session persistence
**Confidence:** HIGH

## Summary

This phase implements Spotify OAuth login via Supabase Auth, which acts as the OAuth intermediary. The flow is: App -> Supabase Auth -> Spotify -> Supabase Auth -> App. Supabase handles the OAuth complexity (PKCE between app and Supabase, authorization code flow between Supabase and Spotify), while the Flutter app needs deep link configuration to receive the redirect callback.

The standard approach is well-documented: call `supabase.auth.signInWithOAuth(OAuthProvider.spotify)` with platform-appropriate redirect URLs and launch modes. Session persistence is handled automatically by `supabase_flutter` (SharedPreferences on mobile, localStorage on web). GoRouter's `redirect` + `refreshListenable` pattern handles route guarding based on auth state.

The critical nuance is the **Spotify provider token**. Supabase manages its own session tokens (JWT + refresh token) separately from Spotify's access token. The Spotify provider token is only available on initial sign-in and is NOT persisted by Supabase. For Phase 2 (auth only), this is acceptable -- we only need Supabase session persistence. Provider token management for Spotify API calls (needed in Phase 3+) should be designed now but can be fully implemented later.

**Primary recommendation:** Use `supabase_flutter`'s built-in OAuth flow with Spotify provider. Configure deep links for iOS (custom URL scheme in Info.plist) and Android (intent filter in AndroidManifest.xml). Add GoRouter redirect guards that react to Supabase auth state via a Riverpod-powered AuthNotifier. Request all Spotify scopes upfront that the full app will need.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| supabase_flutter | ^2.12.0 | OAuth + session management | Already in project; handles PKCE, session persistence, token refresh automatically |
| go_router | ^17.0.1 | Route guarding with auth redirects | Already in project; supports `redirect` + `refreshListenable` for auth guards |
| flutter_riverpod | ^2.6.1 | Auth state management | Already in project; drives GoRouter refresh and UI reactivity |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_secure_storage | ^9.2.4 | Secure storage for Spotify provider tokens | Store Spotify access/refresh tokens on mobile (Keychain/Keystore) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| supabase_flutter OAuth | Direct Spotify OAuth (spotify_sdk, manual PKCE) | Much more work; lose Supabase session management; supabase_flutter already handles it |
| SharedPreferences (default) | flutter_secure_storage for Supabase session | Overkill for Supabase session (JWT is short-lived anyway); only needed for Spotify provider tokens |
| Custom URL schemes | Universal Links / App Links (HTTPS) | Universal links are more secure but require domain hosting of AASA/assetlinks.json; custom schemes work fine for OAuth callbacks and are simpler |

**Installation:**
```bash
# flutter_secure_storage for provider token storage
flutter pub add flutter_secure_storage
```

Note: `supabase_flutter`, `go_router`, and `flutter_riverpod` are already installed from Phase 1.

## Architecture Patterns

### Recommended Project Structure
```
lib/
├── app/
│   ├── app.dart                    # MaterialApp.router (exists)
│   └── router.dart                 # GoRouter with auth redirect (modify)
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   └── auth_repository.dart    # Supabase auth operations
│   │   ├── presentation/
│   │   │   ├── login_screen.dart       # "Log in with Spotify" button
│   │   │   └── auth_gate.dart          # Optional: widget-level auth gate
│   │   └── providers/
│   │       └── auth_providers.dart     # Auth state providers
│   ├── home/
│   │   └── presentation/
│   │       └── home_screen.dart        # (exists) - add logout button
│   └── settings/
│       └── presentation/
│           └── settings_screen.dart    # (exists)
├── core/
│   └── constants/
│       └── spotify_constants.dart      # Scopes, redirect scheme
└── main.dart                           # (exists)
```

### Pattern 1: Auth State Provider with Riverpod
**What:** Expose Supabase auth state as a Riverpod StreamProvider, making it available to GoRouter and all widgets
**When to use:** Always -- this is the foundation of auth-reactive UI
**Example:**
```dart
// features/auth/providers/auth_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stream of auth state changes from Supabase
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Current session (nullable -- null means logged out)
final currentSessionProvider = Provider<Session?>((ref) {
  return Supabase.instance.client.auth.currentSession;
});

/// Whether user is currently authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final session = ref.watch(currentSessionProvider);
  return session != null;
});
```

### Pattern 2: GoRouter Auth Redirect with Riverpod
**What:** GoRouter redirect function that checks auth state and redirects unauthenticated users to login
**When to use:** Router setup -- protects all authenticated routes
**Example:**
```dart
// app/router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A ChangeNotifier that listens to Supabase auth state changes
/// and notifies GoRouter to re-evaluate redirects
class AuthNotifier extends ChangeNotifier {
  AuthNotifier() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      notifyListeners();
    });
  }

  bool get isAuthenticated =>
      Supabase.instance.client.auth.currentSession != null;
}

final authNotifierProvider = Provider<AuthNotifier>((ref) {
  return AuthNotifier();
});

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isAuthenticated = authNotifier.isAuthenticated;
      final isLoginRoute = state.matchedLocation == '/login';

      // Not authenticated and not on login page -> go to login
      if (!isAuthenticated && !isLoginRoute) return '/login';

      // Authenticated and on login page -> go to home
      if (isAuthenticated && isLoginRoute) return '/';

      // No redirect needed
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
```

### Pattern 3: Spotify OAuth Sign-In
**What:** Call Supabase signInWithOAuth with platform-appropriate settings
**When to use:** Login screen button tap
**Example:**
```dart
// features/auth/data/auth_repository.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  /// Sign in with Spotify via Supabase OAuth
  Future<void> signInWithSpotify() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.spotify,
      redirectTo: kIsWeb ? null : 'io.runplaylist.app://login-callback',
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
      scopes: 'user-read-email user-read-private user-top-read '
          'user-library-read playlist-modify-public playlist-modify-private',
    );
  }

  /// Sign out (clears Supabase session)
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Current session
  Session? get currentSession => _client.auth.currentSession;

  /// Auth state change stream
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;
}
```

### Pattern 4: Login Screen
**What:** Simple screen with a "Log in with Spotify" button
**When to use:** Unauthenticated state
**Example:**
```dart
// features/auth/presentation/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Running Playlist AI',
                style: TextStyle(fontSize: 24)),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () async {
                await ref.read(authRepositoryProvider).signInWithSpotify();
              },
              icon: const Icon(Icons.music_note),
              label: const Text('Log in with Spotify'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Pattern 5: Sign Out
**What:** Simple sign-out that clears the Supabase session; GoRouter redirect handles navigation
**When to use:** Settings/profile screen
**Example:**
```dart
// In any screen with a logout button
ElevatedButton(
  onPressed: () async {
    await Supabase.instance.client.auth.signOut();
    // No manual navigation needed -- GoRouter redirect handles it
  },
  child: const Text('Log out'),
),
```

### Anti-Patterns to Avoid
- **Manual navigation after signOut/signIn:** GoRouter's `refreshListenable` + `redirect` handles all navigation automatically. Do NOT call `context.go('/login')` after `signOut()` -- the redirect will fire.
- **Storing Supabase session manually:** `supabase_flutter` persists sessions automatically. Do NOT implement custom session storage for the Supabase JWT.
- **Using LaunchMode.inAppWebView on iOS:** Causes redirect failures with Spotify. Always use `LaunchMode.externalApplication` on mobile.
- **Forgetting to request all scopes upfront:** Spotify scopes are granted at login time. If you add scopes later, the user must re-authenticate. Request all needed scopes from the start.
- **Confusing Supabase session with Spotify token:** `currentSession` is the Supabase session (always refreshed automatically). `session.providerToken` is the Spotify access token (only available on initial login, NOT refreshed by Supabase).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| OAuth PKCE flow | Manual PKCE implementation | `supabase_flutter` signInWithOAuth | PKCE is complex (code verifier, challenge, exchange); Supabase handles it |
| Session persistence | Custom token storage + SharedPreferences | `supabase_flutter` built-in persistence | Handles token refresh, expiry, secure storage automatically |
| Deep link handling | Manual platform channel code | `supabase_flutter` auto-detection + platform config | SDK automatically detects auth callback URLs |
| Route guarding | Manual auth checks in every screen | GoRouter `redirect` + `refreshListenable` | Centralized, reactive, handles all edge cases |
| Auth state management | Custom stream controllers | Supabase `onAuthStateChange` + Riverpod | Stream is built-in, Riverpod makes it reactive |

**Key insight:** `supabase_flutter` handles 90% of the OAuth complexity. The implementation work is mostly configuration (Spotify dashboard, Supabase dashboard, platform files) and wiring (GoRouter redirect, Riverpod providers, UI).

## Common Pitfalls

### Pitfall 1: Spotify Redirect URI Mismatch
**What goes wrong:** OAuth fails with "INVALID_CLIENT: Invalid redirect URI" error
**Why it happens:** The redirect URI in the Spotify Developer Dashboard must EXACTLY match what the app sends. Common mismatches: trailing slash, scheme casing, host name differences.
**How to avoid:** Use a consistent redirect URI everywhere:
  - Spotify Dashboard: `io.runplaylist.app://login-callback`
  - Supabase Dashboard (Additional Redirect URLs): `io.runplaylist.app://login-callback`
  - Flutter code (`redirectTo`): `io.runplaylist.app://login-callback`
  - Android `AndroidManifest.xml`: scheme=`io.runplaylist.app`, host=`login-callback`
  - iOS `Info.plist`: CFBundleURLSchemes=`io.runplaylist.app`
**Warning signs:** OAuth works on web but fails on mobile, or vice versa

### Pitfall 2: iOS Redirect Fails with In-App WebView
**What goes wrong:** After Spotify login, the app shows a blank screen or "Open in app?" prompt that does nothing
**Why it happens:** `LaunchMode.inAppWebView` cannot handle custom URL scheme redirects properly on iOS
**How to avoid:** Always use `LaunchMode.externalApplication` on mobile. This opens Safari/Chrome, which properly handles the custom scheme redirect back to the app.
**Warning signs:** Login screen appears, user can log into Spotify, but nothing happens afterward
**Source:** [GitHub Issue #819](https://github.com/supabase/supabase-flutter/issues/819)

### Pitfall 3: Missing Supabase Callback URL
**What goes wrong:** Spotify login succeeds but Supabase returns an error about invalid redirect
**Why it happens:** The Supabase callback URL (`https://<project>.supabase.co/auth/v1/callback`) was not added to Spotify's redirect URIs in the developer dashboard
**How to avoid:** Add BOTH URLs to Spotify Dashboard:
  1. `https://<project-ref>.supabase.co/auth/v1/callback` (Supabase's callback -- this is what Spotify redirects to)
  2. Your deep link scheme in Supabase's "Additional Redirect URLs" (this is what Supabase redirects to in your app)
**Warning signs:** Spotify shows an error page instead of redirecting back

### Pitfall 4: Web Session Not Available After Redirect
**What goes wrong:** After OAuth redirect on web, `currentSession` is null even though login succeeded
**Why it happens:** On web, `signInWithOAuth` causes a full page redirect. When the page reloads, `Supabase.initialize()` restores the session asynchronously. Code that runs before initialization completes sees null.
**How to avoid:** Listen to `onAuthStateChange` for `AuthChangeEvent.initialSession` or `AuthChangeEvent.signedIn` rather than checking `currentSession` synchronously. The GoRouter `refreshListenable` pattern handles this correctly.
**Warning signs:** Works after manual page refresh but not on first redirect

### Pitfall 5: Confusing Supabase Token with Spotify Token
**What goes wrong:** App tries to call Spotify API with Supabase JWT, gets 401 errors
**Why it happens:** `supabase.auth.currentSession?.accessToken` is the Supabase JWT, NOT the Spotify access token. The Spotify access token is `session.providerToken`, which is only available on initial sign-in.
**How to avoid:** Capture `session.providerToken` and `session.providerRefreshToken` on the `signedIn` auth event and store them separately (e.g., in `flutter_secure_storage`). For Phase 2, just verify the Supabase session works; defer Spotify token storage to Phase 3+.
**Warning signs:** Auth works but Spotify API calls fail

### Pitfall 6: Spotify Provider Token Cannot Be Refreshed Client-Side
**What goes wrong:** Spotify access token expires (1 hour) and cannot be refreshed without exposing client secret
**Why it happens:** Supabase uses Auth Code flow (not PKCE) between Supabase Auth and Spotify. Refreshing the Spotify token requires the client_secret, which cannot be safely stored in a mobile/web app.
**How to avoid:** Use a Supabase Edge Function for Spotify token refresh. The Edge Function holds the client_secret server-side and exposes a secure endpoint for token refresh.
**Warning signs:** Spotify API calls work immediately after login but fail after ~1 hour
**Impact on Phase 2:** Low -- Phase 2 only needs auth. This becomes critical in Phase 3+ when making Spotify API calls.

### Pitfall 7: Android Deep Link Intent Filter Not Matching
**What goes wrong:** OAuth redirect on Android opens the browser instead of returning to the app
**Why it happens:** The `<intent-filter>` in AndroidManifest.xml doesn't match the redirect URI scheme and host exactly
**How to avoid:** Ensure `android:scheme` and `android:host` in the intent filter match the redirect URI. Also ensure `android:launchMode="singleTop"` is set on the activity (already set by default Flutter template).
**Warning signs:** Works on iOS but not Android; browser shows the callback URL instead of opening the app

### Pitfall 8: Scopes Not Requested at Login
**What goes wrong:** Spotify API calls fail with 403 "Insufficient scope" even though user is authenticated
**Why it happens:** Spotify scopes must be requested during the OAuth consent flow. If scopes are omitted from `signInWithOAuth`, only basic profile access is granted.
**How to avoid:** Pass ALL scopes the app will ever need as a space-separated string in the `scopes` parameter of `signInWithOAuth`. Scopes for this app: `user-read-email user-read-private user-top-read user-library-read playlist-modify-public playlist-modify-private`.
**Warning signs:** Login works but later API calls return 403

## Code Examples

### Supabase Dashboard Configuration
```
1. Go to Authentication > Providers > Spotify
2. Toggle "Spotify Enabled" to ON
3. Enter Client ID from Spotify Developer Dashboard
4. Enter Client Secret from Spotify Developer Dashboard
5. Save

6. Go to Authentication > URL Configuration
7. Add to "Additional Redirect URLs":
   - io.runplaylist.app://login-callback
   - http://localhost:PORT (for web dev -- replace PORT)
```

### Spotify Developer Dashboard Configuration
```
1. Go to https://developer.spotify.com/dashboard
2. Create App (or select existing)
3. App Name: "Running Playlist AI"
4. Redirect URIs -- add ALL of these:
   - https://<project-ref>.supabase.co/auth/v1/callback
5. Save
```
Note: The Supabase callback URL is what Spotify redirects to. Supabase then redirects to your app's deep link. You do NOT add your app's deep link to Spotify -- only the Supabase callback URL.

### Android Deep Link Configuration
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<!-- Add inside the existing <activity> tag, after the MAIN intent-filter -->
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="io.runplaylist.app"
          android:host="login-callback" />
</intent-filter>
```

### iOS Deep Link Configuration
```xml
<!-- ios/Runner/Info.plist -->
<!-- Add inside the main <dict> section -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>io.runplaylist.app</string>
        </array>
    </dict>
</array>
```

### Complete Auth Repository
```dart
// features/auth/data/auth_repository.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  static const _spotifyScopes =
      'user-read-email user-read-private user-top-read '
      'user-library-read playlist-modify-public playlist-modify-private';

  static const _mobileRedirectUrl = 'io.runplaylist.app://login-callback';

  Future<void> signInWithSpotify() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.spotify,
      redirectTo: kIsWeb ? null : _mobileRedirectUrl,
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
      scopes: _spotifyScopes,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  bool get isAuthenticated => currentSession != null;
}
```

### Auth State Listening for Provider Token Capture
```dart
// This pattern will be needed in Phase 3+ for Spotify API calls
// Document it now so the planner is aware
supabase.auth.onAuthStateChange.listen((data) {
  if (data.event == AuthChangeEvent.signedIn) {
    final providerToken = data.session?.providerToken;
    final providerRefreshToken = data.session?.providerRefreshToken;
    if (providerToken != null) {
      // Store in flutter_secure_storage for later Spotify API calls
      // secureStorage.write(key: 'spotify_token', value: providerToken);
    }
  }
});
```

### Sign Out with GoRouter (No Manual Navigation)
```dart
// The GoRouter redirect automatically navigates to /login
// when the session becomes null after signOut
Future<void> handleSignOut() async {
  await Supabase.instance.client.auth.signOut();
  // GoRouter's refreshListenable fires, redirect runs,
  // user is sent to /login automatically
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Implicit Grant Flow (Spotify) | Authorization Code + PKCE | Nov 27, 2025 deadline (Spotify) | Implicit grant no longer supported; PKCE mandatory for mobile/SPA |
| HTTP redirect URIs (Spotify) | HTTPS only (except loopback) | Nov 27, 2025 deadline | Custom schemes still allowed but HTTPS preferred |
| `authCallbackUrlHostname` param | Auto-detection of callback URLs | supabase_flutter v2 | No explicit hostname config needed |
| Hive for session storage | SharedPreferences (default) | supabase_flutter v2.x | MigrationLocalStorage available for Hive->SharedPreferences |
| `Provider` enum | `OAuthProvider` enum | supabase_flutter v2 | Avoids collision with Riverpod's `Provider` class |
| WebView-based OAuth | External browser OAuth | supabase_flutter v2 | webview_flutter dependency dropped |
| Manual PKCE implementation | Built-in PKCE (default) | supabase_flutter v2 | PKCE is default for all deep link auth flows |

**Deprecated/outdated:**
- Spotify Implicit Grant Flow: Removed November 27, 2025
- HTTP redirect URIs on Spotify: No longer accepted (except `127.0.0.1`)
- `localhost` as redirect URI on Spotify: Prohibited (use `127.0.0.1` instead)
- `supabase_flutter` v1 WebView OAuth: Dropped in v2

## Open Questions

1. **Spotify Provider Token Refresh Strategy**
   - What we know: Supabase does not refresh Spotify provider tokens. Token expires after ~1 hour. Refreshing requires client_secret which cannot be in the client app.
   - What's unclear: Whether a Supabase Edge Function is the best approach, or if re-authenticating (which is seamless if user is already logged into Spotify) is simpler for an app with infrequent API usage patterns.
   - Recommendation: For Phase 2, ignore this. For Phase 3+, implement a Supabase Edge Function that accepts the provider_refresh_token and returns a fresh access token. This keeps client_secret server-side. Design the auth repository now to accommodate this future need.
   - Confidence: MEDIUM -- Edge Function approach is well-documented but adds deployment complexity.

2. **Custom URL Scheme Choice**
   - What we know: Custom URL schemes (e.g., `io.runplaylist.app://`) work for OAuth callbacks. Spotify still supports them post-Nov 2025.
   - What's unclear: Whether a specific scheme is already registered by another app on user devices (custom schemes are not guaranteed unique).
   - Recommendation: Use a reverse-domain style scheme (`io.runplaylist.app`) which is conventional and unlikely to collide. This is the standard practice recommended by both Apple and Google.
   - Confidence: HIGH -- this is established convention.

3. **Web OAuth Redirect URL for Development**
   - What we know: On web, `redirectTo: null` causes Supabase to redirect back to the current page URL. During development, this is `http://localhost:PORT`.
   - What's unclear: The exact port Flutter dev server uses (varies).
   - Recommendation: Add `http://localhost:*` or multiple common ports (3000, 5000, 8080) to Supabase "Additional Redirect URLs". Use a wildcard pattern if supported. For Spotify dashboard, only the Supabase callback URL is needed (not localhost).
   - Confidence: HIGH -- this is standard local dev practice.

4. **Supabase Session vs flutter_secure_storage for Provider Tokens**
   - What we know: Supabase persists its own session in SharedPreferences (not encrypted). Provider tokens are NOT persisted by Supabase.
   - What's unclear: Whether the default SharedPreferences storage for Supabase session is a security concern.
   - Recommendation: The Supabase JWT is short-lived (default 1 hour) and refreshed automatically, so SharedPreferences is acceptable. For Spotify provider tokens (which grant access to user's Spotify data), use `flutter_secure_storage` on mobile. On web, localStorage is the only practical option.
   - Confidence: MEDIUM -- security tradeoffs depend on threat model.

## Sources

### Primary (HIGH confidence)
- [Supabase Spotify OAuth Guide](https://supabase.com/docs/guides/auth/social-login/auth-spotify) - Official setup instructions
- [Supabase Flutter signInWithOAuth API Reference](https://supabase.com/docs/reference/dart/auth-signinwithoauth) - Method signature, parameters, examples
- [Supabase onAuthStateChange API Reference](https://supabase.com/docs/reference/dart/auth-onauthstatechange) - Auth event stream, event types
- [Supabase Sessions Documentation](https://supabase.com/docs/guides/auth/sessions) - Session lifecycle, token refresh
- [Supabase Deep Linking Guide](https://supabase.com/docs/guides/auth/native-mobile-deep-linking?platform=flutter) - Platform-specific deep link setup
- [Supabase Redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls) - Allow list configuration
- [Supabase signOut Documentation](https://supabase.com/docs/guides/auth/signout) - Sign-out scopes, behavior
- [Spotify Scopes Reference](https://developer.spotify.com/documentation/web-api/concepts/scopes) - All available OAuth scopes
- [Spotify PKCE Flow Tutorial](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow) - PKCE implementation details
- [Spotify OAuth Migration Blog (Oct 2025)](https://developer.spotify.com/blog/2025-10-14-reminder-oauth-migration-27-nov-2025) - Implicit grant removal, HTTPS requirement

### Secondary (MEDIUM confidence)
- [supabase_flutter pub.dev](https://pub.dev/packages/supabase_flutter) - v2.12.0, SharedPreferences default storage
- [GoRouter + Riverpod Auth Redirect (Q Agency)](https://q.agency/blog/handling-authentication-state-with-go_router-and-riverpod/) - AuthNotifier + refreshListenable pattern
- [GoRouter + Riverpod Redirect (ApparenceKit)](https://apparencekit.dev/blog/flutter-riverpod-gorouter-redirect/) - Practical redirect implementation
- [GitHub Issue #819 - Spotify iOS redirect](https://github.com/supabase/supabase-flutter/issues/819) - LaunchMode.externalApplication fix
- [GitHub Issue #1450 - PKCE provider token refresh](https://github.com/supabase/auth/issues/1450) - Known limitation with Spotify token refresh
- [Supabase Discussion #20035 - Spotify refresh token](https://github.com/orgs/supabase/discussions/20035) - Community discussion on workarounds

### Tertiary (LOW confidence)
- [Spotify custom scheme URI issue (Commonsware)](https://commonsware.com/blog/2025/04/12/spotify-android-sdk-redirect-uri-schemes.html) - Post-April 2025 custom scheme issues and resolution
- [go_router_riverpod example (GitHub)](https://github.com/lucavenir/go_router_riverpod) - Community-driven GoRouter+Riverpod integration
- [supabase-flutter local_storage.dart source](https://github.com/supabase/supabase-flutter/blob/main/packages/supabase_flutter/lib/src/local_storage.dart) - SharedPreferencesLocalStorage implementation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - supabase_flutter OAuth with Spotify is documented in official Supabase docs with Flutter-specific examples
- Architecture: HIGH - GoRouter + Riverpod + Supabase auth pattern is well-established with multiple authoritative sources agreeing
- Deep linking: HIGH - Platform configuration (Info.plist, AndroidManifest.xml) is documented by both Supabase and Flutter official docs
- Pitfalls: HIGH - Multiple GitHub issues and community discussions document real-world problems and solutions
- Provider token management: MEDIUM - Known limitation with Spotify+PKCE token refresh; Edge Function workaround is documented but adds complexity

**Research date:** 2026-02-05
**Valid until:** 2026-03-07 (30 days - stable ecosystem, Spotify migration already completed Nov 2025)
