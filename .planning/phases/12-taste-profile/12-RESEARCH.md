# Phase 12: Taste Profile - Research

**Researched:** 2026-02-05
**Domain:** Flutter domain model + persistence + UI for music taste questionnaire
**Confidence:** HIGH

## Summary

This phase adds a taste profile feature where users describe their running music preferences (genres, artists, energy level). The research focused on six areas: (1) curating a running-relevant genre list, (2) the correct Flutter widget for multi-select genre picking, (3) artist input UX, (4) energy level semantics and downstream mapping, (5) data model structure, and (6) SharedPreferences serialization patterns.

The codebase already has two complete examples of the exact pattern needed (RunPlan and Stride features): domain model with `toJson()`/`fromJson()`, static preferences class using `SharedPreferences.getString()`/`setString()` with JSON encoding, StateNotifier with auto-load and auto-persist, and manual `StateNotifierProvider`. The taste profile follows this pattern exactly with zero new dependencies.

**Primary recommendation:** Build the taste profile using the identical domain/data/providers/presentation architecture already established in the `run_plan` feature. Use `FilterChip` wrapped in `Wrap` for genre multi-select, a `TextField` + `InputChip` list for artist entry, and `SegmentedButton` for energy level. Persist as a single JSON string via `SharedPreferences.setString()`.

## Standard Stack

### Core

No new dependencies required. Everything needed is already in the project.

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_riverpod | ^2.6.1 | State management | Already in project, manual StateNotifier pattern |
| shared_preferences | ^2.5.4 | Local persistence | Already in project, JSON serialization pattern |
| go_router | ^17.0.1 | Navigation | Already in project, route already stubbed |

### Supporting

No additional packages needed. The UI uses only built-in Material widgets:
- `FilterChip` (multi-select genre picking)
- `SegmentedButton` (energy level selection, already used in run_plan_screen.dart)
- `InputChip` (displaying added artists)
- `TextField` (artist name entry)
- `Wrap` (responsive chip layout, already used in run_plan_screen.dart)

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| FilterChip | ChoiceChip | ChoiceChip is single-select only; FilterChip supports multi-select |
| TextField + InputChip list | advanced_chips_input package | External dependency for simple functionality; hand-rolling is actually simpler here |
| SegmentedButton | Slider or Radio buttons | SegmentedButton matches existing run_plan_screen.dart pattern and is ideal for 3 discrete choices |
| SharedPreferences JSON | Hive or SQLite | Overkill for a single small config object; SharedPreferences JSON pattern is already established |

**Installation:**
```bash
# No new packages needed
```

## Architecture Patterns

### Recommended Project Structure

```
lib/features/taste_profile/
  domain/
    taste_profile.dart         # TasteProfile model, EnergyLevel enum, RunningGenre enum
  data/
    taste_profile_preferences.dart  # Static load/save/clear via SharedPreferences
  providers/
    taste_profile_providers.dart    # TasteProfileNotifier + StateNotifierProvider
  presentation/
    taste_profile_screen.dart       # Main screen with genre, artist, energy sections
```

### Pattern 1: Domain Model (Pure Dart, No Flutter Imports)

**What:** Immutable data class with `toJson()`/`fromJson()` factory, following RunPlan pattern
**When to use:** Always for domain models in this project

```dart
// Source: Matches existing pattern in lib/features/run_plan/domain/run_plan.dart

/// Energy level preference for running music.
enum EnergyLevel {
  chill,
  balanced,
  intense;

  static EnergyLevel fromJson(String name) =>
      EnergyLevel.values.firstWhere((e) => e.name == name);
}

/// The user's running music taste preferences.
class TasteProfile {
  const TasteProfile({
    this.genres = const [],
    this.artists = const [],
    this.energyLevel = EnergyLevel.balanced,
  });

  factory TasteProfile.fromJson(Map<String, dynamic> json) {
    return TasteProfile(
      genres: (json['genres'] as List<dynamic>)
          .map((g) => g as String)
          .toList(),
      artists: (json['artists'] as List<dynamic>)
          .map((a) => a as String)
          .toList(),
      energyLevel: EnergyLevel.fromJson(json['energyLevel'] as String),
    );
  }

  final List<String> genres;
  final List<String> artists;
  final EnergyLevel energyLevel;

  Map<String, dynamic> toJson() => {
        'genres': genres,
        'artists': artists,
        'energyLevel': energyLevel.name,
      };

  TasteProfile copyWith({
    List<String>? genres,
    List<String>? artists,
    EnergyLevel? energyLevel,
  }) {
    return TasteProfile(
      genres: genres ?? this.genres,
      artists: artists ?? this.artists,
      energyLevel: energyLevel ?? this.energyLevel,
    );
  }
}
```

