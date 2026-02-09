# Phase 29: Scoring & Taste Integration - Research

**Researched:** 2026-02-09
**Domain:** Flutter Riverpod provider integration -- scoring boost, taste pattern analysis, BPM compatibility UI
**Confidence:** HIGH

## Summary

Phase 29 wires the Phase 28 "Songs I Run To" data layer into three existing systems: playlist generation scoring, taste pattern analysis, and a new BPM compatibility indicator on the running songs screen. All three requirements involve modification of existing code rather than creation of new features. No new dependencies are required. The entire implementation consists of small, targeted changes across five existing files plus one new pure-Dart utility for BPM compatibility logic.

The scoring boost (SONGS-03) is the simplest change: merge running song keys into the `liked` set inside `PlaylistGenerationNotifier._readFeedbackSets()`. This gives running songs the existing `+5` likedSongWeight in `SongQualityScorer.score()`, matching the prior decision from milestone research. The method already produces a `({Set<String> disliked, Set<String> liked})` record, and running song keys need only be unioned into the `liked` set. The `shufflePlaylist()` and `regeneratePlaylist()` methods also call `_readFeedbackSets()`, so the boost applies universally.

The taste learning integration (SONGS-04) requires converting running songs into synthetic `SongFeedback` entries that the `TastePatternAnalyzer.analyze()` can process. The analyzer takes a `Map<String, SongFeedback>` as input. Running songs must be converted to `SongFeedback(isLiked: true, ...)` entries and merged into the feedback map before analysis. The natural integration point is `TasteSuggestionNotifier._reanalyze()`, where the real feedback map is already read from `songFeedbackProvider`. Additionally, the notifier should listen to `runningSongProvider` for reactive re-analysis when running songs change.

The BPM compatibility indicator (SONGS-05) is a new UI element on the `RunningSongsScreen` showing green/amber/gray chips relative to the user's current cadence target. This requires reading the current cadence from `strideNotifierProvider` and computing BPM compatibility for each `RunningSong` that has a known BPM. The computation logic (exact/half/double match = green, within +/-5% = amber, else gray) should be a pure function for testability.

