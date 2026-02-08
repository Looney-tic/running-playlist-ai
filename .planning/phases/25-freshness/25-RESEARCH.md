# Phase 25: Freshness - Research

**Researched:** 2026-02-08
**Domain:** Playlist freshness tracking, time-decayed scoring, user preference toggle
**Confidence:** HIGH

## Summary

Phase 25 adds playlist freshness: tracking which songs were included in generated playlists, penalizing recently-played songs during future generation, and letting the user toggle between "keep it fresh" and "optimize for taste" modes.

The codebase already has all the infrastructure needed. Playlist history (`PlaylistHistoryPreferences`) stores full playlist data with `createdAt` timestamps. Songs have `lookupKey` (via `SongKey.normalize`) for cross-source matching. `SongQualityScorer.score()` accepts optional named parameters, making it straightforward to add a `freshnessPenalty` dimension. SharedPreferences persistence with static class wrappers is the established pattern for all data layers in this project.

**Primary recommendation:** Extract a lightweight `Map<String, DateTime>` (songKey -> lastPlayedAt) from playlist history at generation time. Add a `freshnessPenalty` parameter to `SongQualityScorer.score()`. Persist the toggle as a single boolean in SharedPreferences following the `OnboardingPreferences` pattern.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| shared_preferences | ^2.5.4 | Persist freshness toggle & play history | Already used for all persistence in this app |
| flutter_riverpod | ^2.6.1 | State management for freshness toggle + play history | Already used for all state management |

### Supporting
No additional libraries needed. All functionality is achievable with existing dependencies.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SharedPreferences map | Derive from PlaylistHistory | PlaylistHistory already stores full playlists with timestamps; deriving at generation time avoids duplicate storage, but scanning 50 playlists on every generation is O(50*songs). Still fast enough (<1ms for ~500 songs). |
| Separate play_history store | Reuse playlist_history | Separate store adds a new persistence key but gives O(1) lookup. Playlist history may be cleared independently. Separate store is cleaner. |
| Per-song DateTime tracking | Just count appearances | DateTime enables time-decay (songs played 7 days ago penalized less than yesterday). Count-only loses temporal signal. DateTime is correct. |

## Architecture Patterns

### Recommended Project Structure
```
lib/features/
  playlist_freshness/
    domain/
      playlist_freshness.dart       # PlayHistory model + FreshnessMode enum
    data/
      playlist_freshness_preferences.dart  # SharedPreferences persistence
    providers/
      playlist_freshness_providers.dart    # StateNotifier + providers
```

### Pattern 1: Play History as Lightweight Map
**What:** A `Map<String, DateTime>` mapping `songKey` (via `SongKey.normalize`) to the most recent `DateTime` the song appeared in a generated playlist. Updated after each successful playlist generation.
**When to use:** Every time `PlaylistGenerationNotifier` generates or shuffles a playlist.
**Example:**
```dart
// Domain model
class PlayHistory {
  const PlayHistory({this.entries = const {}});

  /// songKey -> last time this song appeared in a generated playlist
  final Map<String, DateTime> entries;

  /// Records all songs from a generated playlist.
  PlayHistory recordPlaylist(Playlist playlist) {
    final updated = Map<String, DateTime>.from(entries);
    final now = playlist.createdAt;
    for (final song in playlist.songs) {
      updated[song.lookupKey] = now;
    }
    return PlayHistory(entries: updated);
  }

  /// Calculates freshness penalty for a song (0 = fresh, negative = stale).
  int freshnessPenalty(String songKey, {DateTime? now}) {
    final lastPlayed = entries[songKey];
    if (lastPlayed == null) return 0; // Never played = no penalty

    final daysSince = (now ?? DateTime.now()).difference(lastPlayed).inDays;
    if (daysSince >= 14) return 0;    // 2+ weeks ago = fresh again
    if (daysSince >= 7) return -2;    // 1-2 weeks = light penalty
    if (daysSince >= 3) return -5;    // 3-7 days = moderate penalty
    return -8;                         // 0-2 days = heavy penalty
  }
}
```