### Pattern 2: Static Preferences Class

**What:** Static class with `load()`, `save()`, `clear()` wrapping SharedPreferences JSON
**When to use:** For every persisted model in this project

```dart
// Source: Matches existing pattern in lib/features/run_plan/data/run_plan_preferences.dart

class TasteProfilePreferences {
  static const _key = 'taste_profile';

  static Future<TasteProfile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return null;
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return TasteProfile.fromJson(json);
  }

  static Future<void> save(TasteProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(profile.toJson());
    await prefs.setString(_key, jsonString);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
```

### Pattern 3: StateNotifier with Auto-Load and Auto-Persist

**What:** StateNotifier that loads from preferences in constructor and persists on every mutation
**When to use:** For every stateful feature in this project

```dart
// Source: Matches existing pattern in lib/features/run_plan/providers/run_plan_providers.dart

class TasteProfileNotifier extends StateNotifier<TasteProfile?> {
  TasteProfileNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    state = await TasteProfilePreferences.load();
  }

  Future<void> setProfile(TasteProfile profile) async {
    state = profile;
    await TasteProfilePreferences.save(profile);
  }

  // Granular mutation methods for UI convenience:
  Future<void> setGenres(List<String> genres) async { /* ... */ }
  Future<void> addArtist(String artist) async { /* ... */ }
  Future<void> removeArtist(String artist) async { /* ... */ }
  Future<void> setEnergyLevel(EnergyLevel level) async { /* ... */ }

  Future<void> clear() async {
    state = null;
    await TasteProfilePreferences.clear();
  }
}

final tasteProfileNotifierProvider =
    StateNotifierProvider<TasteProfileNotifier, TasteProfile?>(
  (ref) => TasteProfileNotifier(),
);
```

### Pattern 4: ConsumerStatefulWidget Screen

**What:** Screen uses `ConsumerStatefulWidget` and `ref.watch()`/`ref.read()` for state access
**When to use:** For all UI screens in this project

The `run_plan_screen.dart` and `stride_screen.dart` both use this pattern. The taste profile screen should follow suit.

### Anti-Patterns to Avoid

- **Do NOT use `@riverpod` code-gen:** The project uses manual `StateNotifierProvider` definitions exclusively
- **Do NOT import Flutter in domain/:** The `taste_profile.dart` domain model must be pure Dart
- **Do NOT use `setStringList()` for the whole profile:** Store as a single JSON string via `setString()` to match the RunPlan pattern and keep atomicity
- **Do NOT create separate SharedPreferences keys for genres, artists, and energy:** Store as one JSON blob for atomic reads/writes, matching RunPlan pattern
- **Do NOT add external packages for chip input:** Use built-in Material `FilterChip` and `InputChip` widgets

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Multi-select chips | Custom toggle buttons or checkboxes | Flutter `FilterChip` in `Wrap` | Material Design standard, handles accessibility/theming automatically |
| Single-select from 3 options | Radio buttons or custom toggle | `SegmentedButton<EnergyLevel>` | Already used in run_plan_screen.dart for RunType |
| Tag-style artist display | Custom container with X button | `InputChip` with `onDeleted` | Built-in Material widget with delete affordance |
| JSON serialization | Manual string concatenation | `dart:convert` `jsonEncode`/`jsonDecode` | Standard library, handles escaping and nested structures |
| Responsive chip layout | Custom grid/flow layout | `Wrap` widget with `spacing`/`runSpacing` | Flutter built-in, handles wrapping and spacing |

**Key insight:** Every UI component needed for this phase is a built-in Flutter Material widget. Zero external packages are required beyond what is already in `pubspec.yaml`.

## Common Pitfalls