**Primary recommendation:** Implement as three independent units: (1) one-line liked set merge in `_readFeedbackSets()` with `ensureLoaded()` addition, (2) synthetic feedback conversion in `TasteSuggestionNotifier._reanalyze()` with reactive listener, (3) BPM compatibility pure function + UI chip on `_RunningSongCard`.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter_riverpod` | ^2.6.1 | State management | All provider modifications use existing manual Riverpod patterns |
| `flutter/material.dart` | (SDK) | BPM indicator UI | Colored chip widget on running songs screen |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `shared_preferences` | ^2.5.4 | Persistence (read-only) | Running songs are read but not modified by this phase |

### Alternatives Considered
None. This phase uses exclusively existing dependencies and modifies existing code. No new packages needed.

**Installation:**
No new packages required. All dependencies already in `pubspec.yaml`.

## Architecture Patterns

### Recommended File Changes
```
lib/features/playlist/providers/playlist_providers.dart          # MODIFY: _readFeedbackSets()
lib/features/taste_learning/providers/taste_learning_providers.dart  # MODIFY: _reanalyze() + listener
lib/features/running_songs/presentation/running_songs_screen.dart   # MODIFY: add BPM chip
lib/features/running_songs/domain/bpm_compatibility.dart            # NEW: pure function
test/features/running_songs/domain/bpm_compatibility_test.dart      # NEW: unit tests
test/features/playlist/providers/playlist_providers_test.dart       # MODIFY: add integration test
test/features/taste_learning/domain/taste_pattern_analyzer_test.dart # MODIFY: add synthetic feedback test
```

### Pattern 1: Merging Running Song Keys into Liked Set (SONGS-03)
**What:** Add running song keys to the `liked` set in `_readFeedbackSets()` so running songs receive the `likedSongWeight (+5)` scoring boost.
**When to use:** Every call to `_readFeedbackSets()` (used by `generatePlaylist()`, `shufflePlaylist()`, `regeneratePlaylist()`).
**Integration point:** `PlaylistGenerationNotifier._readFeedbackSets()` in `lib/features/playlist/providers/playlist_providers.dart`

**Current code (lines 100-112):**
```dart
({Set<String> disliked, Set<String> liked}) _readFeedbackSets() {
  final feedbackMap = ref.read(songFeedbackProvider);
  final disliked = <String>{};
  final liked = <String>{};
  for (final entry in feedbackMap.entries) {
    if (entry.value.isLiked) {
      liked.add(entry.key);
    } else {
      disliked.add(entry.key);
    }
  }
  return (disliked: disliked, liked: liked);
}
```

**Modified code:**
```dart
({Set<String> disliked, Set<String> liked}) _readFeedbackSets() {
  final feedbackMap = ref.read(songFeedbackProvider);
  final disliked = <String>{};
  final liked = <String>{};
  for (final entry in feedbackMap.entries) {
    if (entry.value.isLiked) {
      liked.add(entry.key);
    } else {
      disliked.add(entry.key);
    }
  }
  // Merge "Songs I Run To" keys into liked set for scoring boost
  final runningSongs = ref.read(runningSongProvider);
  liked.addAll(runningSongs.keys);
  return (disliked: disliked, liked: liked);
}
```

**Also required:** Add `await ref.read(runningSongProvider.notifier).ensureLoaded();` in `generatePlaylist()` and `regeneratePlaylist()` alongside the other `ensureLoaded()` calls. The `shufflePlaylist()` method does not await async loads (it's synchronous), so it relies on the provider already being loaded from a prior generate call -- this is consistent with the existing pattern.

**Import addition:**
```dart
import 'package:running_playlist_ai/features/running_songs/providers/running_song_providers.dart';
```

### Pattern 2: Synthetic Feedback for Taste Learning (SONGS-04)
**What:** Convert running songs to synthetic `SongFeedback` entries and merge into the feedback map before passing to `TastePatternAnalyzer.analyze()`.
**When to use:** In `TasteSuggestionNotifier._reanalyze()`.
**Integration point:** `lib/features/taste_learning/providers/taste_learning_providers.dart`

**Conversion logic:**
```dart
/// Converts running songs to synthetic liked SongFeedback entries
/// for taste pattern analysis.
Map<String, SongFeedback> _syntheticFeedbackFromRunningSongs(
  Map<String, RunningSong> runningSongs,
) {
  return {
    for (final entry in runningSongs.entries)
      entry.key: SongFeedback(
        songKey: entry.key,
        isLiked: true,
        feedbackDate: entry.value.addedDate,
        songTitle: entry.value.title,
        songArtist: entry.value.artist,
        genre: entry.value.genre,
      ),
  };
}
```

**Merge into _reanalyze():**
```dart
Future<void> _reanalyze() async {
  final feedback = ref.read(songFeedbackProvider);
  final runningSongs = ref.read(runningSongProvider);
  final profileState = ref.read(tasteProfileLibraryProvider);
  final profile = profileState.selectedProfile;
  if (profile == null || (feedback.isEmpty && runningSongs.isEmpty)) {
    if (mounted) state = [];
    return;
  }

  // Merge real feedback with synthetic feedback from running songs.
  // Real feedback takes precedence (existing key wins in spread).
  final syntheticFeedback = _syntheticFeedbackFromRunningSongs(runningSongs);
  final mergedFeedback = {...syntheticFeedback, ...feedback};

  final genreLookupAsync = ref.read(curatedGenreLookupProvider);
  final genreLookup = genreLookupAsync.valueOrNull ?? {};

  final suggestions = TastePatternAnalyzer.analyze(
    feedback: mergedFeedback,
    curatedGenreLookup: genreLookup,
    activeProfile: profile,
    dismissedSuggestions: _dismissedSuggestions,
  );

  if (mounted) state = suggestions;
}
```

**Key detail:** Using `{...syntheticFeedback, ...feedback}` ensures real feedback entries overwrite synthetic ones when both exist for the same song key. This prevents double-counting: if a user both liked a song AND added it to "Songs I Run To", the real feedback (which may be a dislike toggled after adding) takes precedence.

**Reactive listener:** Add `ref.listen(runningSongProvider, (_, __) => _reanalyze());` in the constructor, alongside the existing listeners for `songFeedbackProvider` and `tasteProfileLibraryProvider`.

### Pattern 3: BPM Compatibility Indicator (SONGS-05)
**What:** A pure function that determines BPM compatibility level, plus UI chip on the running songs screen.
**When to use:** For each `RunningSong` with a known BPM, relative to the user's current cadence.

**BPM compatibility logic (new file: `bpm_compatibility.dart`):**
```dart
/// BPM compatibility level relative to a cadence target.
enum BpmCompatibility {
  /// BPM matches cadence exactly, or at half/double time.
  match,

