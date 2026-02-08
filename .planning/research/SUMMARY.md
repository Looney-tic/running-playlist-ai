# Project Research Summary

**Project:** Running Playlist AI
**Milestone:** v1.4 - Smart Song Search & Spotify Foundation
**Domain:** Music app with song search, user curation, OAuth integration
**Researched:** 2026-02-08
**Confidence:** HIGH

## Executive Summary

This milestone adds three interconnected features to enable user-driven playlist curation: typeahead song search (local curated catalog), a "Songs I Run To" list (user-curated favorites), and Spotify API foundation (OAuth + playlist browsing). Research reveals a clear technical path: leverage Flutter's built-in `Autocomplete` widget, use the `spotify` package (v0.15.0) for API access, and treat Spotify integration as gracefully degrading enhancement rather than requirement. The existing architecture (Riverpod providers, SharedPreferences persistence, SongKey normalization) extends cleanly with minimal changes to scoring and taste learning systems.

The recommended approach prioritizes local functionality first (search curated songs, build "Songs I Run To" list, integrate with scoring) before adding Spotify layers. This delivers immediate user value while the Spotify Developer Dashboard remains closed to new registrations. Critical constraint: Spotify dashboard is blocking new app creation (since late December 2025) and Developer Mode now requires Premium accounts with stricter test user limits (effective February 2026). Build the Spotify integration with abstraction layers and mock implementations to avoid shipping untestable code.

Key risks center on OAuth complexity and token lifecycle management. Supabase OAuth (existing auth) does not persist Spotify provider tokens reliably, requiring a separate token capture/storage layer using `flutter_secure_storage`. Direct Spotify PKCE has platform-specific redirect URI requirements and code verifier persistence challenges. Token expiry (1 hour) demands proactive refresh with automatic retry logic. The mitigation strategy: design against Spotify's official API contract with mock-first development, separate token management into a dedicated service, and ensure every Spotify feature degrades gracefully when tokens are unavailable.

## Key Findings

### Recommended Stack

The milestone requires **one new dependency** (`spotify` package v0.15.0) plus activation of existing unused dependencies (`flutter_secure_storage` for token storage). Research confirms Flutter's built-in `Autocomplete` widget handles typeahead requirements without external packages, avoiding the stale `flutter_typeahead` package (last updated February 2024). The `spotify` package provides complete Spotify Web API coverage with PKCE auth, typed models, and automatic token refresh, using the exact same `http: ^1.6.0` version as the existing codebase (zero version conflicts).

**Core technologies:**
- **`spotify` package (v0.15.0)**: Spotify Web API client with PKCE OAuth, search, playlists — actively maintained (December 2025), pure Dart (no native deps), zero version conflicts with existing dependencies
- **`flutter_secure_storage` (^9.2.4)**: Secure token storage (already in pubspec, first actual usage) — required for OAuth tokens, uses Keychain (iOS) and EncryptedSharedPreferences (Android)
- **Flutter `Autocomplete` widget**: Built-in typeahead with async support and debouncing — no external dependency needed, avoids stale `flutter_typeahead` package
- **Manual Riverpod providers**: Continue existing pattern (code-gen broken with Dart 3.10) — new providers for `runningSongProvider`, `spotifyTokenManagerProvider`, `spotifyApiClientProvider`, `songSearchProvider`

**What NOT to add:**
- `flutter_typeahead` (24 months stale, redundant to built-in widget)
- `spotify_sdk` (native playback SDK, not Web API access)
- `oauth2` standalone (already wrapped by `spotify` package)
- `dio` (redundant to existing `http` package)

### Expected Features

Research reveals three feature tiers: table stakes (what users expect from song search and favorites), differentiators (unique to running context), and anti-features (explicitly defer or avoid). The "Songs I Run To" concept validates against MOOV Beat Runner's "My Songs" feature pattern, while Spotify playlist import follows conventions from SongShift/Soundiiz transfer tools.

