# Phase 28: "Songs I Run To" Data Layer - Research

**Researched:** 2026-02-08
**Domain:** Flutter StateNotifier + SharedPreferences CRUD for user-curated song list
**Confidence:** HIGH

## Summary

Phase 28 implements a standalone data layer for a "Songs I Run To" user-curated song collection. This is pure domain/data/provider work following patterns already established across six features in this codebase (SongFeedback, TasteProfile, PlayHistory, FreshnessMode, Stride, RunPlan). No new dependencies are required. No external APIs are involved.

The implementation consists of three files plus one screen: a `RunningSong` domain model, a `RunningSongPreferences` static persistence class, a `RunningSongNotifier` StateNotifier with Completer-based async init, and a list screen with add/remove/empty state. The model is intentionally **separate** from `SongFeedback` (different user intent: proactive curation vs. reactive feedback). Song identity uses `SongKey.normalize(artist, title)` for cross-source matching, consistent with all existing song-related features.

The success criteria require: (1) add a song and persist across restarts, (2) view all songs, (3) remove a song with immediate disappearance, (4) empty state guidance. All four map cleanly to the established StateNotifier CRUD + SharedPreferences + list screen pattern. The Phase 29 scoring integration (merging running song keys into the liked set) is explicitly out of scope for this phase but shapes the model design: the `songKey` field must use `SongKey.normalize` format to enable O(1) set membership checks during scoring.

**Primary recommendation:** Follow the `SongFeedbackNotifier` pattern exactly (StateNotifier<Map<String, RunningSong>>, Completer async init, static Preferences class), adding only the fields specified in the milestone research (artist, title, bpm?, genre?, source enum, addedDate).

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter_riverpod` | ^2.6.1 | State management | Already used throughout app; manual providers (code-gen broken with Dart 3.10) |
| `shared_preferences` | ^2.5.4 | Local persistence | Used by SongFeedback, TasteProfile, PlayHistory, FreshnessMode, Stride, RunPlan |
| `dart:convert` | (SDK) | JSON serialization | Used by all Preferences classes for jsonEncode/jsonDecode |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `go_router` | ^17.0.1 | Navigation | Route registration for the running songs list screen |
| `flutter/material.dart` | (SDK) | UI widgets | List screen, empty state, song cards |

### Alternatives Considered
None. This phase uses exclusively existing dependencies and established patterns. No new packages needed.

**Installation:**
No new packages required. All dependencies already in `pubspec.yaml`.

## Architecture Patterns

### Recommended Project Structure
```
lib/features/running_songs/
├── domain/
│   └── running_song.dart       # RunningSong model + RunningSongSource enum
├── data/
│   └── running_song_preferences.dart  # SharedPreferences persistence
├── providers/
│   └── running_song_providers.dart    # RunningSongNotifier + provider
└── presentation/
    └── running_songs_screen.dart      # List view + empty state
```

### Pattern 1: StateNotifier + Completer Async Init
**What:** StateNotifier that loads persisted state on construction via a fire-and-forget `_load()` call, with a `Completer<void>` allowing callers to `await ensureLoaded()` before reading state.
**When to use:** Every feature that persists state to SharedPreferences.
**Example (from SongFeedbackNotifier):**
```dart
class SongFeedbackNotifier extends StateNotifier<Map<String, SongFeedback>> {
  SongFeedbackNotifier() : super({}) {
    _load();
  }

  final Completer<void> _loadCompleter = Completer<void>();

  Future<void> ensureLoaded() => _loadCompleter.future;

  Future<void> _load() async {
    try {
      final feedback = await SongFeedbackPreferences.load();
      if (mounted) {
        state = feedback;
      }
    } finally {
      if (!_loadCompleter.isCompleted) _loadCompleter.complete();
    }
  }

  Future<void> addFeedback(SongFeedback feedback) async {
    state = {...state, feedback.songKey: feedback};
    await SongFeedbackPreferences.save(state);
  }

