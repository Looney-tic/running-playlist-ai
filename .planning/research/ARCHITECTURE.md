# Architecture Patterns: v1.3 Song Feedback & Freshness

**Domain:** Song feedback loop, taste learning from feedback, playlist freshness tracking
**Researched:** 2026-02-06
**Overall confidence:** HIGH (based on direct codebase analysis of all integration points)

---

## Current Architecture Snapshot (v1.2 Baseline)

### Application Structure

```
lib/features/
  {feature}/
    data/            -- SharedPreferences static wrappers
    domain/          -- Pure Dart models, enums, calculators
    presentation/    -- Flutter screens and widgets
    providers/       -- Riverpod StateNotifier + state classes
```

### Key Components Being Extended

| Component | File | Current Role |
|-----------|------|-------------|
| `SongQualityScorer` | `song_quality/domain/song_quality_scorer.dart` | Static scorer: 8 dimensions, max ~46 points. All methods pure and static. |
| `PlaylistGenerator` | `playlist/domain/playlist_generator.dart` | Pure synchronous generator: scores candidates, fills segments, enforces diversity. |
| `PlaylistGenerationNotifier` | `playlist/providers/playlist_providers.dart` | Orchestrator: fetches songs, reads providers, calls generator, saves to history. |
| `PlaylistSong` | `playlist/domain/playlist.dart` | Song-in-playlist model with title, artist, BPM, matchType, quality score. |
| `BpmSong` | `bpm_lookup/domain/bpm_song.dart` | Candidate song model with songId, genre, decade, danceability, runnability. |
| `TasteProfile` | `taste_profile/domain/taste_profile.dart` | User preferences: genres, artists, energyLevel, decades, dislikedArtists. |
| `SongTile` | `playlist/presentation/widgets/song_tile.dart` | Song card UI: shows title, artist, BPM chip, star badge, tap-for-play-links. |
| `PlaylistHistoryPreferences` | `playlist/data/playlist_history_preferences.dart` | Stores up to 50 playlists as single JSON blob. |

### Current Scoring Dimensions (SongQualityScorer)

```
Dimension              Weight   Source
---------              ------   ------
Artist match           +10      TasteProfile.artists
Runnability            0-15     CuratedSong runnability score
Danceability           0-8      Song danceability (neutral=3 if null)
Genre match            +6       TasteProfile.genres
Decade match           +4       TasteProfile.decades
BPM match              +3/+1    BpmMatchType (exact/variant)
Artist diversity       -5       Previous song in sequence
Disliked artist        -15      TasteProfile.dislikedArtists
```

### Current Provider Dependency Graph

```
playlistGenerationProvider
  |-- reads runPlanNotifierProvider
  |-- reads tasteProfileNotifierProvider
  |-- reads getSongBpmClientProvider
  |-- reads curatedRunnabilityProvider
  |-- writes playlistHistoryProvider (auto-save)

tasteProfileLibraryProvider (self-loading)
playlistHistoryProvider (self-loading)
```

### Current Persistence Pattern

All features use static wrapper classes around SharedPreferences:
- Single key per data collection (e.g., `taste_profile_library`, `playlist_history`)
- Entire collection serialized as one JSON string
- Load-all / save-all pattern (no partial updates)
- Some use TTL (BpmCachePreferences: 7 days, CuratedSongRepository: 24 hours)

---

## New Data Models

### 1. SongFeedback

Represents a single user feedback entry for a song.

```dart
/// A user's like/dislike feedback for a specific song.
class SongFeedback {
  const SongFeedback({
    required this.songKey,      // 'artist|title' normalized lookup key
    required this.artistName,   // original casing for display
    required this.title,        // original casing for display
    required this.isLiked,      // true = liked, false = disliked
    required this.feedbackAt,   // when feedback was given
    this.genre,                 // from song metadata at feedback time
    this.bpm,                   // from song metadata at feedback time
    this.decade,                // from song metadata at feedback time
  });

  final String songKey;         // primary identifier
  final String artistName;
  final String title;
  final bool isLiked;
  final DateTime feedbackAt;
  final String? genre;          // captured for taste learning
  final int? bpm;               // captured for taste learning
  final String? decade;         // captured for taste learning
}
```

**Why capture metadata at feedback time:** Taste learning needs to analyze patterns across liked/disliked songs (e.g., "user likes 80% hip-hop"). Storing genre/bpm/decade at feedback time means the taste learner can operate on feedback data alone without joining against the song pool or curated dataset.

**Key format:** Same `artist.toLowerCase().trim()|title.toLowerCase().trim()` format already used throughout the codebase (CuratedSong.lookupKey, BpmSong matching, replacement filtering).

### 2. SongPlayRecord

Represents a song's appearance in a generated playlist.

```dart
/// Records that a song appeared in a generated playlist.
class SongPlayRecord {
  const SongPlayRecord({
    required this.songKey,      // 'artist|title' normalized lookup key
    required this.playedAt,     // when the playlist was generated
  });

  final String songKey;
  final DateTime playedAt;
}
```

