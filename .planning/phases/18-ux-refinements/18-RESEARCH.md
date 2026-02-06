# Phase 18: UX Refinements - Research

**Researched:** 2026-02-06
**Domain:** Flutter UI/UX enhancements, Riverpod state management, SharedPreferences persistence
**Confidence:** HIGH

## Summary

Phase 18 adds four distinct UX features to the existing Flutter running playlist app: cadence nudge buttons (+/- BPM), one-tap playlist regeneration for returning users, quality indicator badges on songs, and extended taste preferences (vocal preference, tempo variance tolerance, disliked artists). All four features operate within the existing architecture -- Riverpod StateNotifier providers, SharedPreferences persistence, GoRouter navigation, and Material 3 widgets.

No new dependencies are needed. All four requirements (UX-01 through UX-04) are achievable using existing project patterns: domain model extensions with copyWith, new Riverpod providers or extensions to existing ones, widget composition with Flutter Material components, and SharedPreferences JSON persistence. The scoring pipeline (SongQualityScorer) already receives TasteProfile and can be extended to handle new preference dimensions.

**Primary recommendation:** Split into 2 plans: (1) domain model + provider changes for all 4 requirements with unit tests (TDD), (2) UI screens/widgets, integration wiring, and verification.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter | SDK 3.10.8 | UI framework | Already in project |
| flutter_riverpod | ^2.6.1 | State management | Already in project, all providers use StateNotifier pattern |
| shared_preferences | ^2.5.4 | Local persistence | Already in project for all user preferences |
| go_router | ^17.0.1 | Navigation | Already in project with 7+ routes |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| url_launcher | ^6.3.2 | Open external links | Already in project, used by SongTile |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SharedPreferences for taste prefs | Hive/Isar | Overkill -- JSON blob pattern established, no migration needed |
| Manual provider wiring | riverpod_generator codegen | build_runner partially broken with Dart 3.10 (known blocker) -- stick with manual providers |

**Installation:**
No new packages needed. All requirements can be implemented with existing dependencies.

## Architecture Patterns

### Recommended Project Structure

No new feature folders needed. Changes map to existing feature directories:

```
lib/features/
├── stride/
│   └── providers/stride_providers.dart       # Add cadence nudge method to StrideNotifier
├── taste_profile/
│   ├── domain/taste_profile.dart             # Extend model: vocalPreference, tempoVariance, dislikedArtists
│   ├── data/taste_profile_preferences.dart   # No change needed (JSON serialization handles new fields)
│   └── presentation/taste_profile_screen.dart # Add new UI sections
├── playlist/
│   ├── presentation/
│   │   ├── widgets/song_tile.dart            # Add quality badge
│   │   └── playlist_screen.dart              # Add cadence nudge row
│   └── providers/playlist_providers.dart     # No structural changes needed
├── song_quality/
│   └── domain/song_quality_scorer.dart       # Extend scoring for vocal pref + disliked artists
└── home/
    └── presentation/home_screen.dart         # Add quick-regenerate button + cadence display
```

### Pattern 1: Domain Model Extension with Backward Compatibility

**What:** Add new optional fields to TasteProfile with defaults that preserve existing behavior
**When to use:** Every time a persisted model gains new fields
**Example:**
```dart
// TasteProfile gains new fields -- all optional with defaults
class TasteProfile {
  const TasteProfile({
    this.genres = const [],
    this.artists = const [],
    this.energyLevel = EnergyLevel.balanced,
    // New UX-04 fields
    this.vocalPreference = VocalPreference.noPreference,
    this.tempoVarianceTolerance = TempoVarianceTolerance.moderate,
    this.dislikedArtists = const [],
  });

  // New enum for vocal preference
  final VocalPreference vocalPreference;
  // New enum for how tight BPM matching should be
  final TempoVarianceTolerance tempoVarianceTolerance;
  // Artists to exclude from playlists
  final List<String> dislikedArtists;
}
```

