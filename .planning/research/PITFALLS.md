# Pitfalls Research

**Domain:** Adding song feedback loops, taste learning, and playlist freshness to an existing Flutter running playlist app with a static scoring system
**Researched:** 2026-02-06
**Confidence:** HIGH (grounded in codebase analysis of SongQualityScorer, PlaylistGenerator, and SharedPreferences persistence layer; cross-referenced with recommendation system research)

---

## Critical Pitfalls

### Pitfall 1: Feedback Score Dimension Destabilizes Existing Scoring Balance

**What goes wrong:**
The current `SongQualityScorer` has 8 dimensions totaling a max of 46 points (artist=10, runnability=15, danceability=8, genre=6, decade=4, BPM=3, diversity=-5, disliked=-15). Adding a "user liked this song" bonus (say +10) and a "user disliked" penalty (say -10) fundamentally shifts the scoring distribution. A liked song with mediocre running suitability (runnability=3, danceability=2) suddenly outscores an objectively better running song (runnability=15, danceability=8) that the user hasn't rated. The feedback dimension drowns out the music-science-based scoring that makes the app's playlists actually good for running.

The danger is asymmetric: most songs will have NO feedback (neutral), while a small set will have strong positive/negative signals. This creates a bimodal scoring distribution where rated songs cluster at the top and bottom, with unrated songs stuck in the middle regardless of their actual running quality.

**Why it happens:**
Developers treat feedback as "just another scoring dimension" and assign it a weight proportional to its perceived importance. But feedback is categorically different from the other dimensions: it's sparse (only a few songs have it), binary (like/dislike, not a spectrum), and it accumulates over time (eventually many songs are rated). The weight that "feels right" with 5 rated songs becomes dominant when 200 songs are rated.

**How to avoid:**
1. **Cap the feedback bonus below the runnability dimension.** Feedback should nudge rankings, not override running suitability. Recommended: liked=+5, disliked=-8. This keeps feedback meaningful (a liked song ties with a song that has +5 more runnability) without letting it override the top-scoring dimension.
2. **Test scoring distribution with mock data.** Before implementing, create a spreadsheet or unit test with 20 songs: 5 liked, 5 disliked, 10 unrated. Verify that a liked song with poor running metrics does NOT outrank an unrated song with excellent running metrics. The running-suitability signal should remain the primary ranking factor.
3. **Keep feedback and runnability separable in the score.** Store `runningQuality` (existing dimensions) and `feedbackScore` separately on `PlaylistSong` so the score breakdown is debuggable and the balance can be tuned post-ship.

**Warning signs:**
- Unit tests show liked songs always appearing in top 3 regardless of BPM match quality
- User generates playlist, all liked songs cluster at the top of every segment regardless of genre/BPM fit
- Disliked songs never appear even when they are the only BPM-exact matches for a segment

**Phase to address:**
Feedback-to-scorer integration phase. This is the single most important design decision -- get the weight wrong and playlists degrade.

**Confidence:** HIGH -- the scoring code is fully visible in `song_quality_scorer.dart` and the weight arithmetic is straightforward to analyze.

---

### Pitfall 2: SharedPreferences JSON Blob Grows Unbounded With Feedback + History Data

**What goes wrong:**
The app currently stores playlist history (max 50 playlists) and taste profiles as single JSON strings in SharedPreferences. Adding per-song feedback (like/dislike for potentially all 5,066 curated songs plus API-discovered songs) and play-frequency tracking (how many times each song appeared in playlists) creates a storage scaling problem.

Consider the math: each feedback entry needs a lookup key (~50 chars), a feedback enum (~7 chars), a timestamp (~24 chars), plus JSON overhead. At 500 rated songs, that is roughly 50KB of JSON. At 2,000 rated songs (heavy user over months), that is 200KB+. Combined with playlist history (50 playlists x ~15 songs x ~200 bytes = 150KB) and curated song cache (~1MB for 5,066 songs), the total SharedPreferences footprint exceeds 1.5MB.