  Future<void> removeFeedback(String songKey) async {
    state = Map.from(state)..remove(songKey);
    await SongFeedbackPreferences.save(state);
  }
}
```
**Source:** `lib/features/song_feedback/providers/song_feedback_providers.dart`

### Pattern 2: Static Preferences Class
**What:** A class with only static methods (`load`, `save`, `clear`) wrapping SharedPreferences with a single storage key. Corrupt entries are silently skipped.
**When to use:** Every persisted feature's data layer.
**Example (from SongFeedbackPreferences):**
```dart
class SongFeedbackPreferences {
  static const _key = 'song_feedback';

  static Future<Map<String, SongFeedback>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return {};
    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    final result = <String, SongFeedback>{};
    for (final entry in decoded.entries) {
      try {
        result[entry.key] = SongFeedback.fromJson(
          entry.value as Map<String, dynamic>,
        );
      } catch (_) {
        // Skip corrupt entries
      }
    }
    return result;
  }

  static Future<void> save(Map<String, SongFeedback> feedback) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      feedback.map((k, v) => MapEntry(k, v.toJson())),
    );
    await prefs.setString(_key, encoded);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
```
**Source:** `lib/features/song_feedback/data/song_feedback_preferences.dart`

### Pattern 3: Immutable Domain Model with JSON Round-Trip
**What:** Immutable class with named constructor parameters, `factory fromJson`, `toJson`, and optional `copyWith`. Pure Dart, no Flutter dependencies. Optional fields excluded from JSON when null.
**When to use:** Every domain model.
**Example:** `SongFeedback`, `CuratedSong`, `BpmSong`, `TasteProfile`, `PlaylistSong`

### Pattern 4: StateNotifierProvider Registration
**What:** Global `final` provider using `StateNotifierProvider` with the notifier and state types.
**When to use:** Every StateNotifier-based feature.
**Example:**
```dart
final songFeedbackProvider =
    StateNotifierProvider<SongFeedbackNotifier, Map<String, SongFeedback>>(
  (ref) => SongFeedbackNotifier(),
);
```
**Source:** `lib/features/song_feedback/providers/song_feedback_providers.dart`

### Pattern 5: Empty State Screen
**What:** When a collection is empty, show an icon, title, and guidance text in a centered column. The `SongFeedbackLibraryScreen` uses `_EmptyFeedbackView` with `Icons.thumbs_up_down`, "No Feedback Yet" heading, and explanatory text.
**When to use:** Every library/collection screen.
**Source:** `lib/features/song_feedback/presentation/song_feedback_library_screen.dart`

### Pattern 6: Route Registration
**What:** Add a `GoRoute` to `lib/app/router.dart` with path and builder. Add a navigation button to the home screen if appropriate.
**Example:**
```dart
GoRoute(
  path: '/song-feedback',
  builder: (context, state) => const SongFeedbackLibraryScreen(),
),
```
**Source:** `lib/app/router.dart`

### Anti-Patterns to Avoid
- **Extending SongFeedback:** The `RunningSong` model must NOT extend or reuse `SongFeedback`. Different user intent (proactive "I want to run to this" vs. reactive "I liked/disliked this"). This is a locked prior decision.
- **Using provider state for persistence:** Always persist through the static Preferences class, never rely on provider state surviving across app restarts.
- **Missing `mounted` check in `_load`:** Always check `if (mounted)` before setting state in the async load callback. The notifier may be disposed before load completes.
- **Using `catch(e)` instead of `catch(_)`:** Supabase-related code and SharedPreferences can throw `AssertionError` (an `Error`, not `Exception`). Always use `catch(_)` for broad catch blocks. This is a documented known issue.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Song key normalization | Custom artist+title normalization | `SongKey.normalize(artist, title)` | Single source of truth, already used by SongFeedback, CuratedSong, BpmSong, PlaylistSong |
| Async init with race protection | Custom async initialization | Completer + `ensureLoaded()` pattern | Established pattern across 5+ notifiers, prevents cold-start read-before-load bugs |
| JSON persistence | Custom file I/O | SharedPreferences + static helper class | Consistent with all other features, handles platform differences automatically |
| Navigation | Custom navigation logic | GoRouter route registration | Existing router handles all navigation; just add a GoRoute entry |

**Key insight:** This phase is pure pattern replication. Every component has a direct analog in the existing codebase. The risk is not technical complexity but deviation from established patterns.

## Common Pitfalls

### Pitfall 1: SharedPreferences Key Collision
**What goes wrong:** Using a key that conflicts with an existing feature's storage key.
**Why it happens:** Multiple features share the same SharedPreferences instance.
**How to avoid:** Use a unique, descriptive key. Existing keys: `song_feedback`, `taste_profile_library`, `taste_profile_selected_id`, `play_history`, `freshness_mode`, `stride_state`, `run_plan`, `onboarding_completed`, `taste_suggestions`. Use `running_songs` as the key.
**Warning signs:** Data from one feature mysteriously appears in or corrupts another.

### Pitfall 2: SongKey Format Mismatch
**What goes wrong:** Running songs stored with a different key format than what the scorer/generator expects.
**Why it happens:** Using `artist|title` without normalization (lowercase + trim).
**How to avoid:** Always use `SongKey.normalize(artist, title)` for the `songKey` field. Never inline key construction.
**Warning signs:** Songs added to "Songs I Run To" don't get the `isLiked` boost during scoring (Phase 29 integration).

### Pitfall 3: Missing `mounted` Check After Async Load
**What goes wrong:** Setting state on a disposed notifier causes an assertion error.
**Why it happens:** The notifier can be disposed between the start of `_load()` and its completion (e.g., during hot reload or rapid navigation).
**How to avoid:** Always wrap `state = ...` in the `_load()` method with `if (mounted)`.
**Warning signs:** Assertion errors during hot reload or rapid screen transitions.

### Pitfall 4: Optimistic State Update Without Persistence Failure Handling
**What goes wrong:** State updates but persistence fails (e.g., storage full). User sees the change but it reverts on restart.
**Why it happens:** The established pattern does optimistic updates (`state = ...` before `await save()`), which is fine for UX responsiveness but doesn't handle save failures.
**How to avoid:** This is an accepted tradeoff in the existing codebase. All five existing notifiers use the same optimistic pattern. Do not deviate -- consistency is more important than handling an edge case no other feature handles.
**Warning signs:** None needed; this is acceptable behavior.

### Pitfall 5: Empty String Artist or Title
**What goes wrong:** `SongKey.normalize('', 'song')` produces `'|song'`, which could collide with other empty-artist songs.
**Why it happens:** Source data (API, manual input) may have missing fields.
**How to avoid:** Validate that artist and title are non-empty before creating a `RunningSong`. Reject or skip entries with empty artist/title.
**Warning signs:** Multiple songs resolving to the same key, overwriting each other.

## Code Examples

Verified patterns from the existing codebase:

### RunningSong Model (recommended shape)
```dart
/// Source for a running song (how the user discovered/added it).
enum RunningSongSource {
  curated,   // From curated song catalog
  spotify,   // From Spotify search (future Phase 31+)
  manual,    // Manually entered (future)
}

