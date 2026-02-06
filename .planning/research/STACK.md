# Technology Stack: v1.3 Song Feedback, Taste Learning & Playlist Freshness

**Project:** Running Playlist AI
**Milestone:** v1.3 Song Feedback & Taste Learning
**Researched:** 2026-02-06
**Overall confidence:** HIGH

---

## Scope: What This Document Covers

This STACK.md covers **only the additions and changes** needed for v1.3 features. The existing stack (Flutter 3.38, Dart 3.10, Riverpod 2.x manual providers, GoRouter 17.x, SharedPreferences 2.5.4, http, supabase_flutter, url_launcher, GetSongBPM API) is validated and stable from prior milestones. Do not re-evaluate it.

v1.3 features that drive stack decisions:
1. Like/dislike feedback on songs (during playlist view + post-run review)
2. Feedback persistence and browsing (feedback library screen)
3. Scoring integration (liked songs boosted, disliked songs penalized/filtered)
4. Taste learning (analyze feedback patterns to discover implicit preferences)
5. Freshness toggle and tracking (prefer fresh vs familiar songs)

---

## Critical Decision: SharedPreferences Is Still Sufficient

### The Key Question

Song feedback could grow to thousands of entries over months of use. Is SharedPreferences still the right persistence choice, or should we migrate to a proper database?

### Size Analysis

Realistic data volumes for an active runner using the app:
- Runs 3-5 times per week, ~15 songs per playlist = 45-75 songs/week
- Assume they give feedback on ~50% of songs = 22-37 feedback entries/week
- After 6 months: ~570-960 feedback entries
- After 1 year: ~1,140-1,920 feedback entries
- Extreme power user after 2 years: ~4,000 entries maximum

Each feedback entry in JSON is approximately:
```json
{
  "key": "artist name|song title",
  "liked": true,
  "feedbackAt": "2026-02-06T12:00:00.000",
  "lastPlayedAt": "2026-02-06T12:00:00.000",
  "playCount": 3
}
```

That is roughly **120-150 bytes per entry**. At 4,000 entries (extreme case), the total JSON blob is **~600 KB**. This is well within SharedPreferences' practical limits. For comparison, the curated_songs.json bundled asset with 5,066 songs is already loaded into memory at app startup.

### Performance Characteristics

SharedPreferences loads all data into memory on first `getInstance()` call. Subsequent reads are synchronous and effectively instant. The 600 KB extreme case adds negligible load time (~10-20ms on a modern phone). Writes are asynchronous and non-blocking.

The critical performance concern is not read/write speed but **deserialization cost** of parsing a large JSON array. At 4,000 entries, `jsonDecode` takes roughly 5-15ms on a modern device -- negligible.

### Why NOT Switch to a Database

| Factor | Assessment |
|--------|-----------|
| Data volume | ~600 KB max. SharedPreferences handles this fine. |
| Query complexity | We need two operations: (1) lookup by song key (use a `Map<String, FeedbackEntry>`), (2) list all feedback for the library screen. Both are trivial with in-memory maps. |
| Platform support | SharedPreferences works identically on web, Android, iOS. Drift/SQLite requires FFI on native and sql.js on web (different backends). Hive's web support is okay but Hive is community-maintained. |
| Migration cost | Switching to a database mid-project requires migrating ALL existing SharedPreferences data (BPM cache, taste profiles, run plans, playlist history, onboarding state). This is a massive effort for zero user-visible benefit. |
| Consistency | Every other data store in the app uses SharedPreferences + JSON. Introducing a second persistence mechanism creates cognitive load and maintenance burden. |
| Build complexity | Drift requires code generation (broken with Dart 3.10). Hive requires code generation for type adapters. Both add build_runner complexity to an already fragile code-gen setup. |

**Decision: Continue with SharedPreferences for feedback data.** Use the established single-JSON-key pattern (same as `playlist_history`, `taste_profile_library`, `bpm_cache_*`).

**Confidence:** HIGH (size math verified; existing patterns proven across 6 data stores)

### When to Reconsider

If the app adds features that require:
- Complex querying (e.g., "find all liked songs from the 2010s with BPM > 160")
- Cross-device sync with conflict resolution
- Data volumes exceeding 5,000-10,000 entries
- Full-text search across song metadata

