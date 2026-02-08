# Roadmap: Running Playlist AI

## Milestones

- **v0.1 Foundation** - Phases 1-10 (shipped 2026-02-05)
- **v1.0 Standalone Playlist Generator** - Phases 11-15 (shipped 2026-02-05)
- **v1.1 Experience Quality** - Phases 16-18 (shipped 2026-02-06)
- **v1.2 Polish & Profiles** - Phases 19-21 (shipped 2026-02-06)
- **v1.3 Song Feedback & Freshness** - Phases 22-27 (in progress)

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

<details>
<summary>v1.0 Standalone Playlist Generator (Phases 11-15) - SHIPPED 2026-02-05</summary>

See: `.planning/milestones/v1.0-ROADMAP.md` for full details.

- [x] Phase 11: Auth Cleanup (1/1 plans)
- [x] Phase 12: Taste Profile (2/2 plans)
- [x] Phase 13: BPM Data Pipeline (2/2 plans)
- [x] Phase 14: Playlist Generation (3/3 plans)
- [x] Phase 15: Playlist History (2/2 plans)

</details>

<details>
<summary>v1.1 Experience Quality (Phases 16-18) - SHIPPED 2026-02-06</summary>

See: `.planning/milestones/v1.1-ROADMAP.md` for full details.

- [x] Phase 16: Scoring Foundation (2/2 plans)
- [x] Phase 17: Curated Running Songs (2/2 plans)
- [x] Phase 18: UX Refinements (2/2 plans)

</details>

<details>
<summary>v1.2 Polish & Profiles (Phases 19-21) - SHIPPED 2026-02-06</summary>

See: `.planning/milestones/v1.2-ROADMAP.md` for full details.

- [x] Phase 19: Regeneration Reliability (2/2 plans)
- [x] Phase 20: Profile Polish (2/2 plans)
- [x] Phase 21: Onboarding (2/2 plans)

</details>

### v1.3 Song Feedback & Freshness (In Progress)

**Milestone Goal:** Let users teach the app their taste through song feedback, and choose between fresh variety or taste-optimized playlists.

- [x] **Phase 22: Feedback Data Layer** - Persistence and state management for song feedback
- [x] **Phase 23: Feedback UI & Scoring** - Like/dislike buttons in playlist view with scoring integration
- [x] **Phase 24: Feedback Library** - Dedicated screen to browse and edit all song feedback
- [x] **Phase 25: Freshness** - Track song recency and let users toggle fresh vs taste-optimized playlists
- [ ] **Phase 26: Post-Run Review** - Rate songs from the most recent playlist after a run
- [ ] **Phase 27: Taste Learning** - Analyze feedback patterns and surface preference suggestions

## Phase Details

### Phase 22: Feedback Data Layer
**Goal**: Song feedback can be stored, retrieved, and persisted so all downstream features have a reliable data foundation
**Depends on**: Nothing (first phase of v1.3)
**Requirements**: FEED-02
**Success Criteria** (what must be TRUE):
  1. SongFeedback entries (liked/disliked with metadata) survive app restart without data loss
  2. Feedback lookup by song key returns the correct state in constant time
  3. Song key normalization produces identical keys for the same song across curated data and API results
**Plans**: 2 plans

Plans:
- [x] 22-01-PLAN.md -- SongKey utility, SongFeedback model, SongFeedbackPreferences, lookupKey centralization
- [x] 22-02-PLAN.md -- SongFeedbackNotifier provider and full test suite

### Phase 23: Feedback UI & Scoring
**Goal**: Users can like or dislike songs in the playlist view, and feedback directly influences which songs appear in future playlists
**Depends on**: Phase 22
**Requirements**: FEED-01, FEED-03, FEED-04
**Success Criteria** (what must be TRUE):
  1. User can tap a like or dislike icon on any song in the generated playlist view and see immediate visual confirmation
  2. Disliked songs never appear in subsequently generated playlists
  3. Liked songs rank noticeably higher than equivalent unrated songs in generated playlists
  4. A liked song with poor running metrics does not outrank an unrated song with excellent running metrics
**Plans**: 2 plans

Plans:
- [x] 23-01-PLAN.md — TDD: Liked-song scoring boost, disliked hard-filter, PlaylistSong.lookupKey, provider wiring
- [x] 23-02-PLAN.md — SongTile feedback icons as ConsumerWidget with reactive visual state

### Phase 24: Feedback Library
**Goal**: Users can review all their song feedback decisions in one place and change their mind on any rating
**Depends on**: Phase 23
**Requirements**: FEED-05, FEED-06
**Success Criteria** (what must be TRUE):
  1. User can navigate to a feedback library screen showing all liked songs and all disliked songs in separate views
  2. User can change a liked song to disliked, disliked to liked, or remove feedback entirely from the library screen
  3. Changes made in the feedback library take effect in the next playlist generation
