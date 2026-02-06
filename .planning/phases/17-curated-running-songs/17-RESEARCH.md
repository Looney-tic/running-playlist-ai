# Phase 17: Curated Running Songs - Research

**Researched:** 2026-02-06
**Domain:** Bundled data assets, Supabase remote data, scoring integration
**Confidence:** HIGH

## Summary

Phase 17 adds a curated dataset of verified-good running songs that boosts playlist quality through the existing SongQualityScorer. The phase requires: (1) a domain model for curated songs with genre, BPM, and danceability metadata, (2) a bundled JSON asset with 200-500 songs covering all 15 RunningGenre values, (3) integration into the scoring pipeline as a bonus (not filter), and (4) remote refresh from Supabase without app store releases.

The codebase already has all required infrastructure: `supabase_flutter: ^2.12.0` initialized in main.dart, `SongQualityScorer` with public weight constants ready for a curated bonus dimension, `PlaylistGenerator` that delegates scoring, `BpmSong` with fromJson/toJson serialization, Flutter asset bundling via pubspec.yaml, and SharedPreferences for local caching with TTL patterns.

**Primary recommendation:** Create a `CuratedSong` model, a `CuratedSongRepository` with bundled-asset-first + Supabase-refresh strategy, add a `curatedBonus` weight to `SongQualityScorer`, and inject curated lookup into `PlaylistGenerator` during the scoring phase. Cache Supabase responses in SharedPreferences with TTL to avoid repeated network calls.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| supabase_flutter | ^2.12.0 | Remote curated song table reads | Already in pubspec.yaml and initialized |
| shared_preferences | ^2.5.4 | Local cache for remote curated data | Already used for all persistence in the app |
| flutter/services (rootBundle) | SDK | Load bundled JSON asset | Standard Flutter asset loading, no extra dependency |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| dart:convert (jsonDecode) | SDK | Parse JSON from asset and Supabase | Always -- standard JSON parsing |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SharedPreferences cache | Hive/Isar local DB | Overkill for a single JSON blob; SharedPreferences matches all existing patterns |
| Supabase table | Firebase Remote Config | Would add a new dependency; Supabase already initialized |
| Bundled JSON asset | SQLite with pre-populated DB | Unnecessary complexity; JSON is simpler and fits the existing BpmSong.fromJson pattern |

**Installation:** No new packages needed. All dependencies already in pubspec.yaml.

## Architecture Patterns

### Recommended Project Structure

```
lib/features/curated_songs/
  domain/
    curated_song.dart              # CuratedSong model (pure Dart)
  data/
    curated_song_repository.dart   # Bundled asset + Supabase + cache
  providers/
    curated_song_providers.dart    # Riverpod provider
```

### Pattern 1: Bundled Asset with Remote Refresh (CURA-01, CURA-03)

**What:** Ship a JSON asset with the app. On startup or playlist generation, check Supabase for a newer version. Cache the remote version in SharedPreferences. Fall back to bundled asset if offline.

**When to use:** When you need guaranteed offline data (bundled) plus the ability to update without app releases (Supabase).

**Data flow:**
```
1. Load from SharedPreferences cache (check TTL)
2. If cache valid -> use cached data
3. If cache expired/empty -> try Supabase fetch
4. If Supabase succeeds -> save to SharedPreferences, use fresh data
5. If Supabase fails -> load bundled JSON asset as fallback
```

**Key insight:** The bundled asset is the ultimate fallback -- the app ALWAYS has curated data, even on first launch offline. Supabase is the refresh mechanism, not the primary source.

### Pattern 2: Scoring Bonus Integration (CURA-02)

**What:** Add a `curatedBonus` weight constant to `SongQualityScorer`. During scoring, check if the candidate song matches a curated song (by song ID, or by artist+title). If so, add the bonus.

**When to use:** When scoring candidates in `PlaylistGenerator._scoreAndRank()`.