### Pattern 2: Freshness Mode Toggle
**What:** A simple enum persisted as a boolean in SharedPreferences. When "keep it fresh" is active, the freshness penalty is applied during scoring. When "optimize for taste", no penalty is applied.
**When to use:** User toggle in the playlist generation UI (idle view or settings).
**Example:**
```dart
enum FreshnessMode { keepItFresh, optimizeForTaste }

// Persistence (follows OnboardingPreferences pattern)
class FreshnessPreferences {
  static const _modeKey = 'freshness_mode';

  static Future<FreshnessMode> loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_modeKey);
    if (value == 'optimizeForTaste') return FreshnessMode.optimizeForTaste;
    return FreshnessMode.keepItFresh; // default
  }

  static Future<void> saveMode(FreshnessMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
  }
}
```

### Pattern 3: Scoring Integration
**What:** Add `freshnessPenalty` as an optional `int` parameter to `SongQualityScorer.score()`, following the same pattern as `isLiked`. The caller (`PlaylistGenerator`) computes the penalty from `PlayHistory` and passes it in.
**When to use:** During `_scoreAndRank` in `PlaylistGenerator`.
**Example:**
```dart
// In SongQualityScorer.score():
static int score({
  required BpmSong song,
  // ... existing params ...
  int freshnessPenalty = 0,  // New: 0 or negative
}) {
  var total = 0;
  // ... existing scoring ...
  total += freshnessPenalty;
  return total;
}

// In PlaylistGenerator.generate():
static Playlist generate({
  // ... existing params ...
  Map<String, DateTime>? playHistory,  // New
}) {
  // In _scoreAndRank, compute penalty per song:
  final penalty = playHistory != null
      ? PlayHistory(entries: playHistory).freshnessPenalty(song.lookupKey)
      : 0;
}
```

### Pattern 4: Toggle Placement in Playlist Screen
**What:** Add a `SegmentedButton` or `SwitchListTile` in the playlist idle view (next to the run plan and taste profile selectors) for freshness mode.
**When to use:** Before generating a playlist.
**Example:**
```dart
// In _IdleView or _PlaylistView, above the Generate button:
SegmentedButton<FreshnessMode>(
  segments: const [
    ButtonSegment(
      value: FreshnessMode.keepItFresh,
      label: Text('Keep it Fresh'),
      icon: Icon(Icons.auto_awesome),
    ),
    ButtonSegment(
      value: FreshnessMode.optimizeForTaste,
      label: Text('Best Taste'),
      icon: Icon(Icons.favorite),
    ),
  ],
  selected: {currentMode},
  onSelectionChanged: (selected) { ... },
),
```

### Anti-Patterns to Avoid
- **Storing full song objects in play history:** Only store songKey + DateTime. The play history should be lightweight (~50 bytes per entry vs ~500 for full song data).
- **Rebuilding play history from playlist history on every generation:** Extracting from 50 playlists each with ~10 songs on every generate is wasteful. Maintain a separate, incrementally updated map.
- **Applying freshness penalty in optimize-for-taste mode:** The mode toggle must completely disable the penalty, not just reduce it.
- **Using playlist_history as the source of truth for play history:** Playlist history can be cleared by the user (delete playlists). Play history should be independent -- clearing history should not affect freshness tracking.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Time-decayed scoring | Complex exponential decay formula | Simple tier-based penalty (0, -2, -5, -8) | Matches the existing tiered scoring pattern in SongQualityScorer. Over-engineering decay curves adds complexity with no user-visible benefit at this scale. |
| Toggle persistence | Custom file-based storage | SharedPreferences `getString`/`setString` | Established pattern; all other preferences use this. |

**Key insight:** The existing `SongQualityScorer` uses integer tiers for all scoring dimensions (danceability, runnability, etc.). A tiered freshness penalty (by days-since-played) is consistent and simple to test.

