# Project Research Summary

**Project:** Running Playlist AI
**Domain:** BPM-matched running playlist generator
**Researched:** 2026-02-01
**Confidence:** MEDIUM-HIGH

## Executive Summary

Running Playlist AI is a BPM-matched playlist generator that creates Spotify playlists tailored to a runner's pace and music taste. The product is technically feasible but faces one critical constraint: Spotify deprecated its Audio Features API in November 2024, making BPM data unavailable from Spotify itself. This requires using third-party BPM sources (GetSongBPM API is recommended) and aggressive caching strategies from day one. The project must validate the BPM data pipeline before building anything else.

The recommended technical approach is Flutter (cross-platform web/mobile) with Riverpod state management and Supabase backend. This stack provides the cross-platform reach needed for a web-first experience while keeping backend complexity low. The architecture should follow clean architecture patterns with feature-first organization, heavy caching of BPM data, and a swappable BPM data layer to mitigate provider risk.

Key risks include Spotify's extended access gate (250K MAU requirement for more than 25 users), BPM data source reliability, and the complexity of accurate stride/cadence calculations. Mitigations include early extended access application, designing a pluggable BPM abstraction layer, and building user calibration flows rather than relying on universal biomechanics formulas. The core differentiator is pre-generating complete playlists from run parameters (distance + pace + type) rather than real-time matching, which allows the app to work with any Spotify client and avoids battery drain during runs.

## Key Findings

### Recommended Stack

Flutter 3.38.x with Dart 3.x provides the cross-platform foundation, supporting web, Android, and iOS from a single codebase. Riverpod 3.x is the community consensus for state management in 2026, offering compile-time safety and reactive caching with minimal boilerplate. Supabase provides backend services (auth, PostgreSQL database, edge functions) with transparent pricing and no vendor lock-in, making it superior to Firebase for the relational nature of user-song-playlist data.

**Core technologies:**
- **Flutter 3.38.x**: Cross-platform UI (web, Android, iOS) — latest stable with quarterly release cadence
- **Riverpod 3.x**: State management — community standard for new projects, reactive caching for playlist data
- **Supabase**: Backend (auth, database, storage) — PostgreSQL fits relational data model, row-level security, portable
- **GetSongBPM API**: BPM data source — free with attribution, Spotify audio-features is deprecated
- **spotify (Dart package)**: Spotify Web API client — pure Dart, covers OAuth, playlist CRUD, search, library access
- **go_router**: Navigation — official Flutter team package, deep linking for OAuth redirects

**Critical discovery:** Spotify's audio-features endpoint was deprecated November 27, 2024. New apps get 403 errors. BPM data must come from external sources like GetSongBPM, Soundcharts, or community datasets (MusicBrainz/AcousticBrainz).

### Expected Features

**Must have (table stakes):**
- BPM-to-cadence matching — core value proposition of every app in this space
- Pace/cadence input — both manual BPM entry and calculated from pace
- Genre/taste preferences — filter generated playlists by user's music taste
- Playlist export to Spotify — users expect to play via Spotify, not a custom player
- Warm-up/cool-down support — playlist segments with ascending/descending BPM
- Multiple run types — steady pace, intervals, progressive runs
- Cross-platform access — web + mobile baseline expectation

**Should have (competitive differentiators):**
- Run-detail-driven generation — distance + pace + type produces complete structured playlist (unique to this app)
- Taste profile from Spotify import + manual tuning — combines listening history analysis with running-specific preferences
- Stride rate calculation from pace — removes friction of users needing to know their cadence
- BPM range tolerance with half/double tempo — 170 BPM target can use 85 BPM songs, dramatically expands pool
- Pre-run playlist generation — generate before the run, works with any Spotify client/watch, no battery drain

**Defer (v2+):**
- Interval training with BPM-matched segments — high complexity, requires mapping interval structure to song durations
- Advanced taste tuning — manual refinement of taste profile (start with Spotify-derived data first)
- Heart rate integration — adds complexity without proportional value for playlist generation
- GPS run tracking — Strava/Nike Run Club already do this well, don't rebuild
- Real-time cadence detection — requires foreground app, accelerometer, battery drain