**Integration point:** `SongQualityScorer.score()` already takes `BpmSong` and returns an int. Add a new optional parameter `bool isCurated` (or `int curatedBonus`) and a new `static const curatedBonusWeight` constant. This matches the existing pattern of all weights being public static const.

**Scoring math:**
- Current max score: 31 points (artist=10, danceability=8, genre=6, energy=4, BPM=3)
- Recommended curated bonus: +5 points
- New max score: 36 points
- Curated songs score 5 points higher than equivalent non-curated songs
- This is meaningful (16% boost) but not dominant -- a non-curated song with artist match (+10) still outranks a curated song without artist match

### Pattern 3: Curated Song Lookup During Generation (CURA-02)

**What:** Before scoring, build a lookup Set of curated song identifiers. During scoring, check membership. This avoids O(n*m) matching.

**When to use:** In `PlaylistGenerator.generate()`, load curated songs once, build lookup, pass to scorer.

**Lookup strategy:** Use a `Set<String>` of normalized `"artist|title"` keys (lowercase, trimmed). This works because curated songs may not have the same `songId` as API-discovered songs -- the GetSongBPM API assigns its own IDs. Artist+title matching is the reliable cross-source identifier.

### Pattern 4: Version-Based Supabase Refresh (CURA-03, CURA-04)

**What:** Store a `version` integer alongside the curated dataset in both Supabase and the local cache. When checking for updates, compare version numbers instead of re-downloading the full dataset every time.

**When to use:** To minimize network traffic while still ensuring freshness.

