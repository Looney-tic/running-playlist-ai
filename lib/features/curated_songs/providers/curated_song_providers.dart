import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/curated_songs/data/curated_song_repository.dart';

/// Provides the curated song lookup set for playlist generation.
///
/// Loads curated songs on first access (cache-first, Supabase refresh,
/// bundled fallback). Returns a `Set<String>` of normalized lookup keys
/// for O(1) membership checks during scoring.
///
/// This is a [FutureProvider] because loading is async (SharedPreferences
/// + potential network). Riverpod auto-caches the result -- subsequent
/// reads within the same app session return instantly.
final curatedLookupKeysProvider = FutureProvider<Set<String>>((ref) async {
  final songs = await CuratedSongRepository.loadCuratedSongs();
  return CuratedSongRepository.buildLookupSet(songs);
});