**Why "played" means "appeared in generated playlist":** Users do not listen within the app -- they open Spotify/YouTube via external links. The app cannot know which songs were actually listened to. The closest proxy is "appeared in a playlist the user generated," which is the event this model tracks.

### 3. FreshnessPreference (Enum or Toggle)

```dart
/// User preference for playlist freshness vs taste optimization.
enum FreshnessMode {
  /// Deprioritize recently generated songs. Favors variety.
  keepFresh,

  /// Ignore play history. Optimize purely for taste match.
  optimizeForTaste,
}
```

---

## Persistence Strategy

### Feedback Storage: SharedPreferences (Recommended)

**Decision: Stay with SharedPreferences for feedback data.**

**Rationale:**
- Feedback volume is bounded by user interaction rate. A very active user might provide 5-15 feedback entries per generated playlist, with 2-3 playlists per week. After a year: ~1,500 entries. Power users might reach 3,000-5,000 over the app's lifetime.
- Each `SongFeedback` JSON entry is roughly 150-200 bytes. At 5,000 entries: ~1 MB. SharedPreferences handles this comfortably (practical limit ~1.4 MB per entry on Android, with the full store being much larger).
- The existing codebase uses SharedPreferences exclusively. Introducing sqflite/Hive would add a dependency, a new persistence pattern, and migration complexity for a dataset that fits within SharedPreferences' capabilities.
- Access pattern is always "load all, filter in memory" (no complex queries). No pagination needed at this scale.

**Key:** `song_feedback` -- single JSON blob with all feedback entries.

**Structure:**

```json
{
  "feedbacks": [
    {
      "songKey": "eminem|lose yourself",
      "artistName": "Eminem",
      "title": "Lose Yourself",
      "isLiked": true,
      "feedbackAt": "2026-02-06T14:30:00.000Z",
      "genre": "hipHop",
      "bpm": 171,
      "decade": "2000s"
    }
  ]
}
```

### Play History Storage: SharedPreferences with Rolling Window

**Decision: Store play records with a 90-day rolling window, trimmed on save.**

Play history grows faster than feedback (every song in every generated playlist gets a record). A playlist has ~10-20 songs. At 3 playlists/week: ~45-60 records/week, ~2,500/year.

Rolling window approach:
- On save, trim records older than 90 days
- 90 days at 3 playlists/week = ~780 records = ~50 KB. Well within SharedPreferences limits.
- The freshness system only needs to know "was this song generated recently?" -- 90 days is more than sufficient.

**Key:** `song_play_history` -- single JSON blob.

**Structure:**

```json
{
  "records": [
    {
      "songKey": "eminem|lose yourself",
      "playedAt": "2026-02-06T14:30:00.000Z"
    }
  ]
}
```

### Freshness Preference Storage

**Decision: Store as part of an app-level settings preferences key.**

The Settings screen is currently a placeholder. `FreshnessMode` is the first real setting. Store under a `settings` key:

```json
{
  "freshnessMode": "keepFresh"
}
```

**Alternative considered:** Storing on TasteProfile. Rejected because freshness mode is a playlist generation preference, not a musical taste attribute. Users expect one freshness setting across all taste profiles.

---

## Integration Points: Detailed Analysis

### Integration Point 1: SongQualityScorer -- New Feedback Dimension

**What changes:** Add a `feedbackScore` parameter and scoring dimension.

**Current signature:**

```dart
static int score({
  required BpmSong song,
  TasteProfile? tasteProfile,
  String? previousArtist,
  List<RunningGenre>? songGenres,
  int? runnability,
})
```

**Proposed signature:**

```dart
static int score({
  required BpmSong song,
  TasteProfile? tasteProfile,
  String? previousArtist,
  List<RunningGenre>? songGenres,
  int? runnability,
  bool? isLiked,        // NEW: null = no feedback, true = liked, false = disliked
})
```

**New dimension weights:**

```dart
/// Score bonus for songs the user explicitly liked.
static const likedSongWeight = 12;

/// Score penalty for songs the user explicitly disliked.
static const dislikedSongWeight = -20;
```

**Why these weights:**
- `likedSongWeight = 12`: Slightly stronger than artist match (+10) but weaker than runnability max (+15). A liked song should rank high but not override terrible BPM fit. This makes explicit feedback the second-strongest positive signal.
- `dislikedSongWeight = -20`: Stronger than disliked artist (-15). An explicit dislike on a specific song is a stronger signal than disliking an artist in general. This effectively buries disliked songs to the bottom of rankings but does not hard-filter them (they can still appear if the pool is very small).

**Why `bool? isLiked` not a separate method:**
- Keeps scoring unified in one method. The caller already passes multiple optional parameters.
- `null` = no feedback (neutral, no score impact). Clean three-state representation.
- Follows the existing pattern where null values degrade gracefully (see `danceability`, `runnability`).

**New scoring helper:**

