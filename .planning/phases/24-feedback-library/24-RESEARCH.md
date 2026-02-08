# Phase 24: Feedback Library - Research

**Researched:** 2026-02-08
**Domain:** Flutter UI (tabbed list screen, feedback state mutation), Riverpod state management, go_router navigation
**Confidence:** HIGH

## Summary

Phase 24 creates a dedicated screen where users can browse all their song feedback decisions and modify them. The data layer (Phase 22) and feedback UI + scoring pipeline (Phase 23) are fully built. This phase is purely a presentation-layer task: a new screen that reads from and writes to the existing `songFeedbackProvider`.

The screen needs two views -- liked songs and disliked songs -- which maps naturally to Flutter's `TabBar`/`TabBarView` pattern (or a simpler `SegmentedButton` toggle). Each song entry needs: song title, artist name, feedback date, and action buttons to flip the feedback state (like-to-dislike, dislike-to-like) or remove it entirely. The `SongFeedback` domain model already stores `songTitle`, `songArtist`, `feedbackDate`, and `isLiked`, so all display data is available without any data layer changes.

The existing `SongFeedbackNotifier` already provides `addFeedback()` (which can update/overwrite) and `removeFeedback()`. Changing a liked song to disliked is simply calling `addFeedback()` with a new `SongFeedback` where `isLiked: false` (using the existing `copyWith` method). Removing feedback entirely uses `removeFeedback()`. No new provider methods are needed.

**Primary recommendation:** Create a single `SongFeedbackLibraryScreen` as a `ConsumerWidget` with a `TabBar` for Liked/Disliked views. Each tab shows a `ListView` of feedback entries with action buttons. Wire into `go_router` at `/song-feedback` and add a navigation button on the home screen. No data layer or provider changes needed -- this is a read + mutate screen on existing state.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_riverpod | ^2.6.1 | Reactive state from songFeedbackProvider | Already in pubspec, used by all features |
| go_router | ^17.0.1 | Navigation to the new screen | Already in pubspec, router pattern established |
| flutter/material.dart | (SDK) | TabBar, TabBarView, ListTile, IconButton | Material 3 widgets, consistent with existing screens |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_test | (SDK) | Widget and unit testing | All tests for the new screen |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| TabBar with two tabs | SegmentedButton toggle | SegmentedButton is simpler for two options but TabBar is more conventional for list-switching and consistent with Material 3 patterns. TabBar also scales if a third category is added later (e.g., "All"). |
| Full-screen library | Bottom sheet from home | Bottom sheet limits vertical space for long lists. A full screen is better for potentially hundreds of feedback entries. |
| Separate liked/disliked screens | Single screen with tabs | Two screens would require two routes and duplicate layout code. Tabs are cleaner. |

**Installation:** No new dependencies needed.

## Architecture Patterns

### Recommended Project Structure
```
lib/features/
  song_feedback/
    presentation/
      song_feedback_library_screen.dart  # NEW: tabbed list screen
    domain/
      song_feedback.dart                 # READ ONLY: SongFeedback model already has all fields
    data/
      song_feedback_preferences.dart     # READ ONLY: persistence already built
    providers/
      song_feedback_providers.dart       # READ ONLY: notifier already has addFeedback/removeFeedback
lib/app/
  router.dart                            # MODIFY: add /song-feedback route
lib/features/home/presentation/
  home_screen.dart                       # MODIFY: add navigation button to feedback library
```

