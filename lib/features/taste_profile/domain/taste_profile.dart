/// Pure Dart domain model for taste profiles. No Flutter dependencies.
library;

/// Energy level preference for running music.
enum EnergyLevel {
  chill,
  balanced,
  intense;

  /// Deserializes from a JSON string (enum name).
  ///
  /// Falls back to [balanced] for unknown values, so a newer app version's
  /// data doesn't crash an older version.
  static EnergyLevel fromJson(String name) =>
      EnergyLevel.values.firstWhere(
        (e) => e.name == name,
        orElse: () => EnergyLevel.balanced,
      );
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
  ///
  /// Falls back to [pop] for unknown values. Prefer [tryFromJson] when
  /// building lists where unknown values should be silently dropped.
  static RunningGenre fromJson(String name) =>
      RunningGenre.values.firstWhere(
        (e) => e.name == name,
        orElse: () => RunningGenre.pop,
      );

  /// Returns the matching genre or `null` for unknown values.
  ///
  /// Used when parsing genre lists so unknown values from future app
  /// versions are silently dropped rather than mapped to a fallback.
  static RunningGenre? tryFromJson(String name) {
    for (final genre in RunningGenre.values) {
      if (genre.name == name) return genre;
    }
    return null;
  }
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

/// Preferred music decade for running playlists.
enum MusicDecade {
  the1960s('60s'),
  the1970s('70s'),
  the1980s('80s'),
  the1990s('90s'),
  the2000s('2000s'),
  the2010s('2010s'),
  the2020s('2020s');

  const MusicDecade(this.displayName);

  /// Human-readable name for UI display.
  final String displayName;

  /// The string value stored in curated songs JSON (e.g., "1980s").
  String get jsonValue => switch (this) {
        MusicDecade.the1960s => '1960s',
        MusicDecade.the1970s => '1970s',
        MusicDecade.the1980s => '1980s',
        MusicDecade.the1990s => '1990s',
        MusicDecade.the2000s => '2000s',
        MusicDecade.the2010s => '2010s',
        MusicDecade.the2020s => '2020s',
      };

  /// Deserializes from a JSON string (enum name).
  ///
  /// Falls back to [the2010s] for unknown values.
  static MusicDecade fromJson(String name) =>
      MusicDecade.values.firstWhere(
        (e) => e.name == name,
        orElse: () => MusicDecade.the2010s,
      );

  /// Returns the matching decade or `null` for unknown values.
  ///
  /// Used when parsing decade lists so unknown values from future app
  /// versions are silently dropped rather than mapped to a fallback.
  static MusicDecade? tryFromJson(String name) {
    for (final decade in MusicDecade.values) {
      if (decade.name == name) return decade;
    }
    return null;
  }
}

/// The user's running music taste preferences.
///
/// Stores genre preferences (1-5 from [RunningGenre]), favorite artists
/// (0-10 strings), an [EnergyLevel] preference, a [VocalPreference],
/// a [TempoVarianceTolerance], and disliked artists. Persisted as a single
/// JSON blob via SharedPreferences.
class TasteProfile {
  TasteProfile({
    this.genres = const [],
    this.artists = const [],
    this.energyLevel = EnergyLevel.balanced,
    this.vocalPreference = VocalPreference.noPreference,
    this.tempoVarianceTolerance = TempoVarianceTolerance.moderate,
    this.dislikedArtists = const [],
    this.decades = const [],
    this.name,
    String? id,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  factory TasteProfile.fromJson(Map<String, dynamic> json) {
    return TasteProfile(
      id: json['id'] as String?,
      name: json['name'] as String?,
      genres: (json['genres'] as List<dynamic>)
          .map((g) => RunningGenre.tryFromJson(g as String))
          .whereType<RunningGenre>()
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
      decades: (json['decades'] as List<dynamic>?)
              ?.map((d) => MusicDecade.tryFromJson(d as String))
              .whereType<MusicDecade>()
              .toList() ??
          const [],
    );
  }

  final String id;

  /// Optional user-given name for the profile.
  final String? name;

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

  /// Preferred music decades (empty means no preference).
  final List<MusicDecade> decades;

  Map<String, dynamic> toJson() => {
        'id': id,
        if (name != null) 'name': name,
        'genres': genres.map((g) => g.name).toList(),
        'artists': artists,
        'energyLevel': energyLevel.name,
        'vocalPreference': vocalPreference.name,
        'tempoVarianceTolerance': tempoVarianceTolerance.name,
        'dislikedArtists': dislikedArtists,
        'decades': decades.map((d) => d.name).toList(),
      };

  TasteProfile copyWith({
    String? id,
    String? name,
    List<RunningGenre>? genres,
    List<String>? artists,
    EnergyLevel? energyLevel,
    VocalPreference? vocalPreference,
    TempoVarianceTolerance? tempoVarianceTolerance,
    List<String>? dislikedArtists,
    List<MusicDecade>? decades,
  }) {
    return TasteProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      genres: genres ?? this.genres,
      artists: artists ?? this.artists,
      energyLevel: energyLevel ?? this.energyLevel,
      vocalPreference: vocalPreference ?? this.vocalPreference,
      tempoVarianceTolerance:
          tempoVarianceTolerance ?? this.tempoVarianceTolerance,
      dislikedArtists: dislikedArtists ?? this.dislikedArtists,
      decades: decades ?? this.decades,
    );
  }
}
