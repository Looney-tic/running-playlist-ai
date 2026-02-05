/// Pure Dart domain logic for stride length estimation, cadence calculation,
/// and pace parsing. No Flutter dependencies.

class StrideCalculator {
  /// Converts pace (minutes per kilometer) to speed (meters per second).
  ///
  /// Returns 0.0 for zero or negative pace values.
  static double paceToSpeed(double paceMinPerKm) {
    if (paceMinPerKm <= 0) return 0.0;
    return 1000.0 / (paceMinPerKm * 60.0);
  }

  /// Estimates stride length from height using the 0.65 multiplier.
  ///
  /// Returns stride length in meters.
  static double strideLengthFromHeight(double heightCm) {
    return heightCm * 0.65 / 100.0;
  }

  /// Estimates step length from running speed when height is unknown.
  ///
  /// Uses linear model derived from biomechanical cadence data:
  /// step_length = 0.26 * speed + 0.25, clamped to [0.5, 1.8].
  static double defaultStrideLengthFromSpeed(double speedMs) {
    final stepLength = 0.26 * speedMs + 0.25;
    return stepLength.clamp(0.5, 1.8);
  }

  /// Converts speed and step length to cadence in steps per minute.
  ///
  /// Cadence = (speed / step_length) * 60.
  /// Both [strideLengthFromHeight] and [defaultStrideLengthFromSpeed] return
  /// step length (single foot contact distance), so no stride-to-step
  /// conversion is needed.
  /// Returns 0.0 for zero or negative inputs.
  static double cadenceFromSpeedAndStride(
      double speedMs, double strideLengthM) {
    if (strideLengthM <= 0 || speedMs <= 0) return 0.0;
    final stepFrequency = speedMs / strideLengthM;
    return stepFrequency * 60.0;
  }

  /// Calculates target cadence from pace and optional height.
  ///
  /// Combines [paceToSpeed], stride estimation (height-based or speed-based
  /// fallback), and [cadenceFromSpeedAndStride].
  /// Result is clamped to 150-200 spm for realistic running cadences.
  /// Returns 0.0 for invalid (zero/negative) pace.
  static double calculateCadence({
    required double paceMinPerKm,
    double? heightCm,
  }) {
    final speed = paceToSpeed(paceMinPerKm);
    if (speed <= 0) return 0.0;

    final strideLength = heightCm != null
        ? strideLengthFromHeight(heightCm)
        : defaultStrideLengthFromSpeed(speed);

    final cadence = cadenceFromSpeedAndStride(speed, strideLength);
    return cadence.clamp(150.0, 200.0);
  }
}

/// Parses a pace string in "M:SS" format to decimal minutes.
///
/// Returns `null` for invalid input (non-numeric, missing colon, seconds >= 60,
/// negative values, empty string).
double? parsePace(String input) {
  final parts = input.split(':');
  if (parts.length != 2) return null;

  final minutes = int.tryParse(parts[0]);
  final seconds = int.tryParse(parts[1]);
  if (minutes == null || seconds == null) return null;
  if (minutes < 0) return null;
  if (seconds < 0 || seconds >= 60) return null;

  return minutes + seconds / 60.0;
}

/// Formats decimal minutes as a pace string in "M:SS" format.
String formatPace(double paceMinPerKm) {
  final minutes = paceMinPerKm.truncate();
  final seconds = ((paceMinPerKm - minutes) * 60).round();
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
