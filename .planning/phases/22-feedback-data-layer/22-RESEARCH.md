# Phase 22: Feedback Data Layer - Research

**Researched:** 2026-02-07
**Domain:** Local persistence, state management, song key normalization (Dart/Flutter)
**Confidence:** HIGH

## Summary

This phase creates the foundational data layer for song feedback (like/dislike). The research focused on understanding the existing codebase patterns for persistence and state management, since the phase explicitly requires following established conventions. No new dependencies are needed.

The codebase has two well-established patterns that directly map to this phase's needs: (1) static `*Preferences` wrapper classes for SharedPreferences persistence (TasteProfilePreferences, PlaylistHistoryPreferences), and (2) `StateNotifier`-based providers for CRUD state management (TasteProfileLibraryNotifier, PlaylistHistoryNotifier). The feedback data layer should follow these patterns exactly.

A key finding is that the song lookup key normalization (`artist.toLowerCase().trim()|title.toLowerCase().trim()`) exists in three locations but is NOT centralized -- it is a getter on `CuratedSong`, inline in `PlaylistGenerator`, and will need to be used in feedback. This phase should introduce a shared utility function.

**Primary recommendation:** Build SongFeedback model + SongFeedbackPreferences + SongFeedbackNotifier following the established TasteProfileLibrary pattern, with a centralized song key normalization utility.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| shared_preferences | ^2.5.4 | Persistence of feedback map | Already in pubspec, used by TasteProfilePreferences and PlaylistHistoryPreferences |
| flutter_riverpod | ^2.6.1 | State management (StateNotifier) | Already in pubspec, used by all features |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| dart:convert | (stdlib) | JSON encode/decode for SharedPreferences | All persistence wrappers use this |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SharedPreferences | Hive, SQLite | Overkill for <1MB feedback data; SharedPreferences matches existing patterns |
| Map serialization | Separate key per song | Single JSON blob is the established pattern; simpler to reason about |

**Installation:** No new dependencies needed. Zero additions to pubspec.yaml.

## Architecture Patterns

### Recommended Project Structure
```
lib/features/song_feedback/
  data/
    song_feedback_preferences.dart     # Static persistence wrapper
  domain/
    song_feedback.dart                 # SongFeedback model + SongKey utility
  providers/
    song_feedback_providers.dart       # StateNotifier + providers
```

### Pattern 1: Domain Model (SongFeedback)
**What:** Immutable model with toJson/fromJson, stored as Map<String, SongFeedback>
**When to use:** This is the feedback entry, keyed by normalized song key
**Example (following TasteProfile pattern):**
```dart
/// A user's feedback on a specific song.
class SongFeedback {
  const SongFeedback({
    required this.songKey,
    required this.isLiked,
    required this.feedbackDate,
    required this.songTitle,
    required this.songArtist,
    this.genre,
  });

  factory SongFeedback.fromJson(Map<String, dynamic> json) {
    return SongFeedback(
      songKey: json['songKey'] as String,
      isLiked: json['isLiked'] as bool,
      feedbackDate: DateTime.parse(json['feedbackDate'] as String),
      songTitle: json['songTitle'] as String,
      songArtist: json['songArtist'] as String,
      genre: json['genre'] as String?,
    );
  }

  final String songKey;
  final bool isLiked;
  final DateTime feedbackDate;
  final String songTitle;    // Display name (denormalized for UI)
  final String songArtist;   // Display name (denormalized for UI)
  final String? genre;       // For taste learning (Phase 27)

  Map<String, dynamic> toJson() => {
    'songKey': songKey,
    'isLiked': isLiked,
    'feedbackDate': feedbackDate.toIso8601String(),
    'songTitle': songTitle,
    'songArtist': songArtist,
    if (genre != null) 'genre': genre,
  };

  SongFeedback copyWith({bool? isLiked, DateTime? feedbackDate}) {
    return SongFeedback(
      songKey: songKey,
      isLiked: isLiked ?? this.isLiked,
      feedbackDate: feedbackDate ?? this.feedbackDate,
      songTitle: songTitle,
      songArtist: songArtist,
      genre: genre,
    );
  }
}
```

