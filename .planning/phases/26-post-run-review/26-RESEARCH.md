# Phase 26: Post-Run Review - Research

**Researched:** 2026-02-08
**Domain:** Flutter UI (review flow screen), Riverpod state management, SharedPreferences persistence, go_router navigation
**Confidence:** HIGH

## Summary

Phase 26 adds a post-run review flow: after generating a playlist and (presumably) going for a run, the user returns to the home screen and sees a prompt to rate all songs from their most recent playlist. Tapping the prompt opens a dedicated review screen where the user can like or dislike each song. After completing or dismissing the review, the prompt disappears.

The codebase already has all the building blocks. Playlist history (`playlistHistoryProvider`) stores full playlists with all songs. Song feedback (`songFeedbackProvider`) handles like/dislike persistence and wiring to playlist generation. The `SongTile` widget already contains inline like/dislike toggle logic. The `PlaylistSong` model has `lookupKey` for matching against the feedback map. The home screen (`HomeScreen`) already uses conditional cards for setup prompts, making it straightforward to add a review prompt card.

The only genuinely new concept is tracking which playlists have been "reviewed" (or dismissed). This requires a small piece of persistence: a set of playlist IDs (or a single "last reviewed playlist ID") stored in SharedPreferences. When the most recent playlist's ID is in the reviewed set, the prompt disappears. This follows the same SharedPreferences static-class pattern used by `OnboardingPreferences`, `SongFeedbackPreferences`, and `PlayHistoryPreferences`.

**Primary recommendation:** Create a `PostRunReviewScreen` as a `ConsumerWidget` that lists all songs from the most recent unreviewed playlist with like/dislike buttons (reusing the feedback toggle logic from `SongTile`). Add a `PostRunReviewPreferences` persistence class to track dismissed/reviewed playlist IDs. Add a review prompt card to `HomeScreen` that appears when the most recent playlist has not been reviewed. Wire everything through a simple Riverpod provider. No changes to the feedback data layer, scoring pipeline, or playlist generation are needed.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_riverpod | ^2.6.1 | Reactive state for review status + feedback interaction | Already in pubspec, used by all features |
| go_router | ^17.0.1 | Navigation to the review screen | Already in pubspec, router pattern established |
| shared_preferences | ^2.5.4 | Persist reviewed/dismissed playlist IDs | Already in pubspec, used for all persistence |
| flutter/material.dart | (SDK) | Card, ListView, IconButton for review UI | Material 3 widgets, consistent with existing screens |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_test | (SDK) | Unit and widget tests | Testing review state logic |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Dedicated review screen | Bottom sheet on home screen | Bottom sheet limits vertical space; a full playlist may have 15+ songs. Dedicated screen is better for scrollable lists and matches the pattern of other feature screens in the app. |
| Storing a Set of reviewed playlist IDs | Storing just the last reviewed playlist ID | A set is more robust -- handles edge cases where the user generates multiple playlists without reviewing. But a single string (last-dismissed ID) is simpler and sufficient since we only prompt for the MOST RECENT playlist. |
| New review-specific SongTile variant | Reuse existing SongTile widget | SongTile includes external link functionality (Spotify/YouTube bottom sheet) and BPM chip which may be distracting in a review context. A simpler card focused on artist/title + like/dislike may be cleaner. However, reusing SongTile is less code and provides a consistent experience. |

**Installation:** No new dependencies needed.

## Architecture Patterns

### Recommended Project Structure
```
lib/features/
  post_run_review/
    data/
      post_run_review_preferences.dart   # NEW: SharedPreferences for reviewed playlist IDs
    providers/
      post_run_review_providers.dart     # NEW: StateNotifier + derived provider for review prompt
    presentation/
      post_run_review_screen.dart        # NEW: review flow screen
lib/features/home/presentation/
  home_screen.dart                       # MODIFY: add review prompt card
lib/app/
  router.dart                            # MODIFY: add /post-run-review route
```

### Pattern 1: Review State Tracking
**What:** Track which playlist IDs the user has reviewed or dismissed, using a single SharedPreferences key storing the ID of the last dismissed/reviewed playlist.
**When to use:** Determining whether to show the review prompt on the home screen.
**Key insight:** We only ever prompt for the MOST RECENT playlist. We do not need to track a set of reviewed IDs -- just the ID of the last playlist the user reviewed or dismissed. If the most recent playlist's ID matches the dismissed ID, hide the prompt. If a new playlist is generated (different ID), the prompt reappears.
**Example:**
```dart
class PostRunReviewPreferences {
  static const _key = 'last_reviewed_playlist_id';

  static Future<String?> loadLastReviewedId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> saveLastReviewedId(String playlistId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, playlistId);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
```

