# Feature Research: v1.3 Song Feedback, Taste Learning & Playlist Freshness

**Domain:** Song-level feedback systems, implicit taste learning from explicit feedback, playlist freshness/variety algorithms
**Researched:** 2026-02-06
**Confidence:** MEDIUM-HIGH -- feedback UX patterns well-established across Spotify, Apple Music, Pandora, YouTube Music; taste learning patterns verified through academic research and platform documentation; freshness algorithms documented in Spotify engineering blog and research papers; integration with existing codebase verified through direct code inspection

## Background: Current State and What This Milestone Adds

### What Exists Today

The app generates BPM-matched running playlists using an 8-dimension scoring system (`SongQualityScorer`). Users configure their preferences through `TasteProfile` objects containing genres, artists, energy level, vocal preference, tempo tolerance, decades, and disliked artists. Playlists are generated from a pool of ~5,066 curated songs plus API results, scored, ranked, and assigned to run segments.

The current feedback mechanism is **crude**: users can swipe-dismiss songs from a generated playlist and pick a replacement from a short suggestion list. There is no persistent memory of what songs the user liked or disliked. Every playlist generation starts fresh from the same scoring weights regardless of accumulated user behavior.

### What This Milestone Changes

This milestone adds three interconnected capabilities:

1. **Song feedback** -- Users can like/dislike individual songs. Feedback persists and accumulates.
2. **Taste learning** -- The system analyzes feedback patterns to discover implicit preferences (e.g., user consistently likes songs from the 2010s but never explicitly set a decade preference).
3. **Freshness** -- The system tracks which songs have appeared in generated playlists and can deprioritize recently-used songs.

### Key Constraint: Not a Streaming App

This app does NOT play music. Users generate playlists, review them, then listen externally via Spotify/YouTube links. This means:
- "Played" = "appeared in a generated playlist," not "was streamed through the app"
- There are no implicit signals like skip rate, completion rate, or listening duration
- All feedback must be **explicit** (user taps like/dislike) -- there is no passive signal to harvest
- Post-session review is different from mid-session feedback (user reviews the full playlist after running, not while running)

This is fundamentally different from Spotify/Pandora where the recommendation engine has rich implicit signals. Our system must work with sparse, explicit-only feedback.

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features that users who have used any music app will expect. Missing these makes the feedback system feel incomplete.

| Feature | Why Expected | Complexity | Dependencies | Notes |
|---------|--------------|------------|--------------|-------|
| **Like/dislike buttons on every song tile** | Every major music app (Spotify, Apple Music, YouTube Music, Pandora) provides inline feedback. Users expect to express preference on individual songs. In a running playlist context, this means "I enjoyed running to this" or "this was wrong for my run." | LOW | `PlaylistSong` model (exists), `SongTile` widget (exists). New: `SongFeedback` model, `SongFeedbackRepository` (SharedPreferences persistence). | The `SongTile` widget currently shows title, artist, BPM, match type, and star badge. Adding a like/dislike toggle is a visual addition plus a new data layer. Icon choice matters: use thumbs up/down (explicit feedback intent) not hearts (hearts imply "save to library" per Spotify convention). |
| **Visual feedback state on song tiles** | Once a user has liked or disliked a song, they expect to see that state reflected whenever they see that song again -- in the current playlist, in history detail, and in the feedback library. | LOW | `SongFeedback` model, `SongTile` widget. | Thumbs-up icon filled/highlighted for liked songs, thumbs-down for disliked. Neutral state (no feedback) shows outlined/unfilled icons. The visual state must persist across app restarts and appear on the same song in different playlists (matched by artist+title lookup key). |
| **Liked songs boost scoring** | Spotify, Pandora, and YouTube Music all prioritize songs the user has explicitly liked. A liked song should receive a scoring bonus in `SongQualityScorer` so it ranks higher in future playlists. | LOW | `SongQualityScorer` (exists), `SongFeedback` data. | Add a new scoring dimension: `+8 if song is liked`. This is comparable to the existing `artistMatchWeight` (+10). The bonus should be significant enough to noticeably promote liked songs but not so dominant that it overrides BPM matching or runnability. |
| **Disliked songs filtered or heavily penalized** | Every platform removes disliked songs from future recommendations. Pandora never plays a thumbed-down song again. Apple Music's "Suggest Less" suppresses the song. Users who dislike a song in a running app expect to never see it in a playlist again. | LOW | `SongQualityScorer` (exists), `SongFeedback` data, `PlaylistGenerator` (exists). | Two options: (A) Hard filter -- disliked songs are removed from the candidate pool before scoring. (B) Heavy penalty -- disliked songs get `-20` in scoring. Recommend option A (hard filter) because the user's intent is unambiguous: "I do not want this song." A penalty still allows the song to appear if the candidate pool is small. Hard filter matches Pandora's behavior and user expectations. |
| **Feedback library screen** | Users need a place to see all their feedback decisions, correct mistakes (undo a dislike), and review their liked songs. Apple Music has this (Loved Songs playlist), Spotify has Liked Songs. Without it, feedback feels like a black box. | MEDIUM | `SongFeedback` repository, new screen. | Screen shows two tabs or filters: Liked / Disliked. Each entry shows song title, artist, and the date of feedback. Tap to toggle feedback (change like to dislike or clear feedback entirely). Sort by most recent feedback. Search/filter optional but not MVP. |
| **Undo feedback** | Both Pandora and Apple Music allow undoing feedback. Users make mistakes, change their minds, or accidentally tap. Without undo, users feel locked into decisions. | LOW | `SongFeedback` repository. | Three states: liked, disliked, neutral (no feedback). Tapping the active icon again should clear feedback back to neutral. Tapping the opposite icon should switch (liked -> disliked). This is the standard toggle pattern. Additionally, show a brief snackbar with "Undo" action after any feedback tap (Spotify pattern). |
| **Feedback accessible from both playlist screen and history detail** | Users generate playlists and may want to give feedback immediately. But they also review past playlists (history detail screen) and want to give feedback retroactively after their run. Both surfaces must support like/dislike. | LOW | `SongTile` widget (shared between playlist screen and history detail screen). | Since `SongTile` is already shared across both screens, adding feedback to the widget automatically makes it available everywhere. The feedback state is stored by song identity (artist+title), not by playlist, so a like given on the history screen applies globally. |