Android SharedPreferences loads the entire XML file into memory at `getInstance()` time. A 1.5MB+ SharedPreferences file causes noticeable lag (200-500ms) on every app start because ALL keys are deserialized, not just the one you access. iOS NSUserDefaults is slightly better but still not designed for this scale.

**Why it happens:**
SharedPreferences worked fine for small data (1 taste profile, 1 run plan). Each new feature adds "just one more key" without considering the cumulative impact. The playlist history already stores 50 full playlists with all song metadata -- this was the first scaling step. Feedback data is the second, and it grows without the `maxHistorySize = 50` cap that playlist history has.

**How to avoid:**
1. **Use a compact storage format for feedback.** Store feedback as a `Map<String, String>` where key is the song lookup key and value is a single character (`'L'` for like, `'D'` for dislike). Skip timestamps unless needed. This reduces per-entry storage to ~60 bytes. For 2,000 songs: ~120KB.
2. **Store feedback in its own SharedPreferences key** (not mixed with other data). This isolates the cost: the feedback blob is only loaded when needed, not every time the app reads a taste profile.
3. **Set a maximum feedback count.** When feedback entries exceed 3,000 (arbitrary but safe), trim the oldest entries that are not "disliked" (keep all dislikes, trim oldest likes). Likes are a positive signal that can be re-derived; dislikes are a negative signal the user never wants to see again.
4. **For play-frequency tracking, store only the song key and count**, not full song metadata. A map of `{lookupKey: playCount}` is extremely compact.
5. **Consider migration to SQLite/Drift if the app adds more data-heavy features.** Not needed for v1.3 feedback alone, but flag as tech debt if v1.4+ adds more persistent data.

**Warning signs:**
- App startup time increases noticeably over weeks of use
- `SharedPreferences.getInstance()` takes >100ms (measurable in debug console)
- Users report the app "getting slower" over time
- JSON encode/decode of feedback map takes >50ms

**Phase to address:**
Feedback data model phase (earliest phase). The storage format decision cascades into every subsequent phase. Getting it wrong means a data migration later.

**Confidence:** HIGH -- the SharedPreferences performance characteristics are well-documented. The existing codebase already stores ~150KB of playlist history (50 playlists), and curated song cache adds another ~1MB. Feedback data is additive.

---

### Pitfall 3: Filter Bubble -- Feedback Loop Narrows Playlist to Same 20 Songs

**What goes wrong:**
User likes 15 songs. Those songs get +5 in scoring. Next playlist generation, those 15 songs rank higher, appear in the playlist again. User is happy, likes a few more. Within 10 playlist generations, the user has liked ~30 songs and the scorer always picks from that pool. Every playlist sounds the same. The app becomes a static playlist player, not a discovery tool.

This is the classic recommender system "filter bubble" or "echo chamber" problem, extensively documented in recommendation system research. It is especially acute in small catalogs (5,066 songs is small by music recommendation standards) where liked songs can constitute a significant fraction of BPM-eligible candidates for any given segment.

**Why it happens:**
The feedback loop is a positive reinforcement cycle: liked songs appear more -> user confirms they like them -> songs get reinforced further. There is no counter-force pushing toward exploration. The existing scorer has no "you've heard this recently" penalty -- it treats every generation as independent.

This is compounded by the app's definition of "played": a song that appeared in a generated playlist, whether or not the user actually listened to it. Songs get "play count" credit just by being generated, which biases freshness tracking toward already-highly-scored songs.

**How to avoid:**
1. **Freshness penalty is the primary countermeasure.** Songs that appeared in recent playlists get a score penalty. This is already planned as a feature, but it must be implemented as a scoring dimension (not a post-filter) to interact correctly with feedback bonuses. Recommended: -3 per appearance in the last 5 playlists, capped at -9.
2. **Exploration slot: reserve 1-2 songs per segment for non-liked songs.** After scoring and ranking, force at least 1 song per segment to come from the "unrated" pool. This ensures discovery continues.
3. **Decay feedback weight over time.** A song liked 6 months ago should carry less weight than one liked last week. Simple approach: full weight for likes in last 30 days, half weight for 30-90 days, quarter weight beyond 90 days. This requires storing feedback timestamps (contradicts the "compact storage" advice in Pitfall 2 -- resolve by storing a "likedMonth" integer instead of full timestamp).
4. **Show the user what is happening.** When the freshness toggle is set to "taste-optimized," warn: "Playlists will favor your liked songs. Switch to Fresh for more variety." Transparency reduces frustration when the bubble forms.

