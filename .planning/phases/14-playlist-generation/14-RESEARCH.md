# Phase 14: Playlist Generation - Research

**Researched:** 2026-02-05
**Domain:** Playlist generation algorithm, BPM-to-song matching, taste filtering, external link construction, clipboard integration
**Confidence:** HIGH (algorithm is pure logic on existing models; UI follows established patterns; url_launcher well-documented)

## Summary

Phase 14 transforms the outputs of Phase 12 (taste profile) and Phase 13 (BPM data pipeline) into a complete playlist generation feature. The core algorithm takes a RunPlan (with segments containing target BPMs and durations) and a TasteProfile (genres and artists), queries the BPM lookup system for songs matching each segment's BPM, filters results by taste preferences, and assigns songs to segments until each segment's duration is filled. The UI presents the playlist grouped by segment with song details, and external links enable playback via Spotify or YouTube search URLs.

The most significant architectural challenge is **taste filtering without genre data in the `/tempo/` API response**. The GetSongBPM `/tempo/` endpoint returns songs with artist name but does NOT include genre tags per song. Genre data is only available via the separate `/song/` or `/artist/` endpoints. This means filtering must rely on **artist name matching** from the taste profile, not genre matching. For genre-based filtering, the approach must be heuristic: use the genre preferences to influence song ranking/scoring rather than strict filtering, since genre data would require an additional API call per song.

External links are constructed as search URLs: `https://open.spotify.com/search/{title} {artist}` for Spotify and `https://music.youtube.com/search?q={title} {artist}` for YouTube Music. The `url_launcher` package (already v6.3.2 as a transitive dependency) handles opening these URLs. Clipboard uses Flutter's built-in `Clipboard.setData()` from `services.dart` -- no additional package needed.

**Primary recommendation:** Build the playlist generator as a pure Dart service class that takes RunPlan + TasteProfile + song pool (from BpmLookupNotifier) and returns a Playlist model. Filter by artist name match (from taste profile). Use a greedy duration-filling algorithm: for each segment, select songs matching its BPM and fill until the segment duration is covered. Construct Spotify/YouTube search URLs from song title + artist name.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| url_launcher | ^6.3.2 | Open Spotify/YouTube search URLs externally | Flutter team maintained, already transitive dep, project decision |
| flutter/services.dart | (built-in) | Clipboard.setData() for copy-to-clipboard | Built into Flutter, no package needed |
| flutter_riverpod | ^2.6.1 | State management for playlist generation | Already in project, manual StateNotifier pattern |
| shared_preferences | ^2.5.4 | Persist generated playlists | Already in project, established JSON persistence pattern |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| dart:convert | (built-in) | JSON serialization for playlist persistence | Playlist model toJson/fromJson |
| dart:math | (built-in) | Random shuffling for song selection variety | Shuffle candidate songs before selecting |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Spotify/YouTube search URLs | Spotify API track links | Would require Spotify API auth; search URLs work without auth and cover non-Spotify users |
| Clipboard.setData() | clipboard package | Unnecessary dep; built-in Clipboard class does exactly what we need |
| SharedPreferences for history | SQLite/Drift | Overkill; single JSON blob per playlist matches project pattern |

**Installation:**
```bash
flutter pub add url_launcher
```

This is the ONLY new dependency. url_launcher is already in pubspec.lock as a transitive dependency (v6.3.2) -- adding it to pubspec.yaml promotes it to a direct dependency.

## Architecture Patterns

### Recommended Project Structure

```
lib/features/playlist/
  domain/
    playlist.dart              # Playlist, PlaylistSong models (pure Dart)
    playlist_generator.dart    # Core generation algorithm (pure Dart)
    song_link_builder.dart     # Spotify/YouTube URL construction (pure Dart)
  data/
    playlist_preferences.dart  # SharedPreferences persistence for playlist history
  presentation/
    playlist_screen.dart       # Main generation UI (replaces _ComingSoonScreen)
  providers/
    playlist_providers.dart    # StateNotifier + providers
```