**Supabase table design:**
```sql
CREATE TABLE curated_songs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  artist_name TEXT NOT NULL,
  genre TEXT NOT NULL,
  bpm INT NOT NULL,
  danceability INT,
  energy_level TEXT,  -- 'chill', 'balanced', 'intense'
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE curated_songs_version (
  id INT PRIMARY KEY DEFAULT 1,
  version INT NOT NULL DEFAULT 1,
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

**RLS Policy:** Enable RLS, create a SELECT-only policy for the `anon` role. No authentication needed for read-only curated data.

### Anti-Patterns to Avoid

- **Curated data as a filter:** Curated must be a BOOST to scoring, not a filter that excludes non-curated songs. The requirements explicitly state "non-curated songs still appear."
- **Matching by songId only:** GetSongBPM song IDs are API-specific. Curated songs identified by title+artist, not by songId, for cross-source matching.
- **Fetching from Supabase on every playlist generation:** Cache with TTL (24h recommended). Don't hit the network every time.
- **Large single JSON field in Supabase:** Use proper rows in a table, not a single JSON column. This supports CURA-04 (future expansion) and allows incremental queries.
- **Flutter import in domain model:** CuratedSong must be pure Dart (no Flutter services import). Only the repository/data layer uses rootBundle.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON asset loading | Custom file reader | `rootBundle.loadString('assets/curated_songs.json')` + `jsonDecode()` | Flutter's standard asset pipeline handles platform differences |
| Supabase table query | Raw HTTP client | `Supabase.instance.client.from('curated_songs').select()` | Already initialized, handles auth tokens, RLS |
| Local caching with TTL | SQLite or custom file cache | SharedPreferences with timestamp (same pattern as BpmCachePreferences) | Established project pattern, consistent with all other caching |
| Case-insensitive matching | Custom normalizer | `.toLowerCase().trim()` | Simple and sufficient for artist+title matching |

**Key insight:** Every infrastructure piece already exists in the project. This phase is primarily about creating a domain model, a data layer, and wiring into the existing scorer -- not building new infrastructure.

## Common Pitfalls

### Pitfall 1: Curated Bonus Too Strong or Too Weak

**What goes wrong:** If the curated bonus is too high, playlists become "curated only" and non-curated songs never appear. If too low, the curated dataset has no observable effect.
**Why it happens:** The existing scoring range is 2-31 points. A bonus must be meaningful relative to this range.
**How to avoid:** Use +5 curated bonus. This is less than artist match (+10) and genre match (+6), so user taste still dominates. But it is more than BPM accuracy (+3 vs +1), so curated songs get a noticeable lift. Test with a playlist generation where curated and non-curated songs compete at the same BPM.
**Warning signs:** If all playlist songs are curated, bonus is too high. If zero curated songs appear despite being BPM-matched, bonus is too low.

### Pitfall 2: Bundled Asset Not Declared in pubspec.yaml

**What goes wrong:** `rootBundle.loadString()` throws a FlutterError at runtime because the asset is not registered.
**Why it happens:** Forgetting to add the asset path to the `flutter.assets` section of pubspec.yaml.
**How to avoid:** Add `- assets/curated_songs.json` to pubspec.yaml alongside the existing `- .env` entry. Verify by running the app.
**Warning signs:** Runtime exception on first load, not a compile error.

### Pitfall 3: Genre Coverage Gaps

**What goes wrong:** Some genres in RunningGenre enum have zero curated songs, violating "covers all supported genres."
**Why it happens:** Harder to find verified running songs for niche genres (Drum & Bass, K-Pop, Funk/Disco).
**How to avoid:** The curated dataset JSON must include at least 10 songs per genre. With 15 genres and 200-500 songs, that is 13-33 per genre. Budget approximately equal distribution.
**Warning signs:** Write a test that loads the bundled JSON and asserts every RunningGenre has at least N entries.

### Pitfall 4: Supabase Table Not Set Up

**What goes wrong:** App tries to fetch from Supabase, gets a 404 or permission error, and user gets no curated songs.
**Why it happens:** The table must be created in Supabase and RLS policies configured before the app tries to read.
**How to avoid:** Document Supabase setup as a USER-SETUP requirement. The bundled asset fallback ensures the app works even if Supabase is not configured.
**Warning signs:** Supabase fetch returning empty or error in production.

### Pitfall 5: CuratedSong Model Drift Between Bundled and Supabase

**What goes wrong:** The bundled JSON uses one field naming convention, Supabase uses another, and deserialization breaks.
**Why it happens:** JSON from rootBundle uses Dart camelCase, Supabase tables use snake_case.
**How to avoid:** Use a single `CuratedSong.fromJson()` factory that handles both formats, OR normalize in the repository layer (convert Supabase snake_case to camelCase before passing to fromJson). The simpler approach: use camelCase in both the bundled JSON and a Supabase JSON column, or use two separate factory methods (`fromAssetJson`, `fromSupabaseRow`).
**Warning signs:** Null field errors when loading from one source but not the other.

### Pitfall 6: Artist+Title Matching False Positives

**What goes wrong:** Two different songs with the same title by different artists, or covers, create false curated matches.
**Why it happens:** Artist+title is not a unique identifier in all cases.
**How to avoid:** Normalize both artist AND title for the lookup key: `"${artist.toLowerCase().trim()}|${title.toLowerCase().trim()}"`. This combined key is sufficiently unique for 200-500 songs. If future expansion to thousands of songs is needed, consider adding BPM as a third key component.
**Warning signs:** Songs being marked as curated when they are actually different tracks.

## Code Examples

### CuratedSong Model (Pure Dart)

```dart
/// A curated running song verified as good for running.
class CuratedSong {
  const CuratedSong({
    required this.title,
    required this.artistName,
    required this.genre,
    required this.bpm,
    this.danceability,
    this.energyLevel,
  });

  factory CuratedSong.fromJson(Map<String, dynamic> json) {
    return CuratedSong(
      title: json['title'] as String,
      artistName: json['artistName'] as String,
      genre: json['genre'] as String,
      bpm: (json['bpm'] as num).toInt(),
      danceability: (json['danceability'] as num?)?.toInt(),
      energyLevel: json['energyLevel'] as String?,
    );
  }

