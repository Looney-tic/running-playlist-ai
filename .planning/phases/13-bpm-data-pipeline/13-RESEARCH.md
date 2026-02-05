# Phase 13: BPM Data Pipeline - Research

**Researched:** 2026-02-05
**Domain:** GetSongBPM API integration, HTTP client, BPM caching, half/double-time matching
**Confidence:** MEDIUM (API endpoint details partially verified; codebase patterns HIGH)

## Summary

This phase adds the ability to discover songs by BPM from the GetSongBPM API, cache results locally in SharedPreferences, and handle half/double-time matching (e.g., 85 BPM songs match 170 BPM cadence). The research covered five domains: (1) GetSongBPM API endpoint structure and authentication, (2) the Dart `http` package for making GET requests, (3) BPM cache design with SharedPreferences, (4) half/double-time matching algorithm, and (5) error handling patterns for HTTP in Flutter.

The GetSongBPM API provides a `/tempo/` endpoint that accepts a `bpm` parameter and returns a JSON array of up to 250 song objects. Authentication is via an `api_key` query parameter. The API is free but requires attribution (link back to getsongbpm.com). The Dart `http` package (latest version 1.6.0, recommended `^1.3.0` for stability) provides a simple `http.get()` API that returns a `Future<Response>`. The codebase already has established patterns for domain models, SharedPreferences persistence, and StateNotifier providers that this phase should follow exactly.

**Primary recommendation:** Build the BPM data pipeline using three layers: (1) a pure Dart API client class that wraps `http.get()` calls to the GetSongBPM `/tempo/` endpoint, (2) a `BpmSong` domain model with `toJson()`/`fromJson()`, and (3) a `BpmCachePreferences` class using the established SharedPreferences JSON pattern. For half/double-time matching, query both the target BPM and its half value (e.g., query 170 AND 85), then merge results with a `matchType` field.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| http | ^1.3.0 | HTTP GET requests to GetSongBPM API | Dart team maintained, simple API, already decided for this project |
| flutter_dotenv | ^6.0.0 | API key storage in .env file | Already in project, already used for Supabase keys |
| shared_preferences | ^2.5.4 | Local BPM result caching | Already in project, established JSON persistence pattern |
| flutter_riverpod | ^2.6.1 | State management for BPM lookup | Already in project, manual StateNotifier pattern |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| dart:convert | (built-in) | JSON encoding/decoding | Parsing API responses and cache serialization |
| dart:async | (built-in) | TimeoutException type | HTTP timeout error handling |
| dart:io | (built-in) | SocketException type | Network connectivity error handling |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| http ^1.3.0 | dio | Overkill for simple GET requests; http is simpler and already decided |
| SharedPreferences cache | SQLite/Drift | Overkill for caching BPM lookups; JSON blob in SharedPreferences matches project pattern |
| flutter_dotenv | --dart-define | dotenv already in project and in use for Supabase keys |

**Installation:**
```bash
flutter pub add http
```

This is the ONLY new dependency. Everything else is already in pubspec.yaml.

## GetSongBPM API Reference

### Authentication

- **Method:** API key as query parameter `api_key=YOUR_KEY`
- **Registration:** Free, requires email registration at https://getsongbpm.com/api
- **Requirement:** Attribution link back to getsongbpm.com is mandatory (in app store listing or about screen)

### Base URL

```
https://api.getsongbpm.com
```

### Endpoints

#### 1. Tempo Search: `GET /tempo/`

Search for songs by BPM value. This is the PRIMARY endpoint for this phase.

```
GET https://api.getsongbpm.com/tempo/?api_key=YOUR_KEY&bpm=170
```

**Parameters:**
| Parameter | Required | Description |
|-----------|----------|-------------|
| `api_key` | Yes | Your API key |
| `bpm` | Yes | Integer BPM value to search for |

**Response:** (MEDIUM confidence -- reconstructed from multiple sources)
```json
{
  "tempo": [
    {
      "song_id": "abc123",
      "song_title": "Song Name",
      "song_uri": "https://getsongbpm.com/song/song-name/abc123",
      "tempo": "170",
      "artist": {
        "id": "xyz789",
        "name": "Artist Name",
        "uri": "https://getsongbpm.com/artist/artist-name/xyz789"
      },
      "album": {
        "title": "Album Name",
        "uri": "https://getsongbpm.com/album/album-name/def456"
      }
    }
  ]
}
```

