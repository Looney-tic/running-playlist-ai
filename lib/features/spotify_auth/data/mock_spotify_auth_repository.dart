/// Mock Spotify authentication implementation for development.
///
/// Simulates the full OAuth PKCE lifecycle without real Spotify
/// credentials. This is the default implementation used during
/// development since the Spotify Developer Dashboard is unavailable.
library;

import 'dart:async';

import 'package:running_playlist_ai/features/spotify_auth/data/spotify_token_storage.dart';
import 'package:running_playlist_ai/features/spotify_auth/domain/spotify_auth_service.dart';

/// Mock implementation of [SpotifyAuthService] for development and testing.
///
/// Simulates connect/disconnect/refresh with artificial delays and
/// generated tokens. Persists credentials via `SpotifyTokenStorage`
/// so session restore works identically to the real implementation.
class MockSpotifyAuthRepository implements SpotifyAuthService {
  /// Creates a mock repository backed by the given token storage.
  MockSpotifyAuthRepository(this._tokenStorage);

  final SpotifyTokenStorage _tokenStorage;

  SpotifyConnectionStatus _status = SpotifyConnectionStatus.disconnected;

  final StreamController<SpotifyConnectionStatus> _statusController =
      StreamController<SpotifyConnectionStatus>.broadcast();

  /// Lock to prevent concurrent token refreshes.
  Completer<String?>? _refreshLock;

  void _setStatus(SpotifyConnectionStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  /// Generate a mock token from the current timestamp.
  String _generateMockToken() =>
      'mock_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  @override
  SpotifyConnectionStatus get status => _status;

  @override
  Stream<SpotifyConnectionStatus> get statusStream =>
      _statusController.stream;

  @override
  Future<bool> get isConnected async =>
      _status == SpotifyConnectionStatus.connected &&
      (await getAccessToken()) != null;

  @override
  Future<void> connect() async {
    _setStatus(SpotifyConnectionStatus.connecting);

    // Simulate network latency.
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final credentials = SpotifyCredentials(
      accessToken: _generateMockToken(),
      refreshToken: 'mock_refresh_${DateTime.now().millisecondsSinceEpoch}',
      expiration: DateTime.now().add(const Duration(hours: 1)),
      scopes: ['user-read-email', 'user-library-read'],
      codeVerifier: 'mock_verifier_${DateTime.now().millisecondsSinceEpoch}',
    );

    await _tokenStorage.saveCredentials(credentials);
    _setStatus(SpotifyConnectionStatus.connected);
  }

  @override
  Future<void> disconnect() async {
    await _tokenStorage.clearAll();
    _setStatus(SpotifyConnectionStatus.disconnected);
  }

  @override
  Future<void> handleCallback(Uri callbackUri) async {
    // No-op for mock -- connect() handles the entire flow.
  }

  @override
  Future<String?> getAccessToken() async {
    // If another refresh is in progress, wait for it.
    if (_refreshLock != null) {
      return _refreshLock!.future;
    }

    final creds = await _tokenStorage.loadCredentials();
    if (creds == null) return null;

    if (!creds.isExpired) {
      return creds.accessToken;
    }

    // Token expired -- simulate refresh with a lock.
    _refreshLock = Completer<String?>();

    try {
      final newToken = _generateMockToken();
      final refreshed = SpotifyCredentials(
        accessToken: newToken,
        refreshToken: creds.refreshToken,
        expiration: DateTime.now().add(const Duration(hours: 1)),
        scopes: creds.scopes,
        codeVerifier: creds.codeVerifier,
      );
      await _tokenStorage.saveCredentials(refreshed);
      _refreshLock!.complete(newToken);
      return newToken;
    } on Exception catch (_) {
      _refreshLock!.complete(null);
      return null;
    } finally {
      _refreshLock = null;
    }
  }

  @override
  Future<void> restoreSession() async {
    final creds = await _tokenStorage.loadCredentials();
    if (creds != null) {
      _setStatus(SpotifyConnectionStatus.connected);
    }
    // If no credentials found, stay disconnected (no status change).
  }

  /// Release the status stream controller.
  void dispose() {
    _statusController.close();
  }
}