```dart
static int _feedbackScore(bool? isLiked) {
  if (isLiked == null) return 0;
  return isLiked ? likedSongWeight : dislikedSongWeight;
}
```

**Updated max score:** Current max is ~46 (artist:10 + runnability:15 + danceability:8 + genre:6 + decade:4 + BPM:3). With feedback: ~58 (adds liked:12). Minimum drops further with disliked: -40 possible (disliked:-20, dislikedArtist:-15, diversity:-5).

**Confidence:** HIGH. Direct analysis of SongQualityScorer shows this is a clean extension. All dimensions are additive. No architectural change needed.

### Integration Point 2: PlaylistGenerator -- Feedback Lookup During Scoring

**What changes:** `_scoreAndRank` needs access to a feedback lookup map.

**Current `_scoreAndRank` flow:**
1. For each candidate song, compute lookup key
2. Look up runnability from `curatedRunnability` map
3. Call `SongQualityScorer.score()`

**Proposed extension:**
1. For each candidate song, compute lookup key (already done)
2. Look up runnability from `curatedRunnability` map (existing)
3. **Look up feedback from `feedbackMap`** (NEW)
4. Call `SongQualityScorer.score()` with new `isLiked` parameter

**New parameter on `PlaylistGenerator.generate()`:**

```dart
static Playlist generate({
  required RunPlan runPlan,
  required Map<int, List<BpmSong>> songsByBpm,
  TasteProfile? tasteProfile,
  Random? random,
  Map<String, int>? curatedRunnability,
  Map<String, bool>? songFeedback,     // NEW: songKey -> isLiked
})
```

**Why `Map<String, bool>` not `Map<String, SongFeedback>`:**
- The generator only needs the boolean signal per song key. No need to pass the full feedback model into the pure domain layer.
- Same pattern as `curatedRunnability: Map<String, int>` -- a simple lookup map.

**Lookup inside `_scoreAndRank`:**

```dart
final isLiked = songFeedback?[lookupKey]; // null if no feedback
```

The `lookupKey` is already computed on the line above for runnability lookup. Zero additional computation.

**Confidence:** HIGH. The lookup key infrastructure exists. This is a one-line addition to the scoring loop.

### Integration Point 3: PlaylistGenerationNotifier -- Loading Feedback and Play History

**What changes:** The notifier needs to load feedback data and record play history.

**Loading feedback (in `generatePlaylist()` and `shufflePlaylist()`):**

```dart
// Load feedback map for scoring
var feedbackMap = <String, bool>{};
try {
  feedbackMap = await ref.read(songFeedbackProvider.notifier).getFeedbackMap();
} catch (_) {
  // Graceful degradation: generate without feedback data
}
```

This follows the exact same pattern as the existing `curatedRunnability` loading.

**Recording play history (after generation):**

```dart
// Record songs as "played" for freshness tracking
unawaited(
  ref.read(playHistoryProvider.notifier).recordPlaylistSongs(playlist),
);
```

This follows the exact same pattern as the existing `playlistHistoryProvider` auto-save.

**Where freshness plugs in:** Before scoring, the notifier can optionally filter or annotate songs with a freshness penalty based on play history. See Integration Point 5 below.

**Confidence:** HIGH. The notifier already demonstrates all these patterns with curatedRunnability and playlistHistory.

### Integration Point 4: SongTile -- Feedback Buttons in UI

**What changes:** Add like/dislike buttons to the song tile or its bottom sheet.

**Current SongTile interaction:** Tap opens a bottom sheet with "Open in Spotify" and "Open in YouTube Music" options.

**Proposed UI extension -- two approaches:**

**Option A: Inline buttons on the song tile (Recommended)**

Add small like/dislike icon buttons at the trailing edge of the SongTile, before the BPM chip. This keeps feedback one-tap -- no extra navigation.

```
[1] [star] Song Title                [thumbs-up] [thumbs-down] [170]
         Artist Name
```

**Pros:** Immediate, discoverable, low friction.
**Cons:** Adds visual complexity to every tile. Need to handle feedback state display (already liked? already disliked?).

**Option B: Buttons in the bottom sheet**

Add like/dislike as additional ListTile entries in the existing `_showPlayOptions` bottom sheet.

**Pros:** Cleaner song tile. Consistent with existing interaction pattern.
**Cons:** Requires two taps (tap song, then tap like/dislike). Higher friction.

**Recommendation: Option A (inline).** The whole point of feedback is to make it effortless. Two taps is too much friction for a feature that needs high engagement to be useful. The visual complexity concern is mitigable with subtle icons and color states.

**SongTile needs to become a ConsumerWidget** (or accept a callback) to read/write feedback state. Currently it is a plain StatelessWidget. Options:
1. Pass an `onLike`/`onDislike` callback from the parent (keeps SongTile stateless)
2. Make SongTile a ConsumerWidget that reads `songFeedbackProvider`

**Recommendation: Pass callbacks.** SongTile is used in both PlaylistScreen and PlaylistHistoryDetailScreen. Callbacks let each parent decide whether feedback is available. The history detail screen can choose to show feedback buttons or not.

