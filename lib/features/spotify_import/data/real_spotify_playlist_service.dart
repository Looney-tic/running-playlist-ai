/// Real Spotify API implementation of [SpotifyPlaylistService].
///
/// Uses the `spotify` 0.15.0 package to fetch the current user's
/// playlists and their tracks via the Spotify Web API.
///
/// Requires a valid [SpotifyApi] instance with an authenticated session
/// that includes `playlist-read-private` and `playlist-read-collaborative`
/// OAuth scopes.
library;

import 'package:spotify/spotify.dart' as spotify;

import 'package:running_playlist_ai/features/spotify_import/domain/spotify_playlist_service.dart';

/// [SpotifyPlaylistService] backed by the real Spotify Web API.
///
/// Constructor takes a [SpotifyApi] instance (from the `spotify` package).
/// All methods degrade gracefully -- returning empty lists on any error
/// rather than propagating exceptions.
class RealSpotifyPlaylistService implements SpotifyPlaylistService {
  /// Creates a real playlist service backed by the given Spotify API client.
  RealSpotifyPlaylistService(this._spotifyApi);

  final spotify.SpotifyApi _spotifyApi;

  @override
  Future<List<SpotifyPlaylistInfo>> getUserPlaylists() async {
    try {
      final playlists = await _spotifyApi.playlists.me.all(50);
      return playlists
          .map((p) => SpotifyPlaylistInfo(
                id: p.id ?? '',
                name: p.name ?? 'Untitled',
                description: p.description,
                imageUrl: p.images?.isNotEmpty == true
                    ? p.images!.first.url
                    : null,
                trackCount: p.tracksLink?.total,
                ownerName: p.owner?.displayName,
              ))
          .where((p) => p.id.isNotEmpty)
          .toList();
    } catch (_) {
      // Graceful degradation -- return empty on any error.
      return [];
    }
  }

  @override
  Future<List<SpotifyPlaylistTrack>> getPlaylistTracks(
    String playlistId,
  ) async {
    try {
      final tracks = await _spotifyApi.playlists
          .getPlaylistTracks(playlistId)
          .all(50);
      return tracks
          .where((pt) => pt.track != null && !(pt.isLocal ?? false))
          .map((pt) => SpotifyPlaylistTrack(
                title: pt.track!.name ?? '',
                artist: _artistName(pt.track!),
                spotifyUri: pt.track!.uri,
                durationMs: pt.track!.durationMs,
                albumName: pt.track!.album?.name,
                imageUrl: pt.track!.album?.images?.isNotEmpty == true
                    ? pt.track!.album!.images!.first.url
                    : null,
              ))
          .where((t) => t.title.isNotEmpty)
          .toList();
    } catch (_) {
      // Graceful degradation -- return empty on any error.
      return [];
    }
  }

  /// Formats the artist name from a Track's artist list.
  ///
  /// Reuses the same pattern as [SpotifySongSearchService._artistName].
  static String _artistName(spotify.Track track) {
    return track.artists?.map((a) => a.name ?? '').join(', ') ??
        'Unknown Artist';
  }
}