**Backward compatibility:** TasteProfile.fromJson must handle missing keys gracefully -- existing stored profiles don't have the new fields. Use `json['field'] as String? ?? defaultValue` pattern.

### Pattern 2: Cadence Nudge as State Mutation

**What:** Add a `nudgeCadence(int deltaBpm)` method to StrideNotifier that adjusts the working cadence
**When to use:** UX-01 requirement -- quick BPM adjustment without full stride calculator
**Example:**
```dart
// In StrideNotifier
void nudgeCadence(int deltaBpm) {
  final currentCadence = state.cadence;
  final newCadence = (currentCadence + deltaBpm).clamp(150.0, 200.0);
  // Nudge sets calibrated cadence, overriding formula
  state = state.copyWith(calibratedCadence: () => newCadence);
  _persist();
}
```

**Key insight:** Nudging cadence is equivalent to setting a calibrated cadence override. The StrideNotifier already supports `setCalibratedCadence()`. A nudge is just `currentCadence + delta` written as a calibrated value. This reuses existing persistence and provider infrastructure.

### Pattern 3: Quick Regeneration via Last-Run Detection

**What:** Detect if a RunPlan + TasteProfile exist and show a one-tap regenerate button on the home screen
**When to use:** UX-02 requirement
**Example:**
```dart
// In HomeScreen
final runPlan = ref.watch(runPlanNotifierProvider);
final hasProfile = ref.watch(tasteProfileNotifierProvider) != null;

if (runPlan != null) {
  // Show quick regenerate card with run plan summary
  _QuickRegenerateCard(
    runPlan: runPlan,
    onTap: () {
      // Navigate to playlist screen and auto-trigger generation
      context.push('/playlist');
      // Trigger generation after navigation settles
      ref.read(playlistGenerationProvider.notifier).generatePlaylist();
    },
  );
}
```

**Design choice:** Navigate to /playlist and auto-trigger vs. generate in background and navigate with result. The former is simpler and matches existing flow where PlaylistScreen handles all generation states (loading, error, loaded).

### Pattern 4: Quality Badge in SongTile

**What:** Display a visual quality indicator on songs with high runningQuality or curated status
**When to use:** UX-03 requirement
**Example:**
```dart
// In SongTile.build()
Widget? _qualityBadge() {
  if (song.runningQuality != null && song.runningQuality! >= qualityThreshold) {
    return Icon(Icons.verified, size: 16, color: Colors.amber);
  }
  return null;
}
```

**Threshold decision:** The maximum composite score is 36 (artist 10 + genre 6 + dance 8 + energy 4 + BPM 3 + curated 5). A "high quality" threshold of ~20 (top ~55% of max) would surface songs with multiple positive signals. This is tunable.

### Anti-Patterns to Avoid
- **Don't create a new provider for cadence nudge:** The StrideNotifier already manages cadence state. Adding a separate "nudge provider" would create state synchronization issues. Extend the existing notifier.
- **Don't store "last run config" separately:** The RunPlan is already persisted in SharedPreferences. The "last run" is just the current runPlanNotifierProvider state. No need for a separate "last run" concept.
- **Don't filter songs by quality badge:** Quality indicators are display-only. They should NOT affect playlist generation ranking (that's already handled by SongQualityScorer).
- **Don't break TasteProfile JSON backward compatibility:** New fields must default gracefully when deserializing old data. Never make a new field required in fromJson.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| BPM clamping logic | Custom range validator | `double.clamp(150.0, 200.0)` | Already established pattern in StrideCalculator |
| Persisting extended taste profile | New persistence class | Existing TasteProfilePreferences + extended toJson/fromJson | JSON blob handles new fields automatically |
| Quality threshold calculation | Complex scoring pipeline | Simple integer comparison on `runningQuality` field | Score is already computed and stored on PlaylistSong |
| Disliked artist matching | New string matching util | Same bidirectional substring match used in SongQualityScorer._artistMatchScore | Consistency with existing matching logic |

**Key insight:** All four requirements extend existing patterns rather than introducing new infrastructure. The project's architecture was designed to support these exact extensions.