**Confidence:** HIGH. SongTile is a simple stateless widget; extending it is straightforward.

### Integration Point 5: Freshness -- Scoring Penalty for Recently Generated Songs

**What changes:** Add a freshness dimension to scoring, controlled by user preference.

**Design decision: Freshness as a scoring penalty, not a hard filter.**

Freshness should deprioritize recent songs, not exclude them. In a small song pool (narrow BPM range, few API results), excluding recent songs could leave too few candidates. A scoring penalty naturally degrades -- when the pool is small, recent songs still appear; when the pool is large, fresh songs win.

**New scoring dimension:**

```dart
/// Penalty for songs that appeared in recent playlists.
static const freshnessPenalty = -8;
```

**Why -8:** Strong enough to push recently-played songs below fresh alternatives of similar quality, but not so strong that a great-matching recent song loses to a poor-matching fresh one. For context: a fresh song with no feedback vs. a recent song with no feedback -- the fresh song wins by 8 points (roughly equivalent to max danceability bonus).

**Implementation in PlaylistGenerator (not SongQualityScorer):**

The freshness penalty should be applied in `PlaylistGenerator._scoreAndRank`, not in `SongQualityScorer`, because:
1. Freshness depends on user preference (`FreshnessMode`) which is a generation-time setting, not a song attribute
2. Freshness depends on play history which is a time-varying data source, not a static song property
3. `SongQualityScorer` is designed to be pure and deterministic -- adding time-varying state breaks its contract

**Implementation:**

```dart
// In _scoreAndRank:
var score = SongQualityScorer.score(
  song: song,
  tasteProfile: tasteProfile,
  previousArtist: previousArtist,
  songGenres: songGenres,
  runnability: runnability,
  isLiked: feedbackMap?[lookupKey],
);

// Apply freshness penalty if enabled
if (freshnessMode == FreshnessMode.keepFresh) {
  final isRecent = recentSongKeys?.contains(lookupKey) ?? false;
  if (isRecent) score += freshnessPenalty;  // -8
}
```

**How `recentSongKeys` is built:** Before generation, load play history records from last N days (configurable, default 14 days) and build a `Set<String>` of song keys. This is a one-time cost per generation, O(n) in play history size.

**Confidence:** HIGH. This mirrors the existing `curatedRunnability` pattern -- a pre-built lookup passed into the generator.

### Integration Point 6: Taste Learning -- Statistical Analysis of Feedback

**What changes:** New pure-domain analyzer that reads feedback data and produces implicit preference signals.

**Design: Taste learning is a read-only analyzer, not a modifier.**

Taste learning does NOT mutate the TasteProfile. Instead, it produces a separate `LearnedPreferences` model that supplements explicit taste profile preferences during scoring. This is important because:
1. Users explicitly set their taste profile. Auto-modifying it would be surprising and annoying.
2. Learned preferences should be transparent ("We noticed you like 70% hip-hop") not silently applied.
3. If learning produces bad recommendations, the user can reset learned data without losing their explicit profile.

**LearnedPreferences model:**

```dart
/// Implicit preferences discovered from feedback patterns.
class LearnedPreferences {
  const LearnedPreferences({
    this.genreAffinities = const {},    // genre -> affinity (-1.0 to 1.0)
    this.artistAffinities = const {},   // artist -> affinity (-1.0 to 1.0)
    this.bpmCenter,                     // preferred BPM center (null if insufficient data)
    this.decadeAffinities = const {},   // decade -> affinity (-1.0 to 1.0)
  });

  final Map<String, double> genreAffinities;
  final Map<String, double> artistAffinities;
  final int? bpmCenter;
  final Map<String, double> decadeAffinities;
}
```

**Affinity calculation (simple, effective):**

```dart
// For each genre:
//   liked_count = songs liked with this genre
//   disliked_count = songs disliked with this genre
//   total = liked_count + disliked_count
//   affinity = (liked_count - disliked_count) / total
//   Ranges from -1.0 (all disliked) to +1.0 (all liked)
//   Only include genres with >= 3 total feedback entries (minimum sample)
```

**How learned preferences integrate with scoring:**

Option A: Add learned preference weights as additional scoring dimensions.
Option B: Modify existing dimension weights based on learned data.

**Recommendation: Option A -- additional scoring dimensions.** This is cleaner because:
- Does not modify existing dimension behavior
- Learned preferences have their own weight budget
- Easy to A/B test or disable without touching existing scoring

**New scoring integration (in PlaylistGenerator, not SongQualityScorer):**

```dart
// After SongQualityScorer.score(), apply learned preference bonus
if (learnedPreferences != null && song.genre != null) {
  final genreAffinity = learnedPreferences.genreAffinities[song.genre] ?? 0.0;
  score += (genreAffinity * learnedGenreWeight).round();  // e.g., weight = 4
}
```