### Architecture Approach

Feature-first clean architecture with Riverpod for dependency injection and state management. Three-layer separation (Data/Domain/Presentation) per feature module. The BPM data pipeline must be designed as a swappable abstraction from day one since external providers may change terms or disappear. Heavy caching is essential to avoid hitting rate limits and to enable fast playlist generation.

**Major components:**
1. **Auth Module** — Spotify OAuth PKCE flow, token refresh, session management
2. **Spotify Client** — User library, saved tracks, playlist CRUD, search API calls
3. **BPM Data Service** — Fetch from GetSongBPM, cache aggressively in Supabase, resolve Spotify ID to BPM
4. **Stride Calculator** — Compute target cadence from height, pace, optional user calibration
5. **Run Plan Engine** — Define run structure (steady, warm-up/cool-down, intervals) with BPM targets per segment
6. **Taste Profile** — Aggregate genre/artist preferences from Spotify top tracks + manual overrides
7. **Playlist Generator** — Core algorithm: match songs to segments by BPM + taste score, assemble ordered playlist

**Key patterns:**
- Cache-first BPM enrichment: pre-fetch BPM for user's library in background, generate from cache only
- Half/double-time matching: check BPM, BPM/2, and BPM*2 when matching to expand candidate pool
- Pluggable BPM source abstraction: design data layer to swap providers without rewriting business logic

### Critical Pitfalls

1. **Spotify Audio Features API deprecated** — Returns 403 for new apps since Nov 2024. No BPM data from Spotify. Must use GetSongBPM or alternative from day one. Design BPM layer as swappable abstraction. **Phase 1 blocker.**

2. **Spotify Extended Access gate** — 250K MAU + registered business required for extended access. Apps stuck at 25 users in development mode. Apply early with pitch about driving artist discovery. Have Apple Music fallback plan. **Shapes entire project timeline.**

3. **OAuth flow migration** — Implicit grant removed Nov 2025. Must use Authorization Code with PKCE. HTTPS redirect URIs only (except 127.0.0.1 for dev). Test all three platforms early. **Phase 1 auth setup must get this right.**

4. **BPM half/double-time confusion** — 140 BPM track can be reported as 70 or 280 BPM. Runner at 170 spm matched to 85 BPM ballads ruins experience. Always check x2 and /2 candidates, filter to sane range (100-210 BPM). **Phase 2 matching logic.**

5. **Stride calculation assumes universal constants** — Fixed formulas (stride = height * 0.415) are wildly inaccurate for individuals. Speed = stride_length * cadence, but relationship is individual. Build calibration flow, offer presets, let users override. **Phase 2 cadence logic.**

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Foundation & BPM Validation
**Rationale:** The BPM data source is an existential dependency. Nothing else matters if BPM data is unavailable or unreliable. Spotify OAuth is a hard prerequisite for all features. These must be validated before building business logic.

**Delivers:**
- Spotify OAuth with PKCE (all three platforms: web, Android, iOS)
- GetSongBPM API integration and validation
- BPM cache layer in Supabase
- Project skeleton (Flutter, Riverpod, clean architecture, routing)
- Local storage setup (secure token storage)

**Addresses:**
- Table stakes: Spotify integration foundation
- Critical pitfall: Validate BPM data source works before proceeding
- Critical pitfall: OAuth PKCE flow, not deprecated implicit grant
- Extended access: Apply for Spotify extended access immediately

**Avoids:**
- Building on deprecated Spotify audio-features API
- Using implicit grant OAuth flow
- Proceeding without confirming BPM data availability

### Phase 2: Data Pipeline & Core Engine
**Rationale:** Once BPM data is confirmed available, build the data pipeline that feeds playlist generation. Background BPM enrichment needs time to populate cache. Stride calculation and run planning are independent of Spotify but must exist before generation.

