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

/// The user's running music taste preferences.
///
/// Stores genre preferences (1-5 from [RunningGenre]), favorite artists
/// (0-10 strings), and an [EnergyLevel] preference. Persisted as a single
/// JSON blob via SharedPreferences.
class TasteProfile {
  const TasteProfile({
    this.genres = const [],
    this.artists = const [],
    this.energyLevel = EnergyLevel.balanced,
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
    );
  }

  /// Selected running genres (1-5).
  final List<RunningGenre> genres;

  /// Favorite running artists (0-10).
  final List<String> artists;

  /// Preferred energy level for playlists.
  final EnergyLevel energyLevel;

  Map<String, dynamic> toJson() => {
        'genres': genres.map((g) => g.name).toList(),
        'artists': artists,
        'energyLevel': energyLevel.name,
      };

  TasteProfile copyWith({
    List<RunningGenre>? genres,
    List<String>? artists,
    EnergyLevel? energyLevel,
  }) {
    return TasteProfile(
      genres: genres ?? this.genres,
      artists: artists ?? this.artists,
      energyLevel: energyLevel ?? this.energyLevel,
    );
  }
}
