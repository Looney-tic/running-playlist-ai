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

  /// Estimates stride length from running speed when height is unknown.
  ///
  /// Uses linear model: stride = 0.4 * speed + 0.6, clamped to [1.0, 3.0].
  static double defaultStrideLengthFromSpeed(double speedMs) {
    final stride = 0.4 * speedMs + 0.6;
    return stride.clamp(1.0, 3.0);
  }

  /// Converts speed and stride length to cadence in steps per minute.
  ///
  /// Cadence = (speed / stride) * 60 * 2.
  /// The *2 converts stride frequency to step frequency (one stride = two steps).
  /// Returns 0.0 for zero or negative inputs.
  static double cadenceFromSpeedAndStride(
      double speedMs, double strideLengthM) {
    if (strideLengthM <= 0 || speedMs <= 0) return 0.0;
    final strideFrequency = speedMs / strideLengthM;
    return strideFrequency * 60.0 * 2.0;
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
