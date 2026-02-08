# Technology Stack: Song Search & Spotify Integration Foundation

**Project:** Running Playlist AI
**Milestone:** Song Search + Spotify API Foundation
**Researched:** 2026-02-08
**Overall confidence:** HIGH

---

## Scope: What This Document Covers

This STACK.md covers **only the additions and changes** needed for song search typeahead and Spotify Web API integration. The existing stack (Flutter 3.38, Dart 3.10, Riverpod 2.x manual providers, GoRouter 17.x, SharedPreferences 2.5.4, http 1.6.0, supabase_flutter, url_launcher, GetSongBPM API) is validated and stable from prior milestones. Do not re-evaluate it.

New capabilities that drive stack decisions:
1. Song search typeahead (autocomplete) -- search curated songs locally + Spotify songs remotely
2. Spotify Web API client -- search endpoint, playlist retrieval, track metadata
3. OAuth PKCE flow -- direct Spotify authentication (replacing/supplementing Supabase OAuth proxy)
4. Token management -- secure storage and refresh of Spotify access/refresh tokens

**Critical context:** Spotify Developer Dashboard is not accepting new app registrations (since late December 2025, no ETA for reopening). We are building the foundation against current API docs so it is ready when access opens. All Spotify API integration must be designed to degrade gracefully when no client ID is configured.

---

## Critical Decision 1: Spotify Web API Client Package

### The Key Question

Should we use the `spotify` (spotify-dart) package or build a thin API client on top of the existing `http` package?

### Decision: Use the `spotify` package (v0.15.0)

The `spotify` package (pub.dev/packages/spotify) is a Dart library wrapping the Spotify Web API. It provides typed models for all Spotify entities (tracks, artists, albums, playlists) and handles OAuth token management including PKCE flow.

| Factor | Assessment |
|--------|-----------|
| **Dependency compatibility** | Uses `http: ^1.6.0` -- exact same version constraint as our app. Uses `json_annotation: ^4.9.0` -- same as our app. Zero version conflicts. |
| **PKCE support** | Built-in since v0.13.2. `SpotifyApi.generateCodeVerifier()` + `SpotifyApiCredentials.pkce()` handle the full flow. |
| **API coverage** | Search, playlists, tracks, artists, albums, user profile, top items. Covers everything we need now and for future milestones. |
| **Maintenance** | Last updated December 14, 2025 (v0.15.0). 662 commits, 34 releases, 214 stars. Actively maintained. |
| **Platform support** | Pure Dart -- works on Android, iOS, web, desktop. No native dependencies or FFI. |
| **Code generation** | Does NOT require build_runner or code-gen. Safe given our broken Dart 3.10 code-gen setup. |
| **Dart SDK** | Requires Dart SDK >= 3.0. Our app uses 3.10. Compatible. |

### Why NOT Build a Custom Client

Building a custom Spotify API client on top of `http` would mean:
- Reimplementing OAuth PKCE token exchange (code verifier generation, SHA-256 code challenge, authorization URL construction, token endpoint calls, refresh token rotation)
- Writing Dart model classes for every Spotify entity (Track, Artist, Album, Playlist, SearchResult, Paging)
- Handling pagination (Spotify uses cursor-based paging with `next`/`previous` URLs)
- Managing token refresh with automatic retry on 401
- Implementing rate limit handling (429 with Retry-After header)

The `spotify` package handles all of this. Building it ourselves would take 500+ lines of boilerplate for zero benefit. The package's `http` dependency is literally the same version we already use.

### Why NOT `spotify_sdk`

The `spotify_sdk` package wraps the **native** Spotify Remote SDKs (iOS/Android) and Web Playback SDK. It is for **playback control** (play, pause, skip), not Web API access. It does not provide search, playlist retrieval, or track metadata endpoints. It also requires native SDK setup per platform, adding significant configuration complexity. We need Web API access, not playback control.

