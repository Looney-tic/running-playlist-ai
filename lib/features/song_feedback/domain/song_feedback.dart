/// Pure Dart domain model for song feedback. No Flutter dependencies.
///
/// [SongKey] provides centralized song key normalization used across
/// curated data, API results, and feedback lookups. [SongFeedback]
/// represents a user's like/dislike decision on a specific song.
library;

/// Centralized song key normalization utility.
///
/// Produces deterministic lookup keys of the form
/// `'artist_lowercase_trimmed|title_lowercase_trimmed'` for consistent
/// cross-source matching between curated songs, API results, and
/// user feedback entries.
///
/// This is the **single source of truth** for song key format.
/// All code that needs to match songs across data sources must use
/// [SongKey.normalize] rather than inline normalization.
class SongKey {
  SongKey._();

  /// Produces a normalized lookup key for matching songs across sources.
  ///
  /// Example: `SongKey.normalize('  Eminem ', ' Lose Yourself ')`
  /// returns `'eminem|lose yourself'`.
  static String normalize(String artist, String title) =>
      '${artist.toLowerCase().trim()}|${title.toLowerCase().trim()}';
}

/// A user's feedback (like/dislike) on a specific song.
///
/// Immutable value object that round-trips through JSON for
/// SharedPreferences persistence. The [songKey] field uses the
/// normalized format from [SongKey.normalize].
class SongFeedback {
  const SongFeedback({
    required this.songKey,
    required this.isLiked,
    required this.feedbackDate,
    required this.songTitle,
    required this.songArtist,
    this.genre,
  });

  /// Deserializes from a JSON map.
  factory SongFeedback.fromJson(Map<String, dynamic> json) {
    return SongFeedback(
      songKey: json['songKey'] as String,
      isLiked: json['isLiked'] as bool,
      feedbackDate: DateTime.parse(json['feedbackDate'] as String),
      songTitle: json['songTitle'] as String,
      songArtist: json['songArtist'] as String,
      genre: json['genre'] as String?,
    );
  }

  /// Normalized lookup key (see [SongKey.normalize]).
  final String songKey;

  /// Whether the user liked (`true`) or disliked (`false`) this song.
  final bool isLiked;

  /// When the feedback was recorded.
  final DateTime feedbackDate;

  /// Original song title for display purposes.
  final String songTitle;

  /// Original artist name for display purposes.
  final String songArtist;

  /// Optional genre identifier for Phase 27 taste learning.
  final String? genre;

  /// Serializes to a JSON map.
  ///
  /// The [genre] field is only included when non-null to keep
  /// persisted data compact.
  Map<String, dynamic> toJson() => {
        'songKey': songKey,
        'isLiked': isLiked,
        'feedbackDate': feedbackDate.toIso8601String(),
        'songTitle': songTitle,
        'songArtist': songArtist,
        if (genre != null) 'genre': genre,
      };

  /// Creates a copy with updated fields for toggling like/dislike.
  SongFeedback copyWith({
    bool? isLiked,
    DateTime? feedbackDate,
  }) {
    return SongFeedback(
      songKey: songKey,
      isLiked: isLiked ?? this.isLiked,
      feedbackDate: feedbackDate ?? this.feedbackDate,
      songTitle: songTitle,
      songArtist: songArtist,
      genre: genre,
    );
  }
}