### Pattern 1: Derived Lists from Feedback Map
**What:** Compute liked and disliked lists reactively from the feedback map state
**When to use:** The feedback provider stores a `Map<String, SongFeedback>`. The UI needs two separate `List<SongFeedback>` (liked and disliked), sorted by feedback date.
**Key insight:** Do NOT create new providers for liked/disliked lists. Derive them inline in the widget build method from `ref.watch(songFeedbackProvider)`. This keeps the state source singular and avoids sync issues.
**Example:**
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final feedbackMap = ref.watch(songFeedbackProvider);
  final allFeedback = feedbackMap.values.toList();

  final liked = allFeedback
      .where((f) => f.isLiked)
      .toList()
    ..sort((a, b) => b.feedbackDate.compareTo(a.feedbackDate));

  final disliked = allFeedback
      .where((f) => !f.isLiked)
      .toList()
    ..sort((a, b) => b.feedbackDate.compareTo(a.feedbackDate));

  // ... TabBar with liked.length and disliked.length in tab labels
}
```

### Pattern 2: Feedback Mutation Actions
**What:** Three actions per feedback entry: flip to opposite, remove entirely
**When to use:** FEED-06 requires users to change or remove feedback
**Key insight:** The existing `SongFeedbackNotifier` already supports all needed operations. `addFeedback()` with a new `SongFeedback` using `copyWith(isLiked: !current.isLiked)` flips the state. `removeFeedback(songKey)` removes it entirely. Both optimistically update state and persist.
**Example:**
```dart
// Flip feedback (like -> dislike or dislike -> like)
void _onFlipFeedback(WidgetRef ref, SongFeedback feedback) {
  final notifier = ref.read(songFeedbackProvider.notifier);
  notifier.addFeedback(feedback.copyWith(
    isLiked: !feedback.isLiked,
    feedbackDate: DateTime.now(),
  ));
}

