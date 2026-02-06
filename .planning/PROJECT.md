# Running Playlist AI

## What This Is

A cross-platform app (Flutter -- web, Android, iOS) that generates BPM-matched playlists for runners. Users input their run details (distance, pace, run type), and the app calculates their stride cadence, finds songs matching that BPM via GetSongBPM API, and builds a playlist tailored to their running music preferences -- with links to play each song on Spotify or YouTube.

## Core Value

A runner opens the app, enters their run plan, and gets a playlist where every song's beat matches their footstrike cadence -- no manual searching, no guessing BPM.

## Current State

**Shipped:** v1.2 Polish & Profiles (2026-02-06)
**Codebase:** ~7,618 LOC Dart (lib), ~5,830 LOC tests

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
- Safe enum deserialization with orElse fallbacks (corrupt data resilience)
- Delete confirmation dialogs on destructive actions

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

### Out of Scope

- Spotify OAuth integration -- Deferred until Developer Dashboard available; current approach works without it
- Spotify library import for taste profile -- Running music taste differs from general listening; questionnaire is better
- Spotify playlist export -- Deferred; external play links sufficient for now
- Apple Music / other streaming services -- Architecture allows future expansion
- Social features (sharing runs, leaderboards) -- Not core to the playlist value
- GPS tracking / live run monitoring -- This is a playlist tool, not a running tracker
- Built-in music player -- Use Spotify/YouTube for playback
- Real-time cadence detection -- Pre-generate playlists instead
- Audio tempo manipulation -- Match native BPM instead

## Context

- Spotify deprecated Audio Features API November 2024 -- new apps get 403 errors for BPM data
- GetSongBPM API is the recommended alternative BPM source (free with attribution)
- GetSongBPM has `/tempo/` endpoint for discovering songs by BPM value
- Running music taste differs from general listening taste -- questionnaire approach may produce better results than Spotify import
- Stride cadence for running typically ranges 150-200 steps/min; songs can match at 1:1, 1:2, or 2:1 ratios
- Spotify Developer Dashboard not accepting new app integrations as of 2026-02-05

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

---
*Last updated: 2026-02-06 after v1.2 milestone completed*
