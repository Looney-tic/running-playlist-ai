# Phase 15: Playlist History - Research

**Researched:** 2026-02-05
**Domain:** Local persistence of generated playlists, list/detail UI, SharedPreferences collection patterns
**Confidence:** HIGH

## Summary

This phase adds the ability to save, list, view, and delete previously generated playlists. The codebase already has all foundational pieces in place: the `Playlist` model has complete `toJson`/`fromJson` serialization, the router has a `/playlist-history` placeholder route, the home screen has a navigation button, and the project follows consistent SharedPreferences + StateNotifier patterns.

The main technical decisions are: (1) storage key strategy for multiple playlists, (2) adding a unique ID to each playlist for identification, (3) auto-save after generation vs. manual save, (4) routing for the detail screen, and (5) delete UX.

**Primary recommendation:** Use a single SharedPreferences key holding a JSON-encoded list of playlist objects (not prefix-per-playlist). Add a unique `id` field to `Playlist` (timestamp-based, no external package needed). Auto-save upon generation. Use `go_router` path parameter `/playlist-history/:id` for the detail screen. Implement swipe-to-delete with `Dismissible` plus confirmation `SnackBar` undo.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| shared_preferences | ^2.5.4 | Persist playlist history | Already used for all local persistence in this app |
| flutter_riverpod | ^2.6.1 | State management (StateNotifier) | Already used for all providers |
| go_router | ^17.0.1 | Navigation with path parameters | Already used for all routing |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| (none needed) | - | - | No new dependencies required for this phase |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SharedPreferences (single key) | SharedPreferences (prefix-per-entry) | Prefix pattern used for BPM cache, but single-key-list is simpler for bounded collections; prefix requires key enumeration to load all entries |
| SharedPreferences | sqflite/drift | Over-engineered for <100 playlists; would break consistency with rest of app |
| Timestamp-based ID | uuid package | Adds dependency; timestamp + hashCode is sufficient for local-only IDs |
| Dismissible swipe | flutter_slidable package | Adds dependency; Dismissible is built-in and sufficient for delete-only action |

**Installation:**
```bash
# No new packages needed
```

## Architecture Patterns

### Recommended Project Structure
```
lib/features/playlist/
  domain/
    playlist.dart            # MODIFY: add `id`, `distanceKm`, `paceMinPerKm` fields
  data/
    playlist_history_preferences.dart  # NEW: static persistence class
  providers/
    playlist_providers.dart  # MODIFY: add auto-save hook after generation
    playlist_history_providers.dart    # NEW: PlaylistHistoryNotifier + provider
  presentation/
    playlist_screen.dart     # EXISTING (no changes needed)
    playlist_history_screen.dart       # NEW: history list screen
    playlist_history_detail_screen.dart # NEW: detail screen (reuses _PlaylistView pattern)
```

### Pattern 1: Single-Key List Storage (for Bounded Collections)
**What:** Store the entire list of playlists as a single JSON-encoded string under one SharedPreferences key.
**When to use:** When the collection is bounded (max ~50-100 items) and always loaded/saved as a whole.
**Why this over prefix-per-entry:** The BPM cache uses prefix-per-entry (`bpm_cache_170`, `bpm_cache_85`) because entries are accessed individually by BPM. Playlist history is always loaded as a full list for display and never accessed by a single key, making single-key-list the better fit.

```dart
// Source: Follows TasteProfilePreferences pattern (single key)
class PlaylistHistoryPreferences {
  static const _key = 'playlist_history';

  static Future<List<Playlist>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return null;
    final list = jsonDecode(jsonString) as List<dynamic>;
    return list
        .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> save(List<Playlist> playlists) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(playlists.map((p) => p.toJson()).toList());
    await prefs.setString(_key, jsonString);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
```

### Pattern 2: StateNotifier for List State
**What:** A StateNotifier that manages `List<Playlist>` state, loads from preferences on init, and provides add/delete mutations.
**When to use:** For any provider-managed persisted collection.

```dart
class PlaylistHistoryNotifier extends StateNotifier<List<Playlist>> {
  PlaylistHistoryNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final playlists = await PlaylistHistoryPreferences.load();
    if (playlists != null) {
      state = playlists;
    }
  }

  Future<void> addPlaylist(Playlist playlist) async {
    // Prepend (newest first)
    state = [playlist, ...state];
    await PlaylistHistoryPreferences.save(state);
  }

  Future<void> deletePlaylist(String id) async {
    state = state.where((p) => p.id != id).toList();
    await PlaylistHistoryPreferences.save(state);
  }
}
```

