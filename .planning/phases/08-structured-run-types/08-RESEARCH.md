# Phase 8: Structured Run Types - Research

**Researched:** 2026-02-05
**Domain:** Multi-segment run plan creation (warm-up/cool-down, interval training), segment-aware BPM targeting, Flutter form UX for dynamic segment configuration
**Confidence:** HIGH

## Summary

Phase 8 extends the existing segment-based RunPlan model (built in Phase 6 with Phase 8 in mind) to support two new run types: warm-up/cool-down runs and interval training runs. The domain model (`RunPlan`, `RunSegment`, `RunType`) already supports multiple segments and the `warmUpCoolDown` and `interval` enum values -- the data layer is fully ready. The work is in (1) adding factory methods to `RunPlanCalculator` that generate multi-segment plans, (2) building UI for configuring structured runs, and (3) ensuring the playlist generator (Phase 7, already built by the time Phase 8 executes) can handle plans with multiple segments at different BPM targets.

The core domain logic is straightforward: a warm-up/cool-down run has 3 segments (warm-up at lower BPM, main at target BPM, cool-down at lower BPM), and an interval run has alternating work/rest segments bracketed by optional warm-up/cool-down. The key complexity is in the UI -- users need to configure segment durations and understand BPM transitions -- and in defining sensible defaults so users don't have to configure every detail.

No new dependencies are required. The existing stack (Riverpod, SharedPreferences, GoRouter, Material widgets) handles everything. The data model and persistence already serialize/deserialize multi-segment plans correctly (verified by existing tests for `warmUpCoolDown` and `interval` RunType serialization).

**Primary recommendation:** Add `createWarmUpCoolDownPlan` and `createIntervalPlan` factory methods to `RunPlanCalculator` (pure domain, TDD), then extend the `RunPlanScreen` with a run type selector and type-specific configuration UI. Use sensible defaults (5-min warm-up/cool-down, 1:1 work:rest ratio) to minimize required user input. Keep the existing single-plan persistence model -- the screen just creates a different plan type.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_riverpod | 2.6.1 (installed) | State management for run plan | Project standard; manual providers |
| shared_preferences | 2.5.4 (installed) | Persist structured run plan locally | Same JSON persistence as Phase 6 steady plans |
| dart:convert | (SDK) | JSON encode/decode | Built-in |
| Flutter Material widgets | (SDK) | SegmentedButton, Slider, ListView, Cards | Built-in |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_test | (SDK) | Unit tests for calculator factory methods | Testing segment generation |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Material SegmentedButton | CupertinoSegmentedControl | SegmentedButton is the Material 3 standard and matches the project's Material design |
| Static segment lists | ReorderableListView for drag-and-drop | Over-engineering for v1; warm-up/cool-down is always 3 segments, intervals follow a fixed pattern |
| Slider for durations | Number input fields | Sliders are more tactile for duration selection; prevents invalid input |
| Hardcoded BPM ramps | User-configurable per-segment BPM | Users should not need to manually set BPM for each segment; derive from pace + offset |

**Installation:**
```bash
# No new dependencies needed -- everything already in pubspec.yaml
```

## Architecture Patterns

### Recommended Project Structure
```
lib/features/run_plan/
├── domain/
│   ├── run_plan.dart              # RunPlan, RunSegment, RunType (EXISTING - no changes needed)
│   └── run_plan_calculator.dart   # Add createWarmUpCoolDownPlan, createIntervalPlan (EXTEND)
├── data/
│   └── run_plan_preferences.dart  # EXISTING - no changes needed (already handles multi-segment)
├── providers/
│   └── run_plan_providers.dart    # EXISTING - no changes needed (stores any RunPlan)
└── presentation/
    └── run_plan_screen.dart       # EXTEND with run type selector + type-specific forms
```

Key insight: The data layer (`run_plan.dart`, `run_plan_preferences.dart`, `run_plan_providers.dart`) requires **zero changes**. It already supports multiple segments, all three RunType values, and JSON serialization for any number of segments. Only the calculator (new factory methods) and UI (new configuration forms) need work.

