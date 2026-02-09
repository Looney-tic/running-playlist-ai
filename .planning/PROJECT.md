# Running Playlist AI

## What This Is

A cross-platform app (Flutter -- web, Android, iOS) that generates BPM-matched playlists for runners. Users input their run details (distance, pace, run type), and the app calculates their stride cadence, finds songs matching that BPM via GetSongBPM API, and builds a playlist tailored to their running music preferences. The app learns from song feedback -- liked songs rank higher, disliked songs are filtered out, and implicit taste patterns are surfaced as suggestions to refine the user's profile over time.

## Core Value

A runner opens the app, enters their run plan, and gets a playlist where every song's beat matches their footstrike cadence -- no manual searching, no guessing BPM.

## Current State

**Shipped:** v1.4 Smart Song Search & Spotify Foundation (2026-02-09)
**Codebase:** ~21,038 LOC Dart (12,857 lib + 8,181 test)

**What works end-to-end:**
- Stride calculator (pace + height -> cadence, optional calibration)
- Run planner (steady, warm-up/cool-down, intervals with per-segment BPM)
- Run plan library (multiple saved plans, selection)
- Taste profile (genre picker, artist list, energy level, vocal pref, disliked artists, persisted)
- Multiple named taste profiles with quick switching from playlist screen
- 5,066 curated songs with runnability scores (crowd-sourced + feature-based)
- Playlist generation (BPM-matched, runnability-scored, taste-filtered, artist-diverse)
- Instant shuffle/regenerate reusing song pool (no API re-fetch)
- Quality badges and cadence nudge in playlist UI
- One-tap regeneration from home screen
- External play links (Spotify/YouTube URLs via url_launcher)
- Playlist history (auto-save, list view, detail view, swipe-to-delete)
- Guided onboarding flow for first-time users (4 steps -> first playlist)
- Context-aware home screen with empty states for missing profile/plan
- Song feedback: like/dislike any song, persisted, affects future generation
- Feedback library: tabbed liked/disliked views with flip/remove actions
- Post-run review: rate all songs from last playlist in focused review screen
- Playlist freshness: "Keep it Fresh" vs "Optimize for Taste" toggle with play history tracking
- Taste learning: pattern detection surfaces genre/artist suggestions from feedback
- "Songs I Run To": user-curated running song collection with add/remove/persist
- Running songs scoring: songs boost playlist generation, feed taste learning, show BPM compatibility
- Song search: typeahead autocomplete with match highlighting against curated catalog + Spotify
- Spotify auth: OAuth PKCE connection with secure token storage (mock-first, real scaffold ready)
- Spotify playlist import: browse playlists, multi-select tracks, batch import into collection

## Requirements

### Validated