### Pattern 3: Auto-Save After Generation
**What:** When `PlaylistGenerationNotifier` transitions to the `loaded` state, automatically save the playlist to history.
**When to use:** To ensure every generated playlist is saved without user action.
**How:** The `PlaylistGenerationNotifier` already has access to `Ref`. After setting `state = PlaylistGenerationState.loaded(playlist)`, call `ref.read(playlistHistoryProvider.notifier).addPlaylist(playlist)`.

```dart
// In PlaylistGenerationNotifier.generatePlaylist(), after successful generation:
if (!mounted) return;
state = PlaylistGenerationState.loaded(playlist);

// Auto-save to history
ref.read(playlistHistoryProvider.notifier).addPlaylist(playlist);
```

### Pattern 4: go_router Path Parameter for Detail Screen
**What:** Use `/playlist-history/:id` route with path parameter to navigate to a specific playlist.
**When to use:** For deep-linkable detail screens.

```dart
// In router.dart
GoRoute(
  path: '/playlist-history',
  builder: (context, state) => const PlaylistHistoryScreen(),
  routes: [
    GoRoute(
      path: ':id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return PlaylistHistoryDetailScreen(playlistId: id);
      },
    ),
  ],
),
```

Navigation: `context.push('/playlist-history/$playlistId')`

Note: In go_router 17, path parameters are accessed via `state.pathParameters['key']` (not the older `state.params['key']`).

### Anti-Patterns to Avoid
- **Using `extra` for detail navigation:** `extra` is lost on browser back navigation and deep links. Use path parameter with ID instead.
- **Prefix-per-playlist in SharedPreferences:** Would require `getKeys().where(...)` enumeration to load all entries. The collection is always loaded as a whole, so single-key is cleaner.
- **Storing Playlist without ID:** Without a stable identifier, deletion and navigation become fragile (index-based, which shifts).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Swipe-to-delete | Custom gesture detector | Flutter's built-in `Dismissible` widget | Handles animation, direction, background, callbacks out of the box |
| Unique IDs | Complex UUID generation | `DateTime.now().millisecondsSinceEpoch.toString()` | Local-only; no collision risk at human interaction speeds; no new dependency |
| Delete confirmation | Custom overlay/dialog | `Dismissible` + `ScaffoldMessenger.showSnackBar` with undo action | Standard Material pattern; simpler than AlertDialog for single-action operations |
| List empty state | Complex conditional logic | Simple `state.isEmpty` check with centered message widget | Follow existing `_NoRunPlanView` pattern from playlist_screen.dart |

**Key insight:** This phase is primarily CRUD with existing patterns. Every piece (persistence, state management, routing, list UI) has a direct precedent in the codebase. The risk is over-engineering, not under-engineering.

## Common Pitfalls

### Pitfall 1: SharedPreferences Size with Many Playlists
**What goes wrong:** If a user generates hundreds of playlists over months, the single JSON string could grow large.
**Why it happens:** Each playlist contains 5-15 songs with full metadata (title, artist, BPM, URLs, segment info). Estimated ~500-800 bytes per song, ~5-10 KB per playlist. 50 playlists = ~250-500 KB. Well within SharedPreferences practical limits (safe up to ~1 MB).
**How to avoid:** Cap history at 50 playlists. When adding, trim oldest entries if over limit. This is a simple guard, not an urgent concern.
**Warning signs:** If a single SharedPreferences key exceeds ~500 KB, loading becomes noticeably slow on older devices.

### Pitfall 2: Race Condition Between Generation and History Load
**What goes wrong:** `PlaylistHistoryNotifier._load()` is async. If `addPlaylist()` is called before `_load()` completes, the newly added playlist could be overwritten by the stale loaded state.
**Why it happens:** StateNotifier constructor starts async load, but callers can invoke mutations before load finishes.
**How to avoid:** Use a `Completer` or `_loaded` flag to ensure `addPlaylist` awaits initial load. Or simpler: since auto-save happens after user navigates to playlist screen and generation completes (seconds of interaction), the history notifier will have already loaded by then. Document this assumption.
**Warning signs:** Playlists disappearing from history after app restart.

### Pitfall 3: Playlist Model Changes Breaking Existing Saved Data
**What goes wrong:** Adding new fields (`id`, `distanceKm`, `paceMinPerKm`) to Playlist changes the JSON schema. Previously saved playlists (if any) would lack these fields.
**Why it happens:** No versioning in serialization.
**How to avoid:** Make all new fields nullable or provide defaults in `fromJson`. Since this is the first phase to actually save playlists, there is no pre-existing data to migrate. Still, make `id` nullable in `fromJson` and generate one if missing (defensive).
**Warning signs:** `fromJson` throwing exceptions on load.

