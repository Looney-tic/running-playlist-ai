# Phase 27: Taste Learning - Research

**Researched:** 2026-02-08
**Domain:** On-device pattern detection from user feedback, suggestion UI, taste profile mutation
**Confidence:** HIGH

## Summary

Phase 27 builds an on-device taste learning system that analyzes liked/disliked song feedback to discover implicit genre, artist, and BPM preferences, then surfaces those patterns as actionable suggestion cards the user can accept or dismiss. This is a pure application-layer feature requiring no external libraries -- the data volume (tens to low hundreds of feedback entries) is well within the range where frequency counting outperforms ML-based approaches.

The system has three clear layers: (1) a `TastePatternAnalyzer` domain class that examines a `Map<String, SongFeedback>` against curated song metadata to detect statistically significant patterns, (2) a `TasteSuggestion` model representing a discovered pattern the user can act on, and (3) suggestion card UI that appears on the home screen or settings screen. The architecture follows the exact patterns already established: pure Dart domain logic, SharedPreferences persistence, Riverpod StateNotifier providers, and Material 3 card-based UI.

The key technical challenge is defining "statistically significant" thresholds for a small-data regime. The research below provides concrete threshold recommendations grounded in the data distribution of the existing 5,066-song curated dataset (15 genres, 2,383 unique artists) and realistic feedback volumes (5-50 entries).

**Primary recommendation:** Build a frequency-counting pattern analyzer as a pure Dart domain class with configurable thresholds, using curated song metadata for genre/BPM enrichment of feedback entries. Surface suggestions via a dedicated provider that compares detected patterns against the active taste profile.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_riverpod | (existing) | State management for suggestions | Already in project, follows established patterns |
| shared_preferences | (existing) | Persist dismissed suggestions | Already used for all app persistence |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| (none needed) | -- | -- | All logic is frequency counting on small data sets |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Frequency counting | TensorFlow Lite / ML | Overkill for <4,000 data points per REQUIREMENTS.md out-of-scope decision; adds 10MB+ binary size |
| SharedPreferences | Hive/SQLite | Would enable complex queries but adds dependency for a simple key-value dismissed set |

**Installation:**
```bash
# No new dependencies needed. All required packages are already in the project.
```

## Architecture Patterns

### Recommended Project Structure
```
lib/features/taste_learning/
├── domain/
│   ├── taste_pattern_analyzer.dart   # Pure Dart pattern detection logic
│   └── taste_suggestion.dart         # Suggestion model (type, value, confidence, dismissed state)
├── data/
│   └── taste_suggestion_preferences.dart  # SharedPreferences persistence for dismissed suggestions
├── providers/
│   └── taste_learning_providers.dart      # Riverpod providers (analyzer + suggestion state)
└── presentation/
    └── taste_suggestion_card.dart         # Reusable suggestion card widget
```

### Pattern 1: Frequency-Counting Pattern Analyzer
**What:** Pure Dart class that takes feedback map + curated song metadata, counts genre/artist/BPM distributions in liked vs disliked songs, and returns a list of `TasteSuggestion` objects.
**When to use:** Every time suggestion state needs to be computed (on feedback change).

```dart
// Pattern: stateless analyzer, all inputs explicit
class TastePatternAnalyzer {
  /// Analyzes feedback against curated metadata to discover taste patterns.
  ///
  /// Returns suggestions for patterns NOT already in the active taste profile.
  /// Pure function: no side effects, no Flutter dependencies.
  static List<TasteSuggestion> analyze({
    required Map<String, SongFeedback> feedback,
    required Map<String, CuratedSongMeta> curatedMetadata,
    required TasteProfile activeProfile,
    required Set<String> dismissedSuggestionIds,
  }) {
    final suggestions = <TasteSuggestion>[];
    // ... genre analysis, artist analysis, BPM range analysis
    return suggestions;
  }
}
```

### Pattern 2: Suggestion Model with Deterministic IDs
**What:** Each suggestion gets a deterministic ID derived from its type + value, so the dismissed-suggestions persistence survives app restarts and re-analysis.
**When to use:** Always -- the dismissed set is keyed by suggestion ID.

```dart
enum SuggestionType { addGenre, addArtist, removeArtist, adjustBpmRange }

class TasteSuggestion {
  const TasteSuggestion({
    required this.id,         // e.g. "genre:hipHop" or "artist:Eminem"
    required this.type,
    required this.displayText, // Human-readable: "Add Hip-Hop to your genres?"
    required this.value,       // The actual value: "hipHop" or "Eminem"
    required this.confidence,  // 0.0-1.0, derived from like/dislike ratio
    required this.evidenceCount, // How many feedback entries support this
  });

  /// Deterministic ID: `type.name:value`
  /// Ensures same pattern maps to same dismissed key across re-analyses.
  String get id => '${type.name}:$value';
}
```

