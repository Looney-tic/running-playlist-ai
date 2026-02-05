# Phase 6: Steady Run Planning - Research

**Researched:** 2026-02-05
**Domain:** Run plan data modeling, cadence-to-BPM conversion, duration calculation, local persistence
**Confidence:** HIGH

## Summary

Phase 6 implements the "run plan" concept -- the bridge between the stride/cadence calculator (Phase 5) and playlist generation (Phase 7). A steady run is the simplest plan type: the user specifies a distance and pace, the app calculates the duration and derives a target BPM from their cadence, and this plan is saved for later use by the playlist generator.

The core computation is trivial: `duration_minutes = distance_km * pace_min_per_km`. The target BPM equals the user's cadence (from Phase 5's strideNotifierProvider or recalculated via StrideCalculator). The data model must be designed to be extensible for Phase 8 (Structured Run Types: warm-up/cool-down, intervals) which introduces multi-segment plans. A steady run is simply a plan with a single segment.

The existing codebase provides all the building blocks: StrideCalculator for cadence computation, SharedPreferences for local persistence, Riverpod StateNotifier for state management, GoRouter for routing. No new dependencies are needed.

**Primary recommendation:** Model a `RunPlan` as a list of `RunSegment`s (steady run = one segment). Use a `RunPlanNotifier` (StateNotifier) for state, persist via SharedPreferences (JSON-serialized), build a single-screen UI for creating steady runs with distance/pace input and computed duration/BPM display. Design the data model segment-based from day one so Phase 8 can add segment types without restructuring.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_riverpod | 2.6.1 (installed) | State management for run plan | Project standard; manual providers per prior decision |
| shared_preferences | 2.5.4 (installed) | Persist run plan locally | Same pattern used by Phase 5 for stride preferences |
| dart:convert | (SDK) | JSON encode/decode for plan serialization | Built-in, no dependency |
| Flutter Material widgets | (SDK) | Form inputs, display widgets | Built-in |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_test | (SDK) | Unit tests for domain logic | Testing run plan calculations and serialization |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SharedPreferences (JSON) | Supabase table | Supabase requires auth (blocked); SharedPreferences sufficient for single-device MVP. Can migrate later. |
| SharedPreferences (JSON) | Hive / Isar | Adds dependency for a simple data structure. JSON in SharedPreferences is sufficient for a single active run plan. |
| Manual JSON serialization | freezed + json_serializable | Code-gen is partially broken with Dart 3.10 (per STATE.md). Manual toJson/fromJson for 2-3 small classes is trivial. |
| Single active plan | List of saved plans | Phase 6 only needs one plan at a time. Phase 9 (Playlist History) may introduce plan history. Keep it simple for now. |

**Installation:**
```bash
# No new dependencies needed -- everything already in pubspec.yaml
```

## Architecture Patterns

### Recommended Project Structure
```
lib/features/run_plan/
├── domain/
│   ├── run_plan.dart          # RunPlan, RunSegment, RunType data classes
│   └── run_plan_calculator.dart  # Duration + BPM calculation (pure Dart)
├── data/
│   └── run_plan_preferences.dart  # JSON persistence via SharedPreferences
├── providers/
│   └── run_plan_providers.dart    # RunPlanNotifier + provider
└── presentation/
    └── run_plan_screen.dart       # UI: distance/pace input, duration/BPM display
```

This follows the exact structure used by `features/stride/` (domain/data/providers/presentation layers).

### Pattern 1: Segment-Based Run Plan Model
**What:** Model all run plans as a list of segments, even when a steady run has only one segment. Each segment has a duration and target BPM.
**When to use:** Always -- this is the data model foundation.
**Why:** Phase 8 adds multi-segment plans (warm-up/cool-down, intervals). Designing segment-based from day one means Phase 8 extends the model rather than restructuring it. The ARCHITECTURE.md research already specifies this: "Each segment produces a `{duration_seconds, target_bpm, bpm_tolerance}` tuple."