None of these are in scope for v1.3 or foreseeable v1.4.

---

## Recommended Stack Additions

### No New Dependencies Required

All v1.3 features can be built with the existing stack. No new pub.dev packages are needed.

| Feature | Stack Approach | New Dependencies |
|---------|---------------|-----------------|
| Song feedback UI (like/dislike) | Flutter Material `IconButton` + Riverpod state | None |
| Feedback persistence | SharedPreferences + JSON (same pattern as all other data) | None |
| Feedback library screen | Standard `ListView` + search/filter, same as taste profile library | None |
| Scoring integration | Extend `SongQualityScorer.score()` with new feedback dimension | None |
| Taste learning algorithm | Pure Dart statistical analysis (no ML libraries) | None |
| Freshness tracking | Timestamp map in SharedPreferences, integrated into scorer | None |
| Freshness toggle | Bool field on generation config, Riverpod state | None |

---

## Feature 1: Song Feedback Persistence

### Data Model Design

**Decision: Use a `Map<String, SongFeedback>` keyed by the existing song lookup key format**

The app already has a normalized song key format: `artist.toLowerCase().trim()|title.toLowerCase().trim()`. This is used throughout `CuratedSongRepository` and `PlaylistGenerator` for cross-source matching. Feedback should use the same key.

```dart
class SongFeedback {
  final String songKey;        // "artist|title" normalized
  final bool liked;            // true = liked, false = disliked
  final DateTime feedbackAt;   // when feedback was given
  final DateTime? lastPlayedAt; // last time song appeared in a playlist
  final int playCount;         // number of times generated in playlists
  final String? artistName;    // denormalized for display
  final String? title;         // denormalized for display
}
```

**Why denormalize artist/title:** The feedback library screen needs to display song names. Without denormalization, we would need to look up each song key in the curated song repository (which only has curated songs, not API-sourced ones). Storing 20-30 extra bytes per entry is trivial compared to the lookup complexity.

**Persistence pattern:**
```dart
class SongFeedbackPreferences {
  static const _key = 'song_feedback';

  static Future<Map<String, SongFeedback>> load() async { ... }
  static Future<void> save(Map<String, SongFeedback> feedback) async { ... }
  static Future<void> clear() async { ... }
}
```

This follows the exact same pattern as `TasteProfilePreferences`, `PlaylistHistoryPreferences`, and `BpmCachePreferences`.

**Confidence:** HIGH (proven pattern, trivial data model)

### In-Memory Access Pattern

**Decision: Load feedback map once at app startup, keep in Riverpod state, write-through on changes**

```dart
class SongFeedbackNotifier extends StateNotifier<Map<String, SongFeedback>> {
  SongFeedbackNotifier() : super({}) { _load(); }

  Future<void> _load() async {
    state = await SongFeedbackPreferences.load();
  }

  Future<void> setFeedback(String songKey, bool liked, {String? artist, String? title}) async {
    final entry = SongFeedback(...);
    state = {...state, songKey: entry};
    await SongFeedbackPreferences.save(state);
  }

  Future<void> removeFeedback(String songKey) async {
    state = Map.from(state)..remove(songKey);
    await SongFeedbackPreferences.save(state);
  }
}
```

**Why Map not List:** Feedback is accessed by song key during scoring (O(1) lookup needed for every candidate song during playlist generation). A list would require O(n) search per song. With 5,066 curated songs scored per generation, O(1) lookup is critical.

**Confidence:** HIGH (same pattern as other notifiers in the codebase)

---

## Feature 2: Scoring Integration

### Extending SongQualityScorer

**Decision: Add a single new scoring dimension for feedback, not multiple**

The current `SongQualityScorer` has 8 dimensions with a theoretical max of ~46 points. Feedback should add one dimension:

| Dimension | Points | Rationale |
|-----------|--------|-----------|
| Liked song | +8 | Strong positive signal -- user explicitly endorsed this song for running |
| Disliked song | -20 | Hard filter equivalent -- user explicitly rejected this song |
| No feedback | 0 | Neutral -- no signal, no penalty |

