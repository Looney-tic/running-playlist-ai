# Requirements: Running Playlist AI

**Defined:** 2026-02-05
**Core Value:** A runner enters their run plan and gets a playlist where every song's beat matches their footstrike cadence

## v1.0 Requirements

Requirements for milestone v1.0: Standalone Playlist Generator (no Spotify dependency).

### Auth Cleanup

- [x] **AUTH-10**: Spotify login removed from UI; app launches directly to home hub
- [x] **AUTH-11**: Home screen provides navigation to all features (stride, run plan, taste profile, playlist)

### Taste Profile

- [x] **TASTE-10**: User can select 1-5 preferred running genres from a curated list
- [x] **TASTE-11**: User can add up to 10 favorite artists for running music
- [x] **TASTE-12**: User can set energy level preference (chill, balanced, intense)
- [x] **TASTE-13**: Taste profile persists across app restarts

### BPM Data

- [x] **BPM-10**: App can discover songs by BPM value via GetSongBPM API
- [x] **BPM-11**: Previously looked-up BPM results load from local cache without API call
- [x] **BPM-12**: Songs at half or double target BPM are correctly identified as matches (85 BPM = 170 cadence)
- [x] **BPM-13**: BPM lookup handles API errors gracefully (shows message, doesn't crash)

### Playlist Generation

- [x] **PLAY-10**: User triggers generation and receives a playlist covering full run duration with BPM-matched songs
- [x] **PLAY-11**: Generated playlist respects user's taste profile (genre and artist preferences)
- [x] **PLAY-12**: Each song shows title, artist, BPM, and segment assignment
- [x] **PLAY-13**: User can open any song via external link (Spotify or YouTube)
- [x] **PLAY-14**: User can copy the full playlist as text to clipboard

### Playlist History

- [ ] **HIST-01**: User can view a list of previously generated playlists
- [ ] **HIST-02**: User can open a past playlist and see its tracks
- [ ] **HIST-03**: User can delete a past playlist

## v2 Requirements

Deferred to future milestones.

### Spotify Integration

- **SPOT-01**: User can log in via Spotify OAuth (PKCE flow)
- **SPOT-02**: User session persists across app restarts
- **SPOT-03**: User can log out
- **SPOT-04**: Auto-import taste from Spotify top tracks and saved tracks
- **SPOT-05**: Export generated playlist to user's Spotify account

### Advanced Features

- **ADV-01**: User can swap individual songs with BPM-matched alternatives
- **ADV-02**: Song swap shows alternatives filtered by taste profile
- **ADV-03**: Progressive overload (gradually increase cadence over weeks)

### Mobile

- **MOB-01**: All features verified on iOS
- **MOB-02**: All features verified on Android
- **MOB-03**: Platform-specific UI issues fixed (safe areas, status bar, back navigation)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Built-in music player | Use Spotify/YouTube for playback -- no engineering cost, better UX |
| Real-time cadence detection | Pre-generate playlists instead -- works with any client |
| GPS run tracking | Strava/Nike Run Club handle this -- not our domain |
| Heart rate integration | Cadence/pace is sufficient for BPM matching |
| Social features | Keep single-player for v1.0 |
| Audio tempo manipulation | Match native BPM instead -- avoid DSP complexity |
| Spotify API integration | Deferred to v2; dashboard blocked and questionnaire approach is better for running taste |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| AUTH-10 | Phase 11 | Complete |
| AUTH-11 | Phase 11 | Complete |
| TASTE-10 | Phase 12 | Complete |
| TASTE-11 | Phase 12 | Complete |
| TASTE-12 | Phase 12 | Complete |
| TASTE-13 | Phase 12 | Complete |
| BPM-10 | Phase 13 | Complete |
| BPM-11 | Phase 13 | Complete |
| BPM-12 | Phase 13 | Complete |
| BPM-13 | Phase 13 | Complete |
| PLAY-10 | Phase 14 | Complete |
| PLAY-11 | Phase 14 | Complete |
| PLAY-12 | Phase 14 | Complete |
| PLAY-13 | Phase 14 | Complete |
| PLAY-14 | Phase 14 | Complete |
| HIST-01 | Phase 15 | Pending |
| HIST-02 | Phase 15 | Pending |
| HIST-03 | Phase 15 | Pending |

**Coverage:**
- v1.0 requirements: 18 total
- Mapped to phases: 18
- Unmapped: 0

---
*Requirements defined: 2026-02-05*
*Last updated: 2026-02-05 after Phase 14 completion*
