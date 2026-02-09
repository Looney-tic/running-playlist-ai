# Phase 33: Spotify Playlist Import - Research

**Researched:** 2026-02-09
**Domain:** Spotify Web API playlist endpoints, playlist browsing UI, batch song import to "Songs I Run To"
**Confidence:** HIGH

## Summary

Phase 33 enables users to browse their Spotify playlists and selectively import songs into the "Songs I Run To" collection. The `spotify` 0.15.0 package already provides all the needed API surface: `Playlists.me` returns `Pages<PlaylistSimple>` for listing the user's playlists, and `Playlists.getPlaylistTracks(playlistId)` returns `Pages<PlaylistTrack>` for fetching tracks within a playlist. Both endpoints use the offset-based pagination pattern (`Pages<T>`) where `.first(limit)` fetches the first page and `.all(limit)` fetches all items across pages.

A critical gap exists in the current OAuth scopes: `spotify_constants.dart` does NOT include `playlist-read-private` or `playlist-read-collaborative`. These are required by the Spotify Web API for `GET /me/playlists` and `GET /playlists/{id}/tracks`. Without these scopes, the endpoints will only return public playlists (and may return 403 for private ones). The scopes string must be updated before this feature ships, though since we are building with mocks (Spotify Developer Dashboard unavailable), this is a non-blocking code change that can be verified later.

The import flow maps cleanly to existing patterns: each imported Spotify track becomes a `RunningSong` with `source: RunningSongSource.spotify`, keyed via `SongKey.normalize`. The `RunningSongNotifier.addSong()` method handles persistence. Deduplication uses the same `songKey` mechanism already proven in the song search flow. Since Spotify tracks do not include BPM data (audio features deprecated Nov 2024), imported songs will have `bpm: null` -- they benefit from curated catalog cross-referencing if the same song exists there, and receive neutral BPM scoring otherwise.

**Primary recommendation:** Build a `SpotifyPlaylistService` abstraction (abstract class + mock) following the established mock-first pattern. Create two new screens (`SpotifyPlaylistsScreen` for browsing playlists, `SpotifyPlaylistTracksScreen` for viewing/selecting tracks within a playlist). Wire into `RunningSongNotifier` for import. Add `playlist-read-private` and `playlist-read-collaborative` to the OAuth scopes. Add routes via GoRouter.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `spotify` | 0.15.0 | `Playlists.me`, `Playlists.getPlaylistTracks()` | Already in pubspec.yaml; provides typed models (`PlaylistSimple`, `PlaylistTrack`, `Track`) and pagination |
| `flutter_riverpod` | 2.6.1 | Providers for playlist service, state management | Project-wide state management convention |
| `go_router` | existing | Navigation to playlist browse/track screens | Project routing convention |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `SpotifyAuthService` | existing (Phase 31) | Get access token for API calls | Before any playlist API call |
| `RunningSongNotifier` | existing (Phase 28) | Persist imported songs to "Songs I Run To" | On user import action |
| `SongKey.normalize` | existing | Dedup imported songs against existing collection | During import to prevent duplicates |
| `CuratedSongRepository` | existing | Cross-reference imported songs with curated BPM data | Optional BPM enrichment on import |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Two separate screens (playlist list + track list) | Single screen with expandable playlists | Two screens is simpler, follows navigation depth pattern already in app (e.g., playlist-history -> detail), avoids complex nested scroll |
| Abstract `SpotifyPlaylistService` | Direct SpotifyApi usage in providers | Abstract service maintains mock-first pattern established in Phase 31/32; consistent with `SpotifyAuthService` and `SongSearchService` |
| Checkbox multi-select for tracks | Tap-to-add individual tracks (like song search) | Multi-select is better UX for import: user wants to pick several songs at once, then confirm batch import |
| `cached_network_image` for playlist covers | Direct `Image.network` | `Image.network` is sufficient for this use case; playlist covers are small and session-scoped. No caching library needed. |

**Installation:**
No new packages needed. All dependencies already in pubspec.yaml.

