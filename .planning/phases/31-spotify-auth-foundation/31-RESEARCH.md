# Phase 31: Spotify Auth Foundation - Research

**Researched:** 2026-02-09
**Domain:** OAuth 2.0 PKCE, Spotify Web API, secure token management in Flutter
**Confidence:** HIGH

## Summary

This phase implements OAuth 2.0 PKCE authorization for Spotify in a Flutter app, with secure token storage via `flutter_secure_storage` and automatic token lifecycle management. The `spotify` Dart package (v0.15.0) provides built-in PKCE support including code verifier generation, authorization URL construction, token exchange, and automatic refresh via the `oauth2` package underneath. `flutter_secure_storage` (already in pubspec.yaml at ^9.2.4) handles secure persistence using Keychain (iOS) and EncryptedSharedPreferences (Android).

Key architectural consideration: the existing app uses Supabase OAuth for Spotify login via `AuthRepository.signInWithSpotify()`, but Supabase does NOT reliably persist Spotify provider tokens (access/refresh). This phase must implement a separate, dedicated Spotify token management layer that works independently of Supabase auth. The existing Supabase auth flow can be left intact or deprecated later -- Phase 31 builds an entirely separate Spotify OAuth path.

Since Spotify Developer Dashboard is not accepting new app registrations (and Development Mode now requires Premium + limits to 5 test users), this phase must be built with mock-first development. All Spotify API calls go through an abstraction layer so the entire flow can be tested with mock responses.

