# Project Research Summary

**Project:** Running Playlist AI - v1.3 Song Feedback & Taste Learning
**Domain:** Music recommendation feedback loops, taste learning algorithms, playlist freshness tracking
**Researched:** 2026-02-06
**Confidence:** HIGH

## Executive Summary

v1.3 adds intelligent feedback loops to the Running Playlist AI's existing BPM-matched playlist generator. The research reveals that this milestone can be built entirely with the existing tech stack (Flutter, Riverpod 2.x, SharedPreferences) without adding any new dependencies. The core insight: single-user taste learning from explicit binary feedback is a frequency counting problem, not a machine learning problem. With a bounded dataset of ~5,000 curated songs and user-generated feedback on <4,000 entries over the app's lifetime, SharedPreferences handles all persistence needs with no performance concerns.

The recommended approach extends the existing `SongQualityScorer` with three new dimensions: feedback (+12 for liked, -20 for disliked), freshness (-8 for recently generated songs), and learned preferences (max +4 for implicit patterns). These integrate cleanly into the established pure-function scoring architecture. The key architectural decision is keeping feedback scoring separate from the TasteProfile model—feedback is a per-song signal that supplements but never overrides the user's explicit preferences.

Critical risks center on scoring balance and filter bubbles. If feedback weights are too high, liked songs dominate every playlist regardless of running suitability, breaking the app's core value proposition. If freshness tracking is absent or weak, the feedback loop converges on the same 20-30 songs and playlists become stale. Both risks are mitigated through careful weight selection (feedback weaker than runnability, freshness strong enough to penalize recent plays) and extensive testing with simulated feedback data before shipping.

## Key Findings

### Recommended Stack

**Zero new dependencies required.** All v1.3 features extend the existing stack: SharedPreferences for persistence, Riverpod StateNotifier for reactive state, pure Dart for taste learning algorithms, and the established `SongQualityScorer` for feedback integration.

**Core technologies (existing, reused):**
- **SharedPreferences 2.5.4**: Feedback storage (~600 KB at 4,000 entries), freshness timestamps (~320 KB), settings toggle. Total new footprint <1 MB fits comfortably within practical limits.
- **Riverpod 2.x manual providers**: New `SongFeedbackNotifier`, `FreshnessNotifier` follow existing patterns from `TasteProfileNotifier` and `PlaylistHistoryNotifier`.
- **Pure Dart statistical analysis**: Taste learning via frequency counting (genre affinity, artist patterns, BPM clustering) requires only basic iteration and arithmetic. No tflite_flutter, no ML libraries—single-user data is too sparse for collaborative filtering.

**Critical non-addition:** Did NOT add database (Drift/SQLite/Hive). Data volume analysis shows SharedPreferences handles feedback + freshness data with no scaling issues through realistic heavy-use scenarios (2-3 playlists/week for 2+ years). Code-gen is broken with Dart 3.10, making Drift integration risky. Introducing a database for <1 MB of data creates architectural complexity disproportionate to the problem.

### Expected Features

**Must have (table stakes from competitive analysis):**
- **Like/dislike buttons on every song tile** — Standard across Spotify, Apple Music, Pandora, YouTube Music. Users expect inline feedback. Use thumbs up/down (explicit feedback intent) not hearts (hearts imply "save to library").
- **Liked songs boost scoring** — Every platform prioritizes user-endorsed songs. Feedback dimension adds +12 to score, positioning it between artist match (+10) and runnability max (+15).
- **Disliked songs heavily penalized** — Pandora never plays thumbed-down songs again. Apply -20 penalty (effectively filtering without hard-exclusion). User intent is unambiguous: "do not include this."
- **Feedback library screen** — Apple Music's "Loved Songs," Spotify's "Liked Songs." Users need to review/edit feedback decisions. Two-tab view (Liked / Disliked), clear feedback with single tap.
- **Visual feedback state on tiles** — Once rated, the state must persist across screens and app restarts. Filled thumb icon + color state reflects feedback everywhere the song appears.

