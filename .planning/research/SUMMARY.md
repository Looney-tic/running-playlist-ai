# Project Research Summary

**Project:** Running Playlist AI
**Milestone:** v1.1 Experience Quality
**Domain:** Running music playlist generation with song quality scoring
**Researched:** 2026-02-05
**Confidence:** MEDIUM-HIGH

## Executive Summary

Running Playlist AI v1.1 focuses on improving playlist quality beyond basic BPM matching by incorporating song suitability scoring. Research reveals that successful running music apps distinguish between **objective running suitability** (beat strength, rhythmic drive, danceability) and **subjective taste matching** (genre, artist, energy preferences). The Karageorghis framework establishes that rhythm response matters more than melody, which matters more than cultural impact, which matters more than personal associations.

The critical discovery is that GetSongBPM's `/song/` endpoint already returns `danceability` and `acousticness` fields—data points the current app completely ignores. This enables quality scoring without additional API dependencies. The recommended approach combines a two-tier enrichment strategy: (1) bundled curated song data (200-500 known-good running songs as a static JSON asset) for the quality "floor," and (2) dynamic API enrichment for danceability on non-curated songs. Crucially, no new package dependencies are required—all improvements build on the existing Flutter/Riverpod stack.

The key risk is treating "good running song" as universal rather than contextual. A metalcore fan's ideal running song differs completely from a pop listener's. The architecture must separate running suitability scoring from taste matching to avoid regressing toward bland, lowest-common-denominator recommendations. Other critical pitfalls include making curated data immutable (bundle with remote update capability), over-engineering taste profiles before fixing song pool quality, and scraping copyrighted running song lists.

## Key Findings

### Recommended Stack

**Core decision: No new dependencies needed.** All v1.1 features can be built with the existing stack plus pure Dart domain logic and Flutter bundled assets. The v1.0 stack (Flutter 3.38, Riverpod 2.x, go_router 17, http, SharedPreferences, GetSongBPM API) remains validated and stable.

**Core technologies for v1.1:**
- **GetSongBPM `/song/` endpoint** — Returns danceability, acousticness, key, time signature, artist genres. Currently unused, but critical for quality scoring. Requires lazy enrichment with rate limiting (top-N candidates only, 300ms delays, aggressive caching).
- **Bundled JSON asset** — Ships 200-500 curated running songs as `assets/curated_running_songs.json`. No SQLite/Drift needed for this data volume; SharedPreferences + rootBundle.loadString() handles it efficiently.
- **Pure Dart scoring algorithm** — Weighted multi-factor score (danceability + genre + artist + energy + BPM). No ML/AI packages required; hand-tuned weights based on research.
- **Existing state management** — Extend TasteProfile model, PlaylistGenerator scoring, StrideNotifier with new methods. All within current architecture patterns.

**What NOT to add:** drift/SQLite (overkill for <500 songs), dio (http works fine), Supabase activation (not needed for local-first features), any ML/AI packages, Spotify integration (still blocked), speculative animation libraries.

**Critical API strategy:** Enrichment cache (SharedPreferences, 7-day TTL) with lazy loading. Only enrich top-20 candidates per generation, not all. Over time the cache builds up and generations become near-instant.

### Expected Features

Research synthesized from the Karageorghis framework, 2025 groove/running studies, and competitor analysis (RockMyRun, PaceDJ, Weav).

**Must have (table stakes):**
- **Danceability-weighted scoring** — High-danceability songs at the right BPM are objectively better for running. GetSongBPM returns this; currently ignored. Users will feel the difference even if they can't articulate why.
- **Genre-aware song scoring** — Taste profile stores genres but doesn't use them in scoring. Genre match should boost ranking.
- **Variety within playlists** — No artist repeats in succession. Already partially implemented; needs artist-diversity constraint in scoring.
- **Post-run cadence nudge** — Simple "+/- 2 BPM" adjustment on playlist screen or home, not forcing users back through stride calculator.

