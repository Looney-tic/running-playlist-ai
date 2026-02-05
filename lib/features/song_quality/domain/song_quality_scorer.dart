/// Pure Dart song quality scorer. No Flutter dependencies.
///
/// Computes a composite running-suitability score for candidate songs
/// using danceability, genre match, energy alignment, segment-aware
/// energy, artist diversity, and BPM accuracy.
library;

import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_song.dart';
import 'package:running_playlist_ai/features/taste_profile/domain/taste_profile.dart';

/// Scores songs for running playlist quality across multiple dimensions.
///
/// All methods are static and pure -- no side effects, no Flutter
/// dependencies. Designed for deterministic unit testing and easy
/// integration into playlist generation.
class SongQualityScorer {
  /// Computes a composite score for a candidate song.
  ///
  /// Returns an integer score (higher = better fit for the playlist).
  static int score({
    required BpmSong song,
    TasteProfile? tasteProfile,
    int? danceability,
    String? segmentLabel,
    String? previousArtist,
    List<RunningGenre>? songGenres,
  }) {
    // Stub: return 0 to make tests fail
    return 0;
  }

  /// Reorders a ranked list so no two consecutive songs share the same artist.
  static List<T> enforceArtistDiversity<T>(
    List<T> rankedSongs,
    String Function(T) getArtist,
  ) {
    // Stub: return unmodified list to make tests fail
    return List<T>.from(rankedSongs);
  }
}
