# Phase 30: Local Song Search - Research

**Researched:** 2026-02-09
**Domain:** Flutter typeahead search, in-memory filtering, text highlighting
**Confidence:** HIGH

## Summary

Phase 30 implements typeahead search over the curated song catalog (~5,066 songs), allowing users to find and add songs to their "Songs I Run To" collection. The solution uses Flutter's built-in `Autocomplete<T>` widget, which natively supports async `optionsBuilder` (returns `FutureOr<Iterable<T>>`), custom option rendering via `optionsViewBuilder`, and works with any Dart object type. No external packages are needed.

The curated song data is already loaded and cached by `CuratedSongRepository` (3-tier: cache -> Supabase -> bundled JSON). A new `FutureProvider<List<CuratedSong>>` will expose the full song list for search. In-memory `String.contains()` filtering over 5,066 items is well under the 300ms target -- simple lowercase substring matching is the correct approach for this catalog size. Debouncing at 300ms and a 2-character minimum query length prevent unnecessary recomputation.

**Primary recommendation:** Use Flutter's built-in `Autocomplete<CuratedSong>` with a custom `optionsViewBuilder` for highlight rendering and `RichText`/`TextSpan` for match highlighting. Create an abstract `SongSearchService` interface with a single `CuratedSongSearchService` implementation now, designed for Phase 32's `SpotifySearchService` composite.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter `Autocomplete<T>` | SDK 3.38 | Typeahead widget with async support | Built-in, no deps, handles focus/keyboard/overlay |
| `RichText` + `TextSpan` | SDK 3.38 | Highlight matching characters | Built-in Flutter widgets, no package needed |
| `dart:async` Timer | SDK 3.10 | Debounce input | Standard Dart pattern, ~15 lines |
| `flutter_riverpod` | 2.6.1 | State management for search results | Already used project-wide |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `CuratedSongRepository` | existing | Provides song data | Load curated songs for search |
| `RunningSongNotifier` | existing | Add songs to collection | When user taps search result |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `Autocomplete` | `SearchAnchor` | SearchAnchor opens a full-screen search view -- overkill for inline typeahead on a screen that already shows results. Autocomplete keeps the search inline. |
| `Autocomplete` | `flutter_typeahead` package | External dependency for no benefit -- built-in Autocomplete covers all requirements |
| `RichText` manual spans | `highlight_text` package | External dependency; manual TextSpan building is ~30 lines and more flexible |
| In-memory filter | Trie/inverted index | Premature optimization for 5K items; `String.contains()` is sub-millisecond |

**Installation:**
No new packages needed. All dependencies already in pubspec.yaml.

## Architecture Patterns

### Recommended Project Structure
```
lib/features/
├── song_search/
│   ├── domain/
│   │   └── song_search_service.dart       # Abstract interface + CuratedSongSearchService
│   ├── providers/
│   │   └── song_search_providers.dart     # Provider for search service, curated songs list
│   └── presentation/
│       ├── song_search_screen.dart        # Screen with Autocomplete widget
│       └── highlight_match.dart           # RichText highlight utility
```

### Pattern 1: Abstract Search Service Interface
**What:** An abstract class defining the search contract, with CuratedSongSearchService as the initial implementation. Phase 32 adds SpotifySearchService behind the same interface.
**When to use:** SEARCH-03 requires this for backend extensibility.
**Example:**
```dart
// Source: Project architecture decision for SEARCH-03
/// Result from a search backend. Contains display data + source info.
class SongSearchResult {
  const SongSearchResult({
    required this.title,
    required this.artist,
    this.bpm,
    this.genre,
    required this.source,  // 'curated' or 'spotify'
  });
  final String title;
  final String artist;
  final int? bpm;
  final String? genre;
  final String source;
}

/// Abstract search service interface.
///
/// Implementations: CuratedSongSearchService (Phase 30),
/// SpotifySearchService (Phase 32), CompositeSongSearchService (Phase 32).
abstract class SongSearchService {
  Future<List<SongSearchResult>> search(String query);
}

class CuratedSongSearchService implements SongSearchService {
  CuratedSongSearchService(this._songs);
  final List<CuratedSong> _songs;

  @override
  Future<List<SongSearchResult>> search(String query) async {
    final lowerQuery = query.toLowerCase().trim();
    if (lowerQuery.length < 2) return [];
    return _songs
        .where((s) =>
            s.title.toLowerCase().contains(lowerQuery) ||
            s.artistName.toLowerCase().contains(lowerQuery))
        .take(20)  // Limit results for UI performance
        .map((s) => SongSearchResult(
              title: s.title,
              artist: s.artistName,
              bpm: s.bpm,
              genre: s.genre,
              source: 'curated',
            ))
        .toList();
  }
}
```

