import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/curated_songs/data/curated_song_repository.dart';

/// Provides curated song runnability scores for playlist generation.
///
/// Loads curated songs on first access (cache-first, Supabase refresh,
/// bundled fallback). Returns a `Map<String, int>` mapping normalized
/// lookup keys to runnability scores for use during quality scoring.
///
/// This is a [FutureProvider] because loading is async (SharedPreferences
/// + potential network). Riverpod auto-caches the result -- subsequent
/// reads within the same app session return instantly.
final curatedRunnabilityProvider =
    FutureProvider<Map<String, int>>((ref) async {
  final songs = await CuratedSongRepository.loadCuratedSongs();
  return {
    for (final s in songs)
      s.lookupKey: s.runnability ?? 20, // default 20 for songs without data
  };
});

/// Legacy alias kept for backward compatibility.
///
/// Prefer [curatedRunnabilityProvider] for new code.
final curatedLookupKeysProvider =
    FutureProvider<Set<String>>((ref) async {
  final songs = await CuratedSongRepository.loadCuratedSongs();
  return CuratedSongRepository.buildLookupSet(songs);
});