**Should have (differentiators):**
- **Composite running quality score** — Combines danceability + genre + artist + BPM + energy into weighted score. No competitor in BPM-matching space does multi-factor scoring at this sophistication.
- **Energy-level-to-danceability mapping** — TasteProfile.energyLevel (chill/balanced/intense) maps to preferred danceability ranges. Currently stored but unused.
- **One-tap regeneration** — "Same run, new songs" from home screen. Current flow requires 4 navigation steps; should be 1 tap.
- **Curated "proven running song" bonus** — Static lists per genre from Runner's World, running playlists, community recommendations. Boost in scoring, not a filter.
- **Segment-appropriate energy** — Warm-up prefers lower energy, sprints prefer highest, cool-down prefers calm. Map automatically based on segment labels.

**Defer (anti-features):**
- **Audio analysis/beat detection** — Requires audio file access (unavailable), massive compute. GetSongBPM already provides danceability.
- **AI-powered recommendations** — Overkill; research-backed scoring formula is effectively a hand-tuned model.
- **Real-time BPM adjustment** — Requires foreground app, accelerometer, streaming integration. Weav's entire business model; patent-protected.
- **Lyric analysis** — No free API, marginal benefit over danceability + genre.
- **Social playlist sharing** — Requires accounts, backend, moderation. App is intentionally account-free.

### Architecture Approach

**Design principle: Add a scoring layer, do not restructure.** The existing PlaylistGenerator architecture is clean and well-bounded. Song quality is a new scoring dimension injected into `_scoreAndRank`, not a new pipeline.

**Major components:**

1. **RunningQualityIndex** — Lookup structure for curated song data. Loaded once from bundled JSON asset (`rootBundle.loadString`), kept in memory via Riverpod provider. Supports exact song match (artist|title key) and artist-level fallback for genre/energy inference. ~200-500 songs = 50-200KB, well within asset limits.

2. **SongQualityScorer** — Pure Dart static scoring methods. Replaces simple `_scoreAndRank` logic with weighted multi-factor score:
   - Artist match: +10 (existing)
   - Running quality (curated): +8 (NEW)
   - Genre match: +6 (NEW)
   - Energy alignment: +4 (NEW)
   - Exact BPM: +3 (existing)
   - Tempo variant: +1 (existing)

3. **Enhanced TasteProfile** — Add `preferVocals` (bool), `tempoVarianceTolerance` (double), `dislikedArtists` (Set). Backward-compatible via fromJson defaults.

4. **Stride adjustment layer** — Add `adjustCadence(int delta)` method to existing StrideNotifier. UI shows +/- buttons; persisted as cadence offset.

5. **Quick regeneration state** — Cache last song pool and run plan in PlaylistGenerationNotifier. `regenerate()` method reuses cached data for instant re-generation with different shuffle.

**Data flow enhancement:** PlaylistGenerationNotifier reads RunningQualityIndex → passes to PlaylistGenerator.generate() → SongQualityScorer computes composite score → songs ranked → quality indicators added to PlaylistSong model → displayed in UI.

**Key decision: Curated data is a boost, not a filter.** Unknown songs still appear, just ranked lower. This prevents empty playlists for niche genres.

### Critical Pitfalls

1. **Treating "good running song" as universal** — A metalcore fan's ideal differs completely from a pop listener's. Conflating running suitability (objective: beat strength, rhythm) with taste fit (subjective: genre, mood) produces bland recommendations. **Prevention:** Separate scoring dimensions explicitly. Running suitability and taste match must be independent signals, combined at generation time.

2. **Curated data that requires app store releases to update** — Bundled JSON assets are immutable after build. Errors, new songs, licensing changes require full submission cycle (days to weeks). **Prevention:** Hybrid approach—bundle baseline dataset as fallback, serve latest from Supabase/remote JSON with version checking, cache locally. Shorebird cannot update assets.

3. **Over-engineering taste profile before fixing song pool** — Adding sub-genres, mood dimensions, decade preferences doesn't help if the GetSongBPM candidate pool is mediocre. No amount of sophisticated ranking fixes poor candidates. **Prevention:** Invert priority—curate seed database of known-good songs first (Phase 1), then improve taste profiling (Phase 2+).