### Pattern 2: Autocomplete with Custom Options View
**What:** Flutter's `Autocomplete<SongSearchResult>` with `optionsViewBuilder` for custom result rendering including highlighted matches.
**When to use:** Core UI pattern for the search screen.
**Example:**
```dart
// Source: Flutter SDK autocomplete.1.dart + autocomplete.3.dart examples
Autocomplete<SongSearchResult>(
  optionsBuilder: (TextEditingValue textEditingValue) async {
    if (textEditingValue.text.length < 2) {
      return const Iterable<SongSearchResult>.empty();
    }
    final results = await _debouncedSearch(textEditingValue.text);
    return results ?? _lastOptions;
  },
  displayStringForOption: (result) => '${result.artist} - ${result.title}',
  optionsViewBuilder: (context, onSelected, options) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options.elementAt(index);
              return ListTile(
                title: RichText(text: TextSpan(children: highlightMatches(option.title, query))),
                subtitle: RichText(text: TextSpan(children: highlightMatches(option.artist, query))),
                onTap: () => onSelected(option),
              );
            },
          ),
        ),
      ),
    );
  },
  onSelected: (SongSearchResult result) {
    // Add to "Songs I Run To" via runningSongProvider
  },
)
```

### Pattern 3: Text Match Highlighting with TextSpan
**What:** A utility function that splits a source string into highlighted and non-highlighted `TextSpan` segments based on query matches.
**When to use:** SEARCH-02 requires visual highlighting of matching characters.
**Example:**
```dart
// Source: Verified pattern from nhancv/83bb7792d18a4da9cae22ec47256b9f4
List<TextSpan> highlightMatches(String source, String query, TextStyle? baseStyle) {
  if (query.isEmpty) return [TextSpan(text: source, style: baseStyle)];

  final lowerSource = source.toLowerCase();
  final lowerQuery = query.toLowerCase();
  final spans = <TextSpan>[];
  int start = 0;

  while (true) {
    final index = lowerSource.indexOf(lowerQuery, start);
    if (index == -1) {
      spans.add(TextSpan(text: source.substring(start), style: baseStyle));
      break;
    }
    if (index > start) {
      spans.add(TextSpan(text: source.substring(start, index), style: baseStyle));
    }
    spans.add(TextSpan(
      text: source.substring(index, index + query.length),
      style: baseStyle?.copyWith(fontWeight: FontWeight.bold, color: highlightColor)
          ?? const TextStyle(fontWeight: FontWeight.bold),
    ));
    start = index + query.length;
  }
  return spans;
}
```

### Pattern 4: Debounce via Official Flutter Pattern
**What:** The official Flutter SDK debounce pattern from `autocomplete.3.dart`, using `Timer` + `Completer` + cancel exception.
**When to use:** Wrapping the search service call within Autocomplete's `optionsBuilder`.
**Example:**
```dart
// Source: Flutter SDK examples/api/lib/material/autocomplete/autocomplete.3.dart
typedef _Debounceable<S, T> = Future<S?> Function(T parameter);

_Debounceable<S, T> _debounce<S, T>(_Debounceable<S?, T> function) {
  _DebounceTimer? debounceTimer;
  return (T parameter) async {
    if (debounceTimer != null && !debounceTimer!.isCompleted) {
      debounceTimer!.cancel();
    }
    debounceTimer = _DebounceTimer();
    try {
      await debounceTimer!.future;
    } on _CancelException {
      return null;
    }
    return function(parameter);
  };
}
```
Note: For in-memory search over 5K items, debounce is more about preventing excessive widget rebuilds than about actual computation time. The 300ms debounce specified in requirements is appropriate.