**Why low weight (4 max):** Learned preferences are implicit signals. They should nudge scoring, not dominate it. If a user explicitly picks "Pop" in their taste profile (+6 for genre match), the learned signal adds at most +4 more. But if a user does not pick Pop but consistently likes Pop songs, learned preferences start boosting Pop songs modestly.

**Minimum feedback threshold:** Taste learning should not run until the user has provided at least 10 feedback entries. Below that, statistical patterns are unreliable.

**Confidence:** MEDIUM. The affinity calculation is straightforward, but the optimal weights for learned preferences need tuning through real usage. The architecture is sound; the numbers may need adjustment.

---

## New Feature Directory Structure

```
lib/features/
  song_feedback/                          # NEW FEATURE
    data/
      song_feedback_preferences.dart      # SharedPreferences wrapper for feedback
    domain/
      song_feedback.dart                  # SongFeedback model
      taste_learner.dart                  # Pure Dart analyzer: feedback -> LearnedPreferences
      learned_preferences.dart            # LearnedPreferences model
    presentation/
      feedback_library_screen.dart        # Browse/edit all feedback
      widgets/
        feedback_buttons.dart             # Like/dislike button widget (optional extraction)
    providers/
      song_feedback_providers.dart        # SongFeedbackNotifier + state

  freshness/                              # NEW FEATURE
    data/
      play_history_preferences.dart       # SharedPreferences wrapper for play records
      freshness_preferences.dart          # FreshnessMode setting persistence
    domain/
      play_history.dart                   # SongPlayRecord model
      freshness_mode.dart                 # FreshnessMode enum
    providers/
      freshness_providers.dart            # PlayHistoryNotifier + FreshnessMode provider
```

**Why two features, not one:** Feedback and freshness have distinct data models, distinct persistence, and can be built and tested independently. Feedback is about learning user preferences; freshness is about playlist variety. They converge only at the scoring stage.

---

## New Components

| Component | Layer | Feature | Purpose |
|-----------|-------|---------|---------|
| `SongFeedback` | domain | song_feedback | Feedback entry model with metadata |
| `SongFeedbackPreferences` | data | song_feedback | Load/save all feedback entries |
| `SongFeedbackNotifier` | provider | song_feedback | CRUD operations on feedback, exposes `feedbackMap` |
| `TasteLearner` | domain | song_feedback | Static analyzer: `List<SongFeedback>` -> `LearnedPreferences` |
| `LearnedPreferences` | domain | song_feedback | Implicit preference model (affinities) |
| `FeedbackLibraryScreen` | presentation | song_feedback | Browse/edit all liked/disliked songs |
| `SongPlayRecord` | domain | freshness | Play history record model |
| `PlayHistoryPreferences` | data | freshness | Load/save play records with rolling trim |
| `FreshnessPreferences` | data | freshness | Load/save FreshnessMode setting |
| `FreshnessMode` | domain | freshness | Enum: keepFresh vs optimizeForTaste |
| `PlayHistoryNotifier` | provider | freshness | Record plays, expose recent song keys |
| `FreshnessSettingNotifier` | provider | freshness | Expose freshness mode preference |

## Modified Components

| Component | File | Modification | Reason |
|-----------|------|-------------|--------|
| `SongQualityScorer` | `song_quality_scorer.dart` | Add `isLiked` parameter + `_feedbackScore` helper + weight constants | Feedback scoring dimension |
| `PlaylistGenerator` | `playlist_generator.dart` | Add `songFeedback` map parameter, pass to scorer, apply freshness penalty | Integrate feedback + freshness into generation |
| `PlaylistGenerationNotifier` | `playlist_providers.dart` | Load feedback map + learned preferences + record play history + read freshness mode | Orchestrate new data sources |
| `SongTile` | `song_tile.dart` | Add like/dislike callback parameters + visual state (liked/disliked/none) | Feedback UI on each song |
| `PlaylistScreen` | `playlist_screen.dart` | Pass feedback callbacks to SongTile, read feedback provider | Wire feedback UI |
| `SettingsScreen` | `settings_screen.dart` | Add freshness mode toggle | User preference UI |

## Components NOT Modified

| Component | Why Unchanged |
|-----------|--------------|
| `TasteProfile` | Learned preferences are separate from explicit profile |
| `TasteProfilePreferences` | No change to taste profile persistence |
| `TasteProfileLibraryNotifier` | No change to taste profile CRUD |
| `BpmSong` | Song model does not carry feedback state |
| `PlaylistSong` | Feedback is looked up by key, not stored on the playlist model |
| `Playlist` | Playlist structure unchanged |
| `PlaylistHistoryPreferences` | Play history is a separate concern from playlist history |
| `CuratedSongRepository` | Curated data is independent of feedback |
| `RunPlan` / run plan infrastructure | Completely unrelated |

---

## Data Flow: Feedback Collection