```dart
// lib/features/run_plan/domain/run_plan.dart

/// The type of run plan.
enum RunType { steady, warmUpCoolDown, interval }

/// A single segment of a run plan with a duration and target BPM.
///
/// Steady runs have exactly one segment.
/// Structured runs (Phase 8) will have multiple segments.
class RunSegment {
  const RunSegment({
    required this.durationSeconds,
    required this.targetBpm,
    this.label,
  });

  /// Duration of this segment in seconds.
  final int durationSeconds;

  /// Target BPM for playlist matching in this segment.
  final double targetBpm;

  /// Optional label (e.g., "warm-up", "work", "rest").
  final String? label;

  Map<String, dynamic> toJson() => {
    'durationSeconds': durationSeconds,
    'targetBpm': targetBpm,
    if (label != null) 'label': label,
  };

  factory RunSegment.fromJson(Map<String, dynamic> json) => RunSegment(
    durationSeconds: json['durationSeconds'] as int,
    targetBpm: (json['targetBpm'] as num).toDouble(),
    label: json['label'] as String?,
  );
}

/// A complete run plan with metadata and one or more segments.
///
/// For a steady run: one segment covering the full duration.
/// For structured runs (Phase 8): multiple segments.
class RunPlan {
  const RunPlan({
    required this.type,
    required this.distanceKm,
    required this.paceMinPerKm,
    required this.segments,
    this.name,
    this.createdAt,
  });

  final RunType type;

  /// Total distance in kilometers.
  final double distanceKm;

  /// Pace in decimal minutes per km (e.g., 5.5 = 5:30/km).
  final double paceMinPerKm;

  /// Ordered list of segments making up this run.
  final List<RunSegment> segments;

  /// Optional user-given name for the plan.
  final String? name;

  /// When the plan was created.
  final DateTime? createdAt;

  /// Total run duration in seconds, summed from all segments.
  int get totalDurationSeconds =>
      segments.fold(0, (sum, s) => sum + s.durationSeconds);

  /// Total run duration in minutes.
  double get totalDurationMinutes => totalDurationSeconds / 60.0;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'distanceKm': distanceKm,
    'paceMinPerKm': paceMinPerKm,
    'segments': segments.map((s) => s.toJson()).toList(),
    if (name != null) 'name': name,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };

  factory RunPlan.fromJson(Map<String, dynamic> json) => RunPlan(
    type: RunType.values.byName(json['type'] as String),
    distanceKm: (json['distanceKm'] as num).toDouble(),
    paceMinPerKm: (json['paceMinPerKm'] as num).toDouble(),
    segments: (json['segments'] as List)
        .map((s) => RunSegment.fromJson(s as Map<String, dynamic>))
        .toList(),
    name: json['name'] as String?,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : null,
  );
}
```

### Pattern 2: Pure Computation in Domain Layer
**What:** Duration and BPM calculations as static methods, zero Flutter imports.
**When to use:** All run plan math.
**Why:** Matches Phase 5 pattern (StrideCalculator). Trivially unit-testable.

```dart
// lib/features/run_plan/domain/run_plan_calculator.dart

import 'package:running_playlist_ai/features/stride/domain/stride_calculator.dart';

/// Pure computation for run plan calculations.
///
/// No Flutter dependencies. All static methods.
class RunPlanCalculator {
  /// Calculates run duration in seconds from distance and pace.
  ///
  /// duration = distance_km * pace_min_per_km * 60
  static int durationSeconds({
    required double distanceKm,
    required double paceMinPerKm,
  }) {
    if (distanceKm <= 0 || paceMinPerKm <= 0) return 0;
    return (distanceKm * paceMinPerKm * 60).round();
  }

  /// Determines target BPM for a steady run.
  ///
  /// For a steady run, target BPM equals the runner's cadence (spm).
  /// Uses StrideCalculator from Phase 5 to compute cadence from pace + height.
  /// If calibratedCadence is provided, it takes priority.
  static double targetBpm({
    required double paceMinPerKm,
    double? heightCm,
    double? calibratedCadence,
  }) {
    if (calibratedCadence != null) return calibratedCadence;
    return StrideCalculator.calculateCadence(
      paceMinPerKm: paceMinPerKm,
      heightCm: heightCm,
    );
  }

  /// Creates a steady-run plan with a single segment.
  static RunPlan createSteadyPlan({
    required double distanceKm,
    required double paceMinPerKm,
    required double targetBpm,
    String? name,
  }) {
    final duration = durationSeconds(
      distanceKm: distanceKm,
      paceMinPerKm: paceMinPerKm,
    );

    return RunPlan(
      type: RunType.steady,
      distanceKm: distanceKm,
      paceMinPerKm: paceMinPerKm,
      name: name,
      createdAt: DateTime.now(),
      segments: [
        RunSegment(
          durationSeconds: duration,
          targetBpm: targetBpm,
        ),
      ],
    );
  }
}
```

