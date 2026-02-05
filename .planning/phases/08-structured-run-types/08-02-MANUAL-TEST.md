# Phase 8 Plan 02: Manual Test Checklist

**Status:** Pending
**Created:** 2026-02-05
**Context:** Skipped during execution, run when convenient.

## Setup

1. Run `flutter run -d chrome`
2. Press Shift+R for hot restart
3. Navigate to "Plan Run" screen

## Tests

### Steady (existing flow)
- [ ] Select distance (e.g., 5K chip)
- [ ] Select pace from dropdown
- [ ] Summary card shows single distance/pace/duration/BPM
- [ ] Save works, snackbar confirms

### Warm-up/Cool-down
- [ ] Switch to "Warm-up" in run type selector
- [ ] Warm-up and cool-down duration sliders appear (1-15 min range)
- [ ] Set 5K, pace 6:00/km, warm-up 5min, cool-down 5min
- [ ] Summary shows 3 segments with colored timeline bar
- [ ] Warm-up/cool-down BPM is ~85% of main BPM
- [ ] Save works, snackbar confirms

### Intervals
- [ ] Switch to "Intervals" in run type selector
- [ ] Interval count, work duration, rest duration sliders appear
- [ ] Set 4 intervals, 2:00 work, 1:00 rest
- [ ] Summary shows multi-segment timeline with alternating work/rest
- [ ] Work segments show target BPM, rest segments show ~80% of target
- [ ] Save works, snackbar confirms

### Type Switching
- [ ] Select 10K distance and a pace
- [ ] Switch between Steady → Warm-up → Intervals → Steady
- [ ] Distance and pace selections preserved across switches

### Persistence
- [ ] Save a warm-up/cool-down plan
- [ ] Refresh browser, navigate back to /run-plan
- [ ] Current plan indicator shows saved plan info