### Pattern 3: StateNotifier with Reactive Dependencies
**What:** A `TasteSuggestionNotifier` that watches `songFeedbackProvider` and `tasteProfileLibraryProvider`, re-runs analysis when either changes, and exposes filtered (non-dismissed) suggestions.
**When to use:** This follows the exact same Completer-based `ensureLoaded` pattern as `SongFeedbackNotifier` and `PlayHistoryNotifier`.

```dart
// Follows established project pattern: StateNotifier + Completer + SharedPreferences
class TasteSuggestionNotifier extends StateNotifier<List<TasteSuggestion>> {
  TasteSuggestionNotifier({required this.ref}) : super([]) {
    _load();
  }

  final Ref ref;
  final _dismissedIds = <String>{};

  // Accept: mutates taste profile, adds to dismissed
  Future<void> acceptSuggestion(TasteSuggestion suggestion) async { ... }

  // Dismiss: adds to dismissed set, persists
  Future<void> dismissSuggestion(TasteSuggestion suggestion) async { ... }
}
```

### Pattern 4: Suggestion Cards on Home Screen
**What:** Suggestion cards appear on the home screen between the setup prompts and the navigation buttons, following the existing `_SetupCard` pattern. Each card has Accept/Dismiss actions.
**When to use:** When there are non-dismissed, above-threshold suggestions to show.

### Anti-Patterns to Avoid
- **Auto-applying patterns to taste profile:** REQUIREMENTS.md explicitly forbids this. Suggestions MUST require user acceptance.
- **Using SongFeedback.genre field as primary genre source:** This field is currently NEVER populated (SongTile does not set it). The analyzer must look up genre from curated metadata via lookupKey.
- **Re-analyzing on every build:** The analysis should be triggered by feedback changes, not widget rebuilds. Use Riverpod's dependency tracking.
- **Suggesting patterns already in the profile:** If the user already has "hipHop" in their genres, don't suggest adding it again.
- **Showing dismissed suggestions immediately:** Dismissed suggestions should only resurface when the underlying data changes enough to warrant re-evaluation.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON persistence | Custom file I/O | SharedPreferences (existing pattern) | Consistent with all other persistence in the app |
| Reactive state | Manual listeners | Riverpod StateNotifier (existing pattern) | Already proven pattern in 6+ features |
| Complex statistical tests | Chi-square / hypothesis testing | Simple ratio thresholds | Data volume too small for meaningful statistical tests; frequency ratios are more interpretable |

**Key insight:** The feedback data set is small enough (typically 5-50 entries, max a few hundred) that simple counting and ratio thresholds outperform any statistical sophistication. The REQUIREMENTS.md explicitly states "Single-user frequency counting outperforms ML at <4,000 data points."

## Common Pitfalls

### Pitfall 1: Genre Data Not Available on Feedback Entries
**What goes wrong:** The `SongFeedback.genre` field exists but is always `null` -- `SongTile._onToggleLike()` and `_onToggleDislike()` never set it.
**Why it happens:** The field was added forward-looking for Phase 27 but the UI code was not updated to populate it.
**How to avoid:** The pattern analyzer MUST enrich feedback with genre data by looking up each `feedback.songKey` against the curated song metadata map (keyed by `lookupKey`). Do NOT rely on `SongFeedback.genre`. Optionally, update `SongTile` to start populating genre on new feedback, but the analyzer must still handle legacy null-genre entries.
**Warning signs:** All genre-based suggestions come back empty despite the user having lots of feedback.

### Pitfall 2: Small-Sample False Positives
**What goes wrong:** With 3 liked songs, 2 of which happen to be rock, the system suggests "Add Rock to your genres" with false confidence.
**Why it happens:** Small sample sizes produce noisy frequency distributions.
**How to avoid:** Enforce minimum evidence counts before surfacing a suggestion. Recommended thresholds:
- **Genre suggestion:** Minimum 3 liked songs in that genre AND that genre must represent >=40% of liked songs with known genre
- **Artist suggestion:** Minimum 2 liked songs by that artist
- **Artist removal suggestion:** Minimum 2 disliked songs by that artist
- **BPM range suggestion:** Defer to future phase (BPM data on feedback not directly available, would need enrichment from curated data or play history)
**Warning signs:** Suggestions appearing after just 1-2 feedback entries.

