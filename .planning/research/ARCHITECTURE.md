# Architecture Patterns

**Domain:** Song search, "songs I run to" data model, Spotify API integration
**Researched:** 2026-02-08
**Overall confidence:** HIGH (based on thorough codebase analysis + official Spotify/Supabase docs)

## Executive Summary

This document defines how song search typeahead, the "songs I run to" persisted list, and a Spotify API abstraction layer integrate with the existing Riverpod/service/repository architecture. The key architectural decision is that "songs I run to" should be a **separate model and provider** rather than extending SongFeedback, because it represents a fundamentally different concept (explicit curation vs. reactive feedback). The Spotify API layer must handle a critical token management challenge: Supabase OAuth does not persist or refresh Spotify provider tokens, so the app needs its own token capture/refresh/storage layer.

---

## Current Architecture Snapshot (v1.3 Baseline)

### Application Structure

```
lib/features/
  {feature}/
    data/            -- SharedPreferences static wrappers, API clients
    domain/          -- Pure Dart models, enums, calculators
    presentation/    -- Flutter screens and widgets
    providers/       -- Riverpod StateNotifier + state classes
```

### Key Components Being Extended

| Component | File | Current Role |
|-----------|------|-------------|
| `SongQualityScorer` | `song_quality/domain/song_quality_scorer.dart` | Static scorer: 10 dimensions including liked/freshness. Accepts `isLiked` bool. |
| `PlaylistGenerator` | `playlist/domain/playlist_generator.dart` | Pure synchronous generator. Already accepts `likedSongKeys: Set<String>?`. |
| `PlaylistGenerationNotifier` | `playlist/providers/playlist_providers.dart` | Orchestrator: reads feedback, play history, freshness mode. Merges liked/disliked sets. |
| `SongFeedback` | `song_feedback/domain/song_feedback.dart` | Feedback model with songKey, isLiked, feedbackDate, artist, title, genre. |
| `SongFeedbackNotifier` | `song_feedback/providers/song_feedback_providers.dart` | StateNotifier<Map<String, SongFeedback>>, Completer-based async init. |
| `TastePatternAnalyzer` | `taste_learning/domain/taste_pattern_analyzer.dart` | Analyzes feedback for genre/artist patterns, produces suggestions. |
| `TasteSuggestionNotifier` | `taste_learning/providers/taste_learning_providers.dart` | Listens to feedback + profile changes, re-analyzes reactively. |
| `CuratedSongRepository` | `curated_songs/data/curated_song_repository.dart` | 3-tier loading: cache -> Supabase -> bundled JSON. |
| `AuthRepository` | `auth/data/auth_repository.dart` | Supabase OAuth for Spotify. Already has scopes for playlists. |

### Current Provider Dependency Graph

```
playlistGenerationProvider
  |-- reads runPlanNotifierProvider
  |-- reads tasteProfileNotifierProvider
  |-- reads getSongBpmClientProvider
  |-- reads curatedRunnabilityProvider
  |-- reads songFeedbackProvider          (splits into liked/disliked sets)
  |-- reads playHistoryProvider
  |-- reads freshnessModeProvider
  |-- writes playlistHistoryProvider      (auto-save)
  |-- writes playHistoryProvider          (record plays)

tasteSuggestionProvider
  |-- listens songFeedbackProvider
  |-- listens tasteProfileLibraryProvider
  |-- reads curatedGenreLookupProvider
```

### Current Scoring Integration

The `PlaylistGenerationNotifier._readFeedbackSets()` method already splits feedback into `liked: Set<String>` and `disliked: Set<String>` key sets. These flow into `PlaylistGenerator.generate()` which passes `isLiked: likedSongKeys?.contains(song.lookupKey) ?? false` to `SongQualityScorer.score()`.

**This is the exact integration point for "songs I run to"** -- running song keys merge into the liked set.

---

## Key Architectural Decision: "Songs I Run To" as Separate Model

### Decision

Create a separate `RunningSong` model and `runningSongProvider` rather than extending `SongFeedback`.

### Rationale

**SongFeedback is reactive** -- it captures post-hoc reactions to songs encountered during playlist generation. It has a binary `isLiked` field and is keyed by song encounters.

**"Songs I run to" is proactive** -- it captures songs the user explicitly curates as their running music, independent of whether those songs have appeared in generated playlists. This is a fundamentally different user intent:

| Aspect | SongFeedback | "Songs I Run To" |
|--------|-------------|-------------------|
| User intent | "This song was good/bad in my playlist" | "I actively want to run to this song" |
| Source | Post-run review, in-playlist thumbs | Search, Spotify import, manual add |
| Binary? | Yes (liked/disliked) | No (just "I run to this") |
| BPM data | Not stored | Should store if available |
| Spotify URI | Not stored | Should store for future playback |
| Count | Grows organically with playlists | User-curated, bounded |

