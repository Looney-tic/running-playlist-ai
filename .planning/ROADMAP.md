# Roadmap: Running Playlist AI

## Overview

This roadmap delivers a BPM-matched running playlist generator in 10 phases, progressing from cross-platform foundation through Spotify integration, data pipeline validation, user preference systems, and culminating in playlist generation with structured run support. The critical path validates BPM data availability early (Phase 3) before investing in generation logic, since external BPM sources are an existential dependency after Spotify deprecated their Audio Features API.

**Development Strategy: Web-First**
Phases 3-9 develop and test on web (Chrome) only for fastest iteration. Phase 2 (Spotify Auth) includes mobile OAuth testing since redirect flows differ per platform. Phase 10 handles iOS/Android verification and platform-specific fixes. Flutter's shared widget layer means 95%+ of code works cross-platform without changes.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Project Foundation** - Flutter project skeleton running on web, Android, and iOS
- [ ] **Phase 2: Spotify Authentication** - Users can log in via Spotify and maintain sessions
- [ ] **Phase 3: BPM Data Pipeline** - External BPM lookup and caching validated and operational
- [ ] **Phase 4: Taste Profile** - Users can import and customize their music preferences
- [ ] **Phase 5: Stride & Cadence** - Users can determine their target cadence from pace and body metrics
- [x] **Phase 6: Steady Run Planning** - Users can define a steady-pace run with calculated BPM target
- [ ] **Phase 7: Playlist Generation** - Users get a BPM-matched playlist pushed to their Spotify account
- [ ] **Phase 8: Structured Run Types** - Users can plan warm-up/cool-down and interval runs
- [ ] **Phase 9: Playlist History** - Users can view and reuse previously generated playlists
- [ ] **Phase 10: Mobile Hardening** - App verified and polished on iOS and Android

## Phase Details

### Phase 1: Project Foundation
**Goal**: A working Flutter app shell runs on all three target platforms with navigation, architecture scaffolding, and Supabase backend connected
**Depends on**: Nothing (first phase)
**Requirements**: PLAT-01, PLAT-02, PLAT-03
**Success Criteria** (what must be TRUE):
  1. App launches and renders a screen on Android emulator
  2. App launches and renders a screen on iOS simulator
  3. App launches and renders a screen in a web browser
  4. Navigation between placeholder screens works on all platforms
  5. Supabase connection is established (can read/write test data)
**Plans**: 2 plans

Plans:
- [x] 01-01-PLAN.md — Flutter project creation with dependencies, linting, architecture, and navigation
- [x] 01-02-PLAN.md — Supabase connection, platform config, and cross-platform verification

### Phase 2: Spotify Authentication
**Goal**: Users can securely log in with their Spotify account and stay logged in across app restarts
**Depends on**: Phase 1
**Requirements**: AUTH-01, AUTH-02, AUTH-03
**Note**: Exception to web-first strategy — OAuth redirect flows differ per platform, so this phase tests web + at least one mobile platform.
**Success Criteria** (what must be TRUE):
  1. User can tap "Log in with Spotify" and complete OAuth PKCE flow
  2. User closes and reopens the app and remains logged in
  3. User can log out and is returned to a logged-out state
  4. OAuth flow works correctly on web and at least one mobile platform (iOS or Android)
**Plans**: 2 plans

Plans:
- [ ] 02-01-PLAN.md — Auth repository, providers, auth-guarded router, login screen, and logout
- [ ] 02-02-PLAN.md — Platform deep link configuration and end-to-end OAuth verification

### Phase 3: BPM Data Pipeline
**Goal**: The app can reliably look up BPM for any song and cache results for fast future access
**Depends on**: Phase 2
**Requirements**: BPM-01, BPM-02
**Success Criteria** (what must be TRUE):
  1. Given a Spotify track, the app retrieves its BPM from GetSongBPM (or fallback source)
  2. Previously looked-up BPM values load instantly from cache without hitting external API
  3. BPM lookup handles missing data gracefully (shows "BPM unavailable" rather than crashing)
  4. Cache hit rate is measurable and logged for monitoring coverage
**Plans**: TBD

Plans:
- [ ] 03-01: TBD
- [ ] 03-02: TBD

### Phase 4: Taste Profile
**Goal**: Users have a music taste profile that combines their Spotify listening history with manual running-specific preferences
**Depends on**: Phase 2
**Requirements**: TASTE-01, TASTE-02, TASTE-03, TASTE-04
**Success Criteria** (what must be TRUE):
  1. User sees auto-imported genres and artists from their Spotify listening history
  2. User can select preferred genres for running music
  3. User can boost or exclude specific artists
  4. User can set an energy level preference for their running music
**Plans**: TBD

Plans:
- [ ] 04-01: TBD
- [ ] 04-02: TBD