### Pattern 1: Playlist Domain Model

**What:** Immutable data classes representing a generated playlist with songs assigned to segments
**When to use:** Core output of the generation algorithm

```dart
// Pure Dart -- no Flutter imports

/// A song assigned to a specific run segment in the playlist.
class PlaylistSong {
  const PlaylistSong({
    required this.title,
    required this.artistName,
    required this.bpm,
    required this.matchType,
    required this.segmentLabel,
    required this.segmentIndex,
    this.songUri,       // GetSongBPM page URL
    this.spotifyUrl,    // Spotify search URL
    this.youtubeUrl,    // YouTube Music search URL
  });

  final String title;
  final String artistName;
  final int bpm;
  final BpmMatchType matchType;
  final String segmentLabel;
  final int segmentIndex;
  final String? songUri;
  final String? spotifyUrl;
  final String? youtubeUrl;

  // toJson(), fromJson(), copyWith() following project conventions
}

/// A complete generated playlist.
class Playlist {
  const Playlist({
    required this.songs,
    required this.runPlanName,
    required this.totalDurationSeconds,
    required this.createdAt,
  });

  final List<PlaylistSong> songs;
  final String? runPlanName;
  final int totalDurationSeconds;
  final DateTime createdAt;

  // toJson(), fromJson() for persistence
  // toClipboardText() for PLAY-14 copy feature
}
```

### Pattern 2: Playlist Generation Algorithm (Pure Domain Logic)

**What:** Takes RunPlan + TasteProfile + song candidates, returns a Playlist
**When to use:** Core business logic, fully unit-testable

```dart
// Pure Dart -- no Flutter imports, no async dependencies
// All song data is pre-fetched and passed in

class PlaylistGenerator {
  /// Generates a playlist from a run plan, taste profile, and available songs.
  ///
  /// For each segment:
  /// 1. Get songs matching the segment's target BPM (from pre-fetched pool)
  /// 2. Filter/rank by taste profile (artist name match scores higher)
  /// 3. Fill segment duration with selected songs
  /// 4. Avoid repeating songs across segments
  static Playlist generate({
    required RunPlan runPlan,
    required TasteProfile tasteProfile,
    required Map<int, List<BpmSong>> songsByBpm,
  }) {
    // ... algorithm details below
  }
}
```

**Algorithm design (greedy duration-filling):**

1. For each RunSegment in the RunPlan:
   a. Get the target BPM (rounded to int)
   b. Compute BPM queries via BpmMatcher.bpmQueries(targetBpm) to find which BPM keys to look up
   c. Collect all candidate songs from the songsByBpm map for those BPM keys
   d. Score/rank candidates by taste profile match (see Filtering section below)
   e. Shuffle within same-score tiers for variety
   f. Select songs greedily until cumulative song duration >= segment duration
   g. Track used songs to avoid repeats across segments

2. Construct PlaylistSong objects with segment metadata and external URLs

3. Return Playlist with all songs and metadata

**Duration estimation challenge:** The GetSongBPM API does NOT return song duration. A typical song is 3-4 minutes. Use a fixed estimate of 210 seconds (3.5 min) per song for duration filling. This is a pragmatic choice documented as an assumption. The user sees the segment assignment and the total number of songs, which gives a reasonable feel for coverage.

### Pattern 3: Taste Profile Filtering Strategy

**What:** How to filter/rank songs using the taste profile
**When to use:** Within the playlist generator

**Critical insight: The `/tempo/` API endpoint does NOT return genre tags per song result.** It returns artist name, song title, tempo, and URIs. Genre data is only available via the `/song/` or `/artist/` detail endpoints (which would require additional API calls per song).

**Recommended filtering approach (no extra API calls):**

1. **Artist name matching (direct):** If the taste profile contains artist names (e.g., "Eminem", "Taylor Swift"), songs by those artists score highest. Case-insensitive substring match on `BpmSong.artistName`.