4. **Scraping running song lists without legal/quality considerations** — Scraping Runner's World, Cosmopolitan lists violates ToS, introduces data quality issues (promotional placements, recency bias), and creates reconciliation problems (fuzzy matching between scraped names and GetSongBPM IDs). **Prevention:** Use legitimate sources—GetSongBPM API as candidate pool + manual verification, public playlists for inspiration (not scraping), community curation model like jog.fm.

5. **Designing around Spotify Audio Features that no longer exist** — Spotify deprecated Audio Features (energy, valence, loudness) in Nov 2024. Designing models assuming 7 features breaks when only 2 (danceability, acousticness) are available from GetSongBPM. **Prevention:** Design scoring exclusively around confirmed available data: GetSongBPM fields + curated manual ratings + future user feedback.

## Implications for Roadmap

Based on combined research, v1.1 should be structured as 3 phases with clear dependencies.

### Phase 1: Scoring Foundation (Must Have)
**Rationale:** Core quality improvement. All other enhancements depend on better song selection. Research shows danceability/groove is the single most impactful signal for running music (Karageorghis hierarchy: rhythm response > musicality > cultural impact).

**Delivers:**
- Parse danceability from GetSongBPM `/song/` endpoint
- Parse artist genres from API
- Implement composite quality score (SongQualityScorer)
- Integrate energy level (TasteProfile.energyLevel) into scoring
- Artist diversity constraint (no back-to-back same artist)

**Uses from STACK.md:**
- GetSongBPM `/song/` endpoint enrichment
- Pure Dart scoring algorithm
- Existing http package for API calls
- SharedPreferences for enrichment cache

**Implements from ARCHITECTURE.md:**
- SongQualityScorer class (new)
- Enhanced PlaylistGenerator._scoreAndRank
- Modified PlaylistGenerationNotifier (pass quality index)

**Avoids from PITFALLS.md:**
- Pitfall 1: Separates running suitability from taste matching as independent dimensions
- Pitfall 5: Uses only confirmed available data (danceability, acousticness from GetSongBPM)

**Research flag:** SKIP — Well-documented patterns. GetSongBPM API fields confirmed, scoring logic is pure domain logic.

---

### Phase 2: Curated Data Foundation (Should Have)
**Rationale:** Establishes quality "floor" for recommendations. Even with perfect scoring, GetSongBPM's random BPM results need curation. Research shows 200-500 manually verified songs dramatically improves perceived quality.

**Delivers:**
- Curated running songs JSON asset (200-500 songs, manually verified)
- CuratedSongsLoader (rootBundle + JSON parse)
- RunningQualityIndex (in-memory lookup structure)
- Integration with SongQualityScorer (curated bonus in composite score)
- Baseline remote update capability (Supabase table + version check)

**Uses from STACK.md:**
- Bundled JSON asset (assets/curated_running_songs.json)
- No new packages—rootBundle.loadString() for loading
- Optional: Supabase for remote updates (already in project)

**Implements from ARCHITECTURE.md:**
- RunningSong model
- RunningQualityIndex class
- runningQualityProvider (Riverpod)
- pubspec.yaml asset declaration

**Avoids from PITFALLS.md:**
- Pitfall 2: Includes remote update path from day one (hybrid: bundled baseline + Supabase/remote fetch)
- Pitfall 3: Prioritizes song pool quality before taste sophistication
- Pitfall 4: Manual curation from legitimate sources; no scraping copyrighted lists

**Research flag:** MEDIUM — Needs manual data curation effort (not technical research). Sourcing strategy must be defined: which running playlists to reference, which genres to prioritize, quality rating methodology.

---

### Phase 3: UX Refinements (Should Have)
**Rationale:** Low-friction improvements that leverage the enhanced scoring. These are independent of each other and can be built in parallel or prioritized based on user feedback.

**Delivers:**
- Post-run cadence nudge (+/- 2 BPM buttons)
- One-tap regeneration from home screen
- Segment-appropriate energy mapping (warm-up/cool-down auto-adjust)
- Song quality indicators in UI (badge/icon for curated songs)
- Extended TasteProfile fields (preferVocals, tempoVarianceTolerance, dislikedArtists)

**Uses from STACK.md:**
- Existing StrideNotifier extension
- Existing go_router navigation restructure
- Existing Riverpod state management