class RunningSong {
  const RunningSong({
    required this.songKey,
    required this.artist,
    required this.title,
    required this.addedDate,
    this.bpm,
    this.genre,
    this.source = RunningSongSource.curated,
  });

  factory RunningSong.fromJson(Map<String, dynamic> json) {
    return RunningSong(
      songKey: json['songKey'] as String,
      artist: json['artist'] as String,
      title: json['title'] as String,
      addedDate: DateTime.parse(json['addedDate'] as String),
      bpm: (json['bpm'] as num?)?.toInt(),
      genre: json['genre'] as String?,
      source: RunningSongSource.values.firstWhere(
        (s) => s.name == json['source'],
        orElse: () => RunningSongSource.curated,
      ),
    );
  }

  final String songKey;   // SongKey.normalize(artist, title)
  final String artist;
  final String title;
  final DateTime addedDate;
  final int? bpm;
  final String? genre;
  final RunningSongSource source;

  Map<String, dynamic> toJson() => {
    'songKey': songKey,
    'artist': artist,
    'title': title,
    'addedDate': addedDate.toIso8601String(),
    if (bpm != null) 'bpm': bpm,
    if (genre != null) 'genre': genre,
    'source': source.name,
  };
}
```

### RunningSongNotifier (follow SongFeedbackNotifier exactly)
```dart
class RunningSongNotifier extends StateNotifier<Map<String, RunningSong>> {
  RunningSongNotifier() : super({}) {
    _load();
  }