```
User sees playlist with songs (PlaylistScreen)
  |
  v
User taps like/dislike on SongTile
  |
  v
PlaylistScreen calls SongFeedbackNotifier.setFeedback(
  songKey: lookupKey,
  artistName: song.artistName,
  title: song.title,
  isLiked: true/false,
  genre: song.genre,       // captured from PlaylistSong metadata if available
  bpm: song.bpm,
  decade: song.decade,     // may be null for API-sourced songs
)
  |
  v
SongFeedbackNotifier updates in-memory state + persists to SharedPreferences
  |
  v
SongTile rebuilds with updated visual state (filled thumb icon, color change)
```

**Note on genre/decade availability:** `PlaylistSong` currently stores `title`, `artistName`, `bpm`, `matchType`, `segmentLabel`, `segmentIndex`, `songUri`, `spotifyUrl`, `youtubeUrl`, `runningQuality`, `durationSeconds`. It does NOT store `genre` or `decade`. Two options:

**Option A (Recommended):** When constructing `PlaylistSong` in the generator, also store genre and decade from the `BpmSong` source. This requires adding two nullable fields to `PlaylistSong`.

**Option B:** Look up genre/decade from the curated dataset or song pool when feedback is given. This is fragile because the song pool is only available while a playlist is loaded.

**Recommendation: Option A.** Add `genre` and `decade` to `PlaylistSong`. The fields are nullable and only add a few bytes per song in the JSON. This also enables future UI enhancements (showing genre/decade on song tiles).

## Data Flow: Feedback Reading During Generation

```
User taps "Generate Playlist"
  |
  v
PlaylistGenerationNotifier.generatePlaylist()
  |
  +-> ref.read(songFeedbackProvider) -> feedbackMap: Map<String, bool>
  +-> ref.read(freshnessSettingProvider) -> FreshnessMode
  +-> ref.read(playHistoryProvider) -> recentSongKeys: Set<String>
  +-> (existing) ref.read(curatedRunnabilityProvider)
  +-> (existing) ref.read(runPlanNotifierProvider)
  +-> (existing) ref.read(tasteProfileNotifierProvider)
  |
  v
PlaylistGenerator.generate(
  runPlan: ...,
  songsByBpm: ...,
  tasteProfile: ...,
  curatedRunnability: ...,
  songFeedback: feedbackMap,           // NEW
  recentSongKeys: recentSongKeys,      // NEW (only if keepFresh mode)
  learnedPreferences: learnedPrefs,    // NEW (only if enough feedback)
)
  |
  v
For each candidate in _scoreAndRank:
  1. Compute lookupKey (existing)
  2. Look up runnability (existing)
  3. Look up feedback: feedbackMap[lookupKey] -> isLiked (NEW)
  4. Call SongQualityScorer.score(..., isLiked: isLiked) (MODIFIED)
  5. Apply freshness penalty if recent and keepFresh mode (NEW)
  6. Apply learned preference bonus (NEW)
  |
  v
Playlist generated with feedback-informed scoring
  |
  v
PlaylistGenerationNotifier records play history:
  ref.read(playHistoryProvider.notifier).recordPlaylistSongs(playlist)
```

## Data Flow: Taste Learning

```
TasteLearner.analyze(List<SongFeedback> feedbacks) -> LearnedPreferences
  |
  (Pure synchronous function, no side effects)
  |
  Calculations:
  1. Group feedbacks by genre
  2. For each genre with >= 3 entries: compute affinity
  3. Group feedbacks by artist (normalized)
  4. For each artist with >= 2 entries: compute affinity
  5. Compute median BPM of liked songs (if >= 5 liked)
  6. Group feedbacks by decade
  7. For each decade with >= 3 entries: compute affinity
  |
  Returns LearnedPreferences
```

**When to run:** TasteLearner runs at the start of `generatePlaylist()`, after loading feedback. It is a synchronous computation on an in-memory list. At 5,000 entries the computation is O(n) -- negligible compared to API fetches.

**Caching:** LearnedPreferences can be cached in the SongFeedbackNotifier and invalidated when feedback changes. But given the small data size and the fact that it only runs at generation time, eager computation is fine.

---

## Updated Provider Dependency Graph

```
playlistGenerationProvider
  |-- reads runPlanNotifierProvider          (existing)
  |-- reads tasteProfileNotifierProvider     (existing)
  |-- reads getSongBpmClientProvider         (existing)
  |-- reads curatedRunnabilityProvider       (existing)
  |-- reads songFeedbackProvider             (NEW)
  |-- reads playHistoryProvider              (NEW)
  |-- reads freshnessSettingProvider         (NEW)
  |-- writes playlistHistoryProvider         (existing, auto-save)
  |-- writes playHistoryProvider             (NEW, record plays)

songFeedbackProvider
  |-- SongFeedbackNotifier (self-loading from SongFeedbackPreferences)
  |-- Exposes: feedbackMap, allFeedbacks, learnedPreferences

playHistoryProvider
  |-- PlayHistoryNotifier (self-loading from PlayHistoryPreferences)
  |-- Exposes: recentSongKeys (configurable window)

freshnessSettingProvider
  |-- FreshnessSettingNotifier (self-loading from FreshnessPreferences)
  |-- Exposes: FreshnessMode
```

