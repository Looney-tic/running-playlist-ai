# Phase 32: Spotify Search - Research

**Researched:** 2026-02-09
**Domain:** Spotify Web API search integration, composite search services, dual-source UI
**Confidence:** HIGH

## Summary

Phase 32 extends the existing `SongSearchService` abstraction (Phase 30) with Spotify catalog search when the user has a connected Spotify account (Phase 31). The architecture calls for three new components: a `SpotifySongSearchService` that wraps the `spotify` package's search endpoint, a `CompositeSongSearchService` that merges results from both curated and Spotify backends with deduplication, and UI enhancements to show source badges distinguishing curated from Spotify results.

The `spotify` 0.15.0 package (already in pubspec.yaml) provides `SpotifyApi.search.get(query, types: [SearchType.track])` which returns `BundledPages`. Calling `.first(limit)` on BundledPages yields a `List<Page<dynamic>>` where the tracks page contains `Track` objects with `name`, `artists`, `id`, and `uri` fields. Notably, the Spotify search response does NOT include BPM/tempo data -- that requires the now-deprecated Audio Features endpoint. Since audio features is deprecated (November 2024), Spotify search results will have `bpm: null`. This is acceptable: songs from Spotify will get neutral BPM scoring, and curated cross-referencing can fill in BPM for songs that exist in both catalogs.

The mock-first development approach established in Phase 31 continues here. Since we are building with mocks (no Spotify Developer Dashboard credentials yet), the `SpotifySongSearchService` needs both a real implementation (using `SpotifyApi`) and a mock implementation that returns hardcoded results for testing. The `songSearchServiceProvider` will be updated to conditionally return a `CompositeSongSearchService` when Spotify is connected, or the existing `CuratedSongSearchService` when disconnected.

**Primary recommendation:** Create `SpotifySongSearchService` (real + mock), `CompositeSongSearchService`, extend `SongSearchResult` with an optional `spotifyUri` field, and update `songSearchServiceProvider` to check Spotify connection status and return the appropriate service. Add source badges to `_SearchResultTile`. Keep the existing Autocomplete/debounce infrastructure unchanged.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `spotify` | 0.15.0 | Spotify Web API client (search endpoint) | Already in pubspec.yaml, used by Phase 31 auth |
| `flutter_riverpod` | 2.6.1 | Provider wiring for composite search service | Project-wide state management |
| `SongSearchService` | existing | Abstract search interface | Phase 30 extensibility design |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `SpotifyAuthService` | existing | Check connection status, get access token | Conditional Spotify search activation |
| `SongKey.normalize` | existing | Deduplication between curated and Spotify results | Composite service merge logic |
| `CuratedSongSearchService` | existing | Local catalog search | Always active, base of composite |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `CompositeSongSearchService` | Swap provider entirely to Spotify-only when connected | Loses instant local results while Spotify request is in-flight; composite gives curated results immediately and appends Spotify results |
| `spotify` package search | Direct HTTP to Spotify Search API | Loses type-safe models, pagination support, and auth refresh handling |
| Source badge in ListTile | Separate sections (curated / Spotify) | More complex UI, users care about finding songs not their source |

**Installation:**
No new packages needed. All dependencies already in pubspec.yaml.

## Architecture Patterns

### Recommended Project Structure
```
lib/features/
├── song_search/
│   ├── domain/
│   │   └── song_search_service.dart       # + SpotifySongSearchService, CompositeSongSearchService
│   ├── data/
│   │   └── mock_spotify_search_service.dart  # Mock for dev/testing
│   ├── providers/
│   │   └── song_search_providers.dart     # Updated to check Spotify status
│   └── presentation/
│       ├── song_search_screen.dart        # + source badge in result tiles
│       └── highlight_match.dart           # Unchanged
test/features/
├── song_search/
│   └── domain/
│       └── song_search_service_test.dart  # + tests for Spotify + composite services
```