  final Completer<void> _loadCompleter = Completer<void>();

  Future<void> ensureLoaded() => _loadCompleter.future;

  Future<void> _load() async {
    try {
      final songs = await RunningSongPreferences.load();
      if (mounted) state = songs;
    } finally {
      if (!_loadCompleter.isCompleted) _loadCompleter.complete();
    }
  }

  Future<void> addSong(RunningSong song) async {
    state = {...state, song.songKey: song};
    await RunningSongPreferences.save(state);
  }

  Future<void> removeSong(String songKey) async {
    state = Map.from(state)..remove(songKey);
    await RunningSongPreferences.save(state);
  }

  bool containsSong(String songKey) => state.containsKey(songKey);
}
```

### Test Pattern (follow song_feedback_lifecycle_test.dart)
```dart
setUp(() {
  SharedPreferences.setMockInitialValues({});
  container = ProviderContainer();
});

tearDown(() {
  container.dispose();
});

test('feedback survives dispose and reload', () async {
  final notifier = container.read(runningSongProvider.notifier);
  await notifier.ensureLoaded();

  await notifier.addSong(/* ... */);
  expect(container.read(runningSongProvider), hasLength(1));

  container.dispose();
  container = ProviderContainer();

  final notifier2 = container.read(runningSongProvider.notifier);
  await notifier2.ensureLoaded();
  expect(container.read(runningSongProvider), hasLength(1));
});
```

### Empty State Widget (follow _EmptyFeedbackView pattern)
```dart
class _EmptyRunningSongsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No Running Songs Yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Search for songs and add them to your '
              '"Songs I Run To" list to build your personal collection.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Code-generated Riverpod providers | Manual Riverpod providers | Dart 3.10 broke code-gen | All new providers must be manual `StateNotifierProvider` |
| `surfaceVariant` for backgrounds | `surfaceContainerHighest` / `surfaceContainerLow` | Material 3 migration | Card colors use `surfaceContainerLow` (see SongTile) |
| Single taste profile | Multi-profile library | Phase 20 | TasteProfilePreferences has migration from legacy key |

**Deprecated/outdated:**
- `riverpod_generator` code-gen: Non-functional with Dart 3.10; use manual providers only
- `surfaceVariant`: Replaced by `surfaceContainerHighest` in Material 3

## Open Questions

1. **Should "Songs I Run To" be accessible from the home screen navigation buttons?**
   - What we know: The home screen has navigation buttons for Stride Calculator, My Runs, Taste Profiles, Generate Playlist, Playlist History, and Song Feedback. The route would be `/running-songs`.
   - What's unclear: Whether to add a home screen button now (Phase 28) or defer to when search is available (Phase 30). Without search, users can only remove songs, not add them from this screen.
   - Recommendation: Add the route and screen, but add the home screen navigation button. The screen will show the empty state with guidance text pointing users to playlists for adding songs. Later phases (search) will add the primary "add" flow. The phase requirement "User can add a song to their 'Songs I Run To' list" implies an add mechanism exists somewhere -- likely from playlist results (similar to how like/dislike works on SongTile). A simple action on SongTile (or the play options bottom sheet) is the natural add point.