**Delivers:**
- Spotify library import (saved tracks, top tracks)
- Background BPM enrichment for user's library
- Stride calculator with user calibration flow
- Run plan engine (steady pace, warm-up/cool-down structures)
- Taste profile from Spotify listening data

**Uses:**
- Supabase for BPM cache and user data
- GetSongBPM API with aggressive caching
- Pure Dart biomechanics formulas

**Implements:**
- BPM Data Service component (cache-first architecture)
- Stride Calculator component (with calibration, not just formulas)
- Run Plan Engine component (segment-based BPM targets)

**Avoids:**
- Synchronous BPM fetching during generation (use background enrichment)
- Universal stride formulas (build calibration)
- Exact BPM matching only (plan for tolerance window)

### Phase 3: Playlist Generation & Export
**Rationale:** With BPM data cached and run plans defined, build the core value proposition: generate BPM-matched playlists and push to Spotify.

**Delivers:**
- Playlist generation algorithm (BPM matching + taste scoring)
- Half/double-time tempo matching
- Spotify playlist creation and track addition
- Generate flow UI (run input -> playlist output)
- Playlist preview before export

**Addresses:**
- Table stakes: BPM-to-cadence matching, playlist export to Spotify
- Differentiator: Run-detail-driven generation (distance + pace + type)
- Differentiator: Pre-run playlist generation (not real-time)

**Implements:**
- Playlist Generator component
- Taste scoring integration
- BPM tolerance and half/double-time logic

**Avoids:**
- Exact BPM matching (use tolerance window)
- Half/double-time confusion (explicit handling in algorithm)

### Phase 4: Polish & Multiple Run Types
**Rationale:** Core steady-pace generation working. Add structured workout types and UX refinements.

**Delivers:**
- Warm-up/cool-down BPM ramps
- Multiple run type support (steady, progressive)
- Playlist regeneration and history
- Advanced taste tuning UI

**Addresses:**
- Table stakes: Warm-up/cool-down support, multiple run types
- Differentiator: Taste profile manual tuning

### Phase 5 (Future): Interval Training
**Rationale:** High complexity feature requiring segment-based generation with distinct BPM targets and song duration matching per interval. Defer until core product validated.

**Delivers:**
- Interval training support with BPM-matched segments
- Interval structure definition UI

**Addresses:**
- Table stakes: Interval training (expected but complex)

### Phase Ordering Rationale

- **Phase 1 first:** BPM data availability is existential risk. Must validate before building anything else. OAuth is hard prerequisite for all Spotify features.
- **Phase 2 before 3:** Playlist generation depends on cached BPM data, taste profile, and run planning. Background enrichment needs time to run.
- **Stride calculation in Phase 2:** Independent of Spotify, but must exist before generation. Include calibration to avoid universal formula pitfall.
- **Warm-up/cool-down in Phase 4:** Natural extension of steady pace, but requires working generation first.
- **Intervals last:** Highest complexity, requires segment-duration matching, defer until product validated.

### Research Flags

**Phases likely needing deeper research during planning:**
- **Phase 1:** BPM data source evaluation — GetSongBPM may have coverage gaps, rate limits unclear, need fallback strategy
- **Phase 2:** Stride/cadence formulas — biomechanics research needed for accurate calibration defaults
- **Phase 5:** Interval training — segment-duration matching algorithm needs investigation

**Phases with standard patterns (skip research-phase):**
- **Phase 1:** Spotify OAuth with PKCE — well-documented, official guides available
- **Phase 1:** Flutter project setup — established clean architecture patterns
- **Phase 3:** Spotify playlist creation — standard Web API calls, well-documented

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Flutter 3.38 is latest stable, Riverpod 3.x is community consensus 2026, Supabase is well-proven. Versions and rationale verified. |
| Features | MEDIUM | Based on competitor analysis (RockMyRun, PaceDJ, Weav) but not direct user research. Table stakes clearly identified. |
| Architecture | MEDIUM | Clean architecture + Riverpod is standard Flutter approach, but BPM caching strategy inferred from rate limit constraints, not battle-tested. |
| Pitfalls | HIGH | Spotify API deprecation verified across multiple authoritative sources. OAuth changes confirmed via official Spotify blog. BPM half/double-time issue well-documented in MIR literature. |

