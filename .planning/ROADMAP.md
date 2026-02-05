# Roadmap: Running Playlist AI

## Milestones

- ~~**v0.1 Foundation**~~ - Phases 1-10 (shipped 2026-02-05)
- **v1.0 Standalone Playlist Generator** - Phases 11-15 (in progress)

## Phases

<details>
<summary>v0.1 Foundation (Phases 1-10) - SHIPPED 2026-02-05</summary>

### Phase 1: Project Foundation
**Goal**: Working Flutter app shell on all three platforms with navigation and Supabase connected
**Plans**: 2/2 complete

Plans:
- [x] 01-01-PLAN.md -- Flutter project creation with dependencies, linting, architecture, and navigation
- [x] 01-02-PLAN.md -- Supabase connection, platform config, and cross-platform verification

### Phase 5: Stride & Cadence
**Goal**: Users can determine their target running cadence from pace input with optional calibration
**Plans**: 2/2 complete

Plans:
- [x] 05-01-PLAN.md -- TDD: Stride calculator domain logic with unit tests
- [x] 05-02-PLAN.md -- Providers, persistence, UI screen, router integration, and calibration flow

### Phase 6: Steady Run Planning
**Goal**: Users can define a steady-pace run and see the BPM target for playlist generation
**Plans**: 2/2 complete

Plans:
- [x] 06-01-PLAN.md -- TDD: Run plan domain model and calculator with unit tests
- [x] 06-02-PLAN.md -- Persistence, providers, UI screen, router integration, and home navigation

### Phase 8: Structured Run Types
**Goal**: Users can plan warm-up/cool-down and interval training runs with per-segment BPM targets
**Plans**: 2/2 complete

Plans:
- [x] 08-01-PLAN.md -- TDD: Calculator factory methods for warm-up/cool-down and interval plans
- [x] 08-02-PLAN.md -- Run type selector UI, type-specific config forms, segment timeline, save logic

*Phases 2, 3, 4, 7, 9, 10 were not started -- superseded by v1.0 milestone pivot.*

</details>

## v1.0 Standalone Playlist Generator

**Milestone Goal:** Deliver the full playlist generation experience without Spotify API dependency. Users open the app, enter their run plan, and get a BPM-matched playlist with external play links -- no Spotify integration required.

**Overview:** This milestone builds the core playlist value on top of the validated v0.1 foundation (stride calculator, run planner, structured run types). Five phases deliver auth cleanup, taste profiling, BPM data discovery, playlist generation, and playlist history. The critical dependency is Phase 14 (playlist generation), which requires both the taste profile (Phase 12) and BPM data pipeline (Phase 13) to be complete. Phases 11-13 have no cross-dependencies and could theoretically execute in parallel, but serial execution (11 -> 12 -> 13) is recommended for simplicity.

**Phase Numbering:**
- Integer phases (11, 12, 13, ...): Planned milestone work
- Decimal phases (12.1, 12.2): Urgent insertions (marked with INSERTED)

- [x] **Phase 11: Auth Cleanup** - Remove Spotify login, establish home hub navigation
- [x] **Phase 12: Taste Profile** - Users can define their running music preferences
- [x] **Phase 13: BPM Data Pipeline** - Discover songs by BPM via GetSongBPM API with caching
- [x] **Phase 14: Playlist Generation** - Users get a BPM-matched playlist for their run
- [ ] **Phase 15: Playlist History** - Users can save, view, and reuse past playlists

## Phase Details

### Phase 11: Auth Cleanup
**Goal**: Users launch the app directly to a home hub with clear navigation to all features -- no Spotify login gate
**Depends on**: Nothing (independent of other v1.0 phases)
**Requirements**: AUTH-10, AUTH-11
**Success Criteria** (what must be TRUE):
  1. App launches directly to home screen without any login prompt or Spotify UI
  2. Home screen shows navigation paths to stride calculator, run planner, taste profile, and playlist generation
  3. All existing v0.1 features (stride calculator, run planner) remain accessible from the new home hub
**Plans**: 1 plan

Plans:
- [x] 11-01-PLAN.md -- Remove Spotify auth UI, build home hub screen with feature navigation