### Differentiators (Competitive Advantage)

Features that go beyond standard music app patterns. These are where the running playlist context creates unique value.

| Feature | Value Proposition | Complexity | Dependencies | Notes |
|---------|-------------------|------------|--------------|-------|
| **Post-run review screen** | No competitor in the BPM-matching space offers a post-run review flow. After completing a run, the user opens the app and sees a "How was your playlist?" screen showing each song with like/dislike buttons and optional "perfect for running" / "not great for running" tags. This captures fresh feedback while the experience is vivid. Spotify has no post-session review. Pandora's feedback is real-time only. This is a novel UX for the running context. | MEDIUM | Playlist history (exists), feedback model, new screen or overlay. | The screen should be triggered when the user opens the app and a recently generated playlist (last 4 hours) has not been reviewed. Show songs in playlist order. Make it skippable ("Skip Review" button). The screen is purely for feedback collection -- it does not regenerate or modify the playlist. Consider: is this a new screen or a modal overlay on the home screen? Recommend: a card on the home screen that says "Rate your last playlist" that opens a dedicated review screen. Less intrusive than a modal. |
| **Taste learning from feedback patterns** | Analyze accumulated likes/dislikes to discover implicit preferences the user never explicitly set. Example: user consistently likes songs from the electronic genre but their taste profile only has Pop and Hip-Hop. The system detects this pattern and either (A) auto-updates the taste profile, or (B) suggests "We noticed you like Electronic -- add it to your profile?" This goes beyond simple scoring boosts -- it creates a feedback loop that improves the taste profile itself. No running music app does this. | HIGH | `SongFeedback` with genre/artist/decade metadata, `TasteProfile` model (exists), analysis logic. | Two approaches: (A) **Automatic updates** -- system silently adjusts taste profile weights. Risk: user loses control, recommendations shift without explanation. (B) **Suggestion-based** -- system surfaces insights as suggestions the user can accept or dismiss. "You've liked 8 electronic songs -- add Electronic to your genres?" This is more transparent and builds trust. Recommend option B (suggestion-based). Implementation: after N likes (threshold ~10), run pattern analysis on feedback metadata. Compare genre/artist/decade distribution of liked songs against current taste profile. Surface top 1-2 gaps as suggestions. |
| **Freshness toggle: "Keep it Fresh" vs "Optimize for Taste"** | Users sometimes want familiar favorites, sometimes want discovery. Spotify's approach is algorithmic (Favorites Mix vs Discover Weekly are separate playlists). Our approach can be simpler: a single toggle that controls how aggressively the generator deprioritizes recently-used songs. "Keep it Fresh" = strong recency penalty, more variety. "Optimize for Taste" = standard scoring, best-matching songs regardless of repetition. This is a clear, user-controllable preference that no running app offers. | MEDIUM | Freshness tracking (generation timestamps per song), `PlaylistGenerator` modification, UI toggle. | The toggle belongs on the playlist generation screen (next to the run plan and taste profile selectors). Default to "Optimize for Taste" for new users (they have no history to be fresh from). After the user has generated 5+ playlists, suggest switching to "Keep it Fresh." The toggle is a simple boolean that controls whether the freshness scoring dimension is active. |
| **Freshness tracking: "last appeared in playlist" timestamps** | Track when each song was last included in a generated playlist. This data powers the freshness scoring dimension. Songs that appeared recently get a penalty; songs that have not appeared in a while (or ever) get a bonus. Spotify does this internally for Discover Weekly and Daily Mix. | MEDIUM | New persistence layer: `SongAppearanceHistory` (SharedPreferences or lightweight local DB). Updated during playlist generation. | Store as a map: `songLookupKey -> DateTime lastGenerated`. Updated every time `PlaylistGenerator.generate()` produces a playlist. The map grows with usage but is bounded by the curated song pool size (~5,066 entries). SharedPreferences can handle this as a JSON blob. Consider periodic cleanup of entries older than 90 days. |
| **Freshness scoring dimension** | Add a new dimension to `SongQualityScorer` that penalizes recently-generated songs. The penalty decays over time (exponential decay matching human memory models). A song generated yesterday gets a strong penalty. A song generated 2 weeks ago gets a mild penalty. A song generated 2 months ago gets no penalty. | MEDIUM | `SongQualityScorer` (exists), freshness tracking data. | Suggested penalty curve: -8 if generated in last 3 days, -5 if last 7 days, -3 if last 14 days, -1 if last 30 days, 0 if older or never. This uses the same integer scoring system as existing dimensions. Max penalty (-8) equals the danceability max weight, making it significant but not overwhelming. Only active when freshness toggle is on. |
| **Disliked artist auto-detection** | When a user dislikes 3+ songs by the same artist, surface a suggestion: "You've disliked 3 songs by [Artist]. Add them to your disliked artists?" This bridges the gap between song-level feedback and artist-level preferences. Currently, the `dislikedArtists` list in `TasteProfile` requires manual entry. | LOW | `SongFeedback` with artist metadata, `TasteProfile.dislikedArtists` (exists). | Pattern detection: group disliked songs by artist. If count >= 3, trigger suggestion. This is a specific case of the broader taste learning feature but is called out separately because the existing `dislikedArtistPenalty` (-15) is already the strongest negative signal in the scorer. Auto-detecting disliked artists bridges explicit feedback to the existing scoring system with minimal new logic. |