### Pattern 1: SpotifySongSearchService
**What:** Implementation of `SongSearchService` that calls Spotify's search API via `SpotifyApi.search.get()`.
**When to use:** When the user has Spotify connected and a valid access token.
**Example:**
```dart
// Source: spotify 0.15.0 package source (lib/src/endpoints/search.dart)
class SpotifySongSearchService implements SongSearchService {
  SpotifySongSearchService(this._spotifyApi);
  final SpotifyApi _spotifyApi;

  static const _maxResults = 20;

  @override
  Future<List<SongSearchResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];

    final pages = await _spotifyApi.search
        .get(trimmed, types: [SearchType.track])
        .first(_maxResults);

    // pages is List<Page<dynamic>>, find the tracks page
    final trackPage = pages.firstWhere(
      (p) => p.items?.first is Track,
      orElse: () => pages.first,
    );

    return (trackPage.items ?? [])
        .cast<Track>()
        .map((track) => SongSearchResult(
              title: track.name ?? '',
              artist: track.artists?.map((a) => a.name).join(', ') ?? '',
              bpm: null, // Search API does not return BPM
              genre: null,
              source: 'spotify',
              spotifyUri: track.uri,
            ))
        .toList();
  }
}
```

### Pattern 2: CompositeSongSearchService
**What:** Merges results from curated and Spotify services, deduplicating by `SongKey.normalize`.
**When to use:** When Spotify is connected, used as the `songSearchServiceProvider` return value.
**Example:**
```dart
class CompositeSongSearchService implements SongSearchService {
  CompositeSongSearchService({
    required this.curatedService,
    required this.spotifyService,
  });

  final SongSearchService curatedService;
  final SongSearchService spotifyService;

  @override
  Future<List<SongSearchResult>> search(String query) async {
    // Run both searches in parallel
    final results = await Future.wait([
      curatedService.search(query),
      spotifyService.search(query),
    ]);

    final curatedResults = results[0];
    final spotifyResults = results[1];

    // Deduplicate: curated results take priority (they have BPM data)
    final seen = <String>{};
    final merged = <SongSearchResult>[];

    for (final result in curatedResults) {
      final key = SongKey.normalize(result.artist, result.title);
      seen.add(key);
      merged.add(result);
    }

    for (final result in spotifyResults) {
      final key = SongKey.normalize(result.artist, result.title);
      if (!seen.contains(key)) {
        seen.add(key);
        merged.add(result);
      }
    }

    return merged.take(20).toList();
  }
}
```

### Pattern 3: Conditional Provider Wiring
**What:** `songSearchServiceProvider` checks Spotify connection status and returns composite or curated-only service.
**When to use:** Provider layer, reactively switches when Spotify connects/disconnects.
**Example:**
```dart
final songSearchServiceProvider =
    FutureProvider<SongSearchService>((ref) async {
  final songs = await ref.watch(curatedSongsListProvider.future);
  final curatedService = CuratedSongSearchService(songs);

  final spotifyStatus = ref.watch(spotifyConnectionStatusSyncProvider);
  if (spotifyStatus != SpotifyConnectionStatus.connected) {
    return curatedService;
  }

  final authService = ref.read(spotifyAuthServiceProvider);
  final token = await authService.getAccessToken();
  if (token == null) return curatedService;

  final spotifyApi = SpotifyApi.withAccessToken(token);
  final spotifyService = SpotifySongSearchService(spotifyApi);

  return CompositeSongSearchService(
    curatedService: curatedService,
    spotifyService: spotifyService,
  );
});
```

### Pattern 4: Mock Spotify Search Service
**What:** Returns hardcoded/generated results for development without real Spotify credentials.
**When to use:** Default implementation while Spotify Developer Dashboard is unavailable.
**Example:**
```dart
class MockSpotifySongSearchService implements SongSearchService {
  @override
  Future<List<SongSearchResult>> search(String query) async {
    await Future.delayed(const Duration(milliseconds: 200)); // Simulate latency
    final lowerQuery = query.toLowerCase().trim();
    if (lowerQuery.length < 2) return [];

    // Return mock Spotify results that match the query
    return _mockCatalog
        .where((s) =>
            s.title.toLowerCase().contains(lowerQuery) ||
            s.artist.toLowerCase().contains(lowerQuery))
        .take(10)
        .toList();
  }

  static final _mockCatalog = [
    // Hardcoded songs NOT in curated catalog to demonstrate dual-source
    const SongSearchResult(title: 'Mock Spotify Hit', artist: 'Test Artist', source: 'spotify', spotifyUri: 'spotify:track:mock1'),
    // ...
  ];
}
```