Extending SongFeedback would require:
- Adding a `source` field to distinguish feedback types
- Adding optional fields (BPM, Spotify URI) that are irrelevant to feedback
- Complicating every consumer that reads feedback (must filter by source)
- Mixing two conceptually distinct lists in one UI

**The integration point is simple:** running songs produce lookup keys that flow into `PlaylistGenerator.generate()` and `TastePatternAnalyzer.analyze()` via the same `likedSongKeys` mechanism that SongFeedback already uses.

### Model Definition

```dart
/// A song the user has explicitly added to their "songs I run to" list.
class RunningSong {
  const RunningSong({
    required this.songKey,      // SongKey.normalize(artist, title)
    required this.title,
    required this.artistName,
    required this.addedAt,
    this.bpm,
    this.genre,
    this.spotifyTrackId,        // For future Spotify playback
    this.spotifyUri,            // spotify:track:xxx
    this.source,                // 'search', 'spotify_playlist', 'manual'
  });

  // ... fromJson, toJson, lookupKey getter using SongKey.normalize
}
```

### Provider Shape

```dart
/// Follows the established StateNotifier + Completer pattern.
class RunningSongNotifier extends StateNotifier<Map<String, RunningSong>> {
  // Completer<void> _loadCompleter pattern (same as SongFeedbackNotifier)
  // addSong, removeSong, ensureLoaded
  // Persistence via RunningSongPreferences (same pattern as SongFeedbackPreferences)
}

final runningSongProvider = StateNotifierProvider<
    RunningSongNotifier, Map<String, RunningSong>>(
  (ref) => RunningSongNotifier(),
);
```

This follows the exact same pattern as `SongFeedbackNotifier`: `StateNotifier<Map<String, T>>`, Completer-based async loading, SharedPreferences persistence via a static helper class.

---

## Recommended Architecture

### System Overview

```
+------------------+     +--------------------+     +------------------+
|  Song Search UI  |---->| SongSearchService  |---->| Curated Songs    |
|  (typeahead)     |     | (interface)        |     | Repository       |
+------------------+     +--------------------+     +------------------+
                          |                          +------------------+
                          +------------------------->| SpotifyApiClient |
                                                     | (future phase)   |
                                                     +------------------+
                                                             |
+------------------+     +--------------------+     +------------------+
| My Running Songs |---->| RunningSongNotifier |---->| RunningSong      |
| Screen           |     | (provider)         |     | Preferences      |
+------------------+     +--------------------+     +------------------+
        |                        |
        v                        v
+------------------+     +--------------------+
| Playlist Gen     |     | SongQualityScorer  |
| (reads running   |     | (isLiked boost +5) |
| songs as liked   |     |                    |
| keys)            |     |                    |
+------------------+     +--------------------+

+------------------+     +--------------------+     +------------------+
| Spotify Playlist |---->| SpotifyAuth        |---->| Spotify OAuth    |
| Browser Screen   |     | Service            |     | Token Storage    |
+------------------+     +--------------------+     +------------------+
```

### Component Boundaries

| Component | Responsibility | Communicates With | New/Modified |
|-----------|---------------|-------------------|--------------|
| `SongSearchService` | Abstract search interface, merges results from multiple sources | `CuratedSongRepository`, future `SpotifyApiClient` | **NEW** |
| `SongSearchNotifier` | Manages debounced typeahead state, cancellation | `SongSearchService` | **NEW** |
| `SongSearchResult` | Unified search result model across sources | N/A (pure model) | **NEW** |
| `RunningSong` | Domain model for user-curated "songs I run to" | N/A (pure model) | **NEW** |
| `RunningSongNotifier` | CRUD + persistence for running songs list | `RunningSongPreferences` | **NEW** |
| `RunningSongPreferences` | SharedPreferences persistence for running songs | SharedPreferences | **NEW** |
| `SpotifyApiClient` | HTTP client for Spotify Web API (search, playlists) | Spotify API, `SpotifyTokenManager` | **NEW** |
| `SpotifyTokenManager` | Captures, stores, refreshes Spotify provider tokens | `flutter_secure_storage`, Supabase session | **NEW** |
| `SpotifyTrack` | Domain model for Spotify API track response | N/A (pure model) | **NEW** |
| `SpotifyPlaylist` | Domain model for Spotify API playlist response | N/A (pure model) | **NEW** |
| `PlaylistGenerationNotifier` | Reads running songs as liked keys for scoring | `runningSongProvider` | **MODIFIED** |
| `TasteSuggestionNotifier` | Includes running songs in pattern analysis | `runningSongProvider` | **MODIFIED** |
| `GoRouter` | Add routes for new screens | New screens | **MODIFIED** |
| `HomeScreen` | Add navigation for running songs | New routes | **MODIFIED** |
| `SongQualityScorer` | No changes -- already accepts `isLiked` flag | N/A | **UNCHANGED** |
| `PlaylistGenerator` | No changes -- already accepts `likedSongKeys` | N/A | **UNCHANGED** |

