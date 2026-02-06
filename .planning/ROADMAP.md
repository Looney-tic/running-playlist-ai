# Roadmap: Running Playlist AI

## Milestones

- **v0.1 Foundation** - Phases 1-10 (shipped 2026-02-05)
- **v1.0 Standalone Playlist Generator** - Phases 11-15 (shipped 2026-02-05)
- **v1.1 Experience Quality** - Phases 16-18 (shipped 2026-02-06)
- **v1.2 Polish & Profiles** - Phases 19-21 (in progress)

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

- [x] Phase 16: Scoring Foundation (2/2 plans)
- [x] Phase 17: Curated Running Songs (2/2 plans)
- [x] Phase 18: UX Refinements (2/2 plans)

</details>

### v1.2 Polish & Profiles (In Progress)

**Milestone Goal:** Make the app feel complete for daily use -- multiple taste profiles for different run types, reliable regeneration, and a guided first-run experience.

- [ ] **Phase 19: Regeneration Reliability** - Shuffle/regenerate works instantly and reliably across cold starts and input changes
- [ ] **Phase 20: Profile Polish** - Multi-profile flows are hardened with confirmation dialogs, safe deserialization, and test coverage
- [ ] **Phase 21: Onboarding** - New users are guided from first launch to first playlist in under 60 seconds

## Phase Details

### Phase 19: Regeneration Reliability
**Goal**: Users can shuffle and regenerate playlists instantly and reliably -- no crashes on cold start, no stale inputs after switching plans or profiles
**Depends on**: Phase 18 (existing playlist generation and one-tap regeneration)
**Requirements**: REGEN-01, REGEN-02, REGEN-03
**Success Criteria** (what must be TRUE):
  1. User can tap "shuffle" on a generated playlist and get a different song order instantly without a loading spinner or API call
  2. User can close the app completely, reopen it, and tap "generate" from the home screen without seeing a null-state error or crash
  3. User can switch their selected run plan or taste profile and the next generated playlist reflects the updated selection -- not a stale cached version
**Plans**: 2 plans

Plans:
- [ ] 19-01-PLAN.md -- Readiness guards on library notifiers and instant shufflePlaylist() method
- [ ] 19-02-PLAN.md -- Wire playlist screen UI to shufflePlaylist() and add Generate button

### Phase 20: Profile Polish
**Goal**: Multi-profile management is safe and verified -- destructive actions require confirmation, corrupt data degrades gracefully, and the full create/edit/delete/switch lifecycle is tested
**Depends on**: Phase 19 (regeneration must work for profile-switch-then-generate flow)
**Requirements**: PROF-01, PROF-02, PROF-03
**Success Criteria** (what must be TRUE):
  1. User sees a confirmation dialog before a taste profile is permanently deleted -- accidental taps do not destroy data
  2. App loads without crash even if stored taste profile JSON contains unknown enum values from a future or older app version
  3. User can create a new profile, edit it, select it, delete a different profile, and switch back -- all persisted correctly across app restart
**Plans**: TBD

Plans:
- [ ] 20-01: TBD
- [ ] 20-02: TBD

### Phase 21: Onboarding
**Goal**: First-time users are guided through creating their first run plan and taste profile, arriving at a generated playlist without needing to discover the app's workflow themselves
**Depends on**: Phase 20 (onboarding creates profiles and plans -- those flows must be reliable)
**Requirements**: ONBD-01, ONBD-02, ONBD-03
**Success Criteria** (what must be TRUE):
  1. A brand-new user (no stored data) sees a guided onboarding flow on first launch -- not the regular home screen
  2. User can skip any onboarding step and still reach playlist generation with sensible defaults filled in
  3. After completing onboarding, the home screen shows the user's configured profile and run plan -- not an empty state prompt
  4. A returning user who has already completed onboarding never sees the onboarding flow again
**Plans**: TBD

Plans:
- [ ] 21-01: TBD
- [ ] 21-02: TBD

## Progress

**Execution Order:** Phase 19 -> 20 -> 21

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
| 19. Regeneration Reliability | v1.2 | 0/2 | Planned | - |
| 20. Profile Polish | v1.2 | 0/2 | Not started | - |
| 21. Onboarding | v1.2 | 0/2 | Not started | - |
