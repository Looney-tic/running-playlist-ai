/// Pure Dart domain model for taste profiles. No Flutter dependencies.
library;

/// Energy level preference for running music.
enum EnergyLevel {
  chill,
  balanced,
  intense;

  /// Deserializes from a JSON string (enum name).
  static EnergyLevel fromJson(String name) =>
      EnergyLevel.values.firstWhere((e) => e.name == name);
}

/// Curated list of 15 running-relevant music genres.
///
/// Identifiers align with Spotify genre seed slugs for future API integration.
enum RunningGenre {
  pop('Pop'),
  hipHop('Hip-Hop / Rap'),
  electronic('Electronic'),
  edm('EDM'),
  rock('Rock'),
  indie('Indie'),
  dance('Dance'),
  house('House'),
  drumAndBass('Drum & Bass'),
  rnb('R&B / Soul'),
  latin('Latin / Reggaeton'),
  metal('Metal'),
  punk('Punk Rock'),
  funk('Funk / Disco'),
  kPop('K-Pop');

  const RunningGenre(this.displayName);

  /// Human-readable name for UI display.
  final String displayName;

  /// Deserializes from a JSON string (enum name).
  static RunningGenre fromJson(String name) =>
      RunningGenre.values.firstWhere((e) => e.name == name);
}

/// Vocal vs instrumental preference for running music.
enum VocalPreference {
  noPreference,
  preferVocals,
  preferInstrumental;

  /// Deserializes from a JSON string with fallback to [noPreference].
  static VocalPreference fromJson(String name) =>
      VocalPreference.values.firstWhere(
        (e) => e.name == name,
        orElse: () => VocalPreference.noPreference,
      );
}

/// How strictly BPM must match the target cadence.
///
/// Controls scoring of half-time / double-time variants:
/// - [strict]: only exact BPM matches score
/// - [moderate]: variants score at reduced weight (default)
/// - [loose]: variants score close to exact matches
enum TempoVarianceTolerance {
  strict,
  moderate,
  loose;

  /// Deserializes from a JSON string with fallback to [moderate].
  static TempoVarianceTolerance fromJson(String name) =>
      TempoVarianceTolerance.values.firstWhere(
        (e) => e.name == name,
        orElse: () => TempoVarianceTolerance.moderate,
      );
}

/// The user's running music taste preferences.
///
/// Stores genre preferences (1-5 from [RunningGenre]), favorite artists
/// (0-10 strings), an [EnergyLevel] preference, a [VocalPreference],
/// a [TempoVarianceTolerance], and disliked artists. Persisted as a single
/// JSON blob via SharedPreferences.
class TasteProfile {
  const TasteProfile({
    this.genres = const [],
    this.artists = const [],
    this.energyLevel = EnergyLevel.balanced,
    this.vocalPreference = VocalPreference.noPreference,
    this.tempoVarianceTolerance = TempoVarianceTolerance.moderate,
    this.dislikedArtists = const [],
  });

  factory TasteProfile.fromJson(Map<String, dynamic> json) {
    return TasteProfile(
      genres: (json['genres'] as List<dynamic>)
          .map((g) => RunningGenre.fromJson(g as String))
          .toList(),
      artists: (json['artists'] as List<dynamic>)
          .map((a) => a as String)
          .toList(),
      energyLevel: EnergyLevel.fromJson(json['energyLevel'] as String),
      vocalPreference: json['vocalPreference'] != null
          ? VocalPreference.fromJson(json['vocalPreference'] as String)
          : VocalPreference.noPreference,
      tempoVarianceTolerance: json['tempoVarianceTolerance'] != null
          ? TempoVarianceTolerance.fromJson(
              json['tempoVarianceTolerance'] as String)
          : TempoVarianceTolerance.moderate,
      dislikedArtists: (json['dislikedArtists'] as List<dynamic>?)
              ?.map((a) => a as String)
              .toList() ??
          const [],
    );
  }

  /// Selected running genres (1-5).
  final List<RunningGenre> genres;

  /// Favorite running artists (0-10).
  final List<String> artists;

  /// Preferred energy level for playlists.
  final EnergyLevel energyLevel;

  /// Vocal vs instrumental preference.
  final VocalPreference vocalPreference;

  /// How strictly BPM must match the target cadence.
  final TempoVarianceTolerance tempoVarianceTolerance;

  /// Artists the user wants to avoid in playlists.
  final List<String> dislikedArtists;

  Map<String, dynamic> toJson() => {
        'genres': genres.map((g) => g.name).toList(),
        'artists': artists,
        'energyLevel': energyLevel.name,
        'vocalPreference': vocalPreference.name,
        'tempoVarianceTolerance': tempoVarianceTolerance.name,
        'dislikedArtists': dislikedArtists,
      };

  TasteProfile copyWith({
    List<RunningGenre>? genres,
    List<String>? artists,
    EnergyLevel? energyLevel,
    VocalPreference? vocalPreference,
    TempoVarianceTolerance? tempoVarianceTolerance,
    List<String>? dislikedArtists,
  }) {
    return TasteProfile(
      genres: genres ?? this.genres,
      artists: artists ?? this.artists,
      energyLevel: energyLevel ?? this.energyLevel,
      vocalPreference: vocalPreference ?? this.vocalPreference,
      tempoVarianceTolerance:
          tempoVarianceTolerance ?? this.tempoVarianceTolerance,
      dislikedArtists: dislikedArtists ?? this.dislikedArtists,
    );
  }
}