### Anti-Features (Deliberately NOT Building)

| Feature | Why It Seems Useful | Why It Is Problematic | What to Do Instead |
|---------|--------------------|-----------------------|-------------------|
| **Star ratings (1-5 scale)** | "More granular feedback gives better signal" | Research consistently shows binary feedback (like/dislike) outperforms rating scales for music. Cornell's Piki research found that binary feedback trained algorithms just as effectively as scaled ratings. Users also rate inconsistently -- a 3-star today might be a 4-star tomorrow. Pandora's entire business was built on binary thumbs. Adding granularity adds cognitive load without improving recommendation quality. In a running context, the user's evaluation is inherently binary: "good for running" or "not good for running." | Binary like/dislike. Two taps, zero cognitive load. |
| **Feedback on runs rather than songs** | "Rate the whole playlist as good/bad for this run" | A playlist is a collection of songs. Rating the whole playlist loses the granular signal about WHICH songs worked and which did not. A 10-song playlist where 8 songs were great and 2 were terrible gets a "good" rating that teaches the system nothing about the 2 bad songs. | Song-level feedback. The post-run review screen makes it fast to rate all songs individually. |
| **Skip detection / implicit feedback** | "Track which songs the user skips when listening externally" | The app does not control playback. Users listen on Spotify or YouTube Music. There is no way to detect skips, completion rates, or listening duration. Any attempt to approximate this (e.g., "did they tap the next song link quickly?") would be unreliable guesswork. | Rely exclusively on explicit feedback (like/dislike taps). Be transparent about it. |
| **Automatic taste profile modification** | "Auto-update the taste profile based on feedback patterns" | Violates user agency. The taste profile is the user's explicit declaration of their preferences. Silently modifying it creates confusion ("I set Pop and Hip-Hop but now I'm getting Electronic -- did I change something?"). Research on music recommendation transparency (2025 Fairness review, Music Tomorrow) emphasizes that users must understand WHY recommendations change. | Suggestion-based learning. Surface insights as cards the user can accept or dismiss. "We noticed you like Electronic songs -- add to your profile?" User stays in control. |
| **Collaborative filtering** | "Recommend songs that similar users liked" | Requires a multi-user backend, usage analytics, and sufficient user base for meaningful patterns. The app is local-first with no user accounts. Even with a backend, the running music niche is too narrow for reliable collaborative filtering -- a user who likes EDM for running might hate EDM while working. Context-dependent preferences break collaborative filtering assumptions. | Content-based filtering through the existing scoring system + explicit feedback. The 8-dimension scorer already captures what makes a song good for running. Feedback refines this per-user. |
| **Mood/energy tagging on feedback** | "Let users tag WHY they liked/disliked (too slow, too intense, wrong genre)" | Adds friction to feedback. Every extra tap reduces feedback rates. Pandora found that simple thumbs up/down drives 75 billion data points precisely because it is frictionless. Adding tags turns a 1-tap action into a 3-tap action and dramatically reduces participation. The running context also makes detailed tagging impractical (user is reviewing post-run, tired, wants it fast). | Binary feedback only. If the system needs to know WHY, it can infer from the song's metadata (genre, BPM, energy, decade) and look for patterns across multiple likes/dislikes. This is what taste learning does. |
| **Social sharing of liked songs** | "Share your running playlist favorites with friends" | Feature creep. Social features require sharing infrastructure, deep links, and social graph. The app is a utility, not a social platform. Running music preferences are highly personal and context-dependent (BPM-matched to YOUR cadence). Sharing a playlist matched to your 170 spm cadence is useless to a friend running at 160 spm. | The clipboard copy feature already exists for sharing full playlists. That is sufficient. |
| **Real-time feedback during playlist generation** | "As the playlist generates, show each song and let users approve/reject before finalizing" | Generation is fast (subsecond from curated pool). Adding an approval step slows the experience dramatically. Users want a playlist NOW, not an approval workflow. The swipe-to-dismiss + replacement flow already serves the "reject a specific song" use case post-generation. | Post-generation feedback via like/dislike + swipe-to-dismiss (existing). |
| **Weighted freshness per genre/artist** | "Different freshness decay rates for different genres -- EDM can repeat sooner than singer-songwriter" | Over-engineering. The freshness system is a simple recency penalty. Adding per-genre or per-artist decay rates creates a tuning nightmare with minimal user benefit. Users cannot perceive the difference between "this EDM song was penalized less" and "this singer-songwriter song was penalized more." | Single global freshness decay curve. Simple, predictable, tunable. |