  /// Parses from Supabase row (snake_case columns).
  factory CuratedSong.fromSupabaseRow(Map<String, dynamic> row) {
    return CuratedSong(
      title: row['title'] as String,
      artistName: row['artist_name'] as String,
      genre: row['genre'] as String,
      bpm: (row['bpm'] as num).toInt(),
      danceability: (row['danceability'] as num?)?.toInt(),
      energyLevel: row['energy_level'] as String?,
    );
  }

  final String title;
  final String artistName;
  final String genre;
  final int bpm;
  final int? danceability;
  final String? energyLevel;

  /// Normalized lookup key for matching against BpmSong candidates.
  String get lookupKey =>
      '${artistName.toLowerCase().trim()}|${title.toLowerCase().trim()}';

  Map<String, dynamic> toJson() => {
        'title': title,
        'artistName': artistName,
        'genre': genre,
        'bpm': bpm,
        if (danceability != null) 'danceability': danceability,
        if (energyLevel != null) 'energyLevel': energyLevel,
      };
}
```

### Loading Bundled JSON Asset

```dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

Future<List<CuratedSong>> loadBundledCuratedSongs() async {
  final jsonString = await rootBundle.loadString('assets/curated_songs.json');
  final jsonList = jsonDecode(jsonString) as List<dynamic>;
  return jsonList
      .map((item) => CuratedSong.fromJson(item as Map<String, dynamic>))
      .toList();
}
```

### Supabase Fetch

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<List<CuratedSong>> fetchCuratedSongsFromSupabase() async {
  final response = await Supabase.instance.client
      .from('curated_songs')
      .select();
  return (response as List<dynamic>)
      .map((row) => CuratedSong.fromSupabaseRow(row as Map<String, dynamic>))
      .toList();
}
```

### SharedPreferences Cache (Following BpmCachePreferences Pattern)

```dart
class CuratedSongCachePreferences {
  static const _key = 'curated_songs_cache';
  static const _versionKey = 'curated_songs_version';
  static const cacheTtl = Duration(hours: 24);

  static Future<List<CuratedSong>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return null;

    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    final cachedAt = DateTime.parse(json['cachedAt'] as String);
    if (DateTime.now().difference(cachedAt) > cacheTtl) return null;

    final songs = (json['songs'] as List<dynamic>)
        .map((s) => CuratedSong.fromJson(s as Map<String, dynamic>))
        .toList();
    return songs;
  }

  static Future<void> save(List<CuratedSong> songs) async {
    final prefs = await SharedPreferences.getInstance();
    final json = {
      'cachedAt': DateTime.now().toIso8601String(),
      'songs': songs.map((s) => s.toJson()).toList(),
    };
    await prefs.setString(_key, jsonEncode(json));
  }
}
```

### Scorer Integration

```dart
// In SongQualityScorer, add:
static const curatedBonusWeight = 5;

// In score() method, add new parameter:
static int score({
  required BpmSong song,
  // ... existing params ...
  bool isCurated = false,
}) {
  var total = 0;
  // ... existing dimensions ...
  total += _curatedBonus(isCurated);
  return total;
}

static int _curatedBonus(bool isCurated) {
  return isCurated ? curatedBonusWeight : 0;
}
```

### Lookup Set in PlaylistGenerator

