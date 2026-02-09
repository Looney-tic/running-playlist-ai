/// Secure credential persistence for Spotify OAuth tokens.
///
/// Uses [FlutterSecureStorage] to store access tokens, refresh tokens,
/// and related OAuth state in the platform keychain/keystore.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Immutable value class holding Spotify OAuth credentials.
///
/// Plain immutable class (not freezed) following the same pattern as
/// `SongSearchResult`. Includes [codeVerifier] which must be persisted
/// for token refresh (Spotify PKCE requirement).
class SpotifyCredentials {
  const SpotifyCredentials({
    required this.accessToken,
    this.refreshToken,
    this.expiration,
    this.scopes,
    this.codeVerifier,
  });

  /// The OAuth access token for API calls.
  final String accessToken;

  /// The refresh token for obtaining new access tokens.
  final String? refreshToken;

  /// When the access token expires.
  final DateTime? expiration;

  /// Granted OAuth scopes.
  final List<String>? scopes;

  /// PKCE code verifier -- must persist for token refresh.
  final String? codeVerifier;

  /// Whether the access token has expired.
  bool get isExpired =>
      expiration != null && DateTime.now().isAfter(expiration!);
}

/// Persists [SpotifyCredentials] in platform-secure storage.
///
/// Each credential field is stored under a `spotify_`-prefixed key.
/// Constructor accepts an optional [FlutterSecureStorage] for testability.
class SpotifyTokenStorage {
  /// Creates storage backed by [storage] (defaults to platform default).
  SpotifyTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  // Storage key constants.
  static const _accessTokenKey = 'spotify_access_token';
  static const _refreshTokenKey = 'spotify_refresh_token';
  static const _expirationKey = 'spotify_token_expiration';
  static const _scopesKey = 'spotify_scopes';
  static const _codeVerifierKey = 'spotify_code_verifier';

  /// Save all credential fields to secure storage.
  Future<void> saveCredentials(SpotifyCredentials creds) async {
    await _storage.write(key: _accessTokenKey, value: creds.accessToken);

    if (creds.refreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: creds.refreshToken);
    }

    if (creds.expiration != null) {
      await _storage.write(
        key: _expirationKey,
        value: creds.expiration!.toIso8601String(),
      );
    }

    if (creds.scopes != null) {
      await _storage.write(key: _scopesKey, value: creds.scopes!.join(','));
    }

    if (creds.codeVerifier != null) {
      await _storage.write(key: _codeVerifierKey, value: creds.codeVerifier);
    }
  }

  /// Load credentials from secure storage.
  ///
  /// Returns `null` if no access token is stored.
  Future<SpotifyCredentials?> loadCredentials() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    if (accessToken == null) return null;

    final refreshToken = await _storage.read(key: _refreshTokenKey);
    final expirationStr = await _storage.read(key: _expirationKey);
    final scopesStr = await _storage.read(key: _scopesKey);
    final codeVerifier = await _storage.read(key: _codeVerifierKey);

    return SpotifyCredentials(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiration:
          expirationStr != null ? DateTime.parse(expirationStr) : null,
      scopes: scopesStr?.split(','),
      codeVerifier: codeVerifier,
    );
  }

  /// Delete all spotify-prefixed keys.
  ///
  /// Uses explicit key deletion (not `deleteAll()`) to avoid wiping
  /// other secure storage data.
  Future<void> clearAll() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _expirationKey);
    await _storage.delete(key: _scopesKey);
    await _storage.delete(key: _codeVerifierKey);
  }

  /// Quick check whether an access token exists in storage.
  Future<bool> get hasCredentials async =>
      await _storage.read(key: _accessTokenKey) != null;
}