2. **No genre filtering at API level:** The `/tempo/` endpoint has no genre parameter. All songs at a BPM are returned regardless of genre.

3. **Song scoring function:**
   ```
   score = 0
   if song.artistName matches any tasteProfile.artists -> score += 10
   if song.matchType == exact -> score += 3
   if song.matchType == halfTime -> score += 1
   if song.matchType == doubleTime -> score += 1
   ```

4. **Shuffle within score tiers** for variety across regenerations.

5. **Fallback:** If no songs match taste preferences at all, use unfiltered BPM matches. A playlist with non-preferred songs is better than no playlist.

**Why not fetch genres per song:** Each `/song/` or `/artist/` API call for genre data would add 1 API call per candidate song. For a 30-min run with ~9 songs across segments, that's manageable, but the pool of candidates (up to 250 songs per BPM value x multiple BPM values) would need many more calls to rank. The rate limit risk is too high, and the latency would be poor.

### Pattern 4: External Link Construction

**What:** Build Spotify and YouTube Music search URLs from song metadata
**When to use:** For PLAY-13 external play links

```dart
// Pure Dart -- no Flutter imports
class SongLinkBuilder {
  /// Builds a Spotify search URL for a song.
  ///
  /// Format: https://open.spotify.com/search/{encoded query}
  /// The Spotify web player / app will show search results for the song.
  static String spotifySearchUrl(String title, String artist) {
    final query = '$title $artist';
    return 'https://open.spotify.com/search/${Uri.encodeComponent(query)}';
  }

  /// Builds a YouTube Music search URL for a song.
  ///
  /// Format: https://music.youtube.com/search?q={encoded query}
  static String youtubeMusicSearchUrl(String title, String artist) {
    final query = '$title $artist';
    final uri = Uri.https('music.youtube.com', '/search', {'q': query});
    return uri.toString();
  }
}
```

**Why search URLs, not direct track links:**
- GetSongBPM returns its own website URIs (e.g., `https://getsongbpm.com/song/...`), NOT Spotify track IDs
- Direct Spotify track links require the Spotify Web API to search and resolve track IDs -- requires auth
- Search URLs work without any API call, open directly in browser/app, and work for both Spotify and YouTube
- If the user has the Spotify/YouTube Music app installed, the search URL will open in-app via deep linking

### Pattern 5: Clipboard Text Formatting

**What:** Format playlist as copyable text for PLAY-14
**When to use:** Copy button on playlist screen

```dart
// Method on Playlist model
String toClipboardText() {
  final buffer = StringBuffer();
  buffer.writeln('Running Playlist - ${runPlanName ?? "My Run"}');
  buffer.writeln('Generated: ${createdAt.toLocal().toString().substring(0, 16)}');
  buffer.writeln();

  String? currentSegment;
  for (final song in songs) {
    if (song.segmentLabel != currentSegment) {
      currentSegment = song.segmentLabel;
      buffer.writeln('--- $currentSegment ---');
    }
    buffer.writeln('${song.title} - ${song.artistName} (${song.bpm} BPM)');
  }
  return buffer.toString();
}
```

**Clipboard usage:**
```dart
import 'package:flutter/services.dart';

await Clipboard.setData(ClipboardData(text: playlist.toClipboardText()));
ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text('Playlist copied to clipboard!')),
);
```

### Anti-Patterns to Avoid