### Pattern 1: Factory Methods for Structured Plans
**What:** Static factory methods on `RunPlanCalculator` that generate multi-segment plans from high-level parameters.
**When to use:** Always -- users specify high-level intent (e.g., "5K warm-up/cool-down run"), calculator generates the segments.
**Why:** Keeps segment generation logic pure, testable, and separate from UI. Users don't manually create segments.

```dart
// Source: Project pattern from RunPlanCalculator.createSteadyPlan
class RunPlanCalculator {
  // ... existing methods ...

  /// Creates a warm-up/cool-down plan with 3 segments.
  ///
  /// Warm-up: [warmUpSeconds] at [warmUpBpm]
  /// Main:    remainder of run at [targetBpm]
  /// Cool-down: [coolDownSeconds] at [coolDownBpm]
  ///
  /// Warm-up and cool-down BPMs are derived by applying a percentage
  /// reduction from the target BPM (e.g., 85% of target).
  static RunPlan createWarmUpCoolDownPlan({
    required double distanceKm,
    required double paceMinPerKm,
    required double targetBpm,
    int warmUpSeconds = 300,    // 5 minutes default
    int coolDownSeconds = 300,  // 5 minutes default
    double warmUpBpmFraction = 0.85,
    double coolDownBpmFraction = 0.85,
    String? name,
  }) {
    final totalDuration = durationSeconds(
      distanceKm: distanceKm,
      paceMinPerKm: paceMinPerKm,
    );
    final mainDuration = totalDuration - warmUpSeconds - coolDownSeconds;
    // Clamp: main segment must be at least 60 seconds
    final clampedMain = mainDuration < 60 ? 60 : mainDuration;
    final warmUpBpm = (targetBpm * warmUpBpmFraction).roundToDouble();
    final coolDownBpm = (targetBpm * coolDownBpmFraction).roundToDouble();

    return RunPlan(
      type: RunType.warmUpCoolDown,
      distanceKm: distanceKm,
      paceMinPerKm: paceMinPerKm,
      segments: [
        RunSegment(
          durationSeconds: warmUpSeconds,
          targetBpm: warmUpBpm,
          label: 'Warm-up',
        ),
        RunSegment(
          durationSeconds: clampedMain,
          targetBpm: targetBpm,
          label: 'Main',
        ),
        RunSegment(
          durationSeconds: coolDownSeconds,
          targetBpm: coolDownBpm,
          label: 'Cool-down',
        ),
      ],
      name: name,
      createdAt: DateTime.now(),
    );
  }

  /// Creates an interval training plan with alternating work/rest segments.
  ///
  /// Structure: [warm-up] + N x [work + rest] + [cool-down]
  /// Work segments use [workBpm], rest segments use [restBpm].
  static RunPlan createIntervalPlan({
    required double distanceKm,
    required double paceMinPerKm,
    required double targetBpm,
    required int intervalCount,
    required int workSeconds,
    required int restSeconds,
    int warmUpSeconds = 300,
    int coolDownSeconds = 300,
    double restBpmFraction = 0.80,
    double warmUpBpmFraction = 0.85,
    double coolDownBpmFraction = 0.85,
    String? name,
  }) {
    final warmUpBpm = (targetBpm * warmUpBpmFraction).roundToDouble();
    final coolDownBpm = (targetBpm * coolDownBpmFraction).roundToDouble();
    final restBpm = (targetBpm * restBpmFraction).roundToDouble();

    final segments = <RunSegment>[
      RunSegment(
        durationSeconds: warmUpSeconds,
        targetBpm: warmUpBpm,
        label: 'Warm-up',
      ),
    ];

    for (var i = 0; i < intervalCount; i++) {
      segments.add(RunSegment(
        durationSeconds: workSeconds,
        targetBpm: targetBpm,
        label: 'Work ${i + 1}',
      ));
      if (i < intervalCount - 1 || coolDownSeconds > 0) {
        segments.add(RunSegment(
          durationSeconds: restSeconds,
          targetBpm: restBpm,
          label: 'Rest ${i + 1}',
        ));
      }
    }

    segments.add(RunSegment(
      durationSeconds: coolDownSeconds,
      targetBpm: coolDownBpm,
      label: 'Cool-down',
    ));

    return RunPlan(
      type: RunType.interval,
      distanceKm: distanceKm,
      paceMinPerKm: paceMinPerKm,
      segments: segments,
      name: name,
      createdAt: DateTime.now(),
    );
  }
}
```