### Anti-Patterns to Avoid
- **Creating SpotifyApi on every search call:** The `SpotifyApi` instance should be created once per provider rebuild (when token changes), not per search query. Token refresh is handled by the auth service, not the search service.
- **Fetching audio features during search:** The audio features endpoint is deprecated. Even if it worked, fetching BPM for every search result adds 20 API calls per query. BPM should be null for Spotify results and filled via curated cross-reference when the song is added to the collection.
- **Blocking curated results on Spotify response:** The composite service should run both searches in parallel via `Future.wait`. If Spotify is slow or fails, curated results should still display. Use `Future.wait` with error handling so Spotify failures degrade gracefully.
- **Storing Spotify Track objects in state:** Convert to `SongSearchResult` immediately. The search UI should not depend on spotify package types -- that couples the UI to the API client.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Spotify API HTTP calls | Raw HTTP + JSON parsing for search | `spotify` package `search.get()` | Handles auth headers, pagination, model deserialization, rate limit retries |
| Spotify track model | Custom JSON deserialization | `Track.fromJson` from spotify package | 15+ fields with nested objects, already generated |
| Result deduplication | String-based title matching | `SongKey.normalize` | Existing normalization handles trim, lowercase, pipe-separated key format |
| Debounce/cancel | New debounce logic for Spotify | Existing debounce in `SongSearchScreen` | Already wraps the `SongSearchService.search()` call -- composite service is transparent |

**Key insight:** The Phase 30 `SongSearchService` abstraction was specifically designed for this extension. The search screen's Autocomplete widget, debounce logic, and result tile rendering are all parameterized by `SongSearchResult` -- swapping the service implementation in the provider is the only change needed at the provider/UI layer (plus source badges).

## Common Pitfalls

### Pitfall 1: BundledPages API Confusion
**What goes wrong:** `SpotifyApi.search.get()` returns `BundledPages`, not a list of tracks. Developers try to iterate it directly.
**Why it happens:** The search API returns multiple result types (tracks, artists, albums) bundled together. `BundledPages` requires calling `.first(limit)` to get the first page as `List<Page<dynamic>>`.
**How to avoid:** Always call `.first(N)` on the BundledPages result. Then find the track page from the list (it contains `Track` objects). The pages list has one `Page` per requested `SearchType`.
**Warning signs:** Type errors like `BundledPages is not a List`, empty results despite valid query.

### Pitfall 2: Spotify Track.name vs Track.artists Nullability
**What goes wrong:** Crash on null access when mapping Spotify Track to SongSearchResult.
**Why it happens:** All fields on the spotify `Track` model are nullable (`String?`, `List<Artist>?`). Some tracks have null artist lists or null names (rare but possible for region-restricted content).
**How to avoid:** Always null-check with fallback: `track.name ?? ''`, `track.artists?.map((a) => a.name ?? '').join(', ') ?? 'Unknown Artist'`. Filter out results where both name and artist are empty.
**Warning signs:** Results showing blank titles or "null" as text.

### Pitfall 3: Rate Limiting with Parallel Searches
**What goes wrong:** The composite service fires curated + Spotify searches in parallel. Combined with debounce, fast typing can trigger multiple Spotify API calls within seconds.
**Why it happens:** Debounce prevents rapid-fire, but each debounced query still triggers a Spotify API call. The spotify package has built-in retry for 429 responses (up to 5 retries with backoff), which helps but doesn't prevent the initial rate pressure.
**How to avoid:** The existing 300ms debounce is sufficient for normal usage. The spotify package's `_requestWrapper` already handles 429 with `retryAfter` header. No additional rate limiting needed for search.
**Warning signs:** Console messages about "Spotify API rate exceeded. waiting for N seconds".

### Pitfall 4: SpotifyApi.withAccessToken Does Not Refresh
**What goes wrong:** Using `SpotifyApi.withAccessToken(token)` creates a client with a static token. When the token expires mid-session, search calls fail with 401.
**Why it happens:** `withAccessToken` is a convenience constructor for read-only API access with a known-good token. It has no refresh mechanism.
**How to avoid:** Since the provider rebuilds when Spotify connection status changes, and `getAccessToken()` refreshes if needed, the token passed to `SpotifyApi.withAccessToken()` will be fresh at provider creation time. For long-running sessions, the provider should invalidate when the token expires. Alternatively, the search service can catch 401 and signal the auth service to refresh.
**Warning signs:** Search works initially but fails after ~1 hour with 401 errors.

