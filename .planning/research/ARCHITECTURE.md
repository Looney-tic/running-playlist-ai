# Architecture Patterns

**Domain:** BPM-matched running playlist generator (Flutter + Spotify)
**Researched:** 2026-02-01
**Overall confidence:** MEDIUM

## Critical Constraint: Spotify Audio Features API Is Deprecated

As of November 27, 2024, Spotify's `GET /audio-features/{id}` and `GET /audio-analysis/{id}` endpoints return 403 for new apps. New applications cannot get BPM/tempo data from Spotify. This is the single most important architectural constraint: **BPM data must come from an external source, not Spotify**.

Recommended alternative: **GetSongBPM API** (free, CC BY 4.0, requires attribution link). Fallback: Soundcharts Audio Features API (commercial, richer identifier support). Both can be queried by Spotify track ID or ISRC.

Sources: [Spotify deprecation announcement](https://developer.spotify.com/blog/2024-11-27-changes-to-the-web-api), [GetSongBPM API](https://getsongbpm.com/api), [Soundcharts](https://soundcharts.com/en/audio-features-api)

---

## Recommended Architecture

Flutter clean architecture with Riverpod, feature-first organization. Three-layer separation (Data / Domain / Presentation) per feature. Backend is a lightweight API proxy + BPM cache (can start as Cloud Functions or Supabase Edge Functions).

```
                     +------------------+
                     |   Flutter App    |
                     |  (Presentation)  |
                     +--------+---------+
                              |
                     +--------+---------+
                     |  Domain Layer    |
                     | (Use Cases /     |
                     |  Entities)       |
                     +--------+---------+
                              |
              +---------------+---------------+
              |               |               |
     +--------+---+  +-------+----+  +-------+------+
     | Spotify    |  | BPM Data   |  | Local        |
     | API Client |  | Service    |  | Storage      |
     | (Auth,     |  | (GetSong   |  | (Preferences,|
     |  Playlists,|  |  BPM /     |  |  Calibration,|
     |  Library)  |  |  Cache)    |  |  Run Plans)  |
     +------------+  +------------+  +--------------+
```

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| **Auth Module** | Spotify OAuth PKCE flow, token refresh, session state | Spotify API, all modules needing auth |
| **Spotify Client** | User library, saved tracks, create/modify playlists, search | Auth Module, Playlist Generator |
| **BPM Data Service** | Fetch and cache BPM for tracks; resolve Spotify ID to BPM | GetSongBPM API (or Soundcharts), Local Cache |
| **Stride Calculator** | Compute target cadence (SPM) from height, pace, optional calibration | Run Plan Engine |
| **Run Plan Engine** | Define run structure: steady-state, warm-up/cool-down ramps, intervals with target cadences per segment | Stride Calculator, Playlist Generator |
| **Taste Profile** | Aggregate user genre/artist preferences from Spotify top tracks + manual overrides | Spotify Client, Playlist Generator |
| **Playlist Generator** | Core algorithm: match songs to run segments by BPM + taste score, assemble ordered playlist | All of the above |
| **Local Storage** | Persist user settings, calibration data, cached BPM, generated playlists | All modules |

### Data Flow

**Generating a playlist (happy path):**

```
1. User inputs: run type, duration, pace, height
        |
2. Stride Calculator --> target cadence (SPM) per segment
        |
3. Run Plan Engine --> list of segments [{duration, targetBPM, intensity}]
        |
4. Taste Profile --> candidate track pool (from Spotify library + top tracks)
        |
5. BPM Data Service --> enrich candidates with BPM
   (cache hit or fetch from GetSongBPM)
        |
6. Playlist Generator --> score & rank candidates per segment
   Score = f(|trackBPM - targetBPM|, taste_affinity, energy_match)
   Select best track per segment, avoid repeats
        |
7. Spotify Client --> create playlist, add tracks in order
        |
8. Return playlist URL to user
```

**BPM data pipeline detail:**

```
Spotify track ID --> check local BPM cache
  |-- cache hit --> return BPM
  |-- cache miss --> query GetSongBPM API by Spotify ID or artist+title
       |-- found --> cache locally, return BPM
       |-- not found --> mark track as "BPM unknown", exclude from candidates
```

**Cadence calculation:**

```
Inputs: height_cm, target_pace (min/km), experience_level
Base stride = pace_to_stride_lookup(target_pace)
Height adjustment = (height_cm - 170) * 0.001
Adjusted stride = base_stride + height_adjustment
Cadence (SPM) = (pace_speed_m_per_min) / adjusted_stride
Optional: user calibration multiplier from actual step count
Target BPM = Cadence (or Cadence / 2 for half-time matching)
```

Source: [Molab cadence guide](https://molab.me/running-cadence-the-ultimate-guide/), [Movaia calculator](https://movaia.com/cadence-calculator/)

---

## Run Plan Types (Segment Structures)

| Plan Type | Segments | BPM Profile |
|-----------|----------|-------------|
| **Steady** | Single segment at target cadence | Flat BPM throughout |
| **Warm-up / Cool-down** | 3 segments: ramp up, steady, ramp down | Low BPM --> target --> low BPM |
| **Interval** | Alternating work/rest segments | High BPM / low BPM alternating |
| **Progressive** | Gradually increasing pace | BPM ramps up over duration |

Each segment produces a `{duration_seconds, target_bpm, bpm_tolerance}` tuple that the Playlist Generator uses for matching.

---

## Patterns to Follow

### Pattern 1: Feature-First Clean Architecture with Riverpod

**What:** Organize code by feature (auth, stride, playlist, etc.), each with data/domain/presentation layers. Use Riverpod for DI and state.

**Why:** This is the current Flutter community standard (2025-2026). Riverpod 3.0 provides compile-time safety, testability without widget tree dependency, and minimal boilerplate.

```
lib/
  core/               # Shared: network, errors, constants, theme
  features/
    auth/
      data/            # SpotifyAuthDataSource, AuthRepository impl
      domain/          # AuthEntity, AuthRepository interface, LoginUseCase
      presentation/    # LoginScreen, auth_provider.dart
    stride/
      data/            # CalibrationLocalDataSource
      domain/          # StrideCalculator, CadenceEntity
      presentation/    # StrideSetupScreen, stride_provider.dart
    run_plan/
      domain/          # RunPlan, RunSegment, RunPlanFactory
      presentation/    # PlanBuilderScreen, plan_provider.dart
    bpm/
      data/            # GetSongBpmApiClient, BpmCacheDataSource
      domain/          # BpmRepository, EnrichTracksUseCase
    taste/
      data/            # SpotifyTopTracksDataSource
      domain/          # TasteProfile, TasteScorer
      presentation/    # PreferencesScreen
    playlist/
      domain/          # PlaylistGenerator, TrackSelector
      presentation/    # GenerateScreen, playlist_provider.dart
```

**Confidence:** HIGH (official Flutter docs + widespread community adoption)

Source: [Flutter architecture guide](https://docs.flutter.dev/app-architecture/guide), [Riverpod clean architecture template](https://github.com/ssoad/flutter_riverpod_clean_architecture)

### Pattern 2: BPM Cache-First with Background Enrichment

**What:** When a user connects Spotify, immediately start fetching BPM data for their saved tracks in the background. Store in local DB (Hive, Isar, or SQLite). Playlist generation then hits cache, not network.

**Why:** GetSongBPM API has rate limits. Pre-caching avoids blocking playlist generation on network calls. Users with large libraries need this for responsive UX.

### Pattern 3: Half-Time / Double-Time BPM Matching

**What:** A 150 BPM song works for both 150 SPM cadence AND 75 SPM (walking) or 300 SPM (unlikely but theoretically). Always consider BPM, BPM/2, and BPM*2 when matching.

**Why:** This dramatically expands the candidate pool. A song at 170 BPM matches a 170 SPM runner, but a song at 85 BPM also works (runner takes two steps per beat).

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Depending on Spotify for BPM Data

**What:** Building the app assuming Spotify's audio-features endpoint will work.
**Why bad:** It returns 403 for all new apps since Nov 2024. No workaround exists.
**Instead:** Use GetSongBPM or similar external BPM source from day one.

### Anti-Pattern 2: Synchronous BPM Fetching During Playlist Generation

**What:** Fetching BPM for each track one-by-one during the generate flow.
**Why bad:** Blocks the user for minutes. GetSongBPM rate limits will throttle you.
**Instead:** Background enrichment + cache. Generate from cached data only.

### Anti-Pattern 3: Over-Engineering the Backend Early

**What:** Building a full custom backend (user accounts, BPM processing pipeline, recommendation engine) before validating the core product.
**Why bad:** Delays time-to-value. The MVP can work with client-side logic + direct API calls + local storage.
**Instead:** Start with a thin backend (or none -- just a serverless proxy for API keys). Add backend complexity when user scale demands it.

### Anti-Pattern 4: Exact BPM Matching Only

**What:** Requiring an exact BPM match (e.g., exactly 172 BPM for 172 SPM).
**Why bad:** Too few songs match. Users get repetitive playlists or generation failures.
**Instead:** Use a tolerance window (e.g., +/- 5 BPM) and score by proximity. Include half/double-time matches.

---

## Suggested Build Order

Dependencies flow downward. Each phase builds on the previous.

```
Phase 1: Foundation
  Auth Module (Spotify OAuth PKCE)
  Project skeleton (clean architecture, Riverpod, routing)
  Local storage setup
      |
Phase 2: Data Pipeline
  Spotify Client (fetch user library, top tracks)
  BPM Data Service + GetSongBPM integration
  Background BPM enrichment + cache
      |
Phase 3: Core Engine
  Stride Calculator (height + pace --> cadence)
  Run Plan Engine (steady, warmup/cooldown, interval)
  Taste Profile (from Spotify data + manual prefs)
      |
Phase 4: Playlist Generation
  Playlist Generator algorithm (BPM matching + taste scoring)
  Spotify playlist creation
  Generate flow UI
      |
Phase 5: Polish & Calibration
  Step-count calibration (device sensors)
  Progressive/custom run plans
  Playlist preview & editing
  History & re-generation
```

**Rationale:**
- Auth is a hard prerequisite for everything (Spotify data access).
- BPM data pipeline must exist before playlist generation can work, and background enrichment needs time to populate the cache, so it should come early.
- Stride calculator and run plans are independent of Spotify data, but must exist before playlist generation.
- Playlist generation is the core value prop but depends on all upstream components.
- Calibration and polish are enhancements on a working product.

---

## Scalability Considerations

| Concern | MVP (100 users) | Growth (10K users) | Scale (100K+ users) |
|---------|-----------------|---------------------|----------------------|
| BPM data | Client fetches from GetSongBPM directly | Backend proxy with shared BPM cache (Redis/Firestore) | Pre-populated BPM database, own audio analysis |
| Spotify API rate limits | No issue | Per-user token rate limits manageable | Need request queuing, caching of Spotify responses |
| Playlist generation | Client-side, instant | Client-side, instant | Client-side still works; server-side optional for sharing |
| Backend | None or thin proxy | Serverless functions (Cloud Run / Supabase Edge) | Dedicated service for BPM aggregation + recommendations |

---

## Sources

- [Spotify API deprecation (Nov 2024)](https://developer.spotify.com/blog/2024-11-27-changes-to-the-web-api) -- HIGH confidence
- [GetSongBPM API docs](https://getsongbpm.com/api) -- MEDIUM confidence (verified via official site)
- [Flutter architecture guide](https://docs.flutter.dev/app-architecture/guide) -- HIGH confidence (official docs)
- [Riverpod clean architecture patterns](https://foresightmobile.com/blog/best-flutter-state-management) -- MEDIUM confidence
- [Cadence/stride formulas](https://molab.me/running-cadence-the-ultimate-guide/) -- MEDIUM confidence (multiple sources agree)
- [Spotify community: Audio Features 403](https://community.spotify.com/t5/Spotify-for-Developers/Web-API-Get-Track-s-Audio-Features-403-error/td-p/6654507) -- HIGH confidence
