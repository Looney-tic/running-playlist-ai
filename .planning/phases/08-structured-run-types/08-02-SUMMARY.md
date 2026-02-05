---
phase: 08-structured-run-types
plan: 02
subsystem: run-plan-ui
tags: [ui, segmented-button, sliders, segment-timeline, riverpod]
dependency-graph:
  requires: [08-01]
  provides: [structured-run-ui, run-type-selector, segment-timeline]
  affects: [07-xx]
tech-stack:
  added: []
  patterns: [segmented-button-enum, conditional-config-forms, proportional-timeline-bar]
key-files:
  created: []
  modified:
    - lib/features/run_plan/presentation/run_plan_screen.dart
decisions:
  - id: "08-02-segmented-button"
    description: "SegmentedButton<RunType> for run type selection -- Material 3 standard"
  - id: "08-02-colored-timeline"
    description: "Proportional colored bar for segment visualization -- amber warm-up, blue cool-down, deep orange work, green rest"
metrics:
  duration: 4m
  completed: 2026-02-05
---

# Phase 8 Plan 02: Structured Run Types UI Summary

Extended RunPlanScreen with run type selector, type-specific config forms (warm-up/cool-down sliders, interval count/work/rest sliders), segment timeline visualization, and updated save logic.

## What Was Built

### Run Type Selector
- `SegmentedButton<RunType>` with Steady / Warm-up / Intervals
- Icons: trending_flat, show_chart, stacked_bar_chart
- Switching preserves distance and pace selections

### Warm-Up/Cool-Down Config
- Card with two Sliders: warm-up (1-15 min) and cool-down (1-15 min)
- Defaults: 5 min each
- Only visible when Warm-up type selected

### Interval Config
- Card with three Sliders: count (2-20), work (30-600s), rest (15-300s)
- Defaults: 4 intervals, 2:00 work, 1:00 rest
- Only visible when Intervals type selected

### Segment Timeline
- Colored proportional bar showing segment durations
- Colors: amber (warm-up), primary (main/work), green (rest), blue (cool-down)
- Per-segment BPM breakdown list below the bar
- Shows total duration and segment count

### Updated Save Logic
- Branches on `_selectedRunType`
- Steady: existing `createSteadyPlan` (unchanged)
- Warm-up: `createWarmUpCoolDownPlan` with slider values
- Intervals: `createIntervalPlan` with slider values

## Commits

| Commit    | Description                                              |
|-----------|----------------------------------------------------------|
| `420e83c` | feat(08-02): run type selector, config forms, timeline   |

## Verification Results

- `dart analyze` -- 0 issues
- `flutter test` -- all 67 domain tests pass (99 total including pre-existing widget_test)
- Manual verification deferred (checklist saved to 08-02-MANUAL-TEST.md)

## Deviations from Plan

- Manual checkpoint deferred -- test checklist saved for later verification

## Next Phase Readiness

- All three run types can be configured and saved through the UI
- Phase 7 (Playlist Generation) can read any plan type via `runPlanNotifierProvider`