## Common Pitfalls

### Pitfall 1: TasteProfile Deserialization Breaking on Old Data
**What goes wrong:** User updates the app, existing TasteProfile JSON in SharedPreferences lacks new fields (vocalPreference, tempoVarianceTolerance, dislikedArtists). App crashes on TasteProfile.fromJson() because it expects the keys.
**Why it happens:** TasteProfile.fromJson currently does not use null-safe/defaulting access for fields that didn't exist before.
**How to avoid:** Every new field in fromJson must use null-coalescing: `json['vocalPreference'] as String? ?? VocalPreference.noPreference.name`. Test with JSON that has only the original 3 fields.
**Warning signs:** Crashes on first launch after update but not on fresh install.

### Pitfall 2: Cadence Nudge Losing Formula Context
**What goes wrong:** User nudges cadence, which sets calibratedCadence. Now the pace/height formula inputs are grayed out (because calibration overrides formula). User is confused about what happened.
**Why it happens:** The stride screen already fades pace/height controls when calibratedCadence is set.
**How to avoid:** Two options: (a) make nudge clearly labeled as "override" so user understands they can clear it, or (b) nudge the pace input instead of cadence (more complex). Recommend option (a) with clear UI feedback: "Cadence nudged to X spm (tap to reset)".
**Warning signs:** User reports they can no longer change their pace after nudging.

### Pitfall 3: Quick Regenerate Racing with Navigation
**What goes wrong:** Home screen triggers `generatePlaylist()` and `context.push('/playlist')` simultaneously. The playlist screen renders in idle state, then jumps to loading, creating a visual flash.
**Why it happens:** Navigation and state mutation are async operations that may not complete in the expected order.
**How to avoid:** Navigate first, then trigger generation from within the playlist screen. Or: set a flag/parameter that the playlist screen reads on mount to auto-generate. Simplest: just navigate to /playlist -- if a RunPlan exists, the idle view already shows a "Generate" button. The one-tap experience can be: navigate + auto-trigger on the playlist screen itself using a route parameter or a provider flag.
**Warning signs:** Brief flash of "Generate Playlist" button before loading spinner appears.

### Pitfall 4: Disliked Artists Penalty Stacking with Artist Match Bonus
**What goes wrong:** A song's artist appears in both the favorite artists list AND the disliked artists list. The scoring logic applies both bonus and penalty.
**Why it happens:** User adds an artist to favorites, later adds same artist to disliked, or vice versa.
**How to avoid:** Enforce mutual exclusivity: adding an artist to disliked should remove them from favorites (and vice versa). Validate in the notifier, not just the UI.
**Warning signs:** Contradictory artist preferences in the taste profile.

### Pitfall 5: Tempo Variance Tolerance Confusion with BPM Matching
**What goes wrong:** User sets "strict" tempo variance tolerance expecting only exact BPM matches, but the BpmMatcher still returns half-time and double-time songs.
**Why it happens:** BpmMatcher.bpmQueries is a fixed algorithm that always includes exact + half + double.
**How to avoid:** Tempo variance tolerance should affect the scoring weights, not the query strategy. Strict = only exact gets full points; half/double get 0. Loose = half/double get closer to exact's points. This keeps the song pool large while respecting the preference.
**Warning signs:** User sets strict but still sees "(half-time)" songs in playlist.

## Code Examples

### Example 1: Extending TasteProfile Model

```dart
// New enums in taste_profile.dart
enum VocalPreference {
  noPreference,
  preferVocals,
  preferInstrumental;

  static VocalPreference fromJson(String name) =>
      VocalPreference.values.firstWhere(
        (e) => e.name == name,
        orElse: () => VocalPreference.noPreference,
      );
}

enum TempoVarianceTolerance {
  strict,   // Only exact BPM matches get full score
  moderate, // Default behavior (current)
  loose;    // Half-time/double-time nearly as good as exact

  static TempoVarianceTolerance fromJson(String name) =>
      TempoVarianceTolerance.values.firstWhere(
        (e) => e.name == name,
        orElse: () => TempoVarianceTolerance.moderate,
      );
}
```

