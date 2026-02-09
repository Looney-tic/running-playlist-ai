/// Real Spotify authentication implementation using the `spotify` package.
///
/// Structurally complete PKCE OAuth flow. NOT the default provider yet --
/// `MockSpotifyAuthRepository` is the active default until Spotify
/// Developer Dashboard credentials become available.
library;

import 'dart:async';

import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:running_playlist_ai/core/constants/spotify_constants.dart';
import 'package:running_playlist_ai/features/spotify_auth/data/spotify_token_storage.dart';
import 'package:running_playlist_ai/features/spotify_auth/domain/spotify_auth_service.dart';
import 'package:spotify/spotify.dart' as spotify;
import 'package:url_launcher/url_launcher.dart';

/// Real [SpotifyAuthService] implementation using Spotify's PKCE OAuth flow.
///
/// Uses the `spotify` package's `SpotifyApi.authorizationCodeGrant` for
/// the authorization code exchange and `SpotifyApi.asyncFromCredentials`
/// for token refresh with automatic credential persistence.
///
/// Constructor requires:
/// - `clientId`: Spotify Client ID from environment
/// - `tokenStorage`: Secure credential persistence
class SpotifyAuthRepository implements SpotifyAuthService {
  /// Creates a repository backed by real Spotify OAuth.
  SpotifyAuthRepository({
    required String clientId,
    required SpotifyTokenStorage tokenStorage,
  })  : _clientId = clientId,
        _tokenStorage = tokenStorage;

  final String _clientId;
  final SpotifyTokenStorage _tokenStorage;

  SpotifyConnectionStatus _status = SpotifyConnectionStatus.disconnected;

  final StreamController<SpotifyConnectionStatus> _statusController =
      StreamController<SpotifyConnectionStatus>.broadcast();

  /// The active authorization code grant (held between connect and callback).
  oauth2.AuthorizationCodeGrant? _currentGrant;

  /// The authenticated Spotify API client.
  spotify.SpotifyApi? _spotifyApi;

  /// Lock to prevent concurrent token refreshes.
  Completer<String?>? _refreshCompleter;

  void _setStatus(SpotifyConnectionStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

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

    try {
      // Create PKCE credentials (no client secret needed for PKCE).
      final credentials = spotify.SpotifyApiCredentials(_clientId, null);

      // Create authorization code grant with PKCE.
      // The oauth2 package auto-generates a code verifier internally.
      _currentGrant = spotify.SpotifyApi.authorizationCodeGrant(
        credentials,
        onCredentialsRefreshed: _onCredentialsRefreshed,
      );

      // Get the authorization URL with requested scopes.
      final authUri = _currentGrant!.getAuthorizationUrl(
        Uri.parse(spotifyCallbackUrl),
        scopes: spotifyScopes.split(' '),
      );

      // Launch browser for user authorization.
      await launchUrl(authUri, mode: LaunchMode.externalApplication);

      // Status stays `connecting` until handleCallback() completes.
    } on Exception catch (_) {
      _setStatus(SpotifyConnectionStatus.error);
    }
  }

  @override
  Future<void> handleCallback(Uri callbackUri) async {
    try {
      if (_currentGrant == null) {
        _setStatus(SpotifyConnectionStatus.error);
        return;
      }

      // Exchange authorization code for tokens.
      final params = callbackUri.queryParameters;
      final client =
          await _currentGrant!.handleAuthorizationResponse(params);

      // Create the authenticated API client.
      _spotifyApi = spotify.SpotifyApi.fromClient(client);

      // Get credentials and persist them.
      final creds = await _spotifyApi!.getCredentials();
      await _saveSpotifyCredentials(creds);

      _setStatus(SpotifyConnectionStatus.connected);
    } on Exception catch (_) {
      _setStatus(SpotifyConnectionStatus.error);
    } finally {
      _currentGrant = null;
    }
  }

  @override
  Future<void> disconnect() async {
    await _tokenStorage.clearAll();
    _spotifyApi = null;
    _currentGrant = null;
    _setStatus(SpotifyConnectionStatus.disconnected);
  }

  @override
  Future<String?> getAccessToken() async {
    // If another refresh is in progress, wait for it.
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final creds = await _tokenStorage.loadCredentials();
    if (creds == null) return null;

    // Check if token is still valid (with 5-minute buffer).
    if (creds.expiration != null) {
      final bufferExpiration =
          creds.expiration!.subtract(const Duration(minutes: 5));
      if (DateTime.now().isBefore(bufferExpiration)) {
        return creds.accessToken;
      }
    } else if (!creds.isExpired) {
      // No expiration set but not marked expired -- return token.
      return creds.accessToken;
    }

    // Token expired or near expiration -- attempt refresh.
    _refreshCompleter = Completer<String?>();

    try {
      // Reconstruct SpotifyApiCredentials for refresh.
      final apiCreds = spotify.SpotifyApiCredentials(
        _clientId,
        null, // No secret for PKCE
        accessToken: creds.accessToken,
        refreshToken: creds.refreshToken,
        scopes: creds.scopes,
        expiration: creds.expiration,
      );

      // asyncFromCredentials handles the refresh automatically.
      _spotifyApi = await spotify.SpotifyApi.asyncFromCredentials(
        apiCreds,
        onCredentialsRefreshed: _onCredentialsRefreshed,
      );

      final newCreds = await _spotifyApi!.getCredentials();
      await _saveSpotifyCredentials(newCreds);

      final token = newCreds.accessToken;
      _refreshCompleter!.complete(token);
      return token;
    } on Exception catch (_) {
      // Refresh failed -- clear everything and go disconnected.
      await _tokenStorage.clearAll();
      _spotifyApi = null;
      _setStatus(SpotifyConnectionStatus.disconnected);
      _refreshCompleter!.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }

  @override
  Future<void> restoreSession() async {
    final creds = await _tokenStorage.loadCredentials();
    if (creds == null) {
      // No saved session -- stay disconnected.
      return;
    }

    try {
      // Attempt to create API client from saved credentials.
      final apiCreds = spotify.SpotifyApiCredentials(
        _clientId,
        null,
        accessToken: creds.accessToken,
        refreshToken: creds.refreshToken,
        scopes: creds.scopes,
        expiration: creds.expiration,
      );

      _spotifyApi = await spotify.SpotifyApi.asyncFromCredentials(
        apiCreds,
        onCredentialsRefreshed: _onCredentialsRefreshed,
      );

      _setStatus(SpotifyConnectionStatus.connected);
    } on Exception catch (_) {
      // Restore failed -- clear stale credentials.
      await _tokenStorage.clearAll();
      _spotifyApi = null;
      _setStatus(SpotifyConnectionStatus.disconnected);
    }
  }

  /// Callback invoked by the spotify package when credentials are refreshed.
  void _onCredentialsRefreshed(spotify.SpotifyApiCredentials creds) {
    _saveSpotifyCredentials(creds);
  }

  /// Map `SpotifyApiCredentials` to our [SpotifyCredentials] and persist.
  Future<void> _saveSpotifyCredentials(
    spotify.SpotifyApiCredentials apiCreds,
  ) async {
    final creds = SpotifyCredentials(
      accessToken: apiCreds.accessToken ?? '',
      refreshToken: apiCreds.refreshToken,
      expiration: apiCreds.expiration,
      scopes: apiCreds.scopes,
      // codeVerifier omitted: PKCE verifier is managed by oauth2 grant
    );
    await _tokenStorage.saveCredentials(creds);
  }

  /// Release the status stream controller.
  void dispose() {
    _statusController.close();
  }
}