**Why +8 for liked (not higher):** Liked should be a strong boost but not override everything. A liked song with terrible BPM match (wrong tempo) should still rank below a neutral song with perfect BPM match. +8 puts feedback on par with danceability (max 8) and above genre match (6) but below runnability (max 15) and artist match (10). This reflects that explicit feedback is valuable but BPM match remains the primary purpose of the app.

**Why -20 for disliked (not -15 like disliked artist):** Disliking a specific song is a stronger signal than disliking an artist (the user might like other songs by that artist). A -20 penalty effectively removes the song from consideration without requiring a hard filter, keeping the scorer's ranking-based architecture intact.

**Integration point:** `SongQualityScorer.score()` gains a new optional parameter:

```dart
static int score({
  required BpmSong song,
  TasteProfile? tasteProfile,
  String? previousArtist,
  List<RunningGenre>? songGenres,
  int? runnability,
  bool? songFeedback, // NEW: true=liked, false=disliked, null=no feedback
}) { ... }
```

**Confidence:** HIGH (straightforward extension of existing pure-function scorer)

---

## Feature 3: Taste Learning Algorithm

### The Key Question

Does taste learning need ML libraries (TensorFlow Lite, tflite_flutter) or can simple statistical analysis suffice?

### Decision: Pure Dart Statistical Analysis -- No ML Libraries