### Pattern 2: Run Type Selector in UI
**What:** A `SegmentedButton` at the top of the run plan screen that switches between Steady, Warm-up/Cool-down, and Interval run types.
**When to use:** At the top of the RunPlanScreen, before distance/pace selection.
**Why:** Clean Material 3 pattern for mutually exclusive selection. Each type shows different configuration options below.

```dart
// Source: Flutter Material 3 SegmentedButton API
SegmentedButton<RunType>(
  segments: const [
    ButtonSegment(value: RunType.steady, label: Text('Steady')),
    ButtonSegment(value: RunType.warmUpCoolDown, label: Text('Warm-up')),
    ButtonSegment(value: RunType.interval, label: Text('Intervals')),
  ],
  selected: {_selectedRunType},
  onSelectionChanged: (Set<RunType> selection) {
    setState(() => _selectedRunType = selection.first);
  },
)
```

### Pattern 3: Segment Summary Visualization
**What:** A visual summary of the generated segments showing the BPM timeline for the run.
**When to use:** In the run summary card, replacing the single-BPM display for structured runs.
**Why:** Users need to understand the BPM structure of their run before saving.

```dart
// Visual segment timeline using colored bars
Widget _buildSegmentTimeline(RunPlan plan, ThemeData theme) {
  final totalSeconds = plan.totalDurationSeconds;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Proportional colored bar
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Row(
          children: plan.segments.map((segment) {
            final fraction = segment.durationSeconds / totalSeconds;
            return Expanded(
              flex: (fraction * 1000).round(),
              child: Container(
                height: 24,
                color: _colorForSegment(segment),
                child: Center(
                  child: Text(
                    '${segment.targetBpm.round()}',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 8),
      // Segment list details
      ...plan.segments.map((s) => _SummaryRow(
        label: s.label ?? 'Segment',
        value: '${formatDuration(s.durationSeconds)} @ ${s.targetBpm.round()} bpm',
      )),
    ],
  );
}
```

### Pattern 4: BPM Derivation for Structured Segments
**What:** Derive segment BPMs as fractions of the target cadence rather than asking users to specify BPM per segment.
**When to use:** When creating warm-up/cool-down and interval plans.
**Why:** Users think in terms of "easy warm-up" and "hard intervals", not specific BPM numbers. Apply percentage offsets from the target cadence.

Typical BPM relationships:
- **Target BPM** (main/work): derived from pace + stride state (same as steady run)
- **Warm-up BPM**: ~85% of target BPM (represents easy jogging pace)
- **Cool-down BPM**: ~85% of target BPM (same as warm-up)
- **Rest interval BPM**: ~80% of target BPM (slow recovery jog)

These percentages come from running science: warm-up/cool-down pace is typically 60-90 seconds slower per km than race pace, which translates to roughly 80-90% of target cadence.

### Anti-Patterns to Avoid
- **Asking users to specify BPM per segment:** Users don't know what BPM their warm-up should be. Derive it from their target pace. Expose advanced overrides only if needed later.
- **Making segment durations distance-based:** For Phase 8, use time-based segments. "5-minute warm-up" is more intuitive than "0.8km warm-up". The total distance/pace determine overall run duration, and segments divide that time.
- **Restructuring the data model:** The existing `RunPlan`/`RunSegment` model is already designed for this. Do not create new model classes or change the existing ones.
- **Building a free-form segment editor:** Users should not drag-and-drop individual segments for v1. Use structured templates (warm-up/cool-down = 3 fixed segments, intervals = warm-up + N*(work+rest) + cool-down). Advanced customization is a v2 feature.
- **Splitting the screen into multiple routes:** One screen handles all run types. The type selector at the top switches between configuration panels below. No multi-step wizard needed.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| BPM calculation per segment | Per-segment pace-to-BPM conversion | Percentage of target BPM | Warm-up/cool-down/rest BPMs are fractions of the target cadence, not separate pace calculations |
| Segment duration validation | Complex time-budget validator | Simple arithmetic: totalDuration - warmUp - coolDown = main | Three subtractions with a minimum clamp |
| Run type selection widget | Custom toggle/tab system | Material `SegmentedButton` | Built-in, accessible, Material 3 standard |
| Interval repeat configuration | Complex drag-drop builder | Simple count + work duration + rest duration inputs | Three number inputs with sliders, not a visual editor |
| Multi-segment JSON persistence | New persistence layer | Existing `RunPlanPreferences` | Already handles any RunPlan with any number of segments |

