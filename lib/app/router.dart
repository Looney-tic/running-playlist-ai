import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:running_playlist_ai/features/auth/presentation/login_screen.dart';
import 'package:running_playlist_ai/features/home/presentation/home_screen.dart';
import 'package:running_playlist_ai/features/settings/presentation/settings_screen.dart';
import 'package:running_playlist_ai/features/stride/presentation/stride_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A `ChangeNotifier` that listens to Supabase auth state changes
/// and notifies GoRouter to re-evaluate its redirect logic.
///
/// Used as GoRouter's `refreshListenable` so that route guards react
/// automatically to login/logout events without manual navigation.
class AuthNotifier extends ChangeNotifier {
  AuthNotifier() {
    _subscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _subscription;

  /// Whether the user currently has an active Supabase session.
  bool get isAuthenticated =>
      Supabase.instance.client.auth.currentSession != null;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Provides the [AuthNotifier] singleton for GoRouter refresh.
///
/// Disposes the notifier when the provider is disposed.
final authNotifierProvider = Provider<AuthNotifier>((ref) {
  final notifier = AuthNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

/// Application router with auth-guarded routes.
///
/// Uses [AuthNotifier] as `refreshListenable` so the router
/// re-evaluates redirects on every auth state change.
final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isAuthenticated = authNotifier.isAuthenticated;
      final isLoginRoute = state.matchedLocation == '/login';

      // Not authenticated and not on login page -> go to login
      if (!isAuthenticated && !isLoginRoute) return '/login';

      // Authenticated and on login page -> go to home
      if (isAuthenticated && isLoginRoute) return '/';

      // No redirect needed
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/stride',
        builder: (context, state) => const StrideScreen(),
      ),
    ],
  );
});
