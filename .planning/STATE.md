# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-06)

**Core value:** A runner enters their run plan and gets a playlist where every song's beat matches their footstrike cadence
**Current focus:** v1.3 Song Feedback & Freshness -- Phase 25 (Playlist Freshness) IN PROGRESS

## Current Position

Phase: 25 of 27 (Playlist Freshness)
Plan: 1 of 2 in current phase
Status: In progress
Last activity: 2026-02-08 -- Completed 25-01-PLAN.md

Progress: [██████░░░░] 60% (6/10 v1.3 plans)

## Performance Metrics

**Velocity:**
- Total plans completed: 38 (8 from v0.1 + 10 from v1.0 + 6 from v1.1 + 6 from v1.2 + 2 quick tasks + 6 from v1.3)
- Average duration: 5m
- Total execution time: ~2.5 hours

**By Phase (v1.3 -- current):**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 22 | 2/2 | 5m | 2.5m |
| 23 | 2/2 | 6m | 3m |
| 24 | 1/1 | 4m | 4m |
| 25 | 1/2 | 3m | 3m |

**Recent Trend:**
- Last 7 plans: 3m, 2m, 3m, 4m, 2m, 4m, 3m
- Trend: Stable (~3.0m/plan)

*Updated after each plan completion*

## Accumulated Context

### Decisions

Full decision log in PROJECT.md Key Decisions table.

- **22-01:** Used song.lookupKey in PlaylistGenerator rather than SongKey.normalize() directly for cleaner code
- **22-02:** Followed TasteProfileLibraryNotifier pattern exactly for SongFeedbackNotifier consistency
- **23-01:** likedSongWeight = 5 provides ranking boost without overpowering quality dimensions; disliked songs hard-filtered rather than soft-penalized
- **23-02:** Compact 32x32 icon buttons with 18px icons for feedback; withValues(alpha:) over deprecated withOpacity
- **24-01:** Derive liked/disliked lists inline from watched provider; Icons.thumbs_up_down for empty state
- **25-01:** 5-tier penalty decay (0/-8/-5/-2/0) for freshnessPenalty; 30-day auto-prune on PlayHistory construction

### Pending Todos

- **Manual UI verification:** Onboarding flow, empty states, shuffle, profile switching
- **Pre-existing test failure:** widget_test.dart expects "Home Screen" text
- **Pre-existing test failures:** 2 playlist provider error message tests (string mismatch)
- **User setup:** Add GETSONGBPM_API_KEY to .env before runtime API calls

### Blockers/Concerns

- GetSongBPM API rate limits and danceability field availability unconfirmed
- Research flag: Phase 27 (Taste Learning) may need `/gsd:research-phase` for affinity thresholds

## Session Continuity

Last session: 2026-02-08
Stopped at: Completed 25-01 (Freshness Data Layer), ready for 25-02 (Freshness Integration)
Resume file: .planning/phases/25-freshness/25-02-PLAN.md