**Primary recommendation:** Use the `spotify` package v0.15.0 for PKCE OAuth, `flutter_secure_storage` for token persistence, build behind an abstract `SpotifyAuthService` interface, and test everything with mocks.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `spotify` | 0.15.0 | Spotify Web API client with PKCE OAuth | Pure Dart, built-in PKCE support (PR #237, Dec 2025), handles authorization grant, token exchange, auto-refresh via `onCredentialsRefreshed` callback |
| `flutter_secure_storage` | ^9.2.4 | Secure token persistence | Already in pubspec.yaml; Keychain (iOS), EncryptedSharedPreferences (Android), platform-native encryption |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `url_launcher` | ^6.3.2 | Open Spotify auth URL in external browser | Already in pubspec.yaml; needed to launch the authorization URL on mobile |
| `flutter_riverpod` | ^2.6.1 | State management for auth state | Already in pubspec.yaml; providers for connection status and token state |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `spotify` package | `flutter_appauth` | flutter_appauth handles full OAuth redirect lifecycle (opens browser, listens for callback, exchanges token) but couples to AppAuth native SDKs, adds complexity, and doesn't include Spotify API methods. spotify package does both auth + API. |
| `spotify` package | Manual OAuth with `http` | Full control but requires implementing PKCE code generation, state parameter, redirect listening, token exchange, refresh logic manually. The `spotify` package handles all this. |
| `flutter_secure_storage` | `shared_preferences` | SharedPreferences stores plaintext; not suitable for OAuth tokens per requirements. |

### Installation
```bash
flutter pub add spotify
```
Note: `flutter_secure_storage` and `url_launcher` are already in pubspec.yaml.

## Architecture Patterns

### Recommended Project Structure
```
lib/
├── core/
│   └── constants/
│       └── spotify_constants.dart          # (exists) scopes, redirect URIs
├── features/
│   └── spotify_auth/
│       ├── domain/
│       │   └── spotify_auth_service.dart   # Abstract interface + SpotifyConnectionStatus enum
│       ├── data/
│       │   ├── spotify_token_storage.dart  # flutter_secure_storage wrapper for tokens
│       │   ├── spotify_auth_repository.dart # Real implementation using spotify package
│       │   └── mock_spotify_auth_repository.dart # Mock for testing without credentials
│       └── providers/
│           └── spotify_auth_providers.dart  # Riverpod providers for auth state
```

### Pattern 1: Abstract Auth Service Interface
**What:** Define `SpotifyAuthService` as an abstract class so the entire Spotify integration can be mocked
**When to use:** Always -- mock-first development is mandatory since Dashboard is unavailable
**Example:**
```dart
// Source: project architecture pattern
enum SpotifyConnectionStatus { disconnected, connecting, connected, error }

abstract class SpotifyAuthService {
  Future<void> connect();           // Initiate PKCE flow
  Future<void> disconnect();        // Clear tokens
  Future<String?> getAccessToken(); // Returns valid token or null (handles refresh)
  SpotifyConnectionStatus get status;
  Stream<SpotifyConnectionStatus> get statusStream;
  Future<bool> get isConnected;
}
```

### Pattern 2: PKCE Authorization Flow (spotify package)
**What:** Complete PKCE flow using spotify-dart's built-in support
**When to use:** When implementing the real auth repository
**Example:**
```dart
// Source: https://github.com/rinukkusu/spotify-dart README
// Step 1: Generate verifier + credentials
final verifier = SpotifyApi.generateCodeVerifier();
final credentials = SpotifyApiCredentials.pkce(clientId, codeVerifier: verifier);

// Step 2: Create authorization grant
final grant = SpotifyApi.authorizationCodeGrant(credentials);

// Step 3: Get authorization URL (user opens this in browser)
final authUri = grant.getAuthorizationUrl(
  Uri.parse(spotifyRedirectUrl),
  scopes: spotifyScopes.split(' '),
);

// Step 4: After redirect, handle the response
final client = await grant.handleAuthorizationResponse(responseParams);
final spotify = SpotifyApi.fromClient(client);

// Step 5: Save credentials for later
final creds = await spotify.getCredentials();
// Save: creds.accessToken, creds.refreshToken, creds.expiration,
//        creds.scopes, creds.codeVerifier
```

### Pattern 3: Token Persistence with flutter_secure_storage
**What:** Store/restore tokens in platform-secure storage
**When to use:** After obtaining or refreshing tokens
**Example:**
```dart
// Source: flutter_secure_storage docs + spotify-dart credential pattern
class SpotifyTokenStorage {
  static const _storage = FlutterSecureStorage();
  static const _accessTokenKey = 'spotify_access_token';
  static const _refreshTokenKey = 'spotify_refresh_token';
  static const _expirationKey = 'spotify_token_expiration';
  static const _codeVerifierKey = 'spotify_code_verifier';
  static const _scopesKey = 'spotify_scopes';

  Future<void> saveCredentials(SpotifyApiCredentials creds) async {
    await _storage.write(key: _accessTokenKey, value: creds.accessToken);
    await _storage.write(key: _refreshTokenKey, value: creds.refreshToken);
    await _storage.write(key: _expirationKey, value: creds.expiration?.toIso8601String());
    await _storage.write(key: _codeVerifierKey, value: creds.codeVerifier);
    if (creds.scopes != null) {
      await _storage.write(key: _scopesKey, value: creds.scopes!.join(' '));
    }
  }

  Future<SpotifyApiCredentials?> loadCredentials(String clientId) async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    if (accessToken == null) return null;
    // Reconstruct credentials...
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
```

### Pattern 4: Credential Restoration with Auto-Refresh
**What:** Restore saved credentials and auto-refresh expired tokens
**When to use:** App startup, before any Spotify API call
**Example:**
```dart
// Source: spotify-dart README
// Restore credentials with auto-refresh callback
final spotify = await SpotifyApi.asyncFromCredentials(
  restoredCredentials,
  onCredentialsRefreshed: (newCreds) async {
    // Persist updated tokens
    await tokenStorage.saveCredentials(newCreds);
  },
);
```

### Pattern 5: Proactive Token Check Before API Calls
**What:** Check token expiry before making API calls; refresh proactively
**When to use:** Every Spotify API call goes through `getAccessToken()`
**Example:**
```dart
// Source: architectural pattern
Future<String?> getAccessToken() async {
  final creds = await _tokenStorage.loadCredentials(clientId);
  if (creds == null) return null;

  // Token still valid (with 5-minute buffer)
  if (creds.expiration != null &&
      creds.expiration!.isAfter(DateTime.now().add(Duration(minutes: 5)))) {
    return creds.accessToken;
  }

  // Token expired or expiring soon: refresh
  try {
    final spotify = await SpotifyApi.asyncFromCredentials(creds);
    final refreshed = await spotify.getCredentials();
    await _tokenStorage.saveCredentials(refreshed);
    return refreshed.accessToken;
  } catch (_) {
    // Refresh failed -- clear tokens, degrade gracefully
    await _tokenStorage.clearAll();
    return null;
  }
}
```

### Pattern 6: Graceful Degradation
**What:** App continues working when Spotify is unavailable
**When to use:** Every feature that touches Spotify
**Example:**
```dart
// Source: existing app pattern (see playlist_providers.dart API fallback)
// The app already degrades to curated-only when API calls fail.
// Spotify auth follows the same pattern: null token = no Spotify features.
final token = await ref.read(spotifyAuthProvider).getAccessToken();
if (token == null) {
  // Use local-only features (curated catalog, existing songs)
  return;
}
// Proceed with Spotify API call
```

### Anti-Patterns to Avoid
- **Storing tokens in SharedPreferences:** Plaintext storage violates security requirements.
- **Coupling Spotify auth to Supabase auth:** Supabase doesn't persist Spotify provider tokens reliably. Keep them separate.
- **Storing client_secret in mobile app:** PKCE exists specifically to avoid this. Never include a client secret.
- **Blocking app startup on Spotify auth:** Auth state should load asynchronously; app must be usable without Spotify.
- **Hardcoding Spotify client ID in source code:** Use `.env` file (already loaded via `flutter_dotenv`).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PKCE code verifier generation | Custom random string generator | `SpotifyApi.generateCodeVerifier()` | Must be cryptographically secure, 43-128 chars, specific charset |
| Token exchange | Manual HTTP POST to `/api/token` | `grant.handleAuthorizationResponse()` | Handles code exchange, error responses, token parsing |
| Token refresh | Manual HTTP POST with refresh_token | `SpotifyApi.asyncFromCredentials()` with `onCredentialsRefreshed` | Handles rotation, expiry detection, new credential construction |
| Secure storage | Custom encryption + SharedPreferences | `flutter_secure_storage` | Platform-native encryption (Keychain, EncryptedSharedPreferences) |
| Authorization URL construction | Manual URL building with query params | `grant.getAuthorizationUrl()` | Handles state parameter, PKCE challenge, proper encoding |

**Key insight:** The `spotify` package wraps the `oauth2` Dart package which handles the entire OAuth2 lifecycle. Reimplementing any part of this is error-prone and unnecessary.

## Common Pitfalls

### Pitfall 1: Deep Link Callback Not Received on Mobile
**What goes wrong:** After user authorizes in browser, the redirect to `io.runplaylist.app://login-callback?code=...` doesn't reach the app.
**Why it happens:** Custom URL scheme not properly registered, or app killed while browser is open, or redirect URI mismatch in Spotify Dashboard.
**How to avoid:** Deep link scheme is already configured in AndroidManifest.xml (`io.runplaylist.app://login-callback`) and iOS Info.plist (`io.runplaylist.app`). Listen for incoming links using `WidgetsBindingObserver` or a stream-based deep link listener. Ensure the redirect URI registered in Spotify Dashboard matches EXACTLY.
**Warning signs:** Auth opens browser but never returns; user stuck in browser.

### Pitfall 2: Token Refresh Race Condition
**What goes wrong:** Multiple concurrent API calls all detect expired token and trigger parallel refresh requests.
**Why it happens:** No mutex/lock on token refresh logic.
**How to avoid:** Use a `Completer` or simple boolean lock so only one refresh happens at a time. Other callers await the same future.
**Warning signs:** "Invalid refresh token" errors, 401s after successful refresh.

### Pitfall 3: Supabase Auth Confusion
**What goes wrong:** Developer tries to use Supabase session tokens for Spotify API calls, or mixes up auth flows.
**Why it happens:** The existing `AuthRepository` uses Supabase OAuth with Spotify provider. This creates a Supabase session but does NOT give direct access to Spotify API tokens.
**How to avoid:** Phase 31 is an entirely separate auth flow. The `SpotifyAuthService` does not touch Supabase at all. The existing `AuthRepository` + `LoginScreen` using Supabase can be left as-is or deprecated later.
**Warning signs:** Using `Supabase.instance.client.auth.currentSession` to try to access Spotify tokens.

### Pitfall 4: Web Platform Token Security
**What goes wrong:** Tokens stored via `flutter_secure_storage` on web use localStorage, which is accessible to any JS on the page.
**Why it happens:** Web platform lacks hardware-backed secure storage.
**How to avoid:** Accept this limitation for web. Consider using `WebOptions` with a wrap key for basic obfuscation. Document the security tradeoff. For production, consider server-side token management for web.
**Warning signs:** N/A -- this is a known limitation, not a bug.

### Pitfall 5: Credential Restoration Missing Code Verifier
**What goes wrong:** Token refresh fails after app restart because `codeVerifier` wasn't persisted.
**Why it happens:** The `spotify` package's PKCE credentials include a `codeVerifier` that must be saved alongside tokens.
**How to avoid:** Always persist `creds.codeVerifier` in `SpotifyTokenStorage.saveCredentials()`. When restoring, use `SpotifyApiCredentials.pkce(clientId, codeVerifier: savedVerifier)` constructor.
**Warning signs:** "Cannot refresh" errors only after cold restart (hot restart works because credentials are in memory).

### Pitfall 6: Spotify Dashboard Unavailable
**What goes wrong:** Cannot test real OAuth flow because Dashboard doesn't accept new app registrations.
**Why it happens:** Spotify paused new integrations (since Dec 2025). Development Mode now requires Premium (Feb 2026).
**How to avoid:** Build behind `SpotifyAuthService` interface. Use `MockSpotifyAuthRepository` for all development and testing. When Dashboard opens, implement `RealSpotifyAuthRepository` against the same interface.
**Warning signs:** N/A -- this is a known constraint.

## Code Examples

### Complete Auth Flow (connect)
```dart
// Source: spotify-dart README + project patterns
Future<void> connect() async {
  _status = SpotifyConnectionStatus.connecting;
  _statusController.add(_status);

  try {
    // 1. Generate PKCE verifier + credentials
    final verifier = SpotifyApi.generateCodeVerifier();
    final credentials = SpotifyApiCredentials.pkce(
      _clientId,
      codeVerifier: verifier,
    );

    // 2. Create grant
    final grant = SpotifyApi.authorizationCodeGrant(credentials);

    // 3. Get authorization URL
    final authUri = grant.getAuthorizationUrl(
      Uri.parse(spotifyRedirectUrl),
      scopes: spotifyScopes.split(' '),
    );

    // 4. Open in external browser
    await launchUrl(authUri, mode: LaunchMode.externalApplication);

    // 5. Listen for deep link callback with ?code= parameter
    //    (handled by deep link listener, which calls handleCallback)
  } catch (e) {
    _status = SpotifyConnectionStatus.error;
    _statusController.add(_status);
  }
}

Future<void> handleCallback(Uri callbackUri) async {
  try {
    // Extract query parameters (code, state)
    final params = callbackUri.queryParameters;

    // Exchange code for tokens
    final client = await _currentGrant!.handleAuthorizationResponse(params);
    _spotifyApi = SpotifyApi.fromClient(client);

    // Save credentials (including codeVerifier!)
    final creds = await _spotifyApi!.getCredentials();
    await _tokenStorage.saveCredentials(creds);

    _status = SpotifyConnectionStatus.connected;
    _statusController.add(_status);
  } catch (e) {
    _status = SpotifyConnectionStatus.error;
    _statusController.add(_status);
  }
}
```

### Restoring Session on App Start
```dart
// Source: spotify-dart README + project patterns
Future<void> restoreSession() async {
  final creds = await _tokenStorage.loadCredentials(_clientId);
  if (creds == null) {
    _status = SpotifyConnectionStatus.disconnected;
    return;
  }

  try {
    _spotifyApi = await SpotifyApi.asyncFromCredentials(
      creds,
      onCredentialsRefreshed: (newCreds) async {
        await _tokenStorage.saveCredentials(newCreds);
      },
    );
    _status = SpotifyConnectionStatus.connected;
  } catch (_) {
    // Tokens invalid, clear and mark disconnected
    await _tokenStorage.clearAll();
    _status = SpotifyConnectionStatus.disconnected;
  }
  _statusController.add(_status);
}
```

### Disconnect
```dart
// Source: project patterns
Future<void> disconnect() async {
  await _tokenStorage.clearAll();
  _spotifyApi = null;
  _status = SpotifyConnectionStatus.disconnected;
  _statusController.add(_status);
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Implicit grant flow | PKCE authorization code | Nov 27, 2025 | Implicit grant deprecated; all mobile apps MUST use PKCE |
| `localhost` redirect URIs | `127.0.0.1` or custom scheme or HTTPS | Nov 27, 2025 | `localhost` no longer accepted; custom schemes still work |
| HTTP redirect URIs | HTTPS or custom scheme | Nov 27, 2025 | HTTP redirect URIs rejected (except loopback) |
| Unlimited test users | 5 test users (Development Mode) | Feb 11, 2026 | New registrations limited; March 9 applies to existing apps |
| Free API access | Premium required (Development Mode) | Feb 11, 2026 | Developer must have Spotify Premium |
| Batch endpoints (GET /tracks, GET /artists) | Individual endpoints only | Feb 2026 | Batch metadata endpoints removed; single-item still works |
| Supabase OAuth for Spotify tokens | Direct PKCE OAuth to Spotify | Phase 31 | Supabase doesn't reliably persist Spotify provider tokens |

**Deprecated/outdated:**
- Implicit grant flow: Removed Nov 2025. Use PKCE instead.
- HTTP redirect URIs: Removed Nov 2025. Use HTTPS or custom scheme.
- `localhost` in redirect URIs: Removed Nov 2025. Use `127.0.0.1` for local testing.
- `GET /tracks` (bulk), `GET /artists` (bulk): Removed Feb 2026. Use individual endpoints.
- `GET /artists/{id}/top-tracks`: Removed Feb 2026.

## Existing Codebase Inventory

### Already Present (reuse)
| File | What's There | Reuse? |
|------|-------------|--------|
| `lib/core/constants/spotify_constants.dart` | Scopes, redirect scheme, redirect URL | YES -- extend with client ID env var key |
| `android/app/src/main/AndroidManifest.xml` | Deep link intent filter for `io.runplaylist.app://login-callback` | YES -- already configured |
| `ios/Runner/Info.plist` | URL scheme `io.runplaylist.app` | YES -- already configured |
| `lib/features/auth/data/auth_repository.dart` | Supabase OAuth with Spotify | LEAVE -- separate concern, may deprecate later |
| `.env` | Environment variables loaded via `flutter_dotenv` | YES -- add `SPOTIFY_CLIENT_ID` |
| `pubspec.yaml` | `flutter_secure_storage: ^9.2.4`, `url_launcher: ^6.3.2` | YES -- already present |

### New (to build)
| Component | Purpose |
|-----------|---------|
| `SpotifyAuthService` (abstract) | Interface for auth service (mockable) |
| `SpotifyTokenStorage` | Secure credential persistence wrapper |
| `SpotifyAuthRepository` | Real implementation using `spotify` package |
| `MockSpotifyAuthRepository` | Mock implementation for development/testing |
| `SpotifyConnectionStatus` | Enum for auth state |
| `spotify_auth_providers.dart` | Riverpod providers |
| Settings UI section | "Connect Spotify" / "Disconnect" in SettingsScreen |

## Spotify API Endpoint Availability (Feb 2026)

Endpoints needed by Phases 31-33 that are confirmed available:
| Endpoint | Status | Phase |
|----------|--------|-------|
| `/authorize` + `/api/token` (PKCE) | Available | 31 |
| `GET /search` | Available | 32 |
| `GET /me` | Available | 31 (verify connection) |
| `GET /me/playlists` | Available | 33 |
| `GET /playlists/{id}/tracks` | Available | 33 |

Scopes needed:
- `user-read-email user-read-private`: For user profile verification
- `user-top-read`: For future taste analysis
- `user-library-read`: For library access (may have restrictions)
- `playlist-modify-public playlist-modify-private`: For future playlist creation

Note: The existing `spotify_constants.dart` already defines these scopes.

## Open Questions

1. **Deep link listener mechanism**
   - What we know: Android/iOS deep link config is already in place. The app currently uses Supabase OAuth which handles redirects via `supabase_flutter`.
   - What's unclear: What mechanism should listen for the Spotify PKCE callback? Options: (a) `app_links` package, (b) `WidgetsBindingObserver.didChangeAppLifecycleState` + platform channel, (c) manual `getInitialLink` + `linkStream` from `uni_links`.
   - Recommendation: Use Flutter's built-in `PlatformDispatcher` or a lightweight deep link package. The existing intent filter/URL scheme config means the app WILL receive the callback; we just need to listen for it. Since the existing Supabase deep link is on the same scheme, ensure the Spotify callback uses a distinct path (e.g., `io.runplaylist.app://spotify-callback` vs `io.runplaylist.app://login-callback`). **This is a planner decision.**

2. **Spotify Client ID availability**
   - What we know: Dashboard is not accepting new registrations. A client ID may not be available.
   - What's unclear: When Dashboard will reopen.
   - Recommendation: Add `SPOTIFY_CLIENT_ID` to `.env` with a placeholder value. The `MockSpotifyAuthRepository` works without a real client ID. Real auth testing deferred.

3. **Web platform deep link handling**
   - What we know: Web OAuth typically uses redirect to current page URL with query parameters.
   - What's unclear: How to handle the callback on web where there's no custom scheme.
   - Recommendation: For web, the redirect URI would be an HTTPS URL (e.g., `https://app.runplaylist.ai/spotify-callback`). This requires domain setup. Defer web Spotify auth to later; focus on mobile first. The abstract interface supports this deferral cleanly.

## Sources

### Primary (HIGH confidence)
- [Spotify PKCE Flow Tutorial](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow) - Full PKCE flow documentation
- [Spotify Authorization Concepts](https://developer.spotify.com/documentation/web-api/concepts/authorization) - Supported flows, scopes
- [Spotify Token Refresh](https://developer.spotify.com/documentation/web-api/tutorials/refreshing-tokens) - Refresh endpoint, token rotation
- [Spotify Web API Changes Feb 2026](https://developer.spotify.com/documentation/web-api/references/changes/february-2026) - Available/removed endpoints
- [spotify-dart GitHub](https://github.com/rinukkusu/spotify-dart) - PKCE example, README, credential handling
- [spotify package pub.dev](https://pub.dev/packages/spotify) - v0.15.0, published Dec 2025
- [flutter_secure_storage pub.dev](https://pub.dev/packages/flutter_secure_storage) - Platform storage backends

### Secondary (MEDIUM confidence)
- [Spotify OAuth Migration Blog](https://developer.spotify.com/blog/2025-10-14-reminder-oauth-migration-27-nov-2025) - Implicit grant deprecation, redirect URI rules
- [Spotify Developer Access Update](https://developer.spotify.com/blog/2026-02-06-update-on-developer-access-and-platform-security) - Development Mode changes, Premium requirement
- [spotify-dart PKCE Issue #81](https://github.com/rinukkusu/spotify-dart/issues/81) - PKCE implementation discussion and PR #237

### Tertiary (LOW confidence)
- [TechCrunch Spotify Developer Changes](https://techcrunch.com/2026/02/06/spotify-changes-developer-mode-api-to-require-premium-accounts-limits-test-users/) - Development Mode limitations reporting

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - spotify package PKCE support verified via GitHub source + README, flutter_secure_storage already in project
- Architecture: HIGH - Pattern follows spotify-dart's documented PKCE flow exactly, existing codebase patterns well understood
- Pitfalls: HIGH - Deep link config already verified in AndroidManifest.xml and Info.plist, Supabase/Spotify auth separation clearly understood from codebase analysis
- API availability: HIGH - Search, user playlists, playlist tracks confirmed available in Feb 2026 changes documentation

**Research date:** 2026-02-09
**Valid until:** 2026-03-09 (30 days -- stable domain, but monitor Spotify Dashboard reopening)