### Pattern 2: Derived "Needs Review" Provider
**What:** A derived provider that combines `playlistHistoryProvider` (to get the most recent playlist) and the review preferences (to check if it was already reviewed) into a single boolean or nullable Playlist.
**When to use:** The home screen watches this provider to decide whether to show the review prompt card.
**Key insight:** The provider should return the unreviewed playlist (or null). This way the home screen can both check the condition and access the playlist data for display purposes (e.g., showing "Rate your 5K playlist" with the playlist name).
**Example:**
```dart
class PostRunReviewNotifier extends StateNotifier<String?> {
  PostRunReviewNotifier() : super(null) {
    _load();
  }

  final Completer<void> _loadCompleter = Completer<void>();
  Future<void> ensureLoaded() => _loadCompleter.future;

  Future<void> _load() async {
    try {
      final id = await PostRunReviewPreferences.loadLastReviewedId();
      if (mounted) state = id;
    } finally {
      if (!_loadCompleter.isCompleted) _loadCompleter.complete();
    }
  }

  Future<void> markReviewed(String playlistId) async {
    state = playlistId;
    await PostRunReviewPreferences.saveLastReviewedId(playlistId);
  }
}

final postRunReviewProvider =
    StateNotifierProvider<PostRunReviewNotifier, String?>(
  (ref) => PostRunReviewNotifier(),
);

/// Returns the most recent playlist that has NOT been reviewed/dismissed,
/// or null if there is nothing to review.
final unreviewedPlaylistProvider = Provider<Playlist?>((ref) {
  final playlists = ref.watch(playlistHistoryProvider);
  final lastReviewedId = ref.watch(postRunReviewProvider);

  if (playlists.isEmpty) return null;

  final mostRecent = playlists.first; // newest first
  if (mostRecent.id == null) return null;
  if (mostRecent.id == lastReviewedId) return null;

  return mostRecent;
});
```

### Pattern 3: Review Prompt Card on Home Screen
**What:** A conditional card on the home screen that appears when an unreviewed playlist exists. Follows the existing `_SetupCard` pattern.
**When to use:** Between the quick-regenerate section and the navigation buttons on the home screen.
**Key design:** Use the same `_SetupCard` style (or a similar Card + ListTile) with an icon like `Icons.rate_review` or `Icons.star_outline`, showing "Rate your last playlist" with the playlist name as subtitle. Tapping navigates to `/post-run-review`.
**Example:**
```dart
// In HomeScreen.build(), after hasPlan section:
final unreviewedPlaylist = ref.watch(unreviewedPlaylistProvider);

if (unreviewedPlaylist != null)
  _SetupCard(
    icon: Icons.rate_review,
    title: 'Rate your last playlist',
    subtitle: '${unreviewedPlaylist.songs.length} songs from '
        '${unreviewedPlaylist.runPlanName ?? "your run"}',
    color: theme.colorScheme.tertiaryContainer,
    onTap: () => context.push('/post-run-review'),
  ),
```

### Pattern 4: Review Screen Song List with Feedback Buttons
**What:** A dedicated screen showing all songs from the most recent playlist in order, each with like/dislike buttons. The existing `SongTile` widget can be reused directly since it already reads from `songFeedbackProvider` and handles toggle logic.
**When to use:** The review screen body.
**Key insight:** Reusing `SongTile` is the path of least resistance. It already renders the song info, shows feedback state, and handles like/dislike toggling through `songFeedbackProvider.notifier`. The review screen just needs to wrap it in a ListView with a header and a "Done" / "Skip" action.
**Example:**
```dart
class PostRunReviewScreen extends ConsumerWidget {
  const PostRunReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = ref.watch(unreviewedPlaylistProvider);

    if (playlist == null) {
      // Already reviewed or no playlists -- pop back
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Your Playlist'),
        actions: [
          TextButton(
            onPressed: () => _dismiss(context, ref, playlist),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with song count
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'How did these songs feel during your run?',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: playlist.songs.length,
              itemBuilder: (context, index) {
                return SongTile(song: playlist.songs[index], index: index + 1);
              },
            ),
          ),
          // Done button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: () => _dismiss(context, ref, playlist),
                icon: const Icon(Icons.check),
                label: const Text('Done'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _dismiss(BuildContext context, WidgetRef ref, Playlist playlist) {
    if (playlist.id != null) {
      ref.read(postRunReviewProvider.notifier).markReviewed(playlist.id!);
    }
    context.pop();
  }
}
```