**Important notes:**
- Returns up to **250** song objects per request
- The `tempo` field is a **string**, not a number (e.g., `"170"`, not `170`)
- The response wraps results in a `"tempo"` array (not `"songs"` or `"results"`)
- Field names in the tempo endpoint use `song_id` and `song_title` (different from the `/song/` endpoint which uses `id` and `title`)

#### 2. Song Lookup: `GET /song/`

Get details for a specific song by ID. Useful for future enrichment but NOT needed for this phase.

```
GET https://api.getsongbpm.com/song/?api_key=YOUR_KEY&id=o2r0L
```

**Response:**
```json
{
  "song": {
    "id": "o2r0L",
    "title": "Master of Puppets",
    "uri": "https://getsongbpm.com/song/master-of-puppets/o2r0L",
    "tempo": "220",
    "time_sig": "4/4",
    "key_of": "Em",
    "open_key": "2m",
    "danceability": 55,
    "acousticness": 0,
    "artist": {
      "id": "nZR",
      "name": "Metallica",
      "uri": "https://getsongbpm.com/artist/metallica/nZR",
      "genres": ["heavy metal", "rock"],
      "from": "US",
      "mbid": "65f4f0c5-ef9e-490c-aee3-909e7ae6b2ab"
    }
  }
}
```

#### 3. Search: `GET /search/`

Search for artists or songs by name. NOT needed for this phase but noted for reference.

```
GET https://api.getsongbpm.com/search/?api_key=YOUR_KEY&type=song&lookup=master+of+puppets
```

### Rate Limits

**Confidence: LOW** -- No official rate limit documentation was found in any source. The API is free and community-oriented.

**Recommendation:** Implement defensive rate limiting regardless:
- Cache results aggressively (this is required by BPM-11 anyway)
- Add a minimum delay between API requests (500ms)
- Handle 429 (Too Many Requests) status code gracefully if it occurs
- The cache-first strategy means most lookups will not hit the API at all

### Error Responses

On error, the API returns a non-200 HTTP status code. The response body format for errors is not well-documented. Handle by checking `statusCode != 200` and treating the response as an error.

## Architecture Patterns

### Recommended Project Structure

```
lib/features/bpm_lookup/
  domain/
    bpm_song.dart              # BpmSong model (pure Dart, no Flutter imports)
    bpm_matcher.dart           # Half/double-time matching logic (pure Dart)
  data/
    getsongbpm_client.dart     # API client wrapping http.get()
    bpm_cache_preferences.dart # SharedPreferences cache for BPM results
  providers/
    bpm_lookup_providers.dart  # StateNotifier + providers for BPM lookup
```

### Pattern 1: Domain Model (BpmSong)

**What:** Immutable data class with `toJson()`/`fromJson()` matching the API response fields
**When to use:** For every domain model in this project

