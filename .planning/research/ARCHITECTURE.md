# Architecture Patterns: v1.1 Experience Quality

**Domain:** Running song quality scoring, curated data, taste profiling improvements
**Researched:** 2026-02-05
**Overall confidence:** HIGH (based on direct codebase analysis + Flutter official docs)

---

## Current Architecture Snapshot

Before defining changes, here is the exact current data flow and component map.

### Current Generation Pipeline

```
User inputs run plan
       |
       v
RunPlanNotifier (persisted RunPlan in SharedPreferences)
       |
       v
PlaylistGenerationNotifier.generatePlaylist()
  1. Reads RunPlan from runPlanNotifierProvider
  2. Reads TasteProfile from tasteProfileNotifierProvider
  3. Calls _fetchAllSongs(runPlan) -- batch BPM fetch with cache
  4. Calls PlaylistGenerator.generate(runPlan, songsByBpm, tasteProfile)
       |
       v
PlaylistGenerator.generate() [PURE DART, SYNCHRONOUS]
  For each RunSegment:
    1. _collectCandidates(targetBpm, songsByBpm) -- exact + half/double
    2. Filter out usedSongIds
    3. _scoreAndRank(candidates, tasteProfile)
         Score = artistMatch(+10) + exactBpm(+3) + tempoVariant(+1)
    4. Take top N songs for segment duration
    5. Build PlaylistSong objects
       |
       v
Playlist (songs: List<PlaylistSong>) -> auto-saved to history
```

### Current Scoring (PlaylistGenerator lines 180-219)

```dart
score = 0
if (artistMatch)  score += 10   // _artistMatchScore
if (exactBpm)     score += 3    // _exactMatchScore
if (tempoVariant) score += 1    // _tempoVariantScore
// Shuffled first, then stable-sorted by score descending
```

**The gap:** No "running quality" signal. A slow jazz ballad at 170 BPM scores identically to an energetic rock anthem at 170 BPM if neither artist matches the taste profile. Both get +3 for exact BPM match and that is the only differentiation.

### Current File Map (relevant to changes)

| File | Role | Lines |
|------|------|-------|
| `lib/features/playlist/domain/playlist_generator.dart` | Core scoring + assignment algorithm | 230 |
| `lib/features/playlist/providers/playlist_providers.dart` | Orchestration: fetch songs -> generate -> save | 194 |
| `lib/features/bpm_lookup/domain/bpm_song.dart` | Song data model from API | 112 |
| `lib/features/playlist/domain/playlist.dart` | Output playlist + PlaylistSong models | 140 |
| `lib/features/taste_profile/domain/taste_profile.dart` | TasteProfile model (genres, artists, energy) | 96 |
| `lib/features/taste_profile/providers/taste_profile_providers.dart` | TasteProfile state + persistence | 99 |
| `lib/features/stride/domain/stride_calculator.dart` | Cadence calculation from pace + height | 88 |
| `lib/features/stride/providers/stride_providers.dart` | Stride state + persistence | 115 |
| `lib/features/bpm_lookup/data/bpm_cache_preferences.dart` | Per-BPM cache in SharedPreferences | 71 |
| `lib/features/playlist/presentation/widgets/song_tile.dart` | Song display widget (title, artist, BPM, play links) | 106 |

---

## Recommended Architecture: Enhanced Generation Pipeline

### Design Principle

**Add a scoring layer, do not restructure.** The existing architecture is clean and well-bounded. The running quality enhancement is a new scoring dimension injected into `PlaylistGenerator._scoreAndRank`, not a new pipeline. The curated data is a new data source that feeds into scoring, not a replacement for the API.

### Enhanced Data Flow