  /// BPM is within +/-5% of cadence, half, or double.
  close,

  /// BPM is outside the match/close range, or unknown.
  none,
}

/// Computes BPM compatibility relative to a cadence target.
///
/// - [match] (green): BPM equals cadence, half, or double (exact integer match)
/// - [close] (amber): BPM is within +/-5% of cadence, half, or double
/// - [none] (gray): BPM is outside range or null
BpmCompatibility bpmCompatibility({
  required int? songBpm,
  required int cadence,
}) {
  if (songBpm == null) return BpmCompatibility.none;

  final targets = [cadence, cadence ~/ 2, cadence * 2];
  for (final target in targets) {
    if (songBpm == target) return BpmCompatibility.match;
  }

  for (final target in targets) {
    final tolerance = (target * 0.05).ceil();
    if ((songBpm - target).abs() <= tolerance) {
      return BpmCompatibility.close;
    }
  }

  return BpmCompatibility.none;
}
```

**UI integration on `_RunningSongCard`:**
The card currently shows `song.title`, `song.artist`, and `song.addedDate`. The BPM compatibility chip should appear next to the existing content, showing:
- Green dot/chip for `BpmCompatibility.match`
- Amber dot/chip for `BpmCompatibility.close`
- Gray dot/chip (or nothing) for `BpmCompatibility.none`

The cadence comes from `ref.watch(strideNotifierProvider).cadence.round()`. Since `RunningSongsScreen` is currently a `ConsumerWidget`, it already has access to `ref`. The `_RunningSongCard` widget currently takes `WidgetRef ref` as a parameter, so it can read stride state. Alternatively, the cadence can be passed down as a parameter to avoid coupling the card to the stride provider.

**Recommendation:** Pass cadence as an `int` parameter to `_RunningSongCard` to keep the card testable and decoupled. Compute cadence once in `RunningSongsScreen.build()`.

### Anti-Patterns to Avoid
- **Creating a new scoring dimension for running songs:** The running songs boost should use the existing `likedSongWeight (+5)` mechanism, not a new scoring dimension. Adding running songs to the liked set is the cleanest integration -- no changes to `SongQualityScorer` needed.
- **Modifying `TastePatternAnalyzer.analyze()` signature:** The analyzer is a pure static function. Instead of modifying its inputs, convert running songs to the existing `SongFeedback` input format before calling analyze.
- **Storing BPM compatibility in the model:** BPM compatibility is a derived value that depends on the user's current cadence, which changes. Compute it reactively in the UI, never persist it.
- **Making `_RunningSongCard` a ConsumerWidget:** The card is currently a `StatelessWidget` that receives `WidgetRef ref` as a constructor parameter. Converting it to a `ConsumerWidget` is fine but adds coupling. Preferred: pass cadence as an `int` parameter.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Scoring boost for running songs | Custom scoring dimension in SongQualityScorer | Merge keys into liked set in `_readFeedbackSets()` | Reuses existing `likedSongWeight (+5)` mechanism; zero changes to scorer |
| Taste pattern analysis of running songs | New analyzer or modified analyzer signature | Synthetic `SongFeedback` conversion + merge before `analyze()` | Analyzer is pure function with stable interface; conversion is trivial |
| BPM range matching | Custom math in UI widget | Pure function in domain layer | Testable, reusable, decoupled from presentation |
| Song key format | Inline `artist.toLowerCase()\|title.toLowerCase()` | `SongKey.normalize(artist, title)` | Single source of truth, already used everywhere |

**Key insight:** This phase is pure integration work. Every requirement is satisfied by connecting existing systems via small modifications, not by building new features.

## Common Pitfalls

### Pitfall 1: Missing `ensureLoaded()` for Running Songs Provider
**What goes wrong:** `_readFeedbackSets()` reads an empty running songs map on cold start because the provider hasn't finished loading from SharedPreferences.
**Why it happens:** `RunningSongNotifier` uses the same async init pattern as all other notifiers. Reading state before `_load()` completes returns the initial empty map.
**How to avoid:** Add `await ref.read(runningSongProvider.notifier).ensureLoaded();` in `generatePlaylist()` and `regeneratePlaylist()`, alongside the existing `ensureLoaded()` calls for `songFeedbackProvider`, `playHistoryProvider`, and `freshnessModeProvider`.
**Warning signs:** Running songs added before first playlist generation don't receive the scoring boost.

### Pitfall 2: Double-Counting When Song Is Both Liked and in Running Songs
**What goes wrong:** A song that is both explicitly liked (via feedback) AND in "Songs I Run To" gets counted twice in the liked set.
**Why it happens:** Naive approach: add feedback liked keys + running song keys without dedup.
**How to avoid:** This is actually a non-issue. `Set.addAll()` is idempotent -- adding a key that already exists does nothing. The liked set is a `Set<String>`, so merging running song keys that overlap with feedback liked keys produces no duplicates. The `+5` boost is applied once during scoring regardless of how many times the key appears in the set.
**Warning signs:** None. The set data structure handles this correctly.

### Pitfall 3: Synthetic Feedback Overwriting Real Feedback
**What goes wrong:** A running song's synthetic "liked" feedback overwrites a user's real "dislike" feedback for the same song.
**Why it happens:** Using wrong merge order: `{...realFeedback, ...syntheticFeedback}` would let synthetic entries overwrite real ones.
**How to avoid:** Merge as `{...syntheticFeedback, ...realFeedback}` -- real feedback (from `songFeedbackProvider`) is spread second, so it takes precedence. If a user disliked a song but also has it in "Songs I Run To" (unusual but possible), the dislike feedback drives taste learning.
**Warning signs:** Taste suggestions recommending genres/artists that the user has actively disliked.

### Pitfall 4: BPM Compatibility Using Floating-Point Cadence
**What goes wrong:** Cadence is `double` from `StrideState.cadence` (e.g., 170.5). Using it directly in integer BPM comparison gives incorrect results.
**Why it happens:** `StrideState.cadence` returns a `double` because the formula calculation produces decimal values.
**How to avoid:** Round cadence to `int` before BPM compatibility computation. The home screen already does `strideState.cadence.round()` for display. Follow the same pattern.
**Warning signs:** Songs at exact cadence BPM showing amber instead of green.

### Pitfall 5: Running Songs Without BPM Show Misleading Indicator
**What goes wrong:** Running songs added from API-sourced playlists may not have a BPM field (it's optional). Showing a gray "no match" indicator implies the song doesn't fit the cadence, when really BPM data is simply unavailable.
**Why it happens:** `RunningSong.bpm` is `int?`. API-sourced songs that weren't in the curated dataset may lack BPM.
**How to avoid:** When `song.bpm == null`, show no BPM indicator at all (hide the chip). Reserve gray for songs with known BPM that don't match. This is the difference between "unknown" and "incompatible."
**Warning signs:** Users confused by gray indicators on songs they know match their cadence.

### Pitfall 6: Reactive Listener Order in TasteSuggestionNotifier
**What goes wrong:** Adding a `ref.listen(runningSongProvider, ...)` call in the constructor may trigger `_reanalyze()` before the initial `_load()` completes.
**Why it happens:** Riverpod listeners fire synchronously during provider initialization if the watched provider already has state.
**How to avoid:** The `_reanalyze()` method already handles this gracefully: it checks `feedback.isEmpty` and `profile == null` and returns early. With the running songs integration, the check should be `feedback.isEmpty && runningSongs.isEmpty`. The Completer pattern ensures `_load()` runs first. No additional guard needed beyond the existing early-return checks.
**Warning signs:** Suggestions appearing briefly then disappearing during app startup.

## Code Examples

Verified patterns from the existing codebase:

### SONGS-03: Scoring Integration (complete diff)
```dart
// In PlaylistGenerationNotifier._readFeedbackSets()
// After the existing feedback loop, add:
final runningSongs = ref.read(runningSongProvider);
liked.addAll(runningSongs.keys);