## Architecture Patterns

### Recommended Project Structure
```
lib/features/
├── spotify_import/
│   ├── domain/
│   │   └── spotify_playlist_service.dart    # Abstract interface + data classes
│   ├── data/
│   │   ├── mock_spotify_playlist_service.dart  # Mock for dev/testing
│   │   └── real_spotify_playlist_service.dart  # Real implementation (SpotifyApi)
│   ├── providers/
│   │   └── spotify_import_providers.dart     # Riverpod providers
│   └── presentation/
│       ├── spotify_playlists_screen.dart     # Browse user's playlists
│       └── spotify_playlist_tracks_screen.dart  # Select tracks from a playlist
test/features/
├── spotify_import/
│   ├── domain/
│   │   └── spotify_playlist_service_test.dart
│   └── providers/
│       └── spotify_import_providers_test.dart
```

### Pattern 1: SpotifyPlaylistService Abstraction
**What:** Abstract class defining playlist browse/fetch operations, with mock and real implementations.
**When to use:** Always -- follows the project's established mock-first pattern for Spotify features.
**Example:**
```dart
// Source: project pattern from SpotifyAuthService, SongSearchService
/// Simplified playlist data for display.
class SpotifyPlaylistInfo {
  const SpotifyPlaylistInfo({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.trackCount,
    this.ownerName,
  });

  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final int? trackCount;
  final String? ownerName;
}

/// A track from a Spotify playlist, ready for import consideration.
class SpotifyPlaylistTrack {
  const SpotifyPlaylistTrack({
    required this.title,
    required this.artist,
    this.spotifyUri,
    this.durationMs,
    this.albumName,
    this.imageUrl,
  });

  final String title;
  final String artist;
  final String? spotifyUri;
  final int? durationMs;
  final String? albumName;
  final String? imageUrl;
}

abstract class SpotifyPlaylistService {
  /// Fetch the current user's playlists.
  Future<List<SpotifyPlaylistInfo>> getUserPlaylists();

  /// Fetch tracks for a specific playlist.
  Future<List<SpotifyPlaylistTrack>> getPlaylistTracks(String playlistId);
}
```

### Pattern 2: Fetching User Playlists via spotify Package
**What:** Using `Playlists.me` to list user playlists with pagination.
**When to use:** In the real implementation when Spotify credentials are available.
**Example:**
```dart
// Source: spotify 0.15.0 package source (lib/src/endpoints/playlists.dart)
// Playlists.me returns Pages<PlaylistSimple>
class RealSpotifyPlaylistService implements SpotifyPlaylistService {
  RealSpotifyPlaylistService(this._spotifyApi);
  final SpotifyApi _spotifyApi;

  @override
  Future<List<SpotifyPlaylistInfo>> getUserPlaylists() async {
    try {
      // .all() fetches all pages. For large libraries, use .first(50) instead.
      final playlists = await _spotifyApi.playlists.me.all(50);
      return playlists
          .map((p) => SpotifyPlaylistInfo(
                id: p.id ?? '',
                name: p.name ?? 'Untitled',
                description: p.description,
                imageUrl: p.images?.isNotEmpty == true
                    ? p.images!.first.url
                    : null,
                trackCount: p.tracksLink?.total,
                ownerName: p.owner?.displayName,
              ))
          .where((p) => p.id.isNotEmpty)
          .toList();
    } on Exception catch (_) {
      return [];
    }
  }

  @override
  Future<List<SpotifyPlaylistTrack>> getPlaylistTracks(String playlistId) async {
    try {
      final tracks = await _spotifyApi.playlists
          .getPlaylistTracks(playlistId)
          .all(50);
      return tracks
          .where((pt) => pt.track != null && !(pt.isLocal ?? false))
          .map((pt) => SpotifyPlaylistTrack(
                title: pt.track!.name ?? '',
                artist: pt.track!.artists
                        ?.map((a) => a.name ?? '')
                        .join(', ') ??
                    'Unknown Artist',
                spotifyUri: pt.track!.uri,
                durationMs: pt.track!.durationMs,
                albumName: pt.track!.album?.name,
                imageUrl: pt.track!.album?.images?.isNotEmpty == true
                    ? pt.track!.album!.images!.first.url
                    : null,
              ))
          .where((t) => t.title.isNotEmpty)
          .toList();
    } on Exception catch (_) {
      return [];
    }
  }
}
```

