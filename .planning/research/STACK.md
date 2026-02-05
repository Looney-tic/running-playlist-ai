# Technology Stack: v1.1 Experience Quality

**Project:** Running Playlist AI
**Milestone:** v1.1 Experience Quality
**Researched:** 2026-02-05
**Overall confidence:** MEDIUM-HIGH

---

## Scope: What This Document Covers

This STACK.md covers **only the additions and changes** needed for v1.1 features. The existing v1.0 stack (Flutter 3.38, Riverpod 2.x manual providers, go_router 17, http, SharedPreferences, GetSongBPM API client, url_launcher) is validated and stable. Do not re-evaluate it.

v1.1 features that drive stack decisions:
1. Running song quality scoring (beyond BPM matching)
2. Curated running song data collection/storage
3. Improved taste profiling for running music
4. Post-run stride/cadence adjustment UX
5. Streamlined repeat generation flow

---

## Critical Discovery: GetSongBPM `/song/` Endpoint Has Danceability

The GetSongBPM API's `/song/` endpoint (lookup by song ID) returns **danceability**, **acousticness**, **key**, and **time_sig** in addition to BPM. The current app only uses the `/tempo/` endpoint which returns basic song metadata (title, artist, BPM, album). Since every `/tempo/` result includes a `song_id`, we can enrich songs with audio features via a follow-up `/song/` lookup.

Example `/song/` response (from API docs):
```json
{
  "song": {
    "id": "o2r0L",
    "title": "Master of Puppets",
    "tempo": "220",
    "time_sig": "4/4",
    "key_of": "Em",
    "danceability": 55,
    "acousticness": 0,
    "artist": {
      "genres": ["heavy metal", "rock"]
    }
  }
}
```

This is the single most impactful discovery for v1.1. **Danceability is a strong proxy for "running suitability"** -- research shows danceability correlates with beat strength, tempo stability, rhythm regularity, and energy. High-danceability songs with appropriate BPM are inherently better running songs.

**Confidence:** MEDIUM (API docs confirmed the fields exist; rate limiting behavior on bulk `/song/` calls is unknown and must be tested)

---

## Recommended Stack Additions

### No New Dependencies Required

The critical insight for v1.1 is: **no new pub.dev packages are needed**. All five features can be built with the existing stack plus pure Dart domain logic and Flutter bundled assets.

| Feature | Stack Approach | New Dependencies |
|---------|---------------|-----------------|
| Song quality scoring | Pure Dart scoring algorithm (extend `PlaylistGenerator`) | None |
| Curated running song data | Bundled JSON asset + SharedPreferences enrichment cache | None |
| Improved taste profiling | Extend `TasteProfile` model, new UI widgets (Flutter Material) | None |
| Post-run stride adjustment | Extend `StrideScreen` UI with adjustment controls | None |
| Streamlined repeat flow | Rework navigation flow in go_router + state in Riverpod | None |

**Rationale:** Adding libraries has a cost (version conflicts, maintenance burden, build time). The existing stack is sufficient. The v1.1 work is primarily domain logic and UX refinement, not infrastructure.

---

### Data Strategy: Song Quality Enrichment

**Decision: Two-tier enrichment approach**

#### Tier 1: Bundled Curated Song List (Static Asset)

Ship a curated JSON file as a Flutter asset containing known-good running songs with pre-computed quality scores. This is the "floor" -- songs in this list are guaranteed to be good running songs.

**Format:** `assets/data/curated_running_songs.json`

```json
[
  {
    "title": "Lose Yourself",
    "artist": "Eminem",
    "bpm": 171,
    "danceability": 72,
    "runningScore": 95,
    "genres": ["hip-hop"],
    "yearAdded": 2026
  }
]
```

**Why bundled JSON asset, not SQLite/Drift:**
- The curated list will be ~200-500 songs. At ~150 bytes per entry, that is 30-75 KB. SharedPreferences handles this easily; SQLite is overkill.
- No relational queries needed -- lookup is by `(title, artist)` composite key or by genre+BPM range.
- Bundled assets require zero setup, zero migrations, zero code generation.
- The list is read-only reference data, not user-modifiable state.
- `rootBundle.loadString()` is async but effectively instant for files under 1 MB.

**Why not Drift/SQLite:**
- Drift adds 3 packages (drift, drift_flutter, drift_dev) plus sqlite3_flutter_libs plus code generation via build_runner.
- Current build_runner usage (freezed, json_serializable, riverpod_generator) would need to coordinate with drift_dev generators. This adds CI complexity.
- The data volume (~500 songs) does not justify the overhead. If the curated list grows beyond 5,000 entries or needs user-specific annotations (thumbs up/down), re-evaluate.
- Drift 2.31.0 is the latest stable version if needed in the future.