### Phase 12: Taste Profile
**Goal**: Users can describe their running music taste through a questionnaire so the playlist generator knows what music to find
**Depends on**: Nothing (independent of other v1.0 phases)
**Requirements**: TASTE-10, TASTE-11, TASTE-12, TASTE-13
**Success Criteria** (what must be TRUE):
  1. User can select 1-5 preferred running genres from a curated list of 15 genres
  2. User can add up to 10 favorite artists for running music
  3. User can choose an energy level preference (chill, balanced, intense)
  4. User closes the app, reopens it, and sees their saved taste profile unchanged
**Plans**: 2 plans

Plans:
- [x] 12-01-PLAN.md -- Domain model, persistence layer, Riverpod providers, and unit tests
- [x] 12-02-PLAN.md -- UI screen (genre picker, artist input, energy selector) and router integration

### Phase 13: BPM Data Pipeline
**Goal**: The app can discover songs at a target BPM from the GetSongBPM API, cache results locally, and handle half/double-time matching
**Depends on**: Nothing (independent of other v1.0 phases)
**Requirements**: BPM-10, BPM-11, BPM-12, BPM-13
**Success Criteria** (what must be TRUE):
  1. Given a target BPM, the app returns a list of songs at that tempo from the GetSongBPM API
  2. Repeating the same BPM lookup loads results from local cache without making an API call
  3. A query for 170 BPM also returns songs tagged at 85 BPM (half-time match)
  4. When the API is unreachable or returns an error, the user sees a clear error message and the app does not crash
**Plans**: 2 plans

Plans:
- [x] 13-01-PLAN.md -- Domain models (BpmSong, BpmMatcher), API client, http dependency, macOS entitlements, and unit tests
- [x] 13-02-PLAN.md -- BPM cache (SharedPreferences), cache-first lookup notifier, error handling, and provider integration

### Phase 14: Playlist Generation
**Goal**: Users trigger playlist generation from their run plan and receive a complete playlist of BPM-matched songs filtered by their taste profile, with external play links
**Depends on**: Phase 12 (taste profile), Phase 13 (BPM data pipeline)
**Requirements**: PLAY-10, PLAY-11, PLAY-12, PLAY-13, PLAY-14
**Success Criteria** (what must be TRUE):
  1. User triggers generation from a saved run plan and receives a playlist covering the full run duration with BPM-matched songs assigned to each segment
  2. Generated playlist only contains songs matching the user's genre and artist preferences from their taste profile
  3. Each song in the playlist displays title, artist, BPM, and which run segment it belongs to
  4. User can tap any song and it opens in Spotify or YouTube via external link
  5. User can copy the entire playlist as formatted text to their clipboard
**Plans**: 3 plans

Plans:
- [x] 14-01-PLAN.md -- Domain models (Playlist, PlaylistSong, SongLinkBuilder), playlist generation algorithm, and unit tests
- [x] 14-02-PLAN.md -- url_launcher dependency, Android manifest, PlaylistGenerationNotifier with batch BPM fetching, providers, and unit tests
- [x] 14-03-PLAN.md -- PlaylistScreen UI (generation trigger, segment-grouped display, external links, clipboard copy) and router update

### Phase 15: Playlist History
**Goal**: Users can save generated playlists and come back to view or manage them later
**Depends on**: Phase 14 (playlist generation)
**Requirements**: HIST-01, HIST-02, HIST-03
**Success Criteria** (what must be TRUE):
  1. After generating a playlist, user can navigate to a history screen and see it listed with run details (date, distance, pace)
  2. User can tap a past playlist and see all its tracks with title, artist, BPM, and segment info
  3. User can delete a past playlist and it disappears from the history list
**Plans**: 1 plan

Plans:
- [ ] 15-01: Playlist history persistence, list screen, detail view, delete functionality, and router integration

## Progress

**Execution Order:**
Phases execute in order: 11 -> 12 -> 13 -> 14 -> 15
Note: Phases 11, 12, and 13 have no cross-dependencies. Phase 14 requires both 12 and 13. Phase 15 requires 14.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 11. Auth Cleanup | 1/1 | Complete | 2026-02-05 |
| 12. Taste Profile | 2/2 | Complete | 2026-02-05 |
| 13. BPM Data Pipeline | 2/2 | Complete | 2026-02-05 |
| 14. Playlist Generation | 3/3 | Complete | 2026-02-05 |
| 15. Playlist History | 0/1 | Not started | - |