### Pitfall 3: Dismissed Suggestions Resurface Prematurely
**What goes wrong:** User dismisses "Add Rock" suggestion, gives feedback on 1 more rock song, suggestion reappears.
**Why it happens:** The "new data changes the pattern" check is too sensitive.
**How to avoid:** Track the evidence count at dismissal time. Only re-surface a dismissed suggestion when `currentEvidenceCount > dismissedAtEvidenceCount + 2` (i.e., at least 2 new supporting data points since dismissal). Store `{suggestionId: evidenceCountAtDismissal}` rather than just `Set<String>`.
**Warning signs:** Users repeatedly dismissing the same suggestion.

### Pitfall 4: Filter Bubble (Depends on Phase 25 Freshness)
**What goes wrong:** Taste learning reinforces existing preferences, narrowing the song pool to the point where playlists become repetitive.
**Why it happens:** Accept-loop: user likes genre X -> profile adds X -> more X songs appear -> user likes more X -> tighter filter.
**How to avoid:** This is why Phase 27 depends on Phase 25 (Freshness). The freshness penalty ensures variety regardless of taste profile tightening. Additionally, suggestion cards should show a "This will narrow your playlist pool" warning when the user already has 4+ genres or 8+ artists.
**Warning signs:** User accepts every suggestion and then complains about lack of variety.

### Pitfall 5: Taste Profile Mutation via Accept Must Follow UpdateProfile Pattern
**What goes wrong:** Accepting a suggestion directly modifies SharedPreferences, bypassing the notifier, causing stale state.
**Why it happens:** Developer shortcuts the mutation path instead of going through `TasteProfileLibraryNotifier.updateProfile()`.
**How to avoid:** The accept action MUST:
1. Read current active profile from `tasteProfileLibraryProvider`
2. Create a `copyWith` mutation (e.g., `profile.copyWith(genres: [...profile.genres, newGenre])`)
3. Call `notifier.updateProfile(updatedProfile)` which handles both state and persistence
**Warning signs:** Accepted suggestions don't take effect until app restart.

### Pitfall 6: API-Only Songs Have No Genre Metadata
**What goes wrong:** Songs from the GetSongBPM API (not in curated dataset) have `genre: null` on `BpmSong`. If the user only gives feedback on API-sourced songs, genre analysis has no data.
**Why it happens:** The API doesn't return genre in a format matching RunningGenre enum.
**How to avoid:** The analyzer should gracefully degrade: if genre enrichment fails for a feedback entry (not found in curated metadata), skip it for genre analysis but still include it for artist analysis. Report the enrichment rate in the confidence score.
**Warning signs:** Genre suggestions never appear even with many feedback entries.

## Code Examples

### Genre Pattern Detection Logic
```dart
/// Counts genre frequencies in liked songs using curated metadata lookup.
///
/// Returns genre -> count map for genres NOT already in the active profile.
static Map<RunningGenre, int> _countLikedGenres({
  required Map<String, SongFeedback> feedback,
  required Map<String, String> songKeyToGenre, // lookupKey -> genre enum name
  required Set<String> profileGenreNames,       // genres already in profile
}) {
  final counts = <RunningGenre, int>{};

  for (final entry in feedback.values) {
    if (!entry.isLiked) continue;

    final genreName = songKeyToGenre[entry.songKey];
    if (genreName == null) continue; // API-only song, no genre data

    final genre = RunningGenre.tryFromJson(genreName);
    if (genre == null) continue;
    if (profileGenreNames.contains(genre.name)) continue; // Already in profile

    counts[genre] = (counts[genre] ?? 0) + 1;
  }

  return counts;
}
```

### Artist Pattern Detection Logic
```dart
/// Counts artist frequencies in liked songs.
///
/// Returns artist -> count map for artists NOT already in the active profile.
static Map<String, int> _countLikedArtists({
  required Map<String, SongFeedback> feedback,
  required Set<String> profileArtistsLower,
}) {
  final counts = <String, int>{};

  for (final entry in feedback.values) {
    if (!entry.isLiked) continue;

    final artistLower = entry.songArtist.toLowerCase();
    if (profileArtistsLower.contains(artistLower)) continue;

    // Use display-cased artist name as value
    counts[entry.songArtist] = (counts[entry.songArtist] ?? 0) + 1;
  }

  return counts;
}
```