### Pattern 2: Song Key Normalization Utility
**What:** Static utility function for generating consistent lookup keys
**When to use:** Everywhere a song needs to be identified across curated data and API results
**Rationale:** The normalization logic `artist.toLowerCase().trim()|title.toLowerCase().trim()` currently exists in two places (CuratedSong.lookupKey getter and inline in PlaylistGenerator). This phase should centralize it.
**Example:**
```dart
/// Normalizes artist and title into a consistent lookup key.
///
/// Format: `'artist_lowercase_trimmed|title_lowercase_trimmed'`
/// Used by CuratedSong.lookupKey, PlaylistGenerator, and SongFeedback.
class SongKey {
  SongKey._();

  /// Generates a normalized lookup key from artist and title.
  static String normalize(String artist, String title) =>
      '${artist.toLowerCase().trim()}|${title.toLowerCase().trim()}';
}
```

### Pattern 3: Static Preferences Wrapper (SongFeedbackPreferences)
**What:** Static class wrapping SharedPreferences for load/save/clear
**When to use:** Following TasteProfilePreferences and PlaylistHistoryPreferences patterns
**Key design decisions:**
- Store as single JSON string under one key (matches existing pattern)
- Internal format: JSON object with song keys as map keys (not a list -- enables O(1) lookup after deserialization)
- Corrupt entry resilience: try/catch per entry during deserialization (matches TasteProfilePreferences)
**Example:**
```dart
class SongFeedbackPreferences {
  static const _key = 'song_feedback';

  /// Loads all feedback as a map keyed by normalized song key.
  static Future<Map<String, SongFeedback>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return {};
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    final result = <String, SongFeedback>{};
    for (final entry in map.entries) {
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

  /// Saves the full feedback map.
  static Future<void> save(Map<String, SongFeedback> feedback) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(
      feedback.map((k, v) => MapEntry(k, v.toJson())),
    );
    await prefs.setString(_key, jsonString);
  }

  /// Clears all stored feedback.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
```

### Pattern 4: StateNotifier Provider (SongFeedbackNotifier)
**What:** StateNotifier managing Map<String, SongFeedback> with CRUD + persistence
**When to use:** Following TasteProfileLibraryNotifier pattern with Completer-based ensureLoaded()
**Key methods:**
- `addFeedback(SongFeedback)` -- add or update feedback for a song
- `removeFeedback(String songKey)` -- remove feedback entirely
- `getFeedback(String songKey)` -- O(1) lookup by key
- `ensureLoaded()` -- Completer pattern from TasteProfileLibraryNotifier
**Example:**
```dart
class SongFeedbackNotifier extends StateNotifier<Map<String, SongFeedback>> {
  SongFeedbackNotifier() : super({}) {
    _load();
  }

  final Completer<void> _loadCompleter = Completer<void>();

  Future<void> ensureLoaded() => _loadCompleter.future;

  Future<void> _load() async {
    try {
      state = await SongFeedbackPreferences.load();
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

final songFeedbackProvider =
    StateNotifierProvider<SongFeedbackNotifier, Map<String, SongFeedback>>(
  (ref) => SongFeedbackNotifier(),
);
```

### Anti-Patterns to Avoid
- **Using a List instead of Map for state:** A Map keyed by songKey gives O(1) lookup, which is critical for Phase 23 (checking feedback status during scoring) and Phase 24 (feedback library browsing). The PlaylistHistoryNotifier uses a List because order matters and no keyed lookup is needed -- feedback is the opposite.
- **Storing songKey only without display metadata:** Phase 24 (Feedback Library) needs to show song title and artist. Storing these denormalized in SongFeedback avoids expensive reverse lookups.
- **Hand-rolling date serialization:** Use DateTime.toIso8601String() / DateTime.parse() -- the pattern already used in Playlist.fromJson.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Song key normalization | Inline string concatenation | Centralized `SongKey.normalize()` | Already duplicated in 2 places; will be in 3+ with feedback |
| JSON persistence | Custom file I/O | SharedPreferences + jsonEncode/jsonDecode | Established pattern, handles platform differences |
| State management | Custom streams/callbacks | StateNotifier + Riverpod provider | Established pattern, auto-disposes, testable |
| Async init guarding | Manual flags/checks | Completer-based `ensureLoaded()` | Proven pattern from TasteProfileLibraryNotifier |

**Key insight:** Every piece of this phase has a direct precedent in the codebase. The value is in exact pattern replication, not innovation.

## Common Pitfalls