### Pattern 5: Router Registration
**What:** Add a GoRoute for the review screen.
**Example:**
```dart
GoRoute(
  path: '/post-run-review',
  builder: (context, state) => const PostRunReviewScreen(),
),
```

### Anti-Patterns to Avoid
- **Creating a separate feedback mechanism for the review screen:** The review screen uses the SAME `songFeedbackProvider` as inline feedback in `SongTile`. Do not create a separate "review feedback" store. All feedback goes through the single `SongFeedbackNotifier`.
- **Auto-popping the review screen when the unreviewedPlaylistProvider changes:** If the screen watches `unreviewedPlaylistProvider` and the user taps "Done" (which sets the reviewed ID, causing the provider to return null), the screen would try to pop mid-navigation. Instead, use the `_dismiss` method to explicitly navigate back after marking as reviewed.
- **Blocking app usage until review is done:** The review prompt should be non-intrusive. A card on the home screen that the user can ignore is the right UX. Do NOT use a modal dialog or forced flow.
- **Requiring ALL songs to be rated before marking as reviewed:** The user should be able to skip the review entirely or rate only some songs. The "Done" and "Skip" actions both mark the playlist as reviewed.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Song feedback toggle logic | Custom review-specific feedback handling | Reuse `SongTile` widget which already has `_onToggleLike` / `_onToggleDislike` | Same feedback mechanism, same provider, same persistence. Zero duplication. |
| Song display (title, artist, BPM) | Custom review song card | Reuse `SongTile` widget | Consistent look with playlist screen and history detail screen. |
| Song key normalization | Inline string manipulation | `PlaylistSong.lookupKey` (uses `SongKey.normalize`) | Established pattern from decision 22-01. |
| Feedback persistence | Custom save/load for review feedback | Existing `SongFeedbackNotifier.addFeedback/removeFeedback` | Phase 22 built and tested this completely. |
| Reviewed state persistence | Complex JSON structure | Single SharedPreferences string (last reviewed playlist ID) | Only need to track one ID. |

**Key insight:** This phase creates ONE new persistence key (`last_reviewed_playlist_id`), ONE new screen, ONE new provider (plus a derived provider), and ONE new home screen card. Everything else is reuse of existing infrastructure. The heavy lifting (feedback persistence, feedback-to-scoring pipeline, SongTile UI) is all done.

## Common Pitfalls

### Pitfall 1: Playlist History Empty on Cold Start
**What goes wrong:** Home screen checks for unreviewed playlists before `PlaylistHistoryNotifier` has finished loading from SharedPreferences. The prompt never appears on the first frame.
**Why it happens:** `PlaylistHistoryNotifier._load()` is async. On cold start, the state is an empty list until load completes.
**How to avoid:** Two options: (1) Accept a brief flash (the card appears once the provider loads, within milliseconds). (2) Call `ensureLoaded()` pattern if the `PlaylistHistoryNotifier` adds one. Currently it does NOT have `ensureLoaded()` -- it just loads in the constructor. For the home screen, option (1) is acceptable since the screen rebuilds reactively.
**Warning signs:** Review prompt flickers in on first app launch.

### Pitfall 2: Review Screen Watches Provider That Goes Null
**What goes wrong:** The review screen watches `unreviewedPlaylistProvider`. User taps "Done", which calls `markReviewed()`, which updates `postRunReviewProvider`, which causes `unreviewedPlaylistProvider` to return null. The screen rebuilds with null playlist and tries to pop, but navigation is already in progress from the onPressed handler.
**Why it happens:** Reactive state change during navigation.
**How to avoid:** In the `_dismiss` method, navigate FIRST (pop), THEN mark as reviewed. Or: read the playlist once in initState (not watch), so the screen does not rebuild reactively. Or: use a local variable to guard against double-pop. The simplest approach: call `context.pop()` first, then `markReviewed()` in a `Future.microtask`. But actually the cleanest approach is to capture the playlist data locally and not watch the derived provider -- watch `playlistHistoryProvider` directly and use a `ConsumerStatefulWidget` that stores the playlist in `initState`.
**Warning signs:** Double navigation pop, black screen, or "Navigator operation requested with a context that does not include a Navigator" error.

### Pitfall 3: Playlist Has Null ID
**What goes wrong:** The review logic relies on `playlist.id` to track reviewed state. If a playlist has no ID, the review prompt appears forever and cannot be dismissed.
**Why it happens:** The `Playlist` model has `id` as `String?`. Theoretically a playlist could be created without an ID, though the current `PlaylistGenerator` uses `uuid`.
**How to avoid:** In `unreviewedPlaylistProvider`, filter out playlists with null IDs (`if (mostRecent.id == null) return null`). This ensures we only prompt for playlists that can be tracked.
**Warning signs:** Review prompt that never goes away.

