/// Pure Dart URL construction for external song links. No Flutter dependencies.
///
/// Builds Spotify and YouTube Music search URLs from song metadata.
/// Search URLs work without any API authentication and open the respective
/// app if installed, or fall back to the web player.
library;

/// Constructs external search URLs for playing songs on Spotify or
/// YouTube Music.
class SongLinkBuilder {
  /// Builds a Spotify search URL for a song.
  ///
  /// Format: `https://open.spotify.com/search/{encoded query}`
  ///
  /// ```dart
  /// SongLinkBuilder.spotifySearchUrl('Lose Yourself', 'Eminem');
  /// // => 'https://open.spotify.com/search/Lose%20Yourself%20Eminem'
  /// ```
  static String spotifySearchUrl(String title, String artist) {
    final query = '$title $artist';
    return 'https://open.spotify.com/search/${Uri.encodeComponent(query)}';
  }

  /// Builds a YouTube Music search URL for a song.
  ///
  /// Format: `https://music.youtube.com/search?q={encoded query}`
  ///
  /// ```dart
  /// SongLinkBuilder.youtubeMusicSearchUrl('Lose Yourself', 'Eminem');
  /// // => 'https://music.youtube.com/search?q=Lose+Yourself+Eminem'
  /// ```
  static String youtubeMusicSearchUrl(String title, String artist) {
    final query = '$title $artist';
    final uri = Uri.https('music.youtube.com', '/search', {'q': query});
    return uri.toString();
  }
}
