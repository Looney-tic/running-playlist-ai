# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-01)

**Core value:** A runner enters their run plan and gets a playlist where every song's beat matches their footstrike cadence
**Current focus:** Phase 6 complete. Next: Phase 7 (Playlist Generation) -- requires Phases 3, 4, 6

## Current Position

Phase: 6 of 10 (Steady Run Planning) -- COMPLETE
Plan: 2 of 2 in current phase (all complete)
Status: Complete
Last activity: 2026-02-05 -- Completed 06-02-PLAN.md (run plan screen UI + persistence)

Progress: [████████░░░░░░░░░] ~47% (8/17 plans)

## Performance Metrics

**Velocity:**
- Total plans completed: 8
- Average duration: 8m
- Total execution time: 1.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 2/2 | 36m | 18m |
| 02 | 1/3 | 4m | 4m |
| 05 | 2/2 | 9m | 5m |
| 06 | 2/2 | 8m | 4m |

**Recent Trend:**
- Last 5 plans: 02-01 (4m), 05-01 (3m), 05-02 (6m), 06-01 (3m), 06-02 (5m)
- Trend: accelerating

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Supabase chosen as backend (research recommendation: relational data fits user-song-playlist model)
- GetSongBPM as primary BPM source (Spotify Audio Features API deprecated Nov 2024)
- BPM data pipeline is existential risk -- validate in Phase 3 before building generation logic
- **[01-01]** Used Riverpod 2.x stack (not 3.x) for code-gen compatibility
- **[01-01]** Manual Riverpod providers (not @riverpod code-gen) due to Dart 3.10 analyzer_plugin incompatibility
- **[01-01]** riverpod_lint removed due to same Dart 3.10 incompatibility
- **[01-02]** Used Supabase publishable key format (sb_publishable_xxx) matching current dashboard output
- **[post-01]** Web-first development strategy: phases 3-9 test on Chrome only, Phase 10 added for mobile hardening. Exception: Phase 2 (OAuth) tests mobile too.
- **[02-01]** AuthNotifier (ChangeNotifier) + GoRouter refreshListenable for reactive auth-guarded routing
- **[02-01]** LaunchMode.externalApplication on mobile (never inAppWebView) per iOS redirect failure research
- **[02-01]** All 6 Spotify scopes requested upfront to avoid re-authentication
- **[02-01]** Zero manual navigation after login/logout -- GoRouter redirect handles all routing reactively
- **[05-01]** Pure domain logic pattern: zero Flutter imports, static methods on calculator class, top-level helpers for parsing
- **[05-02]** Step/stride formula corrected: height*0.65 returns step length, not stride length. Removed erroneous *2 multiplier. Recalibrated speed-based default to 0.26*speed+0.25.
- **[05-02]** Pace input changed from text field to dropdown (3:00-10:00 in 15s increments) per user feedback
- **[05-02]** /stride route made public (no auth required) while Spotify auth is blocked
- **[06-01]** Segment-based RunPlan model: steady run = 1 segment, extends to intervals (Phase 8) without restructuring
- **[06-01]** Calibrated cadence always overrides formula-based BPM in RunPlanCalculator.targetBpm
- **[06-02]** Single active run plan stored in SharedPreferences (one plan at a time, sufficient for playlist gen)
- **[06-02]** Run plan screen reads stride state for height/calibrated cadence via strideNotifierProvider
- **[06-02]** Auth guard disabled entirely (return null) while Spotify Dashboard blocked

### Pending Todos

- **Phase 2 checkpoint:** Verify Spotify OAuth end-to-end (02-02 Task 2) when Spotify Developer Dashboard becomes available again. All code is written and committed — only needs dashboard config + human verification.
- **Cadence estimate accuracy:** Validate stride formula produces realistic cadence across full pace/height range. May need tuning based on user feedback.

### Blockers/Concerns

- **BLOCKER:** Spotify Developer Dashboard not accepting new app integrations (as of 2026-02-05). Phase 2 OAuth verification blocked. Retry periodically.
- Spotify extended access requires 250K MAU + registered business. App limited to 25 users in dev mode. Apply early.
- GetSongBPM API rate limits and coverage gaps unknown until Phase 3 validation.
- build_runner code-gen partially broken with Dart 3.10 (riverpod_generator fails, freezed untested). Monitor package updates.

## Session Continuity

Last session: 2026-02-05
Stopped at: Phase 6 complete (both plans). Next: Phase 7 (Playlist Generation) -- blocked on Phases 3 and 4.
Resume file: None