```
User inputs run plan
       |
       v
RunPlanNotifier (persisted RunPlan in SharedPreferences)
       |
       v
PlaylistGenerationNotifier.generatePlaylist()
  1. Reads RunPlan from runPlanNotifierProvider
  2. Reads TasteProfile from tasteProfileNotifierProvider
  3. Reads RunningQualityIndex from runningQualityProvider   <-- NEW
  4. Calls _fetchAllSongs(runPlan) -- batch BPM fetch with cache
  5. Calls PlaylistGenerator.generate(
       runPlan, songsByBpm, tasteProfile,
       qualityIndex,                                         <-- NEW PARAM
     )
       |
       v
PlaylistGenerator.generate() [PURE DART, SYNCHRONOUS]
  For each RunSegment:
    1. _collectCandidates(targetBpm, songsByBpm) -- exact + half/double
    2. Filter out usedSongIds
    3. _scoreAndRank(candidates, tasteProfile, qualityIndex)  <-- ENHANCED
         Score = artistMatch(+10)
               + genreMatch(+6)                               <-- NEW
               + runningQuality(+8)                           <-- NEW
               + energyLevelMatch(+4)                         <-- NEW
               + exactBpm(+3)
               + tempoVariant(+1)
    4. Take top N songs for segment duration
    5. Build PlaylistSong objects with qualityBadge            <-- NEW FIELD
       |
       v
Playlist (songs: List<PlaylistSong>) -> auto-saved to history
```

---

## New Components Needed

### 1. Running Quality Index (Curated Song Database)

**Purpose:** A lookup structure that answers "Is this song known to be good for running?" and "How good?"

**Suggested file paths:**

```
lib/features/song_quality/
  domain/
    running_song.dart             # RunningSong model (songId, title, artist, quality, genre, energy)
    running_quality_index.dart    # RunningQualityIndex class (lookup by artist+title or songId)
    song_quality_scorer.dart      # SongQualityScorer: static scoring methods
  data/
    curated_songs_loader.dart     # Loads curated JSON from bundled assets
    curated_songs_cache.dart      # Optional: SharedPreferences cache for loaded index
  providers/
    song_quality_providers.dart   # Riverpod providers for RunningQualityIndex
```

**Data model:**

```dart
/// A song known to be good for running, from curated data.
class RunningSong {
  const RunningSong({
    required this.title,
    required this.artist,
    required this.genre,
    required this.energy,      // 1-10 scale
    required this.quality,     // 1-10 overall running quality
    this.bpm,                  // Known BPM if available
    this.tags,                 // e.g., ['power', 'steady', 'warmup', 'cooldown']
  });

  final String title;
  final String artist;
  final String genre;          // Aligns with RunningGenre enum
  final int energy;
  final int quality;
  final int? bpm;
  final List<String>? tags;
}
```

**Index structure:**

```dart
/// Fast lookup for running song quality data.
///
/// Supports two lookup strategies:
/// 1. Exact match by normalized "artist|title" key (primary)
/// 2. Artist-level match for genre/energy inference (fallback)
class RunningQualityIndex {
  RunningQualityIndex(List<RunningSong> songs) {
    for (final song in songs) {
      final key = _normalize('${song.artist}|${song.title}');
      _songIndex[key] = song;
      _artistSongs.putIfAbsent(_normalize(song.artist), () => []).add(song);
    }
  }

  final _songIndex = <String, RunningSong>{};
  final _artistSongs = <String, List<RunningSong>>{};

  /// Returns quality data if this exact song is in the curated set.
  RunningSong? lookupSong(String artist, String title) { ... }

  /// Returns all curated songs by this artist (for genre/energy inference).
  List<RunningSong> lookupArtist(String artist) { ... }

  static String _normalize(String s) => s.toLowerCase().trim();
}
```

**Storage strategy: Bundled JSON asset.** Rationale:

- Curated data is **static per app version** -- it ships with the app, not fetched at runtime
- JSON asset is loaded once via `rootBundle.loadString()`, parsed into index, kept in memory
- For ~500-2000 songs (reasonable curated set), JSON will be ~50-200KB -- well within asset limits
- No SharedPreferences needed -- this is read-only reference data, not user state
- Asset can be updated with each app release
- Falls within Flutter's efficient loading path (files >10KB use optimized loading)

**Asset location:**

```
assets/
  curated_running_songs.json    # The curated dataset
```

**pubspec.yaml addition:**

```yaml
flutter:
  assets:
    - .env
    - assets/curated_running_songs.json    # NEW
```