**Must have (table stakes):**
- **Typeahead search with debounced input** (200-300ms, industry standard) — search 5,066 curated songs locally with instant results
- **Add to "Songs I Run To" action** (single tap with haptic feedback) — primary action from search results
- **"Songs I Run To" list view with removal** (swipe-to-dismiss or delete icon) — manage curated song collection
- **Songs appear in generated playlists** (stronger than "liked" boost: +8 to +10 vs. +5) — payoff that connects feature to core function
- **Empty states** (search and list) — guide users to feature discoverability

**Should have (competitive differentiators):**
- **"Songs I Run To" feeds taste learning** — proactive curation teaches system without requiring run feedback first
- **BPM compatibility indicator** on favorites list — shows which songs match current cadence target (green/amber/gray chips)
- **Spotify playlist browse and import** (foundation phase) — connect account, browse playlists, select songs to import into "Songs I Run To"
- **Dual-source search** (local first, Spotify fallback) — instant local results, optional Spotify expansion when connected

**Defer (v2+):**
- **Full Spotify playback integration** — requires Premium, adds SDK maintenance burden; existing URL links sufficient
- **Spotify playlist creation/export** — wait for Dashboard access reopening; clipboard copy is interim export
- **Spotify "Liked Songs" import** — thousands of tracks across all contexts; playlist-level import filters naturally
- **Song recommendations based on favorites** — existing quality scorer already handles via taste learning integration
- **Background token refresh** — over-engineering for foundation phase; on-demand refresh sufficient

### Architecture Approach

The architecture extends existing Riverpod/service/repository patterns with minimal coupling. Critical decision: create a **separate `RunningSong` model and provider** rather than extending `SongFeedback`, because user-curated favorites represent different intent (proactive "I want this" vs. reactive "I liked this"). Integration requires only single-line additions to existing systems: merge running song keys into liked sets for scoring, include running songs as synthetic feedback for taste learning.

**Major components:**
1. **`RunningSongNotifier`** (new StateNotifier) — CRUD for "Songs I Run To" list, follows established Completer pattern for async init, persists to SharedPreferences via static helper class
2. **`SongSearchService`** (abstract interface) — unified search across multiple sources (Phase 1: curated-only; future: composite with Spotify), enables source swapping without UI changes
3. **`SpotifyTokenManager`** (new service) — captures provider tokens from Supabase OAuth session, stores in secure storage with expiry tracking, provides `getValidToken()` with proactive refresh
4. **`SpotifyApiClient`** (new HTTP client) — wraps Spotify Web API endpoints (search, playlists, tracks), throws typed exceptions (`SpotifyAuthException`, `SpotifyApiException`) for graceful degradation
5. **`PlaylistGenerationNotifier`** (modified) — reads `runningSongProvider` and merges keys into liked set before calling `PlaylistGenerator.generate()` (one-line integration)
6. **`TasteSuggestionNotifier`** (modified) — includes running songs as synthetic liked feedback for pattern analysis (converts `RunningSong` to `SongFeedback` before analyzer)

**Key architectural patterns:**
- **SongKey.normalize for cross-source matching** — ensures Spotify-searched songs, curated songs, and feedback use same lookup key format (`artist_lower|title_lower`)
- **StateNotifier + Completer async init** — all persisted state uses `ensureLoaded()` pattern to prevent cold-start race conditions
- **Graceful degradation for Spotify** — all features work without Spotify; API client throws typed exceptions that UI catches for fallback behavior
- **Search interface abstraction** — `SongSearchService` interface allows Phase 1 (curated-only) and future composite implementations without UI changes

### Critical Pitfalls

Research identifies nine critical/moderate pitfalls, with the highest risk being **untestable Spotify integration** due to Dashboard restrictions. Prevention requires mock-first development, interface abstractions, and exhaustive validation against official API documentation.

1. **Spotify Developer Dashboard is blocked** — cannot create new apps since December 2025, Developer Mode requires Premium (February 2026). **Prevention:** Design against Spotify's OpenAPI spec, use `MockClient` for HTTP responses, build interface + mock layer first, implement real HTTP second when Dashboard access opens.

2. **OAuth token storage in SharedPreferences leaks credentials** — refresh tokens grant persistent Spotify account access. **Prevention:** Use `flutter_secure_storage` (already in pubspec) for ALL OAuth tokens; create `SpotifyTokenStorage` abstraction; never log tokens; accept web localStorage limitation (matches existing Supabase pattern).