**Key insight:** The data layer is 100% ready. This phase is purely about calculator factory methods (pure domain) and UI (form configuration). No infrastructure work needed.

## Common Pitfalls

### Pitfall 1: Main Segment Duration Goes Negative
**What goes wrong:** User configures a short run (e.g., 2km at 6:00/km = 12 min) with a 5-min warm-up and 5-min cool-down, leaving only 2 minutes for the main segment. Or worse, warm-up + cool-down exceed total duration.
**Why it happens:** Warm-up/cool-down defaults are too long relative to short runs.
**How to avoid:** Clamp main segment duration to a minimum (e.g., 60 seconds). Alternatively, scale warm-up/cool-down proportionally when total duration is short. Validate before creating the plan. Show a warning in the UI if warm-up + cool-down consume more than 50% of total run time.
**Warning signs:** `durationSeconds` of any segment is 0 or negative.

### Pitfall 2: Interval Count Creates Unreasonable Plan
**What goes wrong:** User requests 20 x 60s work / 60s rest intervals with 5-min warm-up and 5-min cool-down = 50 minutes total, but their run distance only allows 30 minutes.
**Why it happens:** Interval configuration is independent of distance/pace.
**How to avoid:** Two approaches: (a) Make interval count derived from available time after warm-up/cool-down (`intervalsAvailable = (totalTime - warmUp - coolDown) / (work + rest)`), or (b) Show total time from intervals alongside total time from distance/pace and warn on mismatch. Approach (a) is more user-friendly.
**Warning signs:** Total segment durations don't match the expected run duration from distance * pace.

### Pitfall 3: BPM Jumps Too Large Between Segments
**What goes wrong:** Playlist transitions between segments are jarring -- e.g., jumping from 140 BPM warm-up songs to 180 BPM work songs.
**Why it happens:** Warm-up BPM fraction is too low relative to target.
**How to avoid:** Keep warm-up/cool-down BPM within 15-20% of target (85% fraction is reasonable). For intervals, rest BPM should be 75-85% of work BPM. These ranges ensure the playlist generator can find songs that bridge the transition naturally.
**Warning signs:** More than 30 BPM difference between adjacent segments.

### Pitfall 4: Not Updating Summary Card for Multi-Segment Plans
**What goes wrong:** Summary card still shows a single "Target BPM" value even though the plan has multiple segments at different BPMs.
**Why it happens:** Phase 6 summary card was built for single-segment steady runs.
**How to avoid:** For structured runs, replace the single BPM row with a segment timeline or per-segment BPM list. Show total duration and per-segment breakdown.
**Warning signs:** Summary card displays `plan.segments.first.targetBpm` for a multi-segment plan.

### Pitfall 5: Interval Plans Don't Include Rest After Last Work Segment
**What goes wrong:** The pattern `work-rest-work-rest-work` has no rest after the last work segment before cool-down. The cool-down IS the recovery, but the BPM jump from work to cool-down might be large.
**Why it happens:** Off-by-one in loop generating work/rest pairs.
**How to avoid:** Standard interval structure is warm-up + N * (work + rest) + cool-down. The last rest segment transitions into the cool-down. If rest and cool-down BPMs are similar, the last rest can be omitted. Be explicit in the factory method about whether the last rest is included.
**Warning signs:** N work segments but N-1 rest segments without intentional design choice.

### Pitfall 6: Distance vs Time Conflict
**What goes wrong:** User enters 5km at 6:00/km (= 30 min total), then configures 8 intervals of 3-min work / 2-min rest plus 5-min warm-up/cool-down = 50 minutes. The distance/time don't agree.
**Why it happens:** For structured runs, the actual run time is determined by the segment structure, not by distance * pace.
**How to avoid:** For structured runs, consider making distance informational rather than the source of truth for duration. The segment configuration (warm-up + intervals + cool-down) defines the actual run duration. Alternatively, auto-calculate the number of intervals from available time. Display the actual total duration from segments, which may differ from distance * pace.
**Warning signs:** `plan.totalDurationSeconds` differs significantly from `durationSeconds(distanceKm, paceMinPerKm)`.

