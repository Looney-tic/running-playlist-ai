# Feature Research: v1.1 Experience Quality

**Domain:** Running playlist song quality, taste profiling, cadence UX, repeat generation
**Researched:** 2026-02-05
**Confidence:** MEDIUM-HIGH -- research-backed song quality factors; API field availability verified through documentation; UX patterns synthesized from competitor analysis and general mobile UX principles

## Background: What the Research Says About Running Music

Before listing features, the evidence base matters. The app currently scores songs by BPM match + artist name match. Research identifies substantially more factors.

### The Karageorghis Framework (Peer-Reviewed, HIGH Confidence)

Costas Karageorghis (Brunel University) developed the dominant model for exercise music effectiveness, validated through the Brunel Music Rating Inventory (BMRI, BMRI-2, BMRI-3). The model identifies four hierarchical factors:

1. **Rhythm response** (most important) -- how much the music makes you want to move. Driven by tempo, beat strength, rhythmic regularity, and groove. A 170 BPM song with a weak, irregular beat is worse than a 168 BPM song with a powerful, driving rhythm.

2. **Musicality** -- pitch-related elements: harmony, melody. Uplifting harmonic structures and catchy melodies increase motivation. Think "the chorus that flips a switch."

3. **Cultural impact** -- how pervasive and recognized the music is. Familiar songs ("Chariots of Fire," "Eye of the Tiger") carry cultural associations with sport and achievement.

4. **Association** -- personal memories and emotional connections to specific songs. Highly individual and impossible to algorithmically predict without explicit user feedback.

Key insight: **Rhythm response > Musicality > Cultural impact > Association.** The rhythmic "drive" of a song matters more than melody, which matters more than fame, which matters more than personal history. This hierarchy directly informs what data we should prioritize in scoring.

### What "Groove" Means (2025 Research, HIGH Confidence)

A 2025 study (Frontiers in Sports and Active Living) found that **high-groove music boosts self-selected running speed AND positive mood** in female university students. "Groove" is the sensation of wanting to move to the music -- it correlates with danceability, rhythmic regularity, and beat strength. This is not the same as energy or tempo; a slow funk track can have high groove while a fast metal track might have low groove.

**Implication for our app:** Danceability is a proxy for groove. GetSongBPM already returns a `danceability` field (integer, likely 0-100 scale) on the `/song/` endpoint. This is the single most impactful data point we are currently ignoring.

### Synchronization Benefits (HIGH Confidence)

Research consistently shows that running synchronized to music's beat improves efficiency by ~7% (less oxygen required for same work output). This validates the core BPM-matching approach but also means: songs with **strong, clear beats** are more effective than songs with complex, syncopated rhythms at the same BPM.

### Motivational Song Characteristics (MEDIUM Confidence)

Across multiple studies, motivational running music is characterized by:
- Fast tempo (120-180 BPM for running -- already handled)
- Strong, driving rhythm with clear downbeats
- Positive or empowering lyrics ("associations with triumph or overcoming adversity")
- Uplifting harmonic structure (major key, bright timbre)
- Cultural associations with sport, movement, or achievement

### The "Freshness" Factor (MEDIUM Confidence)

Research suggests the brain habituates to repeated musical stimuli. Swapping 2-3 songs per week keeps the playlist "alive." This validates the regeneration feature and argues against playing the exact same playlist every run.

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features that v1.1 must deliver to fulfill the "experience quality" promise. Without these, the app generates playlists that are technically BPM-correct but feel mediocre.