### Why NOT `spotikit`

Android-only as of the latest release. iOS support is "planned." Our app targets Android, iOS, and web. Not viable.

**Confidence:** HIGH (version compatibility verified against pubspec.yaml, PKCE support verified in GitHub example code, API coverage verified in package documentation)

---

## Critical Decision 2: Typeahead / Autocomplete Widget

### The Key Question

Should we use `flutter_typeahead`, Flutter's built-in `Autocomplete` widget, or build a custom search UI?

### Decision: Use Flutter's Built-in `Autocomplete` Widget

Flutter's `Autocomplete` widget (in `package:flutter/material.dart`) provides everything needed for song search typeahead:

| Capability | Built-in Autocomplete | flutter_typeahead |
|-----------|----------------------|-------------------|
| Async suggestions | Yes (optionsBuilder returns FutureOr) | Yes |
| Debouncing | Yes (documented in official examples) | Yes (default 300ms) |
| Custom field builder | Yes (fieldViewBuilder) | Yes (builder) |
| Custom options display | Yes (optionsViewBuilder) | Yes (itemBuilder) |
| Platform support | All Flutter platforms | All Flutter platforms |
| Material Design 3 | Native M3 support | Themed separately |
| Maintained by | Flutter team | Community (last update: Feb 2024, 24 months ago) |
| Dependency | None (part of Flutter SDK) | External package |

### Why NOT flutter_typeahead

1. **Stale**: Last published February 2024 -- 24 months ago. No updates for Dart 3.10 or Flutter 3.38.
2. **Redundant**: Flutter's built-in `Autocomplete` now supports async options with debouncing, which was the original differentiator of flutter_typeahead.
3. **API churn**: Version 5.x introduced breaking changes (removed `TextFieldConfiguration`, removed `TypeAheadFormField`). Adding a dependency with API instability is unnecessary when the built-in widget is stable.
4. **Zero dependency principle**: We have successfully built 4 milestones with zero unnecessary external dependencies. Adding a package that duplicates Flutter SDK functionality breaks that pattern.

### Implementation Approach

```dart
Autocomplete<SearchResult>(
  optionsBuilder: (textEditingValue) async {
    if (textEditingValue.text.length < 2) return [];
    // 1. Search curated songs locally (instant)
    // 2. Search Spotify API remotely (debounced)
    // 3. Merge and deduplicate results
    return mergedResults;
  },
  optionsViewBuilder: (context, onSelected, options) {
    return ListView.builder(
      itemCount: options.length,
      itemBuilder: (context, index) => SongSearchTile(
        result: options.elementAt(index),
        onTap: () => onSelected(options.elementAt(index)),
      ),
    );
  },
  fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        hintText: 'Search songs...',
        prefixIcon: Icon(Icons.search),
      ),
    );
  },
)
```

Debouncing is handled by wrapping the Spotify API call in a `Timer`-based debounce utility (standard Dart pattern, ~10 lines of code). Local curated song search returns instantly with no debounce needed.

**Confidence:** HIGH (Autocomplete widget verified in Flutter API docs with async + debounce examples)

---

## Critical Decision 3: OAuth PKCE Flow Architecture

### The Key Question

The app currently authenticates via Supabase OAuth (which proxies Spotify OAuth). For direct Spotify Web API access, do we use Supabase's provider token, implement standalone PKCE, or both?

### Current State

The existing `AuthRepository` signs in via `Supabase.auth.signInWithOAuth(OAuthProvider.spotify)`. Supabase acts as the OAuth intermediary. The Supabase session contains a `providerToken` (Spotify access token) and `providerRefreshToken` when the Spotify provider is configured.

### Decision: Dual-Path Architecture

**Path 1 -- Supabase Provider Token (preferred when available):**
When the user is authenticated via Supabase OAuth with Spotify, extract the Spotify access token from `session.providerToken`. This avoids a second OAuth flow. Use this token for Spotify Web API calls.