## Code Examples

### Warm-Up/Cool-Down Plan Test Cases
```dart
// Source: Domain testing pattern from run_plan_calculator_test.dart
group('RunPlanCalculator.createWarmUpCoolDownPlan', () {
  test('creates plan with 3 segments', () {
    final plan = RunPlanCalculator.createWarmUpCoolDownPlan(
      distanceKm: 5.0,
      paceMinPerKm: 6.0,
      targetBpm: 170.0,
    );
    expect(plan.segments.length, equals(3));
    expect(plan.type, equals(RunType.warmUpCoolDown));
  });

  test('warm-up segment has correct defaults', () {
    final plan = RunPlanCalculator.createWarmUpCoolDownPlan(
      distanceKm: 5.0,
      paceMinPerKm: 6.0,
      targetBpm: 170.0,
    );
    expect(plan.segments[0].label, equals('Warm-up'));
    expect(plan.segments[0].durationSeconds, equals(300)); // 5 min default
    expect(plan.segments[0].targetBpm, equals(145.0)); // 170 * 0.85 rounded
  });

  test('main segment fills remaining duration', () {
    final plan = RunPlanCalculator.createWarmUpCoolDownPlan(
      distanceKm: 5.0,
      paceMinPerKm: 6.0,
      targetBpm: 170.0,
      warmUpSeconds: 300,
      coolDownSeconds: 300,
    );
    // Total = 1800s, main = 1800 - 300 - 300 = 1200s
    expect(plan.segments[1].durationSeconds, equals(1200));
    expect(plan.segments[1].targetBpm, equals(170.0));
  });

  test('main segment clamped to minimum 60s for short runs', () {
    final plan = RunPlanCalculator.createWarmUpCoolDownPlan(
      distanceKm: 1.0,
      paceMinPerKm: 5.0,
      targetBpm: 170.0,
      warmUpSeconds: 180,
      coolDownSeconds: 180,
    );
    // Total = 300s, main = 300 - 180 - 180 = -60s -> clamped to 60s
    expect(plan.segments[1].durationSeconds, greaterThanOrEqualTo(60));
  });

  test('totalDurationSeconds sums all segments', () {
    final plan = RunPlanCalculator.createWarmUpCoolDownPlan(
      distanceKm: 5.0,
      paceMinPerKm: 6.0,
      targetBpm: 170.0,
    );
    expect(plan.totalDurationSeconds,
        equals(plan.segments.fold(0, (s, seg) => s + seg.durationSeconds)));
  });
});
```

### Interval Plan Test Cases
```dart
group('RunPlanCalculator.createIntervalPlan', () {
  test('creates plan with warm-up, intervals, and cool-down', () {
    final plan = RunPlanCalculator.createIntervalPlan(
      distanceKm: 5.0,
      paceMinPerKm: 6.0,
      targetBpm: 170.0,
      intervalCount: 4,
      workSeconds: 120,
      restSeconds: 60,
    );
    expect(plan.type, equals(RunType.interval));
    // warm-up + 4*work + 4*rest + cool-down = 1 + 4 + 4 + 1 = 10 segments
    // (or 1 + 4*work + 3*rest + 1 = 9 if last rest omitted before cool-down)
  });

  test('work segments have target BPM', () {
    final plan = RunPlanCalculator.createIntervalPlan(
      distanceKm: 5.0,
      paceMinPerKm: 6.0,
      targetBpm: 170.0,
      intervalCount: 3,
      workSeconds: 90,
      restSeconds: 90,
    );
    final workSegments = plan.segments.where(
      (s) => s.label?.startsWith('Work') == true,
    );
    for (final s in workSegments) {
      expect(s.targetBpm, equals(170.0));
    }
  });

  test('rest segments have reduced BPM', () {
    final plan = RunPlanCalculator.createIntervalPlan(
      distanceKm: 5.0,
      paceMinPerKm: 6.0,
      targetBpm: 170.0,
      intervalCount: 3,
      workSeconds: 90,
      restSeconds: 90,
    );
    final restSegments = plan.segments.where(
      (s) => s.label?.startsWith('Rest') == true,
    );
    for (final s in restSegments) {
      expect(s.targetBpm, lessThan(170.0));
    }
  });

  test('JSON round-trip preserves interval plan', () {
    final original = RunPlanCalculator.createIntervalPlan(
      distanceKm: 5.0,
      paceMinPerKm: 6.0,
      targetBpm: 170.0,
      intervalCount: 4,
      workSeconds: 120,
      restSeconds: 60,
    );
    final json = original.toJson();
    final restored = RunPlan.fromJson(json);
    expect(restored.type, equals(RunType.interval));
    expect(restored.segments.length, equals(original.segments.length));
    for (var i = 0; i < original.segments.length; i++) {
      expect(restored.segments[i].targetBpm,
          equals(original.segments[i].targetBpm));
      expect(restored.segments[i].durationSeconds,
          equals(original.segments[i].durationSeconds));
      expect(restored.segments[i].label, equals(original.segments[i].label));
    }
  });
});
```

