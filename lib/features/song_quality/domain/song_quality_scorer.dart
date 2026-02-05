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
  // ── Weight constants (public for testability and future tuning) ──

  /// Score bonus when the song's artist matches a taste profile artist.
  static const artistMatchWeight = 10;

  /// Score bonus when the song's genre matches a taste profile genre.
  static const genreMatchWeight = 6;

  /// Maximum score from danceability (scaled from 0-100 to 0-8).
  static const danceabilityMaxWeight = 8;

  /// Neutral danceability score when danceability data is absent.
  static const danceabilityNeutral = 4;

  /// Maximum score from energy alignment (in-range).
  static const energyAlignedWeight = 4;

  /// Neutral energy alignment score when data is absent.
  static const energyNeutral = 2;

  /// Score bonus for exact BPM match.
  static const exactBpmWeight = 3;

  /// Score bonus for half-time or double-time BPM match.
  static const tempoVariantWeight = 1;

  /// Penalty for consecutive songs by the same artist.
  static const artistDiversityPenalty = -5;

  /// Computes a composite score for a candidate song.
  ///
  /// Returns an integer score (higher = better fit for the playlist).
  /// Dimensions:
  /// 1. Artist match: +10 if song artist in taste profile
  /// 2. Genre match: +6 if song genre matches taste profile genres
  /// 3. Danceability: 0-8 scaled from 0-100 (null -> 4 neutral)
  /// 4. Energy alignment: 0/2/4 based on energy preference vs danceability
  /// 5. BPM match: +3 exact, +1 variant
  /// 6. Artist diversity: -5 if same artist as previous song
  static int score({
    required BpmSong song,
    TasteProfile? tasteProfile,
    int? danceability,
    String? segmentLabel,
    String? previousArtist,
    List<RunningGenre>? songGenres,
  }) {
    var total = 0;

    total += _artistMatchScore(song, tasteProfile);
    total += _genreMatchScore(songGenres, tasteProfile);
    total += _danceabilityScore(danceability);
    total += _energyAlignmentScore(danceability, tasteProfile, segmentLabel);
    total += _bpmMatchScore(song);
    total += _artistDiversityScore(song, previousArtist);

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

  /// Danceability: scales 0-100 to 0-8. Null -> 4 (neutral midpoint).
  static int _danceabilityScore(int? danceability) {
    if (danceability == null) return danceabilityNeutral;
    return (danceability / 100 * danceabilityMaxWeight)
        .round()
        .clamp(0, danceabilityMaxWeight);
  }

  /// Energy alignment: 0/2/4 based on how danceability fits the preferred
  /// energy range. Segment labels can override the user's energy preference.
  static int _energyAlignmentScore(
    int? danceability,
    TasteProfile? tasteProfile,
    String? segmentLabel,
  ) {
    if (danceability == null) return energyNeutral;
    if (tasteProfile == null) return energyNeutral;

    final energyLevel = _resolveEnergyLevel(
      tasteProfile.energyLevel,
      segmentLabel,
    );

    final (min, max) = _energyRange(energyLevel);

    if (danceability >= min && danceability <= max) {
      return energyAlignedWeight;
    }

    // Check proximity: within 15 points of range boundary -> +2
    final distanceToRange = danceability < min
        ? min - danceability
        : danceability - max;

    if (distanceToRange <= 15) {
      return energyNeutral;
    }

    return 0;
  }

  /// Resolves the effective energy level considering segment label overrides.
  ///
  /// - "Warm-up", "Cool-down", "Rest N" -> chill
  /// - "Work N", "Sprint" -> intense
  /// - "Main", "Running", null -> user's preference
  static EnergyLevel _resolveEnergyLevel(
    EnergyLevel userPreference,
    String? segmentLabel,
  ) {
    if (segmentLabel == null) return userPreference;

    final label = segmentLabel.toLowerCase();

    if (label == 'warm-up' || label == 'cool-down') {
      return EnergyLevel.chill;
    }

    if (label.startsWith('rest')) {
      return EnergyLevel.chill;
    }

    if (label.startsWith('work') || label == 'sprint') {
      return EnergyLevel.intense;
    }

    // "Main", "Running", or any other label -> user preference
    return userPreference;
  }

  /// Maps an energy level to a preferred danceability range (min, max).
  static (int, int) _energyRange(EnergyLevel level) {
    return switch (level) {
      EnergyLevel.chill => (20, 50),
      EnergyLevel.balanced => (40, 70),
      EnergyLevel.intense => (60, 100),
    };
  }

  /// BPM match: +3 for exact, +1 for half-time or double-time.
  static int _bpmMatchScore(BpmSong song) {
    if (song.matchType == BpmMatchType.exact) {
      return exactBpmWeight;
    }
    return tempoVariantWeight;
  }

  /// Artist diversity: -5 if same artist as previous song.
  static int _artistDiversityScore(BpmSong song, String? previousArtist) {
    if (previousArtist == null) return 0;

    if (song.artistName.toLowerCase() == previousArtist.toLowerCase()) {
      return artistDiversityPenalty;
    }

    return 0;
  }
}
