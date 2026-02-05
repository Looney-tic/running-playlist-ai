import 'package:shared_preferences/shared_preferences.dart';

/// Persistence wrapper for stride-related user preferences.
///
/// Stores height (cm) and calibrated cadence (spm) to SharedPreferences
/// so they survive app restarts. Uses static methods with async access
/// to the SharedPreferences singleton.
class StridePreferences {
  static const _heightKey = 'stride_height_cm';
  static const _calibratedCadenceKey = 'stride_calibrated_cadence';

  /// Loads the saved height in centimeters, or null if not set.
  static Future<double?> loadHeight() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_heightKey) ? prefs.getDouble(_heightKey) : null;
  }

  /// Loads the saved calibrated cadence in spm, or null if not set.
  static Future<double?> loadCalibratedCadence() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_calibratedCadenceKey)
        ? prefs.getDouble(_calibratedCadenceKey)
        : null;
  }

  /// Saves height in centimeters. Pass null to clear the stored value.
  static Future<void> saveHeight(double? heightCm) async {
    final prefs = await SharedPreferences.getInstance();
    if (heightCm != null) {
      await prefs.setDouble(_heightKey, heightCm);
    } else {
      await prefs.remove(_heightKey);
    }
  }

  /// Saves calibrated cadence in spm. Pass null to clear the stored value.
  static Future<void> saveCalibratedCadence(double? cadence) async {
    final prefs = await SharedPreferences.getInstance();
    if (cadence != null) {
      await prefs.setDouble(_calibratedCadenceKey, cadence);
    } else {
      await prefs.remove(_calibratedCadenceKey);
    }
  }
}