### Run Type Selector UI
```dart
// Source: Flutter Material SegmentedButton + project pattern
enum RunType { steady, warmUpCoolDown, interval }

// In _RunPlanScreenState:
RunType _selectedRunType = RunType.steady;

// In build():
SegmentedButton<RunType>(
  segments: const [
    ButtonSegment(
      value: RunType.steady,
      label: Text('Steady'),
      icon: Icon(Icons.trending_flat),
    ),
    ButtonSegment(
      value: RunType.warmUpCoolDown,
      label: Text('Warm-up'),
      icon: Icon(Icons.show_chart),
    ),
    ButtonSegment(
      value: RunType.interval,
      label: Text('Intervals'),
      icon: Icon(Icons.stacked_bar_chart),
    ),
  ],
  selected: {_selectedRunType},
  onSelectionChanged: (Set<RunType> selection) {
    setState(() => _selectedRunType = selection.first);
  },
)
```

### Warm-Up/Cool-Down Configuration Form
```dart
// Duration sliders for warm-up and cool-down
Widget _buildWarmUpCoolDownConfig() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Warm-up Duration', style: theme.textTheme.titleSmall),
      Slider(
        value: _warmUpMinutes.toDouble(),
        min: 1,
        max: 15,
        divisions: 14,
        label: '$_warmUpMinutes min',
        onChanged: (v) => setState(() => _warmUpMinutes = v.round()),
      ),
      Text('Cool-down Duration', style: theme.textTheme.titleSmall),
      Slider(
        value: _coolDownMinutes.toDouble(),
        min: 1,
        max: 15,
        divisions: 14,
        label: '$_coolDownMinutes min',
        onChanged: (v) => setState(() => _coolDownMinutes = v.round()),
      ),
    ],
  );
}
```

### Interval Configuration Form
```dart
// Interval count, work duration, rest duration
Widget _buildIntervalConfig() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Number of Intervals', style: theme.textTheme.titleSmall),
      Slider(
        value: _intervalCount.toDouble(),
        min: 2,
        max: 20,
        divisions: 18,
        label: '$_intervalCount',
        onChanged: (v) => setState(() => _intervalCount = v.round()),
      ),
      Text('Work Duration', style: theme.textTheme.titleSmall),
      Slider(
        value: _workSeconds.toDouble(),
        min: 30,
        max: 600,
        divisions: 19,  // 30-second increments
        label: formatDuration(_workSeconds),
        onChanged: (v) => setState(() => _workSeconds = v.round()),
      ),
      Text('Rest Duration', style: theme.textTheme.titleSmall),
      Slider(
        value: _restSeconds.toDouble(),
        min: 15,
        max: 300,
        divisions: 19,  // 15-second increments
        label: formatDuration(_restSeconds),
        onChanged: (v) => setState(() => _restSeconds = v.round()),
      ),
    ],
  );
}
```

## Data Flow

### How Phase 8 Extends the Pipeline