**Loading pattern:**
```dart
// Load once at app startup or on first playlist generation
final jsonString = await rootBundle.loadString('assets/data/curated_running_songs.json');
final list = (jsonDecode(jsonString) as List).cast<Map<String, dynamic>>();
```

Declare in `pubspec.yaml`:
```yaml
flutter:
  assets:
    - .env
    - assets/data/curated_running_songs.json
```

**Confidence:** HIGH (Flutter asset loading is well-documented standard practice)

#### Tier 2: API-Enriched Song Features (Dynamic)

For songs NOT in the curated list (i.e., discovered live via `/tempo/` endpoint), fetch danceability from the `/song/` endpoint using the song's `song_id`. Cache the enrichment in SharedPreferences alongside the existing BPM cache.

**Enrichment cache key pattern:** `song_features_{songId}` (mirrors existing `bpm_cache_{bpm}` pattern)

**Rate limiting concern:** The `/tempo/` endpoint returns ~10-20 songs per BPM value. A typical playlist generation queries 3-6 unique BPMs, yielding 30-120 candidate songs. Enriching all of them would mean 30-120 additional API calls. This is problematic.

**Mitigation strategy: Lazy enrichment with batch limiting**
- Only enrich the top-N candidates (e.g., top 20 by existing score) per generation, not all candidates.
- Use the existing 300ms inter-call delay pattern from `PlaylistGenerationNotifier._apiCallDelay`.
- Cache enrichment results with the same 7-day TTL as BPM data.
- Over multiple generations, the enrichment cache builds up, reducing future API calls.

**Confidence:** MEDIUM (API rate limits are undocumented; the batch limiting strategy is a hypothesis that needs production validation)

---

### Song Quality Scoring Algorithm

**Decision: Weighted multi-factor score, pure Dart, no ML**

The current scoring in `PlaylistGenerator._scoreAndRank` uses two factors:
- Artist match: +10 points
- BPM match type (exact vs half/double): +3 or +1 points

v1.1 adds a **running quality dimension** to this score:

| Factor | Score Range | Source | Why |
|--------|------------|--------|-----|
| Curated list membership | +20 | Bundled asset | Known-good running songs should be strongly preferred |
| Danceability (0-100) | +0 to +15 (scaled) | GetSongBPM `/song/` endpoint | Research shows danceability correlates with beat strength, tempo stability, rhythm regularity -- all attributes of good running music |
| Genre match to taste | +10 (existing) | Taste profile | Keep existing behavior |
| Artist match | +10 (existing) | Taste profile | Keep existing behavior |
| BPM match precision | +3 exact, +1 variant (existing) | BPM computation | Keep existing behavior |
| Energy alignment | +5 | Taste profile energy vs song acousticness | Low acousticness + intense preference = bonus; high acousticness + chill = bonus |

**Danceability scaling formula:**
```dart
// Scale 0-100 danceability to 0-15 score points
// Songs below 30 danceability get 0 (likely ballads/ambient)
// Songs above 70 get full 15 (proven danceable/driving rhythm)
final danceScore = ((danceability - 30).clamp(0, 40) / 40 * 15).round();
```

**No ML/AI needed.** A weighted linear score is sufficient because:
- The feature space is small (5-6 signals)
- There is no training data to learn from
- The curated list provides a strong baseline
- The scoring weights can be tuned by hand based on user feedback
- This matches the existing architecture pattern (pure Dart, no external services)

**Confidence:** HIGH (algorithm design is pure domain logic; danceability as running proxy is supported by music research)

---

### Taste Profile Improvements

**Decision: Extend existing `TasteProfile` model, no new packages**

Current model:
```dart
class TasteProfile {
  final List<RunningGenre> genres;  // 1-5 genres
  final List<String> artists;       // 0-10 artists
  final EnergyLevel energyLevel;    // chill/balanced/intense
}
```

Proposed v1.1 additions:
```dart
class TasteProfile {
  // Existing fields (unchanged)
  final List<RunningGenre> genres;
  final List<String> artists;
  final EnergyLevel energyLevel;

  // NEW: Running-specific preferences
  final bool preferVocals;          // vocals vs instrumentals
  final double tempoVarianceTolerance; // 0.0-1.0, how strict on BPM match
  final Set<String> dislikedArtists;   // explicit exclusion list
}
```

**Why `preferVocals`:** Running music preference research distinguishes between runners who want vocals (lyrics as motivation) and those who prefer instrumental/electronic (rhythm focus). This is a meaningful taste signal that affects song selection.

**Why `tempoVarianceTolerance`:** Some runners want exact BPM match; others are fine with +/-5 BPM. This makes half/double-time matching configurable rather than always-on.