### Disliked Artist Detection Logic
```dart
/// Counts artist frequencies in disliked songs.
///
/// Returns artist -> count map for artists NOT already in the disliked list.
static Map<String, int> _countDislikedArtists({
  required Map<String, SongFeedback> feedback,
  required Set<String> dislikedArtistsLower,
}) {
  final counts = <String, int>{};

  for (final entry in feedback.values) {
    if (entry.isLiked) continue;

    final artistLower = entry.songArtist.toLowerCase();
    if (dislikedArtistsLower.contains(artistLower)) continue;

    counts[entry.songArtist] = (counts[entry.songArtist] ?? 0) + 1;
  }

  return counts;
}
```

### Suggestion Card Widget Pattern
```dart
/// Suggestion card following existing _SetupCard style from HomeScreen.
class TasteSuggestionCard extends StatelessWidget {
  const TasteSuggestionCard({
    required this.suggestion,
    required this.onAccept,
    required this.onDismiss,
    super.key,
  });

  final TasteSuggestion suggestion;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 8),
      child: Card(
        color: theme.colorScheme.tertiaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline, color: theme.colorScheme.onTertiaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(suggestion.displayText, style: theme.textTheme.titleSmall),
                    Text('Based on ${suggestion.evidenceCount} songs',
                      style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              TextButton(onPressed: onDismiss, child: const Text('Dismiss')),
              const SizedBox(width: 4),
              FilledButton(onPressed: onAccept, child: const Text('Accept')),
            ],
          ),
        ),
      ),
    );
  }
}
```

### Curated Metadata Enrichment Provider
```dart
/// Provides a lookup map from song lookupKey to genre enum name.
///
/// Used by the taste pattern analyzer to enrich feedback entries
/// (which don't have genre data) with genre from the curated dataset.
final curatedGenreLookupProvider =
    FutureProvider<Map<String, String>>((ref) async {
  final songs = await CuratedSongRepository.loadCuratedSongs();
  return {
    for (final s in songs) s.lookupKey: s.genre,
  };
});
```

### Accept Suggestion -> Taste Profile Mutation
```dart
/// Applies a suggestion to the active taste profile.
///
/// MUST go through TasteProfileLibraryNotifier.updateProfile to ensure
/// both state and persistence are updated atomically.
Future<void> _acceptGenreSuggestion(
  WidgetRef ref,
  TasteSuggestion suggestion,
) async {
  final state = ref.read(tasteProfileLibraryProvider);
  final profile = state.selectedProfile;
  if (profile == null) return;

  final genre = RunningGenre.tryFromJson(suggestion.value);
  if (genre == null) return;
  if (profile.genres.contains(genre)) return; // Already present
  if (profile.genres.length >= 5) return; // At limit

  final updated = profile.copyWith(
    genres: [...profile.genres, genre],
  );
  await ref.read(tasteProfileLibraryProvider.notifier).updateProfile(updated);
}
```

## Threshold Recommendations

Based on the curated dataset distribution (5,066 songs across 15 genres, 2,383 artists):

### Genre Suggestions
| Threshold | Value | Rationale |
|-----------|-------|-----------|
| Minimum liked songs with genre data | 5 | Need enough data for frequency to be meaningful |
| Minimum songs in suggested genre | 3 | At least 3 liked songs in this genre |
| Minimum genre ratio | 30% | Genre must represent >=30% of liked songs with genre data |
| Max genres in profile before warning | 4 | Profile already has 4+ genres, adding more may not help |

### Artist Suggestions
| Threshold | Value | Rationale |
|-----------|-------|-----------|
| Minimum liked songs by artist | 2 | Two liked songs by same artist = signal |
| Minimum disliked songs for removal | 2 | Two disliked songs = consistent dislike signal |
| Max artists in profile before warning | 8 | Profile already has 8+ artists |

### Dismissed Suggestion Re-emergence
| Threshold | Value | Rationale |
|-----------|-------|-----------|
| New evidence delta for resurfacing | +3 | At least 3 new supporting feedback entries since dismissal |
| Maximum suggestions shown at once | 3 | Avoid overwhelming the user |

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| ML-based recommendation | Frequency counting for small data | N/A (project decision) | Much simpler, no model training, deterministic |
| Auto-apply learned preferences | User-approved suggestions only | N/A (project decision) | Preserves user agency, prevents filter bubbles |

**Deprecated/outdated:**
- None relevant. This is a custom feature, not a library integration.

## Data Flow Summary