- ✓ Stride calculator: estimate cadence from height + target pace, with optional real-world calibration -- v0.1
- ✓ Run planner: support steady pace, warm-up/cool-down, and interval training with per-segment BPM targets -- v0.1
- ✓ Cross-platform: single Flutter codebase for web, Android, and iOS -- v0.1
- ✓ Auth cleanup: remove Spotify login, home hub navigation -- v1.0
- ✓ Taste profile: questionnaire-based running music preferences (genres, artists, energy level) with persistence -- v1.0
- ✓ BPM data: discover songs by BPM via GetSongBPM API with local caching and half/double-time matching -- v1.0
- ✓ Playlist generation: BPM-matched playlist for full run duration using taste preferences -- v1.0
- ✓ Play songs: external links to Spotify or YouTube for every song -- v1.0
- ✓ Clipboard copy: copy full playlist as text -- v1.0
- ✓ Playlist history: save, view, and delete previously generated playlists -- v1.0
- ✓ Song quality scoring: composite runnability score (crowd-sourced + feature-based, 0-100) integrated into playlist ranking -- v1.1
- ✓ Curated running songs: 5,066 songs with runnability, danceability, genre, BPM data -- v1.1
- ✓ Extended taste profiling: vocal preference, tempo variance tolerance, disliked artists, decade preferences -- v1.1
- ✓ Cadence nudge: +/- buttons on playlist and home screen for post-run adjustment -- v1.1
- ✓ One-tap regeneration: returning users generate new playlist from home screen -- v1.1
- ✓ Instant shuffle/regenerate: reuses song pool with new random seed, no API re-fetch -- v1.2
- ✓ Cold-start reliability: playlist generation works without null state crashes (readiness guards) -- v1.2
- ✓ Profile-aware regeneration: switching run plan or taste profile updates next generation -- v1.2
- ✓ Delete confirmation: destructive profile actions require user confirmation -- v1.2
- ✓ Corrupt data resilience: enum deserializers have orElse fallbacks preventing crash on unknown values -- v1.2
- ✓ Multi-profile lifecycle: create, edit, delete, switch, persist verified with integration tests -- v1.2
- ✓ Guided onboarding: first-run users see welcome -> genres -> pace -> auto-generate first playlist -- v1.2
- ✓ Skip-friendly onboarding: any step can be skipped with sensible defaults preserved -- v1.2
- ✓ Context-aware home screen: adapts based on whether user has profiles and run plans configured -- v1.2
- ✓ Song feedback: users can like/dislike songs in playlist view and post-run review -- v1.3
- ✓ Feedback library: browse and edit all song feedback in a dedicated screen -- v1.3
- ✓ Scoring integration: feedback signals boost/penalize songs in SongQualityScorer -- v1.3
- ✓ Taste learning: analyze liked/disliked songs to discover implicit genre/artist preferences -- v1.3
- ✓ Freshness toggle: user chooses between fresh variety vs taste-optimized playlists -- v1.3
- ✓ Freshness tracking: record song play history to support freshness deprioritization -- v1.3
- ✓ Post-run review: rate all songs from most recent playlist in a focused review flow -- v1.3
- ✓ Song search with typeahead autocomplete against curated catalog (5,066 songs, 300ms debounce) -- v1.4
- ✓ Search abstraction layer with curated + Spotify composite backend and source badges -- v1.4
- ✓ "Songs I Run To" list with scoring boost, taste learning integration, and BPM compatibility -- v1.4
- ✓ Spotify OAuth PKCE auth with secure token storage, auto-refresh, graceful degradation -- v1.4
- ✓ Spotify playlist browse and multi-select track import with batch addSongs -- v1.4

### Active

(None -- run `/gsd:new-milestone` to define next milestone)

### Out of Scope

- Spotify playlist export -- Deferred; external play links sufficient for now
- Apple Music / other streaming services -- Architecture allows future expansion
- Social features (sharing runs, leaderboards) -- Not core to the playlist value
- GPS tracking / live run monitoring -- This is a playlist tool, not a running tracker
- Built-in music player -- Use Spotify/YouTube for playback
- Real-time cadence detection -- Pre-generate playlists instead
- Audio tempo manipulation -- Match native BPM instead
- ML-based taste learning -- Single-user frequency counting outperforms ML at <4,000 data points

## Context

- Spotify deprecated Audio Features API November 2024 -- new apps get 403 errors for BPM data
- GetSongBPM API is the recommended alternative BPM source (free with attribution)
- GetSongBPM has `/tempo/` endpoint for discovering songs by BPM value
- Running music taste differs from general listening taste -- questionnaire approach may produce better results than Spotify import
- Stride cadence for running typically ranges 150-200 steps/min; songs can match at 1:1, 1:2, or 2:1 ratios
- Spotify Developer Dashboard not accepting new app integrations as of 2026-02-05
- SongQualityScorer: 8 dimensions, max 41 points (artist=10, danceability=8, genre=6, curated=5, energy=4, BPM=3, diversity=-5, dislikedArtist=-15) plus likedSong=5 and freshnessPenalty
- Curated dataset: 5,066 songs across 15 genres and 2,383 unique artists
- Taste learning thresholds: genre 3 liked/30% ratio/5 min total, artist 2 liked, disliked 2, re-emergence +3 delta
- Spotify Developer Dashboard still not accepting new app registrations (as of 2026-02-09)
- All Spotify features built mock-first; real implementations ready for swap when credentials available
- Abstract service pattern used for all Spotify features: SpotifyAuthService, SongSearchService, SpotifyPlaylistService

## Constraints

