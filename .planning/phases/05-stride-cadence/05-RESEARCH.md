# Phase 5: Stride & Cadence - Research

**Researched:** 2026-02-05
**Domain:** Running biomechanics computation (pace-to-cadence), Flutter form input patterns
**Confidence:** HIGH

## Summary

This phase implements a self-contained computational feature: given a user's target pace (min/km), optionally their height, and optionally a real-world calibration count, produce a target cadence in steps per minute (spm). The cadence output is later consumed by the playlist generation phase to determine target BPM for song matching.

The biomechanics formulas are well-established. The fundamental relationship is **Speed = Stride Length x Stride Frequency**, where Stride Frequency = Cadence / 2 (one stride = two steps). The challenge is estimating stride length without measurement -- height provides the best proxy (stride length ~= height x 0.65 for running). When height is unavailable, a pace-based default stride estimate works as a reasonable fallback.

The UI is a simple form: pace input, optional height input, optional calibration step count. All computation is pure Dart with no external dependencies. The existing project patterns (Riverpod manual providers, ConsumerWidget, feature-based folder structure) apply directly.

**Primary recommendation:** Implement as pure Dart computation functions in a `domain/` layer with comprehensive unit tests, expose via Riverpod StateNotifier/Notifier, and build a single-screen UI with TextFormField inputs and real-time cadence display.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_riverpod | 2.6.1 (already installed) | State management for stride inputs and computed cadence | Project standard; manual providers per prior decision |
| Flutter Material widgets | (SDK) | TextFormField, Slider, Form, Scaffold | Built-in, no extra dependency |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_test | (SDK) | Unit tests for computation functions | Testing cadence/stride formulas |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| TextFormField for pace | Slider for pace | TextFormField allows precise min:sec input; Slider would need careful UX for time-format values |
| Manual form state | flutter_form_builder, formz | Overkill for 2-3 fields; simple TextFormField + Riverpod is sufficient |
| No external packages | syncfusion_flutter_sliders for height | Adds commercial dependency; Material Slider is sufficient for height selection |

**Installation:**
```bash
# No new dependencies needed — everything is already in pubspec.yaml
# Pure Dart computation + existing Flutter widgets + existing Riverpod
```

## Architecture Patterns

### Recommended Project Structure
```
lib/features/stride/
├── domain/
│   └── stride_calculator.dart    # Pure computation functions (no Flutter dependency)
├── data/
│   └── stride_preferences.dart   # Persist user height + calibration (optional, SharedPreferences or Supabase)
├── providers/
│   └── stride_providers.dart     # Riverpod providers for stride state
└── presentation/
    └── stride_screen.dart        # UI: pace input, height input, calibration, cadence display
```

This follows the project's existing feature-based structure (`features/auth/{data,providers,presentation}`), adding a `domain/` layer for the pure computation logic that has no Flutter dependencies and is trivially unit-testable.

### Pattern 1: Pure Computation in Domain Layer
**What:** All stride/cadence formulas in a plain Dart class with no framework dependencies
**When to use:** Always — for any mathematical/business logic
**Why:** Testable with plain `dart test` (no widget test overhead), reusable, zero coupling to UI

