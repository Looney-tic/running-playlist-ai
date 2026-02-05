/// All Spotify OAuth scopes the app needs.
///
/// Requested upfront during initial login to avoid re-authentication.
/// See: https://developer.spotify.com/documentation/web-api/concepts/scopes
const String spotifyScopes =
    'user-read-email user-read-private user-top-read '
    'user-library-read playlist-modify-public playlist-modify-private';

/// Custom URL scheme for deep link redirects on mobile.
const String spotifyRedirectScheme = 'io.runplaylist.app';

/// Full redirect URL used for OAuth callback on mobile platforms.
const String spotifyRedirectUrl = 'io.runplaylist.app://login-callback';