```dart
// Source: Matches existing pattern in lib/features/run_plan/domain/run_plan.dart
// Pure Dart -- no Flutter imports

/// How a song's BPM relates to the target cadence.
enum BpmMatchType {
  /// Song tempo directly matches target BPM.
  exact,
  /// Song is at half the target BPM (e.g., 85 BPM song for 170 cadence).
  halfTime,
  /// Song is at double the target BPM (e.g., 340 BPM song for 170 cadence).
  doubleTime;

  static BpmMatchType fromJson(String name) =>
      BpmMatchType.values.firstWhere((e) => e.name == name);
}

/// A song discovered from the GetSongBPM API.
class BpmSong {
  const BpmSong({
    required this.songId,
    required this.title,
    required this.artistName,
    required this.tempo,
    this.songUri,
    this.artistUri,
    this.albumTitle,
    this.matchType = BpmMatchType.exact,
  });

  factory BpmSong.fromJson(Map<String, dynamic> json) {
    return BpmSong(
      songId: json['songId'] as String,
      title: json['title'] as String,
      artistName: json['artistName'] as String,
      tempo: (json['tempo'] as num).toInt(),
      songUri: json['songUri'] as String?,
      artistUri: json['artistUri'] as String?,
      albumTitle: json['albumTitle'] as String?,
      matchType: json['matchType'] != null
          ? BpmMatchType.fromJson(json['matchType'] as String)
          : BpmMatchType.exact,
    );
  }

  /// Factory to parse from GetSongBPM API /tempo/ endpoint response item.
  factory BpmSong.fromApiJson(Map<String, dynamic> json, {BpmMatchType matchType = BpmMatchType.exact}) {
    final artist = json['artist'] as Map<String, dynamic>? ?? {};
    final album = json['album'] as Map<String, dynamic>?;
    return BpmSong(
      songId: json['song_id'] as String? ?? '',
      title: json['song_title'] as String? ?? '',
      artistName: artist['name'] as String? ?? '',
      tempo: int.tryParse(json['tempo']?.toString() ?? '') ?? 0,
      songUri: json['song_uri'] as String?,
      artistUri: artist['uri'] as String?,
      albumTitle: album?['title'] as String?,
      matchType: matchType,
    );
  }

  final String songId;
  final String title;
  final String artistName;
  final int tempo;
  final String? songUri;
  final String? artistUri;
  final String? albumTitle;
  final BpmMatchType matchType;

  Map<String, dynamic> toJson() => {
    'songId': songId,
    'title': title,
    'artistName': artistName,
    'tempo': tempo,
    'songUri': songUri,
    'artistUri': artistUri,
    'albumTitle': albumTitle,
    'matchType': matchType.name,
  };
}
```

**Key design decisions:**
- Two factories: `fromJson()` for cache deserialization (our format), `fromApiJson()` for API response parsing (their format)
- `tempo` stored as `int` (parsed from API string)
- `matchType` tracks how the song relates to the target BPM
- Nullable fields (`songUri`, `artistUri`, `albumTitle`) for defensive parsing

### Pattern 2: API Client Class

**What:** A class that wraps HTTP calls, parses responses, and throws typed exceptions
**When to use:** For any external API integration

```dart
// Source: Flutter official docs pattern + project conventions
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Exception thrown when the GetSongBPM API returns an error.
class BpmApiException implements Exception {
  const BpmApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => 'BpmApiException: $message (status: $statusCode)';
}

/// Client for the GetSongBPM API.
///
/// Makes GET requests to the /tempo/ endpoint to find songs by BPM.
/// Requires an API key passed via constructor.
class GetSongBpmClient {
  GetSongBpmClient({
    required String apiKey,
    http.Client? httpClient,
  })  : _apiKey = apiKey,
        _httpClient = httpClient ?? http.Client();

  final String _apiKey;
  final http.Client _httpClient;

  static const _baseUrl = 'api.getsongbpm.com';
  static const _timeout = Duration(seconds: 10);

  /// Fetches songs at the given BPM from the GetSongBPM API.
  ///
  /// Returns a list of [BpmSong] objects.
  /// Throws [BpmApiException] on API errors.
  /// Throws [SocketException] on network errors.
  /// Throws [TimeoutException] if the request exceeds 10 seconds.
  Future<List<BpmSong>> fetchSongsByBpm(int bpm, {BpmMatchType matchType = BpmMatchType.exact}) async {
    final uri = Uri.https(_baseUrl, '/tempo/', {
      'api_key': _apiKey,
      'bpm': bpm.toString(),
    });

    final response = await _httpClient.get(uri).timeout(_timeout);

    if (response.statusCode != 200) {
      throw BpmApiException(
        'API returned status ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final tempoList = body['tempo'] as List<dynamic>? ?? [];

    return tempoList
        .map((item) => BpmSong.fromApiJson(
              item as Map<String, dynamic>,
              matchType: matchType,
            ))
        .toList();
  }

  /// Disposes the underlying HTTP client.
  void dispose() {
    _httpClient.close();
  }
}
```

**Key design decisions:**
- Accepts `http.Client` via constructor for testability (inject a mock client in tests)
- Uses `Uri.https()` to build URLs safely
- 10-second timeout to prevent hanging requests
- Custom `BpmApiException` for API-specific errors
- Defensive parsing with `?? []` and `?? ''` fallbacks

### Pattern 3: Half/Double-Time Matching (Pure Domain Logic)

**What:** Given a target BPM, compute which BPM values to query and merge results
**When to use:** Core business logic for BPM-12 requirement