**Overall confidence:** MEDIUM-HIGH

The critical Spotify API constraints are verified with HIGH confidence (official sources). Stack choices are verified (official docs, pub.dev). Feature landscape is MEDIUM confidence (inferred from competitors, not user interviews). Architecture patterns are standard but BPM caching strategy needs validation at scale.

### Gaps to Address

- **GetSongBPM API reliability at scale:** Unknown rate limits, uptime SLA, coverage completeness. Needs validation in Phase 1 with real user libraries. Have fallback plan (Soundcharts, MusicBrainz).
- **Spotify extended access approval likelihood:** Unclear how Spotify evaluates applications. Apply early, but have contingency for 25-user cap (Apple Music integration, playlist export as text lists).
- **BPM data coverage for non-popular tracks:** Alternative sources may have gaps for niche genres. Monitor cache hit rate, surface "BPM unavailable" gracefully to users.
- **Accurate stride calculation defaults:** Biomechanics formulas are population averages. User calibration is essential, but need good defaults. Test with diverse runner profiles in Phase 2.
- **Flutter Web performance:** Initial load time and bundle size unknown until first build. May need to de-prioritize web for v1 if performance unacceptable. Measure baseline in Phase 1.

## Sources

### Primary (HIGH confidence)
- [Flutter 3.38 release notes](https://docs.flutter.dev/release/release-notes) — Stack verification
- [Riverpod 3.0 What's New](https://riverpod.dev/docs/whats_new) — State management features
- [Spotify Web API Changes (Nov 2024)](https://developer.spotify.com/blog/2024-11-27-changes-to-the-web-api) — Audio Features deprecation
- [Spotify OAuth Migration (Nov 2025)](https://developer.spotify.com/blog/2025-10-14-reminder-oauth-migration-27-nov-2025) — Implicit grant removal
- [Spotify Extended Access Criteria Update (Apr 2025)](https://developer.spotify.com/blog/2025-04-15-updating-the-criteria-for-web-api-extended-access) — 250K MAU requirement
- [Spotify community: Audio Features 403 errors](https://community.spotify.com/t5/Spotify-for-Developers/Web-API-Get-Track-s-Audio-Features-403-error/td-p/6654507) — Deprecation confirmation
- [Flutter architecture guide](https://docs.flutter.dev/app-architecture/guide) — Architecture patterns

### Secondary (MEDIUM confidence)
- [GetSongBPM API](https://getsongbpm.com/api) — BPM data alternative
- [Supabase vs Firebase comparison](https://www.clickittech.com/software-development/supabase-vs-firebase/) — Backend choice rationale
- [RockMyRun](https://www.rockmyrun.com/), [PaceDJ](https://www.pacedj.com/faq/), [Weav](https://www.producthunt.com/products/weav-run) — Competitor feature analysis
- [Running cadence science](https://runningwritings.com/2026/01/science-of-cadence.html) — Stride calculation research
- [Molab cadence guide](https://molab.me/running-cadence-the-ultimate-guide/) — Biomechanics formulas
- [TechCrunch Spotify API coverage](https://techcrunch.com/2024/11/27/spotify-cuts-developer-access-to-several-of-its-recommendation-features/) — Deprecation context

### Tertiary (LOW confidence)
- [SoundNet Track Analysis API](https://medium.com/@soundnet717/spotify-audio-analysis-has-been-deprecated-what-now-4808aadccfcb) — Alternative BPM source, single source
- [Flutter Web performance critique](https://suica.dev/en/blogs/fuck-off-flutter-web,-unless-you-slept-through-school,-you-know-flutter-web-is-a-bad-idea) — Opinionated take, needs validation

---
*Research completed: 2026-02-01*
*Ready for roadmap: yes*
