/// Domain layer for song search functionality.
///
/// Provides an abstract [SongSearchService] interface for backend
/// extensibility and implementations for curated catalog, Spotify API,
/// and composite (merged) search.
library;

import 'package:running_playlist_ai/features/curated_songs/domain/curated_song.dart';
import 'package:running_playlist_ai/features/song_feedback/domain/song_feedback.dart';
import 'package:spotify/spotify.dart' as spotify;

/// A search result from any song search backend.
///
/// Value class that normalizes results from different sources
/// (curated catalog, Spotify, etc.) into a common shape.
class SongSearchResult {
  const SongSearchResult({
    required this.title,
    required this.artist,
    required this.source,
    this.bpm,
    this.genre,
    this.spotifyUri,
  });

  /// Song title.
  final String title;

  /// Artist name.
  final String artist;

  /// BPM if known.
  final int? bpm;

  /// Genre identifier if known.
  final String? genre;

  /// Origin of this result (e.g. 'curated', 'spotify').
  final String source;

  /// Spotify track URI (e.g. 'spotify:track:abc123'), null for curated results.
  final String? spotifyUri;
}

/// Abstract interface for song search backends.
///
/// Implementations search different catalogs (curated, Spotify, etc.)
/// and return normalized [SongSearchResult] lists.
abstract class SongSearchService {
  /// Searches for songs matching [query].
  ///
  /// Returns an empty list for blank or too-short queries.
  /// Results are capped at an implementation-defined limit.
  Future<List<SongSearchResult>> search(String query);
}

/// Searches the local curated song catalog using substring matching.
///
/// Constructor takes the full curated song list. Search is performed
/// in-memory with case-insensitive substring matching against both
/// title and artist name. Results are capped at 20.
class CuratedSongSearchService implements SongSearchService {
  /// Creates a search service backed by the given curated songs.
  CuratedSongSearchService(this._songs);

  final List<CuratedSong> _songs;

  /// Maximum number of results to return.
  static const _maxResults = 20;

  @override
  Future<List<SongSearchResult>> search(String query) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.length < 2) return [];

    return _songs
        .where((song) =>
            song.title.toLowerCase().contains(trimmed) ||
            song.artistName.toLowerCase().contains(trimmed))
        .take(_maxResults)
        .map((song) => SongSearchResult(
              title: song.title,
              artist: song.artistName,
              bpm: song.bpm,
              genre: song.genre,
              source: 'curated',
            ))
        .toList();
  }
}

/// Searches the Spotify catalog via the Spotify Web API.
///
/// Wraps the Spotify API search endpoint with graceful degradation --
/// any exception returns an empty list rather than propagating.
/// BPM is not available from Spotify search (Audio Features deprecated).
class SpotifySongSearchService implements SongSearchService {
  /// Creates a search service backed by the given Spotify API client.
  SpotifySongSearchService(this._spotifyApi);

  final spotify.SpotifyApi _spotifyApi;

  /// Maximum number of results to request from Spotify.
  static const _maxResults = 20;

  @override
  Future<List<SongSearchResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];

    try {
      final pages = await _spotifyApi.search
          .get(trimmed, types: [spotify.SearchType.track])
          .first(_maxResults);

      if (pages.isEmpty) return [];

      final trackPage = pages.first;
      final tracks = trackPage.items?.cast<spotify.Track>() ?? [];

      return tracks
          .where((track) =>
              (track.name ?? '').isNotEmpty ||
              _artistName(track).isNotEmpty)
          .map((track) => SongSearchResult(
                title: track.name ?? '',
                artist: _artistName(track),
                source: 'spotify',
                spotifyUri: track.uri,
              ))
          .toList();
    } on Exception catch (_) {
      // Graceful degradation -- return empty on any Spotify error.
      return [];
    }
  }

  /// Formats the artist name from a Track's artist list.
  static String _artistName(spotify.Track track) {
    return track.artists?.map((a) => a.name ?? '').join(', ') ??
        'Unknown Artist';
  }
}

/// Merges results from curated and Spotify search with deduplication.
///
/// Curated results appear first (they have BPM data), followed by
/// unique Spotify results. Duplicates are identified via [SongKey.normalize]
/// with curated taking priority. Total results capped at 20.
class CompositeSongSearchService implements SongSearchService {
  /// Creates a composite service merging curated and Spotify results.
  CompositeSongSearchService({
    required this.curatedService,
    required this.spotifyService,
  });

  /// The curated catalog search backend.
  final SongSearchService curatedService;

  /// The Spotify search backend.
  final SongSearchService spotifyService;

  @override
  Future<List<SongSearchResult>> search(String query) async {
    final curatedResults = await curatedService.search(query);

    List<SongSearchResult> spotifyResults;
    try {
      spotifyResults = await spotifyService.search(query);
    } on Exception catch (_) {
      // Spotify failed -- degrade gracefully to curated-only.
      return curatedResults;
    }

    // Deduplicate: curated results take priority.
    final seen = <String>{};
    final merged = <SongSearchResult>[];

    for (final result in curatedResults) {
      seen.add(SongKey.normalize(result.artist, result.title));
      merged.add(result);
    }

    for (final result in spotifyResults) {
      final key = SongKey.normalize(result.artist, result.title);
      if (!seen.contains(key)) {
        seen.add(key);
        merged.add(result);
      }
    }

    return merged.take(20).toList();
  }
}