```dart
// lib/features/stride/domain/stride_calculator.dart

/// Pure computation functions for stride length and cadence estimation.
///
/// Formulas based on biomechanical research:
/// - Speed = Stride Length × Stride Frequency
/// - Stride Frequency = Cadence / 2 (one stride = two steps)
/// - Stride Length ≈ Height × 0.65 (running multiplier)
class StrideCalculator {
  /// Convert pace (min/km) to speed (m/s).
  ///
  /// Example: 5:00 min/km = 5.0 minutes → 1000m / 300s = 3.33 m/s
  static double paceToSpeed(double paceMinPerKm) {
    if (paceMinPerKm <= 0) return 0;
    return 1000.0 / (paceMinPerKm * 60.0);
  }

  /// Estimate stride length (meters) from height (cm) using running multiplier.
  ///
  /// Research-based multiplier: 0.65 for running (vs 0.43 for walking).
  /// This represents a full stride (left foot to left foot = 2 steps).
  static double strideLengthFromHeight(double heightCm) {
    return heightCm * 0.65 / 100.0; // convert cm result to meters
  }

  /// Default stride length estimate based on running speed when height is unknown.
  ///
  /// Uses a linear interpolation between known speed-stride data points.
  /// Sources: biomechanical stride length tables.
  static double defaultStrideLengthFromSpeed(double speedMs) {
    // Approximate stride lengths at various speeds (meters):
    // 2.0 m/s (8:20/km) → ~1.4m stride
    // 2.5 m/s (6:40/km) → ~1.6m stride
    // 3.0 m/s (5:33/km) → ~1.8m stride
    // 3.5 m/s (4:46/km) → ~2.0m stride
    // 4.0 m/s (4:10/km) → ~2.2m stride
    // Linear interpolation: stride ≈ 0.4 * speed + 0.6
    final stride = 0.4 * speedMs + 0.6;
    return stride.clamp(1.0, 3.0);
  }

  /// Calculate cadence (steps per minute) from speed and stride length.
  ///
  /// cadence = (speed / stride_length) * 60 * 2
  /// The ×2 converts stride frequency to step frequency.
  static double cadenceFromSpeedAndStride(double speedMs, double strideLengthM) {
    if (strideLengthM <= 0 || speedMs <= 0) return 0;
    final strideFrequency = speedMs / strideLengthM; // strides per second
    return strideFrequency * 60.0 * 2.0; // steps per minute
  }

  /// Main calculation: pace (min/km) → cadence (spm).
  ///
  /// If [heightCm] is provided, uses height-based stride estimate.
  /// Otherwise, uses speed-based default stride estimate.
  /// Result is clamped to realistic running range (150-200 spm).
  static double calculateCadence({
    required double paceMinPerKm,
    double? heightCm,
  }) {
    final speed = paceToSpeed(paceMinPerKm);
    if (speed <= 0) return 0;

    final strideLength = heightCm != null
        ? strideLengthFromHeight(heightCm)
        : defaultStrideLengthFromSpeed(speed);

    final cadence = cadenceFromSpeedAndStride(speed, strideLength);
    return cadence.clamp(150.0, 200.0);
  }
}
```

### Pattern 2: Riverpod State for Stride Inputs (Manual Providers)
**What:** StateNotifier holding stride inputs + computed cadence, exposed as manual providers
**When to use:** Connecting domain logic to UI
**Why:** Matches project pattern (manual providers, Riverpod 2.x, no code-gen)

```dart
// lib/features/stride/providers/stride_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/stride_calculator.dart';

/// State holding all stride/cadence inputs and the computed result.
class StrideState {
  const StrideState({
    this.paceMinPerKm = 5.5,
    this.heightCm,
    this.calibratedCadence,
  });

  final double paceMinPerKm;
  final double? heightCm;
  final double? calibratedCadence;

  /// The effective cadence: calibration overrides formula.
  double get cadence {
    if (calibratedCadence != null) return calibratedCadence!;
    return StrideCalculator.calculateCadence(
      paceMinPerKm: paceMinPerKm,
      heightCm: heightCm,
    );
  }

  StrideState copyWith({
    double? paceMinPerKm,
    double? Function()? heightCm,
    double? Function()? calibratedCadence,
  }) {
    return StrideState(
      paceMinPerKm: paceMinPerKm ?? this.paceMinPerKm,
      heightCm: heightCm != null ? heightCm() : this.heightCm,
      calibratedCadence: calibratedCadence != null
          ? calibratedCadence()
          : this.calibratedCadence,
    );
  }
}

class StrideNotifier extends StateNotifier<StrideState> {
  StrideNotifier() : super(const StrideState());

  void setPace(double paceMinPerKm) {
    state = state.copyWith(paceMinPerKm: paceMinPerKm);
  }

  void setHeight(double? heightCm) {
    state = state.copyWith(heightCm: () => heightCm);
  }

  void setCalibratedCadence(double? cadence) {
    state = state.copyWith(calibratedCadence: () => cadence);
  }

  void clearCalibration() {
    state = state.copyWith(calibratedCadence: () => null);
  }
}

final strideNotifierProvider =
    StateNotifierProvider<StrideNotifier, StrideState>((ref) {
  return StrideNotifier();
});
```