**Should have (competitive differentiators):**
- **Post-run review screen** — Novel in BPM-matching space. No competitor (RockMyRun, PaceDJ, Weav Run, Spotify) offers post-session review. Captures feedback while run experience is fresh. Makes feedback low-friction (all songs in one view).
- **Taste learning from feedback patterns** — Analyze liked/disliked songs to discover implicit preferences (e.g., 70% of liked songs are Electronic but user's profile only has Pop). Surface as suggestions: "Add Electronic to your profile?" Transparency preserves user agency.
- **Freshness toggle: "Keep it Fresh" vs "Optimize for Taste"** — User-controllable variety. Fresh mode applies recency penalty; Taste mode ignores play history. Two clear modes easier to understand than a freshness slider.
- **Freshness scoring dimension** — Track when songs last appeared in generated playlists. Apply stepped decay penalty: -8 if <3 days, -5 if 3-7 days, -3 if 7-14 days, -1 if 14-30 days, 0 if 30+ days. Prevents "same 15 songs every run" convergence.
- **Disliked artist auto-detection** — When user dislikes 3+ songs by same artist, suggest adding to TasteProfile.dislikedArtists. Bridges song-level feedback to existing artist-penalty system (-15 weight).

**Defer (anti-features or v2+):**
- **5-star ratings** — Research shows binary feedback outperforms rating scales for music (Cornell Piki research, Pandora's 75B feedback data points). Binary is faster, clearer, more actionable.
- **Automatic taste profile modification** — Never auto-update the TasteProfile from learned patterns. Users explicitly set preferences; silent changes violate trust. Use suggestion-based approach instead.
- **Collaborative filtering / ML** — Single-user dataset (<4,000 entries) is too small for collaborative filtering or neural networks. Frequency analysis achieves better results with this data profile.
- **Real-time feedback during generation** — Generation is subsecond; adding approval workflow slows UX. Post-generation feedback (swipe-to-dismiss + like/dislike) serves this need.

### Architecture Approach

**Extend existing scoring architecture with new data sources.** The `SongQualityScorer` remains a pure-function static scorer; feedback, freshness, and learned preferences are passed as parameters from `PlaylistGenerator`, which receives them from `PlaylistGenerationNotifier` via new Riverpod providers. This preserves testability and keeps domain logic pure.

**Major components:**

1. **SongFeedbackNotifier** — In-memory `Map<String, SongFeedback>` loaded at app start, write-through on changes. Provides O(1) feedback lookup during scoring. Follows exact pattern from `TasteProfileNotifier`.

2. **SongQualityScorer extensions** — Add `isLiked` parameter to `score()` method. Liked: +12, Disliked: -20, Neutral: 0. Keeps feedback weaker than runnability (max +15) but stronger than genre match (+6). Prevents feedback from overriding running suitability.

3. **PlaylistGenerator freshness integration** — Apply freshness penalty in `_scoreAndRank` after scorer returns base score. Penalty only active when `FreshnessMode.keepFresh`. Pre-compute `Set<String>` of recent song keys (last 14 days) for O(1) lookup. Pattern matches existing `curatedRunnability` map.

4. **TasteLearner (pure analyzer)** — Synchronous function: `List<SongFeedback> -> LearnedPreferences`. Groups feedback by genre/artist/decade, computes affinity ratios, requires minimum 5 samples per category. Produces affinity map (-1.0 to +1.0) that translates to scoring adjustments (max ±4 points). Runs at generation time, O(n) on feedback list (~5-10ms at 4,000 entries).

5. **PlayHistory tracking** — After generation, record all songs with current timestamp. 90-day rolling window trimmed on save. Feeds freshness penalty calculation. Separate from feedback (songs get played regardless of whether user likes them).

**Component boundaries:** New `song_feedback/` and `freshness/` feature directories follow established `data/domain/presentation/providers` structure. Modified components: `SongQualityScorer` (+1 parameter), `PlaylistGenerator` (+3 parameters), `PlaylistGenerationNotifier` (reads new providers), `SongTile` (+feedback callbacks).

### Critical Pitfalls

1. **Feedback score dimension destabilizes scoring balance** — If liked bonus is too high (+15+), feedback overrides running suitability and mediocre songs dominate playlists. If too low (+2), feedback feels ineffective. **Mitigation:** Cap liked at +12 (between artist match and runnability max). Test with mock data: liked song with poor metrics must NOT outrank unrated song with excellent metrics. Disliked at -20 effectively buries songs without hard-filtering.

2. **Filter bubble — feedback loop narrows playlist to same 20 songs** — Liked songs boost scoring, appear more often, get reinforced. Within 10 generations, user sees only their ~30 liked songs. **Mitigation:** Freshness penalty (-8 for recent plays) is essential counter-force. Must be built in parallel with feedback, not deferred. Consider exploration slot: force 1-2 unrated songs per segment for discovery.

3. **SharedPreferences JSON blob grows unbounded** — Feedback + play history could exceed 1.5 MB over heavy use. Android SharedPreferences loads entire file at app start; 1.5 MB causes 200-500ms lag. **Mitigation:** Compact storage (skip timestamps, single-char enum), 90-day rolling window for play history, cap feedback at 3,000 entries with LRU eviction if needed. Total footprint stays <1 MB.

4. **Taste learning overfits to explicit feedback, ignoring TasteProfile** — User sets Pop + Electronic in profile, likes 10 Hip-Hop songs. Learning infers "boost Hip-Hop." Next playlist is 40% Hip-Hop. User confused. **Mitigation:** Feedback adjusts song-level scores; learned preferences are separate low-weight signals (max +4). Never auto-modify TasteProfile. Surface insights as suggestions user can accept/dismiss.

5. **Song lookup key mismatch between sources** — Curated: "dua lipa|don't start now", API: "dua lipa|don't start now (feat. x)". Keys don't match, feedback not applied. **Mitigation:** Normalize keys more aggressively (strip parentheticals, remove non-alphanumeric except |). Store feedback against curated key when available. Implement fuzzy fallback (artist match + title prefix match).

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Feedback Foundation
**Rationale:** Everything depends on having feedback data. SongFeedback model, persistence (SongFeedbackPreferences), and state management (SongFeedbackNotifier) must exist before UI or scoring integration can be built.

**Delivers:**
- SongFeedback domain model with artist, title, isLiked, feedbackAt, genre, bpm, decade
- SongFeedbackPreferences (SharedPreferences wrapper, follows TasteProfilePreferences pattern)
- SongFeedbackNotifier (in-memory Map, write-through persistence)
- Unit tests for model serialization and notifier CRUD

**Features:** None user-visible. Pure data layer.

**Avoids:** Pitfall #5 (lookup key mismatch). Key normalization strategy decided here before any feedback persisted.

**Research flag:** Standard patterns. Skip phase-level research.

---

### Phase 2: Feedback UI + Scoring Integration
**Rationale:** With data layer complete, close the full feedback loop: user gives feedback -> stored -> next generation uses feedback. This delivers immediate user value.

**Delivers:**
- SongTile modifications (like/dislike buttons, visual state: filled/outlined icons)
- PlaylistScreen wiring (pass callbacks to SongTile, read feedback provider)
- SongQualityScorer feedback dimension (isLiked parameter, +12/-20 weights)
- PlaylistGenerator feedback parameter (Map<String, bool> feedbackMap)
- PlaylistGenerationNotifier reads feedback provider, passes to generator
- Add genre + decade fields to PlaylistSong model (needed for feedback metadata capture)

**Features:** Like/dislike buttons (table stakes), liked songs boost scoring (+12), disliked songs penalized (-20), visual state persistence.

**Avoids:** Pitfall #1 (scoring balance). Extensive unit tests verify liked songs with poor running metrics do NOT override unrated songs with excellent metrics.

**Research flag:** Standard patterns. Skip phase-level research.

---

### Phase 3: Feedback Library Screen
**Rationale:** Quality-of-life feature that builds user trust. Lets users review/edit/undo feedback decisions. Not required for core loop but important for transparency and control.

**Delivers:**
- FeedbackLibraryScreen (two-tab view: Liked / Disliked)
- List all feedback entries, show song title/artist/date
- Tap to toggle feedback (liked -> neutral, disliked -> neutral, liked -> disliked)
- Search/filter by artist (optional but recommended)
- GoRouter route + navigation from settings or home

**Features:** Feedback library screen (table stakes), undo feedback.

**Avoids:** No specific pitfall mitigation. Supports recovery from Pitfall #8 (blacklist spiral) by making it easy to un-dislike songs.

**Research flag:** Standard patterns. Skip phase-level research.

---

### Phase 4: Freshness Tracking
**Rationale:** Freshness prevents filter bubbles. Must be built alongside feedback (not deferred to v1.4+) to provide counter-force against liked-song reinforcement.

**Delivers:**
- SongPlayRecord model (songKey, playedAt)
- PlayHistoryPreferences (90-day rolling window, trimmed on save)
- PlayHistoryNotifier (record plays after generation, expose recent song keys Set)
- FreshnessMode enum (keepFresh vs optimizeForTaste)
- FreshnessPreferences (toggle state persistence)
- FreshnessSettingNotifier (expose mode to UI)
- SettingsScreen freshness toggle UI (SwitchListTile or SegmentedButton)
- PlaylistGenerator freshness penalty (apply -8 to -1 decay based on recency, only if keepFresh mode)
- PlaylistGenerationNotifier records play history after generation

**Features:** Freshness tracking, freshness scoring dimension, freshness toggle UI.

**Avoids:** Pitfall #2 (filter bubble). Freshness penalty (-8 for <3 days) deprioritizes recently-used songs, ensuring variety across sessions.

**Avoids:** Pitfall #6 (small BPM pool). Scale penalty by pool size—if <50 BPM-eligible songs, reduce or disable freshness.

**Research flag:** Standard patterns. Skip phase-level research.

---

### Phase 5: Post-Run Review (Optional MVP)
**Rationale:** Novel differentiator in running music space. Captures feedback while run experience is fresh. Can be deferred to v1.4 if timeline is tight.

**Delivers:**
- Home screen card: "Rate your last playlist" (triggered when recent unreviewed playlist exists)
- Dedicated review screen showing all songs from last playlist with feedback buttons
- Skippable flow (not a blocking modal)
- Mark playlist as "reviewed" to prevent re-prompting

**Features:** Post-run review screen (differentiator).

**Avoids:** Pitfall #7 (feedback fatigue). Review is optional, not forced. User can dismiss or skip entirely.

**Research flag:** UX patterns need light validation. Consider user testing on feedback friction.

---

### Phase 6: Taste Learning (Post-MVP)
**Rationale:** Requires accumulated feedback data (minimum 10 entries). By this phase, users have generated 5+ playlists and provided feedback. Taste learning is experimental—weights/thresholds may need tuning.

**Delivers:**
- TasteLearner static analyzer (feedback list -> LearnedPreferences)
- LearnedPreferences model (genre/artist/decade affinities, BPM center)
- Integration into PlaylistGenerator (apply learned preference bonus, max ±4 points)
- Suggestion cards on home screen ("Add Electronic to your profile?")
- Suggestion acceptance -> TasteProfile.copyWith()

**Features:** Taste learning from feedback patterns, suggestion-based profile updates, disliked artist auto-detection.

**Avoids:** Pitfall #4 (taste learning overfit). Learned preferences are low-weight (max +4), transparent (surfaced as suggestions), and never auto-modify TasteProfile.

**Research flag:** Needs experimentation. Consider `/gsd:research-phase` for tuning affinity thresholds and weights.

---

### Phase Ordering Rationale

- **Phases 1-2 are tightly coupled:** Data layer must exist before UI/scoring. Building both delivers the minimum viable feedback loop.
- **Phase 3 is independent:** Library screen can be built anytime after Phase 1. Placed here because it's lower priority than closing the scoring loop.
- **Phase 4 MUST come before Phase 5-6:** Freshness prevents filter bubbles. Shipping feedback without freshness creates the #2 critical pitfall. Phases 5-6 (review, learning) amplify feedback collection; freshness ensures variety survives that amplification.
- **Phase 5 is optional MVP:** Post-run review is a differentiator but not essential for core loop. Can defer to v1.4 if timeline is tight.
- **Phase 6 requires data:** Taste learning needs 10+ feedback entries. By placing it last, earlier phases have time to accumulate data.

### Research Flags

**Phases needing deeper research during planning:**
- **Phase 6 (Taste Learning):** Affinity calculation thresholds, scoring weights for learned preferences, suggestion UI patterns—all need experimentation. Consider `/gsd:research-phase` for tuning.

**Phases with standard patterns (skip research):**
- **Phase 1 (Feedback Foundation):** Established SharedPreferences + Riverpod patterns from existing codebase.
- **Phase 2 (Feedback UI + Scoring):** Widget extension, scoring parameter addition—both follow existing patterns.
- **Phase 3 (Feedback Library):** Standard list screen, matches TasteProfileLibraryScreen structure.
- **Phase 4 (Freshness Tracking):** Timestamp storage, rolling window trim—established persistence patterns.
- **Phase 5 (Post-Run Review):** Standard screen + card prompt, similar to onboarding flow.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Direct codebase analysis confirms SharedPreferences patterns handle feedback/freshness data. Zero new dependencies validated against project memory (code-gen broken with Dart 3.10). |
| Features | HIGH | Competitive analysis across 7 platforms (Spotify, Apple Music, Pandora, YouTube Music, RockMyRun, PaceDJ, Weav Run) confirms table stakes and identifies differentiators. Binary feedback pattern validated by Cornell research + Pandora's 75B data points. |
| Architecture | HIGH | All integration points traced through existing codebase (SongQualityScorer, PlaylistGenerator, PlaylistGenerationNotifier, SongTile). New components follow established feature directory structure. |
| Pitfalls | HIGH | Critical pitfalls (#1-4) grounded in recommendation system research (filter bubbles, scoring balance, cold start). SharedPreferences performance limits validated against real dataset sizes. Lookup key mismatch pattern observed in existing code. |

**Overall confidence:** HIGH

### Gaps to Address

- **Optimal feedback weights (liked: +12, disliked: -20):** Research suggests this range, but tuning may be needed after user testing. Plan to make weights easily adjustable constants for rapid iteration in early beta.

- **Freshness decay curve:** Stepped decay (-8/-5/-3/-1/0) is informed by Spotify's engineering blog and ACT-R memory models, but exact thresholds are estimates. Monitor playlist variety metrics after launch; adjust curve if <30% song turnover across 5 consecutive generations.

- **Taste learning affinity thresholds:** Minimum 5 samples per category is a heuristic. Real usage may reveal this is too low (noisy patterns) or too high (learning never activates). Plan to expose threshold as a tunable parameter during Phase 6 implementation.

- **Lookup key normalization edge cases:** Parenthetical stripping and punctuation removal handle most API/curated mismatches, but rare edge cases may exist (e.g., "Pt. 1" vs "Part 1"). Build telemetry to log failed feedback lookups; address in patch if frequency >5%.

- **Post-run review adoption rate:** Unknown whether users will engage with review screen. If <20% adoption after 1 month, consider removing or redesigning as less intrusive prompt.

## Sources

### Primary (HIGH confidence)
- **Direct codebase analysis** — All files in SongQualityScorer, PlaylistGenerator, PlaylistGenerationNotifier, SongTile, SharedPreferences preferences classes. Patterns verified, integration points traced.
- **SharedPreferences v2.5.4 documentation** — API capabilities, storage characteristics, practical limits verified.
- **Flutter official storage cookbook** — SharedPreferences recommended for "relatively small collection of key-values."
- **Existing project memory** — Code-gen broken with Dart 3.10, Riverpod 2.x manual providers, Supabase init issues, pre-existing test failures documented.

### Secondary (MEDIUM confidence)
- **Spotify Recommendation System Complete Guide (Music Tomorrow, 2025)** — Explicit/implicit feedback weighting, taste clustering, freshness scoring, diversity injection patterns.
- **Cornell Research: Dislike Button Improves Recommendations** — Binary feedback effectiveness, Piki research system confirms binary outperforms rating scales.
- **Pandora Thumbs System Explained (SoftHandTech)** — 75B feedback data points, attribute-based learning, undo patterns, station-specific feedback.
- **Apple Music Algorithm Guide 2026 (BeatsToRapOn)** — Recency bias, diversity filtering, "Suggest Less" vs hard dislike patterns.
- **YouTube Music Algorithm Guide (BeatsToRapOn)** — Thumbs patterns, Music Tuner (filters), session-based variety.
- **ACT-R Memory Model for Music Recommendation (Springer, 2024)** — Time-decayed frequency/recency modeling for freshness decay curve.
- **SharedPreferences performance analysis (MoldStud)** — Performance characteristics for large data (>1 MB).
- **Flutter database comparison 2025 (DinkoMarinac)** — Drift, Hive, Isar alternatives assessment, Isar/Hive abandonment status.

### Tertiary (LOW confidence)
- **Implicit vs Explicit Feedback in Music Recommendation (ACM)** — Complementary relationship between feedback types, Last.fm study on feedback fatigue.
- **Negative Feedback for Music Personalization (ArXiv, 2024)** — How negative feedback improves recommendation quality.
- **Filter Bubbles in Recommender Systems: Fact or Fallacy (ArXiv)** — Systematic review of feedback loop reinforcement, echo chambers.
- **Measuring Recency Bias in Sequential Recommendation (ArXiv, 2024)** — Academic analysis of recency bias in recommendation systems.
- **Choosing the Right Weights: Balancing Value, Strategy, and Noise (ArXiv)** — Research on weight balancing in recommendation scoring systems.

---
*Research completed: 2026-02-06*
*Ready for roadmap: yes*