### Phase 5: Stride & Cadence
**Goal**: Users can determine their target running cadence from pace input, with optional refinement from height and real-world calibration
**Depends on**: Phase 1
**Requirements**: STRIDE-01, STRIDE-02, STRIDE-03
**Success Criteria** (what must be TRUE):
  1. User enters target pace (min/km) and sees a calculated cadence (steps/min)
  2. User enters their height and the cadence estimate adjusts accordingly
  3. User can perform a real-world calibration (count strides) that overrides the formula estimate
  4. Calculated cadence falls within realistic running range (150-200 spm)
**Plans**: 2 plans

Plans:
- [x] 05-01-PLAN.md — TDD: Stride calculator domain logic with unit tests (pure Dart computation + pace parsing)
- [x] 05-02-PLAN.md — Providers, persistence, UI screen, router integration, and calibration flow

### Phase 6: Steady Run Planning
**Goal**: Users can define a steady-pace run and see the BPM target for playlist generation
**Depends on**: Phase 5
**Requirements**: RUN-01
**Success Criteria** (what must be TRUE):
  1. User enters distance and pace for a steady run
  2. App calculates run duration and target BPM from cadence
  3. Run plan is saved and available for playlist generation
**Plans**: 2 plans

Plans:
- [x] 06-01-PLAN.md — TDD: Run plan domain model and calculator with unit tests (data classes, duration/BPM computation)
- [x] 06-02-PLAN.md — Persistence, providers, UI screen, router integration, and home navigation

### Phase 7: Playlist Generation
**Goal**: Users get a complete BPM-matched playlist for their run, exported directly to their Spotify account
**Depends on**: Phase 3, Phase 4, Phase 6
**Requirements**: PLAY-01, BPM-03, PLAY-02, PLAY-03
**Success Criteria** (what must be TRUE):
  1. User triggers generation and receives a playlist covering their full run duration with BPM-matched songs
  2. Songs at half or double the target BPM are correctly included as candidates (85 BPM matches 170 cadence)
  3. User can swap individual songs and see BPM-matched alternatives
  4. User taps "Export to Spotify" and the playlist appears in their Spotify app
  5. Generated playlist reflects the user's taste profile preferences
**Plans**: TBD

Plans:
- [ ] 07-01: TBD
- [ ] 07-02: TBD
- [ ] 07-03: TBD

### Phase 8: Structured Run Types
**Goal**: Users can plan warm-up/cool-down and interval training runs with per-segment BPM targets
**Depends on**: Phase 7
**Requirements**: RUN-02, RUN-03
**Success Criteria** (what must be TRUE):
  1. User can create a run with warm-up and cool-down segments that ramp BPM up and down
  2. User can create an interval training run with alternating fast/slow BPM segments
  3. Generated playlist for structured runs transitions between BPM targets at segment boundaries
**Plans**: TBD

Plans:
- [ ] 08-01: TBD
- [ ] 08-02: TBD

### Phase 9: Playlist History
**Goal**: Users can revisit and reuse playlists they have previously generated
**Depends on**: Phase 7
**Requirements**: PLAY-04
**Success Criteria** (what must be TRUE):
  1. User can view a list of previously generated playlists with run details
  2. User can open a past playlist and see its tracks
  3. User can re-export a past playlist to Spotify
**Plans**: TBD

Plans:
- [ ] 09-01: TBD

### Phase 10: Mobile Hardening
**Goal**: App works correctly and feels native on both iOS and Android
**Depends on**: Phase 9
**Requirements**: PLAT-01, PLAT-02 (re-verification after all features built)
**Note**: Web-first development means features were built/tested on Chrome. This phase catches platform-specific issues.
**Success Criteria** (what must be TRUE):
  1. All features work on iOS simulator (navigation, auth, playlist generation, history)
  2. All features work on Android emulator (same checks)
  3. Platform-specific UI issues fixed (safe areas, status bar, back navigation)
  4. No platform-specific crashes or errors in debug console
**Plans**: TBD

Plans:
- [ ] 10-01: TBD
- [ ] 10-02: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 > 2 > 3 > 4 > 5 > 6 > 7 > 8 > 9 > 10
Note: Phases 3, 4, and 5 can execute in parallel after Phase 2 (or Phase 1 for Phase 5).
Phases 3-9 target web only (web-first strategy). Phase 10 verifies iOS/Android.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Project Foundation | 2/2 | Complete | 2026-02-05 |
| 2. Spotify Authentication | 0/2 | Not started | - |
| 3. BPM Data Pipeline | 0/TBD | Not started | - |
| 4. Taste Profile | 0/TBD | Not started | - |
| 5. Stride & Cadence | 2/2 | Complete | 2026-02-05 |
| 6. Steady Run Planning | 2/2 | Complete | 2026-02-05 |
| 7. Playlist Generation | 0/TBD | Not started | - |
| 8. Structured Run Types | 0/TBD | Not started | - |
| 9. Playlist History | 0/TBD | Not started | - |
| 10. Mobile Hardening | 0/TBD | Not started | - |