**Implements from ARCHITECTURE.md:**
- StrideNotifier.adjustCadence() method
- PlaylistGenerationNotifier.regenerate() method
- PlaylistSong.runningQuality field
- SongTile widget enhancement
- TasteProfile model extension

**Avoids from PITFALLS.md:**
- UX pitfall: Nudge increments are 2-3 BPM (not aggressive 5+ BPM jumps)
- UX pitfall: Quality score is internal; only show simple badge, not raw numbers
- UX pitfall: Quick action shows confirmation with visible parameters

**Research flag:** SKIP — Standard Flutter UI patterns. All components extend existing features.

---

### Future (v1.2+)
Deferred features based on research:
- Song feedback loop (heart/flag per song) → scoring integration
- Playlist freshness tracking (penalize recently played songs)
- Taste profile refinement from accumulated feedback
- Expand curated dataset to 1000+ songs with community contributions

---

### Phase Ordering Rationale

- **Phase 1 before Phase 2:** Scoring algorithm must exist before curated data can provide scoring bonuses. However, Phase 1 can ship without curated data (quality improves from danceability alone). Phase 2 enhances Phase 1 but isn't a hard dependency.

- **Phase 2 before Phase 3:** UX refinements like quality indicators require quality data to exist. Cadence nudge and quick regen are independent, but make more sense once playlists are higher quality.

- **Phase 1+2 are parallelizable if needed:** Different developers can work on scoring logic (Phase 1) and data curation (Phase 2) simultaneously. Integration point is clear: SongQualityScorer reads from RunningQualityIndex.

- **Phase 3 items are fully parallel:** Cadence nudge, quick regen, segment energy, UI badges, and taste profile extensions have zero dependencies on each other. Prioritize by user feedback or developer preference.

**Pitfall mitigation through ordering:**
- Addressing Pitfall 3 explicitly: Song pool quality (Phase 2) comes before taste sophistication (deferred to v1.2+)
- Addressing Pitfall 1 explicitly: Architecture separates concerns in Phase 1, data model enforces it in Phase 2
- Addressing Pitfall 2 explicitly: Phase 2 includes remote update capability from day one

### Research Flags

**Phases needing deeper research during planning:**
- **Phase 2 (Curated Data):** Requires non-technical research—data sourcing strategy, genre prioritization, quality rating methodology, manual curation workflow. Technical implementation is straightforward (JSON + loader), but data compilation is labor-intensive.

**Phases with standard patterns (skip research-phase):**
- **Phase 1 (Scoring Foundation):** Pure domain logic + confirmed API fields. No unknowns.
- **Phase 3 (UX Refinements):** Standard Flutter/Riverpod patterns. All changes are extensions of existing features.

**Critical unknowns to validate during Phase 1 implementation:**
- GetSongBPM `/tempo/` vs `/song/` endpoint: Which returns danceability? Does `/tempo/` include it, or is a follow-up `/song/` call required? This determines API call volume and rate limiting strategy.
- Rate limiting behavior: Can we safely make 20-30 `/song/` enrichment calls per generation with 300ms delays? Needs production testing.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All recommendations build on existing validated stack. GetSongBPM `/song/` endpoint fields confirmed via API docs. No new package dependencies reduces risk. |
| Features | MEDIUM-HIGH | Feature priorities grounded in peer-reviewed research (Karageorghis framework, 2025 groove study). Must-haves vs should-haves clearly distinguished. Competitor analysis validates differentiation. Confidence docked slightly because danceability as running proxy is strongly supported but not universally tested across all genres. |
| Architecture | HIGH | Direct codebase analysis of all relevant files. Proposed changes are surgical extensions, not restructures. Integration points clearly mapped to specific files/line ranges. Clean separation of concerns (scoring, data loading, UI) reduces risk. |
| Pitfalls | HIGH | All pitfalls grounded in domain-specific patterns (music recommendation systems), confirmed by research sources and existing v1.0 experience. Recovery strategies documented. Pitfall-to-phase mapping makes prevention actionable. |

**Overall confidence:** MEDIUM-HIGH