// In generatePlaylist(), add ensureLoaded:
await ref.read(runningSongProvider.notifier).ensureLoaded();

// In regeneratePlaylist(), add ensureLoaded:
await ref.read(runningSongProvider.notifier).ensureLoaded();
```
**Source:** `lib/features/playlist/providers/playlist_providers.dart` lines 100-112, 131-139, 266-295

### SONGS-04: Taste Learning Integration (conversion function)
```dart
// Helper: converts running songs to synthetic liked SongFeedback entries
Map<String, SongFeedback> _syntheticFeedbackFromRunningSongs(
  Map<String, RunningSong> runningSongs,
) {
  return {
    for (final entry in runningSongs.entries)
      entry.key: SongFeedback(
        songKey: entry.key,
        isLiked: true,
        feedbackDate: entry.value.addedDate,
        songTitle: entry.value.title,
        songArtist: entry.value.artist,
        genre: entry.value.genre,
      ),
  };
}
```
**Source:** Pattern derived from `SongFeedback` model at `lib/features/song_feedback/domain/song_feedback.dart` lines 34-43

### SONGS-05: BPM Compatibility Function
```dart
enum BpmCompatibility { match, close, none }

BpmCompatibility bpmCompatibility({
  required int? songBpm,
  required int cadence,
}) {
  if (songBpm == null) return BpmCompatibility.none;

  final targets = [cadence, cadence ~/ 2, cadence * 2];
  for (final target in targets) {
    if (songBpm == target) return BpmCompatibility.match;
  }
  for (final target in targets) {
    final tolerance = (target * 0.05).ceil();
    if ((songBpm - target).abs() <= tolerance) return BpmCompatibility.close;
  }
  return BpmCompatibility.none;
}
```

### BPM Indicator UI Chip
```dart
Widget _bpmChip(BpmCompatibility compat, int bpm, ThemeData theme) {
  final (color, icon) = switch (compat) {
    BpmCompatibility.match => (Colors.green, Icons.check_circle),
    BpmCompatibility.close => (Colors.amber, Icons.circle_outlined),
    BpmCompatibility.none => (Colors.grey, Icons.circle_outlined),
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text('$bpm', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ],
    ),
  );
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Code-generated Riverpod providers | Manual Riverpod providers | Dart 3.10 broke code-gen | All provider modifications must be manual |
| `surfaceVariant` for backgrounds | `surfaceContainerLow` | Material 3 migration | Card colors in running songs screen |
| Custom scored song integration | Merge into liked set | Phase 23 introduced likedSongWeight | Running songs boost follows same mechanism |