```dart
// Pure Dart -- no Flutter imports
// Source: Domain logic following project conventions

/// Computes BPM values to query for half/double-time matching.
///
/// For a target BPM of 170:
/// - Exact: query 170
/// - Half-time: query 85 (170 / 2)
/// - Double-time: query 340 (170 * 2) -- only if <= 300 (practical upper limit)
///
/// Returns a map of BPM value -> BpmMatchType.
class BpmMatcher {
  /// The maximum BPM value the API is likely to have songs for.
  static const maxQueryBpm = 300;

  /// The minimum BPM value that makes sense to query.
  static const minQueryBpm = 40;

  /// Returns BPM values to query with their match types.
  static Map<int, BpmMatchType> bpmQueries(int targetBpm) {
    final queries = <int, BpmMatchType>{
      targetBpm: BpmMatchType.exact,
    };

    final halfBpm = targetBpm ~/ 2;
    if (halfBpm >= minQueryBpm) {
      queries[halfBpm] = BpmMatchType.halfTime;
    }

    final doubleBpm = targetBpm * 2;
    if (doubleBpm <= maxQueryBpm) {
      queries[doubleBpm] = BpmMatchType.doubleTime;
    }

    return queries;
  }
}
```

**Algorithm:**
- For target 170 BPM: query 170 (exact) + 85 (half-time) = 2 API calls
- For target 85 BPM: query 85 (exact) + 170 (double-time) = 2 API calls
- For target 120 BPM: query 120 (exact) + 60 (half-time) = 2 API calls (no double since 240 < 300, actually query 240 too = 3 calls)
- Double-time only if result <= 300 BPM (practical limit)
- Half-time only if result >= 40 BPM (practical minimum)

### Pattern 4: Cache-First Lookup with SharedPreferences

**What:** Static class storing BPM lookup results as JSON, keyed by BPM value
**When to use:** To satisfy BPM-11 (cache requirement)

```dart
// Source: Matches existing pattern in run_plan_preferences.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache for BPM lookup results in SharedPreferences.
///
/// Stores results as JSON strings, keyed by BPM value.
/// Each entry includes a timestamp for optional TTL expiry.
class BpmCachePreferences {
  static const _prefix = 'bpm_cache_';

  /// Cache time-to-live: 7 days.
  static const cacheTtl = Duration(days: 7);

  /// Loads cached songs for a BPM value, or null if not cached/expired.
  static Future<List<BpmSong>?> load(int bpm) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('$_prefix$bpm');
    if (jsonString == null) return null;

    final json = jsonDecode(jsonString) as Map<String, dynamic>;

    // Check TTL
    final cachedAt = DateTime.parse(json['cachedAt'] as String);
    if (DateTime.now().difference(cachedAt) > cacheTtl) {
      await prefs.remove('$_prefix$bpm');
      return null;
    }

    final songs = (json['songs'] as List<dynamic>)
        .map((s) => BpmSong.fromJson(s as Map<String, dynamic>))
        .toList();
    return songs;
  }

  /// Saves songs for a BPM value with a timestamp.
  static Future<void> save(int bpm, List<BpmSong> songs) async {
    final prefs = await SharedPreferences.getInstance();
    final json = {
      'cachedAt': DateTime.now().toIso8601String(),
      'songs': songs.map((s) => s.toJson()).toList(),
    };
    await prefs.setString('$_prefix$bpm', jsonEncode(json));
  }

  /// Clears a specific BPM cache entry.
  static Future<void> clear(int bpm) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$bpm');
  }

  /// Clears all BPM cache entries.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
```

**Cache key structure:** `bpm_cache_170`, `bpm_cache_85`, etc.

**Cache entry JSON:**
```json
{
  "cachedAt": "2026-02-05T14:30:00.000",
  "songs": [ ... array of BpmSong.toJson() ... ]
}
```

