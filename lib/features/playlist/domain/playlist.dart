/// Pure Dart domain models for generated playlists. No Flutter dependencies.
///
/// A [Playlist] contains a list of [PlaylistSong]s assigned to run
/// segments. Each song has external play links (Spotify, YouTube Music)
/// and segment metadata.
library;

import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_song.dart';

/// A song assigned to a specific run segment in the playlist.
class PlaylistSong {
  const PlaylistSong({
    required this.title,
    required this.artistName,
    required this.bpm,
    required this.matchType,
    required this.segmentLabel,
    required this.segmentIndex,
    this.songUri,
    this.spotifyUrl,
    this.youtubeUrl,
    this.runningQuality,
    this.isEnriched = false,
  });

  factory PlaylistSong.fromJson(Map<String, dynamic> json) {
    return PlaylistSong(
      title: json['title'] as String,
      artistName: json['artistName'] as String,
      bpm: (json['bpm'] as num).toInt(),
      matchType: BpmMatchType.fromJson(json['matchType'] as String),
      segmentLabel: json['segmentLabel'] as String,
      segmentIndex: (json['segmentIndex'] as num).toInt(),
      songUri: json['songUri'] as String?,
      spotifyUrl: json['spotifyUrl'] as String?,
      youtubeUrl: json['youtubeUrl'] as String?,
      runningQuality: (json['runningQuality'] as num?)?.toInt(),
      isEnriched: json['isEnriched'] as bool? ?? false,
    );
  }

  final String title;
  final String artistName;
  final int bpm;
  final BpmMatchType matchType;
  final String segmentLabel;
  final int segmentIndex;
  final String? songUri;
  final String? spotifyUrl;
  final String? youtubeUrl;

  /// Composite running quality score (1-31 range) from SongQualityScorer.
  ///
  /// Null for playlists generated before quality scoring was introduced.
  final int? runningQuality;

  /// Whether danceability data was available during quality scoring.
  ///
  /// True means the score includes real danceability data; false means
  /// the score used neutral defaults.
  final bool isEnriched;

  Map<String, dynamic> toJson() => {
        'title': title,
        'artistName': artistName,
        'bpm': bpm,
        'matchType': matchType.name,
        'segmentLabel': segmentLabel,
        'segmentIndex': segmentIndex,
        'songUri': songUri,
        'spotifyUrl': spotifyUrl,
        'youtubeUrl': youtubeUrl,
        if (runningQuality != null) 'runningQuality': runningQuality,
        if (isEnriched) 'isEnriched': isEnriched,
      };
}

/// A complete generated playlist.
class Playlist {
  const Playlist({
    required this.songs,
    required this.totalDurationSeconds,
    required this.createdAt,
    this.id,
    this.runPlanName,
    this.distanceKm,
    this.paceMinPerKm,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String?,
      songs: (json['songs'] as List<dynamic>)
          .map((s) => PlaylistSong.fromJson(s as Map<String, dynamic>))
          .toList(),
      totalDurationSeconds: (json['totalDurationSeconds'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      runPlanName: json['runPlanName'] as String?,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      paceMinPerKm: (json['paceMinPerKm'] as num?)?.toDouble(),
    );
  }

  final String? id;
  final List<PlaylistSong> songs;
  final String? runPlanName;
  final int totalDurationSeconds;
  final DateTime createdAt;
  final double? distanceKm;
  final double? paceMinPerKm;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'songs': songs.map((s) => s.toJson()).toList(),
        'totalDurationSeconds': totalDurationSeconds,
        'createdAt': createdAt.toIso8601String(),
        'runPlanName': runPlanName,
        if (distanceKm != null) 'distanceKm': distanceKm,
        if (paceMinPerKm != null) 'paceMinPerKm': paceMinPerKm,
      };

  /// Formats the playlist as copyable text for clipboard (PLAY-14).
  ///
  /// Groups songs by segment with headers. Each song line includes
  /// title, artist, and BPM.
  ///
  /// ```text
  /// Running Playlist - My 5K
  /// Generated: 2026-02-05 14:30
  ///
  /// --- Warm-up ---
  /// Lose Yourself - Eminem (170 BPM)
  /// Eye of the Tiger - Survivor (168 BPM)
  /// ```
  String toClipboardText() {
    final buffer = StringBuffer()
      ..writeln('Running Playlist - ${runPlanName ?? "My Run"}')
      ..writeln(
        'Generated: '
        '${createdAt.toLocal().toString().substring(0, 16)}',
      )
      ..writeln();

    String? currentSegment;
    for (final song in songs) {
      if (song.segmentLabel != currentSegment) {
        currentSegment = song.segmentLabel;
        buffer.writeln('--- $currentSegment ---');
      }
      buffer.writeln(
        '${song.title} - ${song.artistName} (${song.bpm} BPM)',
      );
    }
    return buffer.toString();
  }
}