### Pitfall 5: Deduplication Key Mismatch Between Sources
**What goes wrong:** The same song appears twice in composite results (once from curated, once from Spotify) because the normalized keys differ.
**Why it happens:** Spotify artist names may differ from curated data. Example: curated has "The Weeknd", Spotify returns "The Weeknd" (same) -- but edge cases like "Beyonce" vs "Beyonc\u00e9" or "P!nk" vs "Pink" can cause mismatches.
**How to avoid:** `SongKey.normalize` uses `toLowerCase().trim()` which handles basic differences. For accent differences, accept some duplicates -- perfect dedup is not required. Curated results always appear first, so duplicates from Spotify are lower in the list.
**Warning signs:** Searching for well-known artists shows the same song from both curated and Spotify.

### Pitfall 6: SpotifyException When Disconnected Mid-Search
**What goes wrong:** User starts search while Spotify is connected, token expires or user disconnects mid-search, the in-flight Spotify API call throws SpotifyException.
**Why it happens:** The composite service captured a reference to `SpotifySongSearchService` when the provider was created. If the token becomes invalid between provider creation and the actual API call, the request fails.
**How to avoid:** Wrap the Spotify search in a try-catch that returns an empty list on failure. The composite service should never throw from the Spotify leg -- only log and degrade to curated-only results.
**Warning signs:** Unhandled exceptions in the search flow after disconnecting Spotify.

## Code Examples

### Extracting Tracks from BundledPages
```dart
// Source: spotify 0.15.0 package (endpoints/search.dart, endpoint_paging.dart)
// BundledPages.first(limit) returns List<Page<dynamic>>
final bundledPages = spotifyApi.search.get(query, types: [SearchType.track]);
final pages = await bundledPages.first(20);

// Each page corresponds to a SearchType. For track-only search, there's one page.
if (pages.isNotEmpty) {
  final trackItems = pages.first.items?.cast<Track>() ?? [];
  for (final track in trackItems) {
    print('${track.name} by ${track.artists?.first.name} [${track.uri}]');
  }
}
```

### Extending SongSearchResult with spotifyUri
```dart
class SongSearchResult {
  const SongSearchResult({
    required this.title,
    required this.artist,
    required this.source,
    this.bpm,
    this.genre,
    this.spotifyUri,  // NEW: null for curated, 'spotify:track:...' for Spotify
  });

  final String title;
  final String artist;
  final int? bpm;
  final String? genre;
  final String source;
  final String? spotifyUri;  // Needed for future playlist export (Phase 33+)
}
```

### Source Badge in Search Result Tile
```dart
// Source: Material 3 design pattern for labeled chips
Widget _buildSourceBadge(String source, ThemeData theme) {
  final isSpotify = source == 'spotify';
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: isSpotify
          ? const Color(0xFF1DB954).withValues(alpha: 0.15)  // Spotify green
          : theme.colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      isSpotify ? 'Spotify' : 'Catalog',
      style: theme.textTheme.labelSmall?.copyWith(
        color: isSpotify
            ? const Color(0xFF1DB954)
            : theme.colorScheme.onPrimaryContainer,
      ),
    ),
  );
}
```

### Setting RunningSongSource from SongSearchResult
```dart
// Source: Existing pattern in song_search_screen.dart _addToRunningSongs
void _addToRunningSongs(WidgetRef ref, SongSearchResult result) {
  final songKey = SongKey.normalize(result.artist, result.title);
  ref.read(runningSongProvider.notifier).addSong(
    RunningSong(
      songKey: songKey,
      artist: result.artist,
      title: result.title,
      addedDate: DateTime.now(),
      bpm: result.bpm,
      genre: result.genre,
      source: result.source == 'spotify'
          ? RunningSongSource.spotify
          : RunningSongSource.curated,
    ),
  );
}
```