// Remove feedback entirely
void _onRemoveFeedback(WidgetRef ref, SongFeedback feedback) {
  final notifier = ref.read(songFeedbackProvider.notifier);
  notifier.removeFeedback(feedback.songKey);
}
```

### Pattern 3: TabBar in Scaffold (Existing Codebase Pattern)
**What:** Use `DefaultTabController` + `TabBar` in AppBar + `TabBarView` in body
**When to use:** This screen has exactly two views (Liked/Disliked) to switch between
**Key detail:** The screen must use `ConsumerStatefulWidget` with `SingleTickerProviderStateMixin` if it needs to control the tab controller, OR use `DefaultTabController` wrapping the Scaffold for simplicity. Since no programmatic tab switching is needed, `DefaultTabController` is simpler and avoids the stateful widget complexity.
**Example:**
```dart
class SongFeedbackLibraryScreen extends ConsumerWidget {
  const SongFeedbackLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedbackMap = ref.watch(songFeedbackProvider);
    // ... derive liked/disliked lists ...

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Song Feedback'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Liked (${liked.length})'),
              Tab(text: 'Disliked (${disliked.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _FeedbackListView(items: liked, ...),
            _FeedbackListView(items: disliked, ...),
          ],
        ),
      ),
    );
  }
}
```

### Pattern 4: Feedback Card Widget
**What:** A reusable card showing song info and action buttons for each feedback entry
**When to use:** Used in both the liked and disliked tab views
**Key design decisions from prior phases:**
- Use compact icon buttons (32x32 with 18px icons), matching decision 23-02
- Use `withValues(alpha:)` instead of deprecated `withOpacity`, matching decision 23-02
- Match the card styling from existing library screens (Card with surfaceContainerLow, borderRadius 12)
**Example:**
```dart
class _FeedbackCard extends StatelessWidget {
  final SongFeedback feedback;
  final VoidCallback onFlip;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Feedback type icon (thumb_up or thumb_down, colored)
            Icon(
              feedback.isLiked ? Icons.thumb_up : Icons.thumb_down,
              color: feedback.isLiked
                  ? Colors.green
                  : theme.colorScheme.error,
              size: 20,
            ),
            const SizedBox(width: 12),
            // Song info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(feedback.songTitle, ...),
                  Text(feedback.songArtist, ...),
                ],
              ),
            ),
            // Flip action
            IconButton(
              icon: Icon(feedback.isLiked
                  ? Icons.thumb_down_outlined
                  : Icons.thumb_up_outlined),
              tooltip: feedback.isLiked ? 'Change to dislike' : 'Change to like',
              onPressed: onFlip,
            ),
            // Remove action
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Remove feedback',
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
```

### Pattern 5: Router Registration (Established Pattern)
**What:** Add a new GoRoute for the feedback library screen
**When to use:** Required for navigation
**Example:**
```dart
// In router.dart, add alongside existing routes:
GoRoute(
  path: '/song-feedback',
  builder: (context, state) => const SongFeedbackLibraryScreen(),
),
```

### Pattern 6: Home Screen Navigation Button (Established Pattern)
**What:** Add a button to the home screen for navigating to the feedback library
**When to use:** FEED-05 requires users to be able to navigate to the feedback library
**Key design:** Follow the existing pattern of `ElevatedButton.icon` with `context.push('/song-feedback')`. Place it near the "Playlist History" button since both are review/management screens.
**Example:**
```dart
ElevatedButton.icon(
  onPressed: () => context.push('/song-feedback'),
  icon: const Icon(Icons.thumb_up_alt_outlined),
  label: const Text('Song Feedback'),
),
```

### Anti-Patterns to Avoid
- **Creating separate providers for liked/disliked lists:** The feedback map is the single source of truth. Deriving lists inline avoids sync issues and extra provider complexity. The map will be small (hundreds of entries at most), so filtering is O(n) and instant.
- **Mutating state without going through the notifier:** Always use `ref.read(songFeedbackProvider.notifier).addFeedback()` or `.removeFeedback()`. Never modify the map directly.
- **Using Dismissible for remove actions:** The existing library screens (TasteProfileLibrary, RunPlanLibrary) use explicit delete buttons, not swipe-to-dismiss. Follow the same pattern for consistency. Feedback entries are small enough that explicit buttons are more discoverable.
- **Confirmation dialog for every action:** Feedback changes are lightweight and reversible (user can flip back). Adding confirmation dialogs for every like/dislike/remove adds friction without value. Reserve confirmation for destructive-only actions like "clear all feedback".

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Song feedback persistence | Custom save/load | Existing `SongFeedbackNotifier.addFeedback/removeFeedback` | Phase 22 built and tested this. Handles optimistic update + persistence. |
| Song key normalization | Inline string manipulation | `SongKey.normalize()` and `SongFeedback.songKey` | Already standardized in Phase 22. All feedback entries already have correct keys. |
| Liked/disliked filtering | Separate providers or StateNotifiers | Inline `where()` filter in widget build | The map is small, filtering is trivial. Extra providers add complexity for no benefit. |
| Tab switching UI | Custom toggle widget | `DefaultTabController` + `TabBar` + `TabBarView` | Standard Flutter Material 3 pattern. No reason to build custom. |
| Feedback state changes | New notifier methods | Existing `addFeedback(feedback.copyWith(...))` and `removeFeedback(key)` | copyWith already exists on SongFeedback. The notifier already supports updates by overwriting the same key. |

**Key insight:** This phase needs ZERO changes to the data layer or providers. The `SongFeedbackNotifier` already has every operation needed (add, update via add, remove, getFeedback). The `SongFeedback` model already has `copyWith`, display fields (`songTitle`, `songArtist`), and date tracking. This is purely a new screen that reads and mutates existing state.

## Common Pitfalls

### Pitfall 1: Forgetting ensureLoaded() Before First Read
**What goes wrong:** The feedback library shows empty on app cold start even though the user has feedback.
**Why it happens:** `SongFeedbackNotifier` loads from SharedPreferences asynchronously. On cold start, the map may not be populated yet.
**How to avoid:** The screen watches `songFeedbackProvider`, which triggers the notifier constructor and load. However, the initial build may see an empty map. Two options: (1) Accept the brief empty flash since the state updates reactively within milliseconds, or (2) call `ensureLoaded()` in an initState/FutureBuilder pattern. Option 1 is acceptable because the list will populate immediately on the next frame.
**Warning signs:** Empty library screen on first navigation that populates a moment later.

### Pitfall 2: List Item Key Conflicts After State Change
**What goes wrong:** Flipping a song from liked to disliked causes the list to re-render incorrectly or show stale items.
**Why it happens:** The song moves from one tab to another. If the ListView uses index-based keys, the item at the same index in the new list may reuse the old widget's state.
**How to avoid:** Use `songKey` as the `ValueKey` for each list item. This ensures correct widget identity across state changes.
**Warning signs:** Wrong song title/artist shown after flipping, or animation glitches.

### Pitfall 3: Empty State for Individual Tabs
**What goes wrong:** User sees a blank white screen in the "Disliked" tab when they have no disliked songs.
**Why it happens:** The ListView is empty but no empty state message is shown.
**How to avoid:** Show a centered message like "No disliked songs yet" when the filtered list is empty. Follow the empty state pattern from `_EmptyHistoryView` in `playlist_history_screen.dart`.
**Warning signs:** Blank white screen in a tab.

### Pitfall 4: TabBar Count Badge Reactivity
**What goes wrong:** The tab labels show stale counts (e.g., "Liked (5)" after removing one, still showing 5).
**Why it happens:** The counts in tab labels must be derived from the watched state inside the build method, not cached separately.
**How to avoid:** Compute counts inline from the watched `feedbackMap` inside the build method. Since `DefaultTabController` wraps the entire Scaffold, the counts will update reactively when state changes.
**Warning signs:** Tab counts don't update after add/remove/flip operations.

### Pitfall 5: Breaking the Feedback Pipeline
**What goes wrong:** Changes made in the feedback library don't take effect in the next playlist generation.
**Why it happens:** This would only happen if the library screen used a different state store than the one `PlaylistGenerationNotifier` reads. Since both use `songFeedbackProvider`, this is not a risk.
**How to avoid:** Use `ref.read(songFeedbackProvider.notifier)` for all mutations, exactly as `SongTile` does. The `PlaylistGenerationNotifier` reads from the same provider, so changes propagate automatically.
**Warning signs:** None if using the shared provider correctly.

## Code Examples

### Complete Screen Scaffold Pattern
```dart
// Source: derived from existing codebase patterns (TasteProfileLibraryScreen, RunPlanLibraryScreen)
class SongFeedbackLibraryScreen extends ConsumerWidget {
  const SongFeedbackLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedbackMap = ref.watch(songFeedbackProvider);
    final allFeedback = feedbackMap.values.toList();