3. **Spotify PKCE redirect URI mismatch** — web vs mobile require different URIs, `localhost` no longer accepted (must use `127.0.0.1`), code verifier lost during browser redirect. **Prevention:** Register two redirect URIs (web + mobile), persist code verifier in sessionStorage (web) or secure storage (mobile), test app-killed-during-OAuth scenario.

4. **Token lifecycle mismanagement** — tokens expire after 1 hour, refresh tokens may rotate. **Prevention:** Proactive token refresh (check expiry before every API call), reactive 401 handler with single retry, always save new refresh token from refresh response, wrap all API calls in authenticated client with automatic lifecycle.

5. **Typeahead search without debouncing hits rate limits** — every keystroke fires API request, 429 errors block all Spotify features. **Prevention:** 300ms debounce minimum, 2-character minimum query length, cancel in-flight requests, cache recent results, handle 429 with `Retry-After` respect.

## Implications for Roadmap

Based on research, suggested phase structure prioritizes local functionality (delivers immediate value) before Spotify layers (external dependency, Dashboard blocked). Architecture research confirms clean separation: "Songs I Run To" data layer is independent of Spotify, enabling parallel development once foundation is in place.

### Phase 1: "Songs I Run To" Core Data Layer
**Rationale:** Foundation for all other features. Both search and Spotify import need this destination. No external dependencies.
**Delivers:** `RunningSong` model, `RunningSongNotifier` with persistence, list screen with add/remove/empty states
**Addresses:** Table stakes feature (user-curated favorites management), architecture component (separate model, not SongFeedback extension)
**Avoids:** Pitfall #12 (songs bypass freshness/feedback) — integration with existing systems happens here

### Phase 2: Scoring and Taste Learning Integration
**Rationale:** Close the loop immediately after data layer. Users should see playlist improvement from adding favorites.
**Delivers:** Running songs merge into liked sets in `PlaylistGenerationNotifier`, synthetic feedback integration in `TasteSuggestionNotifier`, +8 to +10 scoring weight
**Addresses:** Must-have feature (songs appear in generated playlists), differentiator (feeds taste learning without run feedback)
**Avoids:** Feature feeling disconnected from core playlist generation

### Phase 3: Local Song Search with Typeahead
**Rationale:** Delivers full user value with zero external dependencies. Search 5,066 curated songs instantly.
**Delivers:** `SongSearchService` interface, `CuratedSongSearchService` implementation, search UI with `Autocomplete` widget, 300ms debounce, highlighted matches
**Uses:** Flutter built-in `Autocomplete` (no external package), existing `CuratedSongRepository`
**Addresses:** Table stakes (typeahead search), differentiator (instant local results)
**Avoids:** Pitfall #5 (rate limits) with debounce and query length limits, Pitfall #10 (irrelevant results) with 2-char minimum

### Phase 4: Spotify OAuth and Token Management Foundation
**Rationale:** Infrastructure for all Spotify features. Architecturally independent, can be built with mocks.
**Delivers:** `SpotifyTokenManager` with secure storage, token capture from Supabase OAuth, proactive refresh, `SpotifyApiClient` interface with mock implementation
**Uses:** `flutter_secure_storage` (first usage), `spotify` package models (for mock contracts)
**Addresses:** Architecture component (token lifecycle management)
**Avoids:** Pitfall #1 (untestable integration) with mock-first approach, Pitfall #2 (token leakage) with secure storage, Pitfall #3 (redirect mismatch) with platform-specific URIs, Pitfall #4 (token expiry) with proactive refresh

### Phase 5: Spotify Search Integration
**Rationale:** Extends Phase 3 search with Spotify data source. Gracefully degrades when Spotify unavailable.
**Delivers:** `SpotifySongSearchService`, `CompositeSongSearchService` (merges local + Spotify), dual-result UI with source badges, audio features integration for BPM
**Uses:** `spotify` package search endpoint, existing `SongKey.normalize` for deduplication
**Addresses:** Differentiator (expanded song catalog beyond curated dataset)
**Avoids:** Pitfall #6 (model collision) with `SpotifyTrack.toBpmSong()` conversion, Pitfall #7 (URI/ID/URL confusion) by storing URIs, Pitfall #8 (no BPM from search) with lazy audio features fetch