**Path 2 -- Standalone PKCE (fallback/future):**
Build the PKCE infrastructure using the `spotify` package's built-in PKCE support (`SpotifyApiCredentials.pkce()`) for scenarios where:
- Supabase is not initialized or configured
- The provider token is expired and Supabase cannot refresh it
- We want to decouple from Supabase entirely in a future milestone

### Why Dual-Path

1. **Supabase is already integrated and handling auth.** Ripping it out introduces risk and requires UI changes to the login flow.
2. **Provider token extraction is simpler** -- no additional OAuth flow needed for users already logged in.
3. **Standalone PKCE provides independence** -- if Supabase is ever removed or the provider token proves unreliable, the PKCE path is ready.
4. **Spotify requires PKCE for mobile apps** since November 2025 (implicit grant flow removed). The `spotify` package's PKCE implementation is Spotify-compliant.

### Token Storage

**Decision: Use `flutter_secure_storage` (already in pubspec.yaml but unused)**

The app already depends on `flutter_secure_storage: ^9.2.4`. It was added in the foundation milestone but never used. Spotify tokens should be stored securely because they grant access to the user's Spotify account.

| Storage Option | Assessment |
|---------------|-----------|
| SharedPreferences | Stores in plaintext. Spotify tokens grant account access -- not appropriate. |
| flutter_secure_storage | Uses Keychain (iOS), EncryptedSharedPreferences (Android), libsecret (Linux). Already a dependency. |
| In-memory only | Tokens lost on app restart -- user must re-auth every session. Poor UX. |

`flutter_secure_storage` stores the Spotify access token, refresh token, and expiration timestamp. The `spotify` package's `SpotifyApiCredentials` can be reconstructed from stored tokens.

**Confidence:** HIGH (flutter_secure_storage already in pubspec.yaml; Supabase provider token pattern documented in supabase_flutter docs)

---

## Recommended Stack Additions

### New Dependencies

| Package | Version | Purpose | Why This Package |
|---------|---------|---------|-----------------|
| `spotify` | ^0.15.0 | Spotify Web API client with typed models, PKCE auth, search, playlists | Only actively maintained pure-Dart Spotify Web API client. Compatible `http` version. No code-gen required. |

### Existing Dependencies -- New Usage

| Package | Version | New Usage | Notes |
|---------|---------|-----------|-------|
| `flutter_secure_storage` | ^9.2.4 | Store Spotify access/refresh tokens securely | Already in pubspec.yaml but unused. No version change needed. |
| `http` | ^1.6.0 | Shared with `spotify` package (transitive) | No version change needed. `spotify` uses same constraint. |
| `shared_preferences` | ^2.5.4 | Cache Spotify search results, store search history | Existing pattern. New keys only. |
| `flutter_riverpod` | ^2.6.1 | New providers for Spotify client, search state, token management | Existing pattern. |
| `go_router` | ^17.0.1 | New route for song search screen | Existing pattern. |

### No New Dependencies Needed For

| Capability | Why No New Package |
|-----------|-------------------|
| Typeahead/autocomplete | Flutter's built-in `Autocomplete` widget handles async + debounce |
| Debouncing | `dart:async` `Timer` -- 10 lines of utility code |
| JSON serialization | Hand-written `fromJson`/`toJson` (existing pattern, code-gen broken) |
| OAuth PKCE | `spotify` package handles the full flow |
| Token refresh | `spotify` package's `SpotifyApi` auto-refreshes tokens |

---

## Installation

```bash
# One new dependency
flutter pub add spotify:^0.15.0
```

No other installation steps. `flutter_secure_storage` is already in `pubspec.yaml`.

---

## Spotify Web API: Key Endpoints and Scopes

### Endpoints We Need