```
Phase 5 (Stride)          Phase 8 (Structured Plans)     Phase 7 (Playlist Gen)
                                                          (already built)
strideNotifierProvider --> RunPlanCalculator            -> Playlist Generator
  .heightCm                .createSteadyPlan()           reads plan.segments
  .calibratedCadence       .createWarmUpCoolDownPlan()   iterates each segment:
                           .createIntervalPlan()           {durationSeconds, targetBpm}
                                |                        matches songs by BPM proximity
                                v                        per segment
                           RunPlanNotifier.setPlan()
                                |
                                v
                           RunPlanPreferences.save()
                           (unchanged -- handles any RunPlan)
```

### Contract with Phase 7 (Playlist Generator)

Phase 7 consumes `RunPlan.segments` as a list of `{durationSeconds, targetBpm}` tuples. The playlist generator already iterates segments and fills each segment's duration with BPM-matched songs. Phase 8 just provides plans with more segments at different BPMs. **No changes to Phase 7 should be needed** as long as:
1. Each segment has valid `durationSeconds > 0`
2. Each segment has valid `targetBpm` in a realistic range (120-200)
3. `plan.type` is set correctly (for display purposes)

## Domain Knowledge: Structured Run Types

### Warm-Up/Cool-Down Run (RUN-02)

A warm-up/cool-down run is the most common structured run. Structure:

| Segment | Duration | BPM Target | Purpose |
|---------|----------|------------|---------|
| Warm-up | 5-10 min | 80-90% of target | Gradually increase heart rate |
| Main    | Remainder | Target cadence | Steady running at planned pace |
| Cool-down | 5-10 min | 80-90% of target | Gradually decrease heart rate |

**Sensible defaults:**
- Warm-up: 5 minutes (300 seconds)
- Cool-down: 5 minutes (300 seconds)
- BPM reduction: 85% of target BPM for both warm-up and cool-down

**BPM transition:** Warm-up songs at ~85% target BPM (e.g., if target is 170, warm-up songs at ~145 BPM). The playlist generator handles the transition -- it selects songs matching each segment's target BPM independently.

### Interval Training Run (RUN-03)

An interval training run alternates between high-intensity work and low-intensity rest. Structure:

| Segment | Duration | BPM Target | Purpose |
|---------|----------|------------|---------|
| Warm-up | 5 min | 85% of target | Prepare body |
| Work 1  | 1-5 min | Target cadence | High intensity |
| Rest 1  | 0.5-3 min | 75-85% of target | Recovery |
| Work 2  | 1-5 min | Target cadence | High intensity |
| Rest 2  | 0.5-3 min | 75-85% of target | Recovery |
| ... | ... | ... | ... |
| Cool-down | 5 min | 85% of target | Recovery |

**Sensible defaults:**
- Intervals: 4 repetitions
- Work: 2 minutes (120 seconds)
- Rest: 1 minute (60 seconds) -- 2:1 work:rest ratio
- Warm-up: 5 minutes
- Cool-down: 5 minutes
- Rest BPM: 80% of target BPM

**Common interval patterns:**
| Name | Work | Rest | Ratio |
|------|------|------|-------|
| Speed work | 60-90s | 60-90s | 1:1 |
| VO2 max | 3-5 min | 3-5 min | 1:1 |
| Tempo intervals | 5-10 min | 1-2 min | 5:1 |
| Short sprints | 30s | 60-90s | 1:2-3 |

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| One BPM for entire run | Per-segment BPM targets | Standard in running apps | Enables warm-up/cool-down and interval playlists |
| Manual BPM per segment | Derived BPM from pace + percentages | Running science standard | Users don't need to know BPM numbers |
| Free-form segment editor | Template-based structured runs | UX best practice | Fewer inputs, less confusion, covers 90% of use cases |

## Open Questions

1. **Should distance or segment structure be the source of truth for duration?**
   - What we know: For steady runs, total duration = distance * pace. For structured runs, total duration = sum of segment durations, which may not match distance * pace.
   - What's unclear: If a user enters 5km at 6:00/km (30 min) but configures 5-min warm-up + 8 x (2 min work + 1 min rest) + 5-min cool-down = 34 minutes, which wins?
   - Recommendation: For warm-up/cool-down runs, derive segment durations from distance * pace (main segment fills remaining time). For interval runs, let the segment structure determine total duration and display the actual total prominently. Show a note like "Estimated distance: X km" rather than using the user-entered distance as a hard constraint.