## Common Pitfalls

### Pitfall 1: Race Between Play History Save and Next Generation
**What goes wrong:** User generates a playlist, immediately hits shuffle. The play history hasn't finished writing to SharedPreferences yet, so the shuffled playlist doesn't know about the songs from the first generation.
**Why it happens:** SharedPreferences writes are async. The `unawaited()` pattern used for `addPlaylist` in the current code does not wait for persistence.
**How to avoid:** Update the in-memory state (StateNotifier) synchronously before persisting. The Riverpod state is the source of truth during the session; SharedPreferences is for cross-restart persistence.
**Warning signs:** Shuffled playlists repeat the same songs as the just-generated playlist, but only on the first session.

### Pitfall 2: Unbounded Play History Growth
**What goes wrong:** Play history map grows indefinitely as the user generates hundreds of playlists over months.
**Why it happens:** No pruning strategy.
**How to avoid:** Prune entries older than 30 days on save (or on load). Songs older than 14 days already get no penalty, so entries older than 30 days serve no purpose.
**Warning signs:** SharedPreferences string grows very large over time (unlikely to cause issues at realistic usage, but good hygiene).

### Pitfall 3: Freshness Penalty Too Aggressive
**What goes wrong:** With a small song pool (~50 curated songs at a given BPM), aggressive freshness penalties mean the app runs out of "fresh" songs after 3-4 generations, producing poor playlists.
**Why it happens:** Penalty values that are too large relative to quality scores push good songs below mediocre ones.
**How to avoid:** Cap the maximum freshness penalty at -8 (less than the liked song boost of +5 and much less than the max quality score of 46+). A song with high quality should still rank above a mediocre fresh song.
**Warning signs:** Users switching to "keep it fresh" mode get noticeably worse playlists than "optimize for taste" mode.

### Pitfall 4: Forgetting to Wire All Three Generation Paths
**What goes wrong:** Freshness works for `generatePlaylist()` but not for `shufflePlaylist()` or `regeneratePlaylist()`.
**Why it happens:** The three methods in `PlaylistGenerationNotifier` each independently call `PlaylistGenerator.generate()`. Easy to forget one.
**How to avoid:** Check all three methods (generatePlaylist, shufflePlaylist, regeneratePlaylist) and ensure play history + freshness mode are passed to all three. This was learned in Phase 23 (decision 23-01).
**Warning signs:** Shuffle produces repeated songs even in "keep it fresh" mode.

## Code Examples

Verified patterns from the existing codebase:

### SharedPreferences Persistence Pattern (from SongFeedbackPreferences)
```dart
// Source: lib/features/song_feedback/data/song_feedback_preferences.dart
class SongFeedbackPreferences {
  static const _key = 'song_feedback';

  static Future<Map<String, SongFeedback>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return {};
    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    // ... parse entries ...
    return result;
  }

  static Future<void> save(Map<String, SongFeedback> feedback) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(feedback.map((k, v) => MapEntry(k, v.toJson())));
    await prefs.setString(_key, encoded);
  }
}
```

### StateNotifier with ensureLoaded Pattern (from SongFeedbackNotifier)
```dart
// Source: lib/features/song_feedback/providers/song_feedback_providers.dart
class SongFeedbackNotifier extends StateNotifier<Map<String, SongFeedback>> {
  SongFeedbackNotifier() : super({}) {
    _load();
  }

  final Completer<void> _loadCompleter = Completer<void>();

  Future<void> ensureLoaded() => _loadCompleter.future;

  Future<void> _load() async {
    try {
      final feedback = await SongFeedbackPreferences.load();
      if (mounted) state = feedback;
    } finally {
      if (!_loadCompleter.isCompleted) _loadCompleter.complete();
    }
  }
}
```

### Wiring Feedback Into All 3 Generation Paths (from playlist_providers.dart)
```dart
// Source: lib/features/playlist/providers/playlist_providers.dart
// All three methods (generatePlaylist, shufflePlaylist, regeneratePlaylist)
// call _readFeedbackSets() and pass dislikedSongKeys/likedSongKeys to
// PlaylistGenerator.generate(). Phase 25 must follow the same pattern
// for play history and freshness mode.
```

