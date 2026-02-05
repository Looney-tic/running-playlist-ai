/// Pure Dart playlist generation algorithm. No Flutter dependencies.
///
/// Takes a [RunPlan], [TasteProfile], and pre-fetched song pool, and
/// returns a [Playlist] with songs assigned to each run segment. All
/// async work (API calls, cache reads) must be completed before
/// calling [PlaylistGenerator.generate].
library;

import 'dart:math';

import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_matcher.dart';
import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_song.dart';
import 'package:running_playlist_ai/features/playlist/domain/playlist.dart';
import 'package:running_playlist_ai/features/playlist/domain/song_link_builder.dart';
import 'package:running_playlist_ai/features/run_plan/domain/run_plan.dart';
import 'package:running_playlist_ai/features/taste_profile/domain/taste_profile.dart';

/// Generates BPM-matched playlists from run plans and taste profiles.
///
/// The generator is a pure synchronous function. It:
/// 1. Iterates each [RunSegment] in the plan
/// 2. Finds candidate songs matching the segment's target BPM
/// 3. Scores candidates by taste profile match (artist name matching)
/// 4. Fills each segment's duration using a greedy algorithm
/// 5. Avoids repeating songs across segments
///
/// Song duration is estimated at 210 seconds (3.5 min) since the
/// GetSongBPM API does not return song duration.
class PlaylistGenerator {
  /// Estimated song duration in seconds (3.5 minutes).
  ///
  /// The GetSongBPM API does not return song duration. This fixed
  /// estimate is used to calculate how many songs are needed per
  /// segment.
  static const estimatedSongDurationSeconds = 210;

  /// Score bonus for songs by artists in the taste profile.
  static const _artistMatchScore = 10;

  /// Score bonus for exact BPM match (vs half/double-time).
  static const _exactMatchScore = 3;

  /// Score bonus for half-time or double-time match.
  static const _tempoVariantScore = 1;

  /// Generates a playlist from a run plan, taste profile, and
  /// available songs.
  ///
  /// [runPlan] defines the segments with target BPMs and durations.
  /// [tasteProfile] provides artist preferences for scoring (can be
  /// null if the user has not set up a taste profile).
  /// [songsByBpm] is a map of queried BPM -> list of BpmSong,
  /// pre-fetched from the API/cache. Keys are the raw queried BPMs
  /// (not target BPMs).
  /// [random] optional Random instance for deterministic testing.
  ///
  /// Returns a [Playlist] with songs assigned to all segments.
  /// Segments with no available songs will have zero songs in the
  /// output.
  static Playlist generate({
    required RunPlan runPlan,
    required Map<int, List<BpmSong>> songsByBpm,
    TasteProfile? tasteProfile,
    Random? random,
  }) {
    final rng = random ?? Random();
    final usedSongIds = <String>{};
    final allPlaylistSongs = <PlaylistSong>[];

    for (var i = 0; i < runPlan.segments.length; i++) {
      final segment = runPlan.segments[i];
      final segmentLabel = segment.label ?? 'Segment ${i + 1}';

      // Collect candidate songs for this segment's target BPM
      final targetBpm = segment.targetBpm.round();
      final candidates = _collectCandidates(
        targetBpm: targetBpm,
        songsByBpm: songsByBpm,
      );

      // Filter out already-used songs
      final available = candidates
          .where((s) => !usedSongIds.contains(s.songId))
          .toList();

      // Score and rank by taste profile match
      final scored = _scoreAndRank(
        candidates: available,
        rng: rng,
        tasteProfile: tasteProfile,
      );

      // Skip segment when no candidates available
      if (scored.isEmpty) continue;

      // Calculate how many songs to select for this segment
      final songsNeeded =
          (segment.durationSeconds / estimatedSongDurationSeconds)
              .ceil();
      final selected =
          scored.take(songsNeeded.clamp(1, scored.length));

      // Build PlaylistSong objects and track used song IDs
      for (final entry in selected) {
        usedSongIds.add(entry.song.songId);
        allPlaylistSongs.add(
          PlaylistSong(
            title: entry.song.title,
            artistName: entry.song.artistName,
            bpm: entry.song.tempo,
            matchType: entry.song.matchType,
            segmentLabel: segmentLabel,
            segmentIndex: i,
            songUri: entry.song.songUri,
            spotifyUrl: SongLinkBuilder.spotifySearchUrl(
              entry.song.title,
              entry.song.artistName,
            ),
            youtubeUrl: SongLinkBuilder.youtubeMusicSearchUrl(
              entry.song.title,
              entry.song.artistName,
            ),
          ),
        );
      }
    }

    return Playlist(
      songs: allPlaylistSongs,
      runPlanName: runPlan.name,
      totalDurationSeconds: runPlan.totalDurationSeconds,
      createdAt: DateTime.now(),
    );
  }

  /// Collects all candidate songs for a target BPM from the
  /// pre-fetched pool.
  ///
  /// Uses [BpmMatcher.bpmQueries] to determine which BPM keys to
  /// look up in the songsByBpm map (exact + half-time + double-time).
  static List<BpmSong> _collectCandidates({
    required int targetBpm,
    required Map<int, List<BpmSong>> songsByBpm,
  }) {
    final queries = BpmMatcher.bpmQueries(targetBpm);
    final candidates = <BpmSong>[];

    for (final entry in queries.entries) {
      final bpm = entry.key;
      final matchType = entry.value;
      final songs = songsByBpm[bpm];
      if (songs != null) {
        // Assign the correct matchType based on relationship to target
        candidates.addAll(
          songs.map((s) => s.withMatchType(matchType)),
        );
      }
    }

    return candidates;
  }

  /// Scores and ranks candidate songs by taste profile match.
  ///
  /// Scoring:
  /// - +10 if song's artist matches any artist in the taste profile
  ///   (case-insensitive)
  /// - +3 for exact BPM match
  /// - +1 for half-time or double-time match
  ///
  /// Songs are sorted by score descending. Within the same score
  /// tier, songs are shuffled for variety across regenerations.
  ///
  /// This is a RANKING signal, not a hard filter. If no songs match
  /// taste preferences, all BPM-matched songs are still returned
  /// (just unranked).
  static List<_ScoredSong> _scoreAndRank({
    required List<BpmSong> candidates,
    required Random rng,
    TasteProfile? tasteProfile,
  }) {
    final artistsLower = tasteProfile?.artists
            .map((a) => a.toLowerCase())
            .toList() ??
        const [];

    // Shuffle first for randomness within same-score tiers,
    // then stable-sort by score descending.
    final scored = candidates.map((song) {
      var score = 0;

      // Artist match (case-insensitive)
      if (artistsLower.isNotEmpty) {
        final songArtistLower = song.artistName.toLowerCase();
        if (artistsLower.any(
          (a) =>
              songArtistLower.contains(a) ||
              a.contains(songArtistLower),
        )) {
          score += _artistMatchScore;
        }
      }

      // Match type bonus
      if (song.matchType == BpmMatchType.exact) {
        score += _exactMatchScore;
      } else {
        score += _tempoVariantScore;
      }

      return _ScoredSong(song, score);
    }).toList()
      ..shuffle(rng)
      ..sort((a, b) => b.score.compareTo(a.score));

    return scored;
  }
}

/// Internal scored song wrapper for ranking.
class _ScoredSong {
  const _ScoredSong(this.song, this.score);

  final BpmSong song;
  final int score;
}
