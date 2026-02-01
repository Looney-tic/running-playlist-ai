# Running Playlist AI

## What This Is

A cross-platform app (Flutter — web, Android, iOS) that generates Spotify playlists tailored to a runner's cadence. Users input their run details (distance, pace, run type), and the app calculates their stride rate, matches it to song BPM, factors in their music taste, and builds a playlist that lasts the entire run — then pushes it to Spotify.

## Core Value

A runner opens the app, enters their run plan, and gets a playlist where every song's beat matches their footstrike cadence — no manual searching, no guessing BPM.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Stride calculator: estimate cadence from height + target pace, with optional real-world calibration
- [ ] Taste profile: auto-import from Spotify listening history + manual genre/artist/energy preferences
- [ ] Run planner: support steady pace, warm-up/cool-down, and interval training with per-segment BPM targets
- [ ] Playlist builder: auto-generate full playlist matching BPM to cadence for run duration; user can swap individual songs
- [ ] BPM data: accurate beats-per-minute for a large song catalog (source TBD via research)
- [ ] Spotify integration: OAuth login, read listening history, create playlists on user's account
- [ ] Cross-platform: single Flutter codebase for web, Android, and iOS

### Out of Scope

- Apple Music / other streaming services — Spotify-only for v1, architecture should allow future expansion
- Social features (sharing runs, leaderboards) — not core to the playlist value
- GPS tracking / live run monitoring — this is a playlist tool, not a running tracker
- Offline playback — handled by Spotify's own app

## Context

- Spotify Web API provides audio features including tempo (BPM) per track, plus user top tracks/artists/genres
- BPM accuracy from Spotify's API varies; may need supplementary sources or verification
- Stride cadence for running typically ranges 150-190 steps/min; songs can match at 1:1, 1:2, or 2:1 ratios
- Flutter enables single codebase for all three platforms with good Spotify SDK support
- Future monetization possible — keep architecture ready for feature gating (freemium)

## Constraints

- **Platform**: Flutter (Dart) — single codebase for web, Android, iOS
- **Music service**: Spotify API only for v1
- **Auth**: Spotify OAuth (no separate account system needed for v1)
- **Backend**: TBD — research will determine best fit (Firebase, Supabase, or custom)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Flutter for cross-platform | Single codebase for web + mobile, good ecosystem | — Pending |
| Spotify-only for v1 | Simplifies integration, largest user base | — Pending |
| BPM matching allows half/double time | Songs at 80 BPM can match 160 cadence | — Pending |
| Calibration-based stride calculator | Basic estimate from height+pace, optional real calibration for accuracy | — Pending |

---
*Last updated: 2026-02-01 after initialization*
