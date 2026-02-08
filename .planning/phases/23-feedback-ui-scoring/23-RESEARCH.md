# Phase 23: Feedback UI & Scoring - Research

**Researched:** 2026-02-08
**Domain:** Flutter UI (inline feedback icons), Riverpod state integration, SongQualityScorer modification, PlaylistGenerator hard-filtering
**Confidence:** HIGH

## Summary

This phase connects the Phase 22 feedback data layer to two surfaces: (1) inline like/dislike icons on the existing SongTile widget in the playlist view, and (2) feedback-aware scoring and filtering in the playlist generation pipeline. No new dependencies or libraries are needed. Every piece of this phase builds on established codebase patterns.

The UI work centers on the `SongTile` widget, which currently shows track number, song info, BPM chip, and a star badge. Like/dislike icons must be added without disrupting the existing layout. The `SongTile` is currently a plain `StatelessWidget` and does not take `WidgetRef` -- it will need to become a `ConsumerWidget` (or receive callbacks) so it can read/write the feedback provider. The playlist screen already wraps each `SongTile` in a `Dismissible` for swipe-to-remove, so care is needed to not conflict with that gesture.

The scoring/filtering work has two distinct parts: (1) a hard filter in `PlaylistGenerator` that removes disliked songs from candidates before scoring, and (2) a scoring boost in `SongQualityScorer` for liked songs. The hard filter is straightforward -- filter the `available` list before passing to `_scoreAndRank`. The scoring boost requires adding a new parameter to `SongQualityScorer.score()` and a new scoring dimension. Success criterion 4 ("a liked song with poor running metrics does not outrank an unrated song with excellent running metrics") constrains the boost magnitude: it must be smaller than the runnability range (0-15).

**Primary recommendation:** Add like/dislike icons to SongTile as a ConsumerWidget, add `PlaylistSong.lookupKey` getter, hard-filter disliked songs in PlaylistGenerator before scoring, and add a liked-song boost of +5 to SongQualityScorer (meaningful but cannot overcome a 10-point runnability gap).

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_riverpod | ^2.6.1 | Reactive state management for feedback icons | Already in pubspec, used by all features |
| shared_preferences | ^2.5.4 | Persistence via existing SongFeedbackPreferences | Already in pubspec, data layer built in Phase 22 |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter/material.dart | (SDK) | Icons.thumb_up / Icons.thumb_down widgets | Feedback icon display |
| flutter_test | (SDK) | Widget and unit testing | All tests |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Inline icons on SongTile | Swipe gestures for like/dislike | Swipe is already used for Dismissible (remove song). Conflicting gestures would be confusing. Icons are unambiguous. |
| ConsumerWidget for SongTile | Callback props from parent | Callbacks add prop-drilling through _PlaylistView. ConsumerWidget is simpler since SongTile already lives in a ConsumerWidget tree. |
| Fixed +5 liked boost | Configurable/weighted boost | Over-engineering for v1.3. A fixed constant matches the existing scoring pattern (all weights are static constants). |

**Installation:** No new dependencies needed.

## Architecture Patterns

### Recommended Project Structure
```
lib/features/
  playlist/
    presentation/
      widgets/
        song_tile.dart              # MODIFY: add feedback icons, become ConsumerWidget
    domain/
      playlist.dart                 # MODIFY: add lookupKey getter to PlaylistSong
      playlist_generator.dart       # MODIFY: accept feedback map, hard-filter disliked songs
    providers/
      playlist_providers.dart       # MODIFY: pass feedback map to generator
  song_quality/
    domain/
      song_quality_scorer.dart      # MODIFY: add likedSong parameter and scoring dimension
  song_feedback/
    providers/
      song_feedback_providers.dart  # READ ONLY: already built in Phase 22
    domain/
      song_feedback.dart            # READ ONLY: SongKey.normalize() already available
```

### Pattern 1: Adding Feedback Icons to SongTile
**What:** Convert SongTile from StatelessWidget to ConsumerWidget, add thumb_up/thumb_down icons with reactive state from songFeedbackProvider
**When to use:** This is the primary UI change for FEED-01
**Key design considerations:**
- SongTile is shared by both PlaylistScreen and PlaylistHistoryDetailScreen. Both should show feedback icons.
- Icons should be compact (IconButton with constraints) to fit the existing Row layout.
- Three visual states: neutral (outlined icons), liked (filled thumb_up, green/primary tint), disliked (filled thumb_down, red/error tint).
- Tapping a selected icon again should toggle it off (remove feedback).
- The SongTile currently has `song.title` and `song.artistName` -- these are needed to create the SongFeedback object.

