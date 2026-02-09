/// Mock Spotify search service for development and testing.
///
/// Returns hardcoded results that simulate Spotify catalog searches.
/// Includes 3 songs that overlap with the curated catalog (for dedup
/// testing) and 7 Spotify-only songs.
library;

import 'package:running_playlist_ai/features/song_search/domain/song_search_service.dart';

/// Mock implementation of [SongSearchService] that simulates Spotify search.
///
/// Used while Spotify Developer Dashboard is unavailable for new app
/// registrations. Replace with [SpotifySongSearchService] when real
/// credentials are available.
class MockSpotifySongSearchService implements SongSearchService {
  @override
  Future<List<SongSearchResult>> search(String query) async {
    // Simulate network latency.
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final trimmed = query.trim().toLowerCase();
    if (trimmed.length < 2) return [];

    return _mockCatalog
        .where((song) =>
            song.title.toLowerCase().contains(trimmed) ||
            song.artist.toLowerCase().contains(trimmed))
        .take(10)
        .toList();
  }

  /// Hardcoded mock catalog simulating Spotify search results.
  ///
  /// First 3 songs overlap with the curated catalog for deduplication
  /// testing. Remaining 7 are Spotify-only.
  static final _mockCatalog = <SongSearchResult>[
    // --- Curated catalog overlaps (for dedup testing) ---
    const SongSearchResult(
      title: 'Lose Yourself',
      artist: 'Eminem',
      source: 'spotify',
      spotifyUri: 'spotify:track:mock_lose',
    ),
    const SongSearchResult(
      title: 'Blinding Lights',
      artist: 'The Weeknd',
      source: 'spotify',
      spotifyUri: 'spotify:track:mock_blinding',
    ),
    const SongSearchResult(
      title: 'Run the World',
      artist: 'Beyonce',
      source: 'spotify',
      spotifyUri: 'spotify:track:mock_run',
    ),

    // --- Spotify-only songs ---
    const SongSearchResult(
      title: 'HUMBLE.',
      artist: 'Kendrick Lamar',
      source: 'spotify',
      spotifyUri: 'spotify:track:mock_humble',
    ),
    const SongSearchResult(
      title: 'Levitating',
      artist: 'Dua Lipa',
      source: 'spotify',
      spotifyUri: 'spotify:track:mock_levitating',
    ),
    const SongSearchResult(
      title: 'Physical',
      artist: 'Dua Lipa',
      source: 'spotify',
      spotifyUri: 'spotify:track:mock_physical',
    ),
    const SongSearchResult(
      title: 'Shivers',
      artist: 'Ed Sheeran',
      source: 'spotify',
      spotifyUri: 'spotify:track:mock_shivers',
    ),
    const SongSearchResult(
      title: 'Heat Waves',
      artist: 'Glass Animals',
      source: 'spotify',
      spotifyUri: 'spotify:track:mock_heat',
    ),
    const SongSearchResult(
      title: 'As It Was',
      artist: 'Harry Styles',
      source: 'spotify',
      spotifyUri: 'spotify:track:mock_asit',
    ),
    const SongSearchResult(
      title: 'Anti-Hero',
      artist: 'Taylor Swift',
      source: 'spotify',
      spotifyUri: 'spotify:track:mock_antihero',
    ),
  ];
}
