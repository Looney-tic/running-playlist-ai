# Domain Pitfalls

**Domain:** Adding song search typeahead, Spotify OAuth PKCE, and playlist export to an existing Flutter running playlist app
**Researched:** 2026-02-08
**Confidence:** HIGH (grounded in codebase analysis, Spotify official documentation, Flutter platform behavior, and recent Spotify policy changes)

---

## Critical Pitfalls

### Pitfall 1: Spotify Developer Dashboard Is Blocked -- Building Code You Cannot Test End-to-End

**What goes wrong:**
The Spotify Developer Dashboard currently shows "New integrations are currently on hold" for new app creation. Even if you get a Client ID, Development Mode now requires a Spotify Premium account (effective Feb 11, 2026 for new IDs, March 9, 2026 for existing ones), limits you to 5 authorized test users, and restricts API access to a smaller set of endpoints. You build an entire OAuth + search + playlist export integration, ship it, and then discover:
- The OAuth redirect does not work because the redirect URI was never validated against a real Spotify app registration
- The search endpoint returns different data shapes than you mocked
- Token refresh silently fails because you never tested a real 1-hour token expiry cycle
- The playlist creation endpoint requires scopes you forgot to request

This is the highest-risk pitfall because every other pitfall in this document assumes you can at least test the code. Building Spotify integration without live API access means every assumption is unverified.

**Why it happens:**
Spotify has progressively tightened developer access since 2025. The Nov 2025 OAuth migration killed implicit grant flow and HTTP redirect URIs. The Feb 2026 update added Premium requirements, 5-user caps, and endpoint restrictions. Individual developers can no longer get Extended Quota Mode (requires 250,000 MAU and a registered business entity since May 2025). The dashboard "on hold" status means you may not even be able to create a new Client ID.

**Consequences:**
- Ship an OAuth flow that redirects to a dead URL
- Token refresh logic that has never been exercised against real token expiry
- Search results parsing that fails on the first real API response
- Playlist export that hits an undocumented 429 or 403 on first use

**Prevention:**
1. **Design against the contract, not the implementation.** Use Spotify's official API reference (OpenAPI spec) to define exact request/response shapes. Build typed Dart models from the spec, not from guesses.
2. **Create a `SpotifyApiClient` with an abstract interface.** Separate the HTTP transport from the business logic. The interface defines methods like `searchTracks(query)`, `createPlaylist(name, trackUris)`, `refreshToken()`. Production uses real HTTP; development uses a `MockSpotifyApiClient` that returns hardcoded JSON from the official docs.
3. **Mock at the HTTP level, not the business logic level.** Use the `http` package's `MockClient` (already proven in `GetSongBpmClient` tests) to return canned Spotify API responses. This tests your JSON parsing, error handling, and retry logic against realistic payloads.
4. **Build an integration test suite that can be toggled.** When you eventually get Dashboard access, flip a flag to run the same tests against the real API. Tests should be structured as: `testWithMock('search returns tracks', ...)` and `testWithLiveApi('search returns tracks', ..., skip: !hasSpotifyCredentials)`.
5. **Do NOT hardcode Spotify track URIs or IDs in test data.** Use plausible but clearly fake values (`spotify:track:TEST_000001`) so you never accidentally call the real API with test data.
6. **Phase the build: interfaces and mocks first, real implementation second.** The first phase should produce a fully testable mock layer. The second phase (when Dashboard access opens) replaces mock responses with real HTTP calls. The interface stays the same.

**Warning signs:**
- "It works in tests" but no test uses a real Spotify token
- JSON parsing code that has never been validated against an actual API response
- OAuth flow that opens a browser but you have never completed a real login

**Phase to address:**
FIRST PHASE. The abstraction layer and mock infrastructure must be the foundation. Every subsequent phase builds on it.

**Confidence:** HIGH -- the Dashboard status is confirmed by Spotify's official blog post (Feb 6, 2026) and TechCrunch reporting. The restrictions are policy, not bugs.