**Example:**
```dart
// SongTile becomes ConsumerWidget
class SongTile extends ConsumerWidget {
  const SongTile({required this.song, this.index, super.key});

  final PlaylistSong song;
  final int? index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedbackMap = ref.watch(songFeedbackProvider);
    final feedback = feedbackMap[song.lookupKey];
    final isLiked = feedback?.isLiked;

    // ... existing layout with feedback icons added
    // Icons go between song info and BPM chip, or trailing after BPM chip
  }
}
```

### Pattern 2: PlaylistSong.lookupKey Getter
**What:** Add a lookupKey getter to PlaylistSong that delegates to SongKey.normalize()
**When to use:** Everywhere a PlaylistSong needs to be matched against the feedback map
**Rationale:** BpmSong already has this getter (added in Phase 22). PlaylistSong should be consistent.
**Example:**
```dart
// In PlaylistSong class
String get lookupKey => SongKey.normalize(artistName, title);
```

### Pattern 3: Hard-Filter Disliked Songs in PlaylistGenerator
**What:** Filter out disliked songs from the candidate pool before scoring
**When to use:** FEED-03 requires disliked songs never appear in generated playlists
**Key design decision:** The filter goes in PlaylistGenerator.generate(), not in _scoreAndRank(). Filtering at the generate level means disliked songs are removed from the entire pipeline -- they can never be selected for any segment. This is cleaner than a negative score (which could still allow selection if the pool is small).
**Example:**
```dart
// In PlaylistGenerator.generate():
static Playlist generate({
  required RunPlan runPlan,
  required Map<int, List<BpmSong>> songsByBpm,
  TasteProfile? tasteProfile,
  Random? random,
  Map<String, int>? curatedRunnability,
  Set<String>? dislikedSongKeys,  // NEW: keys of disliked songs to exclude
  Set<String>? likedSongKeys,     // NEW: keys of liked songs for boost
}) {
  // ... in segment loop:
  // Filter out disliked songs (hard filter)
  var available = candidates
      .where((s) => !usedSongIds.contains(s.songId))
      .toList();
  if (dislikedSongKeys != null && dislikedSongKeys.isNotEmpty) {
    available = available
        .where((s) => !dislikedSongKeys.contains(s.lookupKey))
        .toList();
  }
  // ...
}
```

### Pattern 4: Liked-Song Scoring Boost in SongQualityScorer
**What:** Add a new scoring dimension for liked songs
**When to use:** FEED-04 requires liked songs to rank higher than equivalent unrated songs
**Key constraint from success criteria 4:** A liked song with poor running metrics must NOT outrank an unrated song with excellent running metrics. This constrains the boost magnitude.

**Score analysis for boost sizing:**
- Runnability range: 0-15 (null gets neutral 5)
- A "poor metrics" song: runnability 0, danceability 0 = 0 + 0 = 0 points from these
- An "excellent metrics" unrated song: runnability 15, danceability 8 = 23 points from these
- Gap between poor and excellent running metrics = 23 points
- The liked boost must be << 23 to satisfy criterion 4

**Recommended boost: +5 points**
- A liked song with poor metrics (0 runnability, 0 danceability): gets +5 from like = 5
- An unrated song with excellent metrics (15 runnability, 8 danceability): gets 23
- 5 < 23, so the constraint is satisfied by a wide margin
- +5 is still meaningful: it's equivalent to going from neutral danceability (3) to max danceability (8), or from moderate runnability (9) to good runnability (12). It will noticeably boost liked songs in the ranking.
- Updated max score: 46 + 5 = 51

**Example:**
```dart
// In SongQualityScorer:
static const likedSongWeight = 5;

static int score({
  required BpmSong song,
  TasteProfile? tasteProfile,
  String? previousArtist,
  List<RunningGenre>? songGenres,
  int? runnability,
  bool isLiked = false,  // NEW parameter
}) {
  var total = 0;
  // ... existing dimensions ...
  if (isLiked) total += likedSongWeight;
  return total;
}
```