---

## Component Boundaries

```
+-------------------------------------------------------------------------+
|                        PRESENTATION LAYER                               |
|                                                                         |
|  PlaylistScreen -----> SongTile (+ like/dislike callbacks)              |
|  PlaylistHistoryDetailScreen -> SongTile (+ like/dislike callbacks)     |
|                                                                         |
|  FeedbackLibraryScreen   <-- NEW (browse/edit all feedback)             |
|  SettingsScreen          <-- MODIFIED (freshness toggle)                |
|                                                                         |
+----+--------------------+------------------+----------------------------+
     |                    |                  |
+----+--------------------+------------------+----------------------------+
|                        PROVIDER LAYER                                   |
|                                                                         |
|  playlistGenerationProvider  (MODIFIED: reads new providers)            |
|                                                                         |
|  songFeedbackProvider        <-- NEW                                    |
|  playHistoryProvider         <-- NEW                                    |
|  freshnessSettingProvider    <-- NEW                                    |
|                                                                         |
|  tasteProfileLibraryProvider (unchanged)                                |
|  runPlanLibraryProvider      (unchanged)                                |
|                                                                         |
+----+--------------------+------------------+----------------------------+
     |                    |                  |
+----+--------------------+------------------+----------------------------+
|                        DOMAIN LAYER                                     |
|                                                                         |
|  SongQualityScorer       (MODIFIED: +isLiked parameter)                 |
|  PlaylistGenerator       (MODIFIED: +feedback/freshness/learned params) |
|  TasteLearner            <-- NEW (pure analyzer)                        |
|                                                                         |
|  SongFeedback            <-- NEW (model)                                |
|  LearnedPreferences      <-- NEW (model)                                |
|  SongPlayRecord          <-- NEW (model)                                |
|  FreshnessMode           <-- NEW (enum)                                 |
|                                                                         |
+----+--------------------+------------------+----------------------------+
     |                    |                  |
+----+--------------------+------------------+----------------------------+
|                        DATA LAYER                                       |
|                                                                         |
|  SongFeedbackPreferences      <-- NEW                                   |
|  PlayHistoryPreferences       <-- NEW                                   |
|  FreshnessPreferences         <-- NEW                                   |
|                                                                         |
|  PlaylistHistoryPreferences   (unchanged)                               |
|  BpmCachePreferences          (unchanged)                               |
|                                                                         |
+-------------------------------------------------------------------------+
```

---

## Suggested Build Order

Based on dependency analysis -- what must exist before what:

### Phase 1: Feedback Foundation (Data + Domain + Persistence)

**Build:** SongFeedback model, SongFeedbackPreferences, SongFeedbackNotifier.

**Why first:** Everything else depends on having feedback data. The model, persistence, and state management must exist before UI or scoring integration can be built.

**No integration yet** -- just the ability to store and retrieve feedback. Unit test the model, persistence, and notifier in isolation.

**Dependencies:** None. Greenfield feature directory.

### Phase 2: Feedback UI + Scoring Integration

**Build:** SongTile modifications, PlaylistScreen wiring, SongQualityScorer feedback dimension, PlaylistGenerator feedback parameter.

**Why second:** With feedback data available (Phase 1), wire up the full loop: user gives feedback -> feedback stored -> next generation uses feedback in scoring.

**This is the "value delivery" phase** -- after this, the core feedback loop works end-to-end.

**Dependencies:** Phase 1 (feedback data layer).

### Phase 3: Feedback Library Screen

**Build:** FeedbackLibraryScreen with browse/edit/delete.

**Why third:** This is a quality-of-life feature that lets users review their feedback. Not required for the core loop but important for user control and trust.

**Dependencies:** Phase 1 (reads feedback data).

### Phase 4: Freshness Tracking

**Build:** SongPlayRecord model, PlayHistoryPreferences, PlayHistoryNotifier, FreshnessMode, FreshnessPreferences, FreshnessSettingNotifier, SettingsScreen freshness toggle, PlaylistGenerator freshness penalty, PlaylistGenerationNotifier play recording.

**Why fourth:** Freshness is independent of feedback. It could technically be built in parallel with phases 2-3. Placing it after feedback means the scoring system already has the new parameter pattern established, making the freshness penalty addition straightforward.

**Dependencies:** None technically, but benefits from the parameter patterns established in Phase 2.

### Phase 5: Taste Learning

**Build:** TasteLearner, LearnedPreferences, integration into PlaylistGenerator.

**Why last:** Taste learning requires sufficient feedback data to be useful (minimum ~10 entries). By the time this is built, the feedback loop has been running through phases 2-4. Taste learning is also the most experimental feature -- the weights and thresholds may need tuning.

**Dependencies:** Phase 1 (needs feedback data), Phase 2 (scoring integration patterns).

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Mutating TasteProfile from Feedback

