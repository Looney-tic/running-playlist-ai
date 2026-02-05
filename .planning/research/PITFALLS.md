# Pitfalls Research

**Domain:** Adding song quality scoring, curated content, and recommendation improvements to an existing running playlist app (v1.1 Experience Quality)
**Researched:** 2026-02-05
**Confidence:** HIGH (domain-specific, grounded in existing codebase analysis + research literature)

## Critical Pitfalls

### Pitfall 1: Treating "Good Running Song" as an Objective, Universal Property

**What goes wrong:**
The team builds a single "running quality score" (e.g., 0-100) for each song and treats it as ground truth. A song scored 85/100 is presented as objectively better for running than one scored 60/100. But "good for running" is deeply personal: a metalcore fan's ideal 170 BPM running song is completely different from a pop listener's. The score conflates two orthogonal dimensions -- *running suitability* (rhythmic drive, energy consistency, beat clarity) with *taste fit* (genre, mood, familiarity). When these are merged into one number, the system recommends bland, lowest-common-denominator songs that nobody actually loves running to.

**Why it happens:**
It feels elegant to have one score. The scoring function is easier to test with a single output. And early testing with the developer's own taste confirms it "works." But taste diversity means a universal score will always regress toward inoffensive pop.

**How to avoid:**
Separate the concerns explicitly. Build two independent scoring dimensions:
1. **Running suitability score** -- Objective-ish properties: beat consistency/stability, rhythmic drive (strong downbeats), energy sustain (not too many quiet sections), tempo match quality. These are genre-agnostic.
2. **Taste match score** -- Already exists in `PlaylistGenerator._scoreAndRank()` as artist matching and BPM exactness bonuses. Extend with genre affinity, energy level preference.

Multiply or combine at playlist generation time, not at data ingestion time. A song can have high running suitability but low taste match (or vice versa). The user's playlist should prioritize songs high in both.

**Warning signs:**
- Your curated "top running songs" list looks like a generic pop workout playlist
- Test users in different genres report the same songs being recommended
- The scoring model has no input from the taste profile
- Songs with niche genre appeal consistently score low

**Phase to address:**
Song quality scoring design phase -- the data model and scoring architecture must separate these concerns from the start. Retrofitting is expensive because curated data entries with baked-in single scores need to be re-evaluated.

**Confidence:** HIGH -- this is the fundamental design trap in music recommendation systems. Research confirms "danceability and energy are not indicative of personal preference regardless of geography" (Spotify audio features research). Jog.fm solved this via community voting per pace, not per song quality.

---

### Pitfall 2: Curated Data That Cannot Be Updated Without an App Store Release

**What goes wrong:**
The team bundles a curated running song database as a JSON asset file in the Flutter app bundle. The data ships with the app. To add new songs, fix errors, or respond to licensing changes, a full app store submission is required. The curated data becomes stale within weeks, and the update cycle (dev -> review -> release -> user update) takes days to weeks.

**Why it happens:**
Bundled JSON is the simplest approach -- it requires no backend, no network requests, and works offline. The current app already uses SharedPreferences for all persistence, so "just add a JSON file" feels consistent with the existing architecture. Supabase is initialized but barely used.

**Consequences:**
- New popular songs cannot be added without an app update
- Errors in curated data (wrong BPM, wrong genre tag, removed song) persist until the next release
- Genre coverage gaps require a full release cycle to fix
- If GetSongBPM removes or changes a song ID, the curated data references break silently

**How to avoid:**
Use a hybrid approach:
1. **Bundle a baseline dataset** as a Flutter asset for offline/first-launch experience
2. **Serve the latest version from Supabase** (or any remote source) on app start, with a version number
3. **Cache the remote version locally** with SharedPreferences or local file storage
4. **Fall through gracefully**: remote -> local cache -> bundled baseline

This pattern is standard for mobile content apps. Supabase is already in the project and can host a simple `curated_songs` table or a versioned JSON endpoint. The existing `BpmCachePreferences` pattern (TTL-based caching in SharedPreferences) can be reused.

Shorebird (Flutter code push) can update Dart code without app store releases but *cannot* update assets or bundled data files. Remote data is the correct solution.

**Warning signs:**
- Team discussion about "we'll just push an update" when data errors are found
- No version number on the curated dataset
- No network fetch path for curated data
- All test scenarios assume the bundled data is current

**Phase to address:**
Data layer architecture phase -- before populating the curated database, decide the storage and update strategy. Building the curator tool before the delivery mechanism wastes effort.

