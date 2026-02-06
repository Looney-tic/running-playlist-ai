import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:running_playlist_ai/features/home/presentation/home_screen.dart';
import 'package:running_playlist_ai/features/playlist/presentation/playlist_history_detail_screen.dart';
import 'package:running_playlist_ai/features/playlist/presentation/playlist_history_screen.dart';
import 'package:running_playlist_ai/features/playlist/presentation/playlist_screen.dart';
import 'package:running_playlist_ai/features/run_plan/presentation/run_plan_screen.dart';
import 'package:running_playlist_ai/features/settings/presentation/settings_screen.dart';
import 'package:running_playlist_ai/features/stride/presentation/stride_screen.dart';
import 'package:running_playlist_ai/features/taste_profile/presentation/taste_profile_screen.dart';

/// Application router with routes for all app features.
///
/// No auth guard — the app launches directly to the home hub.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
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
        path: '/run-plan',
        builder: (context, state) => const RunPlanScreen(),
      ),
      GoRoute(
        path: '/taste-profile',
        builder: (context, state) => const TasteProfileScreen(),
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