### Phase 6: Spotify Playlist Browse and Import
**Rationale:** Highest complexity, depends on all prior phases being stable. Lowest priority (Dashboard blocked).
**Delivers:** Playlist list screen (`GET /me/playlists`), playlist detail with track selection, bulk import to "Songs I Run To", cross-reference with curated catalog
**Uses:** `spotify` package playlist endpoints, existing curated lookup set
**Addresses:** Differentiator (import existing Spotify running playlists)
**Avoids:** Pitfall #11 (scope mismatch) by reusing `spotifyScopes` constant, Pitfall #9 (dual auth confusion) with unified connection state

### Phase Ordering Rationale

- **Data layer first** (Phase 1) because it is the destination for both search (Phase 3) and Spotify import (Phase 6). No external dependencies means lowest risk, highest immediate value.
- **Integration second** (Phase 2) because the payoff (better playlists) must be immediate. Users should see favorites boost scoring within one playlist generation.
- **Local search third** (Phase 3) because it delivers full user value without external API dependencies. Curated catalog is sufficient for MVP.
- **Spotify foundation fourth** (Phase 4) because it is pure infrastructure with no user-facing features. Can be built entirely with mocks while Dashboard is blocked.
- **Spotify search fifth** (Phase 5) because it extends local search (Phase 3) with minimal coupling. Graceful degradation means feature works even if Spotify auth fails.
- **Spotify playlists last** (Phase 6) because it is highest complexity (OAuth + multi-step flow + bulk operations) and lowest immediate value (Dashboard access uncertain).

**Dependency chain:**
```
Phase 1 (Running Songs Data) → Phase 2 (Scoring Integration)
                              → Phase 3 (Local Search)

Phase 4 (Spotify Auth) → Phase 5 (Spotify Search)
                       → Phase 6 (Spotify Playlists)

Phase 3 + Phase 5 = Composite Search Service
Phase 1 + Phase 6 = Spotify Import Destination
```

### Research Flags

**Phases needing deeper research during planning:**
- **Phase 4 (Spotify Auth):** OAuth PKCE redirect URI configuration per platform (AndroidManifest.xml, Info.plist, web callback page), code verifier persistence strategy (sessionStorage vs secure storage), Supabase provider token capture timing (onAuthStateChange event handling)
- **Phase 5 (Spotify Search):** Audio features API quota/availability in Developer Mode, batch endpoint usage vs. individual calls, cross-reference strategy for Spotify tracks vs. curated catalog (match quality, artist name normalization differences)
- **Phase 6 (Spotify Playlists):** February 2026 API changes impact on playlist response format (`tracks` → `items` rename, non-owned playlist metadata restrictions), pagination handling for large playlists (100+ tracks), bulk import UX for selection/progress/error reporting

**Phases with standard patterns (can skip research-phase):**
- **Phase 1:** StateNotifier + Completer pattern established, SharedPreferences persistence well-documented in existing codebase
- **Phase 2:** Scoring integration is one-line addition to existing `_readFeedbackSets()` method, synthetic feedback conversion follows existing model patterns
- **Phase 3:** Flutter Autocomplete widget well-documented with official examples, debouncing pattern standard across codebase

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | **HIGH** | Version compatibility verified against pubspec.yaml, `spotify` package API coverage confirmed in GitHub examples, zero version conflicts with existing dependencies |
| Features | **MEDIUM-HIGH** | Table stakes validated against industry UX patterns (Spotify, Apple Music), "Songs I Run To" concept validated by MOOV Beat Runner, Spotify import pattern validated by SongShift/Soundiiz |
| Architecture | **HIGH** | Based on exhaustive codebase analysis (60+ Dart files), existing patterns (StateNotifier + Completer, SongKey.normalize, static Preferences helpers) extend cleanly, integration points identified with single-line changes |
| Pitfalls | **HIGH** | Grounded in official Spotify documentation, verified Spotify Developer Dashboard status (February 2026 blog post), token storage security patterns documented in Flutter ecosystem |

