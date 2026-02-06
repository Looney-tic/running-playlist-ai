/// Pure Dart domain model for BPM song data. No Flutter dependencies.
///
/// A [BpmSong] represents a song discovered from the GetSongBPM API.
/// [BpmMatchType] indicates how the song's tempo relates to the target cadence.
library;

/// How a song's BPM relates to the target cadence.
enum BpmMatchType {
  /// Song tempo directly matches target BPM.
  exact,

  /// Song is at half the target BPM (e.g., 85 BPM song for 170 cadence).
  halfTime,

  /// Song is at double the target BPM (e.g., 340 BPM song for 170 cadence).
  doubleTime;

  /// Deserializes from a JSON string (enum name).
  static BpmMatchType fromJson(String name) =>
      BpmMatchType.values.firstWhere((e) => e.name == name);
}

/// A song discovered from the GetSongBPM API.
class BpmSong {
  const BpmSong({
    required this.songId,
    required this.title,
    required this.artistName,
    required this.tempo,
    this.songUri,
    this.artistUri,
    this.albumTitle,
    this.matchType = BpmMatchType.exact,
    this.genre,
    this.decade,
    this.durationSeconds,
    this.danceability,
  });

  /// Deserializes from our local JSON format (cache / persistence).
  factory BpmSong.fromJson(Map<String, dynamic> json) {
    return BpmSong(
      songId: json['songId'] as String,
      title: json['title'] as String,
      artistName: json['artistName'] as String,
      tempo: (json['tempo'] as num).toInt(),
      songUri: json['songUri'] as String?,
      artistUri: json['artistUri'] as String?,
      albumTitle: json['albumTitle'] as String?,
      matchType: json['matchType'] != null
          ? BpmMatchType.fromJson(json['matchType'] as String)
          : BpmMatchType.exact,
      genre: json['genre'] as String?,
      decade: json['decade'] as String?,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      danceability: (json['danceability'] as num?)?.toInt(),
    );
  }

  /// Parses from the GetSongBPM API `/tempo/` endpoint response item.
  ///
  /// The API uses `song_id`, `song_title`, and nests artist/album as objects.
  /// The `tempo` field comes back as a **string** (e.g., `"170"`).
  factory BpmSong.fromApiJson(
    Map<String, dynamic> json, {
    BpmMatchType matchType = BpmMatchType.exact,
  }) {
    final artist = json['artist'] as Map<String, dynamic>? ?? {};
    final album = json['album'] as Map<String, dynamic>?;
    return BpmSong(
      songId: json['song_id'] as String? ?? '',
      title: json['song_title'] as String? ?? '',
      artistName: artist['name'] as String? ?? '',
      tempo: int.tryParse(json['tempo']?.toString() ?? '') ?? 0,
      songUri: json['song_uri'] as String?,
      artistUri: artist['uri'] as String?,
      albumTitle: album?['title'] as String?,
      matchType: matchType,
      danceability:
          int.tryParse(json['danceability']?.toString() ?? ''),
    );
  }

  final String songId;
  final String title;
  final String artistName;
  final int tempo;
  final String? songUri;
  final String? artistUri;
  final String? albumTitle;
  final BpmMatchType matchType;

  /// Optional genre identifier (matches RunningGenre enum names).
  ///
  /// Populated from curated songs dataset. Null for API-sourced songs.
  final String? genre;

  /// Optional release decade (e.g., "1980s", "2010s").
  ///
  /// Populated from curated songs dataset. Null for API-sourced songs.
  final String? decade;

  /// Song duration in seconds. Null for API-sourced songs.
  final int? durationSeconds;

  /// Danceability score (0-100) from the API or curated dataset.
  ///
  /// Higher values indicate stronger, more regular rhythm — a key
  /// predictor of running suitability per Karageorghis research.
  /// Null when the data source does not provide this field.
  final int? danceability;

  /// Serializes to our local JSON format for cache / persistence.
  ///
  /// Note: [matchType] is intentionally **excluded** from the serialized
  /// output. Match type is contextual -- it depends on the relationship
  /// between this song's BPM and the *current* target BPM. Storing it
  /// would cause cache key collisions (see RESEARCH.md Pitfall 5).
  /// Match type is assigned at load time by the lookup notifier.
  Map<String, dynamic> toJson() => {
        'songId': songId,
        'title': title,
        'artistName': artistName,
        'tempo': tempo,
        'songUri': songUri,
        'artistUri': artistUri,
        'albumTitle': albumTitle,
        if (genre != null) 'genre': genre,
        if (decade != null) 'decade': decade,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
        if (danceability != null) 'danceability': danceability,
      };

  /// Creates a copy with a different [matchType].
  BpmSong withMatchType(BpmMatchType type) => BpmSong(
        songId: songId,
        title: title,
        artistName: artistName,
        tempo: tempo,
        songUri: songUri,
        artistUri: artistUri,
        albumTitle: albumTitle,
        matchType: type,
        genre: genre,
        decade: decade,
        durationSeconds: durationSeconds,
        danceability: danceability,
      );
}