### Pitfall 1: Map vs JSON Object Serialization
**What goes wrong:** `jsonEncode(map)` where map keys are not strings fails. `jsonDecode` returns `Map<String, dynamic>` not `Map<String, SongFeedback>`.
**Why it happens:** Dart's type system doesn't enforce JSON-safe types at compile time.
**How to avoid:** Always serialize via `feedback.map((k, v) => MapEntry(k, v.toJson()))` and deserialize entry-by-entry with try/catch.
**Warning signs:** Runtime type errors in tests.

### Pitfall 2: SharedPreferences Mock Initialization
**What goes wrong:** Tests fail with "SharedPreferences not initialized" errors.
**Why it happens:** Each test group needs `SharedPreferences.setMockInitialValues({})` in setUp.
**How to avoid:** Always call `SharedPreferences.setMockInitialValues({})` in setUp for every test file that touches preferences.
**Warning signs:** Tests pass individually but fail in batch runs.

### Pitfall 3: Completer Double-Complete
**What goes wrong:** `_loadCompleter.complete()` called twice throws StateError.
**Why it happens:** Load method called multiple times or error path completes then success path also completes.
**How to avoid:** Guard with `if (!_loadCompleter.isCompleted) _loadCompleter.complete()` (exactly as TasteProfileLibraryNotifier does).
**Warning signs:** Intermittent test failures.

### Pitfall 4: Song Key Inconsistency
**What goes wrong:** A song liked via API result has a different key than the same song from curated data.
**Why it happens:** Slight differences in artist/title strings (extra spaces, capitalization quirks).
**How to avoid:** Always use `SongKey.normalize()` as the single source of truth. Never construct keys inline.
**Warning signs:** User likes a song but it still appears as unrated in feedback library.

### Pitfall 5: State Mutation Before Persistence
**What goes wrong:** State updates visible in UI, but app crash before persistence completes loses the change.
**Why it happens:** Optimistic state update followed by async persistence.
**How to avoid:** This is the accepted pattern in this codebase (TasteProfileLibraryNotifier, PlaylistHistoryNotifier both do optimistic updates). It is the correct choice -- the risk is negligible for SharedPreferences writes which are near-instant. Do NOT add pessimistic write-then-update, as it would make the UI feel sluggish.
**Warning signs:** N/A -- this is documented acceptance, not a bug.

### Pitfall 6: Missing `mounted` Check in StateNotifier
**What goes wrong:** Setting state on a disposed notifier throws.
**Why it happens:** Async load completes after provider is disposed.
**How to avoid:** Check `mounted` before setting state in async callbacks (as PlaylistHistoryNotifier does in `_load()`).
**Warning signs:** "setState called after dispose" errors in widget tests.

## Code Examples

### Creating a SongFeedback from a PlaylistSong
```dart
// Source: derived from existing CuratedSong.lookupKey pattern
final feedback = SongFeedback(
  songKey: SongKey.normalize(playlistSong.artistName, playlistSong.title),
  isLiked: true,
  feedbackDate: DateTime.now(),
  songTitle: playlistSong.title,
  songArtist: playlistSong.artistName,
  genre: null, // PlaylistSong doesn't carry genre; OK for now
);
```

### Test Setup Pattern (following existing conventions)
```dart
// Source: test/features/playlist/providers/playlist_history_providers_test.dart
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SongFeedbackNotifier', () {
    test('starts with empty map', () {
      final container = ProviderContainer();
      final state = container.read(songFeedbackProvider);
      expect(state, isEmpty);
    });

    test('addFeedback stores and persists', () async {
      final container = ProviderContainer();
      final notifier = container.read(songFeedbackProvider.notifier);

      final feedback = SongFeedback(
        songKey: SongKey.normalize('Artist', 'Title'),
        isLiked: true,
        feedbackDate: DateTime.utc(2026, 2, 7),
        songTitle: 'Title',
        songArtist: 'Artist',
      );

      await notifier.addFeedback(feedback);

      final state = container.read(songFeedbackProvider);
      expect(state.length, equals(1));
      expect(state['artist|title']?.isLiked, isTrue);
    });
  });
}
```

### Persistence Round-Trip Test (following TasteProfile lifecycle test)
```dart
test('persistence round-trip: survives dispose and reload', () async {
  final container1 = ProviderContainer();
  final notifier1 = container1.read(songFeedbackProvider.notifier);
  await notifier1.ensureLoaded();

  await notifier1.addFeedback(SongFeedback(
    songKey: 'artist|title',
    isLiked: true,
    feedbackDate: DateTime.utc(2026, 2, 7),
    songTitle: 'Title',
    songArtist: 'Artist',
  ));

  container1.dispose();

  // New container reads persisted data
  final container2 = ProviderContainer();
  final notifier2 = container2.read(songFeedbackProvider.notifier);
  await notifier2.ensureLoaded();

  final state = container2.read(songFeedbackProvider);
  expect(state.length, equals(1));
  expect(state['artist|title']?.isLiked, isTrue);
});
```