---

## Component Architecture: Song Search

### Search Service Interface

```dart
/// Unified search result from any source.
class SongSearchResult {
  const SongSearchResult({
    required this.title,
    required this.artistName,
    this.bpm,
    this.genre,
    this.spotifyTrackId,
    this.spotifyUri,
    this.albumArtUrl,
    required this.source,     // 'curated', 'spotify'
  });

  String get songKey => SongKey.normalize(artistName, title);
}

/// Abstract search interface. Phase 1: curated-only. Future: composite.
abstract class SongSearchService {
  Future<List<SongSearchResult>> search(String query, {int limit = 20});
}
```

### Curated Song Search (Phase 1 Implementation)

```dart
/// Searches the curated songs dataset using in-memory substring matching.
class CuratedSongSearchService implements SongSearchService {
  CuratedSongSearchService(this._songs);
  final List<CuratedSong> _songs;

  @override
  Future<List<SongSearchResult>> search(String query, {int limit = 20}) async {
    final lowerQuery = query.toLowerCase().trim();
    if (lowerQuery.isEmpty) return [];

    return _songs
        .where((s) =>
            s.title.toLowerCase().contains(lowerQuery) ||
            s.artistName.toLowerCase().contains(lowerQuery))
        .take(limit)
        .map((s) => SongSearchResult(
              title: s.title,
              artistName: s.artistName,
              bpm: s.bpm,
              genre: s.genre,
              source: 'curated',
            ))
        .toList();
  }
}
```

The curated dataset is ~700 songs. In-memory substring search on this size is sub-millisecond.

### Debounced Search State and Notifier

```dart
/// Search state with idle/loading/results/error variants.
class SongSearchState {
  const SongSearchState._({
    this.query = '',
    this.results = const [],
    this.isLoading = false,
    this.error,
  });

  const SongSearchState.idle() : this._();
  const SongSearchState.loading(String query)
      : this._(query: query, isLoading: true);
  SongSearchState.results(String query, List<SongSearchResult> results)
      : this._(query: query, results: results);
  const SongSearchState.error(String query, String error)
      : this._(query: query, error: error);

  final String query;
  final List<SongSearchResult> results;
  final bool isLoading;
  final String? error;
}

/// Manages typeahead search with 300ms debounce and cancellation.
class SongSearchNotifier extends StateNotifier<SongSearchState> {
  SongSearchNotifier(this._service) : super(const SongSearchState.idle());

  final SongSearchService? _service;
  Timer? _debounceTimer;

  static const _debounceDuration = Duration(milliseconds: 300);
  static const _minQueryLength = 2;

  void updateQuery(String query) {
    _debounceTimer?.cancel();

    if (query.trim().length < _minQueryLength) {
      state = const SongSearchState.idle();
      return;
    }

    state = SongSearchState.loading(query);

    _debounceTimer = Timer(_debounceDuration, () async {
      if (_service == null) {
        state = SongSearchState.error(query, 'Search not available');
        return;
      }
      try {
        final results = await _service.search(query);
        if (mounted) state = SongSearchState.results(query, results);
      } catch (e) {
        if (mounted) state = SongSearchState.error(query, 'Search failed');
      }
    });
  }

  void clear() {
    _debounceTimer?.cancel();
    state = const SongSearchState.idle();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
```

**Why 300ms debounce:** Matches the `flutter_typeahead` default. Fast enough to feel responsive, slow enough to avoid flooding search on every keystroke. For curated search (in-memory), the debounce is mostly for UI smoothness. For future Spotify search (HTTP), it prevents rate limiting.

**Why Timer over Riverpod debounce pattern:** The Riverpod cookbook debounce pattern (`ref.onDispose` + `Future.delayed`) is designed for FutureProvider-based approaches. Since this is a StateNotifier with mutable query state and explicit cancellation needs, a Timer is simpler and follows the pattern already established in the codebase.

---

## Component Architecture: Spotify API Layer

### Critical Finding: Supabase Provider Token Limitation

