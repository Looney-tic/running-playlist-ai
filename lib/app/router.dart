import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:running_playlist_ai/features/home/presentation/home_screen.dart';
import 'package:running_playlist_ai/features/onboarding/presentation/onboarding_screen.dart';
import 'package:running_playlist_ai/features/onboarding/providers/onboarding_providers.dart';
import 'package:running_playlist_ai/features/playlist/presentation/playlist_history_detail_screen.dart';
import 'package:running_playlist_ai/features/playlist/presentation/playlist_history_screen.dart';
import 'package:running_playlist_ai/features/playlist/presentation/playlist_screen.dart';
import 'package:running_playlist_ai/features/run_plan/presentation/run_plan_library_screen.dart';
import 'package:running_playlist_ai/features/run_plan/presentation/run_plan_screen.dart';
import 'package:running_playlist_ai/features/settings/presentation/settings_screen.dart';
import 'package:running_playlist_ai/features/stride/presentation/stride_screen.dart';
import 'package:running_playlist_ai/features/taste_profile/presentation/taste_profile_library_screen.dart';
import 'package:running_playlist_ai/features/taste_profile/presentation/taste_profile_screen.dart';

/// Application router with routes for all app features.
///
/// Includes an onboarding redirect: new users (onboarding not completed) are
/// sent to /onboarding; returning users who try to visit /onboarding are
/// redirected to /.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final onboarded = ref.read(onboardingCompletedProvider);
      final isOnboardingRoute = state.matchedLocation == '/onboarding';

      // New user trying to go anywhere except onboarding -> redirect.
      if (!onboarded && !isOnboardingRoute) return '/onboarding';

      // Returning user trying to visit onboarding -> redirect to home.
      if (onboarded && isOnboardingRoute) return '/';

      // No redirect needed.
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/stride',
        builder: (context, state) => const StrideScreen(),
      ),
      GoRoute(
        path: '/my-runs',
        builder: (context, state) => const RunPlanLibraryScreen(),
      ),
      GoRoute(
        path: '/run-plan',
        builder: (context, state) => const RunPlanScreen(),
      ),
      GoRoute(
        path: '/taste-profiles',
        builder: (context, state) => const TasteProfileLibraryScreen(),
      ),
      GoRoute(
        path: '/taste-profile',
        builder: (context, state) => TasteProfileScreen(
          profileId: state.uri.queryParameters['id'],
        ),
      ),
      GoRoute(
        path: '/playlist',
        builder: (context, state) => PlaylistScreen(
          autoGenerate: state.uri.queryParameters['auto'] == 'true',
        ),
      ),
      GoRoute(
        path: '/playlist-history',
        builder: (context, state) => const PlaylistHistoryScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return PlaylistHistoryDetailScreen(playlistId: id);
            },
          ),
        ],
      ),
    ],
  );
});