### 2. Song Quality Scorer (Enhanced Scoring Logic)

**Purpose:** Replaces the simple `_scoreAndRank` method with a multi-dimensional scorer.

**Suggested file path:**

```
lib/features/song_quality/domain/song_quality_scorer.dart
```

**Design:**

```dart
/// Scores a BpmSong for running quality using multiple signals.
///
/// This is a pure function -- no side effects, no async.
/// Used by PlaylistGenerator._scoreAndRank as a drop-in enhancement.
class SongQualityScorer {
  /// Score weights (public for testing/tuning)
  static const artistMatchWeight = 10;
  static const runningQualityWeight = 8;   // NEW: curated running quality
  static const genreMatchWeight = 6;        // NEW: genre from taste profile
  static const energyMatchWeight = 4;       // NEW: energy level alignment
  static const exactBpmWeight = 3;
  static const tempoVariantWeight = 1;

  /// Scores a single song candidate.
  static int score({
    required BpmSong song,
    required TasteProfile? tasteProfile,
    required RunningQualityIndex? qualityIndex,
  }) {
    var total = 0;

    // 1. Artist match (existing logic, preserved)
    total += _artistMatchScore(song, tasteProfile);

    // 2. Running quality from curated index (NEW)
    total += _runningQualityScore(song, qualityIndex);

    // 3. Genre match (NEW -- uses curated data + taste profile)
    total += _genreMatchScore(song, qualityIndex, tasteProfile);

    // 4. Energy level alignment (NEW)
    total += _energyAlignmentScore(song, qualityIndex, tasteProfile);

    // 5. BPM match type (existing logic, preserved)
    total += _bpmMatchScore(song);

    return total;
  }
}
```

**Why a separate class instead of extending PlaylistGenerator:**

- `PlaylistGenerator` stays focused on segment assignment and deduplication
- `SongQualityScorer` is independently testable with unit tests
- Scoring weights can be tuned without touching assignment logic
- Future scoring signals (user feedback, popularity, etc.) add here, not to generator

### 3. Enhanced TasteProfile

**Purpose:** Extend the existing `TasteProfile` model to carry running-specific preferences that feed into the enhanced scorer.

**Modification to existing file:** `lib/features/taste_profile/domain/taste_profile.dart`

**Changes needed:**

```dart
class TasteProfile {
  const TasteProfile({
    this.genres = const [],
    this.artists = const [],
    this.energyLevel = EnergyLevel.balanced,
    this.preferFamiliar = true,           // NEW: prefer known vs discovery
    this.avoidedGenres = const [],         // NEW: explicit exclusions
  });

  final List<RunningGenre> genres;
  final List<String> artists;
  final EnergyLevel energyLevel;
  final bool preferFamiliar;               // NEW
  final List<RunningGenre> avoidedGenres;  // NEW
  // ...existing copyWith, toJson, fromJson -- extend with new fields
}
```

**Migration concern:** Existing persisted TasteProfile JSON lacks the new fields. The `fromJson` factory already uses defaults for missing keys since all fields have default values in the constructor. New fields should follow the same pattern with sensible defaults. No migration code needed -- `fromJson` will use default values for missing fields.

### 4. Stride Adjustment Layer

**Purpose:** Allow post-run "nudge" adjustments to cadence without full recalibration.

**Modification to existing file:** `lib/features/stride/providers/stride_providers.dart`

**New method on `StrideNotifier`:**

```dart
/// Adjusts cadence by a delta (e.g., +2 or -3 SPM).
/// Sets as calibrated cadence based on current effective cadence + delta.
void adjustCadence(double deltaSpm) {
  final current = state.cadence;
  final adjusted = (current + deltaSpm).clamp(150.0, 200.0);
  state = state.copyWith(calibratedCadence: () => adjusted);
  _persist();
}
```

**No new files needed.** The existing `StrideState.cadence` getter already resolves calibrated vs formula-based cadence. Adjustment just sets a new calibrated value. The UI change is a new widget (e.g., "+/- buttons" on the playlist result screen or stride screen), not a new domain component.

### 5. Quick Regeneration State

