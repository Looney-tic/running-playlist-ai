# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-05)

**Core value:** A runner enters their run plan and gets a playlist where every song's beat matches their footstrike cadence
**Current focus:** Milestone v1.0 started — defining requirements and roadmap for no-Spotify build

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-02-05 — Milestone v1.0 started (no-Spotify pivot)

Progress: [██████████░░░░░░░] ~59% (10/17 plans from v0.1)

## Performance Metrics

**Velocity:**
- Total plans completed: 10 (from v0.1)
- Average duration: 7m
- Total execution time: 1.2 hours

**By Phase (v0.1):**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 2/2 | 36m | 18m |
| 02 | 1/3 | 4m | 4m |
| 05 | 2/2 | 9m | 5m |
| 06 | 2/2 | 8m | 4m |
| 08 | 2/2 | 7m | 4m |

**Recent Trend:**
- Last 5 plans: 05-02 (6m), 06-01 (3m), 06-02 (5m), 08-01 (3m), 08-02 (4m)
- Trend: accelerating

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- **[v1.0 pivot]** Build without Spotify integration — Developer Dashboard blocked, questionnaire taste profile better for running
- **[v1.0 pivot]** GetSongBPM API for BPM data — Spotify audio-features deprecated Nov 2024
- **[v1.0 pivot]** `http` package for HTTP client — simple GET requests, Dart team maintained
- **[v1.0 pivot]** `url_launcher` for external play links — open songs in Spotify/YouTube browser
- Supabase chosen as backend (research recommendation: relational data fits user-song-playlist model)
- **[01-01]** Used Riverpod 2.x stack (not 3.x) for code-gen compatibility
- **[01-01]** Manual Riverpod providers (not @riverpod code-gen) due to Dart 3.10 analyzer_plugin incompatibility
- **[05-01]** Pure domain logic pattern: zero Flutter imports, static methods on calculator class
- **[05-02]** Pace input changed from text field to dropdown (3:00-10:00 in 15s increments)
- **[06-01]** Segment-based RunPlan model: steady run = 1 segment, extends to intervals without restructuring
- **[06-01]** Calibrated cadence always overrides formula-based BPM in RunPlanCalculator.targetBpm
- **[06-02]** Single active run plan stored in SharedPreferences (one plan at a time)
- **[08-01]** Rest after every work interval (including last) before cool-down
- **[08-02]** SegmentedButton<RunType> for run type selection (Material 3 standard)

### Pending Todos

- **Manual UI verification:** Phase 8 structured run types (saved to 08-02-MANUAL-TEST.md)
- **Cadence estimate accuracy:** Validate stride formula across full pace/height range

### Blockers/Concerns

- **RESOLVED:** Spotify Developer Dashboard blocked — pivoted to no-Spotify approach
- GetSongBPM API rate limits and coverage gaps unknown until BPM pipeline validation
- build_runner code-gen partially broken with Dart 3.10 (monitor package updates)

## Session Continuity

Last session: 2026-02-05
Stopped at: Milestone v1.0 started, defining requirements and roadmap
Resume file: None