2. **How to handle the interaction between run type change and existing distance/pace?**
   - What we know: User has already selected distance and pace (shared across all run types). When switching from Steady to Intervals, the parameters carry over.
   - What's unclear: Whether interval-specific parameters (count, work, rest) should be preserved when switching back to Steady and back to Intervals.
   - Recommendation: Preserve all local state per run type. When switching types, show/hide the relevant configuration section but don't reset values.

3. **Whether to include a visual BPM timeline or segment list**
   - What we know: A visual bar showing proportional segment durations with BPM annotations would help users understand their plan structure.
   - What's unclear: Whether this adds enough value for the implementation cost.
   - Recommendation: Include it -- a simple proportional `Row` of colored `Container`s is ~20 lines of code and significantly improves comprehension of the plan structure.

## Sources

### Primary (HIGH confidence)
- Existing codebase: `run_plan.dart`, `run_plan_calculator.dart`, `run_plan_calculator_test.dart`, `run_plan_preferences.dart`, `run_plan_providers.dart`, `run_plan_screen.dart` -- verified by reading actual source files
- Phase 6 research (`06-RESEARCH.md`) -- established the segment-based architecture that Phase 8 extends
- Existing serialization tests -- confirmed `warmUpCoolDown` and `interval` RunType values serialize/deserialize correctly
- Flutter `SegmentedButton` API -- Material 3 widget for mutually exclusive selection (built into Flutter SDK)

### Secondary (MEDIUM confidence)
- [ASICS Runkeeper - Warm-Up and Cool-Down Guide](https://runkeeper.com/cms/training/the-best-warm-ups-and-cool-downs-for-your-runs/) -- 5-10 minute warm-up/cool-down standard
- [Mayo Clinic - Warm Up and Cool Down](https://www.mayoclinic.org/healthy-lifestyle/fitness/in-depth/exercise/art-20045517) -- 5-10 minutes is standard
- [Runner's World - Interval Rest](https://www.runnersworld.com/advanced/a20803666/how-much-rest-should-you-take-between-intervals/) -- Work:rest ratios from 1:1 to 2:1 for typical intervals
- [CMS Fitness - Interval Ratios](https://www.cmsfitnesscourses.co.uk/blog/interval-training-what-ratio-is-best/) -- 1:1 and 2:1 as standard ratios
- [Runners Need - BPM Guide](https://www.runnersneed.com/expert-advice/training/running-and-music-finding-your-bpm.html) -- 100-120 BPM for warm-up, 140-180 BPM for main workout
- [RunReps - High Tempo Playlists](https://runreps.com/articles/running-with-music-above-160-bpm/) -- BPM above 160 for speed/intervals
- [Flutter ReorderableListView docs](https://api.flutter.dev/flutter/material/ReorderableListView-class.html) -- Reviewed but deemed unnecessary for v1 (template approach preferred)

### Tertiary (LOW confidence)
- Warm-up BPM as 85% of target -- derived from typical warm-up pace being 60-90s/km slower, which correlates to ~85% cadence reduction. Not from a specific authoritative source.
- Rest BPM as 80% of target -- similar derivation from recovery jog pace. Reasonable but approximate.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- No new dependencies; reuses existing installed libraries and patterns
- Architecture: HIGH -- Data model already built for this; factory methods follow established pattern from createSteadyPlan
- Domain logic: HIGH -- Segment generation is straightforward arithmetic; BPM percentages are well-grounded in running science
- UI patterns: HIGH -- SegmentedButton is standard Material 3; Slider for durations is established Flutter pattern
- BPM percentages: MEDIUM -- 85%/80% fractions are reasonable estimates from running science but not exact science; users may want to adjust
- Pitfalls: HIGH -- Most pitfalls are about edge cases in arithmetic (negative durations, mismatched times) which are straightforward to test for

**Research date:** 2026-02-05
**Valid until:** 2026-03-07 (30 days -- stable domain, no fast-moving dependencies)