### Pattern 3: Riverpod StateNotifier for Run Plan State
**What:** RunPlanNotifier managing the current run plan, following the same pattern as StrideNotifier.
**When to use:** Connecting domain logic to UI.
**Why:** Matches project convention (manual providers, StateNotifier, Riverpod 2.x).

```dart
// lib/features/run_plan/providers/run_plan_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/run_plan.dart';
import '../data/run_plan_preferences.dart';

class RunPlanNotifier extends StateNotifier<RunPlan?> {
  RunPlanNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    state = await RunPlanPreferences.load();
  }

  void setPlan(RunPlan plan) {
    state = plan;
    RunPlanPreferences.save(plan);
  }

  void clear() {
    state = null;
    RunPlanPreferences.clear();
  }
}

final runPlanNotifierProvider =
    StateNotifierProvider<RunPlanNotifier, RunPlan?>((ref) {
  return RunPlanNotifier();
});
```

### Pattern 4: SharedPreferences JSON Persistence
**What:** Serialize RunPlan as JSON string in SharedPreferences.
**When to use:** Saving/loading the current run plan.
**Why:** Matches Phase 5 pattern (StridePreferences). Simple, no new dependencies. SharedPreferences can store a single JSON string for the active plan.

```dart
// lib/features/run_plan/data/run_plan_preferences.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/run_plan.dart';

class RunPlanPreferences {
  static const _key = 'current_run_plan';

  static Future<RunPlan?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return null;
    return RunPlan.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
  }

  static Future<void> save(RunPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(plan.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
```

### Anti-Patterns to Avoid
- **Flat data model without segments:** Don't model a run plan as just `{distance, pace, duration, bpm}`. Use segments from the start. Phase 8 (intervals, warm-up/cool-down) will need segments, and restructuring the data model later means migration pain.
- **Recomputing cadence without consulting stride settings:** The run plan's target BPM should come from the user's current stride state (which includes calibration). Don't bypass the strideNotifierProvider and recalculate independently.
- **Coupling BPM calculation to the UI:** Keep `RunPlanCalculator` as pure Dart in `domain/`. The UI should call the calculator, not embed arithmetic in widgets.
- **Storing run plans in multiple SharedPreferences keys:** Serialize the entire RunPlan as a single JSON string. Don't split fields across multiple keys (that's what Phase 5 did for individual values, but a plan is a composite object).
- **Over-engineering for multiple saved plans:** Phase 6 needs one active plan. Don't build a full plan list/history system. Phase 9 (Playlist History) will address that.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON serialization | Code-gen (freezed/json_serializable) | Manual toJson/fromJson | Code-gen broken with Dart 3.10 per STATE.md. 2-3 small classes are trivial to serialize by hand |
| Duration formatting | Parsing/formatting library | Helper function (mm:ss from seconds) | Trivial arithmetic, ~3 lines |
| Distance validation | Complex validation framework | Simple range check (0.1-100 km) | Two comparisons |
| Pace input | New pace widget | Reuse StrideScreen's pace dropdown pattern | Same 3:00-10:00 range, same 15-second increments, proven UX |

**Key insight:** This phase has zero external dependencies to add. The value is in getting the data model right (segment-based, extensible for Phase 8) and wiring the cadence output from Phase 5 into a run plan that Phase 7 can consume.

## Common Pitfalls

### Pitfall 1: Cadence vs BPM Confusion
**What goes wrong:** Treating cadence (steps per minute) and BPM (beats per minute of music) as different numbers that need conversion.
**Why it happens:** The terms are from different domains (running vs music). Easy to think a conversion is needed.
**How to avoid:** For a steady run at a matched cadence, target BPM = cadence (spm). A song at 170 BPM matches a runner at 170 spm (one step per beat). The half/double-time matching (85 BPM matches 170 spm) is Phase 7's responsibility (BPM-03 requirement), not Phase 6's. Phase 6 just stores the target BPM = cadence.
**Warning signs:** Adding multiplication/division between cadence and BPM in the run plan domain.