### Example 2: Backward-Compatible fromJson

```dart
factory TasteProfile.fromJson(Map<String, dynamic> json) {
  return TasteProfile(
    genres: (json['genres'] as List<dynamic>)
        .map((g) => RunningGenre.fromJson(g as String))
        .toList(),
    artists: (json['artists'] as List<dynamic>)
        .map((a) => a as String)
        .toList(),
    energyLevel: EnergyLevel.fromJson(json['energyLevel'] as String),
    // New fields with safe defaults for old data
    vocalPreference: json['vocalPreference'] != null
        ? VocalPreference.fromJson(json['vocalPreference'] as String)
        : VocalPreference.noPreference,
    tempoVarianceTolerance: json['tempoVarianceTolerance'] != null
        ? TempoVarianceTolerance.fromJson(json['tempoVarianceTolerance'] as String)
        : TempoVarianceTolerance.moderate,
    dislikedArtists: (json['dislikedArtists'] as List<dynamic>?)
        ?.map((a) => a as String)
        .toList() ?? const [],
  );
}
```

### Example 3: Cadence Nudge Method

```dart
// Add to StrideNotifier in stride_providers.dart
void nudgeCadence(int deltaBpm) {
  final currentCadence = state.cadence;
  final newCadence = (currentCadence + deltaBpm).clamp(150.0, 200.0);
  state = state.copyWith(calibratedCadence: () => newCadence);
  _persist();
}
```

### Example 4: Quality Badge Widget

```dart
// In song_tile.dart, add to the leading or trailing area
Widget build(BuildContext context) {
  return ListTile(
    leading: _buildQualityIndicator(),
    title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(
      '${song.artistName}  ${_matchLabel(song.matchType)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    trailing: Text(
      '${song.bpm} BPM',
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w500,
      ),
    ),
    onTap: () => _showPlayOptions(context),
  );
}

Widget? _buildQualityIndicator() {
  // High quality threshold: 20+ out of max 36
  if (song.runningQuality != null && song.runningQuality! >= 20) {
    return const Icon(Icons.star, size: 20, color: Colors.amber);
  }
  return null;
}
```

### Example 5: Disliked Artist Scoring Penalty

```dart
// Add to SongQualityScorer
static const dislikedArtistPenalty = -15;

static int _dislikedArtistScore(BpmSong song, TasteProfile? tasteProfile) {
  if (tasteProfile == null || tasteProfile.dislikedArtists.isEmpty) return 0;

  final songArtistLower = song.artistName.toLowerCase();
  if (tasteProfile.dislikedArtists.any(
    (a) => songArtistLower.contains(a.toLowerCase()) ||
           a.toLowerCase().contains(songArtistLower),
  )) {
    return dislikedArtistPenalty;
  }
  return 0;
}
```

### Example 6: Quick Regenerate on Home Screen

