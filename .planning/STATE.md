# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-08)

**Core value:** A runner enters their run plan and gets a playlist where every song's beat matches their footstrike cadence
**Current focus:** Phase 30 complete -- next phase in v1.4

## Current Position

Phase: 30 (third of 6 in v1.4) -- Complete
Plan: 02 of 2 complete
Status: Phase complete
Last activity: 2026-02-09 -- Completed 30-02-PLAN.md (Search UI)

Progress: [#########################.....] 79% (48/53 plans estimated)

## Performance Metrics

**Velocity:**
- Total plans completed: 48 (8 from v0.1 + 10 from v1.0 + 6 from v1.1 + 6 from v1.2 + 2 quick tasks + 10 from v1.3 + 6 from v1.4)
- Average duration: 5m
- Total execution time: ~3 hours

**By Milestone:**

| Milestone | Phases | Plans | Duration |
|-----------|--------|-------|----------|
| v0.1 | 4 | 8 | ~40m |
| v1.0 | 5 | 10 | ~50m |
| v1.1 | 3 | 6 | ~30m |
| v1.2 | 3 | 6 | ~30m |
| v1.3 | 6 | 10 | ~30m |
| v1.4 | 6 | ~11 | -- |

## Accumulated Context

### Decisions

Full decision log in PROJECT.md Key Decisions table.

v1.3 decisions archived.

v1.4 decisions:
- Followed SongFeedback pattern exactly for RunningSong feature consistency
- RunningSongSource enum uses orElse fallback to curated for forward-compatibility
- Captured WidgetRef before showModalBottomSheet for provider access inside builder closure
- Used sheetContext for Navigator.pop and outer context for ScaffoldMessenger.showSnackBar
- Running song keys merged via Set.addAll() into liked set for scoring -- idempotent with explicit likes
- Synthetic feedback merge order {...synthetic, ...real} ensures real feedback takes precedence
- Corrected plan test: songBpm 180 at cadence 170 is none (10 > ceil(170*0.05)=9 tolerance)
- BPM chip uses cadence passed as int from parent (provider decoupled from card widget)
- Abstract SongSearchService interface kept despite one-member-abstract lint for Spotify extensibility
- Separate curatedSongsListProvider for search, decoupled from scoring providers
- Used Flutter SDK debounce pattern (Timer+Completer+CancelException) for Autocomplete
- Track _lastQuery in state for options view highlighting since optionsViewBuilder has no direct text access

### Pending Todos

- **Manual UI verification:** Onboarding flow, empty states, shuffle, profile switching, feedback, taste suggestions, song search
- **Pre-existing test failure:** widget_test.dart expects "Home Screen" text
- **Pre-existing test failures:** 2 playlist provider error message tests (string mismatch)
- **User setup:** Add GETSONGBPM_API_KEY to .env before runtime API calls

### Blockers/Concerns

- Spotify Developer Dashboard not accepting new app registrations (since Dec 2025)
- Spotify Developer Mode requires Premium account (Feb 2026 policy change)
- Build Spotify phases with mocks; defer live testing to when Dashboard opens

## Session Continuity

Last session: 2026-02-09
Stopped at: Phase 30 complete. Next: next phase in v1.4 milestone
Resume file: .planning/ROADMAP.md