- **Do NOT make additional API calls during generation:** All song data must be pre-fetched via BpmLookupNotifier before generation starts. The generator is a pure synchronous function.
- **Do NOT filter strictly by genre:** Genre data is not available from the `/tempo/` endpoint. Overly strict filtering will result in empty playlists.
- **Do NOT assume song duration is available:** The API does not return duration. Use a fixed estimate (210s = 3.5 min).
- **Do NOT use `canLaunchUrl()` before every `launchUrl()`:** On Android 11+ it requires `<queries>` entries in AndroidManifest.xml. For https URLs, just call `launchUrl()` directly and handle failure.
- **Do NOT hand-roll URL encoding:** Use `Uri.encodeComponent()` or `Uri.https()` for URL construction.
- **Do NOT import Flutter in domain/ files:** `playlist.dart`, `playlist_generator.dart`, and `song_link_builder.dart` must be pure Dart.
- **Do NOT use `@riverpod` code-gen:** Follow the project's manual StateNotifier pattern.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Opening external URLs | Custom platform channels | url_launcher `launchUrl()` | Cross-platform, handles app vs browser, deep linking |
| Clipboard access | Platform channels for clipboard | `Clipboard.setData()` from services.dart | Built into Flutter, simple, well-tested |
| URL encoding | Manual percent-encoding | `Uri.encodeComponent()` / `Uri.https()` | Standard library, handles all edge cases |
| Song duration estimation | Complex audio analysis | Fixed 210s estimate | API doesn't provide duration; estimate is pragmatic |
| Genre matching | NLP-based genre classification | Artist name matching | Genre data unavailable from tempo endpoint |

**Key insight:** The playlist generation algorithm is entirely pure Dart logic. All async work (API calls, cache reads) is done by the existing BpmLookupNotifier BEFORE the generator runs. The generator itself is a synchronous function taking pre-fetched data, making it trivially unit-testable.

## Common Pitfalls

### Pitfall 1: Assuming Genre Data is Available from /tempo/ Endpoint

**What goes wrong:** Trying to filter songs by genre using data from the BPM lookup, but the genre field is not in the response
**Why it happens:** The `/song/` endpoint returns artist.genres, but the `/tempo/` endpoint returns only artist.name (and possibly artist.id/uri). The existing BpmSong model has no genre field.
**How to avoid:** Use artist name matching (from taste profile artists list) as the primary taste filter. Do not rely on genre tags.
**Warning signs:** Null or missing genre field when trying to access it on BpmSong

### Pitfall 2: Song Duration Not Available

**What goes wrong:** Trying to precisely fill segment durations, but API does not provide song length
**Why it happens:** GetSongBPM focuses on BPM/key metadata, not song duration
**How to avoid:** Use a fixed estimate of 210 seconds (3.5 min) per song. Document this assumption. Calculate songs needed per segment as `ceil(segmentDurationSeconds / 210)`.
**Warning signs:** Attempting to fetch duration from a field that doesn't exist

### Pitfall 3: Empty Song Pool for a Segment's BPM

**What goes wrong:** A run segment's target BPM has no songs in the cache/API, resulting in an empty segment
**Why it happens:** Unusual BPM values (very low warm-up BPMs like 100-120), or API coverage gaps
**How to avoid:**
1. Use half/double-time matching (already in BpmMatcher) to expand the pool
2. Show a clear message for segments with no available songs
3. Consider falling back to the nearest BPM with results
**Warning signs:** Segments showing "No songs available" consistently

### Pitfall 4: Song Repetition Across Segments

**What goes wrong:** The same song appears in multiple segments (e.g., warm-up and cool-down both at similar BPMs share the same candidates)
**Why it happens:** Different segments query overlapping BPM values (e.g., warm-up at 136 BPM and cool-down at 136 BPM query the same songs)
**How to avoid:** Track selected songs in a Set<String> keyed by songId. Skip already-selected songs when filling subsequent segments.
**Warning signs:** User sees duplicate songs in different segments of their playlist

### Pitfall 5: Android `<queries>` Missing for URL Launching

**What goes wrong:** `canLaunchUrl()` returns false for HTTPS URLs on Android 11+, or external apps don't open
**Why it happens:** Android 11+ requires declaring URL schemes in `<queries>` in AndroidManifest.xml
**How to avoid:** Add intent queries for https and spotify schemes in AndroidManifest.xml. Or better: skip `canLaunchUrl()` and just call `launchUrl()` directly, catching failures.
**Warning signs:** "Could not launch URL" errors only on Android 11+ devices

### Pitfall 6: iOS LSApplicationQueriesSchemes Missing for Spotify