### Pattern 5: Wiring Feedback into PlaylistGenerationNotifier
**What:** The provider orchestrator loads feedback and passes it to the generator
**When to use:** Both generatePlaylist() and shufflePlaylist() need feedback data
**Key design:** Read songFeedbackProvider, ensure loaded, extract disliked/liked sets, pass to generator
**Example:**
```dart
// In PlaylistGenerationNotifier.generatePlaylist():
await ref.read(songFeedbackProvider.notifier).ensureLoaded();
final feedbackMap = ref.read(songFeedbackProvider);
final dislikedKeys = feedbackMap.entries
    .where((e) => !e.value.isLiked)
    .map((e) => e.key)
    .toSet();
final likedKeys = feedbackMap.entries
    .where((e) => e.value.isLiked)
    .map((e) => e.key)
    .toSet();

final playlist = PlaylistGenerator.generate(
  // ... existing params ...
  dislikedSongKeys: dislikedKeys.isNotEmpty ? dislikedKeys : null,
  likedSongKeys: likedKeys.isNotEmpty ? likedKeys : null,
);
```

### Anti-Patterns to Avoid
- **Using a massive negative score instead of hard-filter for disliked songs:** A score of -999 could still allow selection if the candidate pool is tiny (only disliked songs available for a segment BPM). Hard filtering is deterministic and guaranteed.
- **Putting feedback logic in PlaylistScreen instead of SongTile:** The SongTile is shared across PlaylistScreen and PlaylistHistoryDetailScreen. Feedback should work in both places without duplication.
- **Auto-removing the song from the visible playlist on dislike:** Dislike should mark the song for future exclusion but not remove it from the currently displayed playlist. The user already generated this playlist and may want to see what they disliked. Removing songs is already handled by the existing Dismissible swipe-to-remove pattern.
- **Making liked boost depend on other scoring dimensions:** Keep it a flat additive constant, just like every other scoring dimension. Multiplicative or conditional boosts add complexity for no proven benefit.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Song key for PlaylistSong | Inline `'${artist.toLowerCase()}...'` | `SongKey.normalize()` via new `PlaylistSong.lookupKey` getter | Centralized in Phase 22, prevents key drift |
| Feedback persistence | Custom save logic | Existing `SongFeedbackNotifier.addFeedback()` | Built and tested in Phase 22, handles optimistic update + persistence |
| Reactive feedback state | Manual StreamController | `ref.watch(songFeedbackProvider)` | Built in Phase 22, auto-updates all widgets watching it |
| Song filtering | Custom filter in each screen | Hard filter in `PlaylistGenerator.generate()` | Single location, testable, covers all generation paths |

**Key insight:** Phase 22 built the entire data layer. Phase 23 is purely about wiring it to the existing UI and generation pipeline. Zero new persistence or state management code needed.

## Common Pitfalls

### Pitfall 1: Forgetting to Pass Feedback to shufflePlaylist()
**What goes wrong:** User dislikes a song, shuffles, and the disliked song reappears.
**Why it happens:** `shufflePlaylist()` is a separate method from `generatePlaylist()` and easy to forget when adding the feedback parameter.
**How to avoid:** Both `generatePlaylist()` and `shufflePlaylist()` must read the current feedback state and pass disliked/liked sets to `PlaylistGenerator.generate()`. Same for `regeneratePlaylist()`.
**Warning signs:** Disliked songs reappear only when shuffling, not when fully regenerating.

### Pitfall 2: SongTile Layout Overflow with Feedback Icons
**What goes wrong:** Adding two icon buttons makes the Row overflow on narrow screens.
**Why it happens:** The existing Row has: track number (28px) + spacing (10px) + expanded text + spacing (8px) + BPM chip. Adding two icon buttons (~80px total) can push content past screen edge.
**How to avoid:** Use compact icon buttons (constrained size, smaller icons ~18px), or stack them vertically, or use a single toggle button that cycles through states. The BPM chip is already 60px wide -- check total fits at 320px minimum width.
**Warning signs:** Overflow warning in debug console on narrow devices.

### Pitfall 3: Score Test Regression from New Parameter
**What goes wrong:** Existing SongQualityScorer tests fail because the method signature changed.
**Why it happens:** Adding `isLiked` parameter to `score()` method. If it's a required parameter, all existing call sites break.
**How to avoid:** Make `isLiked` an optional parameter with default `false`. This is backward-compatible -- all existing callers get the same behavior as before.
**Warning signs:** Compilation errors in existing test files.

### Pitfall 4: Feedback ensureLoaded() Race Condition
**What goes wrong:** Feedback map is empty when generator reads it because async load hasn't completed.
**Why it happens:** SongFeedbackNotifier loads from SharedPreferences asynchronously on construction.
**How to avoid:** Call `await ref.read(songFeedbackProvider.notifier).ensureLoaded()` before reading the state, just like the existing pattern for `runPlanLibraryProvider` and `tasteProfileLibraryProvider` in `PlaylistGenerationNotifier.generatePlaylist()`.
**Warning signs:** Feedback seems to work on second generation but not first.