**Confidence: HIGH** (verified via Supabase GitHub discussions #20035, #14096, auth issue #1450)

Supabase OAuth with Spotify has a critical limitation for mobile apps:

1. **Provider token is ephemeral.** `session.providerToken` is only available immediately after the OAuth callback. Supabase does not persist it in the database.
2. **Supabase session refresh nullifies it.** When Supabase refreshes its own JWT (~1 hour), the `providerToken` field becomes null.
3. **No client-side token refresh.** The Supabase-to-Spotify flow uses Authorization Code (not PKCE), requiring `client_secret` for refresh. Client secrets cannot be stored in mobile apps.

### Recommended Token Architecture

**Approach: Capture on login, store locally, refresh via Supabase Edge Function (or graceful degradation).**

```
Login Flow:
  1. User signs in via Supabase OAuth (existing AuthRepository flow)
  2. onAuthStateChange fires with SIGNED_IN event
  3. SpotifyTokenManager captures session.providerToken + session.providerRefreshToken
  4. Stores both in flutter_secure_storage (already in pubspec)
  5. SpotifyTokenManager.getValidToken() provides tokens to SpotifyApiClient

Token Refresh:
  Option A (MVP - Graceful Degradation):
    - Token expires after ~1 hour
    - Spotify features degrade to unavailable
    - Show "Re-login to refresh Spotify access" prompt
    - User re-authenticates to get fresh token

  Option B (Full - via Edge Function):
    - Store providerRefreshToken on login
    - When access token expires, call Supabase Edge Function
    - Edge Function holds Spotify client_secret, does refresh
    - Returns new access_token + refresh_token
    - Update local secure storage
```

**Recommendation: Start with Option A (graceful degradation).** It requires no server-side code and is sufficient for an MVP where Spotify is an enhancement. Option B can be added later when Spotify features become central to the experience.

### SpotifyTokenManager

```dart
/// Manages Spotify API tokens with secure storage and expiry tracking.
class SpotifyTokenManager {
  SpotifyTokenManager(this._secureStorage);
  final FlutterSecureStorage _secureStorage;

  static const _accessTokenKey = 'spotify_access_token';
  static const _refreshTokenKey = 'spotify_refresh_token';
  static const _expiresAtKey = 'spotify_token_expires_at';

  /// Captures provider tokens from Supabase OAuth session.
  /// Call from onAuthStateChange when event == SIGNED_IN.
  Future<void> captureFromSession(Session session) async {
    if (session.providerToken != null) {
      await _secureStorage.write(key: _accessTokenKey, value: session.providerToken);
      final expiresAt = DateTime.now()
          .add(const Duration(seconds: 3500)) // 100s buffer before actual expiry
          .toIso8601String();
      await _secureStorage.write(key: _expiresAtKey, value: expiresAt);
    }
    if (session.providerRefreshToken != null) {
      await _secureStorage.write(
          key: _refreshTokenKey, value: session.providerRefreshToken);
    }
  }

  /// Returns a valid access token, or null if expired/unavailable.
  Future<String?> getValidToken() async {
    final token = await _secureStorage.read(key: _accessTokenKey);
    final expiresAtStr = await _secureStorage.read(key: _expiresAtKey);
    if (token == null || expiresAtStr == null) return null;

    final expiresAt = DateTime.parse(expiresAtStr);
    if (DateTime.now().isAfter(expiresAt)) return null; // Expired

    return token;
  }

  /// Whether any Spotify token has ever been captured.
  Future<bool> get hasToken async =>
      await _secureStorage.read(key: _accessTokenKey) != null;

  Future<void> clearTokens() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _expiresAtKey);
  }
}
```

### SpotifyApiClient

```dart
/// HTTP client for Spotify Web API endpoints.
///
/// All methods throw SpotifyAuthException when token is expired/missing,
/// and SpotifyApiException on other API errors. Callers should catch these
/// and degrade gracefully (e.g., fall back to curated-only search).
class SpotifyApiClient {
  SpotifyApiClient({
    required SpotifyTokenManager tokenManager,
    http.Client? httpClient,
  })  : _tokenManager = tokenManager,
        _httpClient = httpClient ?? http.Client();

  final SpotifyTokenManager _tokenManager;
  final http.Client _httpClient;
  static const _baseUrl = 'https://api.spotify.com/v1';

  /// GET /v1/search?type=track&q={query}&limit={limit}
  Future<List<SpotifyTrack>> searchTracks(String query, {int limit = 20}) async {
    final token = await _tokenManager.getValidToken();
    if (token == null) throw SpotifyAuthException('No valid Spotify token');

    final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
      'type': 'track',
      'q': query,
      'limit': limit.toString(),
    });

    final response = await _httpClient.get(uri, headers: {
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 401) throw SpotifyAuthException('Token expired');
    if (response.statusCode != 200) {
      throw SpotifyApiException('Search failed: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final tracks = body['tracks'] as Map<String, dynamic>;
    final items = tracks['items'] as List<dynamic>;
    return items
        .map((item) => SpotifyTrack.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// GET /v1/me/playlists?limit={limit}&offset={offset}
  /// Requires scope: playlist-read-private (already in spotifyScopes)
  Future<SpotifyPlaylistPage> getUserPlaylists({
    int limit = 20, int offset = 0,
  }) async { /* ... */ }

  /// GET /v1/playlists/{playlistId}/tracks
  Future<List<SpotifyTrack>> getPlaylistTracks(String playlistId) async { /* ... */ }

  void dispose() => _httpClient.close();
}
```

### Spotify Domain Models

```dart
/// A track from the Spotify API.
class SpotifyTrack {
  const SpotifyTrack({
    required this.id,
    required this.name,
    required this.artists,
    required this.uri,
    this.albumName,
    this.albumArtUrl,
    this.durationMs,
  });

  factory SpotifyTrack.fromJson(Map<String, dynamic> json) {
    final artists = (json['artists'] as List<dynamic>)
        .map((a) => (a as Map<String, dynamic>)['name'] as String)
        .toList();
    final album = json['album'] as Map<String, dynamic>?;
    final images = album?['images'] as List<dynamic>?;
    return SpotifyTrack(
      id: json['id'] as String,
      name: json['name'] as String,
      artists: artists,
      uri: json['uri'] as String,
      albumName: album?['name'] as String?,
      albumArtUrl: images?.isNotEmpty == true
          ? (images!.first as Map<String, dynamic>)['url'] as String?
          : null,
      durationMs: (json['duration_ms'] as num?)?.toInt(),
    );
  }

  final String id;
  final String name;
  final List<String> artists;
  final String uri;              // spotify:track:xxx
  final String? albumName;
  final String? albumArtUrl;
  final int? durationMs;

  String get artistName => artists.isNotEmpty ? artists.first : '';

  /// Convert to SongSearchResult for unified search UI.
  SongSearchResult toSearchResult() => SongSearchResult(
    title: name,
    artistName: artistName,
    spotifyTrackId: id,
    spotifyUri: uri,
    albumArtUrl: albumArtUrl,
    source: 'spotify',
  );
}

/// A playlist from the Spotify API (for playlist browser).
class SpotifyPlaylist {
  const SpotifyPlaylist({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.trackCount,
    this.isPublic,
  });
  // fromJson...
}
```

---

## Data Flow: How New Components Wire Into Existing System

### Flow 1: Song Search to "Songs I Run To"

```
User types in search bar
  -> SongSearchNotifier.updateQuery("lose your")
  -> Debounce 300ms
  -> SongSearchService.search("lose your")
    -> CuratedSongSearchService filters in-memory (~700 songs)
    -> (Future: SpotifyApiClient.searchTracks via HTTP)
  -> Results shown in typeahead dropdown

User taps result ("Lose Yourself - Eminem")
  -> RunningSongNotifier.addSong(RunningSong(
       songKey: SongKey.normalize('Eminem', 'Lose Yourself'),
       title: 'Lose Yourself',
       artistName: 'Eminem',
       bpm: 171,       // from curated data
       genre: 'hipHop', // from curated data
       addedAt: DateTime.now(),
       source: 'search',
     ))
  -> state = {...state, 'eminem|lose yourself': song}
  -> RunningSongPreferences.save(state)
```

### Flow 2: Running Songs Feed Playlist Generation

```
PlaylistGenerationNotifier.generatePlaylist()
  // Existing code in _readFeedbackSets():
  -> final feedbackMap = ref.read(songFeedbackProvider);
  -> final disliked = <String>{};
  -> final liked = <String>{};
  -> for (entry in feedbackMap) { liked.add / disliked.add }

  // NEW: merge running songs into liked set
  -> await ref.read(runningSongProvider.notifier).ensureLoaded();
  -> final runningSongs = ref.read(runningSongProvider);
  -> liked.addAll(runningSongs.keys);  // <-- single line addition

  -> PlaylistGenerator.generate(likedSongKeys: liked, ...)
  // SongQualityScorer.score() already gives +5 for isLiked=true
  // No changes needed to scorer or generator!
```

**This is a one-line integration.** The `_readFeedbackSets()` method returns mutable sets. Running song keys simply get added to the liked set.

### Flow 3: Running Songs Feed Taste Pattern Analysis

```
TasteSuggestionNotifier._reanalyze()
  // Existing: reads songFeedbackProvider
  // NEW: also reads runningSongProvider
  -> final runningSongs = ref.read(runningSongProvider);
  -> // Convert running songs to synthetic liked feedback entries:
  -> final syntheticFeedback = runningSongs.values.map(
       (rs) => SongFeedback(
         songKey: rs.songKey,
         isLiked: true,
         feedbackDate: rs.addedAt,
         songTitle: rs.title,
         songArtist: rs.artistName,
         genre: rs.genre,
       ),
     );
  -> // Merge into feedback map before passing to analyzer
  -> final mergedFeedback = {...feedback, ...syntheticMap};
  -> TastePatternAnalyzer.analyze(feedback: mergedFeedback, ...)
```

Running songs contribute to artist and genre pattern detection. If a user adds 3 rock songs to their running list, the analyzer will detect a rock preference.

### Flow 4: Spotify Auth Token Capture

```
// In main.dart or a dedicated auth listener provider:
Supabase.instance.client.auth.onAuthStateChange.listen((data) {
  if (data.event == AuthChangeEvent.signedIn && data.session != null) {
    ref.read(spotifyTokenManagerProvider)
        .captureFromSession(data.session!);
  }
});
```

**Why capture immediately:** The provider token is only available on the initial sign-in event. If the app misses this window, the token is gone until the user re-authenticates.

### Flow 5: Spotify Playlist Import to "Songs I Run To"

```
SpotifyPlaylistBrowserScreen
  -> User opens screen
  -> SpotifyApiClient.getUserPlaylists()
  -> Grid of playlist cards with images and names
  -> User taps a playlist
  -> SpotifyApiClient.getPlaylistTracks(playlistId)
  -> List of tracks with checkboxes
  -> User selects songs and taps "Add to My Running Songs"
  -> For each selected track:
     -> RunningSongNotifier.addSong(RunningSong(
          songKey: SongKey.normalize(track.artistName, track.name),
          title: track.name,
          artistName: track.artistName,
          spotifyTrackId: track.id,
          spotifyUri: track.uri,
          source: 'spotify_playlist',
          addedAt: DateTime.now(),
        ))
```

---

## Provider Dependency Graph (Updated)

```
                    spotifyTokenManagerProvider (NEW)
                            |
                    spotifyApiClientProvider (NEW)
                       /              \
          songSearchServiceProvider    spotifyPlaylistProvider (future)
                    |                       (NEW)
          songSearchProvider (NEW)

          runningSongProvider (NEW)
               /          \
  playlistGenerationProvider    tasteSuggestionProvider
  (MODIFIED: reads running     (MODIFIED: reads running
   songs as liked keys)         songs for pattern analysis)
```

### New Providers

```dart
/// Provides SpotifyTokenManager backed by flutter_secure_storage.
final spotifyTokenManagerProvider = Provider<SpotifyTokenManager>((ref) {
  return SpotifyTokenManager(const FlutterSecureStorage());
});

/// Provides SpotifyApiClient.
final spotifyApiClientProvider = Provider<SpotifyApiClient>((ref) {
  final tokenManager = ref.watch(spotifyTokenManagerProvider);
  final client = SpotifyApiClient(tokenManager: tokenManager);
  ref.onDispose(client.dispose);
  return client;
});

/// Provides the song search service.
/// Phase 1: curated-only. Future: composite with Spotify.
final songSearchServiceProvider = FutureProvider<SongSearchService>((ref) async {
  final songs = await CuratedSongRepository.loadCuratedSongs();
  return CuratedSongSearchService(songs);
});

/// Provides debounced song search state.
final songSearchProvider =
    StateNotifierProvider<SongSearchNotifier, SongSearchState>((ref) {
  final serviceAsync = ref.watch(songSearchServiceProvider);
  final service = serviceAsync.valueOrNull;
  return SongSearchNotifier(service);
});

/// Provides the user's "songs I run to" list.
final runningSongProvider =
    StateNotifierProvider<RunningSongNotifier, Map<String, RunningSong>>(
  (ref) => RunningSongNotifier(),
);
```

---

## File Organization

Following the existing feature-based structure:

```
lib/features/
  song_search/                               # NEW FEATURE
    data/
      curated_song_search_service.dart       # CuratedSongSearchService
    domain/
      song_search_result.dart                # SongSearchResult model
      song_search_service.dart               # Abstract interface
    presentation/
      song_search_screen.dart                # Typeahead search UI
      widgets/
        search_result_tile.dart              # Individual result tile
    providers/
      song_search_providers.dart             # songSearchProvider + deps

  running_songs/                             # NEW FEATURE
    data/
      running_song_preferences.dart          # SharedPreferences persistence
    domain/
      running_song.dart                      # RunningSong model
    presentation/
      running_songs_screen.dart              # "Songs I Run To" list UI
    providers/
      running_song_providers.dart            # runningSongProvider

  spotify/                                   # NEW FEATURE
    data/
      spotify_api_client.dart                # HTTP client for Spotify API
      spotify_token_manager.dart             # Token capture/storage/refresh
    domain/
      spotify_track.dart                     # SpotifyTrack model
      spotify_playlist.dart                  # SpotifyPlaylist model
      spotify_exceptions.dart                # SpotifyAuthException, SpotifyApiException
    presentation/
      spotify_playlist_browser_screen.dart   # Browse user's playlists
      widgets/
        spotify_playlist_tile.dart           # Playlist card
        spotify_track_tile.dart              # Track row with checkbox
    providers/
      spotify_providers.dart                 # tokenManager, apiClient, playlist providers
```

---

## Patterns to Follow

### Pattern 1: StateNotifier + Completer (Async Init)

**What:** Every StateNotifier that loads from SharedPreferences uses a `Completer<void>` for `ensureLoaded()`.

**When:** Always, for any new StateNotifier with async initialization.

**Why:** Solves the cold-start race condition where `_load()` is fire-and-forget in the constructor. Consumers call `ensureLoaded()` before reading state.

**Established in:** `SongFeedbackNotifier`, `TasteProfileLibraryNotifier`, `PlayHistoryNotifier`.

### Pattern 2: Static Preferences Helper

**What:** Persistence classes are static-method-only wrappers around SharedPreferences with `load()`, `save()`, `clear()` methods.

**When:** For any new persisted data.

**Established in:** `SongFeedbackPreferences`, `TasteSuggestionPreferences`, `PlaylistHistoryPreferences`.

### Pattern 3: SongKey.normalize for Cross-Source Matching

**What:** All song identity uses `SongKey.normalize(artist, title)` producing `'artist_lower|title_lower'`.

**When:** Every time a song needs to be stored, looked up, or compared.

**Why:** Single source of truth. Used consistently across `CuratedSong.lookupKey`, `BpmSong.lookupKey`, `PlaylistSong.lookupKey`, `SongFeedback.songKey`.

**For new code:** `RunningSong.songKey` and `SongSearchResult.songKey` must use the same normalization.

### Pattern 4: Search Interface Abstraction

**What:** `SongSearchService` is abstract. Phase 1 implements curated-only. Future phases add `SpotifySongSearchService` and `CompositeSongSearchService`.

**Why:** The search UI and providers are decoupled from the data source. Adding Spotify search requires zero changes to the UI or provider layer -- just swap the service implementation.

### Pattern 5: Graceful Degradation for Spotify

**What:** All Spotify features degrade gracefully when tokens expire or are unavailable.

**When:** Any Spotify API interaction.

**Why:** The app must be fully functional without Spotify. Song search works with curated data. Running songs work without Spotify URIs. Spotify is an enhancement.

**Implementation:** `SpotifyApiClient` throws `SpotifyAuthException`. The search service catches it and falls back to curated results. The playlist browser shows a "Connect Spotify" prompt.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Extending SongFeedback for Running Songs

**What:** Adding a `type` or `source` field to SongFeedback to distinguish feedback from running songs.

**Why bad:** Couples two distinct concepts. Complicates every consumer (playlist gen, pattern analyzer, feedback UI, post-run review). Requires migration of existing feedback data. Violates single-responsibility.

**Instead:** Separate `RunningSong` model with a simple one-line merge at the consumer level.

### Anti-Pattern 2: Direct Spotify API Calls Without Token Management

**What:** Passing `session.providerToken` directly to API calls without storage/expiry tracking.

**Why bad:** Provider token becomes null after Supabase session refresh (~1 hour). Every API call would fail silently or crash after the first hour.

**Instead:** `SpotifyTokenManager` captures on login, stores in secure storage, provides `getValidToken()` with expiry checking.

### Anti-Pattern 3: Storing Spotify Client Secret in the App

**What:** Embedding Spotify `client_secret` in the Flutter app for direct token refresh.

**Why bad:** Client secrets in mobile apps can be extracted via reverse engineering. Violates Spotify's security requirements and terms of service.

**Instead:** Token refresh via Supabase Edge Function (server-side), or graceful degradation with re-auth prompt.

### Anti-Pattern 4: Blocking UI on Curated Song Load

**What:** Making the search UI wait for curated songs to load before rendering.

**Why bad:** First search attempt would show a loading spinner while curated songs load.

**Instead:** `songSearchServiceProvider` is a `FutureProvider`. The SongSearchNotifier accepts a nullable service. If service is null (still loading), search returns error state. Curated songs typically load in <100ms from cache.

### Anti-Pattern 5: Using flutter_typeahead Package

**What:** Adding the `flutter_typeahead` package for the search dropdown.

**Why bad:** Adds a dependency for something easily built with a `TextField` + `ListView` + the existing `SongSearchNotifier`. The package's API may not match the app's design system. Custom implementation gives full control over styling, animations, and behavior.

**Instead:** Build custom typeahead with `TextField` + `StreamBuilder`/`Consumer` + overlay or inline `ListView`.

---

## Integration Points Summary (Modified Components)

### 1. PlaylistGenerationNotifier (MODIFIED)

**File:** `lib/features/playlist/providers/playlist_providers.dart`

**Change:** In `_readFeedbackSets()` or `generatePlaylist()`, also read `runningSongProvider` and merge keys into liked set.

```dart
// In generatePlaylist(), after existing ensureLoaded calls:
await ref.read(runningSongProvider.notifier).ensureLoaded();

// In _readFeedbackSets() or after its call:
final runningSongs = ref.read(runningSongProvider);
liked.addAll(runningSongs.keys);
```

**Impact:** Minimal. One additional `ensureLoaded()` call and one `addAll()` operation. Same change needed in `shufflePlaylist()`.

### 2. TasteSuggestionNotifier (MODIFIED)

**File:** `lib/features/taste_learning/providers/taste_learning_providers.dart`

**Change:** In `_reanalyze()`, merge running songs as synthetic liked feedback before analysis. Add `ref.listen(runningSongProvider, ...)` for reactivity.

### 3. GoRouter (MODIFIED)

**File:** `lib/app/router.dart`

**Change:** Add routes: `/song-search`, `/my-running-songs`, `/spotify-playlists`.

### 4. HomeScreen (MODIFIED)

**File:** `lib/features/home/presentation/home_screen.dart`

**Change:** Add navigation buttons for "My Running Songs" and "Search Songs".

### 5. Auth Flow (MODIFIED)

**File:** `lib/main.dart` or new auth listener

**Change:** Add `onAuthStateChange` listener to capture Spotify provider token.

---

## Suggested Build Order (Dependency-Driven)

```
Phase 1: "Songs I Run To" Core (no external deps)
  1. RunningSong model (domain)
  2. RunningSongPreferences (data)
  3. RunningSongNotifier + provider (providers)
  4. Running songs UI screen (presentation)
  5. PlaylistGenerationNotifier integration (merge liked keys)
  6. TasteSuggestionNotifier integration (synthetic feedback)
  7. Router + HomeScreen nav additions

Phase 2: Song Search with Curated Data
  1. SongSearchResult model (domain)
  2. SongSearchService interface (domain)
  3. CuratedSongSearchService (data)
  4. SongSearchNotifier + provider (providers)
  5. Search UI with typeahead (presentation)
  6. Wire search results -> RunningSongNotifier.addSong

Phase 3: Spotify API Foundation (infrastructure)
  1. SpotifyTrack, SpotifyPlaylist models (domain)
  2. SpotifyExceptions (domain)
  3. SpotifyTokenManager (data)
  4. Auth token capture integration (main.dart)
  5. SpotifyApiClient (data)
  6. Providers (spotify_providers.dart)

Phase 4: Spotify Search Integration
  1. SpotifySongSearchService (implements SongSearchService)
  2. CompositeSongSearchService (merges curated + Spotify)
  3. Update songSearchServiceProvider to use composite
  4. UI: album art, source badge for Spotify results

Phase 5: Spotify Playlist Browser
  1. Playlist browser screen (list user's playlists)
  2. Playlist track listing (songs in selected playlist)
  3. Bulk add selected tracks to running songs
```

**Phase ordering rationale:**
- Phase 1 has zero external dependencies and delivers user value immediately. A user can manually type in song names.
- Phase 2 depends on Phase 1 (search adds songs to the running songs list).
- Phase 3 is infrastructure with no user-facing UI but enables Phases 4 and 5.
- Phase 4 extends Phase 2's search with Spotify data. The composite service is a drop-in replacement.
- Phase 5 is the most complex feature and depends on all prior phases being stable.

---

## Scalability Considerations

| Concern | At 100 songs | At 1K songs | At 10K songs |
|---------|-------------|-------------|--------------|
| Curated search (in-memory) | <1ms | <5ms | Consider index or prefix trie |
| Running songs (SharedPrefs) | Fine (~10KB) | Fine (~100KB) | Migrate to SQLite |
| Spotify search (HTTP) | Rate limit not a concern | Same | Debounce protects |
| Running song keys in scoring | Set.contains O(1) | Same | Same |
| Spotify token storage | Fine | N/A | N/A |

The curated dataset is ~700 songs. Running songs will likely stay under 200 for most users. No scaling concerns for the foreseeable future.

---

## Sources

- Spotify Web API Reference: [Search endpoint](https://developer.spotify.com/documentation/web-api/reference/search) -- HIGH confidence
- Spotify Authorization: [PKCE Flow](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow) -- HIGH confidence
- Spotify OAuth Migration: [November 2025 deadline](https://developer.spotify.com/blog/2025-10-14-reminder-oauth-migration-27-nov-2025) -- HIGH confidence
- Spotify Scopes: [Scopes reference](https://developer.spotify.com/documentation/web-api/concepts/scopes) -- HIGH confidence
- Supabase Spotify provider token limitation: [Discussion #20035](https://github.com/orgs/supabase/discussions/20035) -- HIGH confidence
- Supabase PKCE provider token issue: [Auth Issue #1450](https://github.com/supabase/auth/issues/1450) -- HIGH confidence
- Supabase Spotify login docs: [Login with Spotify](https://supabase.com/docs/guides/auth/social-login/auth-spotify) -- HIGH confidence
- Spotify Get Current User's Playlists: [API Reference](https://developer.spotify.com/documentation/web-api/reference/get-a-list-of-current-users-playlists) -- HIGH confidence
- Flutter secure storage: [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) -- HIGH confidence (already in pubspec)
- Codebase analysis: Direct source file reading of all 60+ Dart files -- HIGH confidence