| Feature | Why Expected | Complexity | Dependencies | Notes |
|---------|--------------|------------|--------------|-------|
| **Danceability-weighted scoring** | A song with high danceability/groove at the right BPM is objectively better for running than one with low danceability. Research is unambiguous on this. Users will feel the difference even if they cannot articulate why. | LOW | Requires fetching danceability from GetSongBPM `/song/` endpoint per candidate, OR extracting it if the `/tempo/` endpoint includes it. Need to verify which endpoint returns the field. | GetSongBPM API returns `danceability` as integer (e.g. 55 for "Master of Puppets"). Currently `BpmSong.fromApiJson` ignores this field entirely. Adding it to the model and scoring pipeline is straightforward. |
| **Genre-aware song scoring** | Currently taste profile stores genres but they are not used in scoring. If a user picks "Electronic" and "Hip-Hop," songs from those genres should rank higher than random genre matches. | LOW | GetSongBPM `/song/` endpoint returns artist genres (e.g. `["heavy metal", "rock"]`). The `/tempo/` endpoint may return this too. Taste profile already stores `List<RunningGenre>`. | Need genre mapping: RunningGenre enum values -> GetSongBPM genre strings. Fuzzy matching required (e.g. "electronic" matches "electropop", "edm", "house"). |
| **Variety within playlists** | Users expect to not hear the same artist twice in a row, and to get different songs on regeneration. Currently shuffle + used-song tracking partially handles this. | LOW | Existing `usedSongIds` set. Existing shuffle-within-tier logic. | Add artist-diversity constraint: after selecting a song by Artist X, penalize the next song by Artist X. This is a scoring tweak, not a new feature. |
| **Post-run cadence nudge ("too fast / too slow")** | After running with a playlist, users need a dead-simple way to adjust cadence for next time. The current flow requires going back to stride screen, re-entering pace, recalculating. Too many steps. | LOW-MEDIUM | Depends on stride calculator, run plan, and regeneration flow. | A simple "+/- 2 BPM" nudge on the playlist result screen or home screen. Persisted as an offset to the calculated cadence. Does not replace stride calculator for initial setup. |

### Differentiators (Competitive Advantage)

Features that set this app apart. Competitors either do not offer these or implement them poorly.