### Pitfall 2: Not Reusing Stride State for BPM
**What goes wrong:** Run plan screen asks for pace and height separately, ignoring the user's existing stride configuration (including calibration).
**Why it happens:** Phase 6 creates its own pace/height inputs without consulting the stride provider.
**How to avoid:** Read from `strideNotifierProvider` to get the user's current cadence (which already accounts for pace, height, and calibration). The run plan screen should either use the current stride settings or allow the user to specify a different pace for this specific run -- but the BPM should always come from the stride calculation pipeline.
**Warning signs:** Duplicate pace/height input fields that don't sync with the stride screen.

### Pitfall 3: Duration Precision Errors
**What goes wrong:** Run duration shows as 29:59 instead of 30:00 for a 5km run at 6:00/km.
**Why it happens:** Floating-point multiplication: 5.0 * 6.0 * 60 = 1800.0 is fine, but 5.0 * 5.5 * 60 = 1650.0000...001 or similar.
**How to avoid:** Use `.round()` when converting to integer seconds. Display duration from the rounded integer, not from a floating-point intermediate.
**Warning signs:** Duration display showing unexpected seconds (e.g., 27:30 shows as 27:29).

### Pitfall 4: Empty State UX
**What goes wrong:** User navigates to run plan screen and sees an empty/broken state, or navigates to playlist generation without a plan.
**Why it happens:** No run plan has been created yet. UI doesn't handle null plan state.
**How to avoid:** The RunPlanNotifier starts with `null` state. The UI should show a "Create your run plan" form when no plan exists, and show the current plan summary with an "Edit" option when one exists. Downstream consumers (Phase 7) should check for plan existence before proceeding.
**Warning signs:** White screen or crash when no plan is saved.

