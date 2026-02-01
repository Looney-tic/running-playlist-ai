# Requirements: Running Playlist AI

**Defined:** 2026-02-01
**Core Value:** A runner enters their run plan and gets a playlist where every song's beat matches their footstrike cadence

## v1 Requirements

### Authentication

- [ ] **AUTH-01**: User can log in via Spotify OAuth (PKCE flow)
- [ ] **AUTH-02**: User session persists across app restarts
- [ ] **AUTH-03**: User can log out

### Taste Profile

- [ ] **TASTE-01**: Auto-import taste from Spotify top tracks and saved tracks
- [ ] **TASTE-02**: User can select preferred running genres
- [ ] **TASTE-03**: User can boost or exclude specific artists
- [ ] **TASTE-04**: User can set energy level preference for running music

### Stride & Cadence

- [ ] **STRIDE-01**: Calculate cadence from target pace (min/km)
- [ ] **STRIDE-02**: Improve stride estimate using user's height
- [ ] **STRIDE-03**: Optional real-world calibration (count actual strides)

### BPM Data

- [ ] **BPM-01**: Look up song BPM via external API (GetSongBPM/ReccoBeats)
- [ ] **BPM-02**: Cache BPM data to avoid repeated lookups
- [ ] **BPM-03**: Support half/double tempo matching (85 BPM song = 170 cadence)

### Run Planning

- [ ] **RUN-01**: Create steady-pace run (distance + pace → single BPM target)
- [ ] **RUN-02**: Create warm-up/cool-down run (ramping BPM at start/end)
- [ ] **RUN-03**: Create interval training run (alternating fast/slow BPM segments)

### Playlist Generation

- [ ] **PLAY-01**: Auto-generate playlist matching BPM to cadence for full run duration
- [ ] **PLAY-02**: User can swap individual songs with BPM-matched alternatives
- [ ] **PLAY-03**: Create generated playlist on user's Spotify account
- [ ] **PLAY-04**: Save and view previously generated playlists

### Cross-Platform

- [ ] **PLAT-01**: App works on Android
- [ ] **PLAT-02**: App works on iOS
- [ ] **PLAT-03**: App works on web

## v2 Requirements

### Music Services

- **MUSIC-01**: Support Apple Music as alternative to Spotify
- **MUSIC-02**: Support other streaming services

### Social

- **SOCL-01**: Share playlists with other users in-app
- **SOCL-02**: Community-curated running playlists

### Advanced Training

- **TRAIN-01**: Import training plans from Strava/Garmin
- **TRAIN-02**: Progressive overload (gradually increase cadence over weeks)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Built-in music player | Use Spotify for playback — no engineering cost, better UX |
| Real-time cadence detection | Pre-generate playlists instead — works with any Spotify client |
| GPS run tracking | Strava/Nike Run Club handle this — not our domain |
| Heart rate integration | Cadence/pace is sufficient for BPM matching |
| Social features | Keep single-player for v1, use Spotify's built-in sharing |
| Apple Music / other services | Spotify-only for v1, architecture allows future expansion |
| Audio tempo manipulation | Match native BPM instead — avoid DSP complexity and patents |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| AUTH-01 | Phase 2 | Pending |
| AUTH-02 | Phase 2 | Pending |
| AUTH-03 | Phase 2 | Pending |
| TASTE-01 | Phase 4 | Pending |
| TASTE-02 | Phase 4 | Pending |
| TASTE-03 | Phase 4 | Pending |
| TASTE-04 | Phase 4 | Pending |
| STRIDE-01 | Phase 5 | Pending |
| STRIDE-02 | Phase 5 | Pending |
| STRIDE-03 | Phase 5 | Pending |
| BPM-01 | Phase 3 | Pending |
| BPM-02 | Phase 3 | Pending |
| BPM-03 | Phase 7 | Pending |
| RUN-01 | Phase 6 | Pending |
| RUN-02 | Phase 8 | Pending |
| RUN-03 | Phase 8 | Pending |
| PLAY-01 | Phase 7 | Pending |
| PLAY-02 | Phase 7 | Pending |
| PLAY-03 | Phase 7 | Pending |
| PLAY-04 | Phase 9 | Pending |
| PLAT-01 | Phase 1 | Pending |
| PLAT-02 | Phase 1 | Pending |
| PLAT-03 | Phase 1 | Pending |

**Coverage:**
- v1 requirements: 23 total
- Mapped to phases: 23
- Unmapped: 0

---
*Requirements defined: 2026-02-01*
*Last updated: 2026-02-01 after roadmap creation*