The technical approach is sound and low-risk (no new dependencies, extends existing patterns). The architectural changes are well-scoped. The primary uncertainties are:

1. **Data quality/sourcing** — Curated song compilation is manual labor; quality depends on curation discipline
2. **Danceability effectiveness** — Strong research support, but needs real-world validation across diverse genres
3. **API rate limits** — GetSongBPM's undocumented rate limits for `/song/` endpoint; mitigation strategy (lazy enrichment, aggressive caching) is sound but unproven at scale

### Gaps to Address

**During Phase 1 planning:**
- Confirm whether `/tempo/` endpoint returns danceability or if `/song/` call is required. Test empirically with API before finalizing enrichment strategy.
- Define scoring weight tuning methodology. Initial weights based on research (artist: 10, curated: 8, genre: 6, energy: 4, BPM: 3, variant: 1), but may need adjustment based on user feedback.

**During Phase 2 planning:**
- Define data sourcing protocol: which public running playlists are legitimate references, manual verification checklist, quality rating rubric (1-10 scale definition).
- Establish minimum song count per genre (suggested: 15-20 per RunningGenre enum value for balanced coverage).
- Design Supabase schema for remote curated data: single table with version field, or more normalized structure?

**During implementation:**
- Monitor GetSongBPM API behavior with increased call volume. Adjust enrichment strategy (top-N candidates, delay timing) if rate limiting issues emerge.
- Validate danceability correlation with actual runner preferences. A/B test if possible (danceability scoring on vs off) or gather qualitative feedback.
- Assess SharedPreferences performance with growing enrichment cache. If >500 enriched songs cause jank, consider migration to SQLite (but unlikely—100 bytes/song * 500 = 50KB is trivial).

**Post-v1.1 validation:**
- Does composite scoring noticeably improve playlist quality vs v1.0? Measure via user feedback or retention metrics if available.
- Which genres benefit most from curated data? Identify coverage gaps for curation expansion in v1.2.
- Are any Phase 3 features underutilized? Deprioritize in future roadmaps if low engagement.

## Sources

### Primary (HIGH confidence)
- Direct codebase analysis: All files in `lib/features/` — Complete analysis of existing architecture, state management patterns, data models, scoring logic
- [Flutter asset documentation](https://docs.flutter.dev/ui/assets/assets-and-images) — Asset loading, rootBundle.loadString() patterns
- [GetSongBPM API documentation](https://getsongbpm.com/api) — `/song/` endpoint returns danceability, acousticness, key, time signature, artist genres
- [Spotify API deprecation](https://developer.spotify.com/blog/2024-11-27-changes-to-the-web-api) — Audio Features permanently removed Nov 2024
- [PLOS One: Music synchronization and running](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0208702) — BPM matching improves efficiency by ~7%

### Secondary (MEDIUM confidence)
- [Karageorghis framework / BMRI research](https://pmc.ncbi.nlm.nih.gov/articles/PMC3339578/) — Rhythm response > musicality > cultural impact > association hierarchy
- [Frontiers: High-groove music boosts running speed (2025)](https://www.frontiersin.org/journals/sports-and-active-living/articles/10.3389/fspor.2025.1586484/full) — Danceability/groove directly improves running performance and mood
- [ScraperAPI: Web scraping legality](https://www.scraperapi.com/web-scraping/is-web-scraping-legal/) — Legal framework for data sourcing
- [Shorebird documentation](https://docs.shorebird.dev/code-push/) — Code push limitations (cannot update assets/bundled data)
- Runner's World, Boston Globe, KURU running song lists — Community-curated running music; useful as seed data references
- Competitor analysis: RockMyRun (DJ curation), PaceDJ (library filtering), Weav (adaptive music) — Feature differentiation

### Tertiary (LOW confidence)
- [Running with Data: Danceability correlation](https://runningwithdata.com/2010/10/15/danceability-and-energy.html) — Blog post (2010) but aligns with academic research
- jog.fm model (community voting per pace) — Observed via app store listing; methodology inferred
- SharedPreferences size limits — Community guidance suggests <1MB practical limit; not officially documented by Flutter team

---
*Research completed: 2026-02-05*
*Ready for roadmap: yes*
