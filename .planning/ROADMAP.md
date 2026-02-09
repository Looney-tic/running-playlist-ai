# Roadmap: Running Playlist AI

## Milestones

- **v0.1 Foundation** - Phases 1-10 (shipped 2026-02-05)
- **v1.0 Standalone Playlist Generator** - Phases 11-15 (shipped 2026-02-05)
- **v1.1 Experience Quality** - Phases 16-18 (shipped 2026-02-06)
- **v1.2 Polish & Profiles** - Phases 19-21 (shipped 2026-02-06)
- **v1.3 Song Feedback & Freshness** - Phases 22-27 (shipped 2026-02-08)
- **v1.4 Smart Song Search & Spotify Foundation** - Phases 28-33 (in progress)

## Phases

<details>
<summary>v0.1 Foundation (Phases 1-10) - SHIPPED 2026-02-05</summary>

See: `.planning/milestones/v0.1-ROADMAP.md` for full details.

- [x] Phase 1: Project Foundation (2/2 plans)
- [x] Phase 5: Stride & Cadence (2/2 plans)
- [x] Phase 6: Steady Run Planning (2/2 plans)
- [x] Phase 8: Structured Run Types (2/2 plans)

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

<details>
<summary>v1.3 Song Feedback & Freshness (Phases 22-27) - SHIPPED 2026-02-08</summary>

See: `.planning/milestones/v1.3-ROADMAP.md` for full details.

- [x] Phase 22: Feedback Data Layer (2/2 plans)
- [x] Phase 23: Feedback UI & Scoring (2/2 plans)
- [x] Phase 24: Feedback Library (1/1 plans)
- [x] Phase 25: Freshness (2/2 plans)
- [x] Phase 26: Post-Run Review (1/1 plans)
- [x] Phase 27: Taste Learning (2/2 plans)

</details>

### v1.4 Smart Song Search & Spotify Foundation (In Progress)

**Milestone Goal:** Let users search for and select songs they run to, feeding those selections into taste learning and scoring. Lay the Spotify API foundation so playlist import slots in when credentials become available.

- [x] **Phase 28: "Songs I Run To" Data Layer** - User-curated running songs with persistence and list management
- [ ] **Phase 29: Scoring & Taste Integration** - Running songs boost playlist generation and feed taste learning
- [ ] **Phase 30: Local Song Search** - Typeahead autocomplete against curated catalog with search abstraction
- [ ] **Phase 31: Spotify Auth Foundation** - OAuth PKCE flow with secure token lifecycle management
- [ ] **Phase 32: Spotify Search** - Spotify catalog search extending local results with dual-source UI
- [ ] **Phase 33: Spotify Playlist Import** - Browse Spotify playlists and import songs to "Songs I Run To"

## Phase Details

### Phase 28: "Songs I Run To" Data Layer
**Goal**: Users can build and manage a personal collection of songs they love running to
**Depends on**: Nothing (first phase of v1.4)
**Requirements**: SONGS-01, SONGS-02
**Success Criteria** (what must be TRUE):
  1. User can add a song to their "Songs I Run To" list and it persists across app restarts
  2. User can view all songs in their "Songs I Run To" list
  3. User can remove a song from "Songs I Run To" and it disappears immediately
  4. When the list is empty, user sees guidance on how to add songs
**Plans**: 2 plans

Plans:
- [x] 28-01: RunningSong domain model, persistence, provider, and tests
- [x] 28-02: Running songs screen, SongTile add action, route, and home navigation

### Phase 29: Scoring & Taste Integration
**Goal**: Songs in "Songs I Run To" actively improve playlist quality and teach the system user preferences
**Depends on**: Phase 28
**Requirements**: SONGS-03, SONGS-04, SONGS-05
**Success Criteria** (what must be TRUE):
  1. After adding songs to "Songs I Run To", the next generated playlist ranks those songs higher
  2. Genre and artist patterns from running songs appear as taste suggestions on the home screen
  3. Each song in "Songs I Run To" shows a BPM compatibility indicator (green/amber/gray) relative to the user's current cadence target