### Graceful Spotify Failure in Composite Service
```dart
@override
Future<List<SongSearchResult>> search(String query) async {
  // Always get curated results
  final curatedResults = await curatedService.search(query);

  // Try Spotify, degrade gracefully on failure
  List<SongSearchResult> spotifyResults;
  try {
    spotifyResults = await spotifyService.search(query);
  } on Exception catch (_) {
    // Spotify failed -- return curated-only results
    return curatedResults;
  }

  // Merge with deduplication
  return _merge(curatedResults, spotifyResults);
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Audio features for BPM | Deprecated (403 for new apps) | Nov 2024 | Cannot fetch BPM from Spotify; rely on curated cross-reference |
| Spotify search + audio features batch | Search-only, no BPM | Nov 2024 | Simpler search implementation, neutral BPM for Spotify-only songs |
| `spotify` 0.13.x with client credentials | `spotify` 0.15.0 with PKCE auth | Package update | Search requires user auth token (no more anonymous search) |

**Deprecated/outdated:**
- `AudioFeatures` endpoint: Officially deprecated by Spotify (November 2024). The `spotify` 0.15.0 package marks it `@Deprecated`. Do not use it for BPM lookup on search results. The endpoint returns 403 for applications that did not have an existing quota extension.
- Client credentials flow for search: Still technically works, but the project uses PKCE auth (user-level tokens), which also works for search. No need for a separate client credentials flow.

## Open Questions

1. **Token expiration mid-session: should the search service catch 401 and trigger re-auth?**
   - What we know: `SpotifyApi.withAccessToken()` uses a static token. `getAccessToken()` refreshes before returning. The provider rebuilds on Spotify status change.
   - What's unclear: If a user's session lasts longer than the token TTL (1 hour) without triggering a status change, the search service will get 401s.
   - Recommendation: Catch `SpotifyException` with status 401 in the search service and return empty results. The composite service degrades to curated-only. A more robust solution (invalidating the provider or triggering refresh) can be added later if this proves to be a real issue.

2. **Should mock Spotify search return songs that overlap with curated catalog?**
   - What we know: Deduplication needs testing. If mock and curated never overlap, the dedup path is untested.
   - What's unclear: How many mock songs to include, whether to include some curated-catalog songs in mock results.
   - Recommendation: Include 2-3 songs that ARE in the curated catalog plus 5-7 unique "Spotify-only" mock songs. This exercises both the dedup and the unique-result paths.

3. **Should the RunningSong model gain a spotifyUri field for future playlist export?**
   - What we know: `RunningSong` has `source` (curated/spotify/manual) but no URI field. Future playlist export (Phase 33+) will need Spotify URIs.
   - What's unclear: Whether to add it now or defer to the export phase.
   - Recommendation: Defer. Adding `spotifyUri` to `RunningSong` requires JSON migration for persisted data. The `SongSearchResult.spotifyUri` field is sufficient for now -- export can re-search to resolve URIs when needed.

## Sources

### Primary (HIGH confidence)
- `spotify` 0.15.0 package source code (`/Users/tijmen/.pub-cache/hosted/pub.dev/spotify-0.15.0/lib/src/endpoints/search.dart`) - Search.get() signature, BundledPages return type, SearchType enum
- `spotify` 0.15.0 package source code (`/Users/tijmen/.pub-cache/hosted/pub.dev/spotify-0.15.0/lib/src/models/track.dart`) - Track model fields (name, artists, uri, id -- all nullable)
- `spotify` 0.15.0 package source code (`/Users/tijmen/.pub-cache/hosted/pub.dev/spotify-0.15.0/lib/src/endpoints/endpoint_paging.dart`) - BundledPages.first(limit) returns List<Page<dynamic>>
- `spotify` 0.15.0 package source code (`/Users/tijmen/.pub-cache/hosted/pub.dev/spotify-0.15.0/lib/src/endpoints/audio_features.dart`) - @Deprecated annotation confirming deprecation
- Existing codebase: `song_search_service.dart`, `song_search_providers.dart`, `song_search_screen.dart` - Phase 30 search abstraction
- Existing codebase: `spotify_auth_service.dart`, `spotify_auth_providers.dart` - Phase 31 auth infrastructure
- Existing codebase: `running_song.dart` - RunningSongSource enum includes `.spotify` value

### Secondary (MEDIUM confidence)
- [Spotify Web API Search Reference](https://developer.spotify.com/documentation/web-api/reference/search) - No scope required for search, limit 0-50, offset 0-1000
- [Spotify Scopes Documentation](https://developer.spotify.com/documentation/web-api/concepts/scopes) - Search does not require additional scopes
- [Spotify Audio Features Deprecation Blog](https://developer.spotify.com/blog/2024-11-27-changes-to-the-web-api) - Audio features endpoint deprecated Nov 2024

### Tertiary (LOW confidence)
- None. All findings verified against package source code or official documentation.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all dependencies already in pubspec.yaml, search API verified in package source code
- Architecture: HIGH - follows Phase 30 research recommendation verbatim (SpotifySongSearchService + CompositeSongSearchService), existing codebase designed for this extension
- Pitfalls: HIGH - verified BundledPages API in source code, nullability in Track model, audio features deprecation in package annotations, SpotifyException handling in spotify_exception.dart

**Research date:** 2026-02-09
**Valid until:** 2026-03-09 (stable package, no fast-moving dependencies)