### Pitfall 5: Losing Feedback When Dismissing a Song
**What goes wrong:** User likes a song, then swipes to dismiss it. The feedback should still persist.
**Why it happens:** Dismissible removes the song from the playlist state. If the feedback is only stored in the playlist (not the feedback provider), it's lost.
**How to avoid:** Feedback is stored in `songFeedbackProvider` (SharedPreferences), not in the playlist. Dismissing a song from the playlist does not affect feedback. This is already correct by design.
**Warning signs:** None if feedback is properly stored in the provider.

### Pitfall 6: Composite Score Test Needs Updating
**What goes wrong:** The "best case" composite score test (currently expects 46) will fail if the liked boost is added to the max score.
**Why it happens:** The test explicitly asserts `expect(score, equals(46))`.
**How to avoid:** Update the best-case test to include `isLiked: true` and expect 51 (46 + 5), OR keep the test as-is (testing without like) since `isLiked` defaults to false. Both approaches are valid. Recommend keeping existing test as-is AND adding a new test for liked boost.
**Warning signs:** Test failure in existing composite scoring test.

## Code Examples

### Creating SongFeedback from a PlaylistSong in the UI
```dart
// Source: derived from Phase 22 patterns
void _onLike(WidgetRef ref, PlaylistSong song) {
  final notifier = ref.read(songFeedbackProvider.notifier);
  final key = song.lookupKey;
  final existing = notifier.getFeedback(key);

  if (existing != null && existing.isLiked) {
    // Already liked -- toggle off
    notifier.removeFeedback(key);
  } else {
    notifier.addFeedback(SongFeedback(
      songKey: key,
      isLiked: true,
      feedbackDate: DateTime.now(),
      songTitle: song.title,
      songArtist: song.artistName,
    ));
  }
}
```

### Feedback-Aware Icon Display in SongTile
```dart
// Three states: neutral, liked, disliked
Widget _feedbackIcons(WidgetRef ref, PlaylistSong song) {
  final feedbackMap = ref.watch(songFeedbackProvider);
  final feedback = feedbackMap[song.lookupKey];
  final isLiked = feedback?.isLiked;

  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _FeedbackIconButton(
        icon: isLiked == true ? Icons.thumb_up : Icons.thumb_up_outlined,
        color: isLiked == true ? Colors.green : null,
        onPressed: () => _onLike(ref, song),
        tooltip: 'Like',
      ),
      _FeedbackIconButton(
        icon: isLiked == false ? Icons.thumb_down : Icons.thumb_down_outlined,
        color: isLiked == false ? Theme.of(context).colorScheme.error : null,
        onPressed: () => _onDislike(ref, song),
        tooltip: 'Dislike',
      ),
    ],
  );
}
```

### Hard-Filter Test for Disliked Songs
```dart
// Source: derived from existing playlist_generator_test.dart patterns
test('disliked songs are excluded from generated playlist', () {
  final plan = RunPlan(
    type: RunType.steady,
    distanceKm: 5,
    paceMinPerKm: 6,
    segments: [
      RunSegment(durationSeconds: 210, targetBpm: 170, label: 'Run'),
    ],
  );

  final songsByBpm = {
    170: [
      _song(id: 'liked', title: 'Liked Song', artist: 'Artist A'),
      _song(id: 'disliked', title: 'Disliked Song', artist: 'Artist B'),
    ],
  };

  final dislikedKeys = {'artist b|disliked song'};

  final playlist = PlaylistGenerator.generate(
    runPlan: plan,
    songsByBpm: songsByBpm,
    dislikedSongKeys: dislikedKeys,
    random: Random(42),
  );

  expect(playlist.songs.length, equals(1));
  expect(playlist.songs.first.title, equals('Liked Song'));
});
```