**Overall confidence:** **HIGH**

Research benefits from:
- Direct codebase access (all 60+ Dart files analyzed for patterns)
- Official Spotify API documentation (authorization, search, playlists, token lifecycle)
- Verified external constraint (Dashboard blocked, Developer Mode restrictions)
- Existing architectural patterns (Riverpod manual providers, SharedPreferences persistence, SongKey normalization)
- Version compatibility verification (pubspec.yaml, pub.dev package pages)

### Gaps to Address

Research identified areas requiring validation during planning or execution:

- **Supabase provider token behavior:** Documentation states `session.providerToken` contains Spotify access token, but persistence across session refresh is unclear. Needs empirical testing with actual Supabase instance to confirm whether token capture/storage layer is required or if Supabase handles it. (Mitigation: design token manager assuming Supabase does NOT persist, so if it does, layer becomes pass-through.)

- **Spotify audio features API availability:** Developer Mode restrictions (February 2026) may limit access to `/audio-features` endpoint. Search response does not include BPM/danceability. Research assumes endpoint remains available but needs verification when Dashboard access opens. (Mitigation: design scoring to handle missing BPM with neutral scores; cross-reference with curated catalog where BPM is known.)

- **Flutter Autocomplete widget async debounce implementation:** Official docs show `optionsBuilder` returns `FutureOr`, but debounce implementation details (Timer-based vs. Riverpod pattern) not explicitly shown in examples. (Mitigation: Timer-based debounce is standard Dart pattern, ~10 lines of code; proven approach in similar Flutter search implementations.)

- **Spotify URI format validation:** API docs specify `spotify:track:id` format for playlist operations, but edge cases (podcast episodes, local files, unavailable tracks) may have different URI formats. (Mitigation: regex validation `^spotify:track:[a-zA-Z0-9]+$` before API calls; log warnings for unexpected formats.)

- **Platform-specific OAuth redirect handling:** Web callback page implementation and deep link configuration (iOS Info.plist, Android intent filters) requires platform-specific testing. Research documents requirements but cannot verify end-to-end flow without Dashboard access. (Mitigation: build with mock OAuth flow first, defer platform-specific redirect testing to Phase 4 verification.)

## Sources

### Primary (HIGH confidence)
- **Spotify Web API Reference:** Search endpoint, authorization (PKCE flow), token refresh, playlists, scopes, rate limits — official documentation
- **Spotify Developer Blog:** OAuth migration (November 2025), security requirements (February 2025), developer access update (February 2026), extended quota mode criteria (April 2025) — policy changes verified
- **`spotify` package (pub.dev):** v0.15.0 dependencies, PKCE support, platform compatibility — version/compatibility data
- **Flutter API documentation:** Autocomplete widget with async examples, Material Design 3 widgets — built-in capabilities
- **Codebase analysis:** 60+ Dart files covering existing patterns (StateNotifier, SongKey, scoring, feedback, taste learning, persistence) — direct source code inspection
- **Supabase documentation:** OAuth with Spotify, provider tokens, auth state changes — integration patterns

### Secondary (MEDIUM confidence)
- **UX research:** Smart Interface Design Patterns (autocomplete), Algolia (debouncing), Baymard Institute (mobile search) — industry consensus on typeahead patterns
- **Music app UX:** Spotify/Apple Music search patterns, Liked Songs management, favorites integration — competitor analysis
- **Playlist transfer tools:** Soundiiz, SongShift, FreeYourMusic — playlist-level import patterns
- **Running music apps:** MOOV Beat Runner, RockMyRun, PaceDJ — "Songs I Run To" concept validation
- **Spotify community forums:** Dashboard registration blocked, PKCE errors, playlist API issues — developer experience reports

### Tertiary (LOW confidence)
- **TechCrunch reporting:** Spotify Developer Mode restrictions (February 2026) — secondary source for policy changes (primary is Spotify blog)
- **Medium articles:** Flutter token security, debouncing patterns — community best practices (validated against official docs where possible)

---
*Research completed: 2026-02-08*
*Ready for roadmap: yes*