### Pitfall 5: Pace Inconsistency Between Stride and Run Plan
**What goes wrong:** User sets 5:00/km pace on stride screen but 6:00/km on run plan screen, and the BPM doesn't match what they expect from the stride screen's cadence display.
**Why it happens:** Two separate pace inputs that don't sync.
**How to avoid:** The run plan screen should use its own pace for distance/duration calculation, but derive BPM by passing that pace through StrideCalculator (respecting the user's height and calibration). The pace on the run plan screen is "the pace for this specific run," which may differ from the default pace on the stride screen. This is correct behavior -- document it clearly.
**Warning signs:** User confusion about why stride screen and run plan show different cadence/BPM for different paces.

### Pitfall 6: Not Designing for Phase 8 Extensibility
**What goes wrong:** Run plan model is a flat structure `{distance, pace, duration, bpm}` with no segment concept. Phase 8 requires a complete data model rewrite.
**Why it happens:** Phase 6 only needs a single segment, so it seems simpler to skip the segment abstraction.
**How to avoid:** Use the segment-based model from the start. A steady run has `segments: [RunSegment(durationSeconds: X, targetBpm: Y)]`. Phase 8 adds more segments to the list. The cost of one wrapper class is trivial compared to a data model migration.
**Warning signs:** RunPlan class has a single `durationSeconds` and `targetBpm` field instead of a `segments` list.

## Code Examples

### Duration Calculation Tests
```dart
// test/features/run_plan/domain/run_plan_calculator_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/run_plan/domain/run_plan_calculator.dart';

void main() {
  group('RunPlanCalculator.durationSeconds', () {
    test('5 km at 6:00/km = 1800 seconds (30 minutes)', () {
      expect(
        RunPlanCalculator.durationSeconds(distanceKm: 5.0, paceMinPerKm: 6.0),
        equals(1800),
      );
    });

    test('10 km at 5:30/km = 3300 seconds (55 minutes)', () {
      expect(
        RunPlanCalculator.durationSeconds(distanceKm: 10.0, paceMinPerKm: 5.5),
        equals(3300),
      );
    });

    test('21.1 km at 5:00/km = 6330 seconds (half marathon)', () {
      expect(
        RunPlanCalculator.durationSeconds(distanceKm: 21.1, paceMinPerKm: 5.0),
        equals(6330),
      );
    });

    test('zero distance returns 0', () {
      expect(
        RunPlanCalculator.durationSeconds(distanceKm: 0.0, paceMinPerKm: 5.0),
        equals(0),
      );
    });

    test('zero pace returns 0', () {
      expect(
        RunPlanCalculator.durationSeconds(distanceKm: 5.0, paceMinPerKm: 0.0),
        equals(0),
      );
    });
  });
}
```

### Duration Formatting Helper
```dart
/// Formats total seconds as "H:MM:SS" or "MM:SS".
String formatDuration(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
```

### Run Plan Screen Distance Input Pattern
```dart
// Distance input using common preset buttons + custom input
// Presets: 5K, 10K, Half Marathon, Marathon, Custom
final _distancePresets = <String, double>{
  '5K': 5.0,
  '10K': 10.0,
  'Half': 21.1,
  'Marathon': 42.2,
};

// Wrap preset buttons for quick selection
Wrap(
  spacing: 8,
  children: _distancePresets.entries.map((entry) {
    final isSelected = (selectedDistance - entry.value).abs() < 0.01;
    return ChoiceChip(
      label: Text(entry.key),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) notifier.setDistance(entry.value);
      },
    );
  }).toList(),
)
```

### Integration: Reading Cadence from Phase 5
```dart
// In run plan screen or provider, read cadence from stride state
final strideState = ref.watch(strideNotifierProvider);
final targetBpm = strideState.cadence; // Already accounts for calibration

// Or recalculate for a different pace than the stride screen's default:
final targetBpm = RunPlanCalculator.targetBpm(
  paceMinPerKm: runPlanPace, // May differ from stride screen pace
  heightCm: strideState.heightCm,
  calibratedCadence: strideState.calibratedCadence,
);
```

### Run Plan Summary Display
```dart
// Show the run plan summary: distance, pace, duration, target BPM
Card(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Steady Run', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        _SummaryRow(label: 'Distance', value: '${plan.distanceKm} km'),
        _SummaryRow(label: 'Pace', value: '${formatPace(plan.paceMinPerKm)} /km'),
        _SummaryRow(
          label: 'Duration',
          value: formatDuration(plan.totalDurationSeconds),
        ),
        _SummaryRow(
          label: 'Target BPM',
          value: '${plan.segments.first.targetBpm.round()} bpm',
        ),
      ],
    ),
  ),
)
```

## Data Flow

### How Phase 6 Fits in the Pipeline

```
Phase 5 (Stride)          Phase 6 (Run Plan)         Phase 7 (Playlist Gen)

strideNotifierProvider ──> RunPlanNotifier ──────────> Playlist Generator
  .cadence (spm)            .state (RunPlan?)           reads RunPlan.segments
  .heightCm                   .segments[0]              [{durationSeconds, targetBpm}]
  .calibratedCadence          .targetBpm = cadence      matches songs by BPM proximity
                              .durationSeconds           fills duration with tracks

StrideCalculator ─────────> RunPlanCalculator
  .calculateCadence()         .targetBpm()
                              .durationSeconds()
                              .createSteadyPlan()
```

### Consumer Contract for Phase 7

Phase 7 (Playlist Generation) needs from a run plan:
1. **`segments`** - ordered list of `{durationSeconds, targetBpm}` tuples
2. **`totalDurationSeconds`** - to know total playlist length
3. **Existence check** - `runPlanNotifierProvider` returns `RunPlan?` (null = no plan yet)

This contract is the same whether the plan is steady (1 segment) or structured (N segments), which is why the segment model matters.

## Routing Considerations

### New Route
```dart
GoRoute(
  path: '/run-plan',
  builder: (context, state) => const RunPlanScreen(),
),
```

### Navigation from Home Screen
Add a "Plan Run" button on the home screen, similar to the existing "Stride Calculator" button. Consider whether the run plan screen should be the primary action (since it's closer to the core value proposition than the stride calculator).

### Public vs Auth-Guarded
Follow the same pattern as /stride: make it public while Spotify auth remains blocked. The run plan screen doesn't need Spotify access -- it's pure computation + local storage.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Flat run plan model | Segment-based plans | Standard in running apps (Strava, Garmin) | Supports steady, intervals, warm-up/cool-down with one model |
| BPM = cadence only | BPM matching with half/double time + tolerance window | Well-established | Expands song candidate pool; Phase 7 handles this, Phase 6 just stores target BPM = cadence |
| Server-side run plan storage | Local-first with optional sync | Trend since 2024 | Works offline, no auth dependency, syncs when ready |

## Open Questions

1. **Run plan pace vs stride screen pace**
   - What we know: The stride screen has a pace setting. The run plan also needs a pace input (for distance/duration calculation).
   - What's unclear: Should these be synced? Should changing pace on the run plan screen update the stride screen?
   - Recommendation: Keep them independent. The stride screen sets the user's "default" cadence profile (including calibration). The run plan screen allows specifying a pace for a specific run. BPM is derived from the run plan's pace + the user's height/calibration from stride settings. This allows a user to plan runs at different paces without changing their stride profile.

2. **Calibrated cadence and run plan BPM**
   - What we know: If the user has calibrated their cadence at one pace, that calibrated value overrides the formula for ALL paces on the stride screen.
   - What's unclear: When a user plans a run at a different pace than what they calibrated at, should the calibrated cadence still be used as the target BPM?
   - Recommendation: For Phase 6 (steady run), use `StrideCalculator.calculateCadence()` with the run plan's pace and the user's height, ignoring calibration. The calibration is pace-specific. If the user calibrated at 5:00/km but plans a run at 6:00/km, their cadence will be different. Alternatively, use calibrated cadence if the run plan pace matches the stride screen pace (within some tolerance). This needs a design decision from the planner.

3. **Distance input: presets vs free-form**
   - What we know: Common race distances (5K, 10K, half marathon, marathon) are standard presets.
   - What's unclear: Whether a free-form distance input is needed in addition to presets.
   - Recommendation: Offer both. Preset chips (5K, 10K, Half, Marathon) for quick selection, plus a text field for custom distances. Most users run standard distances, but training runs often have arbitrary distances.

## Sources

### Primary (HIGH confidence)
- Phase 5 codebase: `stride_calculator.dart`, `stride_providers.dart`, `stride_preferences.dart` -- verified by reading actual source code
- Phase 5 verification report: `05-VERIFICATION.md` -- documents the exact API surface Phase 6 consumes
- ARCHITECTURE.md research: Segment-based run plan model with `{durationSeconds, targetBpm}` tuples -- established in initial project research
- REQUIREMENTS.md: RUN-01 definition "Create steady-pace run (distance + pace -> single BPM target)" -- project requirements document
- ROADMAP.md: Phase 6 success criteria, Phase 7/8 dependency chain -- project roadmap

### Secondary (MEDIUM confidence)
- [BODi - Running BPM Guide](https://www.bodi.com/blog/find-running-bpm) -- BPM-to-cadence matching: target BPM equals cadence for 1:1 matching, half/double time expands candidates
- [GetSongBPM Running Tool](https://getsongbpm.com/running) -- Confirms BPM = cadence for running music matching
- Cadence-BPM relationship: Widely established that 1 beat = 1 step for cadence-matched running music

### Tertiary (LOW confidence)
- Multiple run types (steady, intervals, progressive) as standard in running apps -- based on general knowledge of Strava, Garmin, MapMyRun training plans

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- No new dependencies needed; reuses existing project libraries and patterns
- Architecture: HIGH -- Segment-based model prescribed by ARCHITECTURE.md; follows proven feature structure from Phase 5
- Domain logic: HIGH -- Duration = distance * pace is arithmetic; BPM = cadence is a direct relationship established in Phase 5 research
- Data model: HIGH -- Segment-based design with JSON persistence is straightforward
- Pitfalls: HIGH -- Most pitfalls are about data model extensibility and state management, which are well-understood
- UI patterns: MEDIUM -- Distance input UX (presets vs custom) is a design judgment; pace input reuses Phase 5 pattern

**Research date:** 2026-02-05
**Valid until:** 2026-03-07 (30 days -- stable domain, no fast-moving dependencies)
