# Technology Stack

**Project:** Running Playlist AI
**Researched:** 2026-02-01
**Overall confidence:** MEDIUM-HIGH

## Critical Discovery: Spotify Audio Features Deprecated

Spotify deprecated the `GET /audio-features`, `GET /audio-analysis`, and `GET /recommendations` endpoints on November 27, 2024. New apps cannot access BPM/tempo data from Spotify. This is the single most important constraint for this project and dictates the BPM data sourcing strategy.

**Confidence:** HIGH (verified via Spotify developer community posts, multiple sources confirm)

---

## Recommended Stack

### Core Framework

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Flutter | 3.38.x (stable) | Cross-platform UI (web, Android, iOS) | Latest stable as of Jan 2026. Supports iOS 26, Xcode 26, macOS 26. Quarterly release cadence is reliable. | HIGH |
| Dart | 3.x (bundled) | Language | Bundled with Flutter SDK. | HIGH |

### State Management

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| flutter_riverpod | ^3.2.0 | State management | Community consensus for new projects in 2025/2026. Compile-time safety, auto-dispose, low boilerplate. Riverpod 3.0 adds reactive caching (useful for playlist data) and experimental offline persistence. Created by Provider author. | HIGH |
| riverpod_annotation | ^4.0.1 | Code generation for providers | Eliminates boilerplate. Use with build_runner and riverpod_generator. | HIGH |

### Backend / BaaS

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Supabase | (cloud) | Backend: auth, database, storage | PostgreSQL gives SQL joins for user-song-playlist relationships. Row-Level Security for user data. Transparent pricing (100K MAU free tier vs Firebase 50K). No vendor lock-in -- portable Postgres. Edge Functions for server-side logic. | HIGH |
| supabase_flutter | ^2.10.x | Flutter Supabase client | Official package. Handles auth, realtime, DB queries. Supports web, iOS, Android. | HIGH |

**Why not Firebase:** Firestore's document model requires denormalization that fights the relational nature of user-taste-song-playlist data. Migration away from Firebase is expensive. Supabase's SQL is a natural fit for "find songs where BPM BETWEEN X AND Y AND genre IN (user preferences)".

**Why not custom backend (NestJS etc.):** Unnecessary complexity for MVP. Supabase provides auth, DB, edge functions, and realtime out of the box. Can always migrate to custom backend later since data is in Postgres.

### Spotify Integration

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| spotify (Dart) | ^0.15.0 | Spotify Web API client | Pure Dart, works on all platforms (web, mobile). Covers playlist creation, user library, search, user profile. BSD-3 licensed. | MEDIUM |
| spotify_sdk | ^3.0.2 | Native Spotify SDK (mobile playback) | Wraps native iOS/Android Spotify SDKs for playback control. Only needed if preview playback is a feature. | LOW (may not need) |

**Strategy:** Use `spotify` Dart package for Web API calls (OAuth, playlist CRUD, search, user data). Only add `spotify_sdk` if native playback control is required. For web, Spotify Web Playback SDK is separate.

**Note:** The `spotify` package already annotates Spotify-deprecated endpoints with deprecation warnings, which is helpful.

### BPM / Tempo Data

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| GetSongBPM API | REST API | Primary BPM data source | Free API with attribution requirement (link back). CC BY 4.0 database. Provides BPM, key, time signature. No rate limit mentioned but expect reasonable use. | MEDIUM |
| Supabase (cache) | -- | BPM cache layer | Cache BPM lookups in Supabase Postgres to avoid repeated API calls and build own searchable BPM index. | HIGH |

**Why not Spotify audio-features:** Deprecated Nov 2024. New apps get 403 errors.

**Why not Soundcharts:** Commercial API, pricing not transparent. Overkill for BPM-only needs.

**Fallback options:** Tunebat (70M+ tracks, browser-based analysis), MusicBrainz/AcousticBrainz community data. GetSongBPM is the simplest starting point.

### Navigation

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| go_router | ^17.0.1 | Declarative routing | Official Flutter team package. Deep linking support (needed for Spotify OAuth redirect). Web URL support. | HIGH |

### Supporting Libraries

| Library | Version | Purpose | Confidence |
|---------|---------|---------|------------|
| freezed + json_serializable | latest | Immutable data classes, JSON serialization | HIGH |
| dio | ^5.x | HTTP client (for GetSongBPM API calls) | HIGH |
| flutter_secure_storage | latest | Store Spotify tokens securely on device | HIGH |
| url_launcher | latest | OAuth redirect handling | HIGH |
| flutter_dotenv | latest | Environment config (API keys) | MEDIUM |
| cached_network_image | latest | Album art caching | MEDIUM |

### Dev & Testing