**Plans**: 2 plans

Plans:
- [ ] 29-01: Scoring boost and taste learning integration for running songs
- [ ] 29-02: BPM compatibility indicator on running song cards (TDD)

### Phase 30: Local Song Search
**Goal**: Users can quickly find any song in the curated catalog through instant typeahead search
**Depends on**: Phase 28 (search results feed into "Songs I Run To")
**Requirements**: SEARCH-01, SEARCH-02, SEARCH-03
**Success Criteria** (what must be TRUE):
  1. User types 2+ characters and sees matching songs within 300ms, updating as they type
  2. Matching characters in song title and artist name are visually highlighted in results
  3. User can tap a search result to add it to "Songs I Run To"
  4. Search service uses an abstract interface that can be extended with additional backends without changing UI
**Plans**: TBD

Plans:
- [ ] 30-01: TBD
- [ ] 30-02: TBD

### Phase 31: Spotify Auth Foundation
**Goal**: App can authenticate with Spotify and maintain valid tokens for API access
**Depends on**: Nothing (independent of Phases 28-30)
**Requirements**: SPOTIFY-01, SPOTIFY-02
**Success Criteria** (what must be TRUE):
  1. User can initiate Spotify connection and complete OAuth PKCE authorization flow
  2. OAuth tokens are stored securely (not in SharedPreferences/localStorage)
  3. Expired tokens are refreshed automatically before API calls, without user intervention
  4. When Spotify is unavailable or tokens cannot be refreshed, the app continues working with local-only features
**Plans**: TBD

Plans:
- [ ] 31-01: TBD
- [ ] 31-02: TBD

### Phase 32: Spotify Search
**Goal**: Users with Spotify connected can search beyond the curated catalog, finding any song on Spotify
**Depends on**: Phase 30 (search abstraction), Phase 31 (Spotify auth)
**Requirements**: SPOTIFY-03
**Success Criteria** (what must be TRUE):
  1. When Spotify is connected, search results show both local and Spotify songs with source badges
  2. Spotify search results can be added to "Songs I Run To" just like local results
  3. When Spotify is not connected, search works normally with curated catalog only (no errors)
**Plans**: TBD

Plans:
- [ ] 32-01: TBD

### Phase 33: Spotify Playlist Import
**Goal**: Users can browse their Spotify playlists and import running-relevant songs into the app
**Depends on**: Phase 28 ("Songs I Run To" as import destination), Phase 31 (Spotify auth)
**Requirements**: SPOTIFY-04, SPOTIFY-05
**Success Criteria** (what must be TRUE):
  1. User can see a list of their Spotify playlists when connected
  2. User can open a playlist and see its tracks with selection controls
  3. User can select songs from a Spotify playlist and import them into "Songs I Run To"
  4. Imported songs are available for scoring, taste learning, and BPM indicators just like manually added songs
**Plans**: TBD

Plans:
- [ ] 33-01: TBD
- [ ] 33-02: TBD

## Progress

**Execution Order:**
Phases 28-30 execute sequentially (data layer -> integration -> search).
Phases 31 can start independently. Phases 32-33 depend on both tracks.

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
| 26. Post-Run Review | v1.3 | 1/1 | Complete | 2026-02-08 |
| 27. Taste Learning | v1.3 | 2/2 | Complete | 2026-02-08 |
| 28. "Songs I Run To" Data Layer | v1.4 | 2/2 | Complete | 2026-02-09 |
| 29. Scoring & Taste Integration | v1.4 | 0/2 | Not started | - |
| 30. Local Song Search | v1.4 | 0/2 | Not started | - |
| 31. Spotify Auth Foundation | v1.4 | 0/2 | Not started | - |
| 32. Spotify Search | v1.4 | 0/1 | Not started | - |
| 33. Spotify Playlist Import | v1.4 | 0/2 | Not started | - |
