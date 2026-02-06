# Roadmap: Running Playlist AI

## Milestones

- **v0.1 Foundation** - Phases 1-10 (shipped 2026-02-05)
- **v1.0 Standalone Playlist Generator** - Phases 11-15 (shipped 2026-02-05)
- **v1.1 Experience Quality** - Phases 16-18 (in progress)

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

### v1.1 Experience Quality (In Progress)

**Milestone Goal:** Make generated playlists genuinely great for running -- not just BPM-matched, but songs that are proven good running songs, matched to the user's taste, with frictionless stride adjustment and repeat generation.

- [x] **Phase 16: Scoring Foundation** - Composite quality scoring using danceability, genre, energy, and artist diversity
- [x] **Phase 17: Curated Running Songs** - Bundled dataset of verified running songs with remote update capability
- [ ] **Phase 18: UX Refinements** - Cadence nudge, one-tap regeneration, quality indicators, and extended taste preferences

#### Phase 16: Scoring Foundation
**Goal**: Generated playlists rank songs by running suitability -- not just BPM proximity -- using danceability, genre match, energy alignment, and artist diversity
**Depends on**: Phase 15 (existing playlist generation pipeline)
**Requirements**: QUAL-01, QUAL-02, QUAL-03, QUAL-04, QUAL-05, QUAL-06
**Success Criteria** (what must be TRUE):
  1. Generated playlist contains songs scored by a composite of runnability, taste match, and BPM accuracy -- not BPM alone
  2. Songs with high danceability rank higher than low-danceability songs at the same BPM
  3. No two consecutive songs in a generated playlist are by the same artist
  4. Warm-up segments contain lower-energy songs and sprint segments contain higher-energy songs without manual user intervention
  5. A user with "chill" energy preference gets noticeably different song rankings than a user with "intense" preference
**Plans**: 2 plans

Plans:
- [x] 16-01-PLAN.md -- TDD: SongQualityScorer with composite scoring (danceability, energy, genre, artist diversity, BPM)
- [x] 16-02-PLAN.md -- Integration: wire scorer into PlaylistGenerator, extend BpmSong/PlaylistSong models

#### Phase 17: Curated Running Songs
**Goal**: App includes a curated dataset of verified-good running songs that boosts playlist quality while still including non-curated discoveries
**Depends on**: Phase 16 (scoring algorithm must exist for curated bonus to integrate)
**Requirements**: CURA-01, CURA-02, CURA-03, CURA-04
**Success Criteria** (what must be TRUE):
  1. Generated playlists include curated songs when they match the user's BPM and taste -- and these appear higher in the ranking than equivalent non-curated songs
  2. Non-curated songs still appear in playlists (curated data is a boost, not a filter)
  3. Curated dataset covers all genres available in the taste profile picker
  4. Curated song data can be refreshed from Supabase without an app store release
**Plans**: 2 plans

Plans:
- [x] 17-01-PLAN.md -- TDD: CuratedSong model, curated bonus in SongQualityScorer, curatedLookupKeys in PlaylistGenerator
- [x] 17-02-PLAN.md -- Curated dataset JSON (300 songs), CuratedSongRepository, provider wiring into playlist generation

#### Phase 18: UX Refinements
**Goal**: Returning users can regenerate playlists with minimal friction, fine-tune their cadence after real runs, and see which songs are highest quality at a glance
**Depends on**: Phase 17 (quality indicators require quality data; full value requires scoring + curated foundation)
**Requirements**: UX-01, UX-02, UX-03, UX-04
**Success Criteria** (what must be TRUE):
  1. User can tap +/- buttons to nudge cadence by 2-3 BPM from the playlist screen or home screen without navigating to stride calculator
  2. Returning user can generate a new playlist for their last run configuration with a single tap from the home screen
  3. Songs with high runnability or curated status show a visible quality indicator (badge or icon) in the playlist UI
  4. User can set vocal preference, tempo variance tolerance, and disliked artists in the taste profile -- and these preferences affect generated playlists
**Plans**: TBD

Plans:
- [ ] 18-01: TBD
- [ ] 18-02: TBD

## Progress

**Execution Order:** Phase 16 -> 17 -> 18

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
| 18. UX Refinements | v1.1 | 0/? | Not started | - |
