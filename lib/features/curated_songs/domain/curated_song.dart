/// Pure Dart domain model for curated running songs. No Flutter dependencies.
///
/// A [CuratedSong] represents a verified-good running song from the
/// curated dataset. It can be deserialized from both bundled JSON assets
/// (camelCase) and Supabase table rows (snake_case).
library;

/// A curated running song verified as good for running.
///
/// Contains genre, BPM, and release decade metadata. BPM is nullable
/// because some songs lack verified BPM data from Deezer.
/// The [lookupKey] getter produces a normalized identifier for
/// cross-source matching against [BpmSong] candidates during scoring.
class CuratedSong {
  const CuratedSong({
    required this.title,
    required this.artistName,
    required this.genre,
    this.bpm,
    this.decade,
    this.durationSeconds,
  });

  /// Deserializes from camelCase JSON (bundled asset format).
  factory CuratedSong.fromJson(Map<String, dynamic> json) {
    return CuratedSong(
      title: json['title'] as String,
      artistName: json['artistName'] as String,
      genre: json['genre'] as String,
      bpm: (json['bpm'] as num?)?.toInt(),
      decade: json['decade'] as String?,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
    );
  }

  /// Deserializes from snake_case Supabase table row.
  factory CuratedSong.fromSupabaseRow(Map<String, dynamic> row) {
    return CuratedSong(
      title: row['title'] as String,
      artistName: row['artist_name'] as String,
      genre: row['genre'] as String,
      bpm: (row['bpm'] as num?)?.toInt(),
      decade: row['decade'] as String?,
      durationSeconds: (row['duration_seconds'] as num?)?.toInt(),
    );
  }

  /// Song title.
  final String title;

  /// Artist name.
  final String artistName;

  /// Genre identifier (matches RunningGenre enum names).
  final String genre;

  /// Song tempo in beats per minute. Null if no verified BPM data.
  final int? bpm;

  /// Optional release decade (e.g., "1980s", "2010s").
  final String? decade;

  /// Song duration in seconds.
  final int? durationSeconds;

  /// Normalized lookup key for matching against BpmSong candidates.
  ///
  /// Format: `'artist_lowercase_trimmed|title_lowercase_trimmed'`
  /// Used to build a `Set<String>` for O(1) curated status checks
  /// during playlist scoring.
  String get lookupKey =>
      '${artistName.toLowerCase().trim()}|${title.toLowerCase().trim()}';

  /// Serializes to camelCase JSON for cache persistence.
  Map<String, dynamic> toJson() => {
        'title': title,
        'artistName': artistName,
        'genre': genre,
        if (bpm != null) 'bpm': bpm,
        if (decade != null) 'decade': decade,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
      };
}
