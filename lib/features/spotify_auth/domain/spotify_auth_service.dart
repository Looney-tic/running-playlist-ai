/// Domain layer for Spotify authentication.
///
/// Defines the [SpotifyAuthService] abstract interface and
/// [SpotifyConnectionStatus] enum that all auth consumers depend on.
/// Implementations handle OAuth PKCE flow, token management, and
/// session persistence.
library;

/// Connection state for Spotify authentication.
enum SpotifyConnectionStatus {
  /// Not connected to Spotify. Initial state.
  disconnected,

  /// OAuth flow in progress (browser open, waiting for callback).
  connecting,

  /// Successfully authenticated with valid credentials.
  connected,

  /// Authentication failed or token refresh failed.
  error,
}

/// Abstract interface for Spotify authentication backends.
///
/// Implementations manage the OAuth PKCE lifecycle: initiating login,
/// handling callbacks, persisting tokens, and refreshing expired tokens.
///
/// Follows the same pattern as `SongSearchService` -- abstract class
/// (not abstract interface class) for Riverpod 2.x manual providers.
abstract class SpotifyAuthService {
  /// Initiate the OAuth PKCE flow (opens browser for login).
  Future<void> connect();

  /// Clear tokens and set status to [SpotifyConnectionStatus.disconnected].
  Future<void> disconnect();

  /// Handle the OAuth redirect callback after user authorises.
  Future<void> handleCallback(Uri callbackUri);

  /// Return a valid access token, refreshing if needed.
  ///
  /// Returns `null` if not connected or refresh fails (graceful
  /// degradation -- callers fall back to non-Spotify behaviour).
  Future<String?> getAccessToken();

  /// Current connection status (synchronous snapshot).
  SpotifyConnectionStatus get status;

  /// Stream of status changes for reactive UI updates.
  Stream<SpotifyConnectionStatus> get statusStream;

  /// Convenience getter: status is connected AND token is valid.
  Future<bool> get isConnected;

  /// Attempt to restore a saved session on app start.
  ///
  /// Loads credentials from secure storage. If found and not expired
  /// (or refreshable), sets status to connected. Otherwise stays
  /// disconnected.
  Future<void> restoreSession();
}