**Why `dislikedArtists`:** After seeing generated playlists, users need a way to say "never show me this artist again." This is more impactful than adding liked artists.

**Migration:** The existing `TasteProfile.fromJson` already handles missing fields gracefully (defaults). New fields will have sensible defaults, so existing persisted profiles load without migration.

**Confidence:** HIGH (pure model extension, follows existing patterns)

---

### Post-Run Stride Adjustment

**Decision: Extend `StrideNotifier` and `StrideScreen`, no new packages**

Current stride adjustment requires opening the Stride Calculator and either:
- Changing the pace dropdown
- Running a 30-second calibration

v1.1 adds a simpler "nudge" mechanism:

**Implementation approach:**
- Add `adjustCadence(int delta)` method to `StrideNotifier`
- Surface as +/- buttons or a "that was too fast / too slow" prompt on the playlist results screen
- Persist the adjustment as a cadence offset in `StridePreferences`

**No new packages required.** This is a UI/state change within the existing stride feature module.

**Confidence:** HIGH (follows existing stride module patterns exactly)

---

### Streamlined Repeat Generation Flow

**Decision: Rework navigation flow, no new packages**

Current flow for returning user:
```
Home -> Run Plan (review) -> Taste Profile (review) -> Generate Playlist (tap) -> Wait -> Results
```
That is 4 navigation steps + a button tap before seeing a playlist.

v1.1 target flow:
```
Home -> [Generate button with last settings summary] -> Wait -> Results
```
That is 1 tap from home to generation.

**Implementation approach:**
- Home screen detects saved run plan + taste profile
- Shows "Generate with [last settings]" primary CTA
- Tapping triggers `PlaylistGenerationNotifier.generatePlaylist()` directly
- Navigates to playlist screen which shows loading -> results
- "Edit settings" secondary action available for changes

**No new packages required.** This is a navigation/UX restructuring using existing go_router routes and Riverpod providers.

**Confidence:** HIGH (all required state is already persisted and accessible via providers)

---

## What NOT to Add

| Technology | Why Not Add |
|------------|-------------|
| **drift / SQLite** | Overkill for ~500 curated songs. SharedPreferences + bundled JSON asset handles the data volume. Re-evaluate if curated list exceeds 5,000 entries or user-specific song annotations are needed. |
| **Hive / ObjectBox / Isar** | Same as drift -- unnecessary complexity for the data volume. All three add native library dependencies and code generation overhead. |
| **dio** | The existing `http` package is sufficient. The v1.0 STACK.md recommended dio, but the actual implementation uses `http` and works fine. No reason to switch for additional API calls. |
| **Supabase (activate it)** | Supabase is initialized but dormant. For v1.1, all data is local (curated list is bundled, enrichment cache is SharedPreferences, taste profile is SharedPreferences). Supabase adds network dependency for features that don't need it. Activate when user accounts or cross-device sync are needed. |
| **Any ML/AI package** | Song quality scoring is a weighted linear function on 5-6 features. ML adds complexity (model size, inference time, training data requirements) for minimal benefit over hand-tuned weights. |
| **cached_network_image** | No album art display in current UI, and v1.1 doesn't add it. Don't pre-add packages speculatively. |
| **spotify package** | Spotify Developer Dashboard still blocked as of 2026-02-05. No Spotify integration in v1.1. |
| **flutter_animate / animations package** | Frictionless UX does not require custom animations. Flutter Material's built-in transitions (Hero, page transitions) are sufficient. If specific animation needs arise during implementation, evaluate then. |

---

## Existing Stack: Confirmed Sufficient

These existing packages handle all v1.1 needs without changes:

| Package | v1.1 Usage |
|---------|-----------|
| `flutter_riverpod` ^2.6.1 | State for enrichment cache, extended taste profile, cadence adjustment |
| `go_router` ^17.0.1 | Streamlined navigation flow (rework existing routes) |
| `http` ^1.6.0 | Additional `/song/` endpoint calls for danceability enrichment |
| `shared_preferences` ^2.5.4 | Song feature enrichment cache, extended taste profile persistence |
| `url_launcher` ^6.3.2 | Unchanged -- play links |
| `freezed_annotation` + `json_annotation` | Data class extensions (if needed for new models) |
| `very_good_analysis` ^7.0.0 | Linting (unchanged) |

---

## Data Storage Strategy Summary

| Data | Storage | Format | Lifetime |
|------|---------|--------|----------|
| Curated running songs (~500) | Bundled Flutter asset | JSON file | Permanent (updated with app releases) |
| Song feature enrichment (danceability, etc.) | SharedPreferences | JSON per song_id, keyed `song_features_{id}` | 7-day TTL cache (matches BPM cache) |
| Extended taste profile | SharedPreferences | JSON blob (single key, existing pattern) | Permanent (user-managed) |
| Cadence adjustment offset | SharedPreferences | Numeric value (existing stride prefs key) | Permanent (user-managed) |
| Disliked artists | SharedPreferences (part of taste profile) | String list in taste profile JSON | Permanent (user-managed) |

