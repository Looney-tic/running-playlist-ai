import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/curated_songs/data/curated_song_repository.dart';
import 'package:running_playlist_ai/features/curated_songs/domain/curated_song.dart';
import 'package:running_playlist_ai/features/song_search/domain/song_search_service.dart';

/// Provides the full list of curated songs for search.
///
/// Loads asynchronously via [CuratedSongRepository.loadCuratedSongs]
/// (cache-first, Supabase refresh, bundled fallback). Riverpod
/// auto-caches the result for the app session.
final curatedSongsListProvider =
    FutureProvider<List<CuratedSong>>((ref) async {
  return CuratedSongRepository.loadCuratedSongs();
});

/// Provides the [SongSearchService] backed by the curated catalog.
///
/// Awaits [curatedSongsListProvider] to get the full song list,
/// then creates a [CuratedSongSearchService] instance. This provider
/// is a [FutureProvider] because it depends on an async data source.
///
/// Future implementations can swap this to return a Spotify-backed
/// service without changing consumer code.
final songSearchServiceProvider =
    FutureProvider<SongSearchService>((ref) async {
  final songs = await ref.watch(curatedSongsListProvider.future);
  return CuratedSongSearchService(songs);
});