**What goes wrong:** `canLaunchUrl()` returns false for `spotify:` scheme on iOS
**Why it happens:** iOS requires declaring schemes in `LSApplicationQueriesSchemes` in Info.plist
**How to avoid:** Since we use `https://open.spotify.com/search/...` URLs (not `spotify:` scheme), this is NOT an issue. HTTPS URLs work without any Info.plist configuration. Only add `LSApplicationQueriesSchemes` if using `spotify:` deep link scheme.
**Warning signs:** Only relevant if switching to `spotify:` URIs (not planned)

### Pitfall 7: Overly Strict Taste Filtering Producing Empty Playlists

**What goes wrong:** No songs match the taste profile, resulting in an empty playlist
**Why it happens:** Filtering requires exact artist name match from a list of 0-10 artists against a pool that may not contain those artists at the target BPM
**How to avoid:** Taste filtering is a RANKING signal, not a hard filter. Always fall back to unfiltered BPM matches. A playlist with non-preferred songs is better than no playlist.
**Warning signs:** Playlist shows 0 songs despite BPM lookup returning results

### Pitfall 8: Pre-fetching Songs for All Segment BPMs Before Generation

**What goes wrong:** Generation starts but some segments lack song data because not all BPMs were pre-fetched
**Why it happens:** BpmLookupNotifier only tracks one targetBpm at a time. A multi-segment run plan has different BPMs per segment.
**How to avoid:** Before generation, iterate all unique segment BPMs in the run plan and ensure each one has been looked up. The playlist generation notifier should orchestrate this as a batch operation, calling lookupByBpm for each unique BPM.
**Warning signs:** Some segments have songs but others show empty

## Code Examples

### Launching a URL with url_launcher

```dart
// Source: url_launcher 6.3.2 pub.dev example
import 'package:url_launcher/url_launcher.dart';

Future<void> _openSpotifySearch(String title, String artist) async {
  final query = Uri.encodeComponent('$title $artist');
  final url = Uri.parse('https://open.spotify.com/search/$query');

  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
    // Handle failure -- show snackbar or fallback to YouTube
  }
}
```

### Clipboard Copy

```dart
// Source: Flutter services.dart API
import 'package:flutter/services.dart';

Future<void> _copyPlaylist(Playlist playlist) async {
  await Clipboard.setData(ClipboardData(text: playlist.toClipboardText()));
  // Show confirmation snackbar
}
```

### Duration-Filling Song Selection

```dart
// Pure Dart -- core algorithm pattern
List<PlaylistSong> _fillSegment({
  required RunSegment segment,
  required int segmentIndex,
  required List<BpmSong> candidates,
  required Set<String> usedSongIds,
  required TasteProfile tasteProfile,
}) {
  // Score and sort candidates
  final scored = candidates
      .where((s) => !usedSongIds.contains(s.songId))
      .map((s) => _ScoredSong(s, _scoreSong(s, tasteProfile)))
      .toList()
    ..sort((a, b) => b.score.compareTo(a.score));

  // Fill until segment duration is covered
  const estimatedSongDuration = 210; // 3.5 min average
  final songsNeeded = (segment.durationSeconds / estimatedSongDuration).ceil();
  final selected = scored.take(songsNeeded.clamp(1, scored.length));

  for (final s in selected) {
    usedSongIds.add(s.song.songId);
  }

  return selected.map((s) => PlaylistSong(
    title: s.song.title,
    artistName: s.song.artistName,
    bpm: s.song.tempo,
    matchType: s.song.matchType,
    segmentLabel: segment.label ?? 'Segment ${segmentIndex + 1}',
    segmentIndex: segmentIndex,
    spotifyUrl: SongLinkBuilder.spotifySearchUrl(s.song.title, s.song.artistName),
    youtubeUrl: SongLinkBuilder.youtubeMusicSearchUrl(s.song.title, s.song.artistName),
    songUri: s.song.songUri,
  )).toList();
}
```

### Batch BPM Lookup for Multi-Segment Plans