```dart
// In home_screen.dart, add a card when returning user has a run plan
Widget _buildQuickRegenerate(RunPlan plan, WidgetRef ref, BuildContext context) {
  return Card(
    child: ListTile(
      leading: const Icon(Icons.replay),
      title: Text(plan.name ?? 'Your Run'),
      subtitle: Text(
        '${plan.distanceKm.toStringAsFixed(1)} km - Tap to regenerate',
      ),
      onTap: () {
        context.push('/playlist');
        // Auto-trigger after navigation
        Future.microtask(() {
          ref.read(playlistGenerationProvider.notifier).generatePlaylist();
        });
      },
    ),
  );
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| BPM-only matching | Composite quality scoring (Phase 16) | 2026-02-05 | Songs ranked by 6 dimensions, not just BPM |
| No curated data | 300 curated songs with +5 bonus (Phase 17) | 2026-02-06 | Proven running songs surface higher |
| Fixed cadence from stride calculator | Calibrated cadence override | Phase 5 | Users can set real-world cadence |

**Current state of taste preferences:**
- TasteProfile has: genres (1-5), artists (0-10), energyLevel (chill/balanced/intense)
- Missing: vocal preference, tempo variance tolerance, disliked artists
- These are pure additive extensions -- no breaking changes to existing model

## Open Questions

1. **Quality badge threshold value**
   - What we know: Max composite score is 36 (10+6+8+4+3+5). A threshold of ~20 would mark songs with multiple positive signals.
   - What's unclear: Without real-world data, the exact distribution of scores is unknown. The threshold might surface too many or too few songs.
   - Recommendation: Start with 20 as default. This can be tuned later. Consider making it a constant for easy adjustment.

2. **Vocal preference scoring mechanism**
   - What we know: The BpmSong model does not have a "has vocals" field. The GetSongBPM API may not provide this data.
   - What's unclear: Without vocal/instrumental metadata on songs, the vocal preference can only be stored but not applied to scoring.
   - Recommendation: Add the preference field to TasteProfile and persist it. For scoring, mark it as a future-use field that will activate when song metadata includes vocal information. Alternatively, use the danceability heuristic (very high danceability correlates with vocal tracks) as a rough proxy, but document that this is approximate. Best path: store the preference, display it in UI, and add a TODO for when metadata becomes available. This preserves the UX requirement ("user can set vocal preference") without requiring metadata that may not exist.

3. **Auto-trigger generation on navigation**
   - What we know: Quick regenerate needs to navigate to /playlist and start generation. PlaylistScreen already handles all states.
   - What's unclear: The cleanest way to signal "auto-start" without creating race conditions.
   - Recommendation: Use a query parameter in the route (e.g., `/playlist?auto=true`) that the PlaylistScreen checks on mount. If present, auto-trigger generation. This avoids timing issues with `Future.microtask`.

4. **Cadence nudge location: home vs. playlist vs. both**
   - What we know: Requirement says "from the playlist screen or home screen."
   - What's unclear: Whether both locations are needed in plan 1 or if one suffices.
   - Recommendation: Implement the nudge logic once in StrideNotifier, then expose +/- buttons in both locations. The widget is small and reusable.

## Sources

### Primary (HIGH confidence)
- Project codebase analysis -- all files listed in Key existing files section read and analyzed
- `lib/features/taste_profile/domain/taste_profile.dart` -- current model with 3 fields (genres, artists, energyLevel)
- `lib/features/stride/providers/stride_providers.dart` -- StrideNotifier with setCalibratedCadence pattern
- `lib/features/playlist/domain/playlist.dart` -- PlaylistSong with runningQuality (int?) field
- `lib/features/song_quality/domain/song_quality_scorer.dart` -- 7 scoring dimensions, max 36 points
- `lib/features/playlist/presentation/widgets/song_tile.dart` -- current ListTile implementation
- `lib/features/home/presentation/home_screen.dart` -- current home screen with 5 navigation buttons
- `lib/features/playlist/providers/playlist_providers.dart` -- PlaylistGenerationNotifier orchestration flow

### Secondary (MEDIUM confidence)
- Flutter Material 3 widget documentation (Icon, ListTile, SegmentedButton) -- patterns verified against existing project usage
- SharedPreferences JSON blob pattern -- verified working in TasteProfilePreferences, RunPlanPreferences

### Tertiary (LOW confidence)
- Quality badge threshold of 20 -- educated guess based on max score of 36 and scoring dimension analysis; needs real-world validation
- Vocal preference as future-use field -- depends on unconfirmed GetSongBPM API capabilities

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no new dependencies, all existing libraries
- Architecture: HIGH -- all patterns verified against existing codebase, pure extensions
- Pitfalls: HIGH -- identified from direct code analysis of serialization, state management, and navigation patterns
- Quality threshold: LOW -- needs real-world data to calibrate
- Vocal preference scoring: LOW -- depends on external API metadata availability

**Research date:** 2026-02-06
**Valid until:** 2026-03-06 (stable -- no external dependencies changing)