**SharedPreferences size budget:**
- Existing usage: ~50-200 KB (BPM cache, playlists, settings)
- New enrichment cache: ~100 bytes per song x estimated 500 songs over time = ~50 KB
- New curated list: NOT stored in SharedPreferences (bundled asset, read-only)
- Total estimated: <500 KB -- well within SharedPreferences comfort zone (recommended < few KB per entry, but total storage is effectively unlimited on modern platforms)

**Confidence:** HIGH (follows established patterns, data volumes are small)

---

## API Usage Strategy

| Endpoint | Current Usage | v1.1 Usage | Rate Concern |
|----------|--------------|------------|-------------|
| `GET /tempo/?bpm={n}` | 3-6 calls per generation | Unchanged | Low (existing 300ms delay works) |
| `GET /song/?id={id}` | Not used | Up to 20 calls per generation (top candidates only) | MEDIUM -- needs 300ms delay between calls, cache aggressively |

**Total API calls per playlist generation:**
- v1.0: 3-6 calls (BPM lookups only)
- v1.1: 3-6 + up to 20 = 23-26 calls (with enrichment)
- With caching: Second generation for same BPM range = 0 calls (all cached)

**Mitigation:** The enrichment cache means API calls are front-loaded. After a few generations, most songs in the user's BPM range will be enriched, and generation becomes near-instant (all cached).

**Confidence:** MEDIUM (rate limits undocumented; strategy is sound but needs real-world testing)

---

## Integration Points with Existing Code

| Existing File | What Changes | How |
|--------------|-------------|-----|
| `lib/features/bpm_lookup/domain/bpm_song.dart` | Add optional `danceability`, `acousticness`, `genres` fields | Extend `BpmSong` class, nullable fields for backward compat |
| `lib/features/bpm_lookup/data/getsongbpm_client.dart` | Add `fetchSongById(String songId)` method | New method on existing client, returns enriched `BpmSong` |
| `lib/features/playlist/domain/playlist_generator.dart` | Extend `_scoreAndRank` with quality factors | Add curated list lookup + danceability scoring to existing algorithm |
| `lib/features/taste_profile/domain/taste_profile.dart` | Add `preferVocals`, `tempoVarianceTolerance`, `dislikedArtists` | Extend model with defaults, backward-compatible JSON |
| `lib/features/taste_profile/presentation/taste_profile_screen.dart` | Add new preference UI sections | Extend existing form |
| `lib/features/stride/providers/stride_providers.dart` | Add `adjustCadence(int delta)` | New method on existing notifier |
| `lib/features/home/presentation/home_screen.dart` | Add quick-generate CTA | Read run plan + taste profile state, show primary button |
| `lib/features/playlist/providers/playlist_providers.dart` | Add enrichment step before generation | Extend `_fetchAllSongs` or add parallel enrichment step |
| `lib/features/playlist/presentation/playlist_screen.dart` | Show quality indicators on songs | Extend `SongTile` with running quality badge |
| `pubspec.yaml` | Add asset declaration | `assets/data/curated_running_songs.json` |

---

## Sources

- [GetSongBPM API docs](https://getsongbpm.com/api) - MEDIUM confidence (403 on direct fetch, info from search results and Perl wrapper docs)
- [GetSongBPM `/song/` response with danceability](https://getsongbpm.com/api) - MEDIUM confidence (confirmed via multiple web sources showing example JSON with danceability field)
- [Flutter asset loading docs](https://docs.flutter.dev/ui/assets/assets-and-images) - HIGH confidence
- [drift 2.31.0 on pub.dev](https://pub.dev/packages/drift) - HIGH confidence (verified current version)
- [drift_flutter 0.2.8 on pub.dev](https://pub.dev/packages/drift_flutter) - HIGH confidence (verified current version)
- [SharedPreferences size recommendations](https://fluttermasterylibrary.com/4/11/2/4/) - MEDIUM confidence (community guidance, not official Flutter team)
- [Running music BPM synchronization research (PLOS One)](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0208702) - HIGH confidence (peer-reviewed)
- [Danceability and running correlation](https://runningwithdata.com/2010/10/15/danceability-and-energy.html) - LOW confidence (old blog post, but aligns with academic research)
- [Curated running song lists (Runner's World, Cosmopolitan, KURU)](https://www.runnersworld.com/uk/training/motivation/a64724042/best-running-songs/) - MEDIUM confidence (editorial picks, useful as seed data)
- Existing codebase analysis (all files read directly) - HIGH confidence