**Confidence:** HIGH -- confirmed by Flutter documentation (assets are immutable after build) and Shorebird documentation (cannot update non-Dart resources). This is a well-known mobile app pattern.

---

### Pitfall 3: Over-Engineering the Taste Profile When the Real Problem Is Song Pool Quality

**What goes wrong:**
The team invests heavily in sophisticated taste profiling -- adding sub-genres, mood dimensions, decade preferences, vocal style preferences, instrument preferences -- while the underlying song pool from GetSongBPM API remains the same. No amount of taste profiling sophistication helps if the candidate songs at 170 BPM are mostly obscure tracks the user has never heard of and would never choose to run to.

The v1.0 `PlaylistGenerator` scores songs by artist match (+10) and BPM exactness (+3/+1). Adding 15 more taste dimensions to this scoring function produces a more complex model that outputs the same mediocre results, because the problem is not in the ranking -- it's in the candidate pool.

**Why it happens:**
Taste profiling is "fun" engineering work. It's fully within the app's control (no external dependencies). It feels productive. Meanwhile, improving the song pool requires data sourcing, curation effort, and external research -- less glamorous work.

**Consequences:**
- Development time spent on taste features that don't move the quality needle
- Users re-do the taste questionnaire hoping for better results, but get the same songs
- The app becomes more complex to use (longer questionnaire) without better output
- The core complaint ("these songs aren't good for running") persists despite the engineering effort

