/// Riverpod providers for Spotify playlist import.
///
/// Wires [SpotifyPlaylistService] (mock by default) into the widget tree.
/// Uses connection status to determine which implementation to return.
///
/// Manual providers (not code-gen) per project conventions with
/// Riverpod 2.x and Dart 3.10.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running_playlist_ai/features/spotify_auth/domain/spotify_auth_service.dart';
import 'package:running_playlist_ai/features/spotify_auth/providers/spotify_auth_providers.dart';
import 'package:running_playlist_ai/features/spotify_import/data/mock_spotify_playlist_service.dart';
import 'package:running_playlist_ai/features/spotify_import/domain/spotify_playlist_service.dart';

/// Provides the [SpotifyPlaylistService] for the current session.
///
/// When Spotify is connected, returns [MockSpotifyPlaylistService] since
/// real Spotify Dashboard credentials are unavailable.
///
/// When Spotify is not connected, still returns the mock service (the UI
/// layer should gate access based on connection status).
///
/// TODO: Swap to [RealSpotifyPlaylistService] when Spotify Developer
/// Dashboard is available. Use:
///   final authService = ref.read(spotifyAuthServiceProvider);
///   final token = await authService.getAccessToken();
///   final spotifyApi = SpotifyApi.withAccessToken(token!);
///   return RealSpotifyPlaylistService(spotifyApi);
final spotifyPlaylistServiceProvider =
    Provider<SpotifyPlaylistService>((ref) {
  final status = ref.watch(spotifyConnectionStatusSyncProvider);
  if (status == SpotifyConnectionStatus.connected) {
    // Mock for now -- swap to RealSpotifyPlaylistService when Dashboard available.
    return MockSpotifyPlaylistService();
  }
  // Return mock even when disconnected; UI layer gates access.
  return MockSpotifyPlaylistService();
});