**Warning signs:**
- User generates 5 playlists in a row, >60% song overlap between consecutive playlists
- Same 20-30 songs appear in every playlist regardless of BPM target
- User stops liking new songs (nothing new to like because they only see familiar ones)

**Phase to address:**
Freshness tracking phase AND feedback-to-scorer integration phase. These two features MUST be designed together. Shipping feedback without freshness creates the filter bubble. Shipping freshness without feedback loses the personalization value.

**Confidence:** HIGH -- this is the most-studied pitfall in recommendation systems. The small catalog (5,066 songs) and lack of in-app listening (no skip/repeat signals to add noise) make this app especially vulnerable.

---

### Pitfall 4: Taste Learning Overfits to Explicit Feedback, Ignoring the Taste Profile

**What goes wrong:**
The user carefully sets up a taste profile: genres=[Pop, Electronic], artists=[Dua Lipa, Calvin Harris], energy=Intense. Then they like 10 songs that happen to be Hip-Hop (because a friend's playlist had some good running hip-hop). The taste learning system infers "user likes Hip-Hop" and starts boosting Hip-Hop songs in scoring. The next playlist is 40% Hip-Hop. The user is confused -- "I told you I like Pop and Electronic."

The taste profile represents the user's *stated* preferences. Feedback represents *revealed* preferences on individual songs. When these conflict, the system must decide which to trust. Naively learning from feedback ("they liked hip-hop songs, so boost hip-hop") overrides the explicit taste profile and feels like the app ignores the user's settings.

**Why it happens:**
Taste learning algorithms treat all signal equally. A liked song is a liked song, regardless of whether it matches the taste profile. Machine learning approaches would weight recent behavior over stated preferences (this is how Spotify works -- but Spotify has millions of signals, not 30 likes). With sparse explicit feedback, a few outlier likes can dominate the learned model.

**How to avoid:**
1. **Feedback should adjust song-level scoring, NOT modify the taste profile.** Keep the `TasteProfile` as the user's explicit preferences (genres, artists, decades, energy). Feedback is a separate signal that says "this specific song is good/bad for me" without implying genre-level preferences.
2. **If implementing genre-level taste learning, require a threshold.** Only infer "user likes Genre X" if they have liked 5+ songs in Genre X AND Genre X is not already in their taste profile. Show the inference to the user: "You seem to like Hip-Hop songs. Add to your taste profile?" Let them confirm.
3. **Never auto-modify the taste profile without user action.** The taste profile is the user's explicit contract with the app. Silently changing it violates trust.
4. **Artist learning is safer than genre learning.** If a user likes 3 songs by the same artist, inferring "user likes this artist" is much more specific and less likely to cause drift than genre inference.

**Warning signs:**
- User's generated playlists diverge from their taste profile genres
- User edits taste profile to "fix" playlists but feedback overrides their changes
- Taste learning recommends genres the user explicitly does not have in their profile

**Phase to address:**
Taste learning phase (must come AFTER basic feedback is working). Design the learning algorithm with the taste profile as a constraint, not a competitor.

**Confidence:** HIGH -- the tension between explicit preferences and implicit/feedback signals is fundamental to recommendation systems. The existing taste profile architecture (separate domain model, explicit user-set values) makes the boundary clear -- the pitfall is crossing it.

---

## Moderate Pitfalls

### Pitfall 5: Song Lookup Key Mismatch Between Feedback and Curated/API Songs

**What goes wrong:**
Feedback is stored against a song lookup key (`artist.toLowerCase().trim()|title.toLowerCase().trim()`). But the same song can appear with slightly different metadata from different sources:
- Curated: `"dua lipa|don't start now"`
- API: `"Dua Lipa|Don't Start Now"` (different casing, handled by toLowerCase)
- API variant: `"dua lipa|don't start now (feat. someone)"` (different title, NOT handled)
- API variant: `"dua lipa|dont start now"` (apostrophe stripped, NOT handled)

The user likes "Don't Start Now" from a generated playlist. That playlist used the curated version. Next generation, the API returns the song with "(feat. someone)" appended. The lookup key doesn't match, so the feedback bonus is not applied. The user sees a song they liked but it doesn't have the heart icon, and it doesn't get the scoring bonus.

**Why it happens:**
The existing lookup key format (`artist|title` with toLowerCase and trim) handles casing and whitespace but not:
- Featured artist suffixes: `(feat. X)`, `(ft. X)`, `(with X)`
- Remix/version suffixes: `(Radio Edit)`, `(Remaster)`, `(Live)`
- Punctuation differences: apostrophes, dashes, special characters
- "The" prefix variations: `The Weeknd` vs `Weeknd`

The curated dataset is normalized (5,066 entries with consistent formatting). But API-sourced songs (`BpmSong.fromApiJson`) have inconsistent formatting from GetSongBPM.

**How to avoid:**
1. **Normalize lookup keys more aggressively for feedback matching.** Strip parenthetical suffixes (everything after the first `(` in the title), remove non-alphanumeric characters except `|`, collapse multiple spaces. This is a separate "feedback key" that is more forgiving than the curated lookup key.
2. **Store feedback against the curated lookup key when possible.** When a song matches the curated dataset (which the app already checks for runnability scoring), use the curated key as the canonical feedback key. This anchors feedback to the stable, normalized key.
3. **Implement a fallback match.** If exact lookup key match fails, try artist-only match + fuzzy title match (title starts with the same 10 characters). This catches `"don't start now"` vs `"don't start now (radio edit)"`.
4. **Unit test with real edge cases.** Get 20 songs from the API, compare their keys against the curated dataset keys for the same songs. Document the mismatches and ensure the normalization handles them.

**Warning signs:**
- User likes a song, generates a new playlist, the same song appears without the liked indicator
- Feedback count in the library screen is lower than expected (user liked 20 songs but library shows 15 because 5 had key mismatches)
- Same song appears both in "liked" and "unrated" categories in the feedback library

**Phase to address:**
Feedback data model phase. The key normalization strategy must be decided before any feedback is persisted, because changing the key format later requires a data migration.

**Confidence:** HIGH -- the key format is visible in `curated_song.dart` line 87 and `playlist_generator.dart` line 221. The API inconsistency is a known issue (songs from GetSongBPM have variable formatting).

---

### Pitfall 6: Freshness Penalty Makes Small BPM Pools Unplayable

**What goes wrong:**
For a target BPM of 190 (fast runner), the available song pool might be only 40-60 songs. If the user generates 5 playlists (~15 songs each = 75 song slots), many songs have already appeared. A freshness penalty of -3 per recent appearance means most of the pool is penalized. The scorer now picks low-quality songs (poor BPM match, wrong genre) just because they are "fresh." The playlist quality drops sharply.

For common BPMs (160-170), the pool is large enough (200+ songs) that freshness works well. But the penalty is per-song, and pool sizes vary dramatically by BPM.

**Why it happens:**
The freshness penalty is designed with the average case in mind (large pool, moderate generation frequency). Edge cases with small pools or heavy users who generate daily are not considered. The penalty is absolute (fixed point deduction) rather than relative to pool size.

**How to avoid:**
1. **Scale freshness penalty by pool availability.** If fewer than 50 BPM-eligible songs exist, reduce the freshness penalty to -1 (or zero). Check pool size in `PlaylistGenerator._scoreAndRank` before applying freshness.
2. **Track freshness as "playlists since last appearance" not "total appearances."** A song that appeared 2 playlists ago is "stale enough" to re-include, even if it appeared in 10 total playlists. This naturally resets freshness for heavy users.
3. **Never let freshness penalty exceed the runnability score range.** If the maximum freshness penalty is -9 and the runnability range is 0-15, a great running song penalized for freshness (15-9=6) still outscores a poor running song that is fresh (3+0=3). This preserves the running-quality floor.
4. **Make freshness opt-in via the toggle.** Users who generate infrequently (once a week) don't need freshness at all. The toggle should default to OFF for new users and only suggest enabling after they have generated 5+ playlists.

**Warning signs:**
- Playlists at extreme BPMs (>185 or <140) contain many half-time/double-time matches that score poorly
- Users at niche BPMs complain "the app ran out of good songs"
- Test: generate 10 playlists at 190 BPM, verify the 10th playlist still has reasonable quality scores

**Phase to address:**
Freshness tracking phase. Pool size awareness must be built into the freshness algorithm from the start.

**Confidence:** HIGH -- the BPM pool size variation is visible in the curated dataset. BPMs 160-170 have 500+ songs; BPMs 185+ have <100 songs. The pool size problem is predictable.

---

### Pitfall 7: Feedback UI Fatigue -- Constant Like/Dislike Prompts Kill the Post-Run Experience

**What goes wrong:**
After a run, the user sees their playlist with like/dislike buttons on every song (10-15 songs). Rating 15 songs is tedious. The first time, they might rate 5-8 songs. By the third post-run review, they rate 0 songs. The feedback data dries up, and the taste learning system has too little data to be useful.

Alternatively, the app shows a "Rate your playlist!" prompt after every generation. Users dismiss it, it becomes notification blindness, and the feedback feature is effectively dead.

**Why it happens:**
The natural impulse is to collect maximum feedback: buttons on every song, a post-run review screen, prompts to rate. But music app research (particularly from Last.fm studies) shows that explicit feedback is costly for users and they provide it sparingly. The key insight from the literature: explicit feedback provides depth but causes fatigue; implicit feedback provides breadth without effort.

**How to avoid:**
1. **Make feedback zero-effort for strong signals only.** Like/dislike buttons should be visible but not prominent. Only songs the user has strong feelings about get rated. Most songs are "fine" and should remain unrated.
2. **Post-run review should be optional and quick.** Show the playlist, let the user tap hearts on songs they loved. Don't force them through a review flow. A simple "Any favorites?" prompt (not "Rate each song") respects their time.
3. **Do not auto-open a review screen.** The user just finished a run. They want to cool down, not do data entry. Put the feedback option in the playlist history detail screen, accessible when they choose.
4. **Batch feedback moments.** Instead of per-song, offer "Did you enjoy this playlist?" (thumbs up/down). A playlist-level signal is lower effort and still useful (all songs in a liked playlist get a mild boost).
5. **Consider implicit signals.** If a user taps "Open in Spotify" for a song, that is a positive signal. If they skip to the next song's Spotify link without opening the first, that is a weak negative. These signals are free.

**Warning signs:**
- Feedback collection rate drops >50% between first and fifth playlist
- Users consistently rate only 1-2 songs per playlist (only the ones they strongly like/dislike)
- Post-run review screen bounce rate is >70%

**Phase to address:**
Feedback UI phase. The UI design determines the feedback collection rate, which determines whether taste learning has enough data to work.

**Confidence:** MEDIUM -- based on recommendation system literature about explicit feedback fatigue. The specific collection rates depend on this app's user behavior, which we cannot predict. But the general pattern (fatigue with explicit feedback) is well-established.

---

### Pitfall 8: Dislike Feedback Creates a "Blacklist Spiral" That Shrinks the Pool Too Aggressively

**What goes wrong:**
The user dislikes 20 songs over a few weeks. With a dislike penalty of -8, these songs effectively never appear again (they would need +8 from other dimensions to offset, which is unlikely for an already-disliked song). The curated pool shrinks from 5,066 to 5,046, then to 5,020. This seems fine globally, but per-BPM-bucket, the impact is disproportionate. If 10 of those 20 dislikes are in the 165-170 BPM range (the most common running cadence), that is 10 songs removed from a pool of maybe 300, which is a 3% reduction. After 6 months of heavy use, the user might dislike 100 songs, with 50 in popular BPM ranges -- a 15-20% reduction in the most-used pool.

Combined with the existing `dislikedArtistPenalty = -15`, a user who both dislikes an artist (in taste profile) AND dislikes specific songs by that artist gets a combined penalty of -23, which is effectively an absolute ban. This is correct behavior for disliked artists, but for individual song dislikes, the penalty should not compound with artist dislike.

**Why it happens:**
Song-level dislikes feel like a small, safe feature. Each individual dislike barely affects the pool. But they accumulate, and the cumulative effect is not visible until months later.

**How to avoid:**
1. **Dislike penalty should be moderate, not absolute.** Recommended: -8 (enough to push the song to the bottom of rankings but not permanently exclude it). If a disliked song is the only exact-BPM match for a segment, it should still appear rather than leaving the segment empty.
2. **Do not compound song dislike with artist dislike penalty.** If a song is both from a disliked artist (-15) and individually disliked (-8), apply only the larger penalty (-15), not the sum (-23). Implement as `min(dislikedArtistPenalty, songDislikePenalty)` (since both are negative, take the more negative one, not the sum).
3. **Provide an "undo" path.** The feedback library screen should let users remove dislikes. Make it easy to un-dislike songs -- a single tap to clear feedback, not a multi-step process.
4. **Track pool health.** Log the ratio of eligible-to-disliked songs per BPM bucket. If any bucket drops below 80% availability, warn internally (or show a nudge: "You've disliked many songs in this BPM range. Playlists may have less variety.").

**Warning signs:**
- Some BPM targets produce very short playlists (not enough eligible songs to fill segment duration)
- User has 100+ dislikes and complains playlists are "boring" or "same songs every time" (the pool is too small for variety)
- Freshness penalty + dislike penalty combine to make most songs in a BPM bucket unselectable

**Phase to address:**
Feedback-to-scorer integration phase. The dislike penalty design and compounding rules must be decided alongside the like bonus (Pitfall 1).

**Confidence:** HIGH -- the existing `dislikedArtistPenalty = -15` shows the pattern. Pool depletion math is straightforward given the known dataset size (5,066 songs).

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Store all feedback in one SharedPreferences key | Simple implementation, consistent with existing pattern | Load time degrades as feedback grows; blocks migration to SQLite later | Acceptable for v1.3 if feedback entries are capped at 3,000 and stored compactly |
| No feedback timestamps, just like/dislike | Half the storage, simpler data model | Cannot implement time-decay on feedback weight; cannot show "liked on [date]" in library | Acceptable for v1.3 MVP; add timestamps in v1.4 if decay is needed |
| Freshness tracking uses playlist history (already stored) instead of separate play-count map | No new storage mechanism needed | Freshness calculation requires loading and scanning all 50 playlists to count appearances per song; O(50 * 15) = O(750) per lookup | Acceptable if cached at generation time; becomes unacceptable if used in real-time scoring |
| Binary like/dislike instead of 5-star rating | Simpler UI, lower friction, clearer signal | Cannot distinguish "love" from "it was okay"; coarser signal for taste learning | Always acceptable for a running app. Users make snap decisions about running music; granularity adds friction without proportional value |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Loading all feedback on every playlist generation | Generation time increases by 100-200ms after 1000+ feedback entries | Load feedback once into a HashMap at app start, pass to generator | >500 feedback entries |
| Scanning playlist history for freshness on every score call | O(n*m) where n=songs, m=history playlists | Pre-compute a `Map<String, int>` of play counts at generation start, pass to scorer as parameter (same pattern as `curatedRunnability`) | >20 playlists in history |
| Re-serializing full feedback map on every feedback action | 50-100ms write for large maps, blocks UI thread | Debounce writes: accumulate feedback changes in memory, flush to SharedPreferences every 5 seconds or on app background | >200 feedback entries |
| String-based lookup key comparison in hot scoring loop | String creation + comparison for 5,066 songs per generation | Pre-compute feedback into a `Set<String>` for O(1) liked check, `Set<String>` for disliked check | Not a bottleneck until >10,000 candidate songs |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Like/dislike buttons are too small on song rows | Accidental taps during post-run (sweaty fingers, phone in arm band) | Minimum 44x44pt tap target; add 200ms debounce to prevent double-tap; show undo toast for 5 seconds |
| No visual feedback when tapping like/dislike | User unsure if tap registered; taps again (toggles back to unrated) | Animate the icon (scale bounce or color fill), play haptic feedback, show brief toast "Liked!" |
| Freshness toggle is unclear ("Fresh" vs "Taste-optimized") | User doesn't understand what these mean | Add subtitle text: "Fresh = more variety, fewer repeats" vs "Taste = more songs you've liked" |
| Feedback library shows all feedback but no way to filter | Scrolling through 200+ songs to find one specific dislike to undo | Add search/filter by artist name; show separate liked/disliked tabs |
| Disliking a song in the playlist view doesn't remove it from the current playlist | User expects disliked song to disappear immediately | Keep it visible but greyed out with a strikethrough, or add "Remove from playlist" as a separate action |

## "Looks Done But Isn't" Checklist

- [ ] **Feedback persistence:** Feedback saves correctly, but verify it survives app force-kill (SharedPreferences write is async; if app is killed during write, data may be lost). Test: like a song, immediately force-kill app, relaunch, verify feedback persists.
- [ ] **Feedback on API-sourced songs:** Feedback works for curated songs, but verify that API-sourced songs (different `songId` format, no curated lookup key) also match correctly when the same song appears in a future generation from a different source.
- [ ] **Score consistency:** Adding feedback dimension changes all existing test assertions for `SongQualityScorer`. Verify ALL existing scorer tests still pass or are intentionally updated. A silent test regression means the scoring balance shifted without detection.
- [ ] **Freshness with empty history:** Freshness feature works after 5 playlists, but verify it handles the edge case of 0 playlists in history (first-time generation). Freshness penalty should be 0, not crash or return null.
- [ ] **Feedback for songs no longer in curated dataset:** User liked a song, then the curated dataset is updated (Supabase refresh) and that song is removed. The feedback entry persists but the song may never appear again. Verify the feedback library screen handles "orphaned" feedback gracefully (shows the song title from stored feedback, not from curated lookup).
- [ ] **Toggle state persistence:** Freshness toggle (fresh vs taste-optimized) must persist across app restarts. Verify it is saved to SharedPreferences and restored on launch, not defaulting to a hardcoded value every time.
- [ ] **Feedback works across taste profiles:** If the user has Profile A (Pop) and Profile B (Metal), feedback is per-song, not per-profile. Verify that liking a song while Profile A is active also shows the like when Profile B is active. Feedback is a property of the song, not the profile.
- [ ] **Dislike penalty does not compound with disliked artist penalty:** Verify that a song by a disliked artist that is also individually disliked gets `max(penalty)` not `sum(penalties)`.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Scoring balance wrong (#1) | LOW | Change weight constants in `SongQualityScorer` and re-test. No data migration needed. All scoring is recomputed at generation time. |
| SharedPreferences too large (#2) | MEDIUM | Migrate to compact format (requires data migration code); or move to SQLite/Drift (requires new dependency + migration). Can be done incrementally: new feedback uses new format, old feedback migrated on first load. |
| Filter bubble formed (#3) | LOW | Add/increase freshness penalty; add exploration slot. Existing feedback data is still valid. The fix is algorithmic, not a data migration. |
| Taste learning overfit (#4) | LOW | Revert taste learning to song-level-only (no genre inference). Taste profile is unmodified. The fix is removing the overfitting logic, not restoring data. |
| Lookup key mismatch (#5) | MEDIUM | Requires re-normalizing all existing feedback keys to the new format. Old keys may not round-trip perfectly. Some feedback entries may be orphaned (cannot be re-associated with songs). |
| Small pool unplayable (#6) | LOW | Reduce or disable freshness penalty for small pools. Algorithmic fix, no data impact. |
| Feedback fatigue (#7) | LOW | UI redesign to reduce friction. No data impact. But if users already stopped providing feedback, reactivation is hard. |
| Blacklist spiral (#8) | LOW | Reduce dislike penalty weight. Consider bulk "reset dislikes" option if pool is severely depleted. |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Scoring balance (#1) | Feedback-to-scorer integration | Unit test: liked song with low runnability does NOT outrank unrated song with high runnability |
| SharedPreferences growth (#2) | Feedback data model (first phase) | Performance test: serialize/deserialize 2,000 feedback entries in <50ms; total SharedPreferences <500KB |
| Filter bubble (#3) | Freshness tracking + feedback integration (must be co-designed) | Integration test: generate 10 playlists sequentially, measure song overlap between playlist 1 and playlist 10 (should be <30%) |
| Taste learning overfit (#4) | Taste learning phase | Test: user with Pop profile likes 5 Hip-Hop songs; generated playlist is still >60% Pop |
| Lookup key mismatch (#5) | Feedback data model (first phase) | Unit test: same song from curated and API sources produces same feedback key |
| Small pool (#6) | Freshness tracking | Test: generate 10 playlists at BPM 190; verify 10th playlist still fills all segments |
| Feedback fatigue (#7) | Feedback UI | User testing: average feedback actions per playlist should be 2-5, not 0 or 15 |
| Blacklist spiral (#8) | Feedback-to-scorer integration | Test: dislike 50 songs in 165 BPM range; verify playlist still fills all segments |

## Sources

- [Filter Bubbles in Recommender Systems: Fact or Fallacy](https://arxiv.org/html/2307.01221) -- systematic review of feedback loop reinforcement in recommendation
- [When You Hear "Filter Bubble" -- Think "Feedback Loop"](https://medium.com/understanding-recommenders/when-you-hear-filter-bubble-echo-chamber-or-rabbit-hole-think-feedback-loop-7d1c8733d5c) -- conceptual framework for understanding recommendation feedback loops
- [Choosing the Right Weights: Balancing Value, Strategy, and Noise](https://arxiv.org/html/2305.17428) -- research on weight balancing in recommendation scoring systems
- [Comparison of implicit and explicit feedback from an online music recommendation service](https://dl.acm.org/doi/10.1145/1869446.1869453) -- Last.fm study showing complementary nature of implicit/explicit feedback
- [Inside Spotify's Recommendation System](https://www.music-tomorrow.com/blog/how-spotify-recommendation-system-works-complete-guide) -- Spotify's approach to balancing freshness, relevance, and user feedback
- [Measuring Recency Bias in Sequential Recommendation Systems](https://arxiv.org/html/2409.09722v1) -- research on recency bias in sequential recommendations
- [Apple HIG: Explicit Feedback](https://developers.apple.com/design/human-interface-guidelines/machine-learning/inputs/explicit-feedback/) -- Apple's guidance on when and how to request explicit feedback
- [When SharedPreferences Fails: Resilient Cache Infrastructure](https://dev.to/devmatrash/when-sharedpreferences-fails-architecting-resilient-cache-infrastructure-for-production-flutter-3j3d) -- SharedPreferences performance limits in production Flutter apps
- [Artist/album/song name text normalization](http://labrosa.ee.columbia.edu/projects/musicsim/normalization.html) -- Columbia University research on music metadata normalization challenges
- [Cold start (recommender systems)](https://en.wikipedia.org/wiki/Cold_start_(recommender_systems)) -- overview of cold start problem and graceful degradation strategies
- [A Survey on Popularity Bias in Recommender Systems](https://arxiv.org/html/2308.01118v3) -- comprehensive survey on popularity bias and mitigation
- Codebase analysis: `song_quality_scorer.dart`, `playlist_generator.dart`, `playlist_history_preferences.dart`, `taste_profile.dart`, `curated_song.dart`, `curated_song_repository.dart`

---
*Pitfalls research for: v1.3 Song Feedback, Taste Learning & Freshness -- Running Playlist AI*
*Researched: 2026-02-06*