### Song Key Normalization Verification
```dart
// Critical: same song from different sources must produce same key
test('normalize produces identical keys for same song', () {
  // Curated data format
  final curatedKey = SongKey.normalize('  Eminem ', ' Lose Yourself ');
  // API result format
  final apiKey = SongKey.normalize('Eminem', 'Lose Yourself');

  expect(curatedKey, equals(apiKey));
  expect(curatedKey, equals('eminem|lose yourself'));
});
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| N/A (new feature) | SharedPreferences + StateNotifier | Established in Phase 1-2 | Follow existing conventions |

**Note:** The codebase uses Riverpod 2.x manual providers (not code-gen). This is a known constraint due to Dart 3.10 code-gen incompatibility. All new providers MUST use manual `StateNotifierProvider` declarations.

## Open Questions

1. **Should CuratedSong.lookupKey be refactored to use SongKey.normalize()?**
   - What we know: CuratedSong already has a `lookupKey` getter with the same logic
   - What's unclear: Whether refactoring CuratedSong is in-scope or creates unnecessary risk
   - Recommendation: YES -- add `SongKey.normalize()` utility and update CuratedSong.lookupKey to delegate to it. Also update PlaylistGenerator inline usage. This prevents key drift and is low-risk since the logic is identical.

2. **Should BpmSong get a `lookupKey` getter?**
   - What we know: BpmSong does NOT have a lookupKey getter; playlist_generator builds the key inline
   - What's unclear: Adding a getter to BpmSong changes a heavily-used model
   - Recommendation: YES -- add `String get lookupKey => SongKey.normalize(artistName, title)` to BpmSong. Minimal risk since it's a new getter (non-breaking).

3. **Maximum feedback entries before SharedPreferences becomes a problem?**
   - What we know: SharedPreferences is fine for <1MB. A SongFeedback JSON entry is ~150 bytes.
   - Calculation: 1MB / 150 bytes = ~7,000 songs. Realistic user feedback: hundreds, not thousands.
   - Recommendation: No cap needed for v1.3. Can add pruning in a future phase if telemetry shows growth.

## Sources

### Primary (HIGH confidence)
- `/Users/tijmen/running-playlist-ai/lib/features/taste_profile/data/taste_profile_preferences.dart` -- persistence pattern
- `/Users/tijmen/running-playlist-ai/lib/features/playlist/data/playlist_history_preferences.dart` -- persistence pattern
- `/Users/tijmen/running-playlist-ai/lib/features/taste_profile/providers/taste_profile_providers.dart` -- StateNotifier pattern with Completer
- `/Users/tijmen/running-playlist-ai/lib/features/playlist/providers/playlist_history_providers.dart` -- simpler StateNotifier pattern
- `/Users/tijmen/running-playlist-ai/lib/features/curated_songs/domain/curated_song.dart` -- lookupKey normalization pattern
- `/Users/tijmen/running-playlist-ai/lib/features/bpm_lookup/domain/bpm_song.dart` -- song model (no lookupKey)
- `/Users/tijmen/running-playlist-ai/lib/features/playlist/domain/playlist_generator.dart` -- inline key normalization
- `/Users/tijmen/running-playlist-ai/test/features/taste_profile/taste_profile_lifecycle_test.dart` -- test patterns
- `/Users/tijmen/running-playlist-ai/test/features/playlist/providers/playlist_history_providers_test.dart` -- test patterns
- `/Users/tijmen/running-playlist-ai/test/features/playlist/data/playlist_history_preferences_test.dart` -- preferences test patterns

### Secondary (MEDIUM confidence)
- Milestone research context (provided in phase description) -- confirms SharedPreferences, Map<String, SongFeedback>, binary like/dislike decisions

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - zero new dependencies, all existing in pubspec.yaml
- Architecture: HIGH - exact pattern replication from 3 existing features
- Pitfalls: HIGH - derived from actual codebase patterns and test failures
- Song key normalization: HIGH - verified by reading all 3 code locations with the pattern

**Research date:** 2026-02-07
**Valid until:** 2026-03-07 (stable patterns, no external dependencies)