**What:** Automatically adding liked artists to `TasteProfile.artists` or disliked artists to `TasteProfile.dislikedArtists`.
**Why bad:** Users explicitly set their taste profile. Silent modifications feel like the app is "going rogue." If a user likes one Metallica song, they do not want Metallica added to their favorite artists list. Feedback preferences and taste profile preferences serve different functions.
**Instead:** Keep `LearnedPreferences` as a separate, transparent model. The user can see "Based on your feedback, you seem to enjoy Hip-Hop" but the taste profile remains under their control.

### Anti-Pattern 2: Hard-Filtering Disliked Songs

**What:** Removing disliked songs from the candidate pool entirely before scoring.
**Why bad:** In narrow BPM ranges or small song pools, hard-filtering could leave too few candidates, resulting in short playlists or empty segments. The user experience of "no songs found" is worse than seeing a disliked song at the bottom of a playlist.
**Instead:** Use strong scoring penalties (-20 for disliked). The song is effectively buried but still available as a last resort.

### Anti-Pattern 3: Storing Feedback on PlaylistSong

**What:** Adding `isLiked` field to `PlaylistSong` and persisting it in playlist history JSON.
**Why bad:** Feedback applies to a song globally (across all playlists), not per-playlist. If a user likes "Lose Yourself" in playlist A, they expect it to be liked when it appears in playlist B. Storing on PlaylistSong creates redundant, potentially inconsistent state.
**Instead:** Feedback is stored in its own collection keyed by song lookup key. UI looks up feedback state per-song at render time.

### Anti-Pattern 4: Full-Collection Save on Every Feedback Tap

**What:** Serializing and saving ALL feedback entries to SharedPreferences every time the user taps like/dislike.
**Why bad:** At 5,000 entries, JSON serialization + write is measurable (10-50ms). During rapid feedback (user scrolling through playlist tapping likes), this could cause jank.
**Instead:** Debounce persistence. Update in-memory state immediately (instant UI response), then debounce the SharedPreferences write (e.g., 500ms after last change). Use `Timer` or a simple debounce helper.

### Anti-Pattern 5: Complex Recommendation Algorithm for Taste Learning

**What:** Building a collaborative filtering or ML-style recommendation engine.
**Why bad:** The song pool is pre-filtered by BPM. The taste profile already handles genre/artist matching. Taste learning is a nudge, not a replacement for the existing scoring system. Complex algorithms are hard to debug, tune, and explain to users.
**Instead:** Simple affinity scores based on feedback ratios. Transparent, debuggable, and effective for the data volume this app handles.

### Anti-Pattern 6: Freshness as a Hard Time Window

**What:** "Never show songs from the last 2 weeks" as a hard filter.
**Why bad:** Same as hard-filtering disliked songs -- can deplete the pool. Also, the "right" time window varies by user. A runner who generates playlists daily needs a shorter window than one who generates weekly.
**Instead:** Scoring penalty (-8) for recent songs. The 90-day rolling window on play history determines what "recent" means. The penalty is moderate -- recent songs can still appear if they score well enough on other dimensions.

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| SharedPreferences feedback blob grows too large (>1.4 MB) | Low | Medium | Cap at 5,000 entries with LRU eviction by feedbackAt |
| Rapid like/dislike tapping causes jank | Medium | Low | Debounce persistence writes (500ms) |
| Taste learning produces poor recommendations | Medium | Medium | Minimum 10-entry threshold, low weight (max +4), transparent display |
| Freshness penalty too strong/weak | Medium | Low | Constant is easy to tune; start conservative at -8 |
| PlaylistSong lacking genre/decade for feedback capture | High | Medium | Add fields to PlaylistSong model (Phase 2) |
| Adding feedback parameter to SongQualityScorer breaks existing tests | Low | Low | Parameter is optional (null = no effect); existing tests pass unchanged |
| Play history grows unbounded | Low | Medium | 90-day rolling window trimmed on save |

---

## Sources

- Direct codebase analysis of all files listed in the Components table above -- **HIGH confidence** (primary source, every file read and analyzed)
- SharedPreferences size limits: ~1.4 MB practical limit per entry on Android ([Flutter: Finding Optimal Size Limit for shared_preferences](https://copyprogramming.com/howto/how-big-is-too-big-in-flutter-shared-preferences)) -- **MEDIUM confidence** (multiple sources agree, but exact limits depend on platform/device)
- SharedPreferences vs SQLite for large datasets: SQLite recommended for complex queries; SharedPreferences sufficient for load-all/save-all at <1 MB ([Flutter Data Storage Comparison](https://medium.com/@dobri.kostadinov/flutter-data-storage-sharedpreferences-room-and-datastore-compared-69bb529803de)) -- **MEDIUM confidence** (general guidance, confirmed by multiple sources)
- Lookup key pattern (`artist|title`) already established in codebase: `CuratedSong.lookupKey`, `PlaylistGenerator._findReplacements`, `PlaylistGenerationNotifier` -- **HIGH confidence** (direct codebase observation)
- SongQualityScorer additive dimension pattern -- **HIGH confidence** (direct analysis of all 8 existing dimensions)