2. **Where does "add to Songs I Run To" live in the UI for Phase 28?**
   - What we know: Success criterion 1 says "User can add a song to their 'Songs I Run To' list." The requirement SONGS-01 says "from search results," but there is no search UI yet (Phase 30).
   - What's unclear: Whether Phase 28 should add the action to existing song tiles (in playlists) or only build the data layer and defer all "add" UI to later phases.
   - Recommendation: Add an "Add to Songs I Run To" action in the SongTile play options bottom sheet (the sheet shown on tap, which already has Spotify and YouTube links). This gives users a way to curate songs they discover in generated playlists. The requirement says "from search results" but the success criterion is broader. Adding from playlists is a natural first entry point.

3. **Should the `RunningSong` model store `songKey` explicitly or compute it via getter?**
   - What we know: `CuratedSong` and `BpmSong` compute `lookupKey` as a getter. `SongFeedback` stores `songKey` explicitly as a required field.
   - What's unclear: Which pattern to follow.
   - Recommendation: Store `songKey` explicitly (like `SongFeedback`), because it is the primary key for the persistence map. Computing it on every access is wasteful when it's also the map key. The stored value must equal `SongKey.normalize(artist, title)`.

## Sources

### Primary (HIGH confidence)
- **Codebase analysis** (direct file reads):
  - `lib/features/song_feedback/domain/song_feedback.dart` -- SongKey, SongFeedback model
  - `lib/features/song_feedback/data/song_feedback_preferences.dart` -- Persistence pattern
  - `lib/features/song_feedback/providers/song_feedback_providers.dart` -- StateNotifier + Completer pattern
  - `lib/features/song_feedback/presentation/song_feedback_library_screen.dart` -- List screen + empty state
  - `lib/features/taste_profile/domain/taste_profile.dart` -- Complex model with enums
  - `lib/features/taste_profile/data/taste_profile_preferences.dart` -- Multi-entity persistence
  - `lib/features/taste_profile/providers/taste_profile_providers.dart` -- Library state pattern
  - `lib/features/playlist_freshness/domain/playlist_freshness.dart` -- PlayHistory model
  - `lib/features/playlist_freshness/data/playlist_freshness_preferences.dart` -- Preferences with corrupt-entry skip
  - `lib/features/playlist_freshness/providers/playlist_freshness_providers.dart` -- Dual notifier file
  - `lib/features/playlist/domain/playlist.dart` -- PlaylistSong model
  - `lib/features/playlist/domain/playlist_generator.dart` -- isLiked integration point
  - `lib/features/playlist/providers/playlist_providers.dart` -- _readFeedbackSets() for Phase 29
  - `lib/features/playlist/presentation/widgets/song_tile.dart` -- Song UI + feedback actions
  - `lib/features/curated_songs/domain/curated_song.dart` -- CuratedSong model
  - `lib/features/bpm_lookup/domain/bpm_song.dart` -- BpmSong model
  - `lib/features/song_quality/domain/song_quality_scorer.dart` -- Scoring dimensions + isLiked
  - `lib/features/home/presentation/home_screen.dart` -- Home screen navigation
  - `lib/app/router.dart` -- Route registration
  - `pubspec.yaml` -- Dependencies
  - `test/features/song_feedback/domain/song_feedback_test.dart` -- Domain model test pattern
  - `test/features/song_feedback/song_feedback_lifecycle_test.dart` -- Lifecycle test pattern

- **Milestone research** (`.planning/research/SUMMARY.md`):
  - RunningSong model design decisions (separate from SongFeedback)
  - RunningSongNotifier pattern specification
  - Phase ordering rationale (data layer first)
  - Integration point documentation (scoring, taste learning)

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** -- zero new dependencies, all patterns directly observed in 6+ existing features
- Architecture: **HIGH** -- direct pattern replication of SongFeedbackNotifier + SongFeedbackPreferences
- Pitfalls: **HIGH** -- all pitfalls derived from observed codebase patterns and documented known issues

**Research date:** 2026-02-08
**Valid until:** 2026-03-10 (stable patterns, no external dependency changes expected)
