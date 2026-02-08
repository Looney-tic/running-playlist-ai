/// Pure Dart taste pattern analyzer. No Flutter dependencies.
///
/// Analyzes song feedback to detect genre, artist, and disliked-artist
/// patterns that can be suggested as taste profile changes.
library;

import 'package:running_playlist_ai/features/song_feedback/domain/song_feedback.dart';
import 'package:running_playlist_ai/features/taste_learning/domain/taste_suggestion.dart';
import 'package:running_playlist_ai/features/taste_profile/domain/taste_profile.dart';

/// Detects taste patterns from song feedback and produces suggestions.
///
/// This is a pure function class -- all inputs are provided explicitly,
/// no side effects, no Flutter imports. Makes testing straightforward.
class TastePatternAnalyzer {
  TastePatternAnalyzer._();

  /// Minimum liked songs with genre data required before genre analysis runs.
  static const _minGenreDataCount = 5;

  /// Minimum count of liked songs in a genre to suggest it.
  static const _minGenreCount = 3;

  /// Minimum ratio of liked songs in a genre (as fraction of total with genre data).
  static const _minGenreRatio = 0.30;

  /// Minimum liked songs by an artist to suggest adding them.
  static const _minArtistLikedCount = 2;

  /// Minimum disliked songs by an artist to suggest blocking them.
  static const _minArtistDislikedCount = 2;

  /// Evidence count delta required for a dismissed suggestion to resurface.
  static const _dismissedDelta = 3;

  /// Maximum number of suggestions returned.
  static const _maxSuggestions = 3;

  /// Analyzes feedback to produce taste suggestions.
  ///
  /// - [feedback]: All song feedback entries keyed by song key.
  /// - [curatedGenreLookup]: Maps song lookup keys to genre enum names
  ///   from the curated dataset, providing genre enrichment for feedback
  ///   entries that lack genre data.
  /// - [activeProfile]: Current taste profile; existing preferences are
  ///   excluded from suggestions.
  /// - [dismissedSuggestions]: Maps suggestion IDs to the evidence count
  ///   at the time of dismissal. Suggestions only resurface when evidence
  ///   grows by +3 or more.
  ///
  /// Returns up to 3 suggestions sorted by evidence count descending.
  static List<TasteSuggestion> analyze({
    required Map<String, SongFeedback> feedback,
    required Map<String, String> curatedGenreLookup,
    required TasteProfile activeProfile,
    required Map<String, int> dismissedSuggestions,
  }) {
    if (feedback.isEmpty) return [];

    final candidates = <TasteSuggestion>[];

    // Separate liked and disliked feedback entries
    final liked = feedback.values.where((f) => f.isLiked).toList();
    final disliked = feedback.values.where((f) => !f.isLiked).toList();

    // a) Genre analysis via curated metadata enrichment
    candidates.addAll(_analyzeGenres(
      liked: liked,
      curatedGenreLookup: curatedGenreLookup,
      activeProfile: activeProfile,
    ));

    // b) Liked artist analysis
    candidates.addAll(_analyzeLikedArtists(
      liked: liked,
      activeProfile: activeProfile,
    ));

    // c) Disliked artist analysis
    candidates.addAll(_analyzeDislikedArtists(
      disliked: disliked,
      activeProfile: activeProfile,
    ));

    // d) Filter dismissed suggestions by evidence delta
    final filtered = candidates.where((s) {
      final dismissedAt = dismissedSuggestions[s.id];
      if (dismissedAt == null) return true;
      return s.evidenceCount >= dismissedAt + _dismissedDelta;
    }).toList();

    // e) Sort by evidence count descending, cap at 3
    filtered.sort((a, b) => b.evidenceCount.compareTo(a.evidenceCount));
    return filtered.take(_maxSuggestions).toList();
  }

