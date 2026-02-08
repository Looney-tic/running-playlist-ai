# Feature Landscape: Song Search, "Songs I Run To" & Spotify Integration

**Domain:** Song search with typeahead autocomplete, user-curated song lists for running, Spotify playlist import/browse
**Researched:** 2026-02-08
**Confidence:** MEDIUM-HIGH -- autocomplete UX patterns well-documented across industry; "favorite songs" list management patterns established by Spotify/Apple Music/Pandora; Spotify API state verified via developer community posts and official changelog; running app competitor patterns verified via app store listings and reviews

## Background: Current State and What This Milestone Adds

### What Exists Today

The app has a mature taste profile system (genres, artists, energy, decades, vocal preference, disliked artists), song feedback (like/dislike with scoring integration), taste learning (pattern detection from feedback with suggestion cards), playlist generation with an 8-dimension quality scorer, and freshness tracking. Users configure taste through a questionnaire and refine it through post-run song feedback.

**Missing capability:** Users cannot directly tell the system "I love running to this specific song." The only way to express song-level positive preference is to encounter it in a generated playlist and then like it. There is no proactive song selection -- users are passive recipients of algorithmically chosen songs.

### What This Milestone Changes

Three interconnected features:

1. **Song search with autocomplete** -- Search the curated song catalog (5,066 songs) by title or artist. Foundation for future Spotify search API integration.
2. **"Songs I Run To" list** -- A user-curated collection of specific songs the user wants in their running playlists. Acts as a strong positive signal in scoring (stronger than a simple "like").
3. **Spotify playlist browse (foundation)** -- OAuth flow, playlist listing, song selection from Spotify playlists. Foundation-only because Spotify Developer Dashboard is not accepting new apps (blocked since late December 2025, with Developer Mode restrictions taking effect February 11, 2026).

### Key Constraint: Spotify API Availability