### Pitfall 1: ChoiceChip vs FilterChip Confusion
**What goes wrong:** Using `ChoiceChip` for genre selection, which only allows single selection
**Why it happens:** `ChoiceChip` and `FilterChip` look similar, but ChoiceChip is designed for single-select (like radio buttons)
**How to avoid:** Use `FilterChip` for genres (multi-select, 1-5). Use `SegmentedButton` for energy level (single-select, 3 options)
**Warning signs:** User can only select one genre at a time

### Pitfall 2: SharedPreferences Atomicity
**What goes wrong:** Storing genres, artists, and energy level as separate SharedPreferences keys, then loading them individually, leading to partially loaded state
**Why it happens:** Seems simpler to have separate keys
**How to avoid:** Store the entire TasteProfile as one JSON string in one key, matching the RunPlan pattern. Load and save atomically.
**Warning signs:** Profile appears partially loaded after app restart

### Pitfall 3: Genre List Stored as Enum Names vs Display Names
**What goes wrong:** Storing display names ("Hip-Hop / Rap") in JSON, which breaks if display text changes
**Why it happens:** Natural to serialize what the user sees
**How to avoid:** Store machine-readable identifiers (e.g., enum names or slug strings). Map to display names in the UI layer only. This also aligns with potential future Spotify API integration where genre seeds use slugs like "hip-hop".
**Warning signs:** Data migration needed when renaming a genre label

### Pitfall 4: Artist Name Validation Edge Cases
**What goes wrong:** Empty strings, duplicate entries, or whitespace-only names stored in the artist list
**Why it happens:** No input validation on the TextField
**How to avoid:** Trim whitespace, reject empty strings, check for case-insensitive duplicates before adding. Enforce the 10-artist maximum in the notifier.
**Warning signs:** Empty chips appear in the UI, or user can add the same artist twice

### Pitfall 5: Null State After Initial Load
**What goes wrong:** UI renders before `_load()` completes, showing null/empty state briefly
**Why it happens:** `_load()` is async and called from constructor
**How to avoid:** This is the existing pattern in the codebase (RunPlanNotifier does the same). The UI should handle `null` state gracefully -- show the empty form ready for input. This is actually correct UX: a new user sees an empty form.
**Warning signs:** Flicker or loading state shown unnecessarily

### Pitfall 6: Genre Count Validation Off-By-One
**What goes wrong:** User can select 0 or 6+ genres
**Why it happens:** Validation only in the save button, not in the chip selection callback
**How to avoid:** In the `onSelected` callback for FilterChip, check the count. If already at 5, do not allow selecting more. If at 1, do not allow deselecting the last one. Show a snackbar or disable further selection.
**Warning signs:** User selects 6 genres and saves, or deselects all genres

## Code Examples

### Genre Picker with FilterChip (Multi-Select, Max 5)

```dart
// Built-in Flutter Material widgets, no external packages
Wrap(
  spacing: 8,
  runSpacing: 4,
  children: RunningGenre.values.map((genre) {
    final isSelected = _selectedGenres.contains(genre.name);
    return FilterChip(
      label: Text(genre.displayName),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            if (_selectedGenres.length < 5) {
              _selectedGenres.add(genre.name);
            }
          } else {
            _selectedGenres.remove(genre.name);
          }
        });
      },
    );
  }).toList(),
)
```

### Artist Input with TextField + InputChip List

```dart
// TextField for entry, InputChips for display/deletion
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Wrap(
      spacing: 8,
      runSpacing: 4,
      children: _artists.map((artist) {
        return InputChip(
          label: Text(artist),
          onDeleted: () {
            setState(() => _artists.remove(artist));
          },
        );
      }).toList(),
    ),
    if (_artists.length < 10)
      TextField(
        controller: _artistController,
        decoration: const InputDecoration(
          labelText: 'Add artist',
          hintText: 'Type artist name and press enter',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (value) {
          final trimmed = value.trim();
          if (trimmed.isNotEmpty && !_artists.contains(trimmed) && _artists.length < 10) {
            setState(() => _artists.add(trimmed));
            _artistController.clear();
          }
        },
      ),
  ],
)
```

### Energy Level Selector with SegmentedButton

