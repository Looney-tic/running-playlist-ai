/// Pure Dart domain model for taste learning suggestions. No Flutter dependencies.
///
/// [TasteSuggestion] represents an actionable profile change detected by
/// [TastePatternAnalyzer] from the user's song feedback patterns.
library;

/// The type of taste profile change suggested.
enum SuggestionType {
  /// Suggest adding a genre to the user's preferred genres.
  addGenre,

  /// Suggest adding an artist to the user's favorite artists.
  addArtist,

  /// Suggest adding an artist to the user's disliked/blocked list.
  removeArtist,
}

/// A suggested change to the user's taste profile based on feedback patterns.
///
/// Each suggestion has a deterministic [id] based on type and value,
/// enabling stable tracking of dismissed suggestions across sessions.
class TasteSuggestion {
  const TasteSuggestion({
    required this.type,
    required this.displayText,
    required this.value,
    required this.confidence,
    required this.evidenceCount,
  });

  /// The kind of profile change suggested.
  final SuggestionType type;

  /// Human-readable prompt for the user (e.g., "Add Hip-Hop to your genres?").
  final String displayText;

  /// The raw value to apply (e.g., "hipHop" genre enum name or "Eminem" artist).
  final String value;

  /// Confidence score from 0.0 to 1.0 based on evidence ratio.
  final double confidence;

  /// Number of feedback entries supporting this suggestion.
  final int evidenceCount;

  /// Deterministic ID for stable dismissed-set keying.
  ///
  /// Format: `'type.name:value'` (e.g., `'addGenre:rock'`, `'addArtist:Eminem'`).
  String get id => '${type.name}:$value';
}