---

## Feature Dependencies

```
Song Feedback Data Layer (foundation for everything)
    |
    |-- SongFeedback model (songKey, feedbackType, timestamp)
    |       |
    |       +-- SongFeedbackRepository (SharedPreferences persistence)
    |       |       |
    |       |       +-- Load/save/clear feedback
    |       |       +-- Query by song key
    |       |       +-- Query all liked / all disliked
    |       |
    |       +-- SongFeedbackNotifier (Riverpod provider)
    |               |
    |               +-- Exposes feedback state to UI
    |               +-- Provides like/dislike/clear methods
    |
    |-- Feedback UI on SongTile
    |       |
    |       +-- Thumbs up / thumbs down icons on every song tile
    |       +-- Visual state: filled (active) vs outlined (inactive)
    |       +-- Available in: playlist screen, history detail, review screen
    |
    |-- Scoring Integration
    |       |
    |       +-- SongQualityScorer: +8 for liked songs
    |       +-- PlaylistGenerator: hard filter disliked songs from candidates
    |
    |-- Feedback Library Screen
    |       |
    |       +-- Lists all liked/disliked songs
    |       +-- Toggle/clear feedback per song
    |       +-- Navigation from settings or home screen
    |
    |-- Post-Run Review (depends on feedback UI + playlist history)
    |       |
    |       +-- Home screen card: "Rate your last playlist"
    |       +-- Opens review screen showing songs with feedback buttons
    |       +-- Triggered when recent unreviewed playlist exists
    |
    |-- Taste Learning (depends on feedback accumulation)
    |       |
    |       +-- Pattern analysis engine
    |       |       +-- Genre distribution of liked vs profile genres
    |       |       +-- Artist frequency in liked songs
    |       |       +-- Decade patterns in liked songs
    |       |
    |       +-- Suggestion cards on home screen or feedback library
    |       |       +-- "Add Electronic to your genres?"
    |       |       +-- "Add [Artist] to your favorites?"
    |       |       +-- "Block [Artist]? (3 dislikes)"
    |       |
    |       +-- Suggestion acceptance -> TasteProfile.copyWith()
    |
    |-- Freshness Tracking (independent of feedback, parallel)
    |       |
    |       +-- SongAppearanceHistory (songKey -> lastGeneratedAt)
    |       +-- Updated during PlaylistGenerator.generate()
    |       +-- SharedPreferences persistence
    |
    |-- Freshness Scoring Dimension (depends on tracking)
    |       |
    |       +-- SongQualityScorer: -8 to 0 based on recency
    |       +-- Only active when freshness toggle is ON
    |
    |-- Freshness Toggle UI (depends on freshness scoring)
            |
            +-- Toggle on playlist generation screen
            +-- "Keep it Fresh" vs "Optimize for Taste"
            +-- Default: Optimize for Taste
            +-- Persisted per taste profile or globally
```

### Dependency Notes

- **SongFeedback data layer is the foundation.** Every other feedback feature depends on it. Build first.
- **Scoring integration is the immediate payoff.** Once feedback data exists, integrating it into `SongQualityScorer` makes feedback actually DO something. Ship this with the data layer to close the feedback loop immediately.
- **Feedback library can come after scoring integration.** Users can give feedback and see results (better playlists) before needing a dedicated management screen.
- **Post-run review depends on feedback UI but is independent of scoring integration.** It is a feedback COLLECTION mechanism, not a feedback APPLICATION mechanism.
- **Taste learning requires accumulated feedback.** Do not build the analysis engine until there is enough feedback to analyze. Gate behind a minimum threshold (e.g., 10+ liked songs).
- **Freshness tracking is completely independent of feedback.** It can be built in parallel. It depends only on playlist generation (which already exists).
- **Freshness toggle is a UI concern that depends on the freshness scoring dimension being implemented.** Ship the scoring dimension first, toggle second.

---

## How Major Platforms Handle Feedback, Learning, and Freshness

### Spotify

**Feedback mechanism:** Heart icon (add to Liked Songs) + "Hide this song" in context menu. The 2023 reintroduction of the dislike button provides a more explicit negative signal. Explicit feedback (saves, playlist adds, shares) weighs more than implicit signals (skips, completion rate) because background listening makes implicit signals unreliable.

**Taste learning:** Spotify uses collaborative filtering, natural language processing of playlist/track metadata, and audio feature analysis. For explicit feedback, a liked song increases affinity for similar artists, genres, and audio features. The system maintains separate user taste clusters (e.g., "lo-fi beats" cluster vs "contemporary jazz" cluster) to avoid averaging across different listening contexts.