- **Platform**: Flutter (Dart) -- single codebase for web, Android, iOS
- **BPM source**: GetSongBPM API (free tier, attribution required)
- **No auth required**: App works without user accounts
- **Backend**: Supabase initialized but minimal use -- SharedPreferences for local persistence
- **Web-first**: Development and testing on Chrome, mobile hardening deferred

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Flutter for cross-platform | Single codebase for web + mobile, good ecosystem | ✓ Good |
| Supabase as backend | Relational data fits user-song-playlist model | ✓ Good |
| Riverpod 2.x (manual providers) | Code-gen incompatible with Dart 3.10 | ✓ Good |
| BPM matching allows half/double time | Songs at 85 BPM can match 170 cadence, expands pool | ✓ Good |
| Calibration-based stride calculator | Basic estimate from height+pace, optional calibration | ✓ Good |
| Segment-based RunPlan model | Steady=1 segment, extends to intervals without restructuring | ✓ Good |
| No Spotify integration for v1.0 | Dashboard blocked; questionnaire taste profile is better for running | ✓ Good |
| GetSongBPM API for BPM data | Spotify audio-features deprecated Nov 2024; GetSongBPM is free with attribution | ✓ Good |
| Questionnaire taste profile | Running music taste differs from general listening; no auth needed | ✓ Good |
| `http` package for HTTP client | Simple GET requests only; Dart team maintained; dio is overkill | ✓ Good |
| SharedPreferences for all persistence | Consistent pattern across features; sufficient for single-user local app | ✓ Good |
| Playlist.id nullable String? | Backward compat with pre-history JSON; auto-assigned on generation | ✓ Good |
| unawaited() auto-save | Fire-and-forget after UI state is set; doesn't block playlist display | ✓ Good |
| Shared widget extraction | SegmentHeader/SongTile used by both PlaylistScreen and HistoryDetailScreen | ✓ Good |
| Runnability scoring (crowd + features) | 5,066 songs with 0-100 runnability; replaces flat curated bonus in scorer | ✓ Good |
| curatedRunnability Map<String,int> | Lookup runnability values during scoring, not just set membership | ✓ Good |
| Completer-based ensureLoaded() | Sync, idempotent readiness guards for cold-start reliability | ✓ Good |
| shufflePlaylist() reuses songPool | Instant regeneration with new Random seed, no API re-fetch | ✓ Good |
| orElse fallbacks on all enum fromJson | Prevents crash on corrupt/unknown enum values from older/newer app | ✓ Good |
| Onboarding flag pre-loaded in main.dart | Sync GoRouter redirect -- no flicker, no async guard needed | ✓ Good |
| PageView for onboarding steps | NeverScrollableScrollPhysics prevents swipe; buttons control navigation | ✓ Good |
| Context-aware home screen | Conditional setup cards when profile/plan missing; adapts to user state | ✓ Good |
| likedSongWeight = 5 | Ranking boost without overpowering quality dimensions | ✓ Good |
| Disliked songs hard-filtered | Remove entirely rather than soft-penalize; cleaner UX | ✓ Good |
| 5-tier freshness penalty decay | 0/-8/-5/-2/0 over 30 days; auto-prune old history | ✓ Good |
| Frequency counting for taste learning | ML overkill for <4,000 data points; deterministic and interpretable | ✓ Good |
| Genre enrichment via curated lookup | SongFeedback.genre field never populated; curated metadata provides genre | ✓ Good |
| Evidence-count-delta for dismissed re-emergence | Tracks dismissed evidence count, requires +3 new entries to resurface | ✓ Good |
| Pop before state change on dismiss | Avoids reactive rebuild pitfall when marking reviewed and navigating | ✓ Good |
| Profile mutation via existing notifier | acceptSuggestion goes through TasteProfileLibraryNotifier.updateProfile() | ✓ Good |
| Mock-first Spotify pattern | Dashboard unavailable; abstract service + mock allows development without credentials | ✓ Good |
| SongKey.normalize for dedup | Consistent key format across feedback, running songs, and composite search | ✓ Good |
| Batch addSongs method | Single state update + single persist for multi-track import efficiency | ✓ Good |
| Composite search service | Merges curated + Spotify results with SongKey dedup, curated priority | ✓ Good |
| flutter_secure_storage for tokens | Keychain (iOS), EncryptedSharedPreferences (Android) -- not plain SharedPrefs | ✓ Good |
| Abstract class (not interface) | Consistent pattern across SpotifyAuthService, SongSearchService, SpotifyPlaylistService | ✓ Good |

---
*Last updated: 2026-02-09 after v1.4 milestone*
