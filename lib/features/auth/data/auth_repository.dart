import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:running_playlist_ai/core/constants/spotify_constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository wrapping Supabase OAuth operations for Spotify login.
///
/// Handles platform-aware redirect URLs and launch modes.
/// Uses [LaunchMode.externalApplication] on mobile to avoid iOS
/// in-app WebView redirect failures (see research Pitfall 2).
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  /// Sign in with Spotify via Supabase OAuth.
  ///
  /// On web, uses default redirect (current page URL).
  /// On mobile, redirects to [spotifyRedirectUrl] deep link.
  Future<bool> signInWithSpotify() async {
    return _client.auth.signInWithOAuth(
      OAuthProvider.spotify,
      redirectTo: kIsWeb ? null : spotifyRedirectUrl,
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
      scopes: spotifyScopes,
    );
  }

  /// Sign out and clear the Supabase session.
  ///
  /// Does NOT perform manual navigation -- GoRouter redirect handles it.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Current Supabase session, or `null` if not authenticated.
  Session? get currentSession => _client.auth.currentSession;

  /// Stream of auth state changes from Supabase.
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// Whether the user is currently authenticated.
  bool get isAuthenticated => currentSession != null;
}
