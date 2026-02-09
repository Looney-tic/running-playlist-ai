/// Domain layer for Spotify playlist import functionality.
///
/// Provides an abstract [SpotifyPlaylistService] interface and lightweight
/// data classes ([SpotifyPlaylistInfo], [SpotifyPlaylistTrack]) for
/// browsing user playlists and importing tracks into "Songs I Run To".
///
/// Follows the same abstract-class pattern as [SongSearchService] and
/// [SpotifyAuthService] for mock-first development.
library;

/// Simplified playlist metadata for display in the playlist browser.
///
/// Immutable value object extracted from Spotify's `PlaylistSimple` model.
/// Only carries the fields needed for UI rendering and track fetching.
class SpotifyPlaylistInfo {
  const SpotifyPlaylistInfo({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.trackCount,
    this.ownerName,
  });

  /// Spotify playlist ID used to fetch tracks.
  final String id;

  /// Display name of the playlist.
  final String name;

  /// Optional playlist description.
  final String? description;

  /// URL to the playlist cover image, if available.
  final String? imageUrl;

  /// Total number of tracks in the playlist, if known.
  final int? trackCount;

  /// Display name of the playlist owner.
  final String? ownerName;
}

/// A track from a Spotify playlist, ready for import consideration.
///
/// Immutable value object extracted from Spotify's `PlaylistTrack` model.
/// Carries display fields and the Spotify URI for identification.
class SpotifyPlaylistTrack {
  const SpotifyPlaylistTrack({
    required this.title,
    required this.artist,
    this.spotifyUri,
    this.durationMs,
    this.albumName,
    this.imageUrl,
  });

  /// Track title.
  final String title;

  /// Artist name(s), comma-separated if multiple.
  final String artist;

  /// Spotify track URI (e.g. 'spotify:track:abc123').
  final String? spotifyUri;

  /// Track duration in milliseconds.
  final int? durationMs;

  /// Album name, if available.
  final String? albumName;

  /// URL to the album art image, if available.
  final String? imageUrl;
}

/// Abstract interface for Spotify playlist operations.
///
/// Implementations fetch the current user's playlists and their tracks.
/// Follows the same pattern as [SongSearchService] -- abstract class
/// (not abstract interface class) for Riverpod 2.x manual providers.
abstract class SpotifyPlaylistService {
  /// Fetch the current user's playlists.
  ///
  /// Returns an empty list on error (graceful degradation).
  Future<List<SpotifyPlaylistInfo>> getUserPlaylists();

  /// Fetch tracks for a specific playlist.
  ///
  /// Returns an empty list on error or for unknown playlist IDs.
  /// Filters out local tracks and entries with empty titles.
  Future<List<SpotifyPlaylistTrack>> getPlaylistTracks(String playlistId);
}
