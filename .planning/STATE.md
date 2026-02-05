# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-05)

**Core value:** A runner enters their run plan and gets a playlist where every song's beat matches their footstrike cadence
**Current focus:** Phase 14 complete (Playlist Generation). All 3 plans delivered. Ready for Phase 15 (Playlist History).

## Current Position

Phase: 14 of 15 (Playlist Generation)
Plan: 3 of 3 in current phase
Status: Phase complete
Last activity: 2026-02-05 -- Completed 14-03-PLAN.md (PlaylistScreen UI + router)

Progress: [████████░░] 89% (8/9 plans in v1.0)

## Performance Metrics

**Velocity:**
- Total plans completed: 18 (10 from v0.1 + 8 from v1.0)
- Average duration: 6m
- Total execution time: 1.60 hours

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
| 13 | 2/2 | 7m | 4m |
| 14 | 3/3 | 15m | 5m |

**Recent Trend:**
- Last 5 plans: 13-02 (3m), 14-01 (7m), 14-02 (6m), 14-03 (2m)
- Trend: stable at 2-7m per plan

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
- **[13-02]** Cache keyed by queried BPM (not target BPM) for reuse across different target lookups
- **[13-02]** getSongBpmClientProvider reads API key from dotenv with empty string fallback
- **[13-02]** Catch-all in BpmLookupNotifier produces generic user-facing error message
- **[14-01]** PlaylistSong.toJson includes matchType (unlike BpmSong) -- display attribute in playlist context
- **[14-01]** PlaylistGenerator.generate() param order: required (runPlan, songsByBpm) before optional (tasteProfile, random)
- **[14-01]** Generator skips empty segments instead of crashing on clamp(1, 0)
- **[14-02]** PlaylistGenerationNotifier uses GetSongBpmClient + BpmCachePreferences directly (not BpmLookupNotifier) for batch multi-BPM fetching
- **[14-02]** Pre-populate SharedPreferences mock values in tests for reliable notifier loading
- **[14-02]** on Exception catch-all instead of bare catch for very_good_analysis compliance
- **[14-03]** ConsumerWidget (not ConsumerStatefulWidget) for PlaylistScreen -- all state via providers
- **[14-03]** Bottom sheet for song tap gives user choice of Spotify or YouTube (not direct link)
- **[14-03]** No canLaunchUrl pre-check -- just call launchUrl and handle failure
- **[14-03]** _ComingSoonScreen retained for /playlist-history (Phase 15)

### Pending Todos

- **Manual UI verification:** Phase 8 structured run types (saved to 08-02-MANUAL-TEST.md)
- **Manual UI verification:** Taste profile screen (genre selection, artist input, energy level, persistence)
- **Manual UI verification:** Playlist generation screen (all 5 states, song tap, clipboard copy)
- **Cadence estimate accuracy:** Validate stride formula across full pace/height range
- **Pre-existing test failure:** widget_test.dart expects "Home Screen" text that no longer exists
- **User setup:** Add GETSONGBPM_API_KEY to .env before runtime API calls

### Blockers/Concerns

- GetSongBPM API rate limits and coverage gaps unknown until runtime validation
- build_runner code-gen partially broken with Dart 3.10 (monitor package updates)

## Session Continuity

Last session: 2026-02-05T18:35:00Z
Stopped at: Completed 14-03-PLAN.md (PlaylistScreen UI + router) -- Phase 14 complete
Resume file: None