**Purpose:** Enable one-tap regenerate with cached song pool and last-used parameters.

**Modification to existing file:** `lib/features/playlist/providers/playlist_providers.dart`

**Changes to `PlaylistGenerationNotifier`:**

```dart
class PlaylistGenerationNotifier
    extends StateNotifier<PlaylistGenerationState> {
  // ...existing fields...

  /// Cached song pool from last generation (NEW)
  Map<int, List<BpmSong>>? _lastSongPool;

  /// Cached RunPlan from last generation (NEW)
  RunPlan? _lastRunPlan;

  Future<void> generatePlaylist() async {
    // ...existing logic...
    final songsByBpm = await _fetchAllSongs(runPlan);
    _lastSongPool = songsByBpm;   // NEW: cache for regeneration
    _lastRunPlan = runPlan;        // NEW: cache for regeneration
    // ...rest of existing logic...
  }

  /// Regenerates with cached data -- near-instant, no API calls.
  /// Falls back to full generation if cache is stale or missing.
  Future<void> regenerate() async {
    final runPlan = ref.read(runPlanNotifierProvider);
    if (runPlan == null || _lastSongPool == null ||
        _lastRunPlan != runPlan) {
      // Cache invalid -- fall back to full generation
      return generatePlaylist();
    }

    state = const PlaylistGenerationState.loading();
    final tasteProfile = ref.read(tasteProfileNotifierProvider);

    // Reuse cached songs, just re-run generator (different random seed)
    final playlist = PlaylistGenerator.generate(
      runPlan: runPlan,
      tasteProfile: tasteProfile,
      songsByBpm: _lastSongPool!,
    );

    state = PlaylistGenerationState.loaded(playlist);
    unawaited(
      ref.read(playlistHistoryProvider.notifier).addPlaylist(playlist),
    );
  }
}
```

**No new files needed.** The cached song pool lives in the notifier's instance state (in-memory only, not persisted). If the app restarts, the first generation does a full fetch. Subsequent regenerates are instant.

**Why not persist the song pool?** The BPM cache (`BpmCachePreferences`) already persists songs per-BPM with 7-day TTL. On app restart, `_fetchAllSongs` will hit the warm cache and return quickly. The bottleneck is only the first cold fetch. Duplicating the entire song pool in SharedPreferences would waste storage and create cache invalidation complexity.

---

## Modified Components (Existing Files)

### PlaylistGenerator (lib/features/playlist/domain/playlist_generator.dart)

**What changes:**

1. `generate()` signature adds optional `RunningQualityIndex? qualityIndex` parameter
2. `_scoreAndRank()` delegates to `SongQualityScorer.score()` instead of inline scoring
3. `_ScoredSong` class unchanged (still wraps BpmSong + int score)

**Lines affected:** 60-65 (signature), 180-219 (scoring method body)

**Backward compatible:** `qualityIndex` is optional/nullable. Without it, scoring falls back to existing behavior (artist + BPM match only). Existing tests pass without modification.

### PlaylistGenerationNotifier (lib/features/playlist/providers/playlist_providers.dart)

**What changes:**

1. `generatePlaylist()` reads `RunningQualityIndex` from new provider
2. Passes `qualityIndex` to `PlaylistGenerator.generate()`
3. Caches `_lastSongPool` and `_lastRunPlan` for quick regeneration
4. New `regenerate()` method

**Lines affected:** 77-127 (generatePlaylist method), new method ~30 lines

### TasteProfile (lib/features/taste_profile/domain/taste_profile.dart)

**What changes:**

1. Add `preferFamiliar` field (bool, default true)
2. Add `avoidedGenres` field (List<RunningGenre>, default empty)
3. Extend `copyWith`, `toJson`, `fromJson` for new fields

**Lines affected:** 50-95 (class body)

**Migration:** No breaking change. `fromJson` handles missing keys via constructor defaults.

### PlaylistSong (lib/features/playlist/domain/playlist.dart)

**What changes:**

1. Add optional `runningQuality` field (int?, 1-10) for UI display
2. Add optional `isVerifiedRunning` field (bool) for badge display

