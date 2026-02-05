# Running Playlist AI

## What This Is

A cross-platform app (Flutter — web, Android, iOS) that generates BPM-matched playlists for runners. Users input their run details (distance, pace, run type), and the app calculates their stride cadence, finds songs matching that BPM via GetSongBPM API, and builds a playlist tailored to their running music preferences — with links to play each song on Spotify or YouTube.

## Core Value

A runner opens the app, enters their run plan, and gets a playlist where every song's beat matches their footstrike cadence — no manual searching, no guessing BPM.

## Current Milestone: v1.0 Standalone Playlist Generator

**Goal:** Deliver the full playlist generation experience without Spotify API dependency.

**Target features:**
- BPM song discovery via GetSongBPM API
- Questionnaire-based running music taste profile
- Playlist generation matching BPM to cadence per run segment
- External play links (Spotify/YouTube URLs) for listening
- Playlist history for reuse

## Requirements

### Validated

- ✓ Stride calculator: estimate cadence from height + target pace, with optional real-world calibration — v0.1
- ✓ Run planner: support steady pace, warm-up/cool-down, and interval training with per-segment BPM targets — v0.1
- ✓ Cross-platform: single Flutter codebase for web, Android, and iOS — v0.1

### Active

- [ ] Auth cleanup: remove Spotify login from UI, simplify to unauthenticated flow
- [ ] Taste profile: questionnaire-based running music preferences (genres, artists, energy level)
- [ ] BPM data: discover songs by BPM via GetSongBPM API with local caching
- [ ] BPM matching: support half/double tempo matching (85 BPM song = 170 cadence)
- [ ] Playlist builder: generate BPM-matched playlist for full run duration using taste preferences
- [ ] Play songs: external links to play songs on Spotify or YouTube
- [ ] Playlist history: save and reuse previously generated playlists

### Out of Scope

- Spotify OAuth integration — Deferred until Developer Dashboard available; current approach works without it
- Spotify library import for taste profile — Running music taste differs from general listening; questionnaire is better
- Spotify playlist export — Deferred; external play links sufficient for v1.0
- Apple Music / other streaming services — Architecture allows future expansion
- Social features (sharing runs, leaderboards) — Not core to the playlist value
- GPS tracking / live run monitoring — This is a playlist tool, not a running tracker
- Built-in music player — Use Spotify/YouTube for playback
- Real-time cadence detection — Pre-generate playlists instead
- Audio tempo manipulation — Match native BPM instead

## Context

- Spotify deprecated Audio Features API November 2024 — new apps get 403 errors for BPM data
- GetSongBPM API is the recommended alternative BPM source (free with attribution)
- GetSongBPM has `/tempo/` endpoint for discovering songs by BPM value
- Running music taste differs from general listening taste — questionnaire approach may produce better results than Spotify import
- Stride cadence for running typically ranges 150-200 steps/min; songs can match at 1:1, 1:2, or 2:1 ratios
- Spotify Developer Dashboard not accepting new app integrations as of 2026-02-05

## Constraints

- **Platform**: Flutter (Dart) — single codebase for web, Android, iOS
- **BPM source**: GetSongBPM API (free tier, attribution required)
- **No auth required**: App works without user accounts for v1.0
- **Backend**: Supabase initialized but minimal use — SharedPreferences for local persistence
- **Web-first**: Development and testing on Chrome, mobile hardening deferred

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Flutter for cross-platform | Single codebase for web + mobile, good ecosystem | ✓ Good |
| Supabase as backend | Relational data fits user-song-playlist model | ✓ Good |
| Riverpod 2.x (manual providers) | Code-gen incompatible with Dart 3.10 | ✓ Good |
| BPM matching allows half/double time | Songs at 85 BPM can match 170 cadence, expands pool | — Pending |
| Calibration-based stride calculator | Basic estimate from height+pace, optional calibration | ✓ Good |
| Segment-based RunPlan model | Steady=1 segment, extends to intervals without restructuring | ✓ Good |
| No Spotify integration for v1.0 | Dashboard blocked; questionnaire taste profile is better for running; add Spotify later | — Pending |
| GetSongBPM API for BPM data | Spotify audio-features deprecated Nov 2024; GetSongBPM is free with attribution | — Pending |
| Questionnaire taste profile | Running music taste differs from general listening; no auth needed | — Pending |
| `http` package for HTTP client | Simple GET requests only; Dart team maintained; dio is overkill | — Pending |
| SharedPreferences for all persistence | Consistent pattern across features; sufficient for single-user local app | ✓ Good |

---
*Last updated: 2026-02-05 after milestone v1.0 started*