**TTL design:** 7 days. BPM data is relatively stable (songs don't change tempo). A 7-day TTL balances freshness with API usage reduction. The TTL is checked on load; expired entries are auto-removed.

### Pattern 5: BPM Lookup Provider (StateNotifier)

**What:** Orchestrates the cache-first lookup strategy with API fallback
**When to use:** To wire everything together for the UI

```dart
// Follows project pattern from run_plan_providers.dart

/// State for a BPM lookup operation.
class BpmLookupState {
  const BpmLookupState({
    this.songs = const [],
    this.isLoading = false,
    this.error,
    this.targetBpm,
  });

  final List<BpmSong> songs;
  final bool isLoading;
  final String? error;
  final int? targetBpm;
}

class BpmLookupNotifier extends StateNotifier<BpmLookupState> {
  BpmLookupNotifier(this._client) : super(const BpmLookupState());

  final GetSongBpmClient _client;

  Future<void> lookupByBpm(int targetBpm) async {
    state = BpmLookupState(isLoading: true, targetBpm: targetBpm);

    try {
      // Get all BPM values to query (exact + half + double)
      final queries = BpmMatcher.bpmQueries(targetBpm);
      final allSongs = <BpmSong>[];

      for (final entry in queries.entries) {
        final bpm = entry.key;
        final matchType = entry.value;

        // Cache-first: check local cache
        var songs = await BpmCachePreferences.load(bpm);
        if (songs == null) {
          // Cache miss: fetch from API
          songs = await _client.fetchSongsByBpm(bpm, matchType: matchType);
          await BpmCachePreferences.save(bpm, songs);
        }

        allSongs.addAll(songs);
      }

      state = BpmLookupState(songs: allSongs, targetBpm: targetBpm);
    } on SocketException {
      state = BpmLookupState(
        error: 'No internet connection. Please check your network and try again.',
        targetBpm: targetBpm,
      );
    } on TimeoutException {
      state = BpmLookupState(
        error: 'Request timed out. Please try again.',
        targetBpm: targetBpm,
      );
    } on BpmApiException catch (e) {
      state = BpmLookupState(
        error: 'Could not fetch songs: ${e.message}',
        targetBpm: targetBpm,
      );
    } on FormatException {
      state = BpmLookupState(
        error: 'Received unexpected data from the server.',
        targetBpm: targetBpm,
      );
    } catch (e) {
      state = BpmLookupState(
        error: 'An unexpected error occurred. Please try again.',
        targetBpm: targetBpm,
      );
    }
  }
}
```

### Anti-Patterns to Avoid

- **Do NOT use `@riverpod` code-gen:** The project uses manual `StateNotifierProvider` definitions exclusively
- **Do NOT import Flutter in domain/:** The `bpm_song.dart` and `bpm_matcher.dart` must be pure Dart
- **Do NOT hardcode the API key:** Use `dotenv.env['GETSONGBPM_API_KEY']` to read from `.env`
- **Do NOT skip the `http.Client` constructor parameter:** Inject a mock client for unit tests
- **Do NOT parse `tempo` as a number directly from JSON:** The API returns it as a string `"170"`, parse with `int.tryParse()`
- **Do NOT make API calls for cached BPM values:** Always check cache first (BPM-11 requirement)
- **Do NOT cache half/double-time results under the target BPM key:** Cache each queried BPM individually (e.g., cache 170 and 85 separately). This way a future lookup for exactly 85 BPM can reuse the 85 cache.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP requests | Raw `HttpClient` from dart:io | `http` package | Cross-platform, simpler API, testable with mock Client |
| URL construction | String concatenation | `Uri.https()` | Handles encoding, query params, escaping |
| JSON parsing | Manual string splitting | `dart:convert` `jsonDecode()` | Standard library, handles all edge cases |
| BPM caching | Custom file-based cache | SharedPreferences JSON pattern | Matches existing project pattern, simple and sufficient |
| API key storage | Hardcoded strings | `flutter_dotenv` `.env` file | Already in project, keeps keys out of source code |
| Error type detection | String matching on error messages | Typed exceptions (`SocketException`, `TimeoutException`) | Reliable, cross-platform, standard Dart pattern |

**Key insight:** The `http` package's `http.Client` interface is critical for testability. By accepting an `http.Client` in the constructor, the API client can be unit tested with a mock client that returns predetermined responses without any network calls.

## Common Pitfalls

### Pitfall 1: macOS Network Entitlement Missing

**What goes wrong:** HTTP requests fail silently or throw `SocketException` on macOS
**Why it happens:** macOS sandboxed apps need `com.apple.security.network.client` entitlement for outbound connections
**How to avoid:** Add the entitlement to BOTH `DebugProfile.entitlements` and `Release.entitlements`
**Warning signs:** App works on iOS/Android but fails on macOS with network errors
**Current state:** The project's `DebugProfile.entitlements` has `network.server` but NOT `network.client`. `Release.entitlements` has neither. BOTH files need the client entitlement added.

```xml
<!-- Add to both DebugProfile.entitlements and Release.entitlements -->
<key>com.apple.security.network.client</key>
<true/>
```

### Pitfall 2: API Tempo Field is a String, Not a Number

**What goes wrong:** JSON parsing crashes or produces 0 for all tempos
**Why it happens:** The GetSongBPM API returns tempo as `"170"` (string), not `170` (number)
**How to avoid:** Parse with `int.tryParse(json['tempo']?.toString() ?? '') ?? 0`
**Warning signs:** All songs show 0 BPM, or `FormatException` thrown during parsing

### Pitfall 3: Different Field Names Between Endpoints

**What goes wrong:** `fromJson()` fails because field names don't match
**Why it happens:** The `/tempo/` endpoint uses `song_id` and `song_title`, while the `/song/` endpoint uses `id` and `title`
**How to avoid:** Use a dedicated `fromApiJson()` factory for API parsing and a separate `fromJson()` for cache deserialization (our own format)
**Warning signs:** Null or empty song titles when parsing tempo results

### Pitfall 4: Not Handling Empty API Responses

**What goes wrong:** App shows error when API returns 200 but empty results (no songs at that BPM)
**Why it happens:** Treating empty results as an error
**How to avoid:** An empty `tempo` array is a valid response. Show "No songs found at this BPM" message, not an error. Only treat non-200 status codes as errors.
**Warning signs:** "Error" message shown when searching for obscure BPM values

### Pitfall 5: Cache Key Collision Between Exact and Half-Time Results

**What goes wrong:** Querying 170 BPM caches both 170 and 85 results, but the 85 results are tagged with `halfTime` matchType. A later direct query for 85 BPM returns songs tagged as `halfTime` instead of `exact`.
**Why it happens:** Caching the matchType along with the songs
**How to avoid:** Cache songs with their raw BPM data only. Apply the `matchType` when reading from cache based on the current query context, not at cache write time. Alternatively, strip/re-assign `matchType` when loading from cache.
**Warning signs:** Songs show "half-time" badge when directly searching for that BPM

**Better approach:** Cache the raw API response data per-BPM (without matchType). When loading from cache, assign the matchType based on the relationship between the cached BPM and the current target BPM.

### Pitfall 6: Forgetting to Handle `FormatException` from `jsonDecode()`

**What goes wrong:** App crashes when API returns non-JSON response (e.g., HTML error page, maintenance page)
**Why it happens:** Assuming the response body is always valid JSON
**How to avoid:** Wrap `jsonDecode()` in try-catch for `FormatException`
**Warning signs:** Unhandled exception crash when API has temporary issues

### Pitfall 7: Not Closing the HTTP Client

**What goes wrong:** Resource leak, too many open connections
**Why it happens:** Creating `http.Client()` but never calling `.close()`
**How to avoid:** Call `_httpClient.close()` in the `dispose()` method. If using the top-level `http.get()` function (no explicit client), this is handled automatically.
**Warning signs:** Connection pool exhaustion on repeated lookups

## Code Examples

### Making a GET Request with the http Package

```dart
// Source: Flutter official docs https://docs.flutter.dev/cookbook/networking/fetch-data
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<List<BpmSong>> fetchSongs(String apiKey, int bpm) async {
  final uri = Uri.https('api.getsongbpm.com', '/tempo/', {
    'api_key': apiKey,
    'bpm': bpm.toString(),
  });

  final response = await http.get(uri).timeout(const Duration(seconds: 10));

  if (response.statusCode == 200) {
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final tempoList = json['tempo'] as List<dynamic>? ?? [];
    return tempoList
        .map((item) => BpmSong.fromApiJson(item as Map<String, dynamic>))
        .toList();
  } else {
    throw Exception('Failed to load songs: ${response.statusCode}');
  }
}
```

### Error Handling Pattern for HTTP Calls

```dart
// Source: Flutter docs + Dart best practices for http error handling
import 'dart:async';
import 'dart:io';

try {
  final songs = await client.fetchSongsByBpm(170);
  // Success
} on SocketException {
  // No internet connection
} on TimeoutException {
  // Request took too long
} on BpmApiException catch (e) {
  // API returned non-200 status
} on FormatException {
  // Response was not valid JSON
} catch (e) {
  // Unexpected error
}
```

**Import note for `SocketException`:** It lives in `dart:io` which is not available on web. If web support is needed, wrap the import conditionally. For this mobile-first app, `dart:io` import is fine.

### Unit Testing with Mock HTTP Client

```dart
// Source: http package testing pattern
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

test('fetchSongsByBpm returns parsed songs', () async {
  final mockClient = MockClient((request) async {
    expect(request.url.path, '/tempo/');
    expect(request.url.queryParameters['bpm'], '170');
    return http.Response(
      jsonEncode({
        'tempo': [
          {
            'song_id': 'abc123',
            'song_title': 'Test Song',
            'tempo': '170',
            'artist': {'name': 'Test Artist', 'id': 'xyz', 'uri': ''},
          }
        ]
      }),
      200,
    );
  });

  final client = GetSongBpmClient(
    apiKey: 'test-key',
    httpClient: mockClient,
  );

  final songs = await client.fetchSongsByBpm(170);
  expect(songs.length, 1);
  expect(songs.first.title, 'Test Song');
  expect(songs.first.tempo, 170);
});
```

**Key:** The `http` package provides `MockClient` from `package:http/testing.dart` which is purpose-built for this. No additional mocking library needed.

### Reading API Key from .env

```dart
// Source: Matches existing pattern in lib/main.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

// In provider setup:
final apiKey = dotenv.env['GETSONGBPM_API_KEY'] ?? '';
final client = GetSongBpmClient(apiKey: apiKey);
```

**.env file addition:**
```
GETSONGBPM_API_KEY=your_api_key_here
```

### BPM Half/Double-Time Unit Test

```dart
test('bpmQueries for 170 returns exact and half-time', () {
  final queries = BpmMatcher.bpmQueries(170);
  expect(queries[170], BpmMatchType.exact);
  expect(queries[85], BpmMatchType.halfTime);
  // 340 > 300, so no double-time
  expect(queries.containsKey(340), isFalse);
});

test('bpmQueries for 85 returns exact and double-time', () {
  final queries = BpmMatcher.bpmQueries(85);
  expect(queries[85], BpmMatchType.exact);
  expect(queries[170], BpmMatchType.doubleTime);
  // 42 >= 40, so half-time is included
  expect(queries[42], BpmMatchType.halfTime);
});

test('bpmQueries for 120 returns exact, half, and double', () {
  final queries = BpmMatcher.bpmQueries(120);
  expect(queries[120], BpmMatchType.exact);
  expect(queries[60], BpmMatchType.halfTime);
  expect(queries[240], BpmMatchType.doubleTime);
});
```

## Platform Configuration Required

### macOS (CRITICAL)

The macOS entitlements files currently lack the `com.apple.security.network.client` entitlement needed for outbound HTTP requests.

**Files to modify:**

1. `macos/Runner/DebugProfile.entitlements` -- Add:
```xml
<key>com.apple.security.network.client</key>
<true/>
```

2. `macos/Runner/Release.entitlements` -- Add:
```xml
<key>com.apple.security.network.client</key>
<true/>
```

### Android

Already configured. `android/app/src/main/AndroidManifest.xml` already has:
```xml
<uses-permission android:name="android.permission.INTERNET" />
```

### iOS

No additional configuration needed for HTTP requests.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `http` 0.13.x | `http` 1.x (^1.3.0) | 2023 | Major version bump, same API surface, better charset handling |
| `dart:io HttpClient` | `package:http` Client | Always preferred in Flutter | Cross-platform, testable, simpler API |
| Hardcoded API keys | `flutter_dotenv` .env file | Project convention | Keys not in source code |

**Deprecated/outdated:**
- `http` 0.13.x: Still functional but 1.x is current. Use `^1.3.0` for stability.
- `dart:io HttpClient` directly: Works but is platform-specific and harder to test.

## Open Questions

1. **Exact /tempo/ endpoint response format**
   - What we know: Returns a `"tempo"` JSON array with objects containing `song_id`, `song_title`, `tempo`, `artist` (nested), and `album` (nested). Up to 250 results.
   - What's unclear: The exact field names and nesting structure are reconstructed from blog posts and third-party wrapper code, not from official API docs (the API docs page returned 403)
   - Recommendation: Build defensively with nullable fields and `tryParse()`. Test against the live API during development to validate the actual response shape. Adjust `fromApiJson()` if the real response differs from research.

2. **Rate limits**
   - What we know: The API is free, requires attribution. No documented rate limits.
   - What's unclear: Whether there are undocumented rate limits or IP-based throttling
   - Recommendation: Implement cache-first strategy (required anyway for BPM-11), add a minimum delay between requests, and handle 429 responses gracefully

3. **Pagination on /tempo/ endpoint**
   - What we know: The endpoint returns "up to 250 objects" per request
   - What's unclear: Whether pagination is supported or needed. 250 songs per BPM value is likely sufficient for playlist generation.
   - Recommendation: Do not implement pagination. 250 results per BPM value is more than enough for Phase 14 playlist generation.

4. **Cache matchType approach**
   - What we know: Songs need a `matchType` field for UI display
   - What's unclear: Whether to store matchType in cache or compute it on load
   - Recommendation: Do NOT store matchType in cache. Store raw song data per queried BPM. Assign matchType when loading from cache based on the relationship between cached BPM and target BPM. This prevents Pitfall 5.

## Sources

### Primary (HIGH confidence)
- Existing codebase: `lib/features/run_plan/` -- domain model, preferences, providers patterns
- Existing codebase: `lib/features/taste_profile/` -- identical pattern confirmed
- [Flutter official docs - Fetch data from the internet](https://docs.flutter.dev/cookbook/networking/fetch-data) -- http package usage, error handling
- [pub.dev http package](https://pub.dev/packages/http) -- version 1.6.0 latest, ^1.3.0 recommended
- [pub.dev http package example](https://pub.dev/packages/http/example) -- `Uri.https()`, `http.get()`, `jsonDecode()` pattern
- `macos/Runner/DebugProfile.entitlements` -- verified missing `network.client` entitlement
- `macos/Runner/Release.entitlements` -- verified missing `network.client` entitlement
- `android/app/src/main/AndroidManifest.xml` -- verified INTERNET permission present

### Secondary (MEDIUM confidence)
- [GetSongBPM API page](https://getsongbpm.com/api) -- authentication method (api_key param), free with attribution, endpoint names (/tempo/, /search/, /song/, /artist/)
- [WebService::GetSongBPM Perl module source](https://raw.githubusercontent.com/ology/WebService-GetSongBPM/refs/heads/master/lib/WebService/GetSongBPM.pm) -- base URL (`api.getsongbpm.com`), endpoint paths, query parameters
- [Song endpoint response example](https://getsongbpm.com/api) -- Metallica "Master of Puppets" response with id, title, uri, tempo, artist fields
- Multiple web sources confirming /tempo/ endpoint uses `&bpm=VALUE` parameter

### Tertiary (LOW confidence)
- [Katie Hom blog - Beginning with APIs](https://katiehom.hashnode.dev/beginning-with-apis) -- tempo endpoint returns array called "tempo" with "song_title" fields, up to 250 objects, accessed via `data.tempo`
- Web search results mentioning `song_id`, `song_title`, `artist.name`, `album` fields in tempo response
- Rate limit information: not documented anywhere; defensive approach recommended

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- http package well-documented, all other deps already in project
- Architecture: HIGH -- follows exact patterns from run_plan and taste_profile features
- API endpoint structure: MEDIUM -- base URL and endpoint names verified via Perl wrapper source; response format reconstructed from multiple secondary sources since official docs returned 403
- Half/double-time matching: HIGH -- pure math, well-defined requirements
- Cache design: HIGH -- follows established SharedPreferences JSON pattern
- Error handling: HIGH -- standard Dart exception types, well-documented
- Pitfalls: HIGH -- macOS entitlement issue verified by reading actual files; API response format pitfalls from multiple sources
- Platform config: HIGH -- verified by reading actual entitlement and manifest files

**Research date:** 2026-02-05
**Valid until:** 2026-02-19 (API response format is LOW confidence and should be validated against live API early in development)