**Lines affected:** 11-59 (PlaylistSong class)

### SongTile (lib/features/playlist/presentation/widgets/song_tile.dart)

**What changes:**

1. Display running quality badge/indicator when `song.runningQuality != null`
2. Visual distinction for curated vs API-discovered songs

**Lines affected:** 17-37 (build method)

### StrideNotifier (lib/features/stride/providers/stride_providers.dart)

**What changes:**

1. Add `adjustCadence(double deltaSpm)` method

**Lines affected:** New method ~6 lines, after line 85

---

## Component Boundaries Diagram

```
+---------------------------------------------------------------------+
|                        PRESENTATION LAYER                           |
|                                                                     |
|  PlaylistScreen    StrideScreen    TasteProfileScreen    HomeScreen  |
|       |                |                 |                          |
+-------+----------------+-----------------+--------------------------+
        |                |                 |
+-------+----------------+-----------------+--------------------------+
|                        PROVIDER LAYER                               |
|                                                                     |
|  playlistGenerationProvider    strideNotifierProvider                |
|  playlistHistoryProvider       tasteProfileNotifierProvider          |
|  runPlanNotifierProvider       runningQualityProvider  <-- NEW      |
|  getSongBpmClientProvider                                           |
|                                                                     |
+-------+----------------+-----------------+--------------------------+
        |                |                 |
+-------+----------------+-----------------+--------------------------+
|                        DOMAIN LAYER                                 |
|                                                                     |
|  PlaylistGenerator -----> SongQualityScorer  <-- NEW               |
|  BpmMatcher                RunningQualityIndex  <-- NEW            |
|  StrideCalculator          RunningSong  <-- NEW                    |
|  RunPlan / RunSegment                                              |
|  TasteProfile (extended)                                           |
|  BpmSong (unchanged)                                               |
|  Playlist / PlaylistSong (extended)                                |
|                                                                     |
+-------+----------------+-----------------+--------------------------+
        |                |                 |
+-------+----------------+-----------------+--------------------------+
|                        DATA LAYER                                   |
|                                                                     |
|  GetSongBpmClient (unchanged)    CuratedSongsLoader  <-- NEW      |
|  BpmCachePreferences (unchanged) (reads bundled JSON asset)        |
|  TasteProfilePreferences         StridePreferences                 |
|  RunPlanPreferences              PlaylistHistoryPreferences        |
|                                                                     |
+---------------------------------------------------------------------+
        |                                  |
        v                                  v
  GetSongBPM API               assets/curated_running_songs.json
  (external, rate-limited)     (bundled, read-only, ships with app)
```

---

## Data Flow for Running Quality Score

### How a curated song enters the pipeline

```
1. App startup (or first playlist generation):
   CuratedSongsLoader.load()
     -> rootBundle.loadString('assets/curated_running_songs.json')
     -> jsonDecode -> List<RunningSong>
     -> RunningQualityIndex(songs)
     -> Cached in runningQualityProvider (kept in memory for session)

2. During PlaylistGenerator.generate():
   For each BpmSong candidate:
     SongQualityScorer.score(song, tasteProfile, qualityIndex)
       -> qualityIndex.lookupSong(song.artistName, song.title)
          MATCH: +8 points (runningQualityWeight) scaled by quality rating
          NO MATCH: qualityIndex.lookupArtist(song.artistName)
            ARTIST FOUND: +3 points (artist has other curated songs,
                          infer genre/energy from their catalog)
            NOT FOUND: +0 (song is unknown, no penalty)

3. Result: curated running songs float to top of rankings,
   but unknown songs are never excluded -- they just rank lower.
```

### Key design decision: Curated data is a boost, not a filter

The curated index does NOT filter out songs. It only BOOSTS known-good running songs in the ranking. This is critical because:

- The curated set will always be incomplete (hundreds of songs vs millions in the API)
- Users may have niche taste not represented in curated data
- The GetSongBPM API returns songs we have no quality data for -- they should still appear
- A curated boost combined with taste profile matching is more robust than either alone

---

## Curated Data Format

### JSON Structure

