/// Pure Dart domain model for "Songs I Run To" collection. No Flutter dependencies.
///
/// [RunningSongSource] tracks how a song was added to the collection.
/// [RunningSong] represents a song the user wants in their running playlists.
///
/// Callers must provide a pre-normalized [songKey] via [SongKey.normalize]
/// from `package:running_playlist_ai/features/song_feedback/domain/song_feedback.dart`.
library;

// ignore: unused_import -- referenced in doc comments for SongKey.normalize
import 'package:running_playlist_ai/features/song_feedback/domain/song_feedback.dart';

/// How a song was added to the "Songs I Run To" collection.
enum RunningSongSource {
  /// From the curated song database.
  curated,

  /// Imported from Spotify.
  spotify,

  /// Manually entered by the user.
  manual,
}

/// A song in the user's "Songs I Run To" collection.
///
/// Immutable value object that round-trips through JSON for
/// SharedPreferences persistence. The [songKey] field must use the
/// normalized format from [SongKey.normalize].
class RunningSong {
  const RunningSong({
    required this.songKey,
    required this.artist,
    required this.title,
    required this.addedDate,
    this.bpm,
    this.genre,
    this.source = RunningSongSource.curated,
  });

  /// Deserializes from a JSON map.
  ///
  /// Unknown [source] values fall back to [RunningSongSource.curated]
  /// for forward-compatibility with future enum additions.
  factory RunningSong.fromJson(Map<String, dynamic> json) {
    return RunningSong(
      songKey: json['songKey'] as String,
      artist: json['artist'] as String,
      title: json['title'] as String,
      addedDate: DateTime.parse(json['addedDate'] as String),
      bpm: (json['bpm'] as num?)?.toInt(),
      genre: json['genre'] as String?,
      source: RunningSongSource.values.firstWhere(
        (s) => s.name == json['source'],
        orElse: () => RunningSongSource.curated,
      ),
    );
  }

  /// Normalized lookup key (see [SongKey.normalize]).
  ///
  /// Callers must provide a pre-normalized key. This model does NOT
  /// call normalize internally.
  final String songKey;

  /// Original artist name for display purposes.
  final String artist;

  /// Original song title for display purposes.
  final String title;

  /// When the song was added to the collection.
  final DateTime addedDate;

  /// Known BPM at the time of addition, if available.
  final int? bpm;

  /// Genre identifier, if known from curated data.
  final String? genre;

  /// How this song was added to the collection.
  final RunningSongSource source;

  /// Serializes to a JSON map.
  ///
  /// The [bpm] and [genre] fields are only included when non-null
  /// to keep persisted data compact.
  Map<String, dynamic> toJson() => {
        'songKey': songKey,
        'artist': artist,
        'title': title,
        'addedDate': addedDate.toIso8601String(),
        'source': source.name,
        if (bpm != null) 'bpm': bpm,
        if (genre != null) 'genre': genre,
      };
}