**Deprecated/outdated:**
- `riverpod_generator` code-gen: Non-functional with Dart 3.10; all changes use manual providers
- `withOpacity()`: Deprecated in Flutter; use `withValues(alpha: ...)` instead

## Open Questions

1. **Should running songs receive a higher boost than regular liked songs?**
   - What we know: The milestone research says "treated like liked songs" with `likedSongWeight = 5`. The SUMMARY.md mentions "stronger than liked boost: +8 to +10 vs. +5" but attributes this to a future search feature, not Phase 29.
   - What's unclear: Whether Phase 29 should use the standard `+5` or introduce a stronger boost.
   - Recommendation: Use the existing `+5` likedSongWeight for Phase 29 (matches prior decisions). A stronger boost can be added later by introducing a separate `runningSongWeight` constant in `SongQualityScorer`. For now, the one-line merge approach is cleaner and matches the milestone's "treated like liked songs" language.

2. **Should running songs without BPM show any indicator?**
   - What we know: `RunningSong.bpm` is optional (`int?`). Songs added from API-sourced playlists may lack BPM.
   - What's unclear: Whether to show a gray chip (implying "no match") or hide the indicator entirely.
   - Recommendation: Hide the BPM indicator when `song.bpm == null`. Only show the chip when BPM data is available. This avoids the misleading "no match" signal for songs with unknown BPM.