```json
{
  "version": 1,
  "generated": "2026-02-05",
  "songs": [
    {
      "title": "Lose Yourself",
      "artist": "Eminem",
      "genre": "hipHop",
      "energy": 9,
      "quality": 9,
      "bpm": 171,
      "tags": ["power", "motivation", "classic"]
    },
    {
      "title": "Eye of the Tiger",
      "artist": "Survivor",
      "genre": "rock",
      "energy": 8,
      "quality": 10,
      "bpm": 109,
      "tags": ["power", "classic", "warmup"]
    }
  ]
}
```

### Genre values

Must align with `RunningGenre` enum names: `pop`, `hipHop`, `electronic`, `edm`, `rock`, `indie`, `dance`, `house`, `drumAndBass`, `rnb`, `latin`, `metal`, `punk`, `funk`, `kPop`.

### Data sourcing strategy

Curate from published "best running songs" lists (Runner's World, Marathon Handbook, Timeout, etc.) combined with jog.fm popularity data. Each song gets:

- **quality** (1-10): How frequently it appears across running song lists + community ratings
- **energy** (1-10): Subjective energy rating based on musical complexity, tempo drive, vocal intensity
- **genre**: Mapped to RunningGenre enum
- **tags**: Freeform tags for future segment-aware matching (e.g., "warmup" songs for warmup segments)

Target: 500-1000 songs across all 15 genres for v1.1. This is a manual curation task, not automated scraping.

---

## Integration Points (Specific Files and Line Ranges)

### 1. PlaylistGenerator.generate() -- signature change

**File:** `lib/features/playlist/domain/playlist_generator.dart`, lines 60-65

**Current:**
```dart
static Playlist generate({
  required RunPlan runPlan,
  required Map<int, List<BpmSong>> songsByBpm,
  TasteProfile? tasteProfile,
  Random? random,
})
```

**After:**
```dart
static Playlist generate({
  required RunPlan runPlan,
  required Map<int, List<BpmSong>> songsByBpm,
  TasteProfile? tasteProfile,
  RunningQualityIndex? qualityIndex,  // NEW
  Random? random,
})
```

### 2. PlaylistGenerator._scoreAndRank() -- delegate to SongQualityScorer

**File:** `lib/features/playlist/domain/playlist_generator.dart`, lines 180-219

**Current:** Inline scoring with `_artistMatchScore`, `_exactMatchScore`, `_tempoVariantScore`

**After:** Delegates to `SongQualityScorer.score()` for each candidate. The shuffle-then-sort pattern is preserved.

### 3. PlaylistGenerationNotifier.generatePlaylist() -- read quality index

**File:** `lib/features/playlist/providers/playlist_providers.dart`, lines 77-98

**Current:**
```dart
final playlist = PlaylistGenerator.generate(
  runPlan: runPlan,
  tasteProfile: tasteProfile,
  songsByBpm: songsByBpm,
);
```

**After:**
```dart
final qualityIndex = ref.read(runningQualityProvider);  // NEW
final playlist = PlaylistGenerator.generate(
  runPlan: runPlan,
  tasteProfile: tasteProfile,
  songsByBpm: songsByBpm,
  qualityIndex: qualityIndex,  // NEW
);
```

### 4. PlaylistSong -- add quality fields

**File:** `lib/features/playlist/domain/playlist.dart`, lines 11-59

**Add fields:**
```dart
final int? runningQuality;     // 1-10 from curated index, null if unknown
final bool isVerifiedRunning;  // true if song was in curated index
```

### 5. SongTile -- display quality indicator

**File:** `lib/features/playlist/presentation/widgets/song_tile.dart`, lines 17-37

**Add:** A small badge or icon indicating running quality (e.g., a running shoe icon for verified songs, or a quality star rating).

### 6. TasteProfile -- extend model

**File:** `lib/features/taste_profile/domain/taste_profile.dart`, lines 50-95

**Add fields:** `preferFamiliar`, `avoidedGenres` with defaults. Extend `copyWith`, `toJson`, `fromJson`.

### 7. StrideNotifier -- add adjustCadence

**File:** `lib/features/stride/providers/stride_providers.dart`, after line 85

**Add:** `adjustCadence(double deltaSpm)` method.

---

## Suggested Build Order

Dependencies flow top-to-bottom. Each step builds on the previous.

```
Step 1: Running Quality Domain Models
  NEW: RunningSong model
  NEW: RunningQualityIndex class
  NEW: SongQualityScorer (with comprehensive unit tests)
  No UI, no Flutter dependencies, pure Dart only
  Tests: score calculations with mock data
  |
Step 2: Curated Data Asset Pipeline
  NEW: curated_running_songs.json asset (initial set, ~100-200 songs)
  NEW: CuratedSongsLoader (rootBundle.loadString + parse)
  NEW: runningQualityProvider (Riverpod provider, loads on first read)
  UPDATE: pubspec.yaml (add asset declaration)
  Tests: loader parses valid/invalid JSON, index lookups work
  |
Step 3: Enhanced Scoring Integration
  MODIFY: PlaylistGenerator.generate() signature
  MODIFY: PlaylistGenerator._scoreAndRank() -> delegates to SongQualityScorer
  MODIFY: PlaylistGenerationNotifier -> reads and passes qualityIndex
  Tests: end-to-end generation with quality index produces better rankings
  |
Step 4: Taste Profile Enhancement
  MODIFY: TasteProfile model (new fields)
  MODIFY: TasteProfilePreferences (extended serialization)
  MODIFY: TasteProfileScreen (new UI for avoidedGenres, preferFamiliar)
  Tests: serialization roundtrip, backward compat with old JSON
  |
Step 5: Quality Indicators in UI
  MODIFY: PlaylistSong model (add runningQuality, isVerifiedRunning)
  MODIFY: SongTile widget (display quality badge)
  MODIFY: PlaylistGenerator -> populate quality fields on PlaylistSong
  Tests: widget tests for badge display
  |
Step 6: Stride Adjustment
  MODIFY: StrideNotifier (add adjustCadence method)
  NEW: Stride adjustment UI (buttons or slider on stride/playlist screen)
  Tests: adjustment clamps to valid range, persists correctly
  |
Step 7: Quick Regeneration
  MODIFY: PlaylistGenerationNotifier (cache song pool, add regenerate())
  MODIFY: PlaylistScreen (change Regenerate button to use regenerate())
  Tests: regenerate uses cached pool, falls back on cache miss
  |
Step 8: Expand Curated Dataset
  UPDATE: curated_running_songs.json (expand to 500+ songs)
  UPDATE: Scoring weights based on real-world testing
  No code changes, just data
```

**Build order rationale:**

- Steps 1-3 form the core enhancement: domain models -> data loading -> scoring integration. These are the foundation everything else depends on.
- Step 4 (taste profile) is independent of quality scoring and can be parallelized with Step 3 if desired.
- Step 5 depends on Step 3 (quality data must exist before UI can display it).
- Steps 6-7 (stride adjustment, quick regen) are independent of each other and of the quality scoring pipeline. They could be built in any order after Step 3.
- Step 8 is data-only and can happen continuously.

---

## Scoring Weight Rationale

| Signal | Weight | Rationale |
|--------|--------|-----------|
| Artist match (taste profile) | +10 | Strongest signal -- user explicitly chose this artist |
| Running quality (curated) | +8 | Proven running song is very valuable, but user taste should still win |
| Genre match (taste profile) | +6 | Genre alignment matters for enjoyment; uses curated data to infer API song genre |
| Energy alignment | +4 | Matching chill/balanced/intense preference improves experience |
| Exact BPM match | +3 | Exact BPM is better than half/double-time for cadence sync |
| Tempo variant match | +1 | Half/double-time still works, just less ideal |

**Max possible score:** 10 + 8 + 6 + 4 + 3 = 31 (artist match + curated running song + genre match + energy match + exact BPM)

**Scoring is a ranking signal, not a threshold.** All BPM-matched songs remain candidates. Scores only determine ordering within each segment's candidate pool.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Fetching Quality Data at Runtime from External API

**What:** Building an API service to fetch running quality ratings on-demand
**Why bad:** Adds latency, requires backend, introduces failure mode during generation
**Instead:** Bundle curated data as a static asset. Update with app releases. No network dependency.

### Anti-Pattern 2: Filtering Out Non-Curated Songs

**What:** Only allowing songs that appear in the curated index
**Why bad:** Curated set is always incomplete. Users in niche genres get empty playlists.
**Instead:** Curated data is a scoring boost, not a filter. Unknown songs still appear, just ranked lower.

### Anti-Pattern 3: Storing Curated Data in SharedPreferences

**What:** Loading curated JSON on first run and saving to SharedPreferences
**Why bad:** SharedPreferences is not designed for large datasets. The data is read-only and ships with the app -- no reason to copy it to user storage.
**Instead:** Load from bundled asset on each app session. Parse once, keep in memory via Riverpod provider.

### Anti-Pattern 4: Complex Genre Inference from Song Titles

**What:** Trying to infer a song's genre from its title or artist name using heuristics
**Why bad:** Unreliable, creates false matches, hard to test
**Instead:** Genre data comes from the curated index (high confidence) or is unknown (no penalty). Do not guess.

### Anti-Pattern 5: Modifying BpmSong Model for Quality Data

**What:** Adding `runningQuality` fields directly to `BpmSong`
**Why bad:** `BpmSong` represents API response data. Mixing external quality ratings into it breaks the clean separation between data sources. Also complicates cache serialization.
**Instead:** Quality data lives in `RunningQualityIndex` (separate domain). Scoring happens at generation time by cross-referencing. Quality fields appear only on `PlaylistSong` (the output model).

---

## Scalability Considerations

| Concern | Current (v1.1) | Future (v2.0+) |
|---------|----------------|-----------------|
| Curated dataset size | 500-1000 songs, ~100KB JSON | 5000+ songs, consider SQLite or binary format |
| Quality data freshness | Ships with app release | Could add server-side quality API for dynamic updates |
| Genre inference for API songs | Only via curated artist lookup | Could integrate genre API (MusicBrainz, Last.fm) |
| User feedback | None | "Thumbs up/down" per song to personalize scoring weights |
| Asset loading performance | `rootBundle.loadString()` is fine for 100KB | For 1MB+, use `compute()` for isolate-based parsing |

---

## Testing Strategy

### Unit Tests (Pure Dart)

| Component | Test Focus |
|-----------|------------|
| `SongQualityScorer` | Score calculation for all signal combinations, edge cases |
| `RunningQualityIndex` | Lookup hit/miss, normalization, artist-level fallback |
| `RunningSong` | JSON serialization roundtrip |
| `PlaylistGenerator` (updated) | Quality index integration, backward compat without index |
| `TasteProfile` (updated) | New field serialization, backward compat with old JSON |

### Integration Tests

| Component | Test Focus |
|-----------|------------|
| `CuratedSongsLoader` | Asset loading, error handling for malformed JSON |
| `PlaylistGenerationNotifier` | Full pipeline with quality index, regenerate flow |
| `StrideNotifier` | adjustCadence persists and clamps correctly |

### Widget Tests

| Component | Test Focus |
|-----------|------------|
| `SongTile` | Quality badge renders when present, hidden when absent |
| `PlaylistScreen` | Regenerate button triggers correct method |

---

## Sources

- Direct codebase analysis of all files in `lib/features/` -- **HIGH confidence**
- [Flutter asset documentation](https://docs.flutter.dev/ui/assets/assets-and-images) -- **HIGH confidence** (official docs)
- [The Science Behind Good Running Music](https://foreverfitscience.com/running/good-running-music/) -- **MEDIUM confidence** (peer-reviewed research referenced)
- [SharedPreferences limitations for large data](https://docs.flutter.dev/cookbook/persistence/key-value) -- **HIGH confidence** (official Flutter cookbook)
- [AssetBundle.loadString() performance for files >10KB](https://api.flutter.dev/flutter/services/AssetBundle-class.html) -- **HIGH confidence** (official API docs)
- [jog.fm running song database model](https://jog.fm/) -- **MEDIUM confidence** (verified via App Store listing)
