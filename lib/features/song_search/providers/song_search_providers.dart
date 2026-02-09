import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/curated_songs/data/curated_song_repository.dart';
import 'package:running_playlist_ai/features/curated_songs/domain/curated_song.dart';
import 'package:running_playlist_ai/features/song_search/data/mock_spotify_search_service.dart';
import 'package:running_playlist_ai/features/song_search/domain/song_search_service.dart';
import 'package:running_playlist_ai/features/spotify_auth/domain/spotify_auth_service.dart';
import 'package:running_playlist_ai/features/spotify_auth/providers/spotify_auth_providers.dart';

/// Provides the full list of curated songs for search.
///
/// Loads asynchronously via [CuratedSongRepository.loadCuratedSongs]
/// (cache-first, Supabase refresh, bundled fallback). Riverpod
/// auto-caches the result for the app session.
final curatedSongsListProvider =
    FutureProvider<List<CuratedSong>>((ref) async {
  return CuratedSongRepository.loadCuratedSongs();
});

/// Provides the [SongSearchService] for the current session.
///
/// When Spotify is connected, returns a [CompositeSongSearchService] that
/// merges curated catalog results with Spotify catalog results (with
/// deduplication). When Spotify is not connected, returns a plain
/// [CuratedSongSearchService] backed by the curated catalog only.
///
/// This provider is a [FutureProvider] because it depends on async data
/// sources (curated song list loading, token retrieval).
final songSearchServiceProvider =
    FutureProvider<SongSearchService>((ref) async {
  final songs = await ref.watch(curatedSongsListProvider.future);
  final curatedService = CuratedSongSearchService(songs);

  final spotifyStatus = ref.watch(spotifyConnectionStatusSyncProvider);
  if (spotifyStatus != SpotifyConnectionStatus.connected) {
    return curatedService;
  }

  // Spotify is connected -- build composite service.
  final authService = ref.read(spotifyAuthServiceProvider);
  final token = await authService.getAccessToken();
  if (token == null) return curatedService;

  // For now, use mock since Spotify Dashboard is unavailable.
  // When real credentials are available, replace with:
  //   final spotifyApi = SpotifyApi.withAccessToken(token);
  //   final spotifyService = SpotifySongSearchService(spotifyApi);
  final spotifyService = MockSpotifySongSearchService();

  return CompositeSongSearchService(
    curatedService: curatedService,
    spotifyService: spotifyService,
  );
});
