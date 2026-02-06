import 'package:shared_preferences/shared_preferences.dart';

/// Persists the onboarding-completed flag via SharedPreferences.
///
/// The [completedSync] field is pre-loaded in main.dart before GoRouter
/// initializes, so the router redirect can read it synchronously.
class OnboardingPreferences {
  static const _key = 'onboarding_completed';

  /// Synchronous snapshot of the onboarding flag, populated by [preload].
  ///
  /// GoRouter redirect reads this value — it must be available before
  /// the first route resolution.
  static bool completedSync = false;

  /// Pre-loads the onboarding flag into [completedSync].
  ///
  /// Call this in main.dart after WidgetsFlutterBinding.ensureInitialized()
  /// and before runApp(). This ensures GoRouter redirect has a synchronous
  /// value on the very first frame.
  static Future<void> preload() async {
    final prefs = await SharedPreferences.getInstance();
    completedSync = prefs.getBool(_key) ?? false;
  }

  /// Reads the onboarding-completed flag (async).
  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  /// Marks onboarding as completed and updates [completedSync].
  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    completedSync = true;
  }
}