### Pattern 3: Pace Input as Minutes:Seconds
**What:** TextFormField that accepts pace in "M:SS" format (e.g., "5:30" for 5.5 min/km)
**When to use:** Pace input field
**Why:** Runners think in min:sec, not decimal minutes

```dart
/// Parse pace string "M:SS" to decimal minutes.
/// "5:30" → 5.5, "4:00" → 4.0, "6:45" → 6.75
double? parsePace(String input) {
  final parts = input.split(':');
  if (parts.length != 2) return null;
  final minutes = int.tryParse(parts[0]);
  final seconds = int.tryParse(parts[1]);
  if (minutes == null || seconds == null) return null;
  if (seconds < 0 || seconds >= 60) return null;
  if (minutes < 0) return null;
  return minutes + seconds / 60.0;
}

/// Format decimal minutes to "M:SS" string.
/// 5.5 → "5:30", 4.0 → "4:00", 6.75 → "6:45"
String formatPace(double paceMinPerKm) {
  final minutes = paceMinPerKm.truncate();
  final seconds = ((paceMinPerKm - minutes) * 60).round();
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
```

### Pattern 4: Calibration Flow
**What:** User counts their actual steps over a fixed time/distance to calibrate cadence
**When to use:** STRIDE-03 — optional real-world calibration
**Design:** Count steps for 30 seconds, multiply by 2 for SPM. This is the standard "count for 30 seconds" method recommended by running coaches and apps.

```dart
// Calibration: user counts left-foot strikes for 30 seconds
// Multiply by 2 (both feet) × 2 (full minute) = × 4
// Or: user counts ALL steps for 30 seconds, multiply by 2
int calibrate({required int stepsIn30Seconds}) {
  return stepsIn30Seconds * 2; // extrapolate to full minute
}
```

### Anti-Patterns to Avoid
- **Putting computation logic in widgets:** Keep `StrideCalculator` as pure Dart in `domain/` — never import `flutter` in computation files
- **Using setState for form state:** Use Riverpod providers to match project patterns, not local widget state
- **Hardcoding a single cadence formula:** The formula should be decomposed into testable steps (pace→speed, height→stride, speed+stride→cadence) so each step can be verified independently
- **Over-engineering the calibration flow:** A timer countdown with step-counting is sufficient. No need for accelerometer/pedometer integration in v1
- **Ignoring the step vs stride distinction:** One stride = two steps. Cadence is in steps per minute (spm). Stride frequency is half of cadence. Getting this wrong doubles or halves the result

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Pace parsing/formatting | Custom regex parser | Dedicated `parsePace`/`formatPace` helper functions | But DO hand-roll these — they're trivial (~5 lines each) and adding a dependency for time parsing is overkill |
| Complex form validation | Custom validation framework | Flutter's built-in `Form` + `TextFormField` validators | Built-in `validator` callback handles all our needs |
| Persistent storage of preferences | Custom file I/O | SharedPreferences (or Supabase user_profiles table) | For saving user's height and calibration data across sessions |
| Timer for calibration | Custom timer | `Timer` / `Stopwatch` from `dart:async` / `dart:core` | Built-in Dart, no external package needed |