### Adding a Scoring Dimension (from SongQualityScorer likedSongWeight)
```dart
// Source: lib/features/song_quality/domain/song_quality_scorer.dart
// The isLiked parameter was added in Phase 23:
static int score({
  required BpmSong song,
  // ...
  bool isLiked = false,  // Added in Phase 23
}) {
  var total = 0;
  // ... other scoring ...
  if (isLiked) total += likedSongWeight;
  return total;
}
// Freshness follows the same pattern: add freshnessPenalty int parameter
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| No play tracking | Phase 25 adds play tracking | Current phase | Enables "keep it fresh" mode |
| Flat scoring (no temporal dimension) | Time-decayed freshness penalty | Current phase | Songs penalized based on recency |

**Deprecated/outdated:**
- `withOpacity` -- use `withValues(alpha:)` instead (learned in Phase 23, decision 23-02)

## Open Questions

1. **Default freshness mode**
   - What we know: Two modes exist: "keep it fresh" and "optimize for taste"
   - What's unclear: Which should be the default for new users
   - Recommendation: Default to "keep it fresh" -- users who generate multiple playlists benefit from variety. Power users who prefer consistency can toggle to "optimize for taste". This aligns with the success criteria which tests "keep it fresh" behavior first.

2. **Freshness penalty weight calibration**
   - What we know: Current max quality score is 51 (46 base + 5 liked). Freshness penalty should not dominate.
   - What's unclear: Exact penalty tiers. Proposed: -8 (0-2 days), -5 (3-6 days), -2 (7-13 days), 0 (14+ days).
   - Recommendation: Start with proposed tiers. The -8 max penalty is significant enough to move recently-played songs down the ranking but not so large that it overrides quality entirely. A song scored 46 (best quality) penalized -8 still scores 38, well above the median unpenalized score (~11). Test-driven tuning is easy since the scorer is pure and deterministic.

3. **Play history pruning threshold**
   - What we know: Entries older than 14 days get no penalty.
   - What's unclear: Whether to prune at 14 days (no-penalty threshold) or 30 days (buffer).
   - Recommendation: Prune at 30 days for safety margin. The data is tiny (one entry = ~60 chars of JSON). No performance concern.

## Sources

### Primary (HIGH confidence)
- Codebase investigation: All architecture patterns, code examples, and dependency versions verified directly from source files in the repository.
- `lib/features/song_quality/domain/song_quality_scorer.dart` -- scoring dimensions, weight constants, parameter patterns
- `lib/features/playlist/domain/playlist_generator.dart` -- generation flow, parameter passing, all three paths
- `lib/features/playlist/providers/playlist_providers.dart` -- orchestration, feedback wiring, all three methods
- `lib/features/song_feedback/` -- full data layer pattern (domain model, preferences, providers)
- `lib/features/playlist/domain/playlist.dart` -- PlaylistSong.lookupKey, Playlist.createdAt
- `lib/features/onboarding/data/onboarding_preferences.dart` -- simple boolean persistence pattern
- `pubspec.yaml` -- shared_preferences ^2.5.4, flutter_riverpod ^2.6.1

### Secondary (MEDIUM confidence)
- Prior phase decisions (22-01, 23-01, 23-02, 24-01) -- patterns for extending the scorer and wiring through all generation paths

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no new dependencies needed; all patterns verified from existing codebase
- Architecture: HIGH -- follows established patterns (SongFeedbackPreferences, SongFeedbackNotifier, SongQualityScorer.score parameter extension)
- Pitfalls: HIGH -- derived from actual codebase patterns (three generation paths learned from Phase 23, race conditions from async persistence pattern)

**Research date:** 2026-02-08
**Valid until:** 2026-03-08 (30 days -- stable patterns, no external dependencies)