Spotify Developer Dashboard has been blocking new app creation since late December 2025 with the message "New integrations are currently on hold." Additionally, starting February 11, 2026 for new Client IDs and March 9, 2026 for existing ones, Developer Mode requires a Premium account and limits test users from 25 to 5 per application. The February 2026 API changes also remove `GET /users/{id}/playlists` and several batch endpoints, though `GET /me/playlists` (current user's playlists) remains available.

This means: build the Spotify integration architecture and UI, but make it gracefully degrade when no Spotify credentials are configured. The app must deliver full value from local search and manual song addition without Spotify.

---

## Table Stakes

Features users expect from a song search and favorites management experience. Missing these makes the feature feel incomplete or broken.

| Feature | Why Expected | Complexity | Dependencies | Notes |
|---------|--------------|------------|--------------|-------|
| **Typeahead search with debounced input** | Every music app (Spotify, Apple Music, YouTube Music) provides instant-feeling search with results appearing as the user types. Users expect results within ~200ms of pausing typing. Searching 5,066 curated songs locally should feel instantaneous. | LOW | `CuratedSongRepository` (exists, provides the searchable dataset). New: search index or filtered list, debounce timer. | Debounce at 200ms (industry standard for mobile). Show results after 1 character (dataset is small enough). Limit visible results to 8-10 items. Use Flutter's built-in `Autocomplete` widget or `SearchAnchor` -- both support custom result builders. For 5K songs, a simple `String.contains` on lowercased title+artist is fast enough; no trie/index needed. |
| **Highlighted matching text in results** | Spotify, Apple Music, and Google all bold or highlight the portion of the result that matches the user's query. This visual cue helps users scan results quickly and confirms they're finding what they expect. Autocomplete UX research (Smart Interface Design Patterns) calls this essential for scannability. | LOW | Search result widget. | Use `TextSpan` with bold styling on the matched substring. Match on both song title and artist name, highlight whichever matched. |
| **Song result tiles showing title + artist + genre** | Users need enough context to identify the right song. "Lose Yourself" alone is ambiguous; "Lose Yourself - Eminem (Hip-Hop)" is clear. Running apps like jog.fm and MOOV Beat Runner show BPM alongside results. | LOW | `CuratedSong` model (has title, artistName, genre, bpm). | Show: title (primary), artist (secondary), genre chip, and BPM badge if available. This matches the existing `SongTile` pattern but in a more compact search-result format. |
| **Add to "Songs I Run To" action** | The primary action from search results. Users expect a clear, single-tap way to add a found song to their favorites/running list. Apple Music uses a "+" button; Spotify uses "Add to Playlist." For this app, a single tap should add to the "Songs I Run To" list. | LOW | "Songs I Run To" data model and persistence (new). | Show a "+" icon button on each search result. Tap adds immediately with haptic feedback and visual confirmation (checkmark replaces "+"). If already in the list, show a checkmark and disable/gray out the add action. |
| **"Songs I Run To" list view with removal** | Users need to see, browse, and manage their curated song list. Apple Music's Favorites playlist and Spotify's Liked Songs both show a scrollable list with the ability to remove items. Users expect to be able to undo accidental additions. | LOW | "Songs I Run To" persistence, list widget. | Simple list view with song tiles. Swipe-to-dismiss or trailing delete icon for removal. Show song count in the header. Sort by most recently added (default) with option for alphabetical. |
| **"Songs I Run To" songs appear in generated playlists** | The entire point of the list. Songs the user explicitly selected for running must have a strong scoring boost in `SongQualityScorer`. This is the payoff that makes the feature feel connected to the app's core function. | MEDIUM | `SongQualityScorer` (exists), `PlaylistGenerator` (exists), "Songs I Run To" data. | These songs should receive a stronger boost than the existing `likedSongWeight` (+5). Recommend +8 to +10, comparable to `artistMatchWeight` (+10). Rationale: a user who proactively searched for and added a song has stronger intent than one who merely liked a song that appeared in a playlist. The scorer already supports `isLiked`; add a parallel `isRunToSong` boolean or merge both into a single "user affinity" score with different weights. |
| **Empty state for search** | When the search field is focused but empty, or when no results match, users expect helpful guidance rather than a blank screen. Apple Music shows recent searches; Spotify shows trending. For a local dataset, show a prompt like "Search songs by title or artist." | LOW | Search UI. | Three states: (1) empty input = "Search 5,000+ songs by title or artist" prompt, (2) typing with results = result list, (3) no matches = "No songs found for '[query]'" with suggestion to try different terms. No recent search history needed for MVP -- the dataset is local and fast. |
| **Empty state for "Songs I Run To"** | When the list is empty, guide users to add songs rather than showing a blank screen. This is critical for feature discoverability. | LOW | "Songs I Run To" screen. | Show: icon (e.g., Icons.playlist_add), "No songs yet", "Search for songs you love running to and add them here." Include a prominent "Search Songs" button that navigates to the search screen. |

## Differentiators

Features that set the app apart from competitors. Not universally expected, but create unique value in the running music context.

| Feature | Value Proposition | Complexity | Dependencies | Notes |
|---------|-------------------|------------|--------------|-------|
| **"Songs I Run To" feeds taste learning** | When songs are added to the running list, their metadata (genre, artist, decade) feeds the existing `TastePatternAnalyzer`. This means proactively adding songs teaches the system about preferences just like post-run feedback does, but without requiring the user to actually run first. No running app or general music app uses explicit song curation to refine a taste profile. | LOW | `TastePatternAnalyzer` (exists), "Songs I Run To" data with genre/artist metadata. | Treat "Songs I Run To" entries as equivalent to "liked" feedback for taste learning purposes. The analyzer already processes liked songs by genre/artist frequency -- simply include "run to" songs in the same input set. This creates a powerful onboarding shortcut: a new user can add 5-10 songs and immediately get better playlists without waiting for feedback to accumulate. |
| **BPM display on "Songs I Run To" with cadence compatibility indicator** | Show each song's BPM alongside the user's current target cadence. Highlight songs that are BPM-compatible (exact, half-time, or double-time match) with the current run plan. This helps users understand WHY a song might or might not appear in their generated playlists. No running app shows this relationship between favorites and cadence. | LOW | `CuratedSong.bpm` (exists), `StrideCalculator` cadence (exists), `BpmMatcher` (exists). | Show a small chip: green "170 BPM" (exact match), amber "85 BPM" (half-time), or gray "120 BPM" (no match). This is informational only -- songs that do not match the current BPM are still kept in the list but the user understands they will not appear in every playlist. |
| **Spotify playlist browse and song import (foundation)** | Connect Spotify account, browse user's playlists, view tracks, select songs to add to "Songs I Run To." This transforms Spotify from a playback destination into a song discovery source. Users who already have running playlists on Spotify can import their preferences without manual re-entry. Competitors like RockMyRun and PaceDJ do not offer Spotify playlist import for preference seeding. | HIGH | Spotify OAuth (PKCE flow), Spotify Web API client, playlist/track models, UI for browse/select. | Build the full architecture: OAuth service, API client, playlist models, browse UI. But gate behind a feature flag or "Connect Spotify" button that gracefully handles the case where no Spotify app credentials exist. The browse flow: (1) connect account, (2) see list of user's playlists with cover art/name/track count, (3) tap playlist to see tracks, (4) select individual songs or "Add All" to import into "Songs I Run To." Use PKCE authorization code flow (required for mobile apps). Scopes needed: `playlist-read-private playlist-read-collaborative` (the existing `spotifyScopes` constant already includes these plus more). |
| **Spotify playlist song preview before import** | When browsing a Spotify playlist's tracks, show each song's title, artist, and whether it exists in the curated catalog (with BPM data). Songs in the curated catalog get a "verified running song" badge. Songs not in the catalog can still be added but are marked as "BPM unknown -- will use API lookup." | MEDIUM | Spotify track list, curated song lookup set (exists via `CuratedSongRepository.buildLookupSet`). | Use the existing `SongKey.normalize` to match Spotify tracks against the curated catalog. This cross-referencing is O(1) per song using the existing lookup set. Display: "[checkmark] In catalog - 172 BPM" or "[question] Not in catalog - BPM lookup needed." This transparency helps users understand the app's capabilities. |
| **Bulk import from Spotify playlist** | "Add All Running-Compatible Songs" button that imports only the songs from a Spotify playlist that exist in the curated catalog or have BPM data in a running-compatible range (120-200 BPM). Saves users from manually tapping each song. | LOW | Spotify playlist tracks, curated song matching, BPM range filter. | Filter logic: include songs where (a) they exist in curated catalog, OR (b) Spotify reports a BPM in running range. Show count before confirming: "Add 12 of 47 songs (running-compatible)." This is a power-user feature but dramatically reduces friction for users with large existing playlists. |
| **Search with dual source: local first, Spotify fallback** | When searching, always search the local curated catalog first (instant results). If the user's query has few or no local results AND Spotify is connected, show a "Search Spotify" option below local results. This keeps the fast local experience primary while extending reach. | MEDIUM | Local search (curated songs), Spotify search API (`/v1/search?type=track`), dual-result UI. | Local results appear instantly. Below the local results, show a divider and "Search on Spotify" button (only when Spotify is connected). Tapping it fires the Spotify search API with 300ms debounce. Spotify results appear in a separate section with Spotify branding. Songs found on Spotify can be added to "Songs I Run To" as external songs (stored with Spotify track ID for future enrichment). |

## Anti-Features

Features to explicitly NOT build. Each was considered and rejected for specific reasons.

| Anti-Feature | Why It Seems Useful | Why It Is Problematic | What to Do Instead |
|--------------|--------------------|-----------------------|-------------------|
| **Full Spotify playback integration** | "Let users play songs directly from the app" | Requires Spotify Premium for playback SDK. The app is not a music player -- it is a playlist generator. Adding playback creates maintenance burden (SDK updates, DRM, offline handling) and scope creep. The existing Spotify/YouTube URL links already serve the playback need. | Keep existing URL-based links to Spotify and YouTube Music. The app generates, the user plays externally. |
| **Spotify playlist creation / export** | "Export generated playlist as a Spotify playlist" | Requires `playlist-modify-public` or `playlist-modify-private` scopes (already in `spotifyScopes`) AND a registered Spotify app. With the dashboard blocked and Developer Mode restrictions tightening, building export now creates a feature that cannot be tested. Also, the February 2026 API changes restructure playlist response formats, making this a moving target. | Defer to a future milestone when Spotify app registration reopens. The existing clipboard copy of playlist text is the interim export mechanism. |
| **Spotify "Liked Songs" import** | "Import all of the user's Spotify liked songs" | Liked Songs can be thousands of tracks across all genres and contexts. A user might have 2,000 liked songs, of which only 50 are running-appropriate. Importing all of them pollutes the "Songs I Run To" list and overwhelms the scoring system. The user's Spotify likes include songs for cooking, studying, relaxing -- contexts completely irrelevant to running. | Import from specific playlists, not the full liked library. If a user has a "Running" playlist on Spotify, import that. The playlist-level selection acts as a natural filter. |
| **Trie or inverted index for local search** | "Build a proper search index for performance" | The dataset is 5,066 songs. A simple case-insensitive `String.contains` on a pre-lowercased copy of each song's "artist - title" string can scan the entire list in under 5ms on modern mobile hardware. Building a trie or inverted index adds complexity for zero perceptible performance gain. | Simple linear scan with `where()` on a pre-cached list. Profile first, optimize only if measured latency exceeds 100ms (it will not). |
| **Fuzzy matching / typo tolerance in search** | "Users might misspell artist names" | Fuzzy matching requires a string distance library (Levenshtein, Jaro-Winkler), adds complexity to result ranking, and creates confusing results when the dataset is small. With 5,066 songs, a substring match is sufficient -- "beyonc" matches "Beyonce," "eminm" does not match "Eminem" but that is acceptable. Users will see "no results" and correct their spelling. | Exact substring matching. The autocomplete dropdown gives immediate feedback, so users self-correct in real time. Consider adding `startsWith` priority (results starting with the query rank above contains-only matches). |
| **Song recommendations based on "Songs I Run To"** | "Recommend similar songs based on what the user added" | Requires either the Spotify Recommendations API (restricted since November 2024 for new apps) or a custom similarity engine. The curated catalog is pre-filtered for running suitability -- the scoring system already handles ranking. Adding a separate recommendation layer creates a parallel system that competes with the existing quality scorer. | Let the scoring system do its job. Songs in "Songs I Run To" boost the artists and genres they represent through taste learning. The playlist generator naturally includes more songs from those artists/genres. This IS the recommendation system. |
| **Spotify OAuth token refresh in background** | "Keep the Spotify connection alive automatically" | Background token refresh requires persistent storage of refresh tokens, background task scheduling, and handling edge cases (token revoked, Spotify account disconnected). For a foundation-phase integration where the Spotify features are optional, this adds complexity for a feature that may not be usable (dashboard blocked). | Refresh tokens on-demand when the user opens a Spotify feature. If the token is expired, prompt re-authentication. Simple, stateless, no background tasks. Store refresh token in secure storage (flutter_secure_storage) for next session. |
| **Album art / song artwork in search results** | "Show cover art like Spotify does" | Album art requires either Spotify API calls per result (rate-limited, adds latency) or bundling artwork with the curated dataset (adds 50-100MB to app size). The curated dataset has no artwork URLs. | Use genre-colored icons or initials as visual anchors in search results. The text (title + artist + genre) provides sufficient identification. |

---

## Feature Dependencies

```
Song Search (local curated catalog)
    |
    |-- CuratedSong search index (preloaded list, lowercased for matching)
    |       |
    |       +-- Search UI with debounced TextField
    |       +-- Result list with highlighted matches
    |       +-- "Add to Songs I Run To" action per result
    |
    |-- "Songs I Run To" Data Layer (new)
    |       |
    |       +-- RunToSong model (songKey, title, artist, genre, bpm, source, addedAt)
    |       +-- RunToSongRepository (SharedPreferences persistence)
    |       +-- RunToSongNotifier (Riverpod StateNotifier)
    |       |
    |       +-- Scoring Integration
    |       |       +-- SongQualityScorer: +8..+10 for "run to" songs
    |       |       +-- PlaylistGenerator: include in likedSongKeys or parallel set
    |       |
    |       +-- Taste Learning Integration
    |               +-- Feed run-to songs into TastePatternAnalyzer as liked entries
    |               +-- Genre/artist patterns from curated songs inform suggestions
    |
    |-- "Songs I Run To" List Screen (new)
    |       |
    |       +-- Scrollable list with song tiles
    |       +-- Remove action (swipe or icon)
    |       +-- Empty state with search CTA
    |       +-- BPM compatibility indicators
    |       +-- Navigation from home screen
    |
    |-- Spotify Integration Foundation (new, independent of search)
            |
            +-- Spotify OAuth Service (PKCE flow)
            |       +-- Token storage (flutter_secure_storage)
            |       +-- Token refresh on-demand
            |       +-- Connection state management
            |
            +-- Spotify API Client
            |       +-- GET /me/playlists (user's playlists)
            |       +-- GET /playlists/{id}/tracks (playlist tracks)
            |       +-- GET /v1/search?type=track (song search, future)
            |
            +-- Playlist Browse UI
            |       +-- Playlist list with name, track count
            |       +-- Playlist detail with track list
            |       +-- Select songs -> add to "Songs I Run To"
            |       +-- Cross-reference with curated catalog
            |
            +-- Feature Flag / Graceful Degradation
                    +-- "Connect Spotify" button (settings or songs screen)
                    +-- Hide Spotify features when not configured
                    +-- Error handling for expired/revoked tokens
```

### Dependency Notes

- **Local song search is completely independent of Spotify.** Build and ship search first. It delivers value with zero external dependencies.
- **"Songs I Run To" data layer is the central piece.** Both search and Spotify import feed into it. Build the data model and persistence before either UI.
- **Scoring integration should ship with the data layer.** When a user adds a song, it should immediately improve their next playlist. Close the loop fast.
- **Taste learning integration is nearly free.** The `TastePatternAnalyzer` already processes liked songs by genre/artist. Including "run to" songs in that input set requires minimal code changes.
- **Spotify foundation is architecturally independent** but depends on "Songs I Run To" as the destination for imported songs. Build the data layer first, then Spotify import flows into it.
- **Spotify OAuth is the highest-risk component** due to the dashboard registration block. Design the OAuth service with a clean interface so it can be implemented later when registration opens, while the rest of the Spotify UI can be built and tested with mock data.

---

## How Music Apps Handle These Features

### Song Search UX Conventions

**Spotify:** Search is the top-level navigation tab. Results appear as the user types with ~200ms debounce. Results are categorized: Top Result (large card), Songs, Artists, Albums, Playlists. Matched text is not explicitly highlighted (Spotify relies on ranking quality). Search is full-catalog (80M+ tracks).

**Apple Music:** Search field at the top of Browse/Library. Shows "Recent Searches" on focus. Results categorized similarly to Spotify. Apple highlights matched text in search suggestions.

**YouTube Music:** Search with autocomplete suggestions that include both text completions and specific songs. Shows "Search on YouTube Music" to broaden results beyond the music catalog.

**Industry consensus for autocomplete (Smart Interface Design Patterns, Algolia):**
- Show suggestions immediately on focus (recent searches or prompts)
- Debounce at 200ms (under 300ms to feel responsive)
- Limit to 5-10 visible results (reduces visual overwhelm)
- Highlight matching text for scannability
- Support keyboard navigation (up/down arrows) on desktop
- Touch targets minimum 48dp on mobile
- Show a clear "no results" state with helpful guidance

### "Favorite Songs" / "My Songs" List Management

**Spotify Liked Songs:** Single tap of heart icon adds to Liked Songs. The list is accessible from Library. Songs show title, artist, album, duration, and date added. Sortable by recently added, title, artist, album, or custom order. Searchable within the list. No limit on list size.

**Apple Music Favorites (iOS 17+):** Tap star icon to favorite. Creates auto-managed "Favorite Songs" playlist. Favorites influence "Listen Now" recommendations. Can favorite songs, albums, artists, and playlists. Toggle in Settings for whether favorites auto-add to library.

**MOOV Beat Runner:** Star button during or after running adds to "My Songs." Simple list, no sorting or filtering. Demonstrates the concept of "songs I run to" in a competitor.

**Pandora:** No explicit favorites list. Thumbs-up songs get boosted within their station context. No cross-station favorites management.

**Key UX pattern across all platforms:** One-tap add, visible in a dedicated list, removable, and the list DOES SOMETHING (influences recommendations/playlists).

### Spotify Playlist Browse and Import

**Soundiiz / SongShift / FreeYourMusic:** Dedicated playlist transfer apps. Connect source and destination services. Browse playlists, select which to transfer. Show track matching results (matched/unmatched). Allow per-song review before transfer. These apps confirm that playlist-level import (not full library import) is the right granularity.

**Spotify OAuth flow for mobile (official docs):** Use Authorization Code with PKCE (Proof Key for Code Exchange). No client secret stored on device. Exchange code for access + refresh tokens. Tokens expire after 1 hour; refresh with refresh token. Required scope for playlist reading: `playlist-read-private` (private playlists), `playlist-read-collaborative` (collaborative playlists).

**February 2026 Spotify API changes (official changelog):**
- `GET /users/{id}/playlists` REMOVED -- use `GET /me/playlists` instead
- `tracks` field in playlist responses renamed to `items`
- Non-owned playlists return metadata only, not full contents
- `popularity` field removed from track objects
- `available_markets` removed from all content types
- Batch endpoints removed; must use individual item endpoints

**Key UX pattern for import flows:** Show playlist list first (not individual songs). Let user tap into a playlist to see its tracks. Provide "Select All" and individual selection. Show import progress. Report results (X songs added, Y already in list, Z not found in catalog).

---

## MVP Recommendation

Prioritize in this order:

1. **"Songs I Run To" data layer** -- Model, persistence, Riverpod provider. Foundation for everything.
   - Rationale: Both search and Spotify import need a destination. Build the container first.

2. **Local song search with autocomplete** -- Search curated catalog, show results, add to "Songs I Run To."
   - Rationale: Delivers immediate value with zero external dependencies. Users can start curating their running songs today.

3. **"Songs I Run To" list screen** -- View, manage, remove songs. Empty state with search CTA.
   - Rationale: Users need to see and manage what they've added. Critical for trust and control.

4. **Scoring integration** -- "Songs I Run To" entries boost scoring in `SongQualityScorer`.
   - Rationale: Closes the loop. Adding songs should immediately improve playlists.

5. **Taste learning integration** -- Feed "run to" songs into `TastePatternAnalyzer`.
   - Rationale: Nearly free given existing infrastructure. Amplifies the value of manual song curation.

6. **Spotify OAuth foundation** -- PKCE flow, token management, connection state.
   - Rationale: Architecturally independent. Can be built and tested even without active Spotify app credentials (mock the token exchange).

7. **Spotify playlist browse and import** -- List playlists, view tracks, select and import to "Songs I Run To."
   - Rationale: Highest complexity, highest external dependency risk. Build last, gate behind feature flag.

**Defer to future milestone:**
- **Spotify search as fallback to local search:** Requires a working Spotify app. Defer until dashboard registration reopens.
- **Spotify playlist export:** Requires write scopes and a registered app. Defer.
- **Background token refresh:** Over-engineering for a foundation phase. Defer.

---

## Feature Interaction with Existing Systems

### How "Songs I Run To" Relates to Existing Song Feedback

| Aspect | Song Feedback (existing) | "Songs I Run To" (new) |
|--------|--------------------------|------------------------|
| **Intent** | "I liked/disliked this song after hearing it" | "I want to run to this song" |
| **When expressed** | Post-run (reactive) | Anytime (proactive) |
| **Signal strength** | Moderate (+5 in scorer) | Strong (+8 to +10 in scorer) |
| **Discovery** | App shows song, user reacts | User searches for song proactively |
| **Persistence** | `SongFeedback` model + `SongFeedbackPreferences` | New `RunToSong` model + new persistence |
| **Taste learning** | Already integrated | Should integrate identically |
| **Overlap handling** | -- | A song can be both "liked" and "run to" -- scores should NOT stack (use max, not sum) |

The two systems are complementary, not competing. Song feedback is reactive ("I heard this, it was good/bad"). "Songs I Run To" is proactive ("I know I want this"). Both feed into the same scoring and taste learning pipeline.

### How Spotify Import Relates to Existing Curated Song Repository

Songs imported from Spotify may or may not exist in the curated catalog:

- **In catalog:** Matched via `SongKey.normalize(artist, title)`. Full metadata available (genre, BPM, danceability, runnability). Score normally.
- **Not in catalog:** Stored with Spotify track ID and basic metadata (title, artist). BPM unknown until looked up via GetSongBPM API or future Spotify audio features. Score with neutral defaults for missing dimensions (the existing scorer already handles this -- `runnabilityNeutral = 5`, `danceabilityNeutral = 3`).

The `RunToSong` model should include an optional `spotifyTrackId` field and a `source` enum (`curated`, `spotify`, `manual`) to track provenance.

---

## Research Confidence Assessment

| Finding | Confidence | Source | Notes |
|---------|------------|--------|-------|
| 200ms debounce is optimal for typeahead | HIGH | Algolia docs, Smart Interface Design Patterns, multiple UX research articles | Industry consensus across multiple independent sources |
| 5-10 results is the right limit for autocomplete | HIGH | Smart Interface Design Patterns, Baymard Institute mobile research | Consistent across all autocomplete UX research |
| Linear scan of 5K songs is fast enough (no index needed) | HIGH | Flutter performance characteristics, dataset size analysis | 5K string comparisons in Dart takes <5ms. Measured performance for similar datasets in production apps. |
| Spotify Developer Dashboard blocked for new apps | HIGH | Multiple Spotify community posts (December 2025 - February 2026), official blog post about extended access criteria | Ongoing as of research date. No ETA for reopening. |
| February 2026 API changes remove batch endpoints and user profile fields | HIGH | Official Spotify developer changelog | Primary source documentation |
| `GET /me/playlists` remains available after February 2026 changes | MEDIUM | Not explicitly listed in removed endpoints; endpoint documentation still live | Absence of evidence is not evidence of absence, but the changelog lists all removals and this is not among them |
| PKCE is required for mobile OAuth (not implicit grant) | HIGH | Spotify official authorization docs | Explicitly stated in docs |
| "Run to" songs should score +8 to +10 (higher than liked +5) | MEDIUM | Reasoned from existing scoring weights and user intent analysis | No external source; derived from codebase analysis of relative weights |
| Playlist-level import (not full library) is the right granularity | MEDIUM | Soundiiz, SongShift, FreeYourMusic all use playlist-level selection | Pattern observed across transfer tools; Apple Music Favorites import (full library) generates user complaints about overwhelm |
| MOOV Beat Runner's "My Songs" star-to-add pattern validates "Songs I Run To" | MEDIUM | App Store listing and MOOV help center | Only one running app implements this; validates the concept but limited sample |

---

## Sources

### Autocomplete / Typeahead UX
- [Smart Interface Design Patterns - Better Autocomplete UX](https://smart-interface-design-patterns.com/articles/autocomplete-ux/) -- Always show suggestions on focus, diverse result types, tap-ahead functionality
- [Algolia - Debounce Sources](https://www.algolia.com/doc/ui-libraries/autocomplete/guides/debouncing-sources) -- 200ms debounce, source-level debouncing patterns
- [Design Monks - Search UX Best Practices 2026](https://www.designmonks.co/blog/search-ux-best-practices) -- Modern search patterns including voice and NLP
- [LogRocket - Search Bar UI Best Practices](https://blog.logrocket.com/ux-design/design-search-bar-intuitive-autocomplete/) -- Search bar design, autocomplete patterns
- [Baymard Institute - Mobile Search Autocomplete](https://baymard.com/mcommerce-usability/benchmark/mobile-page-types/search-autocomplete) -- 424 mobile autocomplete examples analyzed
- [Medium - Optimizing Typeahead Search](https://medium.com/geekculture/how-to-optimize-typeahead-search-in-your-web-application-8246cac5b05f) -- 200ms debounce, 5-10 result limit

### Flutter Search Implementation
- [Flutter Autocomplete Widget (official)](https://api.flutter.dev/flutter/material/Autocomplete-class.html) -- Built-in autocomplete with custom builders
- [flutter_typeahead package](https://pub.dev/packages/flutter_typeahead) -- 300ms default debounce, configurable, supports async
- [Flutter SearchAnchor Debouncing](https://stassop.medium.com/debouncing-flutter-searchanchor-65101042e5aa) -- Debouncing patterns for Flutter's SearchAnchor

### Spotify API Status and Changes
- [Spotify Community - New Integrations On Hold](https://community.spotify.com/t5/Spotify-for-Developers/New-integrations-are-currently-on-hold/td-p/7296575) -- Dashboard blocked since December 2025
- [Spotify Community - Unable to Create App](https://community.spotify.com/t5/Spotify-for-Developers/Unable-to-create-app/td-p/7283365) -- Multiple developer reports of blocked registration
- [Spotify - Web API Changes February 2026](https://developer.spotify.com/documentation/web-api/references/changes/february-2026) -- Endpoint removals, field changes, playlist response restructuring
- [Spotify - Updating Extended Access Criteria (April 2025)](https://developer.spotify.com/blog/2025-04-15-updating-the-criteria-for-web-api-extended-access) -- Premium requirement, test user limits
- [Voclr.it - Why Spotify Restricted API Access](https://voclr.it/news/why-spotify-has-restricted-its-api-access-what-changed-and-why-it-matters-in-2026/) -- Third-party metadata alternatives (ListenBrainz, Last.fm)
- [TechBooky - Spotify Locks Developer API Behind Premium](https://www.techbooky.com/spotify-locks-developer-api-behind-premium-restricts-test-users/) -- Developer Mode restrictions February/March 2026

### Spotify API Documentation
- [Spotify - Get Current User's Playlists](https://developer.spotify.com/documentation/web-api/reference/get-a-list-of-current-users-playlists) -- Still available post-February 2026
- [Spotify - Playlists Concepts](https://developer.spotify.com/documentation/web-api/concepts/playlists) -- Scope requirements for owned/followed/collaborative playlists
- [Spotify - Authorization](https://developer.spotify.com/documentation/web-api/concepts/authorization) -- PKCE flow for mobile apps
- [Spotify - Scopes](https://developer.spotify.com/documentation/web-api/concepts/scopes) -- Required scopes for playlist access
- [Spotify - Rate Limits](https://developer.spotify.com/documentation/web-api/concepts/rate-limits) -- Rolling 30-second window, no per-endpoint quotas published

### Music App UX Patterns
- [Apple Support - Add and Find Favorites in Apple Music](https://support.apple.com/en-us/111118) -- iOS 17+ favorites, auto-playlist, influence on recommendations
- [Spotify UX Case Study (UX Magazine)](https://uxmag.com/articles/a-ux-ui-case-study-on-spotify) -- Cards and carousels for content display
- [Spotify Playlist Feature User Flow (Medium)](https://medium.com/@aliciagarciadettke/how-i-designed-a-user-flow-for-spotifys-playlist-feature-e9d8c1de09ce) -- Playlist creation and sharing flow design
- [How to Organize Favorite Songs in Apple Music (HowToGeek)](https://www.howtogeek.com/ways-i-organize-my-favorite-songs-and-playlists-in-apple-music/) -- Favorites management patterns

### Running Music Apps
- [MOOV Beat Runner Help Center](https://helpcentre.moov-music.com/en/knowledge-base/moov-beat-runner/) -- "My Songs" star button, genre selection
- [RockMyRun](https://www.rockmyrun.com/) -- Favorite mixes (not songs), no import
- [PaceDJ](https://www.pacedj.com/) -- Library BPM scanning, no playlist import
- [Weav Run (Runner's World)](https://www.runnersworld.com/runners-stories/a32257227/running-app-weav-improves-cadence-stride/) -- Curated playlists, tempo adjustment, no user favorites
- [Chosic - Spotify Playlist Generator](https://www.chosic.com/playlist-generator/) -- Seed-based recommendation with up to 5 seeds

### Playlist Transfer Tools
- [Soundiiz](https://soundiiz.com/) -- Cross-platform playlist transfer
- [SongShift](https://apps.apple.com/us/app/songshift/id1097974566) -- iOS playlist transfer
- [FreeYourMusic - Add Multiple Songs to Spotify](https://freeyourmusic.com/blog/how-to-add-multiple-songs-to-a-playlist) -- Bulk song management

---
*Feature research for: Song Search, "Songs I Run To" & Spotify Integration -- Running Playlist AI*
*Researched: 2026-02-08*