### Liked Boost Test
```dart
test('liked song scores +5 higher than equivalent unrated song', () {
  final likedScore = SongQualityScorer.score(
    song: _song(),
    isLiked: true,
  );
  final unratedScore = SongQualityScorer.score(
    song: _song(),
    isLiked: false,
  );
  expect(likedScore - unratedScore, equals(5));
});

test('liked song with poor metrics does NOT outrank unrated with excellent metrics', () {
  // Poor metrics: no runnability, no danceability
  final likedPoor = SongQualityScorer.score(
    song: _song(danceability: 10),
    isLiked: true,
    runnability: 5,
  );
  // Excellent metrics: high runnability, high danceability
  final unratedExcellent = SongQualityScorer.score(
    song: _song(danceability: 85),
    isLiked: false,
    runnability: 90,
  );
  expect(unratedExcellent, greaterThan(likedPoor));
});
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| No feedback mechanism | Phase 22 data layer only (no UI, no scoring) | Phase 22 (2026-02-08) | Data foundation ready, no user-facing feature yet |
| Static scoring (8 dimensions, max 46) | Will become 9 dimensions (max 51 with liked boost) | This phase | Existing tests remain valid since new param defaults to false |

**Deprecated/outdated:**
- None relevant. All patterns in the codebase are current.

## Open Questions

1. **Should feedback icons appear in PlaylistHistoryDetailScreen too?**
   - What we know: SongTile is shared between PlaylistScreen and PlaylistHistoryDetailScreen. If SongTile shows feedback icons, both screens get them automatically.
   - What's unclear: The phase description says "playlist view" -- is that only the generation view or also history detail?
   - Recommendation: YES, show feedback in both places. Users reviewing old playlists should be able to rate songs retroactively. Since SongTile is shared, this comes for free with no extra work. The success criteria say "any song in the generated playlist view" but showing them in history detail too is strictly additive and won't break anything.

2. **Should the Dismissible swipe-to-remove automatically dislike the song?**
   - What we know: Currently, swiping a song removes it and offers replacements. There's no feedback implication.
   - What's unclear: Whether removing a song implies dislike intent.
   - Recommendation: NO. Keep them separate. Swiping to remove is "I don't want this in THIS playlist." Disliking is "I never want to see this song again." These are distinct user intents. Coupling them would surprise users.

3. **Should the liked boost constant be configurable per taste profile?**
   - What we know: All existing scoring constants are static (not per-profile).
   - Recommendation: NO. Keep it a static constant like every other weight. Per-profile tuning is premature optimization with no user demand signal.

## Sources

### Primary (HIGH confidence)
- `/Users/tijmen/running-playlist-ai/lib/features/playlist/presentation/widgets/song_tile.dart` -- current SongTile layout and interaction patterns
- `/Users/tijmen/running-playlist-ai/lib/features/song_quality/domain/song_quality_scorer.dart` -- current scoring dimensions and weights
- `/Users/tijmen/running-playlist-ai/lib/features/playlist/domain/playlist_generator.dart` -- current generation pipeline and filtering
- `/Users/tijmen/running-playlist-ai/lib/features/playlist/domain/playlist.dart` -- PlaylistSong model (no lookupKey yet)
- `/Users/tijmen/running-playlist-ai/lib/features/playlist/providers/playlist_providers.dart` -- PlaylistGenerationNotifier orchestration
- `/Users/tijmen/running-playlist-ai/lib/features/playlist/presentation/playlist_screen.dart` -- current playlist view with Dismissible wrapping
- `/Users/tijmen/running-playlist-ai/lib/features/song_feedback/domain/song_feedback.dart` -- SongKey.normalize() and SongFeedback model
- `/Users/tijmen/running-playlist-ai/lib/features/song_feedback/providers/song_feedback_providers.dart` -- SongFeedbackNotifier with ensureLoaded()
- `/Users/tijmen/running-playlist-ai/test/features/song_quality/domain/song_quality_scorer_test.dart` -- existing scorer test patterns
- `/Users/tijmen/running-playlist-ai/test/features/playlist/domain/playlist_generator_test.dart` -- existing generator test patterns
- `/Users/tijmen/running-playlist-ai/.planning/phases/22-feedback-data-layer/22-VERIFICATION.md` -- verified Phase 22 outputs

### Secondary (MEDIUM confidence)
- Phase 22 research and plan documents -- confirmed data layer patterns and decisions (22-01, 22-02)

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - zero new dependencies, all existing in pubspec
- Architecture: HIGH - all patterns derived from reading actual codebase files; no external research needed
- Pitfalls: HIGH - identified from reading actual code interactions (Dismissible + icons, scoring signature backward-compat, race conditions in existing ensureLoaded patterns)
- Scoring boost sizing: HIGH - mathematically derived from existing weight constants with explicit constraint satisfaction check against success criterion 4

**Research date:** 2026-02-08
**Valid until:** 2026-03-08 (stable internal patterns, no external dependencies)