| Feature | Value Proposition | Complexity | Dependencies | Notes |
|---------|-------------------|------------|--------------|-------|
| **"Running song quality" composite score** | Combine danceability + genre match + artist match + BPM closeness + energy level alignment into a single quality score. No competitor in the BPM-matching space does multi-factor scoring -- RockMyRun uses human DJs, PaceDJ just filters your library by BPM, Weav does adaptive tempo on a small curated catalog. A quality score lets us rank from the entire GetSongBPM catalog. | MEDIUM | Requires danceability data, genre data, existing artist match, existing BPM match type. Energy level from taste profile (chill/balanced/intense) should map to preferred danceability ranges. | This is the core v1.1 deliverable. The scoring formula replaces the current simple `_artistMatchScore + _exactMatchScore` system with a weighted multi-factor score. |
| **Energy-level-to-danceability mapping** | The taste profile already captures energy preference (chill/balanced/intense). Map this to preferred danceability ranges: chill = 20-50, balanced = 40-70, intense = 60-100. Songs matching the preferred range get a scoring bonus. | LOW | Danceability data from API. EnergyLevel from taste profile (already exists). | Currently EnergyLevel is stored but never used in playlist generation. This gives it actual teeth. Simple range check in the scoring function. |
| **One-tap regeneration from home screen** | Returning users should be able to generate a new playlist in one tap. "Same run, new songs." The app remembers their last run plan + taste profile + cadence. No re-entry needed. Just tap and go. | LOW-MEDIUM | Run plan persistence (exists). Taste profile persistence (exists). Playlist generation (exists). | The current flow: Home -> Playlist tab -> tap Generate. For returning users, a prominent "Generate Playlist" action on the home screen that uses the last-saved run plan. One tap, not three screens. |
| **Curated "proven running song" bonus lists** | Maintain per-genre lists of songs that are community-verified as great running songs (from Runner's World lists, popular running playlists on Spotify, Reddit r/running recommendations). Songs on these lists get a scoring bonus. | MEDIUM | Requires maintaining static data (song title + artist pairs per genre). Matched against GetSongBPM results by title+artist fuzzy match. | RockMyRun pays DJs to curate. PaceDJ has no curation. We can get 80% of the value by scraping/compiling public "best running songs" lists and embedding them as a static asset. Updated quarterly. |
| **Segment-appropriate energy mapping** | Warm-up segments should prefer lower danceability/energy songs. Cool-down segments should prefer lower energy. Sprint intervals should prefer highest energy. Map segment type to energy preference automatically. | LOW | Run plan segment labels (exists). Danceability data. | Segment labels already distinguish "Warm-up", "Main", "Cool-down", "Sprint", "Recovery". Use label to override the global energy preference per segment. |
| **"Songs I liked" feedback loop** | Let users heart/flag individual songs in generated playlists. Hearted songs get boosted in future generations. Flagged songs get excluded. Builds a personal running music profile over time. | MEDIUM | Playlist display (exists). Local persistence for liked/disliked song IDs. Integration with scoring pipeline. | This captures Karageorghis's "association" factor -- the most personal, least algorithmically predictable dimension. Explicit feedback is the only reliable signal. Competitors do not do this for running-specific contexts. |

### Anti-Features (Deliberately NOT Building)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Audio analysis / beat detection** | "Analyze songs locally to compute danceability, energy, beat strength" | Requires audio file access (not available -- app uses external links), massive compute, audio DSP libraries. GetSongBPM already provides danceability. | Use GetSongBPM's existing danceability field. Possibly supplement with Soundcharts API if coverage is poor (but at $250/mo, unlikely justified). |
| **AI-powered song recommendations** | "Use ML to learn what songs are good for running" | Requires training data, model serving infrastructure, cold start problem. Overkill for the current app scale. The Karageorghis framework already provides a well-validated scoring model. | Implement the research-backed scoring formula. It is effectively a hand-tuned ML model based on decades of sports psychology research. |
| **Real-time BPM adjustment during runs** | "Detect cadence changes and swap songs mid-run" | Requires foreground app, accelerometer, real-time song switching, streaming integration. Weav's entire company is built on this technology. Patent-protected adaptive music format. | Pre-generate playlist at target BPM. If the runner wants to adjust, they nudge cadence post-run and regenerate. The playlist IS the pacing tool. |
| **Lyric analysis for motivational content** | "Scan lyrics for words like 'run', 'fight', 'power' to boost motivational songs" | No reliable free lyrics API. Copyright issues with lyrics databases. NLP analysis adds complexity. Marginal benefit over danceability + genre scoring. | Genre and danceability already correlate heavily with motivational content. Pop, hip-hop, and EDM at high danceability are almost always motivational. |
| **Social/community playlist sharing** | "Let runners share playlists with each other" | Requires user accounts, backend infrastructure, moderation. The app is intentionally account-free. Low engagement for niche app. | Users can copy playlist text to clipboard (already exists) or share their Spotify/YouTube links directly. |
| **Detailed per-song audio feature display** | "Show danceability, energy, key, time signature for each song" | Information overload. Runners want to run, not analyze audio metadata. Clutters the UI. | Quality score is internal. The UI shows BPM, match type, and Spotify/YouTube links. Quality is reflected in song ranking, not exposed as numbers. |
| **Acoustic/chill song mode for recovery runs** | "Support very slow recovery runs with calm music" | GetSongBPM song pool at very low BPMs (100-120) is sparse. Chill running music is a niche use case. The stride calculator already clamps at 150 BPM. | The energy level "chill" option already exists in taste profile. It should soften the danceability preference rather than requiring a separate mode. |

---

## Feature Dependencies

```
Existing v1.0 Features (solid foundation)
    |
    |-- BpmSong model
    |       |
    |       +-- [NEW] Add danceability field -----> [NEW] Danceability-weighted scoring
    |       |                                              |
    |       +-- [NEW] Add artist genres field ----> [NEW] Genre-aware scoring
    |                                                      |
    |-- TasteProfile (genres, artists, energy)             |
    |       |                                              |
    |       +-- EnergyLevel (unused currently) ---> [NEW] Energy-to-danceability mapping
    |       |                                              |
    |       +-- genres (unused in scoring) -------> [NEW] Genre match scoring
    |                                                      |
    |-- PlaylistGenerator._scoreAndRank                    |
    |       |                                              |
    |       +-- [REPLACE] Simple scoring ---------> [NEW] Composite quality score
    |                                                      |
    |-- RunPlan.segments[].label                           |
    |       |                                              |
    |       +-- Segment type detection -----------> [NEW] Segment-appropriate energy
    |
    |-- [NEW] Curated song lists (static asset)
    |       |
    |       +-- Title+artist match ---------------> [NEW] "Proven running song" bonus
    |
    |-- [NEW] Song feedback (heart/flag)
    |       |
    |       +-- Liked/disliked song IDs ----------> Scoring boost/penalty
    |
    |-- [NEW] Cadence nudge (+/- BPM)
    |       |
    |       +-- Stride offset persistence --------> RunPlan regeneration with offset
    |
    |-- [NEW] One-tap regeneration
            |
            +-- Last run plan (exists) + Generate action on home screen
```

### Dependency Notes

- **Danceability scoring requires BpmSong model change:** The `danceability` field must be added to `BpmSong` and parsed from API responses. This is a prerequisite for all quality scoring improvements.
- **Genre scoring requires genre data:** Either from the `/tempo/` endpoint (if available) or via a follow-up `/song/` call. May require an additional API call per song, which has rate-limit implications.
- **Composite score replaces existing scoring:** The new multi-factor score replaces `_scoreAndRank` in `PlaylistGenerator`. This is a single modification point, making it low risk.
- **Curated lists are independent:** Static JSON assets that can be compiled and shipped without any API changes.
- **Song feedback is independent of scoring improvements:** Can be built before or after the composite score, but integrates with it.
- **Cadence nudge is independent of song quality:** A UX feature that can be built in parallel with scoring improvements.
- **One-tap regeneration is independent:** A home screen UX change with no scoring dependencies.

---

## Critical Data Question: What Does `/tempo/` Return?

The app currently uses only the `/tempo/` endpoint to fetch songs by BPM. This endpoint returns a list of songs. The `/song/` endpoint (individual song lookup) returns `danceability`, `acousticness`, `key_of`, `time_sig`, and artist `genres`.

**Unknown (MEDIUM confidence):** Whether the `/tempo/` endpoint response includes `danceability` and artist `genres` per song, or only the basic fields (id, title, artist name, tempo).

**This is the single most important technical question for v1.1.** If `/tempo/` already returns danceability and genres, implementation is straightforward (parse additional fields, add to scoring). If not, we need either:
1. A follow-up `/song/{id}` call per candidate (expensive, rate-limited), OR
2. A cache strategy where we gradually enrich songs with detail data over time

**Recommendation:** Test the `/tempo/` endpoint response first. Inspect the raw JSON to see if danceability and genre fields are included. This determines the architecture of the entire scoring pipeline.

---

## v1.1 Milestone Definition

### Phase 1: Scoring Foundation (Must Have)

- [ ] **Parse danceability from API** -- Add `danceability` field to `BpmSong`, parse from API response
- [ ] **Parse artist genres from API** -- Add `genres` field to `BpmSong` or artist sub-model
- [ ] **Composite quality score** -- Replace simple scoring with weighted multi-factor score: `(danceabilityScore * 0.3) + (bpmClosenessScore * 0.25) + (genreMatchScore * 0.2) + (artistMatchScore * 0.15) + (energyAlignmentScore * 0.1)`
- [ ] **Energy level integration** -- Map EnergyLevel to preferred danceability range, apply as scoring factor
- [ ] **Artist diversity constraint** -- Penalize back-to-back songs by same artist

### Phase 2: UX Improvements (Should Have)

- [ ] **Cadence nudge** -- "+2 / -2 BPM" buttons on playlist screen, persisted as stride offset
- [ ] **One-tap regeneration** -- "New Playlist" action on home screen using last run plan
- [ ] **Segment energy mapping** -- Auto-adjust energy preference by segment type (warm-up = lower, sprint = higher)

### Phase 3: Personalization (Add After Validation)

- [ ] **Song feedback (heart/flag)** -- Per-song like/dislike in playlist view, persisted locally
- [ ] **Feedback integration in scoring** -- Liked songs boosted, flagged songs excluded
- [ ] **Curated running song lists** -- Static JSON per genre, compiled from public running playlists and community lists
- [ ] **Curated song bonus in scoring** -- Songs on curated lists get +N scoring bonus

### Future (v1.2+)

- [ ] **Playlist freshness tracking** -- Track which songs have been played recently, penalize repetition across generations
- [ ] **Taste profile refinement from feedback** -- Infer genre/artist preferences from accumulated heart/flag data
- [ ] **Danceability histogram visualization** -- Show users why songs were chosen (optional, for curious users)

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority | Rationale |
|---------|------------|---------------------|----------|-----------|
| Danceability-weighted scoring | HIGH | LOW | P1 | Biggest quality jump for least effort. Data likely already available. |
| Genre-aware scoring | HIGH | LOW | P1 | Genres exist in taste profile but are unused in scoring. Direct fix. |
| Energy level integration | MEDIUM | LOW | P1 | EnergyLevel is already stored, just not used. Quick win. |
| Composite quality score | HIGH | MEDIUM | P1 | Combines above factors. The core v1.1 deliverable. |
| Artist diversity | MEDIUM | LOW | P1 | Prevents repetitive-feeling playlists. Simple scoring penalty. |
| One-tap regeneration | HIGH | LOW | P2 | Massive UX improvement for returning users. Low code effort. |
| Cadence nudge | MEDIUM | LOW | P2 | Solves a real post-run friction point. Small UI addition. |
| Segment energy mapping | MEDIUM | LOW | P2 | Natural extension of energy integration. |
| Song feedback (heart/flag) | HIGH | MEDIUM | P2 | Enables personalization over time. Requires UI + persistence. |
| Curated running song lists | MEDIUM | MEDIUM | P3 | Requires data compilation effort. High value but not automated. |
| Feedback scoring integration | MEDIUM | LOW | P3 | Depends on feedback feature. Simple once feedback exists. |
| Playlist freshness tracking | LOW | MEDIUM | P3 | Nice-to-have. Shuffle already provides some variety. |

---

## Competitor Feature Analysis

| Feature | RockMyRun | PaceDJ | Weav Run | Spotify Running (retired) | Our Approach (v1.1) |
|---------|-----------|--------|----------|---------------------------|---------------------|
| **Song quality beyond BPM** | DJ-curated mixes (human quality) | None (filters user's library) | ~500 curated adaptive songs | Algorithm-selected (deprecated) | Multi-factor scoring: danceability + genre + artist + energy + BPM closeness |
| **Running-specific taste** | Genre/mood/activity filters | Uses whatever is in your library | Curated playlists by vibe | Based on Spotify listening history | Questionnaire (genres, artists, energy level) with feedback loop |
| **Cadence adjustment** | Real-time via accelerometer/HR | Manual BPM target | Real-time via accelerometer (Match My Stride mode) | Real-time (deprecated) | Post-run nudge (+/- BPM) with persisted offset |
| **Quick regeneration** | Always streaming, no "generation" step | Filter results update live | Always streaming | N/A | One-tap from home screen using last run plan |
| **Song feedback** | Implicit (skip = dislike) | None | None documented | Implicit (Spotify signals) | Explicit heart/flag per song |
| **Multi-segment playlists** | "Stations build in BPM during workout" | Basic interval support | Two modes (Match Stride / Fixed Tempo) | Single tempo | Full segment-based: warm-up, main, cool-down, intervals with per-segment energy |

### Competitive Positioning

RockMyRun's advantage is human curation by professional DJs, but it locks users into their ecosystem and a subscription. PaceDJ's advantage is using your own library, but it offers no quality scoring. Weav's advantage is real-time adaptive music, but with only ~500 songs.

**Our unique position:** We score the entire GetSongBPM catalog using research-backed quality factors, generate complete segment-aware playlists pre-run, and let users play on any platform. No subscription needed for core functionality. No lock-in to a proprietary player.

---

## Research Confidence Assessment

| Finding | Confidence | Source | Notes |
|---------|------------|--------|-------|
| Danceability/groove matters more than BPM precision | HIGH | Karageorghis framework + 2025 Frontiers study | Multiple peer-reviewed sources agree |
| Rhythm response > Musicality > Cultural impact > Association | HIGH | BMRI-2 validated instrument (Karageorghis 2006) | Well-established hierarchy |
| GetSongBPM `/song/` endpoint returns danceability | HIGH | API documentation example shows `"danceability": 55` | Verified from multiple documentation sources |
| GetSongBPM `/tempo/` endpoint returns danceability | LOW | Not explicitly documented for this specific endpoint | Must test empirically -- this is the critical unknown |
| GetSongBPM `/song/` endpoint returns artist genres | HIGH | API example shows `"genres": ["heavy metal", "rock"]` | Verified |
| Soundcharts as alternative audio features source | MEDIUM | Pricing starts at $250/mo after 1000 free requests | Likely overkill; GetSongBPM may suffice |
| Spotify audio features API is permanently deprecated | HIGH | Multiple sources (Spotify blog, TechCrunch, community) | No alternative from Spotify |
| Energy level mapping to danceability ranges | MEDIUM | Inference from research (not directly studied) | Reasonable extrapolation but not validated |
| Curated lists improve perceived quality | MEDIUM | Runner's World, community playlists exist | Anecdotal + face validity, not experimentally tested |

---

## Sources

### Peer-Reviewed Research
- [Music in the exercise domain: review and synthesis (Part I)](https://pmc.ncbi.nlm.nih.gov/articles/PMC3339578/) -- Karageorghis framework, BMRI factors, rhythm response hierarchy
- [High-groove music boosts running speed and mood (2025)](https://www.frontiersin.org/journals/sports-and-active-living/articles/10.3389/fspor.2025.1586484/full) -- Groove/danceability directly improves running
- [Music preference influence on exercise performance](https://pmc.ncbi.nlm.nih.gov/articles/PMC8167645/) -- Motivation, dissociation, affect mechanisms
- [Effects of music on anaerobic performance and motivation (2025)](https://www.frontiersin.org/journals/sports-and-active-living/articles/10.3389/fspor.2025.1518359/full) -- Music significantly increases motivation
- [BMRI-2 validation](https://pubmed.ncbi.nlm.nih.gov/16815785/) -- 6-item scale, motivational quotients 6-42
- [Psychology of workout music (Scientific American)](https://www.scientificamerican.com/article/psychology-workout-music/) -- Rhythm response, lyrical cadence, emotional engagement

### API and Technical
- [GetSongBPM API documentation](https://getsongbpm.com/api) -- Song endpoint fields including danceability, acousticness, genres
- [Spotify API deprecation announcement](https://developer.spotify.com/blog/2024-11-27-changes-to-the-web-api) -- Audio features removed Nov 2024
- [Spotify API restriction analysis 2026](https://voclr.it/news/why-spotify-has-restricted-its-api-access-what-changed-and-why-it-matters-in-2026/) -- No alternatives from Spotify
- [Soundcharts Audio Features API](https://soundcharts.com/en/audio-features-api) -- Alternative for energy, valence, danceability ($250/mo)

### Competitor Analysis
- [RockMyRun official site](https://www.rockmyrun.com/) -- Body-Driven Music, DJ curation, genre/mood filtering
- [PaceDJ official site](https://www.pacedj.com/) -- BPM-based library filtering, half/double tempo
- [Weav Run (Runner's World review)](https://www.runnersworld.com/runners-stories/a32257227/running-app-weav-improves-cadence-stride/) -- Adaptive music 100-240 BPM, ~500 songs
- [Weav Music adaptive technology](https://medium.com/@weavmusic/whats-so-adaptive-about-our-music-bc9190772890) -- Stem-based adaptive remixing

### Running Playlist Curation
- [Runner's World best running songs 2025](https://www.runnersworld.com/runners-stories/a69547480/top-running-songs-2025/) -- Community-sourced running music picks
- [Boston Globe marathon playlist 2025](https://www.bostonglobe.com/2025/03/28/arts/boston-marathon-2025-runner-playlist-best-songs/) -- Running club curated songs
- [KURU 100 best running songs](https://www.kurufootwear.com/blogs/articles/best-running-songs) -- Community-compiled running music list

---
*Feature research for: v1.1 Experience Quality -- Running Playlist AI*
*Researched: 2026-02-05*