| Endpoint | Method | Purpose | Scope Required |
|----------|--------|---------|---------------|
| `/v1/search` | GET | Search songs by name/artist | None (public data) |
| `/v1/me/playlists` | GET | List user's playlists | `playlist-read-private`, `playlist-read-collaborative` |
| `/v1/me/top/tracks` | GET | User's top tracks (for taste learning) | `user-top-read` |
| `/v1/me/top/artists` | GET | User's top artists (for taste learning) | `user-top-read` |
| `/v1/me` | GET | User profile | `user-read-private`, `user-read-email` |

### Search Endpoint Details

The Spotify search endpoint (`/v1/search`) is the primary driver for typeahead:

- **No user auth required** -- works with client credentials (no user login needed just to search)
- **Parameters:** `q` (query string), `type` (comma-separated: track, artist, album), `limit` (1-50, default 20), `offset` (0-1000), `market` (ISO country code)
- **Rate limits:** Rolling 30-second window, exact limit not disclosed. Returns 429 with `Retry-After` header when exceeded.
- **Response:** Paginated results with `items`, `total`, `next`, `previous`

For typeahead, we will use `type=track`, `limit=5` (enough for autocomplete dropdown), and debounce at 300ms.

### Scopes Configuration

The existing `spotify_constants.dart` already defines scopes:
```dart
const String spotifyScopes =
    'user-read-email user-read-private user-top-read '
    'user-library-read playlist-modify-public playlist-modify-private';
```

This is **almost complete**. Missing scopes for playlist reading:
- `playlist-read-private` -- needed to list user's own private playlists
- `playlist-read-collaborative` -- needed to see collaborative playlists

Updated scopes:
```dart
const String spotifyScopes =
    'user-read-email user-read-private user-top-read '
    'user-library-read playlist-read-private playlist-read-collaborative '
    'playlist-modify-public playlist-modify-private';
```

**Confidence:** HIGH (scope requirements verified in Spotify developer documentation, search endpoint docs confirmed no scope needed)

---

## Architecture: Spotify API Client Integration

### Client Initialization Pattern

```dart
// Provider for Spotify API client
final spotifyClientProvider = Provider<SpotifyApi?>((ref) {
  final clientId = dotenv.env['SPOTIFY_CLIENT_ID'];
  if (clientId == null || clientId.isEmpty) return null; // Graceful degradation

  // Try to restore from stored credentials first
  final storedCredentials = ref.watch(spotifyCredentialsProvider);
  if (storedCredentials != null) {
    return SpotifyApi.fromCredentials(storedCredentials);
  }

  // Fall back to client credentials (search-only, no user data)
  return SpotifyApi(SpotifyApiCredentials(clientId, clientSecret));
});
```

### Graceful Degradation

Since Spotify Developer Dashboard is not accepting new apps, the entire Spotify integration must work in "offline" mode:

| State | Search Behavior | Playlist Behavior |
|-------|----------------|-------------------|
| No Spotify client ID configured | Curated songs only (local search) | Generate from curated songs only |
| Client ID configured, no user auth | Curated + Spotify search (client credentials) | Generate from curated songs only |
| Client ID + user authenticated | Curated + Spotify search + user data | Full Spotify playlist creation |

This means:
- Song search works immediately with curated songs (no Spotify needed)
- Spotify search is an additive enhancement, not a requirement
- All Spotify-dependent UI elements show appropriate empty/disabled states

**Confidence:** HIGH (pattern follows existing graceful degradation in `CuratedSongRepository`)

---

## Search Architecture: Dual-Source with Merge

### Local Curated Song Search

The app has 5,066 curated songs loaded into memory. Local search is:
- **Instant** -- in-memory string matching, no network call
- **Always available** -- works offline, no API key needed
- **Rich metadata** -- genre, BPM, runnability score, danceability

Implementation: Simple case-insensitive substring match on `title` and `artistName` fields of loaded `CuratedSong` objects. No new packages needed.

### Spotify API Search