```
[User gives feedback]
    → songFeedbackProvider updated
    → TasteSuggestionNotifier detects change
    → TastePatternAnalyzer.analyze() runs:
        1. Load curated metadata (genre lookup)
        2. Count genre/artist frequencies in liked/disliked
        3. Filter out patterns already in active profile
        4. Filter out dismissed suggestions (evidence check)
        5. Apply minimum thresholds
        6. Return List<TasteSuggestion>
    → State updated with filtered suggestions
    → HomeScreen displays suggestion cards
    → User accepts or dismisses

[User accepts suggestion]
    → Mutate TasteProfile via TasteProfileLibraryNotifier.updateProfile()
    → Add suggestion.id to dismissed set
    → Next playlist generation reflects updated profile

[User dismisses suggestion]
    → Store (suggestion.id, currentEvidenceCount) in dismissed map
    → Suggestion hidden until evidence count grows by +3
```

## Implementation Plan Shape (for Planner)

This phase naturally splits into two plans:

**Plan 27-01: Pattern Detection Engine (domain + providers)**
- TasteSuggestion model
- TastePatternAnalyzer (pure Dart, testable)
- TasteSuggestionPreferences (dismissed state persistence)
- TasteSuggestionNotifier (reactive provider)
- CuratedGenreLookup provider
- Unit tests for analyzer thresholds and edge cases

**Plan 27-02: Suggestion UI + Profile Integration**
- TasteSuggestionCard widget
- Home screen integration (show cards)
- Accept action (mutate taste profile via existing notifier)
- Dismiss action (persist dismissed state)
- Router changes (if needed, likely none)
- Integration test for accept/dismiss flow

## Open Questions

1. **BPM range suggestions**
   - What we know: SongFeedback does not store BPM. BPM could be enriched from curated metadata (via lookupKey lookup). However, users already directly control BPM via their run plan cadence setting.
   - What's unclear: Whether BPM-based taste suggestions add value when the user already controls cadence directly.
   - Recommendation: Defer BPM range suggestions to a future iteration. Focus on genre and artist suggestions for Phase 27 which are the most impactful and clearly defined in LRNG-01.

2. **Genre enrichment for SongTile feedback**
   - What we know: SongFeedback has a `genre` field but SongTile never populates it. The analyzer can work around this via curated metadata lookup.
   - What's unclear: Whether to also fix SongTile to populate genre on new feedback (forward-filling) or rely entirely on curated lookup.
   - Recommendation: Fix SongTile to populate genre from curated metadata when available (minimal change, improves data quality over time), but the analyzer MUST still handle null-genre entries via the lookup path.

3. **Where to show suggestion cards**
   - What we know: Home screen has an established pattern of context-aware cards (setup prompts, post-run review).
   - What's unclear: Whether suggestions should also appear on the taste profile screen or settings screen.
   - Recommendation: Home screen only for Phase 27 (matching existing card pattern). The taste profile screen is for editing, not discovery.

## Sources

### Primary (HIGH confidence)
- Codebase analysis: All existing domain models, providers, preferences, and UI patterns examined directly
- `SongFeedback` model at `lib/features/song_feedback/domain/song_feedback.dart` -- confirmed `genre` field exists but is never populated
- `TasteProfile` model at `lib/features/taste_profile/domain/taste_profile.dart` -- confirmed mutable via `copyWith` + `updateProfile`
- `SongQualityScorer` at `lib/features/song_quality/domain/song_quality_scorer.dart` -- confirmed scoring dimensions
- `HomeScreen` at `lib/features/home/presentation/home_screen.dart` -- confirmed `_SetupCard` pattern for suggestion cards
- Curated songs dataset: 5,066 songs, 15 genres, 2,383 unique artists
- `REQUIREMENTS.md` -- confirmed ML out of scope, suggestion-based approach required

### Secondary (MEDIUM confidence)
- Threshold recommendations based on statistical reasoning for small-sample frequency counting in domains with 15 categories (genres) and long-tail distributions (artists). These should be validated with real user data.

### Tertiary (LOW confidence)
- None. All findings verified against codebase.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - no new dependencies, uses only existing patterns
- Architecture: HIGH - follows established feature structure exactly (domain/data/providers/presentation)
- Pitfalls: HIGH - identified from direct codebase analysis (genre null field, mutation path, enrichment gap)
- Thresholds: MEDIUM - reasonable defaults that should be tuned with real user data

**Research date:** 2026-02-08
**Valid until:** 2026-03-10 (stable -- no external dependencies to change)