### Pattern 3: Multi-Select Track Import
**What:** User selects multiple tracks via checkboxes, then imports them all at once into "Songs I Run To".
**When to use:** On the playlist tracks screen.
**Example:**
```dart
// Source: project pattern from song_search_screen.dart _addToRunningSongs
void _importSelectedTracks(
  WidgetRef ref,
  List<SpotifyPlaylistTrack> selected,
  Map<String, RunningSong> existingSongs,
) {
  final notifier = ref.read(runningSongProvider.notifier);
  var imported = 0;

  for (final track in selected) {
    final songKey = SongKey.normalize(track.artist, track.title);
    if (existingSongs.containsKey(songKey)) continue; // Already in collection

    notifier.addSong(RunningSong(
      songKey: songKey,
      artist: track.artist,
      title: track.title,
      addedDate: DateTime.now(),
      bpm: null, // Spotify does not provide BPM
      source: RunningSongSource.spotify,
    ));
    imported++;
  }
  // Show snackbar: "$imported songs imported"
}
```

### Pattern 4: Conditional Navigation Entry Point
**What:** The "Import from Spotify" button only appears when Spotify is connected.
**When to use:** On the Running Songs screen or as a contextual action.
**Example:**
```dart
// Source: project pattern from settings_screen.dart SpotifyConnectionStatus usage
final spotifyStatus = ref.watch(spotifyConnectionStatusSyncProvider);
if (spotifyStatus == SpotifyConnectionStatus.connected) {
  IconButton(
    icon: const Icon(Icons.cloud_download),
    tooltip: 'Import from Spotify',
    onPressed: () => context.push('/spotify-playlists'),
  );
}
```

### Anti-Patterns to Avoid
- **Fetching all tracks for all playlists upfront:** Only fetch tracks when the user opens a specific playlist. Playlists can have hundreds or thousands of tracks.
- **Using `Pages.all()` for very large playlists:** For playlists with 500+ tracks, `.all()` fires many paginated requests. Use `.first(50)` for the initial load with a "Load More" pattern or lazy loading. For this phase, `.all(50)` is acceptable for playlists up to ~200 tracks (4 pages); add a track count warning for very large playlists.
- **Importing without dedup check:** Always check `RunningSongNotifier.containsSong(songKey)` before adding. The UI should also show which tracks are already in the collection.
- **Blocking the UI during large imports:** Adding 50+ songs should not freeze the UI. Since `addSong` is optimistic (updates state then persists), this should be fast, but batch the persistence call rather than calling `save()` after each individual add.
- **Storing full Spotify API model objects in state:** Convert to lightweight domain objects (`SpotifyPlaylistInfo`, `SpotifyPlaylistTrack`) immediately. Don't leak `spotify` package types into the UI layer.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Playlist pagination | Manual HTTP + offset tracking | `Playlists.me` / `.getPlaylistTracks()` with `Pages.all()` or `.first()` | Package handles offset management, rate limit retries, JSON deserialization |
| Playlist model deserialization | Custom JSON parsing for playlists | `PlaylistSimple.fromJson`, `PlaylistTrack.fromJson` from spotify package | 15+ fields with nested objects, already generated with json_serializable |
| Track artist name formatting | Custom multi-artist join logic | Reuse pattern from `SpotifySongSearchService._artistName()` | Already handles nullable artists, joins with commas |
| Song deduplication on import | New dedup logic | `SongKey.normalize` + `RunningSongNotifier.containsSong()` | Proven dedup mechanism used by song search and song feedback |
| Access token management | Manual token handling | `SpotifyAuthService.getAccessToken()` | Handles token refresh, expiry, Completer-based lock for concurrency |