3. **Should `_RunningSongCard` also display the BPM value alongside the indicator?**
   - What we know: The existing `SongTile` shows BPM in a chip. The `_RunningSongCard` currently shows title, artist, addedDate, and source label.
   - What's unclear: Whether to show just the colored dot, or the full BPM value with colored background.
   - Recommendation: Show the BPM value with colored background (matching the SongTile chip style). This provides more information and serves as a running suitability signal.

## Sources

### Primary (HIGH confidence)
- **Codebase analysis** (direct file reads):
  - `lib/features/playlist/providers/playlist_providers.dart` -- `_readFeedbackSets()` integration point, `generatePlaylist()`, `shufflePlaylist()`, `regeneratePlaylist()` call sites
  - `lib/features/song_quality/domain/song_quality_scorer.dart` -- `likedSongWeight = 5`, scoring dimensions, `score()` method signature
  - `lib/features/taste_learning/providers/taste_learning_providers.dart` -- `TasteSuggestionNotifier._reanalyze()`, reactive listeners, `ref.listen` pattern
  - `lib/features/taste_learning/domain/taste_pattern_analyzer.dart` -- `analyze()` method signature, input types (`Map<String, SongFeedback>`)
  - `lib/features/running_songs/domain/running_song.dart` -- `RunningSong` model, fields available for conversion
  - `lib/features/running_songs/providers/running_song_providers.dart` -- `RunningSongNotifier`, `runningSongProvider`, `ensureLoaded()` pattern
  - `lib/features/running_songs/presentation/running_songs_screen.dart` -- `_RunningSongCard` widget, current layout
  - `lib/features/song_feedback/domain/song_feedback.dart` -- `SongFeedback` constructor, `SongKey.normalize()`
  - `lib/features/stride/providers/stride_providers.dart` -- `StrideState.cadence`, `strideNotifierProvider`
  - `lib/features/bpm_lookup/domain/bpm_matcher.dart` -- BPM query logic (exact/half/double)
  - `lib/features/home/presentation/home_screen.dart` -- Taste suggestion card integration point
  - `lib/features/taste_learning/presentation/taste_suggestion_card.dart` -- Suggestion card UI pattern
  - `lib/features/playlist/domain/playlist_generator.dart` -- `_scoreAndRank()` uses `likedSongKeys`
  - `lib/features/bpm_lookup/domain/bpm_song.dart` -- `lookupKey` getter, BPM data model
  - `test/features/playlist/domain/playlist_generator_test.dart` -- Test patterns for liked song scoring
  - `test/features/taste_learning/domain/taste_pattern_analyzer_test.dart` -- Test patterns for taste analysis
  - `test/features/running_songs/running_song_test.dart` -- Model test patterns
  - `test/features/running_songs/running_song_lifecycle_test.dart` -- Provider lifecycle test patterns

- **Planning documents:**
  - `.planning/research/SUMMARY.md` -- Milestone research confirming one-line scoring integration, synthetic feedback approach
  - `.planning/phases/28-songs-i-run-to-data-layer/28-RESEARCH.md` -- Phase 28 architecture decisions, model design

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** -- zero new dependencies, all modifications to existing code with established patterns
- Architecture: **HIGH** -- integration points explicitly identified in prior milestone research, verified against current codebase
- Pitfalls: **HIGH** -- all pitfalls derived from direct observation of existing code patterns and known issues

**Research date:** 2026-02-09
**Valid until:** 2026-03-11 (stable integration patterns, no external dependency changes expected)