**Freshness:** Discover Weekly regenerates weekly with entirely new songs. Daily Mix uses diversity injection -- inserting slightly different songs between similar ones. A "Fewer Repeats" shuffle mode (November 2025) considers previously played tracks when generating randomized playlists. Internally, Spotify scores playlist candidates for "freshness" by analyzing how recently songs were played and whether repeats appear too quickly.

**Relevance to our app:** Spotify's approach confirms that binary feedback (like/hide) is sufficient for personalization. Their freshness approach (recency penalty + diversity injection) maps directly to our proposed freshness scoring dimension. However, Spotify has implicit signals we do not -- our system must be more aggressive with explicit feedback weighting to compensate.

### Apple Music

**Feedback mechanism:** "Love" and "Suggest Less Like This" on songs, albums, and artists. Three-tier system: Love (positive), neutral (default), Suggest Less (negative). No hard "dislike" -- the language is deliberately softer ("Suggest Less"). Available via long-press context menu on iOS, ellipsis menu on Mac.

**Taste learning:** Apple Music's Listen Now tab shows strong recency bias (last 24-72 hours). The algorithm heavily weights recent explicit signals. One poorly-targeted listen can temporarily skew recommendations (a known user complaint, documented as recently as February 2026 by AppleInsider). Apple's approach is more opaque than Spotify's.

**Freshness:** Favorites Mix is the "exploitation" surface (familiar songs the user loves). New Music Mix and Discovery Station are the "exploration" surfaces. The final recommendation list is filtered for diversity, freshness, and editorial rules.

**Relevance to our app:** Apple's "Suggest Less" is softer than our needs. For a running playlist, users want certainty: "Do not put this song in my running playlist again." Hard filter (not soft suppression) is the right approach. Apple's recency sensitivity is a warning: we should not let a single feedback session dramatically swing recommendations.

### Pandora

**Feedback mechanism:** Thumbs up / thumbs down. The original and most studied binary feedback system. Built on the Music Genome Project (450+ musical attributes per song). Thumbs up increases frequency of songs with similar attributes. Thumbs down removes the specific song AND reduces frequency of songs with similar attributes. Feedback is station-specific (a thumbs-down on a pop station does not affect a rock station). Undo is available by giving the opposite thumb.

**Taste learning:** Pandora's system explicitly maps feedback to musical attributes. Thumbing up a song with strong bass, syncopated rhythm, and female vocals teaches the system to prefer those attributes. The learning is transparent to the user in the sense that the algorithm tells you "Playing because of [attribute]." Pandora uses ~70 different algorithms: 10 for content analysis, 40 for collective intelligence, 30 for personalized filtering.

**Freshness:** Pandora limits repeat plays within a station. The FCC-inspired "variety rule" prevents the same song from appearing too frequently within a listening period.

**Relevance to our app:** Pandora's attribute-based learning is the closest analog to our system. Our `SongQualityScorer` already uses song attributes (genre, BPM, danceability, runnability, decade). Feedback should reinforce or penalize at the attribute level, not just the song level. Pandora's station-specific feedback does NOT apply -- our users have one playlist context (running), so feedback should be global. Pandora's undo pattern (tap opposite thumb) is the right model.

### YouTube Music

**Feedback mechanism:** Thumbs up / thumbs down on songs. Liking tells the system you enjoy the song, style, and artist. Disliking suppresses the song and reduces similar recommendations. YouTube Music also offers Music Tuner (filters for tempo, popularity, mood) which is a form of explicit preference control beyond feedback.

**Freshness:** YouTube Music uses post-filtering to ensure playlists do not feature multiple songs by the same artist in sequence (we already do this via `enforceArtistDiversity`). Session-based variety ensures songs from different styles appear even within a single playlist.

**Relevance to our app:** YouTube Music's Music Tuner concept (user-controllable filters for tempo, mood) is analogous to our taste profile. Their artist diversity post-filtering validates our existing approach. Their thumbs pattern is standard.

### Running-Specific Apps (RockMyRun, PaceDJ, Weav Run)

**Feedback mechanism:** None of the BPM-matching running music apps have meaningful song feedback systems. RockMyRun lets users favorite workout mixes (not individual songs). PaceDJ lets users include/exclude songs from their library. Weav Run has no feedback mechanism.

**Taste learning:** None. Running music apps rely entirely on upfront configuration (genre picks, BPM targets).

**Freshness:** RockMyRun and Weav Run are streaming services -- freshness comes from their catalog updates, not user-side tracking. PaceDJ scans the user's library, so freshness is inherently limited to what the user has.

**Relevance to our app:** This is the biggest differentiator opportunity. No running music app has a feedback loop. Adding like/dislike, taste learning, and freshness to a BPM-matched running playlist generator is novel in this space.

---

## Feedback UX Patterns: Best Practices

### Icon Choice

Use **thumbs up / thumbs down**, not hearts.