**Sources:**
- [Spotify: Update on Developer Access and Platform Security (Feb 6, 2026)](https://developer.spotify.com/blog/2026-02-06-update-on-developer-access-and-platform-security)
- [TechCrunch: Spotify changes developer mode API (Feb 6, 2026)](https://techcrunch.com/2026/02/06/spotify-changes-developer-mode-api-to-require-premium-accounts-limits-test-users/)
- [Spotify Community: New integrations currently on hold](https://community.spotify.com/t5/Spotify-for-Developers/New-integrations-are-currently-on-hold/td-p/7296575)

---

### Pitfall 2: OAuth Token Storage in SharedPreferences Leaks Credentials on Web and Rooted Devices

**What goes wrong:**
The app currently uses SharedPreferences for all persistence. The natural inclination is to store Spotify OAuth tokens (access token, refresh token) in SharedPreferences alongside everything else. On web, SharedPreferences maps to `localStorage`, which is accessible to any JavaScript running on the page (XSS vulnerability). On Android, SharedPreferences is stored as plaintext XML in the app's data directory, readable on rooted devices or by backup extraction. On iOS, NSUserDefaults is similarly unencrypted.

A leaked refresh token gives an attacker persistent access to the user's Spotify account (the refresh token does not expire unless revoked). They can read the user's listening history, modify playlists, and access private data -- all scoped to the permissions in `spotifyScopes` (which currently includes `user-read-email`, `user-read-private`, `user-top-read`, `user-library-read`, `playlist-modify-public`, `playlist-modify-private`).

**Why it happens:**
The app already has `flutter_secure_storage: ^9.2.4` in pubspec.yaml but uses SharedPreferences for everything. Adding "one more key" to SharedPreferences is the path of least resistance. The developer may not realize that OAuth tokens are categorically different from taste profiles and run plans -- they are bearer credentials that grant access to a third-party service.

**Consequences:**
- Spotify refresh token exposed in localStorage on web (visible in DevTools)
- Token extractable via ADB backup or root access on Android
- App review rejection by Spotify if they audit token storage practices
- User account compromise if device is shared or compromised

**Prevention:**
1. **Use `flutter_secure_storage` for ALL OAuth tokens.** Access token, refresh token, and token expiry timestamp must be stored in the secure keychain (iOS), EncryptedSharedPreferences (Android), or equivalent.
2. **On web, accept the trade-off.** `flutter_secure_storage` on web still uses localStorage under the hood (browsers have no secure storage API equivalent to Keychain). Mitigate by: (a) storing tokens in-memory only during the session and using the refresh flow to re-obtain them on page reload, or (b) accepting the risk and documenting it. The existing app already uses Supabase auth which stores its session in localStorage, so this is a known limitation of the web platform.
3. **Create a `TokenStorage` abstraction.** Do not scatter `SecureStorage.read('spotify_access_token')` calls throughout the codebase. A single `SpotifyTokenStorage` class handles read/write/delete/has-valid-token. This isolates the storage decision and makes migration easy.
4. **Never log tokens.** Ensure debug logging does not print access or refresh tokens. Use `token.substring(0, 8)...` if you need to log token presence for debugging.

**Warning signs:**
- `SharedPreferences` key containing "token" or "access" or "refresh" in any key name
- Tokens visible in Chrome DevTools Application > Local Storage
- Debug console printing full token strings

**Phase to address:**
OAuth implementation phase. Token storage is the first decision in the auth flow -- it must be right before any token is persisted.

**Confidence:** HIGH -- the security characteristics of SharedPreferences vs flutter_secure_storage are extensively documented. The app already has `flutter_secure_storage` as a dependency.

**Sources:**
- [Token Theft via SharedPreferences in Flutter Apps](https://medium.com/flutter-minds/part-4-token-theft-via-sharedpreferences-how-jwts-leak-from-flutter-apps-7e7dec6271d3)
- [Securely Storing JWTs in Flutter Web Apps](https://carmine.dev/posts/flutterwebjwt/)
- [flutter_secure_storage package](https://pub.dev/packages/flutter_secure_storage)

---

### Pitfall 3: Spotify PKCE Redirect URI Mismatch Between Web and Mobile Platforms

**What goes wrong:**
The existing `spotify_constants.dart` defines `spotifyRedirectUrl = 'io.runplaylist.app://login-callback'` for mobile and uses `null` (current page URL) for web. The existing auth flow goes through Supabase OAuth, which wraps the redirect handling. If you implement direct Spotify PKCE (bypassing Supabase for Spotify API calls), you need a SEPARATE redirect URI registered in the Spotify Dashboard.

The PKCE flow requires the redirect URI to match EXACTLY -- including casing, trailing slashes, and scheme. Common failures:
- Web uses `http://localhost:8080` during development but Spotify no longer accepts HTTP redirect URIs (since Nov 27, 2025), except for loopback IPs (`http://127.0.0.1` for IPv4)
- Mobile custom scheme `io.runplaylist.app://` works on Android but may fail on iOS if the URL scheme is not registered in `Info.plist`
- Web redirect lands on a page that does not extract the authorization code from the URL query parameters
- The code verifier generated before the redirect is lost because the page reloaded (web) or the app was killed (mobile) during the OAuth browser session

**Why it happens:**
OAuth PKCE involves two separate HTTP interactions with a browser redirect in between. The code verifier must survive across this redirect. On web, a page navigation clears JavaScript state unless the verifier is stored in `sessionStorage` or `localStorage`. On mobile, the app may be killed by the OS while the browser is showing the Spotify consent screen (especially on low-memory devices). When the deep link fires to reopen the app, the verifier is gone, and the token exchange fails.

The existing Supabase auth handles this transparently because Supabase manages the PKCE flow server-side. Direct Spotify PKCE means the app owns the entire flow, including verifier persistence.

**Consequences:**
- "Invalid redirect URI" error on Spotify consent screen (registration mismatch)
- Token exchange fails silently after successful consent (verifier lost)
- Works on web but fails on mobile (or vice versa) due to platform-specific redirect handling
- Works in development (`localhost`) but fails in production (different URI)

**Prevention:**
1. **Decide: Supabase-proxied OAuth or direct PKCE.** If the app already authenticates via Supabase (`AuthRepository.signInWithSpotify`), consider routing Spotify API calls through Supabase Edge Functions that use the provider token. This avoids implementing PKCE a second time. The trade-off: Supabase adds latency and a backend dependency.
2. **If doing direct PKCE, register TWO redirect URIs in the Spotify Dashboard.** One for web (`http://127.0.0.1:8080/callback` for dev, `https://yourdomain.com/callback` for prod) and one for mobile (`io.runplaylist.app://callback`). Use `kIsWeb` to select the correct one at runtime (the existing pattern in `AuthRepository`).
3. **Persist the code verifier in platform-appropriate storage.** Web: `window.sessionStorage` (not localStorage -- sessionStorage is tab-scoped, reducing the attack surface). Mobile: `flutter_secure_storage` (survives app kill). Do NOT use SharedPreferences for the verifier -- it is a short-lived security credential.
4. **Handle the redirect on web by creating a dedicated callback page.** A simple `callback.html` that extracts the `code` parameter from the URL and passes it to Dart via `window.postMessage` or by setting a flag in `sessionStorage` that the Flutter app polls on reload.
5. **Test the "app killed during OAuth" scenario.** On mobile, start the OAuth flow, force-kill the app, then tap the deep link. The app should detect the missing verifier and restart the OAuth flow gracefully (not crash or hang).
6. **For `localhost` development, use `http://127.0.0.1:PORT` not `http://localhost:PORT`.** Spotify explicitly allows loopback IP addresses but no longer allows `localhost` as an alias.

**Warning signs:**
- OAuth works on first attempt but fails on subsequent attempts (verifier reuse)
- "INVALID_CLIENT: Invalid redirect URI" error in browser
- Works perfectly in Chrome dev mode but fails when deployed

**Phase to address:**
OAuth foundation phase. The redirect URI strategy must be decided before any Dashboard registration. Get the URIs wrong and you have to re-register (which may be blocked by the Dashboard pause).

**Confidence:** HIGH -- Spotify's redirect URI requirements are explicitly documented, including the Nov 2025 HTTP deprecation. The code verifier persistence issue is a well-known PKCE implementation challenge.

**Sources:**
- [Spotify: Authorization Code with PKCE Flow](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow)
- [Spotify: Increasing security requirements (Feb 2025)](https://developer.spotify.com/blog/2025-02-12-increasing-the-security-requirements-for-integrating-with-spotify)
- [Spotify Community: PKCE INVALID_CLIENT errors](https://community.spotify.com/t5/Spotify-for-Developers/Web-API-PKCE-Authorize-Not-Working-INVALID-CLIENT-Invalid/td-p/5478109)
- [Flutter PKCE implementation discussion](https://groups.google.com/g/flutter-dev/c/F5VW4DMp41w)

---

### Pitfall 4: Spotify Token Lifecycle Mismanagement -- Silent Auth Failure After 1 Hour

**What goes wrong:**
Spotify access tokens expire after exactly 1 hour. The app makes a search request, gets results, the user browses for 45 minutes, then tries to export a playlist. The token has expired. The API returns 401. The app shows a generic "something went wrong" error. The user has to re-authenticate, losing their search context and any unsaved playlist selections.

Worse: the app might not handle 401s at all (the `http` package does not throw on non-200 responses; you must check `response.statusCode` manually). The expired-token response is parsed as song data, fails silently or crashes with a `type 'String' is not a subtype of type 'List'` error deep in JSON parsing.

**Why it happens:**
The existing `GetSongBpmClient` treats all non-200 responses as errors (`BpmApiException`). But new Spotify API code might not follow this pattern. Token expiry is easy to forget because it never happens during short development sessions. A developer tests for 30 minutes, everything works, ships it. The bug appears only in real usage where sessions span 60+ minutes.

The PKCE token refresh flow also has a subtlety: Spotify may rotate the refresh token. The response to a refresh request may include a NEW refresh token. If the code only reads `access_token` from the response and ignores the new `refresh_token`, the next refresh attempt uses the old (now invalid) refresh token and fails. The documentation states: "When a refresh token is not returned, continue using the existing token" -- meaning sometimes a new one IS returned and must be saved.

**Consequences:**
- All API calls fail silently after 1 hour of use
- User data loss if they were mid-search or mid-playlist-creation
- Infinite retry loops if the app retries failed requests without checking token validity
- Permanent logout if refresh token rotation is not handled (refresh token becomes invalid)

**Prevention:**
1. **Proactive token refresh.** Store the token expiry timestamp (returned in the token response as `expires_in: 3600`). Before every API call, check if the token expires within the next 5 minutes. If so, refresh BEFORE making the request. This eliminates 99% of expired-token errors.
2. **Reactive 401 handler as a safety net.** If a request returns 401 despite proactive refresh (clock skew, race condition), automatically refresh the token and retry the request ONCE. If the retry also fails, surface the error and prompt re-authentication.
3. **Always save the refresh token from the refresh response.** After calling `/api/token` with `grant_type=refresh_token`, check if the response contains a `refresh_token` field. If yes, overwrite the stored refresh token. If no, keep the existing one. This handles Spotify's optional token rotation.
4. **Build a `SpotifyAuthenticatedClient` wrapper** that handles token lifecycle automatically. Every API call goes through this wrapper, which checks expiry, refreshes if needed, adds the `Authorization: Bearer {token}` header, and handles 401 retries. The rest of the codebase never touches tokens directly.
5. **Unit test token expiry.** Create a test where the mock returns 401 on the first request. Verify that the client refreshes the token and retries. Create another test where the refresh response includes a new refresh token. Verify it is saved.

**Warning signs:**
- API calls work for 59 minutes then all fail
- "FormatException" or "type cast" errors in JSON parsing (parsing error response as data)
- Refresh token works once but fails on second use (rotation not handled)
- Users report having to log in again frequently

**Phase to address:**
OAuth foundation phase, in the `SpotifyAuthenticatedClient` wrapper. Token lifecycle must be correct before any API endpoint is called.

**Confidence:** HIGH -- Spotify's token expiry behavior is explicitly documented. The refresh token rotation behavior is documented in the refresh tokens tutorial.

**Sources:**
- [Spotify: Refreshing Tokens](https://developer.spotify.com/documentation/web-api/tutorials/refreshing-tokens)
- [Spotify: Authorization Code with PKCE Flow](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow)

---

## Moderate Pitfalls

### Pitfall 5: Typeahead Search Without Debouncing Hits Spotify Rate Limits

**What goes wrong:**
User types "Lose Yourself" (13 characters). Without debouncing, the app fires 13 API requests: "L", "Lo", "Los", "Lose", "Lose ", "Lose Y", etc. Spotify's rate limit is based on a rolling 30-second window. 13 requests in 3 seconds is fine for a single user, but if the user deletes and retypes, or types quickly across multiple searches, the app can hit the rate limit within minutes. A 429 response includes a `Retry-After` header; if the app does not respect it, subsequent requests also fail, creating a cascade where search appears completely broken.

The flutter_typeahead package includes built-in debouncing (default 300ms), but if you build a custom search with Flutter's `Autocomplete` widget or a raw `TextField` + `FutureBuilder`, you must implement debouncing yourself. Forgetting the debounce -- or setting it too low (50ms) -- turns every keystroke into an API call.

**Why it happens:**
Debouncing is a "nice to have" in development (where you type slowly and deliberately) but critical in production (where users type fast, make typos, and retype). The developer sees search working fine in testing and ships without debouncing or with an inadequately short debounce interval.

**Consequences:**
- 429 errors that block ALL Spotify API calls (rate limit is app-wide, not per-endpoint)
- Search appears broken for 30-60 seconds while waiting for the rate limit window to reset
- Excessive network usage on mobile data plans
- Spotify may flag the app for "pattern scraping" behavior

**Prevention:**
1. **300ms debounce minimum on all search inputs.** Use a `Timer` in the search controller. Cancel the previous timer on each keystroke, start a new 300ms timer. Only fire the API call when the timer completes (user stopped typing for 300ms).
2. **Minimum query length of 2-3 characters.** Do not fire API requests for single-character queries -- the results are useless and waste quota. Show a "Type at least 2 characters" hint instead.
3. **Cancel in-flight requests.** When the user types a new character before the previous search completes, cancel the previous HTTP request. The `http` package does not support request cancellation natively. Use `CancelableOperation` from the `async` package, or track a request generation counter and ignore stale responses.
4. **Cache recent search results.** If the user types "Lose", gets results, then types "Lose Y", do NOT re-request "Lose" when they backspace to "Lose" again. Cache the last 10 queries and their results in memory (not SharedPreferences).
5. **Handle 429 responses explicitly.** Parse the `Retry-After` header, pause all API requests for that duration, show a "Too many searches, please wait" message. Do NOT silently retry -- that compounds the problem.
6. **Implement the search with Flutter's built-in `Autocomplete` widget** rather than pulling in `flutter_typeahead`. The built-in widget is dependency-free and sufficient for a single search field with async suggestions. The app already avoids unnecessary dependencies (uses `http` instead of `dio`).

**Warning signs:**
- Network tab shows 10+ requests within 2 seconds during a search
- Search results flicker as stale responses arrive after newer ones
- "429 Too Many Requests" in debug console

**Phase to address:**
Song search UI phase. The debounce and rate limiting must be built into the search widget from the start, not added as an afterthought.

**Confidence:** HIGH -- Spotify rate limits are documented. The debounce pattern is well-established in Flutter.

**Sources:**
- [Spotify: Rate Limits](https://developer.spotify.com/documentation/web-api/concepts/rate-limits)
- [Flutter Autocomplete widget](https://api.flutter.dev/flutter/material/Autocomplete-class.html)
- [How to create a debounce utility in Flutter](https://medium.com/@valerii.novykov/how-to-create-a-debounce-utility-in-flutter-for-efficient-search-input-cd2827e3bd08)

---

### Pitfall 6: Spotify Track Data Model Collision With Existing BpmSong Model

**What goes wrong:**
The app has `BpmSong` (from GetSongBPM API) and `CuratedSong` (from curated dataset). Spotify's track object has different fields: `id` (not `songId`), `uri` (`spotify:track:...`), `name` (not `title`), nested `artists` array (not `artistName` string), `duration_ms` (not `durationSeconds`), `popularity`, `explicit`, `album.images`, and potentially audio features like `danceability` (0.0-1.0 float, not 0-100 integer).

The temptation is to convert Spotify tracks into `BpmSong` objects so they "just work" with the existing scorer. But this loses Spotify-specific data (Spotify URI for playlist export, album art for the UI, popularity for ranking) and forces awkward field mappings (Spotify's `danceability` is a 0.0-1.0 float; `BpmSong.danceability` expects 0-100 integer).

Alternatively, creating a separate `SpotifyTrack` model that does not integrate with the scorer means searched songs cannot be scored or included in the quality ranking. The user searches for a song, adds it to the playlist, but it has no quality score and no feedback integration.

**Why it happens:**
Two independent data pipelines (GetSongBPM and Spotify) produce different representations of the same real-world entity (a song). The existing codebase was designed around GetSongBPM's data shape. Spotify data does not fit the same shape.

**Consequences:**
- Spotify-searched songs cannot be scored (no BPM match type, no runnability)
- Forced conversion loses Spotify-specific data needed for playlist export
- Dual model confusion: is a song a `BpmSong` or a `SpotifyTrack`? Which model does the UI display?
- `SongKey.normalize` may produce different keys for the same song from Spotify vs GetSongBPM (artist name formatting differences)

**Prevention:**
1. **Create a `SpotifyTrack` model for Spotify-specific data** (id, uri, name, artists, duration_ms, album art, popularity). This model is NOT a replacement for `BpmSong`.
2. **Create a conversion method `SpotifyTrack.toBpmSong()`** that maps Spotify fields to `BpmSong` fields for scoring. Map `name` to `title`, `artists[0].name` to `artistName`, `duration_ms / 1000` to `durationSeconds`, `(danceability * 100).round()` to `danceability`. Set `matchType` based on whether the BPM matches the current run plan target. Set `songId` to the Spotify ID (not URI).
3. **Store the Spotify URI alongside the BpmSong.** Add a `spotifyUri` field to `BpmSong` (or to `PlaylistSong`). This field is null for GetSongBPM-sourced songs and populated for Spotify-sourced songs. Playlist export uses this URI directly instead of constructing a search URL.
4. **Use `SongKey.normalize` for feedback consistency.** When a user searches for a song on Spotify and likes it, the feedback key must match if the same song later appears from the curated dataset or GetSongBPM. Test with real examples: does Spotify's "Don't Start Now" by "Dua Lipa" produce the same key as the curated entry?
5. **Handle multi-artist tracks.** Spotify returns an `artists` array. GetSongBPM returns a single `artist.name`. For key normalization, use only the first (primary) artist. For display, show all artists joined by ", ".

**Warning signs:**
- Searched song appears in playlist but has no quality score
- Same song from two sources shows different feedback states (liked on one, unrated on other)
- Playlist export includes search-URL links instead of direct Spotify URIs for searched songs
- Danceability scores are wildly different for the same song from Spotify vs curated (scale mismatch)

**Phase to address:**
Song search data model phase (before UI). The model design determines how searched songs flow through scoring, feedback, and export.

**Confidence:** HIGH -- the field mappings are deterministic based on the Spotify API reference and the existing `BpmSong` model. The scale mismatch (0.0-1.0 vs 0-100) is a documented difference.

**Sources:**
- [Spotify Web API Reference: Search](https://developer.spotify.com/documentation/web-api/reference/search)
- [Spotify URIs and IDs](https://developer.spotify.com/documentation/web-api/concepts/spotify-uris-ids)
- Codebase analysis: `bpm_song.dart`, `curated_song.dart`, `song_feedback.dart`

---

### Pitfall 7: Spotify URI vs ID vs URL Confusion in Playlist Export

**What goes wrong:**
Spotify has three identifiers for every resource:
- **Spotify URI:** `spotify:track:6rqhFgbbKwnb9MLmUQDhG6` (used by Add Tracks to Playlist API)
- **Spotify ID:** `6rqhFgbbKwnb9MLmUQDhG6` (used in API endpoint URLs like `/tracks/{id}`)
- **Spotify URL:** `https://open.spotify.com/track/6rqhFgbbKwnb9MLmUQDhG6` (for browser/app linking)

The "Add Tracks to Playlist" endpoint requires URIs in the request body (`uris: ['spotify:track:...']`). If you pass IDs or URLs instead, the request fails with "No URIs provided" or silently adds nothing. This is the most common error in Spotify playlist integration, with multiple community threads about it.

The existing `SongLinkBuilder.spotifySearchUrl` returns search URLs (not track URLs or URIs). These are for opening Spotify to search for a song, not for API-level track identification. Mixing these up means the export flow tries to add search URLs to a playlist, which fails.

**Why it happens:**
The Spotify API uses different identifier formats for different contexts, and the naming is confusing. A "URI" in general programming means a URL. In Spotify's world, a "URI" is a non-URL identifier format (`spotify:type:id`). Developers store the URL when they should store the URI, or store the ID when the API expects the URI.

**Consequences:**
- Playlist creation succeeds but track addition fails (empty playlist)
- Silent failure: Spotify accepts malformed URIs without error but does not add the tracks
- Export feature appears to work (no error) but the Spotify playlist is empty

**Prevention:**
1. **Store the Spotify URI (not ID, not URL) for every Spotify-sourced track.** The `SpotifyTrack` model must have a `uri` field containing the full `spotify:track:...` string. This is the canonical identifier for playlist operations.
2. **Validate URI format before API calls.** A simple regex: `^spotify:track:[a-zA-Z0-9]+$`. Reject any value that does not match. Log a warning if a URL or bare ID is passed where a URI is expected.
3. **For tracks from GetSongBPM/curated (no Spotify URI), require a search-then-resolve step.** Before exporting a playlist containing non-Spotify tracks, search Spotify for each track, get the Spotify URI from the search result, then use that URI for playlist addition. This is the bridge between the existing data model and Spotify's API.
4. **Add a `spotifyUri` field to `PlaylistSong`.** Null for songs without Spotify data. The export flow checks: if `spotifyUri` is non-null, use it directly. If null, search Spotify first. This avoids re-searching songs that already have URIs.

**Warning signs:**
- API response "No URIs provided" when adding tracks
- Playlist is created but contains 0 tracks
- Track URLs being passed in the `uris` array

**Phase to address:**
Playlist export phase. But the `spotifyUri` field should be added to the data model in the search phase so searched songs carry their URI forward.

**Confidence:** HIGH -- the URI/ID/URL distinction is explicitly documented by Spotify. The "No URIs provided" error is the most common error in community forums.

**Sources:**
- [Spotify URIs and IDs](https://developer.spotify.com/documentation/web-api/concepts/spotify-uris-ids)
- [Spotify Community: Add Tracks Changed; No URIs Provided error](https://community.spotify.com/t5/Spotify-for-Developers/Add-Tracks-to-Playlist-Changed-No-URIs-Provided-error/td-p/5911269)
- [Spotify Community: Add Tracks To Playlist API Error](https://community.spotify.com/t5/Spotify-for-Developers/Add-Tracks-To-Playlist-API-Error/td-p/6223458)

---

### Pitfall 8: Search Results Do Not Have BPM -- Scoring Integration Gap

**What goes wrong:**
The Spotify Search API returns track metadata (name, artists, duration, popularity, album art) but does NOT return BPM or tempo. The existing `SongQualityScorer` uses BPM match as a scoring dimension (+3 for exact, +1 for variant). When a user searches for a song and adds it to a playlist, the scorer cannot determine the BPM match quality. The song gets a neutral BPM score (0), which is unfair compared to GetSongBPM-sourced songs that have verified BPM data.

To get a track's audio features (including tempo/BPM), you must make a SEPARATE API call to the `/audio-features/{id}` endpoint. This is an additional request per track. For 20 search results, that is 20 additional API calls (or 1 batch call to `/audio-features?ids=id1,id2,...` which accepts up to 100 IDs). This doubles the API calls for search and counts against the rate limit.

Additionally, some Spotify audio features fields (including `danceability`, `energy`, `tempo`) may be deprecated or have restricted availability. The search response now marks `available_markets`, `external_ids`, `followers`, `genres`, and `popularity` as deprecated fields.

**Why it happens:**
The Search and Track endpoints return commercial metadata (title, artist, album, duration). Audio features (BPM, danceability, energy, key, loudness) are in a separate endpoint because they are computed properties, not editorial metadata. Developers assume the search response contains everything they need and are surprised when BPM is missing.

**Consequences:**
- User-searched songs score lower than curated/API songs (missing BPM bonus)
- Additional API calls increase latency and rate limit consumption
- Audio features endpoint may have usage restrictions in Development Mode

**Prevention:**
1. **Accept that searched songs will have incomplete scoring data initially.** Do not fetch audio features for every search result -- that is wasteful. Only fetch audio features when the user SELECTS a song to add to the playlist (or to their library).
2. **Assign neutral BPM scores to songs without BPM data.** The existing pattern: `danceabilityNeutral = 3`, `runnabilityNeutral = 5`. Add a `bpmNeutral = 1` for songs without BPM data. This prevents penalizing searched songs while still giving a slight advantage to songs with verified BPM match.
3. **Use the batch audio features endpoint.** When the user finalizes a playlist for export, fetch audio features for all Spotify-sourced songs in one batch call (`/audio-features?ids=...`). This is 1 API call instead of N.
4. **Cache audio features.** Once fetched, store the BPM/danceability/energy for a song in the local cache (keyed by Spotify ID). If the user searches for the same song again, use the cached features.
5. **Cross-reference searched songs with the curated dataset.** If the user searches for "Lose Yourself" and it matches a curated song (via `SongKey.normalize`), use the curated BPM, runnability, and danceability data. The curated dataset has 5,066 songs -- there will be significant overlap.

**Warning signs:**
- Search results all show the same quality score regardless of how well they match the run plan
- Audio features requests double the time to display search results
- 429 errors triggered by audio features batch calls during playlist export

**Phase to address:**
Song search scoring integration phase (after search UI, before playlist export). The scoring gap must be addressed before users notice that searched songs are always ranked lower.

**Confidence:** HIGH -- the Spotify Search response format is documented. The audio features endpoint is a separate call. The curated cross-reference strategy leverages existing infrastructure.

**Sources:**
- [Spotify Web API Reference: Search](https://developer.spotify.com/documentation/web-api/reference/search)
- Codebase analysis: `song_quality_scorer.dart`, `bpm_song.dart`

---

### Pitfall 9: Two Auth Systems -- Supabase OAuth vs Direct Spotify PKCE Conflict

**What goes wrong:**
The app currently authenticates via Supabase OAuth (`AuthRepository.signInWithSpotify`). Supabase handles the Spotify OAuth flow, stores the session, and provides a Supabase access token. But Supabase's provider token (the Spotify access token stored by Supabase) may not be accessible or refreshable from the client. To call the Spotify API directly, you need a Spotify access token that you control -- including the ability to refresh it.

If you implement a SECOND OAuth flow (direct PKCE) alongside Supabase, the user now has TWO separate auth sessions: one via Supabase (for your backend) and one direct to Spotify (for API calls). These sessions have independent lifecycles: the Supabase session might expire while the Spotify token is still valid, or vice versa. The user is "logged in" to one system but "logged out" of the other. The app shows confusing states like "Welcome back, Tijmen!" but "Please connect your Spotify account."

**Why it happens:**
The app was built with Supabase OAuth as the primary auth mechanism. Supabase provides user identity and session management. Adding direct Spotify API access requires Spotify's own access token, which Supabase may not expose or keep fresh. The two auth systems were designed independently and do not share token lifecycle.

**Consequences:**
- User logs in once but sees two consent screens (Supabase OAuth then Spotify PKCE)
- Token refresh for one system succeeds while the other fails
- Confusing logged-in/logged-out state combinations
- Double the auth-related code, double the auth-related bugs

**Prevention:**
1. **First choice: Use Supabase's provider token.** After Supabase OAuth with Spotify, check if Supabase exposes the Spotify access token via `session.providerToken` or `session.providerRefreshToken`. If available, use these tokens for Spotify API calls and let Supabase manage the lifecycle. This is the simplest approach.
2. **If Supabase does not expose/refresh the provider token, implement a Supabase Edge Function** that proxies Spotify API calls using the server-side provider token. The Flutter app calls your Edge Function, which calls Spotify. This keeps auth management server-side.
3. **If neither option works (no backend desired), replace Supabase OAuth with direct PKCE for Spotify** and use Supabase only for non-auth features (database, etc.). Do NOT maintain two parallel auth flows.
4. **If you must maintain both, synchronize the logout.** When the user logs out from one system, log out from both. When one token expires, check the other. Display auth state as a single unified concept: "Connected to Spotify" means both systems are authenticated.
5. **Research Supabase's provider token handling before writing any code.** This is the fork-in-the-road decision. If Supabase provides the Spotify token, the entire PKCE implementation is unnecessary. If not, PKCE is required. Do not assume -- check the Supabase docs and test with your Supabase instance.

**Warning signs:**
- Two separate "Login with Spotify" buttons or flows
- User reports: "I logged in but search doesn't work" (logged into Supabase but not Spotify direct)
- Token refresh code duplicated in two places
- Logout does not fully disconnect (one system still has a valid session)

**Phase to address:**
FIRST PHASE (before any API work). The auth architecture decision (Supabase-proxied vs direct PKCE) determines the entire integration strategy.

**Confidence:** MEDIUM -- Supabase's provider token behavior varies by SDK version and is not fully documented for all edge cases. This needs empirical verification with the actual Supabase instance.

**Sources:**
- [Supabase Flutter Auth documentation](https://supabase.com/docs/reference/dart/auth-signinwithoauth)
- Codebase analysis: `auth_repository.dart`, `auth_providers.dart`

---

## Minor Pitfalls

### Pitfall 10: Spotify Search Returns Irrelevant Results for Short Queries

**What goes wrong:**
Searching for "Run" returns Spotify tracks titled "Run" by dozens of artists, "Running Up That Hill", "Run This Town", "Runner", and so on. The search is too broad. Searching for "Ed" returns Ed Sheeran tracks but also "The Edge" by U2, "Ed, Edd n Eddy" soundtrack songs, etc. Short or common-word queries produce noisy results that make the typeahead feel broken.

**Prevention:**
1. Require minimum 2-3 characters before firing a search.
2. Use Spotify's field filters: `q=track:Lose artist:Eminem` narrows results significantly.
3. Show search results grouped by relevance: exact title matches first, then partial matches.
4. Consider pre-populating the search with the run plan's genre context (if user's taste profile is Pop, bias search results toward Pop tracks).

**Phase to address:** Song search UI phase.

**Confidence:** MEDIUM -- behavior is based on Spotify community reports and general search API characteristics.

---

### Pitfall 11: Playlist Export Scope Mismatch -- "Insufficient Client Scope" on First Export Attempt

**What goes wrong:**
The app requests OAuth scopes at login time. If playlist export scopes (`playlist-modify-public`, `playlist-modify-private`) are not included in the initial scope request, the first export attempt fails with 403 "Insufficient client scope." The user must log out and log in again with the correct scopes. The existing `spotifyScopes` constant includes these scopes, but if the PKCE flow uses different scopes (or forgets to pass scopes entirely), the export breaks.

**Prevention:**
1. Request ALL needed scopes upfront during the initial OAuth flow. The existing `spotify_constants.dart` already defines the correct scope string -- reuse it for both Supabase OAuth and any direct PKCE flow.
2. Never request scopes incrementally (Spotify does not support incremental scope grants the way Google does).
3. Test the export flow immediately after auth in integration tests.

**Phase to address:** OAuth foundation phase.

**Confidence:** HIGH -- scope requirements are documented in the Spotify API reference for each endpoint.

---

### Pitfall 12: Songs Added via Search Bypass Freshness and Feedback History

**What goes wrong:**
User searches for a song, adds it to a playlist manually. The playlist generator's freshness tracking (`PlayHistory`) does not know about this manually-added song because freshness is tracked per playlist generation, not per song addition. The user adds the same song to every playlist manually, it never gets a freshness penalty, and it appears in every single playlist forever.

Similarly, manually-added songs may not flow through the feedback system correctly. If the user likes a song they found via search, the feedback is stored against the SongKey. But when the playlist generator runs, it only checks feedback for songs in its candidate pool (from GetSongBPM/curated). The manually-added song might not be in the candidate pool, so the feedback is orphaned.

**Prevention:**
1. Record manually-added songs in the play history alongside generated songs.
2. When a user adds a Spotify-searched song to their "liked" list, store the feedback against the normalized SongKey so it integrates with future playlist generations.
3. Consider adding a "pinned songs" concept: songs the user always wants in their playlists, which are explicitly included regardless of scoring but DO count toward freshness.

**Phase to address:** Search-to-playlist integration phase.

**Confidence:** MEDIUM -- depends on how manual song addition is implemented, which is not yet designed.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Spotify API abstraction layer | Building against API you cannot test (#1) | Interface + mock-first development; test against official response schemas |
| OAuth PKCE implementation | Redirect URI mismatch across platforms (#3); Token lifecycle bugs (#4); Dual auth confusion (#9) | Decide Supabase-proxied vs direct PKCE FIRST; persist code verifier securely; proactive token refresh |
| Token storage | Credentials in SharedPreferences (#2) | Use flutter_secure_storage; create TokenStorage abstraction |
| Song search UI | Rate limits from undebounced search (#5); Irrelevant short queries (#10) | 300ms debounce, 2-char minimum, cancel in-flight requests, cache results |
| Search data model | Spotify track model collision with BpmSong (#6); URI/ID/URL confusion (#7) | SpotifyTrack model with toBpmSong() conversion; store URI not ID/URL |
| Search scoring integration | No BPM data from search (#8) | Neutral BPM scores; lazy audio features fetch; curated cross-reference |
| Playlist export | Scope mismatch (#11); URI format errors (#7) | Request all scopes upfront; validate URI format before API call |
| Manual song addition | Bypasses freshness/feedback (#12) | Record manual additions in play history and feedback system |

## "Looks Done But Isn't" Checklist

- [ ] **OAuth redirect works on BOTH web and mobile.** Tested with `kIsWeb` true and false. Custom scheme registered in both `AndroidManifest.xml` and `Info.plist`.
- [ ] **Token refresh handles rotation.** Test: mock a refresh response that includes a new refresh_token. Verify the new token is saved and the old one is replaced.
- [ ] **Token refresh handles rejection.** Test: mock a refresh response that returns 400 (invalid grant). Verify the app prompts re-authentication instead of looping.
- [ ] **Search debounce works under rapid typing.** Test: programmatically type 10 characters at 50ms intervals. Verify only 1-2 API calls are made, not 10.
- [ ] **Stale search responses are ignored.** Test: fire two searches in quick succession. The second response should display, not the first (even if the first arrives later).
- [ ] **Song from search produces same SongKey as same song from curated dataset.** Test with 10 real songs that exist in both Spotify and the curated dataset.
- [ ] **Playlist export uses URIs not IDs or URLs.** Regex check on the `uris` array before calling the Add Tracks endpoint.
- [ ] **Token is NOT in SharedPreferences.** Audit all SharedPreferences keys and verify none contain OAuth tokens.
- [ ] **429 response is handled gracefully.** Test: mock a 429 response with `Retry-After: 30`. Verify the app shows a user-friendly message and retries after the specified delay.
- [ ] **Supabase auth still works.** Adding Spotify direct auth does not break the existing Supabase login flow. Both can coexist.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Can't test against real API (#1) | LOW | Mock layer is the recovery -- it IS the strategy. When Dashboard opens, swap mocks for real HTTP. |
| Token in SharedPreferences (#2) | MEDIUM | Migrate token from SharedPreferences to SecureStorage. Delete the SharedPreferences key. Force token refresh on next launch. |
| Redirect URI wrong (#3) | LOW | Fix redirect URI in code and Dashboard registration. No data migration needed. |
| Token lifecycle bugs (#4) | LOW | Fix the refresh logic. No data loss -- just re-authenticate once. |
| Rate limited (#5) | LOW | Add debounce and retry logic. No data impact. Rate limit window resets in 30 seconds. |
| Model collision (#6) | MEDIUM | Add missing fields to BpmSong or create SpotifyTrack model. May require cache invalidation if song data was cached with wrong field mappings. |
| URI/ID/URL confusion (#7) | LOW | Fix the identifier format in export code. No data migration (URIs are not persisted, they are fetched per-export). |
| No BPM from search (#8) | LOW | Add audio features fetch or neutral score. No data migration -- scores are computed at generation time. |
| Dual auth confusion (#9) | HIGH | Requires architectural decision and possible migration of auth system. Most expensive to recover from if built wrong initially. |

## Sources

- [Spotify: Authorization Code with PKCE Flow](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow)
- [Spotify: Refreshing Tokens](https://developer.spotify.com/documentation/web-api/tutorials/refreshing-tokens)
- [Spotify: Rate Limits](https://developer.spotify.com/documentation/web-api/concepts/rate-limits)
- [Spotify: Quota Modes](https://developer.spotify.com/documentation/web-api/concepts/quota-modes)
- [Spotify: URIs and IDs](https://developer.spotify.com/documentation/web-api/concepts/spotify-uris-ids)
- [Spotify: Search API Reference](https://developer.spotify.com/documentation/web-api/reference/search)
- [Spotify: Update on Developer Access (Feb 6, 2026)](https://developer.spotify.com/blog/2026-02-06-update-on-developer-access-and-platform-security)
- [Spotify: Increasing Security Requirements (Feb 2025)](https://developer.spotify.com/blog/2025-02-12-increasing-the-security-requirements-for-integrating-with-spotify)
- [Spotify: Extended Quota Mode Update (Apr 2025)](https://developer.spotify.com/blog/2025-04-15-updating-the-criteria-for-web-api-extended-access)
- [TechCrunch: Spotify Developer API Changes (Feb 2026)](https://techcrunch.com/2026/02/06/spotify-changes-developer-mode-api-to-require-premium-accounts-limits-test-users/)
- [Token Theft via SharedPreferences](https://medium.com/@tiger.chirag/part-4-token-theft-via-sharedpreferences-how-jwts-leak-from-flutter-apps-7e7dec6271d3)
- [Securely Storing JWTs in Flutter Web](https://carmine.dev/posts/flutterwebjwt/)
- [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)
- [Flutter Autocomplete widget](https://api.flutter.dev/flutter/material/Autocomplete-class.html)
- [Spotify Community: PKCE INVALID_CLIENT](https://community.spotify.com/t5/Spotify-for-Developers/Web-API-PKCE-Authorize-Not-Working-INVALID-CLIENT-Invalid/td-p/5478109)
- [Spotify Community: Add Tracks No URIs error](https://community.spotify.com/t5/Spotify-for-Developers/Add-Tracks-to-Playlist-Changed-No-URIs-Provided-error/td-p/5911269)
- Codebase analysis: `spotify_constants.dart`, `auth_repository.dart`, `auth_providers.dart`, `bpm_song.dart`, `curated_song.dart`, `song_quality_scorer.dart`, `playlist_generator.dart`, `song_link_builder.dart`, `song_feedback.dart`, `getsongbpm_client.dart`, `curated_song_repository.dart`

---
*Pitfalls research for: Song Search, Spotify OAuth PKCE & Playlist Export -- Running Playlist AI*
*Researched: 2026-02-08*