When a Spotify client is available, supplement local results with Spotify search:
- **Debounced** -- 300ms delay after user stops typing
- **Limited** -- `limit=5` to keep autocomplete responsive
- **Type-filtered** -- `type=track` only (we don't need album/artist/playlist results for song search)

### Result Merging

```dart
class SearchResult {
  final String title;
  final String artistName;
  final SearchSource source; // curated, spotify, both
  final CuratedSong? curatedSong; // present if from curated dataset
  final SpotifyTrack? spotifyTrack; // present if from Spotify
  final int? bpm; // from curated data if available
}
```

Merge strategy:
1. Show curated results first (they have BPM + runnability data)
2. Append Spotify results that are NOT in curated dataset (deduplicate by normalized artist|title key)
3. Mark results with source indicator so UI can show data availability

**Confidence:** HIGH (uses existing `SongKey.normalize()` for deduplication, same lookup key format used throughout the app)

---

## What NOT to Add

| Technology | Why NOT |
|-----------|---------|
| **flutter_typeahead** | Stale (24 months since last update). Flutter's built-in `Autocomplete` handles async + debounce natively. Adding a redundant external dependency. |
| **spotify_sdk** | For native playback control, not Web API access. Requires native SDK setup per platform. We need search and playlists, not play/pause. |
| **spotikit** | Android-only. We target Android, iOS, and web. |
| **oauth2** (standalone) | The `spotify` package already depends on and wraps `oauth2` for PKCE. No need to add it separately. |
| **app_links / uni_links** | Deep link handling for OAuth redirect is already handled by Supabase's URL callback. The `spotify` package's PKCE flow handles redirect URI parsing internally. |
| **flutter_web_auth** / **flutter_web_auth_2** | OAuth web view package. The `spotify` package manages the auth flow. If we need a web view, `url_launcher` (already in pubspec) opens the browser for auth. |
| **dio** | HTTP client alternative. The `spotify` package uses `http` internally (same as our app). Adding dio would mean two HTTP clients for no benefit. |
| **riverpod_generator** | Still broken with Dart 3.10. Continue with manual providers. |
| **freezed** (for new models) | Existing models use hand-written serialization. Stay consistent. |
| **cached_network_image** | Not needed for song search. Album art display is a future concern if we add Spotify album images. |

---

## Existing Stack: Confirmed Sufficient (Unchanged)

| Package | Version | Continued Usage |
|---------|---------|----------------|
| `flutter_riverpod` | ^2.6.1 | New providers for Spotify client, search state, token management |
| `go_router` | ^17.0.1 | New route for song search screen |
| `shared_preferences` | ^2.5.4 | Cache Spotify search results, search history |
| `http` | ^1.6.0 | Shared transitively with `spotify` package |
| `url_launcher` | ^6.3.2 | Open Spotify auth URL in browser (PKCE flow) |
| `supabase_flutter` | ^2.12.0 | Existing auth (provider token extraction for Spotify) |
| `flutter_dotenv` | ^6.0.0 | `SPOTIFY_CLIENT_ID` and `SPOTIFY_CLIENT_SECRET` env vars |
| `flutter_secure_storage` | ^9.2.4 | **First actual usage** -- store Spotify tokens securely |

---

## New Environment Variables

| Variable | Purpose | Required |
|----------|---------|----------|
| `SPOTIFY_CLIENT_ID` | Spotify app client ID for API access | No (graceful degradation without it) |
| `SPOTIFY_CLIENT_SECRET` | Spotify app client secret (for client credentials flow only; NOT used in PKCE) | No (only needed for unauthenticated search) |

These go in `.env` alongside existing `SUPABASE_URL` and `SUPABASE_ANON_KEY`.

---

## New SharedPreferences Keys

| Key | Type | Purpose |
|-----|------|---------|
| `spotify_search_cache` | String (JSON) | Cached search results to reduce API calls for repeated queries |
| `recent_searches` | String (JSON list) | Recent search queries for search history UI |

Total new storage: negligible (<50 KB even with aggressive caching).

---

## Dependency Version Compatibility Matrix

| Package | Our Version | `spotify` Requires | Compatible? |
|---------|------------|-------------------|-------------|
| `http` | ^1.6.0 | ^1.6.0 | Yes (identical) |
| `json_annotation` | ^4.9.0 | ^4.9.0 | Yes (identical) |
| Dart SDK | ^3.10.8 | >=3.0 | Yes |
| `meta` | (Flutter SDK) | ^1.17.0 | Yes (Flutter bundles meta) |
| `oauth2` | (not direct) | ^2.0.5 (transitive) | Yes (no conflicts) |

**Zero version conflicts.** The `spotify` package was clearly developed alongside the same dependency ecosystem we use.

**Confidence:** HIGH (all version constraints verified against pubspec.yaml and pub.dev package pages)

---

## Alternatives Considered

| Decision | Chosen | Alternative | Why Not Alternative |
|----------|--------|------------|-------------------|
| Spotify API client | `spotify` package (v0.15.0) | Custom client on `http` | 500+ lines of boilerplate for OAuth, models, pagination, rate limiting. Package does it all with same `http` version. |
| Autocomplete UI | Flutter's built-in `Autocomplete` | `flutter_typeahead` | flutter_typeahead is 24 months stale. Built-in widget supports async + debounce natively. Zero dependency is better. |
| OAuth PKCE | `spotify` package's built-in PKCE | `flutter_web_auth_2` + manual token exchange | spotify package handles the entire flow. Adding a second OAuth package is redundant. |
| Token storage | `flutter_secure_storage` (existing dep) | SharedPreferences | Tokens grant Spotify account access -- must be encrypted at rest. flutter_secure_storage is already in pubspec. |
| Search approach | Dual-source (local + Spotify) | Spotify-only search | Local curated search works without API key. Must function while Spotify dashboard is closed. |

---

## Sources

### Primary (HIGH confidence)
- [spotify package v0.15.0 on pub.dev](https://pub.dev/packages/spotify) -- version, dependencies, platform support verified
- [spotify-dart GitHub repository](https://github.com/rinukkusu/spotify-dart) -- PKCE example code, API coverage, maintenance activity verified
- [Spotify Web API Authorization docs](https://developer.spotify.com/documentation/web-api/concepts/authorization) -- PKCE requirements, auth flow types
- [Spotify Web API Scopes docs](https://developer.spotify.com/documentation/web-api/concepts/scopes) -- scope requirements per endpoint
- [Spotify Search endpoint docs](https://developer.spotify.com/documentation/web-api/reference/search) -- parameters, response format, no scope required
- [Flutter Autocomplete widget docs](https://api.flutter.dev/flutter/material/Autocomplete-class.html) -- async support, debounce, builder parameters
- [Spotify OAuth migration notice (Nov 2025)](https://developer.spotify.com/blog/2025-10-14-reminder-oauth-migration-27-nov-2025) -- implicit grant removed, PKCE required for mobile

### Secondary (MEDIUM confidence)
- [flutter_typeahead on pub.dev](https://pub.dev/packages/flutter_typeahead) -- last update date (Feb 2024), version 5.2.0
- [spotify_sdk on pub.dev](https://pub.dev/packages/spotify_sdk) -- confirmed playback-only, not Web API
- [Spotify rate limits docs](https://developer.spotify.com/documentation/web-api/concepts/rate-limits) -- rolling 30s window, 429 response handling
- [Spotify Developer Dashboard status](https://community.spotify.com/t5/Spotify-for-Developers/New-integrations-are-currently-on-hold/td-p/7296575) -- new app registration paused since Dec 2025

### Tertiary (LOW confidence)
- [oauth2 package on pub.dev](https://pub.dev/packages/oauth2) -- PKCE support unclear from pub.dev page alone, but `spotify` package wraps it successfully