### Pitfall 4: Forgetting to Import Review Provider in Home Screen
**What goes wrong:** Home screen doesn't show the review prompt because the `unreviewedPlaylistProvider` wasn't imported or wired.
**Why it happens:** Simple oversight.
**How to avoid:** The planner should have a verification step that checks the home screen renders the review card when conditions are met.
**Warning signs:** Review prompt never appears despite having unreviewed playlists.

### Pitfall 5: Review Feedback Not Affecting Future Generation
**What goes wrong:** User rates songs during review, but the next playlist generation doesn't reflect those ratings.
**Why it happens:** This would only happen if the review screen used a different feedback store than `songFeedbackProvider`. Since we reuse `SongTile` (which uses `songFeedbackProvider`), this is not a risk.
**How to avoid:** Do NOT create a separate feedback mechanism. Reuse `SongTile` and `songFeedbackProvider` exclusively.
**Warning signs:** None if using the shared provider correctly.

## Code Examples

### Home Screen Review Prompt Integration
```dart
// Source: derived from existing HomeScreen pattern (home_screen.dart)
// In HomeScreen.build(), add after the hasPlan section:
final unreviewedPlaylist = ref.watch(unreviewedPlaylistProvider);

// Review prompt card (between quick-regenerate and nav buttons)
if (unreviewedPlaylist != null)
  _SetupCard(
    icon: Icons.rate_review,
    title: 'Rate your last playlist',
    subtitle: '${unreviewedPlaylist.songs.length} songs from '
        '${unreviewedPlaylist.runPlanName ?? "your run"}',
    color: theme.colorScheme.tertiaryContainer,
    onTap: () => context.push('/post-run-review'),
  ),
```

### PostRunReviewPreferences (follows OnboardingPreferences pattern)
```dart
// Source: derived from OnboardingPreferences pattern
class PostRunReviewPreferences {
  static const _key = 'last_reviewed_playlist_id';

  static Future<String?> loadLastReviewedId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> saveLastReviewedId(String playlistId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, playlistId);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
```

### PostRunReviewNotifier (follows SongFeedbackNotifier pattern)
```dart
// Source: derived from SongFeedbackNotifier pattern
class PostRunReviewNotifier extends StateNotifier<String?> {
  PostRunReviewNotifier() : super(null) {
    _load();
  }

  final Completer<void> _loadCompleter = Completer<void>();
  Future<void> ensureLoaded() => _loadCompleter.future;

  Future<void> _load() async {
    try {
      final id = await PostRunReviewPreferences.loadLastReviewedId();
      if (mounted) state = id;
    } finally {
      if (!_loadCompleter.isCompleted) _loadCompleter.complete();
    }
  }

  Future<void> markReviewed(String playlistId) async {
    state = playlistId;
    await PostRunReviewPreferences.saveLastReviewedId(playlistId);
  }
}
```

### Derived Unreviewed Playlist Provider
```dart
// Source: derived from existing provider patterns
final unreviewedPlaylistProvider = Provider<Playlist?>((ref) {
  final playlists = ref.watch(playlistHistoryProvider);
  final lastReviewedId = ref.watch(postRunReviewProvider);

  if (playlists.isEmpty) return null;
  final mostRecent = playlists.first;
  if (mostRecent.id == null) return null;
  if (mostRecent.id == lastReviewedId) return null;

  return mostRecent;
});
```

