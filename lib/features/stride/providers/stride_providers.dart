import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/stride/data/stride_preferences.dart';
import 'package:running_playlist_ai/features/stride/domain/stride_calculator.dart';

/// Immutable state for the stride/cadence feature.
///
/// Holds the user's target pace, optional height, and optional calibrated
/// cadence. The [cadence] getter computes the displayed value: calibrated
/// cadence if available, otherwise the formula estimate via [StrideCalculator].
class StrideState {
  const StrideState({
    this.paceMinPerKm = 5.5,
    this.heightCm,
    this.calibratedCadence,
  });

  /// Target running pace in decimal minutes per kilometer (e.g. 5.5 = 5:30).
  final double paceMinPerKm;

  /// User's height in centimeters, or null if not provided.
  final double? heightCm;

  /// Cadence from real-world calibration (spm), or null if not calibrated.
  final double? calibratedCadence;

  /// The cadence to display. Returns calibrated cadence if set,
  /// otherwise calculates from pace and optional height.
  double get cadence {
    if (calibratedCadence != null) return calibratedCadence!;
    return StrideCalculator.calculateCadence(
      paceMinPerKm: paceMinPerKm,
      heightCm: heightCm,
    );
  }

  /// Creates a copy with updated fields.
  ///
  /// Uses nullable function pattern for optional fields so callers
  /// can explicitly set them to null: `copyWith(heightCm: () => null)`.
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

/// Manages stride state mutations and persistence.
///
/// Loads saved preferences on initialization and persists height
/// and calibration changes to SharedPreferences automatically.
class StrideNotifier extends StateNotifier<StrideState> {
  StrideNotifier() : super(const StrideState()) {
    _loadFromPreferences();
  }

  /// Updates the target pace (decimal minutes per km).
  void setPace(double paceMinPerKm) {
    state = state.copyWith(paceMinPerKm: paceMinPerKm);
  }

  /// Updates the user's height. Pass null to clear.
  void setHeight(double? heightCm) {
    state = state.copyWith(heightCm: () => heightCm);
    _persist();
  }

  /// Sets calibrated cadence from real-world measurement.
  void setCalibratedCadence(double cadence) {
    state = state.copyWith(calibratedCadence: () => cadence);
    _persist();
  }

  /// Clears calibration, reverting to formula-based estimate.
  void clearCalibration() {
    state = state.copyWith(calibratedCadence: () => null);
    _persist();
  }

  /// Loads saved height and calibration from SharedPreferences.
  Future<void> _loadFromPreferences() async {
    final height = await StridePreferences.loadHeight();
    final calibratedCadence = await StridePreferences.loadCalibratedCadence();
    state = state.copyWith(
      heightCm: () => height,
      calibratedCadence: () => calibratedCadence,
    );
  }

  /// Persists current height and calibration to SharedPreferences.
  Future<void> _persist() async {
    await Future.wait([
      StridePreferences.saveHeight(state.heightCm),
      StridePreferences.saveCalibratedCadence(state.calibratedCadence),
    ]);
  }
}

/// Provides [StrideNotifier] and its [StrideState] to the widget tree.
///
/// Usage:
/// - `ref.watch(strideNotifierProvider)` to read state reactively
/// - `ref.read(strideNotifierProvider.notifier).setPace(5.0)` to mutate
final strideNotifierProvider =
    StateNotifierProvider<StrideNotifier, StrideState>(
  (ref) => StrideNotifier(),
);