### Pitfall 4: Regenerating Overwrites vs. Creates New Entry
**What goes wrong:** User generates playlist, it auto-saves. User taps "Regenerate" on the playlist screen, a new playlist auto-saves. Now they have two entries for the same run plan.
**Why it happens:** Each generation creates a new Playlist with a new `createdAt` and `id`.
**How to avoid:** This is actually desirable behavior -- each generation is a unique playlist. The user may want to compare different generations. If history grows too large, the cap (Pitfall 1) handles it.

### Pitfall 5: Forgetting to Pass Run Plan Metadata to Playlist
**What goes wrong:** The history list needs to show distance and pace for each saved playlist, but `Playlist` currently only stores `runPlanName` and `totalDurationSeconds`.
**Why it happens:** `Playlist` was designed for display, not for history context.
**How to avoid:** Add `distanceKm` and `paceMinPerKm` fields to `Playlist` model. Set them in `PlaylistGenerator.generate()` from the `RunPlan` input.

## Code Examples

### Adding ID and Run Metadata to Playlist Model
```dart
// In playlist.dart - add fields to Playlist class
class Playlist {
  const Playlist({
    required this.songs,
    required this.totalDurationSeconds,
    required this.createdAt,
    this.id,
    this.runPlanName,
    this.distanceKm,
    this.paceMinPerKm,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String?,
      songs: (json['songs'] as List<dynamic>)
          .map((s) => PlaylistSong.fromJson(s as Map<String, dynamic>))
          .toList(),
      totalDurationSeconds: (json['totalDurationSeconds'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      runPlanName: json['runPlanName'] as String?,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      paceMinPerKm: (json['paceMinPerKm'] as num?)?.toDouble(),
    );
  }

  final String? id;  // Timestamp-based unique ID
  final List<PlaylistSong> songs;
  final String? runPlanName;
  final int totalDurationSeconds;
  final DateTime createdAt;
  final double? distanceKm;
  final double? paceMinPerKm;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'songs': songs.map((s) => s.toJson()).toList(),
        'totalDurationSeconds': totalDurationSeconds,
        'createdAt': createdAt.toIso8601String(),
        'runPlanName': runPlanName,
        if (distanceKm != null) 'distanceKm': distanceKm,
        if (paceMinPerKm != null) 'paceMinPerKm': paceMinPerKm,
      };
}
```

### ID Generation in PlaylistGenerator
```dart
// In playlist_generator.dart, in the generate() method return:
return Playlist(
  id: DateTime.now().millisecondsSinceEpoch.toString(),
  songs: allPlaylistSongs,
  runPlanName: runPlan.name,
  totalDurationSeconds: runPlan.totalDurationSeconds,
  createdAt: DateTime.now(),
  distanceKm: runPlan.distanceKm,
  paceMinPerKm: runPlan.paceMinPerKm,
);
```

### History List Screen (Simplified)
```dart
// Follows HomeScreen and PlaylistScreen widget patterns
class PlaylistHistoryScreen extends ConsumerWidget {
  const PlaylistHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Playlist History')),
      body: playlists.isEmpty
          ? const _EmptyHistoryView()
          : ListView.builder(
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                return Dismissible(
                  key: Key(playlist.id ?? index.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    ref
                        .read(playlistHistoryProvider.notifier)
                        .deletePlaylist(playlist.id!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Playlist deleted')),
                    );
                  },
                  child: ListTile(
                    title: Text(playlist.runPlanName ?? 'Untitled Run'),
                    subtitle: Text(_formatSubtitle(playlist)),
                    trailing: Text(
                      '${playlist.songs.length} songs',
                    ),
                    onTap: () => context.push(
                      '/playlist-history/${playlist.id}',
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _formatSubtitle(Playlist playlist) {
    final date = playlist.createdAt.toLocal();
    final dateStr = '${date.day}/${date.month}/${date.year}';
    final parts = <String>[dateStr];
    if (playlist.distanceKm != null) {
      parts.add('${playlist.distanceKm!.toStringAsFixed(1)} km');
    }
    if (playlist.paceMinPerKm != null) {
      final mins = playlist.paceMinPerKm!.floor();
      final secs = ((playlist.paceMinPerKm! - mins) * 60).round();
      parts.add("$mins'${secs.toString().padLeft(2, '0')}\"/km");
    }
    return parts.join(' - ');
  }
}
```