```dart
// Pattern for pre-fetching all BPMs needed by a run plan
Future<Map<int, List<BpmSong>>> _fetchAllSegmentSongs(
  RunPlan plan,
  BpmLookupNotifier lookupNotifier,
) async {
  final songsByBpm = <int, List<BpmSong>>{};

  // Collect unique target BPMs across all segments
  final uniqueBpms = plan.segments
      .map((s) => s.targetBpm.round())
      .toSet();

  for (final targetBpm in uniqueBpms) {
    await lookupNotifier.lookupByBpm(targetBpm);
    // After lookup, songs are in lookupNotifier.state.songs
    // But we need to collect per-BPM results...
  }

  return songsByBpm;
}
```

**Note on batch lookup design:** The current BpmLookupNotifier is designed for single-BPM lookups and replaces state each time. For playlist generation, the notifier pattern needs adaptation. Two approaches:

1. **Separate PlaylistGenerationNotifier** that internally calls the GetSongBpmClient directly (not through BpmLookupNotifier) for each unique BPM, using cache-first strategy, and accumulates results. This is cleaner.

2. **Reuse BpmLookupNotifier** but collect results after each call. This is fragile since state replacement loses previous results.

**Recommended: Approach 1** -- The PlaylistGenerationNotifier should use GetSongBpmClient + BpmCachePreferences directly, bypassing BpmLookupNotifier. This gives full control over batching and result accumulation.

## Platform Configuration Required

### Android (AndroidManifest.xml)

For `url_launcher` to work with `canLaunchUrl()` on Android 11+, add queries for HTTPS intent. However, since we use `launchUrl()` directly (not `canLaunchUrl()`), this is optional but recommended:

```xml
<!-- Add inside <queries> in android/app/src/main/AndroidManifest.xml -->
<queries>
    <!-- Existing text processing intent -->
    <intent>
        <action android:name="android.intent.action.PROCESS_TEXT"/>
        <data android:mimeType="text/plain"/>
    </intent>
    <!-- For url_launcher HTTPS support -->
    <intent>
        <action android:name="android.intent.action.VIEW"/>
        <category android:name="android.intent.category.BROWSABLE"/>
        <data android:scheme="https"/>
    </intent>
</queries>
```

### iOS (Info.plist)

No changes needed. We use HTTPS URLs (not custom schemes like `spotify:`), which work without `LSApplicationQueriesSchemes`.

### macOS (Entitlements)

Already configured in Phase 13 with `com.apple.security.network.client` for HTTP requests. url_launcher on macOS uses the system's default URL handler, which doesn't require additional entitlements.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `launch(String)` | `launchUrl(Uri, {mode})` | url_launcher 6.1+ | Type-safe, platform-neutral launch modes |
| `canLaunch(String)` | `canLaunchUrl(Uri)` | url_launcher 6.1+ | Returns false on Android 11+ without queries |
| Spotify track IDs | Search URLs | N/A (project choice) | No Spotify API auth needed |
| Custom clipboard plugins | `Clipboard.setData()` | Always available | Built into Flutter, no deps |

**Deprecated/outdated:**
- `launch()` and `canLaunch()` (string-based): Deprecated since url_launcher 6.1. Use `launchUrl()` and `canLaunchUrl()` (Uri-based).
- `forceSafariVC` / `forceWebView` parameters: Replaced by `LaunchMode` enum.

## Open Questions

1. **Does the `/tempo/` endpoint return artist genres?**
   - What we know: The `/song/` endpoint returns `artist.genres` as an array. The existing BpmSong model does NOT parse genres. The `/tempo/` endpoint response structure is partially documented.
   - What's unclear: Whether the `/tempo/` endpoint includes the `genres` array in its nested artist object
   - Recommendation: During implementation, make a live API call to `/tempo/` and inspect the response. If genres ARE present, add a `genres` field to BpmSong and use it for taste filtering. If not (likely), proceed with artist-name-only filtering as described above. **Do not block on this** -- the artist-name approach works either way.

