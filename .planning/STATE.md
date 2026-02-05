# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-05)

**Core value:** A runner enters their run plan and gets a playlist where every song's beat matches their footstrike cadence
**Current focus:** Phase 13 in progress (BPM Data Pipeline). Plan 01 complete, Plan 02 next.

## Current Position

Phase: 13 of 15 (BPM Data Pipeline)
Plan: 1 of 2 in current phase
Status: In progress
Last activity: 2026-02-05 -- Completed 13-01-PLAN.md (BPM domain models, API client, tests)

Progress: [████░░░░░░] 44% (4/9 plans in v1.0)

## Performance Metrics

**Velocity:**
- Total plans completed: 14 (10 from v0.1 + 4 from v1.0)
- Average duration: 7m
- Total execution time: 1.3 hours

**By Phase (v0.1):**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 2/2 | 36m | 18m |
| 05 | 2/2 | 9m | 5m |
| 06 | 2/2 | 8m | 4m |
| 08 | 2/2 | 7m | 4m |

**By Phase (v1.0):**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 11 | 1/1 | 1m | 1m |
| 12 | 2/2 | 4m | 2m |
| 13 | 1/2 | 4m | 4m |

**Recent Trend:**
- Last 5 plans: 11-01 (1m), 12-01 (2m), 12-02 (2m), 13-01 (4m)
- Trend: stable (13-01 slightly longer due to 33 unit tests)

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- **[v1.0 pivot]** Build without Spotify integration -- questionnaire taste profile, GetSongBPM for BPM data
- **[v1.0 pivot]** `http` package for HTTP client, `url_launcher` for external play links
- **[v1.0 pivot]** SharedPreferences for all local persistence (taste profile, BPM cache, playlist history)
- **[11-01]** Kept HomeScreen as ConsumerWidget for future taste profile state
- **[11-01]** Auth files left dormant (not deleted) in lib/features/auth/
- **[12-01]** RunningGenre enum names align with Spotify genre seeds for future API integration
- **[12-01]** addArtist returns bool for UI rejection feedback; case-insensitive dedup preserves original casing
- **[12-02]** Local UI state pattern for TasteProfileScreen: genres/artists/energy in State class, synced to notifier only on save
- **[12-02]** FilterChip (not ChoiceChip) for multi-select genre picking; TextField hidden at max artists
- **[13-01]** toJson excludes matchType to avoid cache key collisions (assigned at load time by notifier)
- **[13-01]** BpmMatcher bounds: minQueryBpm=40, maxQueryBpm=300 for practical API coverage
- **[13-01]** http.Client constructor injection pattern for testability with MockClient

### Pending Todos

- **Manual UI verification:** Phase 8 structured run types (saved to 08-02-MANUAL-TEST.md)
- **Manual UI verification:** Taste profile screen (genre selection, artist input, energy level, persistence)
- **Cadence estimate accuracy:** Validate stride formula across full pace/height range
- **Pre-existing test failure:** widget_test.dart expects "Home Screen" text that no longer exists
- **User setup:** Add GETSONGBPM_API_KEY to .env before Phase 13-02 integration testing

### Blockers/Concerns

- GetSongBPM API rate limits and coverage gaps unknown until Phase 13 validation
- build_runner code-gen partially broken with Dart 3.10 (monitor package updates)

## Session Continuity

Last session: 2026-02-05
Stopped at: Completed 13-01-PLAN.md (BPM domain models, API client, tests) -- ready for 13-02
Resume file: None