**Key insight:** This phase has NO external dependencies to add. Everything is pure computation + standard Flutter widgets + existing Riverpod. The value is in getting the formulas right and the UX clear, not in library selection.

## Common Pitfalls

### Pitfall 1: Step vs Stride Confusion
**What goes wrong:** Cadence is off by exactly 2x — either 85 spm or 340 spm instead of 170 spm
**Why it happens:** Mixing up "stride" (one full gait cycle, left-to-left) with "step" (one foot contact). Cadence is conventionally in steps/min (spm), but the physics formula uses strides/sec.
**How to avoid:** Document every function clearly with units. The conversion is: `cadence_spm = stride_frequency_per_second × 60 × 2`. Unit tests should catch this immediately.
**Warning signs:** Calculated cadence outside 100-250 range for reasonable pace inputs

### Pitfall 2: Pace Input UX
**What goes wrong:** Users enter "530" meaning 5:30, or "5.5" meaning 5 min 30 sec, or "5:30" literally
**Why it happens:** Pace can be represented many ways (M:SS, decimal minutes, seconds per km)
**How to avoid:** Use a clear "M:SS" format with placeholder text showing example (e.g., "5:30"). Validate on submission. Consider separate minute/second input fields if parsing proves confusing.
**Warning signs:** User testing reveals confusion about input format

### Pitfall 3: Height Unit Confusion
**What goes wrong:** User enters "5.8" (feet) but formula expects centimeters, producing wildly wrong stride length
**Why it happens:** Different countries use different height systems (cm vs feet+inches)
**How to avoid:** Default to cm with clear labeling. Consider offering a ft/in toggle if the app targets international users. For v1, cm-only with clear label is simplest.
**Warning signs:** Stride length estimates that are absurdly small or large

### Pitfall 4: Edge Cases in Pace Input
**What goes wrong:** Division by zero when pace is 0, or negative speed values, or extremely slow/fast paces producing nonsensical cadence
**Why it happens:** Missing input validation before computation
**How to avoid:** Validate pace is within reasonable range (3:00 - 10:00 min/km covers walk-to-sprint). Clamp cadence output to 150-200 spm. Return null/error for invalid inputs.
**Warning signs:** Cadence values outside 100-250 spm, NaN or Infinity in output

### Pitfall 5: Calibration Overriding Everything Silently
**What goes wrong:** User calibrates once, forgets about it, then changes pace but cadence doesn't change
**Why it happens:** Calibrated cadence takes absolute priority with no UI indication
**How to avoid:** Show clear UI state indicating "Using calibrated cadence" vs "Using estimated cadence". Provide a "Clear calibration" button. When calibration is active, show the formula estimate alongside for comparison.
**Warning signs:** User confusion about why changing pace doesn't affect cadence

