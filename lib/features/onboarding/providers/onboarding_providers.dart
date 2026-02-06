import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/onboarding/data/onboarding_preferences.dart';

/// Whether the user has completed onboarding.
///
/// Initialized from [OnboardingPreferences.completedSync], which is pre-loaded
/// in main.dart before GoRouter init. The router redirect reads this provider
/// synchronously via `ref.read(onboardingCompletedProvider)`.
///
/// Updated to `true` when the user finishes the onboarding flow.
final onboardingCompletedProvider = StateProvider<bool>(
  (ref) => OnboardingPreferences.completedSync,
);