**Plans**: 1 plan

Plans:
- [x] 24-01-PLAN.md -- Feedback library screen with tabbed liked/disliked views, flip/remove actions, router + home nav

### Phase 25: Freshness
**Goal**: Users can choose between varied playlists that avoid recent repeats or taste-optimized playlists that favor proven songs
**Depends on**: Phase 23
**Requirements**: FRSH-01, FRSH-02, FRSH-03
**Success Criteria** (what must be TRUE):
  1. After generating a playlist, the app records which songs were included and when
  2. In "keep it fresh" mode, songs from a playlist generated yesterday rank lower than songs not played recently
  3. User can toggle between "keep it fresh" and "optimize for taste" modes, and the toggle persists across app restarts
  4. In "optimize for taste" mode, recently played songs receive no freshness penalty
**Plans**: 2 plans

Plans:
- [x] 25-01-PLAN.md -- TDD: PlayHistory domain model, freshness penalty scoring, FreshnessMode enum, persistence, providers
- [x] 25-02-PLAN.md -- Wire freshnessPenalty into scorer + generator + all 3 generation paths + UI toggle

### Phase 26: Post-Run Review
**Goal**: Users can rate all songs from their most recent playlist in a single review flow after a run
**Depends on**: Phase 23
**Requirements**: FEED-07
**Success Criteria** (what must be TRUE):
  1. When an unreviewed recent playlist exists, the home screen shows a prompt to rate the last playlist
  2. User can like or dislike each song from their last playlist in a dedicated review screen
  3. The review prompt disappears after the user completes or dismisses the review
  4. Feedback given during post-run review appears in the feedback library and affects future generation
**Plans**: TBD

Plans:
- [ ] 26-01: TBD

### Phase 27: Taste Learning
**Goal**: The app discovers implicit taste patterns from feedback and surfaces actionable suggestions the user can accept or ignore
**Depends on**: Phase 25 (freshness must exist before taste learning to prevent filter bubbles)
**Requirements**: LRNG-01, LRNG-02, LRNG-03
**Success Criteria** (what must be TRUE):
  1. After accumulating enough feedback, the app identifies genre, artist, or BPM patterns in liked vs disliked songs
  2. Discovered patterns appear as suggestion cards the user can accept or dismiss (never auto-applied to taste profile)
  3. Accepting a suggestion updates the user's active taste profile and is reflected in the next playlist generation
  4. Dismissed suggestions do not reappear until new feedback data changes the pattern
**Plans**: TBD

Plans:
- [ ] 27-01: TBD
- [ ] 27-02: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 22 -> 23 -> 24 -> 25 -> 26 -> 27
(Phases 24, 25, 26 are independent after 23 -- order is recommended, not strict)

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation | v0.1 | 2/2 | Complete | 2026-02-05 |
| 5. Stride | v0.1 | 2/2 | Complete | 2026-02-05 |
| 6. Steady Run | v0.1 | 2/2 | Complete | 2026-02-05 |
| 8. Structured Runs | v0.1 | 2/2 | Complete | 2026-02-05 |
| 11. Auth Cleanup | v1.0 | 1/1 | Complete | 2026-02-05 |
| 12. Taste Profile | v1.0 | 2/2 | Complete | 2026-02-05 |
| 13. BPM Pipeline | v1.0 | 2/2 | Complete | 2026-02-05 |
| 14. Playlist Gen | v1.0 | 3/3 | Complete | 2026-02-05 |
| 15. History | v1.0 | 2/2 | Complete | 2026-02-05 |
| 16. Scoring Foundation | v1.1 | 2/2 | Complete | 2026-02-05 |
| 17. Curated Songs | v1.1 | 2/2 | Complete | 2026-02-06 |
| 18. UX Refinements | v1.1 | 2/2 | Complete | 2026-02-06 |
| 19. Regeneration Reliability | v1.2 | 2/2 | Complete | 2026-02-06 |
| 20. Profile Polish | v1.2 | 2/2 | Complete | 2026-02-06 |
| 21. Onboarding | v1.2 | 2/2 | Complete | 2026-02-06 |
| 22. Feedback Data Layer | v1.3 | 2/2 | Complete | 2026-02-08 |
| 23. Feedback UI & Scoring | v1.3 | 2/2 | Complete | 2026-02-08 |
| 24. Feedback Library | v1.3 | 1/1 | Complete | 2026-02-08 |
| 25. Freshness | v1.3 | 2/2 | Complete | 2026-02-08 |
| 26. Post-Run Review | v1.3 | 0/1 | Not started | - |
| 27. Taste Learning | v1.3 | 0/2 | Not started | - |
