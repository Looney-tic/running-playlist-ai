/// Riverpod providers for Spotify authentication state.
///
/// Wires [SpotifyAuthService] (mock by default) into the widget tree
/// and exposes reactive connection status for UI consumption.
///
/// Manual providers (not code-gen) per project conventions with
/// Riverpod 2.x and Dart 3.10.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running_playlist_ai/features/spotify_auth/data/mock_spotify_auth_repository.dart';
import 'package:running_playlist_ai/features/spotify_auth/data/spotify_token_storage.dart';
import 'package:running_playlist_ai/features/spotify_auth/domain/spotify_auth_service.dart';

/// The active [SpotifyAuthService] implementation.
///
/// Returns [MockSpotifyAuthRepository] by default (Spotify Dashboard
/// unavailable). Swap to `SpotifyAuthRepository` when real credentials
/// are available.
final spotifyAuthServiceProvider = Provider<SpotifyAuthService>((ref) {
  final storage = SpotifyTokenStorage();
  final service = MockSpotifyAuthRepository(storage)
    // Attempt session restoration on creation.
    ..restoreSession();
  return service;
});

/// Reactive Spotify connection status.
///
/// Rebuilds when status changes (connected, disconnected, etc.).
final spotifyConnectionStatusProvider =
    StreamProvider<SpotifyConnectionStatus>((ref) {
  final service = ref.watch(spotifyAuthServiceProvider);
  return service.statusStream;
});

/// Current Spotify connection status (synchronous snapshot).
///
/// Defaults to [SpotifyConnectionStatus.disconnected] if the stream
/// hasn't emitted yet.
final spotifyConnectionStatusSyncProvider =
    Provider<SpotifyConnectionStatus>((ref) {
  final asyncStatus = ref.watch(spotifyConnectionStatusProvider);
  return asyncStatus.valueOrNull ?? SpotifyConnectionStatus.disconnected;
});
