/// Pure Dart song quality scorer. No Flutter dependencies.
///
/// Computes a composite running-suitability score for candidate songs
/// using genre match, artist match, BPM accuracy, artist diversity,
/// decade match, and curated bonus.
library;

import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_song.dart';
import 'package:running_playlist_ai/features/taste_profile/domain/taste_profile.dart';

/// Scores songs for running playlist quality across multiple dimensions.
///
/// All methods are static and pure -- no side effects, no Flutter
/// dependencies. Designed for deterministic unit testing and easy
/// integration into playlist generation.
class SongQualityScorer {
  // ── Weight constants (public for testability and future tuning) ──

  /// Score bonus when the song's artist matches a taste profile artist.
  static const artistMatchWeight = 10;

  /// Score bonus when the song's genre matches a taste profile genre.
  static const genreMatchWeight = 6;

  /// Score bonus for exact BPM match.
  static const exactBpmWeight = 3;

  /// Score bonus for half-time or double-time BPM match.
  static const tempoVariantWeight = 1;

  /// Penalty for consecutive songs by the same artist.
  static const artistDiversityPenalty = -5;

  /// Penalty for songs by an artist the user dislikes.
  static const dislikedArtistPenalty = -15;

  /// Score for half-time/double-time match under loose tempo tolerance.
  static const looseTempoVariantWeight = 2;

  /// Score bonus for songs from a preferred decade.
  static const decadeMatchWeight = 4;

  /// Score bonus for curated (verified-good) running songs.
  static const curatedBonusWeight = 5;

  /// Computes a composite score for a candidate song.
  ///
  /// Returns an integer score (higher = better fit for the playlist).
  /// Dimensions:
  /// 1. Artist match: +10 if song artist in taste profile
  /// 2. Genre match: +6 if song genre matches taste profile genres
  /// 3. BPM match: +3 exact, +1 variant
  /// 4. Decade match: +4 if song decade matches taste profile decades
  /// 5. Curated bonus: +5 if from curated dataset
  /// 6. Artist diversity: -5 if same artist as previous song
  /// 7. Disliked artist: -15 if artist is disliked
  static int score({
    required BpmSong song,
    TasteProfile? tasteProfile,
    String? previousArtist,
    List<RunningGenre>? songGenres,
    bool isCurated = false,
  }) {
    var total = 0;

    total += _artistMatchScore(song, tasteProfile);
    total += _dislikedArtistScore(song, tasteProfile);
    total += _genreMatchScore(songGenres, tasteProfile);
    total += _bpmMatchScore(song, tasteProfile);
    total += _artistDiversityScore(song, previousArtist);
    total += _curatedBonus(isCurated);
    total += _decadeMatchScore(song.decade, tasteProfile);

    return total;
  }

  /// Reorders a ranked list so no two consecutive songs share the same artist.
  ///
  /// Walks through the list and when a consecutive duplicate artist is found,
  /// swaps it with the next song that has a different artist. If no swap
  /// candidate exists (all remaining songs are the same artist), leaves as-is.
  /// Preserves relative ranking as much as possible.
  static List<T> enforceArtistDiversity<T>(
    List<T> rankedSongs,
    String Function(T) getArtist,
  ) {
    if (rankedSongs.length <= 1) return List<T>.from(rankedSongs);

    final result = List<T>.from(rankedSongs);

    for (var i = 1; i < result.length; i++) {
      if (getArtist(result[i]).toLowerCase() ==
          getArtist(result[i - 1]).toLowerCase()) {
        // Find the next song with a different artist
        var swapIndex = -1;
        for (var j = i + 1; j < result.length; j++) {
          if (getArtist(result[j]).toLowerCase() !=
              getArtist(result[i]).toLowerCase()) {
            swapIndex = j;
            break;
          }
        }
        if (swapIndex != -1) {
          final temp = result[i];
          result[i] = result[swapIndex];
          result[swapIndex] = temp;
        }
      }
    }

    return result;
  }

  // ── Private scoring helpers ──

  /// Artist match: +10 if song artist matches any taste profile artist.
  /// Case-insensitive substring match (bidirectional).
  static int _artistMatchScore(BpmSong song, TasteProfile? tasteProfile) {
    if (tasteProfile == null || tasteProfile.artists.isEmpty) return 0;

    final songArtistLower = song.artistName.toLowerCase();
    final profileArtistsLower =
        tasteProfile.artists.map((a) => a.toLowerCase()).toList();

    if (profileArtistsLower.any(
      (a) => songArtistLower.contains(a) || a.contains(songArtistLower),
    )) {
      return artistMatchWeight;
    }

    return 0;
  }

  /// Genre match: +6 if any song genre matches any taste profile genre.
  static int _genreMatchScore(
    List<RunningGenre>? songGenres,
    TasteProfile? tasteProfile,
  ) {
    if (songGenres == null || songGenres.isEmpty) return 0;
    if (tasteProfile == null || tasteProfile.genres.isEmpty) return 0;

    if (songGenres.any((g) => tasteProfile.genres.contains(g))) {
      return genreMatchWeight;
    }

    return 0;
  }

  /// Disliked artist: -15 if song artist matches any disliked artist.
  /// Case-insensitive bidirectional substring match (same as artist match).
  static int _dislikedArtistScore(BpmSong song, TasteProfile? tasteProfile) {
    if (tasteProfile == null || tasteProfile.dislikedArtists.isEmpty) return 0;

    final songArtistLower = song.artistName.toLowerCase();
    final dislikedLower =
        tasteProfile.dislikedArtists.map((a) => a.toLowerCase()).toList();

    if (dislikedLower.any(
      (a) => songArtistLower.contains(a) || a.contains(songArtistLower),
    )) {
      return dislikedArtistPenalty;
    }

    return 0;
  }

  /// BPM match: +3 for exact, variable for half-time/double-time based on
  /// [TempoVarianceTolerance]: strict=0, moderate=1, loose=2.
  static int _bpmMatchScore(BpmSong song, TasteProfile? tasteProfile) {
    if (song.matchType == BpmMatchType.exact) {
      return exactBpmWeight;
    }

    final tolerance =
        tasteProfile?.tempoVarianceTolerance ?? TempoVarianceTolerance.moderate;

    return switch (tolerance) {
      TempoVarianceTolerance.strict => 0,
      TempoVarianceTolerance.moderate => tempoVariantWeight,
      TempoVarianceTolerance.loose => looseTempoVariantWeight,
    };
  }

  /// Artist diversity: -5 if same artist as previous song.
  static int _artistDiversityScore(BpmSong song, String? previousArtist) {
    if (previousArtist == null) return 0;

    if (song.artistName.toLowerCase() == previousArtist.toLowerCase()) {
      return artistDiversityPenalty;
    }

    return 0;
  }

  /// Curated bonus: +5 if the song is from the curated running songs dataset.
  static int _curatedBonus(bool isCurated) =>
      isCurated ? curatedBonusWeight : 0;

  /// Decade match: +4 if song decade matches any preferred decade.
  static int _decadeMatchScore(
    String? songDecade,
    TasteProfile? tasteProfile,
  ) {
    if (songDecade == null) return 0;
    if (tasteProfile == null || tasteProfile.decades.isEmpty) return 0;

    if (tasteProfile.decades.any((d) => d.jsonValue == songDecade)) {
      return decadeMatchWeight;
    }

    return 0;
  }
}