```dart
// In PlaylistGenerator.generate(), before segment loop:
final curatedLookup = curatedSongs
    .map((s) => '${s.artistName.toLowerCase().trim()}|${s.title.toLowerCase().trim()}')
    .toSet();

// In _scoreAndRank(), when scoring each candidate:
final isCurated = curatedLookup.contains(
  '${song.artistName.toLowerCase().trim()}|${song.title.toLowerCase().trim()}'
);
final score = SongQualityScorer.score(
  song: song,
  isCurated: isCurated,
  // ... other params ...
);
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| rootBundle only | rootBundle + SharedPreferences cache | Established pattern in this project | Consistent with BpmCachePreferences |
| Firebase Remote Config | Supabase table reads | Project decision (Supabase already initialized) | No new dependency needed |
| Single bundled dataset | Bundled fallback + remote refresh | Standard for apps needing both offline and updates | Meets CURA-01 + CURA-03 |

## Open Questions

### 1. Curated Song Data Source

- **What we know:** We need 200-500 verified running songs covering all 15 RunningGenre values with BPM data.
- **What's unclear:** Where does the actual curated song data come from? The planner will need to either generate a representative dataset or the user needs to provide one.
- **Recommendation:** Create a realistic but representative JSON dataset using well-known running songs across genres with accurate BPM values. Sources like GetSongBPM's own running page, popular running playlists, and "best running songs by BPM" lists can inform the selection. The bundled JSON is the minimum viable dataset; it can be expanded via Supabase later.

### 2. Supabase Table Creation Timing

- **What we know:** The app already has Supabase initialized with URL and anon key from .env.
- **What's unclear:** Whether the Supabase project already has tables set up, or if table creation is a manual user step.
- **Recommendation:** Document table creation SQL as a USER-SETUP step. The app should gracefully handle Supabase table not existing (fall back to bundled asset). This matches the existing pattern where GETSONGBPM_API_KEY is documented as a user setup requirement.

### 3. PlaylistGenerator Signature Change

- **What we know:** `PlaylistGenerator.generate()` is a static method. Adding curated song data requires passing it in.
- **What's unclear:** Whether to pass `Set<String>` curated lookup, or `List<CuratedSong>`, or a `CuratedSongRepository`.
- **Recommendation:** Pass `Set<String>` curatedLookupKeys as an optional parameter to `generate()`. This keeps the generator pure (no async, no repository dependency). The provider layer resolves curated data and builds the lookup set before calling `generate()`. This matches the existing pattern where `songsByBpm` is pre-resolved before generation.

## Sources

### Primary (HIGH confidence)

- **Codebase analysis:** Direct reading of all key files (song_quality_scorer.dart, playlist_generator.dart, bpm_song.dart, taste_profile.dart, main.dart, pubspec.yaml, auth_repository.dart, bpm_cache_preferences.dart, playlist_providers.dart)
- **[Supabase Flutter Docs - select()](https://supabase.com/docs/reference/dart/select)** - Verified fetch API returns `List<Map<String, dynamic>>`
- **[Flutter Asset Docs](https://docs.flutter.dev/ui/assets/assets-and-images)** - Verified rootBundle.loadString() pattern for JSON assets
- **[Supabase Flutter Quickstart](https://supabase.com/docs/guides/getting-started/quickstarts/flutter)** - Verified initialization pattern already matches main.dart

### Secondary (MEDIUM confidence)

- **[Supabase RLS Docs](https://supabase.com/docs/guides/database/postgres/row-level-security)** - RLS SELECT policy for anon role allows public read-only access
- **[Flutter rootBundle API](https://api.flutter.dev/flutter/services/AssetBundle-class.html)** - loadString() for text assets, loadStructuredData for parsed

### Tertiary (LOW confidence)

- **Curated bonus weight of +5:** Based on analysis of existing scoring weights and what creates a meaningful-but-not-dominant boost. Needs tuning validation with real playlists.
- **24-hour cache TTL for Supabase refresh:** Reasonable default, but optimal value depends on how frequently curated data actually changes. Could be longer (7 days like BPM cache).

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in pubspec.yaml, patterns verified in codebase
- Architecture: HIGH - Follows established feature/domain/data/provider patterns from existing codebase
- Scoring integration: HIGH - SongQualityScorer.score() extensible by design (public weights, optional params)
- Pitfalls: MEDIUM - Based on codebase analysis and common Flutter patterns, not battle-tested
- Curated data source: LOW - Dataset content is a creative/editorial task, not a technical one

**Research date:** 2026-02-06
**Valid until:** 2026-03-06 (30 days -- stable domain, no fast-moving dependencies)