### Anti-Patterns to Avoid
- **Loading curated songs on every search call:** The song list should be loaded once via a provider and passed to the search service, not re-fetched per query.
- **Building the search into the running songs screen:** Search deserves its own screen/route for clean navigation and potential reuse from other contexts.
- **Fuzzy matching for V1:** Simple `String.contains()` is sufficient for 5K songs. Levenshtein distance, trigram indices, etc. are premature optimization.
- **Returning all 5K results:** Always `.take(N)` to limit results shown in the dropdown (20 is a sensible limit).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Typeahead overlay positioning | Custom overlay management | `Autocomplete` widget | Handles focus, keyboard navigation, overlay positioning, dismiss-on-tap-outside |
| Debounce timer | Custom timer management | Flutter's official debounce pattern from autocomplete.3.dart | Handles cancellation, memory cleanup, edge cases with in-flight calls |
| Text input field | Raw `TextField` + manual state | `Autocomplete.fieldViewBuilder` | Gets proper focus, editing controller, and submission handling for free |

**Key insight:** The Flutter SDK's `Autocomplete` widget handles the complete typeahead lifecycle (input -> debounce -> filter -> display -> select -> dismiss). Building this from `TextField` + `Overlay` manually would require reimplementing keyboard navigation, overlay positioning, focus management, and tap-outside-to-dismiss.

## Common Pitfalls

### Pitfall 1: Autocomplete optionsViewBuilder Alignment
**What goes wrong:** Custom `optionsViewBuilder` content renders at wrong position or overflows screen.
**Why it happens:** The `optionsViewBuilder` widget is placed in an `Overlay` positioned relative to the text field. Without `Align(alignment: Alignment.topLeft)` wrapping, the content stretches to fill the overlay.
**How to avoid:** Always wrap `optionsViewBuilder` content in `Align(alignment: Alignment.topLeft)` with a `Material` parent and `ConstrainedBox` for height.
**Warning signs:** Options list appears full-width or at wrong vertical position.

### Pitfall 2: Stale Search Results on Fast Typing
**What goes wrong:** Results from an earlier (slower) query replace results from a later (faster) query.
**Why it happens:** Without debouncing or staleness checks, multiple in-flight searches can complete out-of-order.
**How to avoid:** Use the debounce pattern that returns `null` for stale results, and fall back to `_lastOptions` when null is returned.
**Warning signs:** Results flickering or showing wrong matches briefly.

### Pitfall 3: Missing Curated Songs Provider
**What goes wrong:** Each search call triggers a full `CuratedSongRepository.loadCuratedSongs()`, causing redundant disk I/O.
**Why it happens:** Currently no provider exposes `List<CuratedSong>` -- only derived maps (runnability, genre lookup, keys).
**How to avoid:** Create a `FutureProvider<List<CuratedSong>>` that loads once and caches. Pass the list to `CuratedSongSearchService`.
**Warning signs:** Search feeling slow on first keystroke; SharedPreferences being read repeatedly.

### Pitfall 4: Case-Sensitivity in Matching vs. Highlighting
**What goes wrong:** Match highlighting shows wrong substring or misses matches.
**Why it happens:** Searching on `toLowerCase()` but highlighting on original case requires index alignment between the two.
**How to avoid:** Use `indexOf` on the lowercased source with the lowercased query to find positions, then extract substrings from the original-case source at those positions.
**Warning signs:** Bold text not aligning with actual matching characters.

### Pitfall 5: Duplicate Songs Already in Running Collection
**What goes wrong:** User adds a song that's already in "Songs I Run To", creating confusion.
**Why it happens:** No duplicate check in the search result UI.
**How to avoid:** Check `runningSongProvider` state for the song's lookupKey before showing the add action, or show a "Already added" indicator.
**Warning signs:** Same song appearing multiple times in the running songs list (though the Map key prevents actual duplication -- the UX is still confusing).

## Code Examples

### Loading Curated Songs for Search (New Provider)
```dart
// Source: Follows existing pattern in curated_song_providers.dart
final curatedSongsListProvider = FutureProvider<List<CuratedSong>>((ref) async {
  return CuratedSongRepository.loadCuratedSongs();
});
```

### Creating SongSearchResult from CuratedSong after Selection
```dart
// Source: Follows existing RunningSong creation pattern in running_songs_screen.dart
void _addToRunningSongs(WidgetRef ref, SongSearchResult result) {
  final songKey = SongKey.normalize(result.artist, result.title);
  final notifier = ref.read(runningSongProvider.notifier);
  if (notifier.containsSong(songKey)) return; // Already added

  notifier.addSong(RunningSong(
    songKey: songKey,
    artist: result.artist,
    title: result.title,
    addedDate: DateTime.now(),
    bpm: result.bpm,
    genre: result.genre,
    source: RunningSongSource.curated,
  ));
}
```