### Detail Screen Reusing Playlist Song Display Pattern
```dart
// Reuses _SegmentHeader and _SongTile patterns from playlist_screen.dart
// but as a read-only view (no Regenerate button)
class PlaylistHistoryDetailScreen extends ConsumerWidget {
  const PlaylistHistoryDetailScreen({
    required this.playlistId,
    super.key,
  });

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistHistoryProvider);
    final playlist = playlists.where((p) => p.id == playlistId).firstOrNull;

    if (playlist == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Playlist')),
        body: const Center(child: Text('Playlist not found')),
      );
    }

    // Reuse the same segment-grouped list view pattern
    // from PlaylistScreen's _PlaylistView
    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.runPlanName ?? 'Playlist'),
        actions: [
          IconButton(
            onPressed: () => _copyPlaylist(context, playlist),
            icon: const Icon(Icons.copy),
            tooltip: 'Copy to clipboard',
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary header with date, distance, pace
          _PlaylistSummaryHeader(playlist: playlist),
          const Divider(),
          // Song list (same grouped-by-segment pattern)
          Expanded(
            child: ListView.builder(
              itemCount: playlist.songs.length,
              itemBuilder: (context, index) {
                // ... same segment header + song tile pattern
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `state.params['key']` | `state.pathParameters['key']` | go_router 7+ | Use `pathParameters` in go_router 17 |
| Manual JSON string manipulation | `jsonEncode`/`jsonDecode` with model `toJson`/`fromJson` | Stable | Already in use throughout codebase |
| `SharedPreferences.setStringList` | `setString` with JSON-encoded list | Preference | `setString` with JSON is more flexible for nested objects |

**Deprecated/outdated:**
- `GoRouterState.params` was renamed to `GoRouterState.pathParameters` in go_router 7+. The app uses go_router 17 so use `pathParameters`.
- `GoRouterState.queryParams` was renamed to `GoRouterState.uri.queryParameters`.

## Open Questions

1. **Should `_PlaylistView` and `_SongTile` be extracted as shared widgets?**
   - What we know: The detail screen will display songs identically to the generation screen. Both use segment headers + song tiles with Spotify/YouTube links.
   - What's unclear: Whether to extract into shared widgets (more DRY) or duplicate the code (more independence).
   - Recommendation: Extract `SegmentHeader` and `SongTile` into `lib/features/playlist/presentation/widgets/` as public widgets. Both screens import them. This avoids duplicating ~100 lines of UI code.

2. **Should undo be supported on delete?**
   - What we know: The `Dismissible` widget removes the item immediately from the list. An undo `SnackBar` would need to temporarily hold the deleted playlist.
   - What's unclear: Whether the UX complexity of undo is worth it for v1.
   - Recommendation: For v1, use `confirmDismiss` with a simple `showDialog` AlertDialog ("Delete this playlist?") instead of undo. Simpler to implement, prevents accidental deletion, and avoids the complexity of temporary state management for undo.

## Sources

### Primary (HIGH confidence)
- Codebase analysis: `lib/features/playlist/domain/playlist.dart` - existing Playlist model with toJson/fromJson
- Codebase analysis: `lib/features/bpm_lookup/data/bpm_cache_preferences.dart` - prefix-per-entry pattern
- Codebase analysis: `lib/features/taste_profile/data/taste_profile_preferences.dart` - single-key pattern
- Codebase analysis: `lib/features/run_plan/providers/run_plan_providers.dart` - StateNotifier pattern
- Codebase analysis: `lib/app/router.dart` - existing `/playlist-history` placeholder route
- Codebase analysis: `lib/features/playlist/presentation/playlist_screen.dart` - _PlaylistView, _SongTile, _SegmentHeader widgets
- Codebase analysis: `lib/features/playlist/domain/playlist_generator.dart` - where Playlist is created
- [go_router API docs - GoRouterState](https://pub.dev/documentation/go_router/latest/go_router/GoRouterState-class.html) - pathParameters API
- [Flutter Dismissible widget](https://api.flutter.dev/flutter/widgets/Dismissible-class.html) - built-in swipe-to-dismiss

### Secondary (MEDIUM confidence)
- [Flutter cookbook - Implement swipe to dismiss](https://docs.flutter.dev/cookbook/gestures/dismissible) - Dismissible best practices
- [Flutter cookbook - Store key-value data on disk](https://docs.flutter.dev/cookbook/persistence/key-value) - SharedPreferences patterns
- [go_router parameters docs](https://docs.page/csells/go_router/parameters) - path parameter syntax

### Tertiary (LOW confidence)
- SharedPreferences practical size limit (~1 MB safe) - based on community consensus from multiple web sources, not official documentation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - no new libraries, all patterns exist in codebase
- Architecture: HIGH - direct extension of existing patterns (preferences, notifier, router)
- Pitfalls: HIGH - based on analysis of existing code and SharedPreferences behavior
- Code examples: HIGH - based on existing codebase patterns, verified against source files

**Research date:** 2026-02-05
**Valid until:** 2026-03-07 (stable domain, no fast-moving dependencies)
