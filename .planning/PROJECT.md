# Running Playlist AI

## What This Is

A cross-platform app (Flutter -- web, Android, iOS) that generates BPM-matched playlists for runners. Users input their run details (distance, pace, run type), and the app calculates their stride cadence, finds songs matching that BPM via GetSongBPM API, and builds a playlist tailored to their running music preferences -- with links to play each song on Spotify or YouTube.

## Core Value

A runner opens the app, enters their run plan, and gets a playlist where every song's beat matches their footstrike cadence -- no manual searching, no guessing BPM.

## Current State

**Shipped:** v1.0 Standalone Playlist Generator (2026-02-05)
**Codebase:** 4,282 LOC Dart (lib), 3,924 LOC tests, 38 files, 229 tests passing

**What works end-to-end:**
- Stride calculator (pace + height -> cadence, optional calibration)
- Run planner (steady, warm-up/cool-down, intervals with per-segment BPM)
- Taste profile (genre picker, artist list, energy level, persisted)
- BPM discovery (GetSongBPM API, local cache with 7-day TTL, half/double-time matching)
- Playlist generation (BPM-matched songs assigned to run segments, scored by taste)
- External play links (Spotify/YouTube URLs via url_launcher)
- Playlist history (auto-save, list view, detail view, swipe-to-delete)

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

## Current Milestone: v1.1 Experience Quality

**Goal:** Make generated playlists genuinely great for running — not just BPM-matched, but songs that are proven good running songs, matched to the user's taste, with frictionless stride adjustment and repeat generation.

**Target features:**
- Running song quality scoring (what makes a song good for running beyond BPM)
- Curated running song data per genre from web sources
- Improved taste profiling specifically for running music
- Easy post-run stride/cadence adjustment ("that was a bit fast/slow")
- Streamlined repeat generation flow (near-instant for returning users)

### Active

- [ ] Song quality: playlist includes songs that are proven good for running, not just BPM-matched
- [ ] Taste accuracy: running-specific taste profiling produces results users actually want to hear
- [ ] Stride adjustment: easy to nudge cadence after a real run
- [ ] Repeat flow: returning users can generate a new playlist with minimal friction

### Out of Scope

- Spotify OAuth integration -- Deferred until Developer Dashboard available; current approach works without it
- Spotify library import for taste profile -- Running music taste differs from general listening; questionnaire is better
- Spotify playlist export -- Deferred; external play links sufficient for v1.0
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

---
*Last updated: 2026-02-05 after v1.1 milestone started*