```dart
// Matches the RunType selector pattern in run_plan_screen.dart
SegmentedButton<EnergyLevel>(
  segments: const [
    ButtonSegment(
      value: EnergyLevel.chill,
      label: Text('Chill'),
      icon: Icon(Icons.spa),
    ),
    ButtonSegment(
      value: EnergyLevel.balanced,
      label: Text('Balanced'),
      icon: Icon(Icons.balance),
    ),
    ButtonSegment(
      value: EnergyLevel.intense,
      label: Text('Intense'),
      icon: Icon(Icons.local_fire_department),
    ),
  ],
  selected: {_selectedEnergyLevel},
  onSelectionChanged: (selected) {
    setState(() => _selectedEnergyLevel = selected.first);
  },
)
```

### JSON Round-Trip Test Pattern

```dart
// Source: Matches test pattern in test/features/run_plan/domain/run_plan_calculator_test.dart
test('toJson -> fromJson round-trip preserves all fields', () {
  final original = TasteProfile(
    genres: ['pop', 'hip-hop', 'electronic'],
    artists: ['Dua Lipa', 'The Weeknd'],
    energyLevel: EnergyLevel.intense,
  );
  final json = original.toJson();
  final restored = TasteProfile.fromJson(json);
  expect(restored.genres, equals(original.genres));
  expect(restored.artists, equals(original.artists));
  expect(restored.energyLevel, equals(original.energyLevel));
});
```

## Running Music Genres: Curated List of 15

Based on research into running playlists, Spotify genre seeds, and workout music patterns, here is the recommended curated list of 15 running-relevant genres. Each genre identifier is chosen to align with Spotify's genre seed format for future API integration (Phase 14).

| # | Identifier | Display Name | Why Relevant for Running | Typical BPM |
|---|------------|-------------|-------------------------|-------------|
| 1 | `pop` | Pop | Most popular workout genre, consistent BPM | 100-130 |
| 2 | `hip-hop` | Hip-Hop / Rap | Top motivational genre for running | 85-115 (half-time feel at 170-230) |
| 3 | `electronic` | Electronic | Steady beats ideal for tempo maintenance | 120-150 |
| 4 | `edm` | EDM | High-energy drops, excellent for intervals | 128-150 |
| 5 | `rock` | Rock | Driving energy for sustained effort | 110-140 |
| 6 | `indie` | Indie | Lighter alternative for easy/recovery runs | 100-130 |
| 7 | `dance` | Dance | Upbeat and rhythmic, great for steady pace | 120-135 |
| 8 | `house` | House | Consistent 4/4 beat, ideal for cadence sync | 120-130 |
| 9 | `drum-and-bass` | Drum & Bass | Fast tempo, perfect for intense runs | 160-180 |
| 10 | `r-n-b` | R&B / Soul | Groove-based, good for balanced runs | 90-110 |
| 11 | `latin` | Latin / Reggaeton | Infectious rhythm, high energy | 90-110 (reggaeton), 120-140 (latin pop) |
| 12 | `metal` | Metal | Aggressive intensity for HIIT/sprints | 120-180 |
| 13 | `punk` | Punk Rock | Fast tempo, high energy | 140-180 |
| 14 | `funk` | Funk / Disco | Groovy basslines, good for steady pace | 110-130 |
| 15 | `k-pop` | K-Pop | High-energy choreography-inspired | 120-140 |

**Design note:** Store the identifier string (e.g., `"pop"`, `"hip-hop"`) in JSON, not the display name. The display name is a UI concern and can be mapped from the identifier. This also aligns with Spotify's genre seed parameter format for downstream playlist generation in Phase 14.

**Implementation:** Define as an enum with a `displayName` getter and a `slug` (or just use `name`). Alternatively, define as a simple class/map since the list is curated and fixed.

## Energy Level Semantics

The three energy levels map to playlist filtering as follows:

| Level | Display | Description | BPM Bias | Downstream Use (Phase 14) |
|-------|---------|-------------|----------|---------------------------|
| `chill` | Chill | Easy runs, recovery, warm-up/cool-down | Prefer lower BPM range within genre | Filter for lower-energy tracks; favor acoustic/mellow variants |
| `balanced` | Balanced | Standard runs, tempo runs | Use genre's natural BPM range | No filtering bias; use tracks as-is |
| `intense` | Intense | Intervals, sprints, race pace | Prefer higher BPM range within genre | Filter for high-energy tracks; favor upbeat/aggressive variants |