- Hearts (Spotify's convention) imply "save to my library." This app has no library concept for external songs.
- Thumbs (Pandora, YouTube Music convention) imply "I like/dislike this." This matches the intent.
- Running context reinforces binary: the song was either good for running or not.

### Placement on Song Tile

The existing `SongTile` has this layout:
```
[Track #] [Title / Artist] [BPM chip]
```

Recommended addition:
```
[Track #] [Title / Artist] [thumbs-down] [thumbs-up] [BPM chip]
```

Or, to save horizontal space:
```
[Track #] [Title / Artist] [BPM chip]
                            [thumbs-up / thumbs-down]
```

Consider placing feedback icons on the trailing edge, replacing the BPM chip's position, or below the artist line. The icons must be touch-target sized (minimum 44x44 points iOS, 48x48 dp Android) per mobile UX guidelines.

Alternative: show feedback icons only on long-press or via the existing bottom sheet (when user taps the song tile). This is cleaner visually but adds a tap. Recommend: show icons inline for the post-run review screen (where the purpose is rating), and behind the bottom sheet for the regular playlist view (where the purpose is playback links).

### Feedback Confirmation

- Brief haptic feedback on tap (HapticFeedback.lightImpact)
- Icon fills/highlights immediately (optimistic UI)
- Snackbar with "Undo" appears for 3 seconds (Spotify pattern)
- Animation: icon bounces briefly (under 300ms per UX research)

### Three-State Toggle

Each song has three states:
1. **Liked** (thumbs up filled, primary color)
2. **Disliked** (thumbs down filled, error color)
3. **Neutral** (both icons outlined, no fill)

State transitions:
- Neutral -> tap thumbs up -> Liked
- Neutral -> tap thumbs down -> Disliked
- Liked -> tap thumbs up -> Neutral (toggle off)
- Liked -> tap thumbs down -> Disliked (switch)
- Disliked -> tap thumbs down -> Neutral (toggle off)
- Disliked -> tap thumbs up -> Liked (switch)

This matches Pandora's undo model and is the most intuitive for binary feedback.

---

## Taste Learning: How Pattern Detection Should Work

### Data Available Per Liked/Disliked Song

From the curated song dataset and BPM API, each song has:
- **Artist** (string)
- **Genre** (RunningGenre enum)
- **BPM** (int)
- **Decade** (string, e.g., "2010s")
- **Danceability** (int, 0-100)
- **Runnability** (int, 0-100)

When a user likes or dislikes a song, store all available metadata alongside the feedback. This enables pattern analysis without re-looking up the song later.

### Pattern Analysis Algorithm

After accumulating N liked songs (threshold: 10), analyze:

1. **Genre distribution:** What percentage of liked songs fall in each genre? Compare to taste profile genres. If a genre appears in 30%+ of likes but is not in the profile, suggest adding it.

2. **Artist frequency:** Which artists appear 2+ times in liked songs? If not already in taste profile artists, suggest adding them.

3. **Decade distribution:** Which decades dominate liked songs? If a decade represents 40%+ of likes and is not in the taste profile decades, suggest adding it.

4. **Disliked artist detection:** Which artists appear 3+ times in disliked songs? Suggest adding to disliked artists list.

5. **Energy pattern:** Compute average runnability/danceability of liked vs disliked songs. If liked songs cluster around high danceability (>70) but the user's energy level is "balanced," suggest "intense."

### Suggestion Presentation

Surface as dismissable cards on the home screen or feedback library:

```
"Based on your likes..."
[Genre chip] Electronic   [Add to Profile] [Dismiss]

"You've disliked 4 songs by [Artist]"
[Block this artist]  [Keep allowing]
```

Suggestions should:
- Appear at most once per pattern (do not re-suggest dismissed items)
- Be limited to 1-2 suggestions at a time (avoid overwhelming)
- Require explicit user acceptance (never auto-apply)
- Track which suggestions were dismissed (do not re-surface)

---

## Freshness: How Recency Tracking Should Work

### What "Freshness" Means in This App

A song is "fresh" if it has not appeared in a recently generated playlist. The freshness system prevents the "same 15 songs every run" problem that emerges when the scoring algorithm converges on a fixed set of top-scoring songs for a given BPM and taste profile.

### Tracking Mechanism

During `PlaylistGenerator.generate()`, after producing the final `Playlist`:
1. For each `PlaylistSong` in the output, update `SongAppearanceHistory` with the current timestamp.
2. Persist the history to SharedPreferences.

Storage format:
```json
{
  "artist|title": "2026-02-06T14:30:00Z",
  "artist2|title2": "2026-02-05T09:15:00Z"
}
```

### Scoring Penalty

The freshness penalty decays over time (stepped decay, matching the integer scoring system):

| Last Appeared | Penalty | Rationale |
|---------------|---------|-----------|
| Within 3 days | -8 | User just ran with this song; strong penalty |
| 4-7 days | -5 | Recent but not immediate; moderate penalty |
| 8-14 days | -3 | Getting stale in memory; mild penalty |
| 15-30 days | -1 | Fading; minimal penalty |
| 31+ days or never | 0 | Fresh or forgotten; no penalty |

This curve is inspired by Spotify's freshness scoring (documented in engineering blog) and memory decay models (ACT-R declarative memory module, used in academic music recommendation research).

### User Control

The freshness toggle controls whether this penalty is active:
- **"Keep it Fresh"** = freshness penalty active. Playlists will have more variety across sessions.
- **"Optimize for Taste"** = freshness penalty disabled. The algorithm picks the best-scoring songs regardless of recency.

Default: "Optimize for Taste" for new users (no history to be fresh from). After 5+ playlists generated, the system could suggest switching to "Keep it Fresh."

---

## MVP Recommendation

For v1.3 MVP, prioritize in this order:

1. **Song feedback data layer + SongTile integration** (foundation -- everything depends on this)
2. **Scoring integration: liked boost + disliked filter** (closes the feedback loop -- feedback DOES something)
3. **Feedback library screen** (users can manage their feedback decisions)
4. **Freshness tracking + scoring dimension** (prevents playlist staleness)
5. **Freshness toggle UI** (user control over freshness behavior)
6. **Post-run review screen** (novel differentiator for running context)

Defer to post-v1.3:
- **Taste learning / pattern analysis:** Requires accumulated feedback data. Build the analysis engine after users have had time to generate feedback. The data layer should store song metadata with feedback now so the analysis can run later.
- **Suggestion cards for taste profile updates:** Depends on taste learning. Defer.
- **Disliked artist auto-detection:** Simple enough to include in v1.3 if time allows, but not critical path.

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority | Rationale |
|---------|------------|---------------------|----------|-----------|
| Song feedback data layer | HIGH | MEDIUM | P0 | Foundation for all feedback features. Must be built first. |
| Like/dislike on SongTile | HIGH | LOW | P0 | The user-facing entry point for feedback. Ships with data layer. |
| Liked song scoring boost (+8) | HIGH | LOW | P0 | Closes the feedback loop immediately. Feedback DOES something. |
| Disliked song hard filter | HIGH | LOW | P0 | Users expect disliked songs to vanish. Binary intent, binary action. |
| Feedback state persistence | HIGH | LOW | P0 | Feedback must survive app restarts. SharedPreferences JSON blob. |
| Undo feedback (snackbar + toggle) | MEDIUM | LOW | P1 | Standard pattern, prevents user frustration from accidental taps. |
| Feedback library screen | MEDIUM | MEDIUM | P1 | Management screen for all feedback. Two-tab list (liked/disliked). |
| Freshness tracking (appearance history) | HIGH | MEDIUM | P1 | Prevents "same 15 songs" convergence problem. |
| Freshness scoring dimension | HIGH | LOW | P1 | Uses tracked data to penalize recent songs. |
| Freshness toggle UI | MEDIUM | LOW | P2 | User control over freshness. Simple toggle widget. |
| Post-run review screen | HIGH | MEDIUM | P2 | Novel differentiator. Captures feedback while experience is fresh. |
| Taste learning / pattern analysis | MEDIUM | HIGH | P3 | Requires accumulated data. Defer until feedback is widely used. |
| Suggestion cards for profile updates | MEDIUM | MEDIUM | P3 | Depends on taste learning engine. |
| Disliked artist auto-detection | LOW | LOW | P3 | Nice-to-have. Simple pattern detection on disliked songs. |

---

## Competitive Positioning After v1.3

| Feature | Spotify | Apple Music | Pandora | YouTube Music | RockMyRun | PaceDJ | This App (v1.3) |
|---------|---------|-------------|---------|---------------|-----------|--------|-----------------|
| Song-level feedback | Heart + Hide | Love + Suggest Less | Thumbs up/down | Thumbs up/down | No | No | Thumbs up/down |
| Feedback affects next playlist | Yes (gradual) | Yes (gradual) | Yes (immediate) | Yes (gradual) | N/A | N/A | Yes (immediate, next generation) |
| Feedback library / management | Liked Songs playlist | Loved songs (Mac only) | Thumbed tracks per station | Liked songs | No | No | Dedicated library screen |
| Post-session review | No | No | No | No | No | No | Yes (post-run review) |
| Freshness / variety control | Algorithmic (Fewer Repeats mode) | Separate Mix surfaces | Variety rules | Post-filtering | Catalog updates | N/A | User toggle + recency penalty |
| Taste learning from feedback | Yes (deep ML) | Yes (opaque) | Yes (attribute mapping) | Yes (ML) | No | No | Pattern analysis with suggestions |
| Running-specific context | No | No | No | No | Yes (mixes, not songs) | Yes (BPM filter) | Yes (BPM + taste + feedback + freshness) |

This app becomes the only running music tool that combines BPM matching, multi-dimensional scoring, explicit feedback, taste learning, and freshness control. General music apps have deeper recommendation engines but no running context. Running apps have BPM matching but no feedback loop. This app bridges both.

---

## Research Confidence Assessment

| Finding | Confidence | Source | Notes |
|---------|------------|--------|-------|
| Binary feedback outperforms rating scales for music | HIGH | Cornell Piki research, Pandora's 75B feedback points, Spotify's binary (heart/hide) design | Multiple independent sources converge |
| Disliked songs should be hard-filtered, not soft-penalized | MEDIUM | Pandora never replays thumbed-down songs; Apple "Suggest Less" is less decisive | Pandora's approach matches user intent better; Apple's softer approach gets complaints |
| Thumbs up/down icons preferred over hearts for feedback context | MEDIUM | Pandora + YouTube Music convention for "rate this" vs Spotify hearts for "save this" | Convention-based reasoning; user testing would strengthen |
| Freshness penalty with time decay matches user expectations | MEDIUM | Spotify's "Fewer Repeats" mode, ACT-R memory decay models, Apple's recency filtering | Academic + industry support; specific decay curve is estimated, not proven |
| Post-run review is a novel differentiator | HIGH | No running app offers this; no general music app offers post-session review | Confirmed via competitor analysis of RockMyRun, PaceDJ, Weav, Spotify, Apple Music, Pandora, YouTube Music |
| Taste learning should be suggestion-based, not automatic | MEDIUM | Apple Music transparency complaints, Music Tomorrow fairness research (2025), Pandora's transparent attribute mapping | Industry trend toward transparency; automatic modification gets user complaints |
| No running music app has a song-level feedback loop | HIGH | Direct competitor analysis | Verified: RockMyRun, PaceDJ, Weav Run have no song-level feedback |
| SharedPreferences adequate for feedback storage at ~5000 songs | MEDIUM | SharedPreferences handles JSON blobs up to a few MB; 5000 entries with timestamps is well under this | Technical assessment from existing codebase patterns; may need migration to Hive/SQLite at scale |

---

## Sources

### Platform Feedback Systems
- [Spotify Recommendation System Complete Guide (Music Tomorrow, 2025)](https://www.music-tomorrow.com/blog/how-spotify-recommendation-system-works-complete-guide) -- Explicit/implicit feedback weighting, taste clustering, freshness
- [Cornell Research: Dislike Button Improves Recommendations](https://cis.cornell.edu/dislike-button-would-improve-spotify-recommendations) -- Binary feedback effectiveness, Piki research system
- [Pandora Thumbs System Explained (SoftHandTech)](https://softhandtech.com/what-are-thumbs-on-pandora/) -- Station-specific feedback, attribute learning, undo patterns
- [Apple Music Love/Dislike Guide (MacRumors)](https://www.macrumors.com/how-to/customize-apple-music/) -- Three-tier feedback, scope per song/album/artist
- [YouTube Music Algorithm Guide (BeatsToRapOn)](https://beatstorapon.com/blog/ultimate-youtube-music-algorithm-a-comprehensive-guide/) -- Thumbs up/down, Music Tuner, session-based variety
- [Spotify DISLIKE BUTTON Community Discussion](https://community.spotify.com/t5/Live-Ideas/All-platforms-Dislike-an-item-and-avoid-it/idi-p/5749554) -- User expectations for dislike functionality

### Freshness and Variety
- [Spotify Prompted Playlists (Spotify Newsroom, Dec 2025)](https://newsroom.spotify.com/2025-12-10/spotify-prompted-playlists-algorithm-gustav-soderstrom/) -- User-controlled freshness, daily/weekly refresh
- [Spotify Fewer Repeats Shuffle (TechBuzz)](https://www.techbuzz.ai/articles/spotify-fixes-shuffle-s-repetition-problem-with-smarter-algorithm) -- Recency-aware shuffle, freshness scoring
- [Apple Music Algorithm Guide 2026 (BeatsToRapOn)](https://beatstorapon.com/blog/the-apple-music-algorithm-in-2026-a-comprehensive-guide-for-artists-labels-and-data-scientists/) -- Recency bias, diversity filtering, freshness signals
- [Measuring Recency Bias in Sequential Recommendation (ArXiv, 2024)](https://arxiv.org/html/2409.09722v1) -- Academic analysis of recency bias in recommendation systems
- [ACT-R Memory Model for Music Recommendation (Springer, 2024)](https://link.springer.com/chapter/10.1007/978-3-031-55109-3_4) -- Time-decayed frequency/recency modeling

### Feedback UX Design
- [Mobile Gesture UI Design Tips (ZeePalm)](https://www.zeepalm.com/blog/10-gesture-ui-design-tips-for-ios-and-android-apps) -- Touch targets, haptic feedback, animation timing
- [Apple Music Suggest Less Complaints (AppleInsider, Feb 2026)](https://appleinsider.com/articles/26/02/06/one-song-can-ruin-your-entire-apple-music-algorithm-there-needs-to-be-a-fix) -- User frustration with opaque recommendation changes

### Taste Learning and Recommendation Research
- [Implicit vs Explicit Feedback in Music Recommendation (ACM)](https://dl.acm.org/doi/10.1145/1869446.1869453) -- Complementary relationship between feedback types
- [Negative Feedback for Music Personalization (ArXiv, 2024)](https://arxiv.org/html/2406.04488) -- How negative feedback improves recommendation quality
- [Fairness and Transparency in Music Streaming Algorithms (Music Tomorrow, 2025)](https://www.music-tomorrow.com/blog/fairness-transparency-music-recommender-systems) -- Transparency, feedback loops, user agency
- [How Spotify Uses AI to Recommend Music (IABAC)](https://iabac.org/blog/how-spotify-uses-ai-to-recommend-music) -- Pattern detection from explicit signals

### Running and Music
- [Nike: Picking Music to Power a Run](https://www.nike.com/a/picking-music-to-power-a-run) -- BPM sweet spots for running intensity
- [RockMyRun App](https://www.rockmyrun.com/) -- Competitor analysis, no song-level feedback
- [PaceDJ App](https://www.pacedj.com/) -- Competitor analysis, library BPM scanning

---
*Feature research for: v1.3 Song Feedback, Taste Learning & Playlist Freshness -- Running Playlist AI*
*Researched: 2026-02-06*