  /// Analyzes genre patterns in liked songs using curated metadata enrichment.
  static List<TasteSuggestion> _analyzeGenres({
    required List<SongFeedback> liked,
    required Map<String, String> curatedGenreLookup,
    required TasteProfile activeProfile,
  }) {
    final suggestions = <TasteSuggestion>[];

    // Count genre frequencies from curated lookup
    final genreCounts = <String, int>{};
    var totalLikedWithGenre = 0;

    for (final entry in liked) {
      final genre = curatedGenreLookup[entry.songKey];
      if (genre == null) continue; // Skip API-only songs
      totalLikedWithGenre++;
      genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
    }

    // Require minimum total liked songs with genre data
    if (totalLikedWithGenre < _minGenreDataCount) return suggestions;

    // Existing genre names from profile for exclusion
    final existingGenreNames =
        activeProfile.genres.map((g) => g.name).toSet();

    for (final entry in genreCounts.entries) {
      final genreName = entry.key;
      final count = entry.value;

      // Skip genres already in profile
      if (existingGenreNames.contains(genreName)) continue;

      // Check thresholds
      final ratio = count / totalLikedWithGenre;
      if (count < _minGenreCount || ratio < _minGenreRatio) continue;

      // Resolve display name from RunningGenre enum
      final genre = RunningGenre.tryFromJson(genreName);
      final displayName = genre?.displayName ?? genreName;

      suggestions.add(TasteSuggestion(
        type: SuggestionType.addGenre,
        displayText: 'Add $displayName to your genres?',
        value: genreName,
        confidence: ratio,
        evidenceCount: count,
      ));
    }

    return suggestions;
  }

  /// Analyzes liked artist patterns.
  static List<TasteSuggestion> _analyzeLikedArtists({
    required List<SongFeedback> liked,
    required TasteProfile activeProfile,
  }) {
    final suggestions = <TasteSuggestion>[];
    if (liked.isEmpty) return suggestions;

    // Count by artist (preserve display case from first occurrence)
    final artistCounts = <String, int>{};
    final artistDisplayNames = <String, String>{};

    for (final entry in liked) {
      final lowerArtist = entry.songArtist.toLowerCase();
      artistCounts[lowerArtist] = (artistCounts[lowerArtist] ?? 0) + 1;
      artistDisplayNames.putIfAbsent(lowerArtist, () => entry.songArtist);
    }

    // Existing artists from profile (case-insensitive)
    final existingArtists =
        activeProfile.artists.map((a) => a.toLowerCase()).toSet();

    for (final entry in artistCounts.entries) {
      final lowerArtist = entry.key;
      final count = entry.value;

      // Skip artists already in profile
      if (existingArtists.contains(lowerArtist)) continue;

      // Check threshold
      if (count < _minArtistLikedCount) continue;

      final displayName = artistDisplayNames[lowerArtist]!;
      suggestions.add(TasteSuggestion(
        type: SuggestionType.addArtist,
        displayText: 'Add $displayName to your favorites?',
        value: displayName,
        confidence: count / liked.length,
        evidenceCount: count,
      ));
    }

    return suggestions;
  }

  /// Analyzes disliked artist patterns.
  static List<TasteSuggestion> _analyzeDislikedArtists({
    required List<SongFeedback> disliked,
    required TasteProfile activeProfile,
  }) {
    final suggestions = <TasteSuggestion>[];
    if (disliked.isEmpty) return suggestions;

    // Count by artist (preserve display case from first occurrence)
    final artistCounts = <String, int>{};
    final artistDisplayNames = <String, String>{};

    for (final entry in disliked) {
      final lowerArtist = entry.songArtist.toLowerCase();
      artistCounts[lowerArtist] = (artistCounts[lowerArtist] ?? 0) + 1;
      artistDisplayNames.putIfAbsent(lowerArtist, () => entry.songArtist);
    }

    // Existing disliked artists from profile (case-insensitive)
    final existingDisliked =
        activeProfile.dislikedArtists.map((a) => a.toLowerCase()).toSet();

    for (final entry in artistCounts.entries) {
      final lowerArtist = entry.key;
      final count = entry.value;

      // Skip artists already in disliked list
      if (existingDisliked.contains(lowerArtist)) continue;

      // Check threshold
      if (count < _minArtistDislikedCount) continue;

      final displayName = artistDisplayNames[lowerArtist]!;
      suggestions.add(TasteSuggestion(
        type: SuggestionType.removeArtist,
        displayText: 'Block $displayName from playlists?',
        value: displayName,
        confidence: count / disliked.length,
        evidenceCount: count,
      ));
    }

    return suggestions;
  }
}