**Design note:** The energy level is a single preference, not per-segment. It flavors the overall playlist generation. Per-segment energy is handled by the run plan's segment BPM targets, not the taste profile.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `ChoiceChip` for multi-select | `FilterChip` for multi-select | Always (Material Design spec) | `FilterChip` is the correct widget for multi-select |
| `Wrap` with `ChoiceChip` | `Wrap` with `FilterChip` | N/A | Same layout, different chip type |
| Separate SharedPreferences keys | Single JSON blob via `setString()` | Project convention | Atomic persistence, simpler load/save |
| `@riverpod` code-gen | Manual `StateNotifierProvider` | Project convention | Consistency with existing codebase |

**Deprecated/outdated:**
- Spotify's `get-available-genre-seeds` API endpoint has been deprecated. Genre seeds are no longer officially maintained by Spotify's Web API. For the taste profile, we use a curated static list instead of fetching dynamically from Spotify.

## Open Questions

1. **Case-sensitivity in artist names**
   - What we know: Artists should be trimmed and deduplicated
   - What's unclear: Should "the weeknd" and "The Weeknd" be treated as duplicates?
   - Recommendation: Use case-insensitive comparison for deduplication, store the user's original casing for display

2. **Genre list extensibility**
   - What we know: The curated list of 15 genres covers the main running music categories
   - What's unclear: Whether users will want genres not in the list (e.g., country, classical)
   - Recommendation: Start with the fixed list of 15. If user feedback indicates missing genres, adding more is trivial since genres are stored as strings, not enum ordinals

3. **Downstream API integration**
   - What we know: Phase 14 (Playlist Generation) will consume the taste profile
   - What's unclear: The exact Spotify API strategy since genre seeds are deprecated
   - Recommendation: Store genre identifiers that loosely align with Spotify slugs. Phase 14 can map these to artist seeds or other recommendation strategies as needed

## Sources

### Primary (HIGH confidence)
- Existing codebase: `lib/features/run_plan/` (domain model, preferences, providers, presentation patterns)
- Existing codebase: `lib/features/stride/` (preferences and providers patterns)
- Existing codebase: `lib/app/router.dart` (route already stubbed at `/taste-profile`)
- [Flutter official docs - SharedPreferences](https://docs.flutter.dev/cookbook/persistence/key-value) - supported types and limitations
- [Flutter FilterChip API](https://api.flutter.dev/flutter/material/FilterChip-class.html) - multi-select chip widget

### Secondary (MEDIUM confidence)
- [Spotify genre seeds gist](https://gist.github.com/drumnation/91a789da6f17f2ee20db8f55382b6653) - 149 available genre seed values (pre-deprecation)
- [Playlist Names - 15 Best Workout Genres](https://www.playlistnames.org/what-are-the-best-genres-of-music-to-include-in-a-workout-playlist/) - genre list with BPM ranges
- [Runner's Need - Running and Music BPM](https://www.runnersneed.com/expert-advice/training/running-and-music-finding-your-bpm.html) - BPM ranges for running intensities

### Tertiary (LOW confidence)
- [Cosmopolitan - Best Running Songs 2025](https://www.cosmopolitan.com/uk/body/fitness-workouts/a63330170/running-music-playlist/) - popular running music genres
- [Modded - 7 Best Workout Music Genres](https://modded.com/fitness/best-workout-music/) - genre recommendations

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - No new dependencies; exact patterns already exist in codebase
- Architecture: HIGH - Carbon copy of run_plan feature architecture
- Data model: HIGH - Follows established toJson/fromJson pattern; straightforward fields
- Genre list: MEDIUM - Curated from multiple sources, may need user validation
- Energy level mapping: MEDIUM - BPM ranges well-documented but downstream mapping is Phase 14's concern
- Pitfalls: HIGH - Based on direct code analysis and known Flutter widget behavior

**Research date:** 2026-02-05
**Valid until:** 2026-03-05 (stable; no fast-moving dependencies)