| Library | Version | Purpose | Confidence |
|---------|---------|---------|------------|
| flutter_test | (bundled) | Widget and unit testing | HIGH |
| mocktail | latest | Mocking for tests | HIGH |
| build_runner | latest | Code generation (freezed, riverpod, json) | HIGH |
| very_good_analysis | latest | Lint rules | MEDIUM |

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Backend | Supabase | Firebase | Document DB fights relational data model; vendor lock-in; less generous free tier |
| Backend | Supabase | Custom NestJS | Unnecessary complexity for MVP; Supabase provides 90% of needs out of box |
| State mgmt | Riverpod 3 | Bloc | Too much boilerplate for small-medium team; Riverpod is community consensus for new projects |
| State mgmt | Riverpod 3 | GetX | Avoid entirely -- single-maintainer risk, maintenance crisis, technical debt trap |
| State mgmt | Riverpod 3 | Signals | Too immature, limited async support, small ecosystem |
| BPM source | GetSongBPM | Spotify audio-features | Deprecated Nov 2024, 403 for new apps |
| BPM source | GetSongBPM | Soundcharts | Commercial, opaque pricing |
| Routing | go_router | auto_route | go_router is official Flutter team package, simpler setup |
| Spotify client | spotify (Dart) | Raw HTTP | Package handles OAuth flows, typed responses, deprecation annotations |

---

## What NOT to Use

| Technology | Why Not |
|------------|---------|
| GetX | Single maintainer, maintenance crisis, community moving away. Technical debt trap. |
| Provider (for new code) | Superseded by Riverpod from the same author. Provider is maintenance mode. |
| Firebase Firestore | Wrong data model for relational song/user/playlist data. Vendor lock-in. |
| Spotify audio-features endpoint | Deprecated. Will get 403. |
| Hive (local DB) | supabase_flutter moved away from Hive to shared_preferences. If local DB needed, use Drift or Isar. |
| flutter_bloc | Not bad, just unnecessarily verbose for this project size. Riverpod does same with less code. |

---

## Installation

```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter

  # State management
  flutter_riverpod: ^3.2.0
  riverpod_annotation: ^4.0.1

  # Backend
  supabase_flutter: ^2.10.0

  # Spotify
  spotify: ^0.15.0

  # Navigation
  go_router: ^17.0.1

  # Data classes
  freezed_annotation: ^3.0.0
  json_annotation: ^4.9.0

  # HTTP
  dio: ^5.0.0

  # Utilities
  flutter_secure_storage: ^9.0.0
  url_launcher: ^6.0.0
  cached_network_image: ^3.0.0
  flutter_dotenv: ^5.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.0
  riverpod_generator: ^3.0.0
  freezed: ^3.0.0
  json_serializable: ^6.0.0
  mocktail: ^1.0.0
  very_good_analysis: ^7.0.0
```

---

## Architecture Implications

The stack choices imply this architecture:

```
Flutter App (Riverpod state, go_router navigation)
    |
    +-- Supabase (Auth, User profiles, BPM cache, Playlists)
    |
    +-- Spotify Web API via `spotify` package (OAuth, playlist CRUD, search, user library)
    |
    +-- GetSongBPM API via dio (BPM lookups, cached to Supabase)
```

**Stride/BPM calculation** is pure Dart logic (no external dependency needed). Pace + height/leg length -> stride rate -> target BPM. This is local computation.

**Playlist building algorithm** is also pure Dart, querying the BPM cache in Supabase for songs matching target BPM range, filtered by user taste profile.

---

## Sources

- [Flutter 3.38 release notes](https://docs.flutter.dev/release/release-notes) - HIGH confidence
- [Riverpod 3.0 - What's New](https://riverpod.dev/docs/whats_new) - HIGH confidence
- [flutter_riverpod on pub.dev](https://pub.dev/packages/flutter_riverpod) - HIGH confidence
- [supabase_flutter on pub.dev](https://pub.dev/packages/supabase_flutter) - HIGH confidence
- [spotify Dart package on pub.dev](https://pub.dev/packages/spotify) - HIGH confidence
- [go_router on pub.dev](https://pub.dev/packages/go_router) - HIGH confidence
- [Spotify API deprecation (Nov 2024)](https://medium.com/@soundnet717/spotify-audio-analysis-has-been-deprecated-what-now-4808aadccfcb) - HIGH confidence
- [Spotify developer community - 403 errors](https://community.spotify.com/t5/Spotify-for-Developers/Web-API-Get-Track-s-Audio-Features-403-error/td-p/6654507) - HIGH confidence
- [GetSongBPM API](https://getsongbpm.com/api) - MEDIUM confidence (free API, unclear on rate limits/reliability)
- [Supabase vs Firebase comparison](https://www.clickittech.com/software-development/supabase-vs-firebase/) - MEDIUM confidence
- [Flutter state management 2025/2026 comparison](https://www.creolestudios.com/flutter-state-management-tool-comparison/) - MEDIUM confidence
- [Soundcharts Audio Features API](https://soundcharts.com/en/audio-features-api) - LOW confidence (not investigated in depth)