**How to avoid:**
Invert the priority. Fix the song pool first, taste profile second:
1. **Phase 1**: Curate a seed database of known-good running songs per genre/BPM range. Even 50-100 verified songs per genre is transformative compared to random GetSongBPM results.
2. **Phase 2**: Add a simple "running quality" flag or score to curated songs (binary: is/isn't a good running song, or a 1-5 rating).
3. **Phase 3**: Only then consider taste profile improvements -- and only where the curated pool is large enough that taste differentiation matters.

The current taste profile (1-5 genres, 0-10 artists, energy level) is actually well-designed for the problem size. The bottleneck is not taste understanding -- it's song selection.

**Warning signs:**
- The taste profile screen gets more complex but playlist satisfaction doesn't improve
- A/B testing (if possible) shows taste profile changes have no effect on user behavior
- User feedback mentions specific songs ("why is this in my playlist?") rather than categories
- The team debates adding more taste dimensions before verifying the song pool is good

**Phase to address:**
This is a *prioritization* pitfall, not a technical one. The roadmap must sequence song pool quality improvement before taste profile sophistication.

**Confidence:** HIGH -- this is a well-documented pattern in recommendation systems: improving the ranker has diminishing returns when the candidate set is poor. "Garbage in, garbage out" applies directly.

---

### Pitfall 4: Scraping Running Song Lists Without Understanding Legal and Data Quality Risks

**What goes wrong:**
To populate the curated running song database, the team scrapes "Best Running Songs" lists from Runner's World, Cosmopolitan, timeout.com, etc. This creates three compound problems:
1. **Legal risk**: Scraping copyrighted curated lists may violate terms of service and copyright. The scraped data is someone else's editorial work.
2. **Data quality**: These lists mix genuine running songs with promotional placements, recency bias, and editorial preferences that may not match running suitability.
3. **Data reconciliation**: Song names and artists from scraped lists don't always match GetSongBPM's identifiers, requiring fuzzy matching that introduces errors.

**Why it happens:**
It feels like the fastest path to "lots of data." Manually curating 500+ songs across 15 genres is tedious. Scraping automates the collection.

**Consequences:**
- ToS violations can result in legal action (unlikely for small apps, but ToS enforcement is unpredictable)
- Scraped lists skew heavily toward English-language pop/rock, leaving genres like K-Pop, Latin, and Metal with poor coverage
- Fuzzy matching between scraped song names and GetSongBPM IDs introduces phantom entries (song exists in curated data but can't be found via API) or wrong matches (different songs with similar names)
- Data staleness: scraped lists from 2023 include songs that may no longer be available on streaming platforms

**How to avoid:**
Use legitimate data sources and manual curation:
1. **GetSongBPM's own data**: The API returns songs by BPM. Use this as the candidate pool, then manually verify running suitability. No scraping needed.
2. **Public playlists**: Spotify and YouTube Music public playlists tagged with "running" are user-generated and can be referenced (not scraped) for inspiration. Note song names, then look them up via GetSongBPM.
3. **Community curation**: jog.fm's model -- users submit songs they run to -- is the gold standard. Build a lightweight song submission/voting feature for the app itself.
4. **Manual seed curation**: Start with 20-30 personally verified running songs per genre. This is enough for a meaningful quality improvement over random BPM matching.

For any data collected, store the source and date so stale entries can be identified.

**Warning signs:**
- The curation plan starts with "we'll scrape X website"
- Genre coverage is heavily skewed toward English-language pop
- More than 10% of curated song IDs don't resolve when looked up via GetSongBPM API
- No source attribution on curated entries

**Phase to address:**
Data sourcing phase -- must be designed before curation begins. The sourcing strategy determines the entire data pipeline architecture.

**Confidence:** HIGH -- web scraping legality is well-documented; music metadata inconsistency is a known industry problem ("Copyright's critical mess: music metadata" -- Kluwer Copyright Blog).

---

### Pitfall 5: Song Quality Score Based on Spotify Audio Features That No Longer Exist

**What goes wrong:**
The natural approach to "running quality scoring" is to use Spotify Audio Features (energy, danceability, valence, tempo, loudness) to compute a running suitability score. Every blog post and tutorial about music recommendation uses these features. But Spotify deprecated Audio Features in November 2024 and returns 403 for new apps. The team spends time designing scoring models around features they cannot actually access.

This was the critical v1.0 pitfall (#1 in the original research), but it manifests again in v1.1 in a subtler form: even if you don't plan to call Spotify's API directly, you might design a scoring model that *assumes* these features exist in your data, planning to get them "from somewhere." GetSongBPM returns `danceability` and `acousticness` but NOT energy, valence, loudness, or the full feature set. The scoring model designed around 7 features breaks when only 2 are available.

**Why it happens:**
All the recommendation system literature and blog posts reference Spotify Audio Features. They are deeply embedded in how developers think about music scoring. It's easy to design a model using them and assume "we'll source the data somehow."

**How to avoid:**
Design the scoring model exclusively around data you can actually obtain:
- **From GetSongBPM API**: BPM, danceability, acousticness, time signature, key
- **From curated data**: manually assigned running suitability flags, genre tags, verified BPM accuracy
- **From user behavior**: skip rates, repeat plays, "thumbs up/down" on individual songs (future feature)

Do NOT design features requiring energy, valence, or loudness unless you have a confirmed source for them. If a third-party API like SoundNet or ReccoBeats can provide these, verify it works before building features on top of it.

**Warning signs:**
- Scoring model design documents reference "energy" or "valence" without a confirmed data source
- The BpmSong model gets new fields that no API actually populates
- Tests use hardcoded feature values that came from Spotify documentation examples

**Phase to address:**
Scoring model design phase -- audit available data fields from GetSongBPM before designing the scoring function. The model must be grounded in accessible data.

**Confidence:** HIGH -- confirmed by direct API experience in v1.0 and Spotify developer blog.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcoding running quality scores in JSON | No backend needed, fast to implement | Cannot update without app release; scores become stale; no user feedback loop | MVP/prototype only, with remote update path planned |
| Single composite score instead of separate dimensions | Simpler data model, easier to sort | Cannot tune taste vs. suitability independently; genre bias baked in | Never -- always keep running suitability and taste match separate |
| Bundling entire curated database as Flutter asset | Offline-first, simple architecture | Stale data, large app bundle, no incremental updates | Only as fallback baseline, with remote fetch as primary path |
| Using `SharedPreferences` for curated song data | Consistent with v1.0 patterns | SharedPreferences has a ~1MB practical limit on some platforms; poor query performance for large datasets | Acceptable for < 500 songs; migrate to SQLite/Drift if larger |
| Estimating song duration at 210 seconds for all songs | Simple calculation, already works in v1.0 | Playlists overshoot or undershoot duration by up to 2 minutes per hour; perceived as inaccurate | Acceptable until actual duration data is available |
| Adding taste dimensions without A/B validation | Feels like progress | Complexity without proven value; longer questionnaire without better results | Only when song pool is large enough that taste differentiation matters |

## Integration Gotchas

Common mistakes when connecting to external services in this domain.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| GetSongBPM `/tempo/` endpoint | Assuming genre filtering exists on the tempo endpoint -- it does not. Songs returned are across all genres. | Filter by genre client-side after fetching. Cache broadly, filter narrowly. Accept that API calls return cross-genre results and your curation layer handles genre matching. |
| GetSongBPM song IDs | Assuming song IDs are stable forever. IDs can change if GetSongBPM re-indexes their database. | Store song title + artist as the canonical key, use song ID as a cache optimization only. Always fall back to title/artist matching. |
| GetSongBPM danceability/acousticness | Assuming these are on the same 0-1 scale as Spotify's deprecated features. They may use different algorithms and scales. | Treat GetSongBPM's danceability as an independent measure. Do not compare to Spotify documentation values. Calibrate thresholds empirically against known running songs. |
| Supabase for curated data | Over-designing the schema with full relational models (songs, artists, genres, tags, votes) before having any data. | Start with a single `curated_songs` table: `id, title, artist, bpm, genre, running_quality, source, updated_at`. Normalize later only if needed. |
| Remote JSON fetch for curated data | No versioning, so the app refetches the full dataset every launch. | Include a `version` or `last_modified` header. Only download when version > cached version. Reduces bandwidth and startup time. |

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Loading entire curated song database into memory on app start | Startup lag, high memory usage on low-end Android devices | Lazy-load by genre/BPM range on demand, keep only active segment's candidates in memory | > 2,000 curated songs, or on devices with < 2GB RAM |
| SharedPreferences storing large JSON blobs for curated data | `getString()` blocks the platform channel; noticeable jank when reading | Use SQLite/Drift for structured data > 500 entries; SharedPreferences for small config only | > 500 curated songs or > 100KB JSON |
| Scoring all candidates on every playlist generation | Fine with 50 songs; O(n * m) with n candidates and m taste dimensions | Pre-compute running suitability scores at data ingestion time; only compute taste match at generation time | > 500 candidates per BPM value |
| Re-fetching curated data on every app launch | Wastes bandwidth, adds latency to first playlist generation | Cache with version check; only fetch delta or full set when version mismatch | Always wasteful, but becomes user-visible with > 1MB curated dataset |

## UX Pitfalls

Common user experience mistakes specific to this domain.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Showing a numerical "running quality score" (e.g., 85/100) next to each song | Users argue with the score ("this song is NOT an 85!"), focus on the number instead of enjoying the playlist. Creates distrust in the system. | Use quality scoring internally for ranking only. Never show the raw score to users. If anything, show a simple badge: "Popular running song" or a heart icon. |
| Stride adjustment that changes BPM by > 5 per nudge | One "a bit fast" tap changes cadence from 170 to 160, which is a completely different song pool. The playlist changes dramatically for a minor adjustment. | Nudge in increments of 2-3 BPM. Running cadence adjustment in practice is subtle (168 vs 172, not 170 vs 160). Show the BPM changing in real-time so users understand the effect. |
| "Quick action" repeat flow that skips the run plan screen entirely | Users who changed their run plan since last time get a playlist for outdated parameters. Confusion: "I wanted 10K today but got my usual 5K playlist." | Default to last-used parameters but always show a confirmation step with distance, pace, and run type visible. One-tap "Same run, fresh playlist" with visible parameters, not invisible defaults. |
| Post-activity adjustment that requires re-generating the entire playlist | User just finished a run, wants to tweak cadence for next time. Being forced to wait for API calls and playlist generation is frustrating. | Save the cadence adjustment immediately (one tap: "a bit fast" / "just right" / "a bit slow"). Apply it to the *next* playlist generation. Don't re-generate the current one. |
| Taste profile changes that silently invalidate cached/curated data | User updates genres, but the cached playlist and curated data rankings are still based on old preferences. Next playlist seems to ignore the changes. | When taste profile changes, clear relevant caches or at minimum flag that the next generation should skip cached rankings. Show "Preferences updated -- your next playlist will reflect this." |
| Overwhelming users with new v1.1 features on upgrade | Existing v1.0 users suddenly see stride adjustment buttons, quality indicators, and a modified taste profile flow. Cognitive overload. | Introduce new features progressively. Stride adjustment appears only after the first playlist generation (contextual). Quality improvements are invisible (better ranking, same UI). |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Song quality scoring:** Model produces scores, but no validation against actual runners' preferences -- verify by having 5+ runners rate 20 songs and comparing to model output
- [ ] **Curated database:** 200 songs added, but coverage skewed to 3-4 genres -- verify minimum 15 songs per selected RunningGenre
- [ ] **Curated database:** Songs have BPM values, but not verified against GetSongBPM IDs -- verify every curated song resolves to a valid GetSongBPM entry
- [ ] **Curated database:** Remote fetch works, but no fallback when network unavailable -- verify app works in airplane mode with bundled baseline
- [ ] **Stride adjustment:** +/- buttons exist, but the adjusted cadence is not persisted -- verify adjustment survives app restart
- [ ] **Stride adjustment:** Cadence changes, but the next playlist generation still uses the old cadence -- verify the adjustment flows through to `RunPlan.segments[].targetBpm`
- [ ] **Repeat flow:** "Generate again" button exists, but it re-uses the exact same song pool (no variety) -- verify repeat generation shuffles or cycles through different curated songs
- [ ] **Repeat flow:** Quick action preserves last run parameters, but not the latest stride adjustment -- verify stride nudge from previous run is reflected in quick-action defaults
- [ ] **Taste profile update:** Genres changed, but curated song filter still uses old genres until app restart -- verify real-time reactivity of genre filter in playlist generation
- [ ] **Scoring integration:** Quality scoring works in isolation, but `PlaylistGenerator.generate()` was not updated to use it -- verify the generator actually reads and applies quality scores

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Single composite score baked into curated data | MEDIUM | Add separate `running_suitability` and `taste_relevance` columns; backfill from composite score using genre heuristics; update generator to use both |
| Curated data bundled as immutable asset | LOW | Add Supabase table + remote fetch layer; keep bundled data as fallback; version the remote data |
| Over-engineered taste profile | LOW | Revert to simple profile; keep extra fields but make them optional/hidden; data migration is backward-compatible since TasteProfile.fromJson handles missing fields |
| Scraped data with legal issues | HIGH | Remove all scraped entries; rebuild from legitimate sources; audit every curated entry for source provenance |
| Scoring model depends on unavailable audio features | MEDIUM | Strip unavailable features from model; re-weight remaining features; accept reduced model quality until alternative data source found |
| SharedPreferences overloaded with curated data | MEDIUM | Migrate to SQLite/Drift; convert SharedPreferences entries to database rows; update all read/write paths |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Single universal score (#1) | Scoring model design | Score has separate `runningSuitability` and `tasteMatch` dimensions in data model |
| Immutable bundled data (#2) | Data layer architecture | Curated data can be updated via Supabase without app release; verified by changing a value remotely and seeing it in-app |
| Over-engineering taste profile (#3) | Roadmap sequencing | Song pool quality phase completes before taste profile changes; user satisfaction measured before/after |
| Scraping legal/quality risks (#4) | Data sourcing strategy | Every curated entry has a `source` field; no entries sourced from scraped copyrighted lists |
| Unavailable audio features (#5) | Scoring model design | Every field in the scoring model maps to a confirmed data source; no orphan features |
| Stride nudge too aggressive (UX) | Stride adjustment UX | Nudge increment is 2-3 BPM; tested with actual runners for feel |
| Repeat flow with stale parameters (UX) | Quick action design | Confirmation screen shows all parameters; stride adjustment from last run is reflected |
| Curated data genre gaps | Data curation | Minimum song count per genre verified before feature is considered complete |

## Sources

- [ForeverFitScience: The Science Behind Good Running Music](https://foreverfitscience.com/running/good-running-music/) -- research on music complexity and synchronization effects on running performance
- [PLOS One: Optimizing beat synchronized running to music](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0208702) -- phase alignment and tempo matching research
- [Kluwer Copyright Blog: Copyright's critical mess: music metadata](https://copyrightblog.kluweriplaw.com/2025/03/13/copyrights-critical-mess-music-metadata/) -- music metadata quality issues
- [ScraperAPI: Is Web Scraping Legal? 2026 Guide](https://www.scraperapi.com/web-scraping/is-web-scraping-legal/) -- legal framework for data scraping
- [jog.fm FAQ](https://jog.fm/pages/faq) -- community-driven running song curation model
- [Spotify developer blog: API changes Nov 2024](https://developer.spotify.com/blog/2024-11-27-changes-to-the-web-api) -- Audio Features deprecation
- [GetSongBPM API documentation](https://getsongbpm.com/api) -- available data fields and limitations
- [Shorebird documentation](https://docs.shorebird.dev/code-push/) -- code push limitations (Dart only, no assets)
- [Music Tomorrow: Fairness in Music Streaming Algorithms](https://www.music-tomorrow.com/blog/fairness-transparency-music-recommender-systems) -- popularity bias in recommendation systems
- [LinkedIn: Cold Start Problem in Music Recommendation](https://www.linkedin.com/advice/0/how-do-you-deal-cold-start-problem-long-tail-music) -- cold start mitigation strategies

---
*Pitfalls research for: v1.1 Experience Quality -- Running Playlist AI*
*Researched: 2026-02-05*