    final liked = allFeedback
        .where((f) => f.isLiked)
        .toList()
      ..sort((a, b) => b.feedbackDate.compareTo(a.feedbackDate));

    final disliked = allFeedback
        .where((f) => !f.isLiked)
        .toList()
      ..sort((a, b) => b.feedbackDate.compareTo(a.feedbackDate));

    if (allFeedback.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Song Feedback')),
        body: _EmptyFeedbackView(),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Song Feedback'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Liked (${liked.length})'),
              Tab(text: 'Disliked (${disliked.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _FeedbackListView(items: liked, ref: ref),
            _FeedbackListView(items: disliked, ref: ref),
          ],
        ),
      ),
    );
  }
}
```

### Flipping Feedback State with copyWith
```dart
// Source: SongFeedback.copyWith exists (song_feedback.dart line 88-100)
void _onFlipFeedback(WidgetRef ref, SongFeedback feedback) {
  ref.read(songFeedbackProvider.notifier).addFeedback(
    feedback.copyWith(
      isLiked: !feedback.isLiked,
      feedbackDate: DateTime.now(),
    ),
  );
}
```

### Removing Feedback
```dart
// Source: SongFeedbackNotifier.removeFeedback (song_feedback_providers.dart line 45-48)
void _onRemoveFeedback(WidgetRef ref, SongFeedback feedback) {
  ref.read(songFeedbackProvider.notifier).removeFeedback(feedback.songKey);
}
```

### Empty State Widget (follows existing pattern)
```dart
// Source: pattern from _EmptyHistoryView in playlist_history_screen.dart
class _EmptyFeedbackView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.thumbs_up_down, size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text(
              'No Feedback Yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Like or dislike songs in your playlists to build your feedback library.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
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
| No feedback browsing | Feedback visible only inline on SongTile in playlist views | Phase 23 (2026-02-08) | Users can only see feedback on songs they encounter in generated playlists |
| N/A | This phase adds dedicated feedback library screen | Phase 24 | Users can browse and manage ALL feedback in one place |

**Deprecated/outdated:**
- `withOpacity()` deprecated in Flutter -- use `withValues(alpha:)` (decision 23-02, already adopted)

## Open Questions

1. **Should there be a "Clear All Feedback" action?**
   - What we know: The requirements (FEED-05, FEED-06) don't mention bulk actions. `SongFeedbackPreferences.clear()` exists.
   - What's unclear: Whether a "clear all" button adds value or is a dangerous footgun.
   - Recommendation: OUT OF SCOPE for this phase. Individual removal satisfies FEED-06. A bulk clear could be added later if needed but risks accidental data loss. The `clear()` method exists in the data layer if needed later.

2. **Should the feedback library show the song's BPM?**
   - What we know: `SongFeedback` does not store BPM. It stores `songKey`, `isLiked`, `feedbackDate`, `songTitle`, `songArtist`, and `genre`.
   - What's unclear: Whether BPM is valuable in the feedback context.
   - Recommendation: NO. BPM is a playlist-context property, not a song-context property. The library shows feedback decisions, not playlist details. Adding BPM would require storing it in `SongFeedback`, which changes the data model for no clear benefit.

3. **Should the screen show when the feedback was given?**
   - What we know: `SongFeedback.feedbackDate` exists and is persisted.
   - Recommendation: YES, show a relative or formatted date as a subtitle. This helps users understand their feedback history (e.g., "liked 2 days ago" vs "liked today"). Use a simple date format like "dd/MM/yyyy" consistent with playlist history.

## Sources

### Primary (HIGH confidence)
- `/Users/tijmen/running-playlist-ai/lib/features/song_feedback/domain/song_feedback.dart` -- SongFeedback model with copyWith, all display fields
- `/Users/tijmen/running-playlist-ai/lib/features/song_feedback/providers/song_feedback_providers.dart` -- SongFeedbackNotifier with addFeedback, removeFeedback, getFeedback
- `/Users/tijmen/running-playlist-ai/lib/features/song_feedback/data/song_feedback_preferences.dart` -- Persistence layer (no changes needed)
- `/Users/tijmen/running-playlist-ai/lib/features/taste_profile/presentation/taste_profile_library_screen.dart` -- Library screen pattern (Card styling, empty state, layout)
- `/Users/tijmen/running-playlist-ai/lib/features/run_plan/presentation/run_plan_library_screen.dart` -- Library screen pattern (Card styling, delete actions)
- `/Users/tijmen/running-playlist-ai/lib/features/playlist/presentation/playlist_history_screen.dart` -- Empty state pattern, date formatting
- `/Users/tijmen/running-playlist-ai/lib/features/playlist/presentation/widgets/song_tile.dart` -- Feedback icon patterns, toggle logic
- `/Users/tijmen/running-playlist-ai/lib/app/router.dart` -- Router pattern for adding new routes
- `/Users/tijmen/running-playlist-ai/lib/features/home/presentation/home_screen.dart` -- Navigation button pattern
- `/Users/tijmen/running-playlist-ai/test/features/song_feedback/song_feedback_lifecycle_test.dart` -- Existing test patterns for feedback operations

### Secondary (MEDIUM confidence)
- Phase 22 and 23 research, plans, and verification documents -- confirmed data layer completeness and UI patterns
- Prior decisions 22-01, 22-02, 23-01, 23-02 -- design constraints to follow

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - zero new dependencies, all existing in pubspec
- Architecture: HIGH - all patterns derived from reading actual codebase files; TabBar/TabBarView is standard Flutter, no external research needed
- Pitfalls: HIGH - identified from reading actual codebase patterns and prior phase pitfall documentation
- Data layer completeness: HIGH - verified all needed operations exist in SongFeedbackNotifier (addFeedback for update, removeFeedback for delete, state map for reads)

**Research date:** 2026-02-08
**Valid until:** 2026-03-08 (stable internal patterns, no external dependencies)