2. **Song duration from GetSongBPM API**
   - What we know: The `/song/` detail endpoint might return duration, but the `/tempo/` endpoint does not.
   - What's unclear: Whether any endpoint returns song duration in seconds/milliseconds
   - Recommendation: Use the 210-second (3.5 min) fixed estimate. This is adequate for a v1 feature. Precise duration filling is a future optimization.

3. **Rate limits for batch BPM lookups**
   - What we know: No documented rate limits. Cache-first strategy mitigates most calls. A typical run plan has 1-10 unique BPM values.
   - What's unclear: Whether rapid successive API calls (for multiple segment BPMs) will trigger throttling
   - Recommendation: Add a small delay (300ms) between API calls for uncached BPMs. Cache hits have no delay.

4. **Spotify search URL format stability**
   - What we know: `https://open.spotify.com/search/{query}` works as of 2026
   - What's unclear: Whether Spotify will maintain this URL format long-term
   - Recommendation: Encapsulate URL construction in `SongLinkBuilder` so the format can be updated in one place. This is already in the recommended architecture.

## Sources

### Primary (HIGH confidence)
- Existing codebase: `lib/features/bpm_lookup/` -- BpmSong model, BpmMatcher, BpmLookupNotifier, BpmCachePreferences, GetSongBpmClient
- Existing codebase: `lib/features/run_plan/domain/run_plan.dart` -- RunPlan, RunSegment, formatDuration
- Existing codebase: `lib/features/taste_profile/domain/taste_profile.dart` -- TasteProfile, RunningGenre, EnergyLevel
- Existing codebase: `lib/features/taste_profile/providers/taste_profile_providers.dart` -- TasteProfileNotifier pattern
- Existing codebase: `lib/app/router.dart` -- GoRouter with '/playlist' route
- `pubspec.lock` -- url_launcher 6.3.2 already transitive dependency
- `test/features/bpm_lookup/data/getsongbpm_client_test.dart` -- confirmed `/tempo/` response format with `song_uri` as GetSongBPM page URL
- [pub.dev url_launcher changelog](https://pub.dev/packages/url_launcher/changelog) -- latest version 6.3.2, launchUrl API
- [Flutter Clipboard API](https://api.flutter.dev/flutter/services/Clipboard-class.html) -- Clipboard.setData() built-in

### Secondary (MEDIUM confidence)
- [Spotify developer docs](https://developer.spotify.com/documentation/web-api/concepts/spotify-uris-ids) -- Spotify search URL format: `https://open.spotify.com/search/{query}`
- [GetSongBPM API documentation](https://getsongbpm.com/api) -- API authentication, endpoint structure, response fields
- Phase 13 RESEARCH.md -- API response format for `/tempo/` endpoint (MEDIUM confidence)
- [url_launcher pub.dev example](https://pub.dev/packages/url_launcher/example) -- launchUrl with LaunchMode, canLaunchUrl usage
- YouTube Music search URL format: `https://music.youtube.com/search?q={query}`

### Tertiary (LOW confidence)
- Song duration from GetSongBPM: no evidence found that `/tempo/` returns duration; assumption of non-availability
- Genre data in `/tempo/` response: no evidence of genres field; assumption based on existing BpmSong model lacking genres

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- url_launcher well-documented, all other deps already in project
- Architecture: HIGH -- follows exact patterns from existing features (run_plan, taste_profile, bpm_lookup)
- Playlist algorithm: HIGH -- pure Dart logic, well-defined inputs/outputs, fully unit-testable
- Taste filtering approach: MEDIUM -- constrained by API limitations; artist-name matching is pragmatic but not ideal
- External link construction: MEDIUM -- Spotify/YouTube search URL formats verified but could change
- Platform configuration: HIGH -- verified by reading actual manifest/plist files
- Pitfalls: HIGH -- identified from codebase analysis and API research

**Research date:** 2026-02-05
**Valid until:** 2026-03-05 (stable domain; url_launcher and Flutter APIs are mature)