For an app with ~500-4,000 feedback entries from a single user, machine learning is overkill. The data is too sparse and too homogeneous (one user's taste) for collaborative filtering or neural networks to provide value over simple frequency analysis.

**What taste learning actually needs to discover:**

| Pattern | Detection Method | Example |
|---------|-----------------|---------|
| Genre preferences from feedback | Count likes/dislikes per genre, compute like ratio | "User likes 80% of Electronic songs but only 30% of Rock songs" |
| Artist preferences from feedback | Count likes per artist | "User liked 5 songs by Dua Lipa but disliked 2 by Metallica" |
| BPM sweet spot | Compute mean/median BPM of liked songs vs disliked | "User likes songs at 168-175 BPM, dislikes outside that range" |
| Energy/danceability preferences | Average danceability of liked vs disliked songs | "User prefers high-danceability songs (avg 78 vs 45)" |

All of these are basic frequency counts, ratios, and averages. They require:
- Iterating over feedback entries (~500-4,000 items)
- Grouping by category (genre, artist, BPM range)
- Computing ratios and averages
- Comparing against thresholds

This is O(n) computation that runs in <1ms on any modern device. No matrix factorization, no gradient descent, no training step.

**Why NOT tflite_flutter or ml_kit:**

| Factor | Assessment |
|--------|-----------|
| Data volume | ~500-4,000 entries from one user. ML models need thousands of users or millions of interactions. |
| Cold start | ML models are useless with <50 entries. Statistical analysis produces meaningful insights from ~10 entries. |
| Model training | Would need to happen on-device (no backend). On-device ML training in Flutter is experimental and adds massive binary size (~15MB for TFLite). |
| Interpretability | Statistical analysis produces human-readable insights ("You like Electronic 80%"). ML models produce opaque vectors. |
| Complexity | ML adds a dependency, model file management, platform-specific FFI. Statistical analysis is 50-100 lines of pure Dart. |
| Accuracy | With single-user data, frequency analysis IS the optimal approach. Collaborative filtering requires a user base. |

### Taste Learning Output

The learning algorithm produces a `LearnedTasteInsights` object:

```dart
class LearnedTasteInsights {
  final Map<RunningGenre, double> genreAffinity;   // genre -> like ratio (0.0-1.0)
  final Map<String, int> artistAffinity;            // artist -> net likes (likes - dislikes)
  final double? preferredBpmCenter;                 // mean BPM of liked songs
  final double? preferredBpmRange;                  // stddev of liked song BPMs
  final double? preferredDanceability;              // mean danceability of liked songs
  final int totalFeedbackCount;                     // confidence indicator
}
```

**How scoring uses learned insights:**

The learned insights are converted to scoring adjustments in `SongQualityScorer`:
- Genre affinity above threshold (e.g., >0.7 like ratio, >5 samples) -> implicit genre boost (+3)
- Genre affinity below threshold (e.g., <0.3 like ratio, >5 samples) -> implicit genre penalty (-3)
- Artist with net positive likes (>2) -> implicit artist boost (+5) if not already in taste profile
- BPM within preferred range -> small boost (+1)

These implicit boosts are SMALLER than explicit taste profile settings (genre match = +6, artist match = +10) because learned preferences have less certainty than explicitly stated ones.

**Minimum sample threshold:** Learning insights require at least 5 feedback entries per category before activating. Below that, the sample size is too small to be meaningful. This prevents a single like of an Electronic song from boosting all Electronic songs.

**Confidence:** HIGH (frequency analysis is a well-understood technique; the data characteristics match perfectly)

---

## Feature 4: Freshness Tracking

### Data Model

**Decision: Track last-played timestamps in a separate SharedPreferences key**

Freshness tracking needs to know when a song was last included in a generated playlist. This is separate from feedback (a song can be fresh/stale regardless of whether the user liked it).

```dart
class FreshnessPreferences {
  static const _key = 'song_freshness';

  // Map<String, DateTime> -- songKey -> lastPlayedAt
  static Future<Map<String, DateTime>> load() async { ... }
  static Future<void> save(Map<String, DateTime> freshness) async { ... }
}
```

**Why separate from feedback:** Not all generated songs receive feedback. Every generated song should update the freshness tracker regardless. Combining with feedback would conflate two independent concerns.

**Size analysis:** Same calculation as feedback -- at most 4,000 entries, each ~80 bytes (key + ISO timestamp). Total ~320 KB. Well within SharedPreferences limits.

### Freshness Scoring Integration

**Decision: Freshness is a scoring modifier, not a hard filter**

Add a freshness dimension to `SongQualityScorer`:

| Freshness State | Points | Rationale |
|----------------|--------|-----------|
| Never played | +3 | Bonus for discovery when "keep it fresh" is on |
| Played > 30 days ago | +2 | Enough time has passed, feels fresh again |
| Played 7-30 days ago | 0 | Neutral |
| Played < 7 days ago | -3 | Recent, penalize when freshness is on |
| Played < 3 days ago | -6 | Very recent, strong penalty when freshness is on |

**Freshness toggle behavior:**
- When "keep it fresh" is ON: Apply freshness scoring as above
- When "optimize for taste" is ON (default): Set all freshness scores to 0 (ignore freshness entirely, maximize for taste/quality)

This is a simple boolean toggle, not a slider. Two clear modes are easier for runners to understand than a freshness-vs-taste continuum.

**Integration:** The freshness map is passed to `PlaylistGenerator.generate()` alongside the feedback map. The generator passes freshness data to the scorer.

**Confidence:** HIGH

---

## Feature 5: Freshness Toggle UI

### Decision: Store as Part of Generation Config, Not a Separate Setting

The freshness toggle is a generation-time preference, like choosing a run plan or taste profile. It should live near those selectors on the playlist generation screen, not buried in app settings.

**Storage:** A single SharedPreferences boolean key `freshness_enabled` (default: false). This follows the same pattern as `onboarding_complete`.

**No new packages needed.** A `SwitchListTile` or `SegmentedButton` in the playlist screen's idle/loaded view is sufficient.

**Confidence:** HIGH

---

## What NOT to Add

| Technology | Why NOT |
|-----------|---------|
| **tflite_flutter** (TensorFlow Lite) | ML is overkill for single-user taste learning from <4,000 entries. Adds ~15MB binary size, platform-specific FFI, model file management. Simple frequency analysis achieves the same or better results for this use case. |
| **drift** / **sqflite** | Data volume (<1MB total) does not justify a database migration. Code generation (required by Drift) is broken with Dart 3.10. Would require migrating ALL existing SharedPreferences data stores. |
| **hive** / **isar** | Hive and Isar are abandoned by their original author and community-maintained. Isar's Rust core makes forking impractical. Neither offers meaningful benefits over SharedPreferences at this data volume. |
| **objectbox** | Commercial NoSQL database -- overkill for local feedback storage. Requires native binaries per platform. |
| **flutter_rating_bar** | Song feedback is binary (like/dislike), not a 1-5 star rating. Two icon buttons are sufficient. Adding a rating package for two buttons is wasteful. |
| **collection** (dart package) | Dart's built-in `Map`, `List`, and `Iterable` methods are sufficient for all statistical computations. No need for `groupBy`, `maxBy`, etc. when the operations are simple counts and averages. |
| **riverpod_generator** | Still broken with Dart 3.10 (documented in project memory). Continue with manual `StateNotifierProvider`. |
| **freezed** (for new models) | Existing domain models use hand-written `fromJson`/`toJson`/`copyWith`. New models should follow the same pattern for consistency. |
| **SharedPreferencesAsync** migration | The legacy `SharedPreferences` API works correctly for all current use cases. Migration adds risk for zero user-visible benefit. Defer until the legacy API is actually deprecated. |

---

## Existing Stack: Confirmed Sufficient

| Package | Version | v1.3 Usage |
|---------|---------|-----------|
| `flutter_riverpod` | ^2.6.1 | New `SongFeedbackNotifier`, `FreshnessNotifier`, `TasteLearningProvider` |
| `go_router` | ^17.0.1 | New routes for feedback library screen |
| `shared_preferences` | ^2.5.4 | Three new keys: `song_feedback`, `song_freshness`, `freshness_enabled` |
| `http` | ^1.6.0 | Unchanged |
| `url_launcher` | ^6.3.2 | Unchanged |
| `supabase_flutter` | ^2.12.0 | Unchanged (init only) |
| `flutter_dotenv` | ^6.0.0 | Unchanged |

**Confidence:** HIGH (all versions verified, all patterns verified against codebase)

---

## New SharedPreferences Keys for v1.3

| Key | Type | Purpose |
|-----|------|---------|
| `song_feedback` | String (JSON map) | All song feedback entries, keyed by song lookup key |
| `song_freshness` | String (JSON map) | Last-played timestamps, keyed by song lookup key |
| `freshness_enabled` | bool | Whether "keep it fresh" mode is active |

**Total new storage footprint (extreme case):** ~920 KB (600 KB feedback + 320 KB freshness). Combined with existing data (~200 KB for profiles, plans, history, cache), total SharedPreferences usage is ~1.1 MB. This is well within practical limits on all platforms. Web localStorage limits are typically 5-10MB per origin.

---

## Integration Points with Existing Code

| Existing File | What Changes | How |
|--------------|-------------|-----|
| `lib/features/song_quality/domain/song_quality_scorer.dart` | Add feedback and freshness scoring dimensions | Two new static methods + parameters on `score()` |
| `lib/features/playlist/domain/playlist_generator.dart` | Pass feedback map and freshness map to scorer | Add parameters to `generate()` and `_scoreAndRank()` |
| `lib/features/playlist/presentation/widgets/song_tile.dart` | Add like/dislike icon buttons | Extend existing `SongTile` widget |
| `lib/features/playlist/presentation/playlist_screen.dart` | Add freshness toggle to generation UI | Add `SwitchListTile` or `SegmentedButton` |
| `lib/features/playlist/providers/playlist_providers.dart` | Read feedback + freshness maps during generation | Add provider reads in `generatePlaylist()` |
| `lib/app/router.dart` | Add `/feedback-library` route | Standard GoRouter route addition |

**New files to create:**

| File | Purpose |
|------|---------|
| `lib/features/feedback/domain/song_feedback.dart` | `SongFeedback` domain model |
| `lib/features/feedback/data/song_feedback_preferences.dart` | SharedPreferences persistence for feedback |
| `lib/features/feedback/providers/feedback_providers.dart` | `SongFeedbackNotifier` + derived providers |
| `lib/features/feedback/presentation/feedback_library_screen.dart` | Browse/edit all feedback entries |
| `lib/features/freshness/domain/freshness_tracker.dart` | Freshness computation logic |
| `lib/features/freshness/data/freshness_preferences.dart` | SharedPreferences persistence for freshness |
| `lib/features/freshness/providers/freshness_providers.dart` | `FreshnessNotifier` state management |
| `lib/features/taste_learning/domain/taste_learner.dart` | Pure Dart statistical analysis algorithm |
| `lib/features/taste_learning/domain/learned_taste_insights.dart` | Output model from taste learning |
| `lib/features/taste_learning/providers/taste_learning_providers.dart` | Provider that computes insights from feedback |

These follow the exact same `features/{name}/data|domain|presentation|providers` structure as every other feature module.

---

## Architecture Decision Record: Why Zero New Dependencies (Again)

v1.3 is a **data-driven intelligence milestone**, but the intelligence is simple enough to implement in pure Dart. The core insight is that single-user taste learning from explicit binary feedback is a frequency counting problem, not a machine learning problem.

The existing stack handles:
- **Persistence:** SharedPreferences stores up to ~1 MB of feedback + freshness data with no performance concerns
- **State management:** Riverpod `StateNotifier` provides reactive in-memory access with write-through persistence
- **Scoring:** `SongQualityScorer` is a pure-function scorer designed for extensibility with new dimensions
- **UI patterns:** `SongTile`, library screens, and toggle UIs have established patterns to follow

Adding ML libraries, databases, or UI packages for this milestone would create complexity disproportionate to the problem. The right approach is extending the existing architecture with new domain logic, not adding new infrastructure.

**Zero new dependencies for the third milestone in a row.** This is a sign of a well-chosen initial stack, not a resistance to change.

---

## Alternatives Considered

| Decision | Chosen | Alternative | Why Not Alternative |
|----------|--------|------------|-------------------|
| Feedback persistence | SharedPreferences (JSON map) | Drift/SQLite database | Data volume <1MB; code-gen broken; migration cost outweighs benefit |
| Taste learning | Pure Dart frequency analysis | tflite_flutter (ML) | Single-user, <4K entries; ML adds 15MB+ binary size for worse results |
| Feedback data structure | `Map<String, SongFeedback>` | `List<SongFeedback>` | Map provides O(1) lookup during scoring; list would be O(n) per song |
| Freshness storage | Separate SharedPreferences key | Embedded in feedback entries | Not all songs get feedback; freshness tracks ALL generated songs |
| Freshness UX | Binary toggle (fresh/taste) | Slider (0-100% freshness weight) | Binary is clearer for runners; two distinct modes are easier to understand |
| Feedback granularity | Binary (like/dislike) | 5-star rating | Binary feedback has higher completion rates; more actionable for scoring |

---

## Sources

### Primary (HIGH confidence)
- [SharedPreferences v2.5.4](https://pub.dev/packages/shared_preferences) - Verified version, API capabilities, and storage characteristics
- [Flutter official storage cookbook](https://docs.flutter.dev/cookbook/persistence/key-value) - SharedPreferences is recommended for "relatively small collection of key-values"
- Existing codebase analysis (all files read directly) - Pattern consistency verified across 6 existing SharedPreferences data stores

### Secondary (MEDIUM confidence)
- [SharedPreferences performance analysis](https://moldstud.com/articles/p-the-role-of-shared-preferences-in-flutter-app-performance-frequently-asked-questions-explained) - Performance characteristics for large data
- [Flutter database comparison 2025](https://dinkomarinac.dev/best-local-database-for-flutter-apps-a-complete-guide) - Drift, Hive, Isar alternatives assessment
- [Isar abandonment discussion](https://github.com/isar/isar/issues/1689) - Isar/Hive maintenance status
- [Spotify recommendation system guide](https://www.music-tomorrow.com/blog/how-spotify-recommendation-system-works-complete-guide) - Collaborative filtering requires user base; content-based filtering suitable for single-user
- [Hive vs Isar vs Drift comparison 2025](https://medium.com/@flutter-app/hive-vs-isar-vs-drift-best-offline-db-for-flutter-c6f73cf1241e) - Database alternatives analysis

### Tertiary (LOW confidence)
- [Music recommendation with implicit feedback](https://blog.reachsumit.com/posts/2022/09/explicit-implicit-cf/) - Academic patterns for feedback-based recommendation
- [Content-based music filtering review](https://arxiv.org/html/2507.02282v1) - Content-based filtering approaches
