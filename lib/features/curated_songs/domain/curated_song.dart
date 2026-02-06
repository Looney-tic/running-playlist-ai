/// Pure Dart domain model for curated running songs. No Flutter dependencies.
///
/// A [CuratedSong] represents a verified-good running song from the
/// curated dataset. It can be deserialized from both bundled JSON assets
/// (camelCase) and Supabase table rows (snake_case).
library;

/// A curated running song verified as good for running.
///
/// Contains genre, BPM, and optional danceability/energy metadata.
/// The [lookupKey] getter produces a normalized identifier for
/// cross-source matching against [BpmSong] candidates during scoring.
class CuratedSong {
  const CuratedSong({
    required this.title,
    required this.artistName,
    required this.genre,
    required this.bpm,
    this.danceability,
    this.energyLevel,
  });

  /// Deserializes from camelCase JSON (bundled asset format).
  factory CuratedSong.fromJson(Map<String, dynamic> json) {
    return CuratedSong(
      title: json['title'] as String,
      artistName: json['artistName'] as String,
      genre: json['genre'] as String,
      bpm: (json['bpm'] as num).toInt(),
      danceability: (json['danceability'] as num?)?.toInt(),
      energyLevel: json['energyLevel'] as String?,
    );
  }

  /// Deserializes from snake_case Supabase table row.
  factory CuratedSong.fromSupabaseRow(Map<String, dynamic> row) {
    return CuratedSong(
      title: row['title'] as String,
      artistName: row['artist_name'] as String,
      genre: row['genre'] as String,
      bpm: (row['bpm'] as num).toInt(),
      danceability: (row['danceability'] as num?)?.toInt(),
      energyLevel: row['energy_level'] as String?,
    );
  }

  /// Song title.
  final String title;

  /// Artist name.
  final String artistName;

  /// Genre identifier (matches RunningGenre enum names).
  final String genre;

  /// Song tempo in beats per minute.
  final int bpm;

  /// Optional danceability score (0-100).
  final int? danceability;

  /// Optional energy level label ('chill', 'balanced', 'intense').
  final String? energyLevel;

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
        'bpm': bpm,
        if (danceability != null) 'danceability': danceability,
        if (energyLevel != null) 'energyLevel': energyLevel,
      };
}