### Highlight Match Utility Integration
```dart
// Source: Pattern from gist nhancv/83bb7792d18a4da9cae22ec47256b9f4, adapted
Widget _buildHighlightedTile(SongSearchResult result, String query, ThemeData theme) {
  return ListTile(
    leading: Icon(Icons.music_note, color: theme.colorScheme.primary),
    title: RichText(
      text: TextSpan(
        children: highlightMatches(
          result.title,
          query,
          theme.textTheme.titleSmall,
        ),
      ),
    ),
    subtitle: RichText(
      text: TextSpan(
        children: highlightMatches(
          result.artist,
          query,
          theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ),
  );
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `flutter_typeahead` package | Built-in `Autocomplete<T>` | Flutter 2.5+ | No external dependency needed |
| `SearchDelegate` (deprecated style) | `SearchAnchor` / `Autocomplete` | Flutter 3.7+ | Material 3 compliance |
| Sync-only `optionsBuilder` | `FutureOr<Iterable<T>>` optionsBuilder | Flutter 3.22+ (PR #147021) | Native async support in Autocomplete |

**Deprecated/outdated:**
- `showSearch()` / `SearchDelegate`: Legacy pattern, replaced by Material 3 `SearchAnchor`. Not relevant here since we want inline typeahead, not full-screen search.

## Open Questions

1. **Search screen placement: separate screen or bottom sheet on running songs screen?**
   - What we know: Phase 28's running songs screen has an app bar where a search icon could trigger navigation. A separate route keeps things clean and is more reusable.
   - What's unclear: Whether user expects to search from within the running songs list or from a dedicated entry point.
   - Recommendation: Separate `/song-search` route accessible from running songs screen app bar via search icon. This keeps the running songs screen simple and makes search reusable for Phase 32.

2. **Should search results show songs already in "Songs I Run To" differently?**
   - What we know: `RunningSongNotifier.containsSong(key)` provides O(1) lookup.
   - What's unclear: Whether to hide them, gray them out, or show a checkmark.
   - Recommendation: Show a checkmark icon instead of add icon for already-added songs. Don't hide them (user may want to verify a song is already saved).

3. **Result limit: how many results to show?**
   - What we know: Autocomplete dropdown has `optionsMaxHeight: 200` default. With custom builder we control this.
   - What's unclear: Optimal result count for mobile UX.
   - Recommendation: Limit to 20 results and set max height to ~300px. If user needs to narrow down, they type more characters.

## Sources

### Primary (HIGH confidence)
- Flutter SDK `Autocomplete` class source (`/opt/homebrew/share/flutter/packages/flutter/lib/src/material/autocomplete.dart`) - verified constructor, `FutureOr` support
- Flutter SDK `RawAutocomplete` typedef source (`/opt/homebrew/share/flutter/packages/flutter/lib/src/widgets/autocomplete.dart`) - verified `AutocompleteOptionsBuilder` returns `FutureOr<Iterable<T>>`
- Flutter SDK official example `autocomplete.3.dart` - debounce pattern with Timer + Completer
- Flutter SDK official example `autocomplete.1.dart` - custom type with optionsBuilder
- Codebase: `CuratedSongRepository`, `CuratedSong`, `RunningSong`, `SongKey` - verified existing data layer
- Codebase: `curated_songs.json` - verified 5,066 songs in catalog

### Secondary (MEDIUM confidence)
- [Flutter Autocomplete API docs](https://api.flutter.dev/flutter/material/Autocomplete-class.html) - confirmed async optionsBuilder, custom builders
- [Flutter SearchAnchor API docs](https://api.flutter.dev/flutter/material/SearchAnchor-class.html) - confirmed full-screen search pattern (not needed here)
- [GitHub Issue #126531](https://github.com/flutter/flutter/issues/126531) - confirmed suggestionsBuilder async support was added
- [Highlight text gist](https://gist.github.com/nhancv/83bb7792d18a4da9cae22ec47256b9f4) - verified TextSpan highlight pattern

### Tertiary (LOW confidence)
- None. All findings verified against SDK source or official docs.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - verified against Flutter 3.38.9 SDK source code, all built-in
- Architecture: HIGH - search service interface pattern is straightforward, maps directly to Phase 32 extension point
- Pitfalls: HIGH - verified against official examples and codebase analysis

**Research date:** 2026-02-09
**Valid until:** 2026-03-09 (stable Flutter SDK patterns, no fast-moving dependencies)