**Key insight:** This phase is primarily a UI/orchestration feature. The data layer (Spotify API access), persistence layer (RunningSong/SharedPreferences), and dedup logic (SongKey.normalize) all exist. The new work is: (1) an abstract service for playlist operations, (2) mock implementation, (3) two screens, (4) routing, and (5) scope update.

## Common Pitfalls

### Pitfall 1: Missing OAuth Scopes for Playlist Access
**What goes wrong:** `GET /me/playlists` returns empty or 403 because `playlist-read-private` scope was not requested during OAuth.
**Why it happens:** The current `spotify_constants.dart` scopes string does NOT include `playlist-read-private` or `playlist-read-collaborative`. Without these, only public playlists (if any) are returned.
**How to avoid:** Add `playlist-read-private playlist-read-collaborative` to the `spotifyScopes` constant. Note: adding scopes requires re-authentication (existing tokens won't have the new scopes). Users who connected before the scope change will need to disconnect and reconnect.
**Warning signs:** Empty playlist list even though the user has many playlists in Spotify.

### Pitfall 2: Local Tracks in Playlists
**What goes wrong:** Attempting to import a local file track (one synced from the user's computer, not from Spotify catalog) produces a song with no meaningful artist/title or an invalid Spotify URI.
**Why it happens:** `PlaylistTrack.isLocal` is `true` for local files. These tracks have limited metadata and no Spotify URI.
**How to avoid:** Filter out local tracks: `tracks.where((pt) => !(pt.isLocal ?? false))`. The `isLocal` field on `PlaylistTrack` is specifically for this purpose.
**Warning signs:** Import results with blank titles, "Unknown Artist", or `null` URIs.

### Pitfall 3: Podcast Episodes in Playlists
**What goes wrong:** Some playlists contain podcast episodes mixed with tracks. Casting all items to `Track` fails or produces nonsense metadata.
**Why it happens:** Spotify playlists can contain both tracks and episodes since 2020. The `additional_types` parameter defaults to `track` in the spotify package's `getPlaylistTracks()` (already filtered), but the `PlaylistTrack.track` field could theoretically be null if the item is an episode that was filtered out.
**How to avoid:** The spotify package's `getPlaylistTracks()` already adds `additional_types=track` to the query AND filters items where `track != null`. This is handled. Still, null-check `pt.track` before accessing.
**Warning signs:** Null pointer exceptions when mapping playlist tracks.

### Pitfall 4: Very Large Playlists Causing Timeout/Memory Issues
**What goes wrong:** A playlist with 1000+ tracks triggers many paginated API calls when using `.all()`, leading to long loading times or rate limiting.
**Why it happens:** `Pages.all()` fetches every page sequentially. At 50 items/page, a 1000-track playlist requires 20 API calls.
**How to avoid:** Use `PlaylistSimple.tracksLink.total` to display track count upfront. For playlists over 200 tracks, show a warning or use paginated loading (`.first(50)` + "Load More"). For the initial implementation, `.all(50)` is acceptable with a loading indicator.
**Warning signs:** Playlist track loading takes >5 seconds; "API rate exceeded" messages.

### Pitfall 5: Batch Import Causing O(n) Persist Calls
**What goes wrong:** Importing 50 songs calls `RunningSongNotifier.addSong()` 50 times, each of which calls `RunningSongPreferences.save()` (full JSON encode + SharedPreferences write).
**Why it happens:** `addSong()` persists after each mutation. This is fine for single adds but expensive for batch operations.
**How to avoid:** Add a `addSongs(List<RunningSong>)` batch method to `RunningSongNotifier` that updates state once and persists once. Or, temporarily accumulate additions and call save once at the end. The state notification will fire once with the full batch.
**Warning signs:** UI lag or jank when importing many songs at once.

### Pitfall 6: Re-authentication Required After Scope Change
**What goes wrong:** User was already connected to Spotify (Phase 31), but their existing token doesn't have the new `playlist-read-private` scope. Playlist fetch returns 403 or empty.
**Why it happens:** OAuth tokens are scoped. Adding scopes to the app requires the user to re-authorize.
**How to avoid:** When upgrading scopes, detect the issue (403 on playlist fetch) and show a message asking the user to disconnect and reconnect. Alternatively, check if the stored token's scopes include the needed ones and prompt re-auth if not.
**Warning signs:** Connected Spotify but empty playlist list; works for new users but not existing ones.

## Code Examples

### Fetching User Playlists (Real Implementation)
```dart
// Source: spotify 0.15.0 package (lib/src/endpoints/playlists.dart line 25-28)
// Playlists.me returns Pages<PlaylistSimple>
final pages = spotifyApi.playlists.me;

// Option A: Fetch first page only (fast, 50 playlists max)
final firstPage = await pages.first(50);
final playlists = firstPage.items?.toList() ?? [];

// Option B: Fetch all playlists (may be slow for users with many playlists)
final allPlaylists = await pages.all(50);
// allPlaylists is Iterable<PlaylistSimple>
```

### Fetching Playlist Tracks (Real Implementation)
```dart
// Source: spotify 0.15.0 package (lib/src/endpoints/playlists.dart line 55-65)
// getPlaylistTracks returns Pages<PlaylistTrack>
final trackPages = spotifyApi.playlists.getPlaylistTracks(playlistId);
final allTracks = await trackPages.all(50);

for (final pt in allTracks) {
  if (pt.track == null || (pt.isLocal ?? false)) continue;
  final track = pt.track!;
  print('${track.name} by ${track.artists?.first?.name} [${track.uri}]');
  print('  Added at: ${pt.addedAt}');
  print('  Album: ${track.album?.name}');
}
```

### PlaylistSimple Key Fields
```dart
// Source: spotify 0.15.0 package (lib/src/models/playlist.dart line 90-150)
// PlaylistSimple fields relevant for display:
// - id: String?        -- Spotify playlist ID
// - name: String?      -- Playlist name
// - description: String?  -- Optional description
// - images: List<Image>?  -- Cover images (up to 3, descending size)
// - tracksLink: TracksLink?  -- Contains .total (int?) for track count
// - owner: User?       -- Contains .displayName
// - collaborative: bool?
// - public: bool?
```

### PlaylistTrack Key Fields
```dart
// Source: spotify 0.15.0 package (lib/src/models/playlist.dart line 168-192)
// PlaylistTrack fields:
// - addedAt: DateTime?    -- When track was added
// - addedBy: UserPublic?  -- Who added it
// - isLocal: bool?        -- True for locally synced files (FILTER THESE OUT)
// - track: Track?         -- Full Track object with name, artists, uri, album, etc.
```

### Converting SpotifyPlaylistTrack to RunningSong
```dart
// Source: Existing pattern from song_search_screen.dart line 226-241
RunningSong _toRunningSong(SpotifyPlaylistTrack track) {
  final songKey = SongKey.normalize(track.artist, track.title);
  return RunningSong(
    songKey: songKey,
    artist: track.artist,
    title: track.title,
    addedDate: DateTime.now(),
    bpm: null, // Spotify does not provide BPM (audio features deprecated)
    source: RunningSongSource.spotify,
  );
}
```

### Batch Import with Single Persist
```dart
// Pattern: extend RunningSongNotifier with batch operation
Future<int> addSongs(List<RunningSong> songs) async {
  var added = 0;
  final newState = Map<String, RunningSong>.from(state);
  for (final song in songs) {
    if (!newState.containsKey(song.songKey)) {
      newState[song.songKey] = song;
      added++;
    }
  }
  if (added > 0) {
    state = newState;
    await RunningSongPreferences.save(state);
  }
  return added;
}
```

### Scope Update in spotify_constants.dart
```dart
// Current (missing playlist scopes):
const String spotifyScopes =
    'user-read-email user-read-private user-top-read '
    'user-library-read playlist-modify-public playlist-modify-private';

// Required (add playlist-read-private and playlist-read-collaborative):
const String spotifyScopes =
    'user-read-email user-read-private user-top-read '
    'user-library-read playlist-read-private playlist-read-collaborative '
    'playlist-modify-public playlist-modify-private';
```

### Mock Playlist Data
```dart
// Source: project pattern from mock_spotify_search_service.dart
class MockSpotifyPlaylistService implements SpotifyPlaylistService {
  @override
  Future<List<SpotifyPlaylistInfo>> getUserPlaylists() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const [
      SpotifyPlaylistInfo(
        id: 'mock_pl_1', name: 'Running Hits',
        trackCount: 25, ownerName: 'Test User',
      ),
      SpotifyPlaylistInfo(
        id: 'mock_pl_2', name: 'Morning Run',
        trackCount: 15, ownerName: 'Test User',
      ),
      SpotifyPlaylistInfo(
        id: 'mock_pl_3', name: 'Discover Weekly',
        trackCount: 30, ownerName: 'Spotify',
      ),
    ];
  }

  @override
  Future<List<SpotifyPlaylistTrack>> getPlaylistTracks(String playlistId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Return different tracks per playlist for realistic testing
    return _mockTracks[playlistId] ?? _defaultTracks;
  }

  static const _defaultTracks = [
    SpotifyPlaylistTrack(
      title: 'Stronger', artist: 'Kanye West',
      spotifyUri: 'spotify:track:mock_stronger',
    ),
    // ... more mock tracks, including some overlapping with curated catalog
  ];
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Audio features for BPM on imported tracks | Deprecated (403 for new apps) | Nov 2024 | Imported Spotify tracks have `bpm: null`; rely on curated cross-reference |
| `getTracksByPlaylistId` (deprecated method) | `getPlaylistTracks` returns `PlaylistTrack` objects | spotify 0.15.0 | New method includes `addedAt`, `addedBy`, `isLocal` fields |
| Unlimited API calls | Rate limiting with retry-after | Ongoing | spotify package handles 429 with built-in retry (5 attempts) |
| `GET /playlists/{id}/tracks` batch endpoint | Still available (not removed in Feb 2026) | Feb 2026 | Playlist tracks endpoint confirmed available |

**Deprecated/outdated:**
- `Playlists.getTracksByPlaylistId()`: Marked `@Deprecated` in spotify 0.15.0. Use `getPlaylistTracks()` instead -- it returns `PlaylistTrack` objects with `isLocal` and `addedAt` fields.
- Audio Features endpoint: Deprecated Nov 2024. Cannot enrich imported tracks with BPM data from Spotify.

## Open Questions

1. **Should we add a batch `addSongs()` method to `RunningSongNotifier`?**
   - What we know: The current `addSong()` persists after each mutation. Importing 50 songs means 50 persist calls.
   - What's unclear: Whether the performance impact is noticeable with SharedPreferences (each call serializes the full map).
   - Recommendation: YES -- add `addSongs(List<RunningSong>)` that batches the state update and persists once. This is a small, safe addition to the existing notifier. The UI improvement for bulk import is significant.

2. **Where should the "Import from Spotify" entry point live?**
   - What we know: The Running Songs screen has a search icon in the app bar. The home screen has feature navigation buttons.
   - What's unclear: Whether import should be accessible from Running Songs screen (app bar action), from a dedicated home button, or both.
   - Recommendation: Add to the Running Songs screen app bar (alongside the existing search icon) -- visible only when Spotify is connected. This puts import next to the collection it imports into. Optionally also accessible from settings or a future Spotify section.

3. **Should we attempt curated catalog cross-reference to enrich BPM on import?**
   - What we know: `CuratedSongRepository.loadCuratedSongs()` is cached. `SongKey.normalize` works for matching. Some imported tracks may exist in the curated catalog.
   - What's unclear: Whether the cross-reference lookup on import is worth the complexity vs. letting the scoring system handle it later.
   - Recommendation: DEFER to planner discretion. A lightweight lookup at import time (`O(1)` against a pre-built `Set<String>` of curated song keys) could enrich `bpm` and `genre` fields. But the scoring system already handles this via `CuratedSongRepository` lookup. The planner should decide if the added complexity is worth showing BPM badges immediately after import.

4. **How to handle the scope upgrade for existing connected users?**
   - What we know: Adding `playlist-read-private` to scopes requires re-authentication. Existing tokens won't have the new scope.
   - What's unclear: Best UX for prompting re-auth.
   - Recommendation: When playlist fetch fails or returns empty AND the user is connected, show a message: "Reconnect Spotify to access your playlists" with a button that triggers disconnect + re-connect. This handles the scope upgrade transparently.

## Sources

### Primary (HIGH confidence)
- `spotify` 0.15.0 package source code (`~/.pub-cache/hosted/pub.dev/spotify-0.15.0/lib/src/endpoints/playlists.dart`) -- `Playlists.me` returns `Pages<PlaylistSimple>`, `getPlaylistTracks(playlistId)` returns `Pages<PlaylistTrack>`, verified pagination API
- `spotify` 0.15.0 package source code (`~/.pub-cache/hosted/pub.dev/spotify-0.15.0/lib/src/models/playlist.dart`) -- `PlaylistSimple`, `Playlist`, `PlaylistTrack` model fields including `isLocal`, `addedAt`, `TracksLink.total`
- `spotify` 0.15.0 package source code (`~/.pub-cache/hosted/pub.dev/spotify-0.15.0/lib/src/endpoints/endpoint_paging.dart`) -- `Pages<T>` with `.first(limit)`, `.all(limit)`, `.stream(limit)` methods
- `spotify` 0.15.0 package source code (`~/.pub-cache/hosted/pub.dev/spotify-0.15.0/lib/src/authorization_scope.dart`) -- `PlaylistAuthorizationScope.readPrivate` = `playlist-read-private`, `.readCollaborative` = `playlist-read-collaborative`
- Existing codebase: `spotify_constants.dart` -- current scopes MISSING `playlist-read-private` and `playlist-read-collaborative`
- Existing codebase: `running_song.dart`, `running_song_preferences.dart`, `running_song_providers.dart` -- `RunningSong` model, persistence, `RunningSongNotifier.addSong()`
- Existing codebase: `mock_spotify_auth_repository.dart`, `mock_spotify_search_service.dart` -- established mock-first patterns
- Existing codebase: `song_search_screen.dart` -- `_addToRunningSongs()` pattern for converting search results to `RunningSong`
- Existing codebase: `router.dart` -- GoRouter route registration pattern

### Secondary (MEDIUM confidence)
- [Spotify Web API: Get Current User's Playlists](https://developer.spotify.com/documentation/web-api/reference/get-a-list-of-current-users-playlists) -- Requires `playlist-read-private` scope, returns paginated PlaylistSimple objects, limit 1-50
- [Spotify Web API: Get Playlist Items](https://developer.spotify.com/documentation/web-api/reference/get-playlists-tracks) -- Requires `playlist-read-private` scope, returns paginated PlaylistTrack objects with `track`, `added_at`, `is_local`
- [Spotify Web API Scopes](https://developer.spotify.com/documentation/web-api/concepts/scopes) -- `playlist-read-private` for private playlists, `playlist-read-collaborative` for collaborative playlists

### Tertiary (LOW confidence)
- None. All findings verified against package source code or official API documentation.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all dependencies already in pubspec.yaml, API endpoints verified in package source code and official docs
- Architecture: HIGH -- follows established patterns (abstract service + mock, Riverpod providers, GoRouter navigation, RunningSong persistence) that are proven in Phases 28, 31, 32
- Pitfalls: HIGH -- scope gap verified by reading `spotify_constants.dart` and `authorization_scope.dart`; local track filtering verified in `PlaylistTrack` model; pagination behavior verified in `endpoint_paging.dart`

**Research date:** 2026-02-09
**Valid until:** 2026-03-09 (stable package, no fast-moving dependencies)