### Review Screen with SongTile Reuse
```dart
// Source: derived from PlaylistHistoryDetailScreen pattern
class PostRunReviewScreen extends ConsumerWidget {
  const PostRunReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = ref.watch(unreviewedPlaylistProvider);
    if (playlist == null) {
      // Reviewed already or no playlists; navigate back
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Your Playlist'),
        actions: [
          TextButton(
            onPressed: () => _dismiss(context, ref, playlist),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'How did these songs feel during your run?',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: playlist.songs.length,
              itemBuilder: (context, index) =>
                  SongTile(song: playlist.songs[index], index: index + 1),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: () => _dismiss(context, ref, playlist),
                icon: const Icon(Icons.check),
                label: const Text('Done'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _dismiss(BuildContext context, WidgetRef ref, Playlist playlist) {
    if (playlist.id != null) {
      ref.read(postRunReviewProvider.notifier).markReviewed(playlist.id!);
    }
    context.pop();
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Feedback only inline on SongTile during playlist view | Phase 23 added inline feedback, Phase 24 added feedback library | Phase 23-24 (2026-02-08) | Users can rate during generation or browse all feedback |
| No post-run review prompt | Phase 26 adds proactive review prompt on home screen | Current phase | Users prompted to rate songs after a run |

**Deprecated/outdated:**
- `withOpacity()` deprecated in Flutter -- use `withValues(alpha:)` (decision 23-02, already adopted)

## Open Questions

1. **Should the review screen use SongTile or a simpler card?**
   - What we know: SongTile includes external link functionality (Spotify/YouTube bottom sheet tap), BPM chip, star badge, and feedback buttons. In a review context, the external links and BPM may be noise.
   - What's unclear: Whether the extra SongTile features are helpful or distracting in review mode.
   - Recommendation: REUSE SongTile. The consistency benefit outweighs the minor UI noise. Users already know the SongTile interaction pattern from the playlist screen. Building a custom review card duplicates logic and diverges the UX. If the review screen feels cluttered in testing, a simplified variant can be extracted later.

2. **Should the review prompt disappear after a time threshold?**
   - What we know: Success criteria say the prompt disappears after the user completes or dismisses the review. No time-based auto-dismiss is mentioned.
   - What's unclear: Whether showing a review prompt for a week-old playlist is useful.
   - Recommendation: OUT OF SCOPE for this phase. The prompt persists until the user acts on it or generates a new playlist (which creates a new most-recent playlist, causing the prompt to update). Adding time-based dismissal adds complexity for unclear benefit. Can be revisited if users find it annoying.

3. **Should the review screen group songs by segment?**
   - What we know: PlaylistHistoryDetailScreen and PlaylistScreen both group songs by segment using SegmentHeader.
   - Recommendation: YES, include segment headers. It helps the user remember which songs played during which part of their run. Reuse the existing `SegmentHeader` widget.

## Sources

### Primary (HIGH confidence)
- `/Users/tijmen/running-playlist-ai/lib/features/playlist/providers/playlist_history_providers.dart` -- PlaylistHistoryNotifier, newest-first ordering
- `/Users/tijmen/running-playlist-ai/lib/features/playlist/domain/playlist.dart` -- Playlist model with id, songs, runPlanName, createdAt; PlaylistSong.lookupKey
- `/Users/tijmen/running-playlist-ai/lib/features/song_feedback/providers/song_feedback_providers.dart` -- SongFeedbackNotifier, addFeedback/removeFeedback
- `/Users/tijmen/running-playlist-ai/lib/features/song_feedback/domain/song_feedback.dart` -- SongFeedback model, SongKey.normalize
- `/Users/tijmen/running-playlist-ai/lib/features/playlist/presentation/widgets/song_tile.dart` -- SongTile with feedback toggle logic
- `/Users/tijmen/running-playlist-ai/lib/features/playlist/presentation/playlist_history_detail_screen.dart` -- Pattern for displaying a full playlist with segment headers
- `/Users/tijmen/running-playlist-ai/lib/features/home/presentation/home_screen.dart` -- HomeScreen layout, _SetupCard pattern, conditional card rendering
- `/Users/tijmen/running-playlist-ai/lib/app/router.dart` -- Router pattern for adding new routes
- `/Users/tijmen/running-playlist-ai/lib/features/onboarding/data/onboarding_preferences.dart` -- Simple SharedPreferences persistence pattern
- `/Users/tijmen/running-playlist-ai/lib/features/playlist_freshness/providers/playlist_freshness_providers.dart` -- Completer-based ensureLoaded pattern for StateNotifier
- `/Users/tijmen/running-playlist-ai/lib/features/playlist/providers/playlist_providers.dart` -- Playlist generation flow, auto-save to history

### Secondary (MEDIUM confidence)
- Prior phase decisions (22-01, 23-02, 24-01, 25-01, 25-02) -- design constraints and UI patterns
- Phase 24 research document -- feedback library architecture patterns (tabbed views, derived lists)

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- zero new dependencies; all patterns verified from existing codebase
- Architecture: HIGH -- all patterns derived from reading actual codebase files; review state tracking follows established SharedPreferences pattern; SongTile reuse verified by reading the widget source
- Pitfalls: HIGH -- identified from reading actual codebase (async loading races from PlaylistHistoryNotifier, reactive navigation from unreviewedPlaylistProvider, null playlist ID edge case from Playlist model)
- Data layer completeness: HIGH -- verified all needed operations exist in SongFeedbackNotifier and PlaylistHistoryNotifier; only new persistence is a single string key

**Research date:** 2026-02-08
**Valid until:** 2026-03-08 (30 days -- stable internal patterns, no external dependencies)
