/// Domain layer for song search functionality.
///
/// Provides an abstract [SongSearchService] interface for backend
/// extensibility (curated catalog now, Spotify later) and a
/// [CuratedSongSearchService] implementation that searches the local
/// curated song catalog using substring matching.
library;

import 'package:running_playlist_ai/features/curated_songs/domain/curated_song.dart';

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