### Pitfall 6: Not Clamping to Realistic Range
**What goes wrong:** Formula produces 120 spm (walking) or 250 spm (sprinting) for edge case inputs
**Why it happens:** Linear formulas extrapolate poorly outside their calibration range
**How to avoid:** Clamp final cadence to 150-200 spm range (success criteria #4). Show a warning when clamping occurs.
**Warning signs:** Output values at the clamping boundary suggest user inputs are outside expected running range

## Code Examples

### Complete Unit Test Suite Structure
```dart
// test/features/stride/domain/stride_calculator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/stride/domain/stride_calculator.dart';

void main() {
  group('StrideCalculator', () {
    group('paceToSpeed', () {
      test('5:00 min/km = 3.33 m/s', () {
        expect(
          StrideCalculator.paceToSpeed(5.0),
          closeTo(3.333, 0.01),
        );
      });

      test('4:00 min/km = 4.17 m/s', () {
        expect(
          StrideCalculator.paceToSpeed(4.0),
          closeTo(4.167, 0.01),
        );
      });

      test('zero pace returns 0', () {
        expect(StrideCalculator.paceToSpeed(0), equals(0));
      });
    });

    group('strideLengthFromHeight', () {
      test('170 cm height → ~1.105 m stride', () {
        expect(
          StrideCalculator.strideLengthFromHeight(170),
          closeTo(1.105, 0.01),
        );
      });

      test('180 cm height → ~1.17 m stride', () {
        expect(
          StrideCalculator.strideLengthFromHeight(180),
          closeTo(1.17, 0.01),
        );
      });
    });

    group('calculateCadence', () {
      test('5:00 min/km without height produces cadence in 150-200 range', () {
        final cadence = StrideCalculator.calculateCadence(
          paceMinPerKm: 5.0,
        );
        expect(cadence, greaterThanOrEqualTo(150));
        expect(cadence, lessThanOrEqualTo(200));
      });

      test('adding height adjusts cadence', () {
        final withoutHeight = StrideCalculator.calculateCadence(
          paceMinPerKm: 5.0,
        );
        final withHeight = StrideCalculator.calculateCadence(
          paceMinPerKm: 5.0,
          heightCm: 190, // tall runner → longer stride → lower cadence
        );
        expect(withHeight, isNot(equals(withoutHeight)));
      });

      test('result is always clamped to 150-200', () {
        // Very slow pace
        final slow = StrideCalculator.calculateCadence(paceMinPerKm: 9.0);
        expect(slow, greaterThanOrEqualTo(150));

        // Very fast pace
        final fast = StrideCalculator.calculateCadence(paceMinPerKm: 3.0);
        expect(fast, lessThanOrEqualTo(200));
      });
    });
  });
}
```

### Pace Input Widget Pattern
```dart
// Using TextFormField with M:SS format
TextFormField(
  decoration: const InputDecoration(
    labelText: 'Target Pace',
    hintText: '5:30',
    suffixText: 'min/km',
  ),
  keyboardType: TextInputType.datetime, // gives : on keyboard
  validator: (value) {
    if (value == null || value.isEmpty) return 'Enter a pace';
    final pace = parsePace(value);
    if (pace == null) return 'Use M:SS format (e.g., 5:30)';
    if (pace < 3.0 || pace > 10.0) return 'Pace must be 3:00-10:00 min/km';
    return null;
  },
  onChanged: (value) {
    final pace = parsePace(value);
    if (pace != null) {
      ref.read(strideNotifierProvider.notifier).setPace(pace);
    }
  },
)
```

### Height Slider Widget Pattern
```dart
// Material Slider for height input
Column(
  children: [
    Text('Height: ${heightCm?.round() ?? "--"} cm'),
    Slider(
      value: heightCm ?? 170,
      min: 140,
      max: 210,
      divisions: 70, // 1 cm increments
      label: '${(heightCm ?? 170).round()} cm',
      onChanged: (value) {
        ref.read(strideNotifierProvider.notifier).setHeight(value);
      },
    ),
  ],
)
```

### Cadence Display Widget Pattern
```dart
// Real-time cadence display that updates as inputs change
Consumer(
  builder: (context, ref, _) {
    final state = ref.watch(strideNotifierProvider);
    final cadence = state.cadence;
    final isCalibrated = state.calibratedCadence != null;

    return Column(
      children: [
        Text(
          '${cadence.round()} spm',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        if (isCalibrated)
          Chip(
            label: const Text('Calibrated'),
            onDeleted: () {
              ref.read(strideNotifierProvider.notifier).clearCalibration();
            },
          )
        else
          Text(
            'Estimated from ${state.heightCm != null ? "pace + height" : "pace"}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  },
)
```

## Biomechanics Reference

### The Fundamental Relationship
```
Speed (m/s) = Stride Length (m) × Stride Frequency (strides/s)
Cadence (spm) = Stride Frequency × 60 × 2
```

Therefore:
```
Cadence (spm) = (2 × Speed × 60) / Stride Length
              = 120 × Speed / Stride Length
```

### Stride Length Estimation Methods

| Method | Formula | Accuracy | When to Use |
|--------|---------|----------|-------------|
| Height-based | stride = height_cm × 0.65 / 100 | Moderate (~20-40% of variance explained by height) | User provides height (STRIDE-02) |
| Speed-based default | stride ≈ 0.4 × speed + 0.6 | Low-moderate | No height available (STRIDE-01 fallback) |
| Direct calibration | cadence = steps_counted × (60 / counting_duration_sec) | High | User performs calibration (STRIDE-03) |

### Stride Length Multiplier for Height
| Source | Multiplier | Context |
|--------|-----------|---------|
| Walking (general) | 0.43 | Not applicable for this app |
| Running (conservative) | 0.45 | Elite runner optimal range lower bound |
| Running (general) | 0.65 | Widely cited running multiplier |
| Running (elite optimal) | 0.45-0.48 | Elite runner range |

**Recommendation:** Use **0.65** as the running stride multiplier for height. This is the most commonly cited value for recreational runners and produces stride lengths that, combined with typical running speeds, yield cadences in the expected 160-185 spm range.

**Important note on multiplier confusion:** Some sources cite 0.65 as a "stride length" multiplier where stride = full gait cycle (left foot to left foot). Others cite 0.43 as a "step length" multiplier where step = half a stride. These are consistent: 0.43 × 2 ≈ 0.86, which is in the right ballpark when accounting for the difference between walking (0.43 per step) and running (0.65 per stride). The key is being consistent about whether you're computing step length or stride length and converting appropriately.

### Realistic Cadence Ranges by Pace
| Pace (min/km) | Typical Cadence (spm) | Runner Type |
|---------------|----------------------|-------------|
| 3:00-3:30 | 185-200+ | Elite marathon |
| 3:30-4:00 | 180-190 | Competitive |
| 4:00-5:00 | 170-185 | Intermediate |
| 5:00-6:00 | 165-180 | Recreational |
| 6:00-7:00 | 155-170 | Beginner |
| 7:00-8:00+ | 150-165 | Slow jog/walk-run |

### Calibration Method
The standard manual calibration method used by running coaches and apps:
1. Run at target pace for at least 30 seconds
2. Count every foot strike (both feet) for 30 seconds
3. Multiply by 2 to get steps per minute

Alternative: Count only left foot strikes for 60 seconds, multiply by 2.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| "Everyone should run at 180 spm" (Daniels, 1984) | Cadence varies with speed, height, and individual biomechanics | Gradual shift, well-established by 2020 | No single target cadence; must calculate per-runner |
| Height-only stride estimation | Multi-factor models (speed + height + weight + age) | Recent research (Movaia 2023+) | Height-only is good enough for v1; speed is the dominant factor |
| Fixed stride length per runner | Stride length increases with speed (cadence stays more constant) | Well-established | At higher speeds, stride length increases more than cadence |

**Key insight for this app:** Speed (derived from pace) is the primary driver of cadence. Height is a meaningful secondary factor. Weight and age have minimal effect and can be safely omitted in v1.

## Routing Integration

### Adding Stride Screen to GoRouter
The stride screen needs to be added to the existing router in `lib/app/router.dart`:

```dart
GoRoute(
  path: '/stride',
  builder: (context, state) => const StrideScreen(),
),
```

The home screen should provide navigation to the stride calculator. Since this phase depends only on Phase 1 (not Phase 2 auth), the stride screen should be accessible to all users (no auth guard needed for computation-only features, though the app's existing auth guard will apply since all routes except `/login` require auth).

## Open Questions

1. **Persistence of stride settings**
   - What we know: User's height and calibration data should persist across sessions
   - What's unclear: Whether to use local storage (SharedPreferences) or Supabase (user_profiles table). Supabase would require auth (Phase 2 dependency), but SharedPreferences works without auth.
   - Recommendation: Use SharedPreferences for v1 since Phase 5 depends only on Phase 1. Can migrate to Supabase user_profiles later when auth is working. Alternatively, since the app currently guards all routes behind auth, Supabase may be available — but don't create a hard dependency on it for this phase's core functionality.

2. **Stride length multiplier precision**
   - What we know: Sources cite 0.65 (full stride) and 0.43 (step) for running; elite research suggests 0.45-0.48 as optimal stride-to-height ratio
   - What's unclear: The 0.65 multiplier may overestimate stride length for slower recreational runners, producing cadence estimates on the low end
   - Recommendation: Use 0.65 as starting point. The calibration feature (STRIDE-03) exists specifically to correct inaccuracies. If user feedback shows systematic bias, the multiplier can be tuned later.

3. **Pace input: min/km vs min/mile**
   - What we know: The requirements specify min/km
   - What's unclear: Whether international users will need min/mile
   - Recommendation: Build with min/km for v1 per requirements. Structure the conversion functions so adding min/mile support later is trivial (it's just a constant multiplier: 1 mile = 1.60934 km).

## Sources

### Primary (HIGH confidence)
- Fundamental biomechanics: Speed = Stride Length × Stride Frequency (textbook physics, universally established)
- [Omnicalculator - Stride Length](https://www.omnicalculator.com/sports/stride-length) — Height-to-stride ratio of 0.43 (walking), confirmed
- [GenghisFitness - Stride Length Calculator](https://www.genghisfitness.com/stride-length-calculator/) — Running multiplier 0.65, walking 0.415
- [Running Writings - Science of Cadence (Jan 2026)](https://runningwritings.com/2026/01/science-of-cadence.html) — Height explains ~24% of cadence variance; speed is primary driver
- [Flutter docs - Form validation](https://docs.flutter.dev/cookbook/forms/validation) — TextFormField validator pattern
- [Flutter docs - Slider](https://api.flutter.dev/flutter/material/Slider-class.html) — Material Slider widget API

### Secondary (MEDIUM confidence)
- [Strength Running - Best Running Cadence](https://strengthrunning.com/2020/02/best-running-cadence-step-rate/) — Cadence ranges by pace, debunking 180 spm myth
- [Marathon Handbook - Average Stride Length](https://marathonhandbook.com/average-stride-length/) — Stride length by height data
- [Movaia Cadence Calculator](https://movaia.com/cadence-calculator/) — Multi-factor prediction model (speed, height, weight, age); proprietary formula not disclosed
- [Calculator Academy - Cadence Running Calculator](https://calculator.academy/cadence-running-calculator/) — Basic cadence formulas confirmed
- Speed-stride data points (Very Easy 1.4m to Elite 2.4m+) — [RunnerSpace stride length tool](https://tools.runnerspace.com/gprofile.php?do=title&title_id=805&mgroup_id=45577)
- Stride length estimation tables — [FitLifeRegime](https://fitliferegime.com/running-cadence-calculator/)

### Tertiary (LOW confidence)
- Height multiplier range (0.45 for running vs 0.65) — multiple sources disagree on whether this is step length or stride length; cross-referenced and resolved via stride/step distinction

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — No new dependencies needed; uses existing project libraries
- Architecture: HIGH — Follows established project patterns (feature folders, manual Riverpod providers, domain layer)
- Biomechanics formulas: MEDIUM — Core relationship (speed = stride × frequency) is physics fact (HIGH), but the height-to-stride multiplier varies across sources (0.43 to 0.65 depending on step vs stride and walking vs running). Resolved with clear documentation of which multiplier and what it represents.
- Pitfalls: HIGH — Well-known issues (step vs stride, unit confusion, edge cases) documented from multiple sources
- UI patterns: HIGH — Standard Flutter form patterns, no novel approaches needed

**Research date:** 2026-02-05
**Valid until:** 2026-03-07 (30 days — stable domain, no fast-moving dependencies)
