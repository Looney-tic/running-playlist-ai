import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/auth/data/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provides the [AuthRepository] backed by the Supabase client singleton.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});

/// Stream of [AuthState] changes from Supabase auth.
///
/// Used by widgets and providers that need to react to login/logout events.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Current Supabase session, or `null` if not authenticated.
final currentSessionProvider = Provider<Session?>((ref) {
  return Supabase.instance.client.auth.currentSession;
});

/// Whether the user is currently authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  final session = ref.watch(currentSessionProvider);
  return session != null;
});
