import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/bpm_lookup/data/bpm_cache_preferences.dart';
import 'package:running_playlist_ai/features/bpm_lookup/data/getsongbpm_client.dart';
import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_matcher.dart';
import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_song.dart';
import 'package:running_playlist_ai/features/bpm_lookup/providers/bpm_lookup_providers.dart';
import 'package:running_playlist_ai/features/curated_songs/data/curated_song_repository.dart';
import 'package:running_playlist_ai/features/curated_songs/providers/curated_song_providers.dart';
import 'package:running_playlist_ai/features/playlist/domain/playlist.dart';
import 'package:running_playlist_ai/features/playlist/domain/playlist_generator.dart';
import 'package:running_playlist_ai/features/playlist/domain/song_link_builder.dart';
import 'package:running_playlist_ai/features/playlist/providers/playlist_history_providers.dart';
import 'package:running_playlist_ai/features/playlist_freshness/domain/playlist_freshness.dart';
import 'package:running_playlist_ai/features/playlist_freshness/providers/playlist_freshness_providers.dart';
import 'package:running_playlist_ai/features/run_plan/domain/run_plan.dart';
import 'package:running_playlist_ai/features/run_plan/providers/run_plan_providers.dart';
import 'package:running_playlist_ai/features/running_songs/providers/running_song_providers.dart';
import 'package:running_playlist_ai/features/song_feedback/providers/song_feedback_providers.dart';
import 'package:running_playlist_ai/features/taste_profile/domain/taste_profile.dart';
import 'package:running_playlist_ai/features/taste_profile/providers/taste_profile_providers.dart';

/// State for playlist generation.
class PlaylistGenerationState {
  const PlaylistGenerationState._({
    this.playlist,
    this.isLoading = false,
    this.error,
    this.songPool = const {},
    this.runPlan,
    this.tasteProfile,
  });

  /// Initial idle state.
  const PlaylistGenerationState.idle() : this._();

  /// Loading state while fetching songs and generating.
  const PlaylistGenerationState.loading() : this._(isLoading: true);

  /// Loaded state with a generated playlist.
  PlaylistGenerationState.loaded(
    Playlist playlist, {
    Map<int, List<BpmSong>> songPool = const {},
    RunPlan? runPlan,
    TasteProfile? tasteProfile,
  }) : this._(
          playlist: playlist,
          songPool: songPool,
          runPlan: runPlan,
          tasteProfile: tasteProfile,
        );

  /// Error state with a user-facing message.
  const PlaylistGenerationState.error(String message) : this._(error: message);

  final Playlist? playlist;
  final bool isLoading;
  final String? error;

  /// The full song pool used during generation, kept for replacements.
  final Map<int, List<BpmSong>> songPool;

  /// The run plan used for the last generation, kept for shuffle/regenerate.
  final RunPlan? runPlan;

  /// The taste profile used for the last generation, kept for shuffle/regenerate.
  final TasteProfile? tasteProfile;
}

/// Orchestrates playlist generation: batch BPM fetching + algorithm execution.
///
/// Uses [GetSongBpmClient] and [BpmCachePreferences] directly (not through
/// [BpmLookupNotifier]) for batch multi-BPM fetching. This gives full control
/// over fetching songs for all unique segment BPMs in a single operation.
///
/// Flow:
/// 1. Read current RunPlan and TasteProfile from their providers
/// 2. Collect unique target BPMs across all run plan segments
/// 3. For each unique BPM, compute query BPMs via BpmMatcher
///    (exact + half + double)
/// 4. For each query BPM, check cache first, then fetch from API
///    on miss
/// 5. Accumulate all songs into a map of BPM to song list
/// 6. Call PlaylistGenerator.generate with the accumulated songs
/// 7. Update state with the generated Playlist
class PlaylistGenerationNotifier
    extends StateNotifier<PlaylistGenerationState> {
  PlaylistGenerationNotifier({
    required this.client,
    required this.ref,
  }) : super(const PlaylistGenerationState.idle());

  final GetSongBpmClient client;
  final Ref ref;

  /// Delay between API calls for uncached BPMs to avoid rate limiting.
  static const _apiCallDelay = Duration(milliseconds: 300);

  /// Reads current feedback and splits into disliked/liked key sets.
  ({Set<String> disliked, Set<String> liked}) _readFeedbackSets() {
    final feedbackMap = ref.read(songFeedbackProvider);
    final disliked = <String>{};
    final liked = <String>{};
    for (final entry in feedbackMap.entries) {
      if (entry.value.isLiked) {
        liked.add(entry.key);
      } else {
        disliked.add(entry.key);
      }
    }
    // Merge "Songs I Run To" keys into liked set for scoring boost
    final runningSongs = ref.read(runningSongProvider);
    liked.addAll(runningSongs.keys);
    return (disliked: disliked, liked: liked);
  }

  /// Reads play history for freshness scoring, or null if in optimize-for-taste mode.
  Map<String, DateTime>? _readPlayHistory() {
    final mode = ref.read(freshnessModeProvider);
    if (mode == FreshnessMode.optimizeForTaste) return null;
    final history = ref.read(playHistoryProvider);
    return history.entries.isNotEmpty ? history.entries : null;
  }

  /// Generates a playlist from the current run plan and taste profile.
  ///
  /// Reads RunPlan from [runPlanNotifierProvider] and TasteProfile from
  /// [tasteProfileNotifierProvider]. If no run plan is saved, produces an
  /// error state.
  ///
  /// Awaits [ensureLoaded] on library notifiers before reading state,
  /// fixing the cold-start race condition where fire-and-forget _load()
  /// hasn't completed yet.
  Future<void> generatePlaylist() async {
    state = const PlaylistGenerationState.loading();

    // Ensure library notifiers have finished loading from preferences.
    await ref.read(runPlanLibraryProvider.notifier).ensureLoaded();
    await ref.read(tasteProfileLibraryProvider.notifier).ensureLoaded();
    await ref.read(songFeedbackProvider.notifier).ensureLoaded();
    await ref.read(playHistoryProvider.notifier).ensureLoaded();
    await ref.read(freshnessModeProvider.notifier).ensureLoaded();
    await ref.read(runningSongProvider.notifier).ensureLoaded();

    final runPlan = ref.read(runPlanNotifierProvider);
    if (runPlan == null) {
      state = const PlaylistGenerationState.error(
        'No run plan saved. Please create a run plan first.',
      );
      return;
    }

    final tasteProfile = ref.read(tasteProfileNotifierProvider);

    try {
      // Try API first, fall back to curated songs on any failure.
      var songsByBpm = <int, List<BpmSong>>{};
      try {
        songsByBpm = await _fetchAllSongs(runPlan);
      } catch (_) {
        // API failed -- fall back to curated dataset
        songsByBpm = await _buildSongsFromCurated(runPlan);
      }

      // Load curated song runnability scores for quality scoring.
      // Uses catch-all because Supabase.instance throws AssertionError
      // (not Exception) when not initialized, and Riverpod re-throws it.
      var curatedRunnability = <String, int>{};
      try {
        curatedRunnability =
            await ref.read(curatedRunnabilityProvider.future);
        // ignore: avoid_catches_without_on_clauses, Supabase.instance throws AssertionError (Error, not Exception) when not initialized.
      } catch (_) {
        // Graceful degradation: generate without runnability data
      }

      final feedback = _readFeedbackSets();
      final playHistory = _readPlayHistory();

      final playlist = PlaylistGenerator.generate(
        runPlan: runPlan,
        tasteProfile: tasteProfile,
        songsByBpm: songsByBpm,
        curatedRunnability:
            curatedRunnability.isNotEmpty ? curatedRunnability : null,
        dislikedSongKeys:
            feedback.disliked.isNotEmpty ? feedback.disliked : null,
        likedSongKeys: feedback.liked.isNotEmpty ? feedback.liked : null,
        playHistory: playHistory,
      );

      if (!mounted) return;
      state = PlaylistGenerationState.loaded(
        playlist,
        songPool: songsByBpm,
        runPlan: runPlan,
        tasteProfile: tasteProfile,
      );

      // Auto-save to history
      unawaited(
        ref.read(playlistHistoryProvider.notifier).addPlaylist(playlist),
      );
      ref.read(playHistoryProvider.notifier).recordPlaylist(playlist);
      // ignore: avoid_catches_without_on_clauses
    } catch (e, stackTrace) {
      debugPrint('Playlist generation error: $e\n$stackTrace');
      if (!mounted) return;
      state = const PlaylistGenerationState.error(
        'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Regenerates the playlist using the stored song pool with a new random seed.
  ///
  /// This is instant -- no API call, no loading spinner. Reuses [state.songPool]
  /// and reads the CURRENT run plan and taste profile from providers.
  /// Falls back to [generatePlaylist] if no song pool exists.
  void shufflePlaylist() {
    if (state.songPool.isEmpty || state.runPlan == null) {
      generatePlaylist();
      return;
    }

    final runPlan = ref.read(runPlanNotifierProvider) ?? state.runPlan!;
    final tasteProfile =
        ref.read(tasteProfileNotifierProvider) ?? state.tasteProfile;

    var curatedRunnability = <String, int>{};
    try {
      final cached = ref.read(curatedRunnabilityProvider).valueOrNull;
      if (cached != null) curatedRunnability = cached;
    } catch (_) {
      // Graceful degradation
    }

    final feedback = _readFeedbackSets();
    final playHistory = _readPlayHistory();

    final playlist = PlaylistGenerator.generate(
      runPlan: runPlan,
      tasteProfile: tasteProfile,
      songsByBpm: state.songPool,
      curatedRunnability:
          curatedRunnability.isNotEmpty ? curatedRunnability : null,
      dislikedSongKeys:
          feedback.disliked.isNotEmpty ? feedback.disliked : null,
      likedSongKeys: feedback.liked.isNotEmpty ? feedback.liked : null,
      playHistory: playHistory,
    );

    state = PlaylistGenerationState.loaded(
      playlist,
      songPool: state.songPool,
      runPlan: runPlan,
      tasteProfile: tasteProfile,
    );

    unawaited(
      ref.read(playlistHistoryProvider.notifier).addPlaylist(playlist),
    );
    ref.read(playHistoryProvider.notifier).recordPlaylist(playlist);
  }

  /// Regenerates the playlist by re-fetching songs from the API.
  ///
  /// This performs a full re-fetch, unlike [shufflePlaylist] which reuses
  /// the stored song pool. Falls back to [generatePlaylist] if no prior
  /// generation state exists.
  Future<void> regeneratePlaylist() async {
    final storedPlan = state.runPlan;
    if (storedPlan == null) {
      return generatePlaylist();
    }

    final tasteProfile = state.tasteProfile;

    state = const PlaylistGenerationState.loading();

    try {
      var songsByBpm = <int, List<BpmSong>>{};
      try {
        songsByBpm = await _fetchAllSongs(storedPlan);
      } catch (_) {
        songsByBpm = await _buildSongsFromCurated(storedPlan);
      }

      var curatedRunnability = <String, int>{};
      try {
        curatedRunnability =
            await ref.read(curatedRunnabilityProvider.future);
        // ignore: avoid_catches_without_on_clauses
      } catch (_) {
        // Graceful degradation
      }

      await ref.read(songFeedbackProvider.notifier).ensureLoaded();
      await ref.read(playHistoryProvider.notifier).ensureLoaded();
      await ref.read(freshnessModeProvider.notifier).ensureLoaded();
      await ref.read(runningSongProvider.notifier).ensureLoaded();
      final feedback = _readFeedbackSets();
      final playHistory = _readPlayHistory();

      final playlist = PlaylistGenerator.generate(
        runPlan: storedPlan,
        tasteProfile: tasteProfile,
        songsByBpm: songsByBpm,
        curatedRunnability:
            curatedRunnability.isNotEmpty ? curatedRunnability : null,
        dislikedSongKeys:
            feedback.disliked.isNotEmpty ? feedback.disliked : null,
        likedSongKeys: feedback.liked.isNotEmpty ? feedback.liked : null,
        playHistory: playHistory,
      );

      if (!mounted) return;
      state = PlaylistGenerationState.loaded(
        playlist,
        songPool: songsByBpm,
        runPlan: storedPlan,
        tasteProfile: tasteProfile,
      );

      unawaited(
        ref.read(playlistHistoryProvider.notifier).addPlaylist(playlist),
      );
      ref.read(playHistoryProvider.notifier).recordPlaylist(playlist);
      // ignore: avoid_catches_without_on_clauses
    } catch (e, stackTrace) {
      debugPrint('Playlist regeneration error: $e\n$stackTrace');
      if (!mounted) return;
      state = const PlaylistGenerationState.error(
        'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Fetches songs for all unique BPMs needed by the run plan.
  ///
  /// For each unique target BPM in the plan:
  /// 1. Compute query BPMs via BpmMatcher
  ///    (exact + half + double)
  /// 2. For each query BPM: check cache, fetch from API on
  ///    miss, save to cache
  /// 3. Accumulate results keyed by queried BPM
  ///
  /// Returns a map of queried BPM to songs, suitable for
  /// PlaylistGenerator.
  Future<Map<int, List<BpmSong>>> _fetchAllSongs(RunPlan plan) async {
    final songsByBpm = <int, List<BpmSong>>{};

    // Collect all unique query BPMs across all segments
    final allQueryBpms = <int>{};
    for (final segment in plan.segments) {
      final targetBpm = segment.targetBpm.round();
      final queries = BpmMatcher.bpmQueries(targetBpm);
      allQueryBpms.addAll(queries.keys);
    }

    // Fetch songs for each unique query BPM (cache-first)
    var isFirstApiCall = true;
    for (final bpm in allQueryBpms) {
      // Check cache first
      var songs = await BpmCachePreferences.load(bpm);

      if (songs == null) {
        // Rate limiting: small delay between API calls (skip for first call)
        if (!isFirstApiCall) {
          await Future<void>.delayed(_apiCallDelay);
        }
        isFirstApiCall = false;

        // Cache miss: fetch from API
        songs = await client.fetchSongsByBpm(bpm);
        // Save to cache for future use
        await BpmCachePreferences.save(bpm, songs);
      }

      songsByBpm[bpm] = songs;
    }

    return songsByBpm;
  }

  /// Builds a songsByBpm map from the curated dataset as API fallback.
  ///
  /// Converts curated songs into BpmSong objects and groups them by BPM.
  /// Only includes BPMs that the run plan actually needs (exact, half,
  /// double-time). This enables offline playlist generation using the
  /// bundled curated songs dataset.
  Future<Map<int, List<BpmSong>>> _buildSongsFromCurated(
    RunPlan plan,
  ) async {
    final curatedSongs = await CuratedSongRepository.loadCuratedSongs();

    // Build a map of BPM -> list of BpmSong from curated data
    // Skip songs without verified BPM data
    final allCuratedByBpm = <int, List<BpmSong>>{};
    for (final song in curatedSongs) {
      if (song.bpm == null) continue;
      allCuratedByBpm.putIfAbsent(song.bpm!, () => []).add(
            BpmSong(
              songId: song.lookupKey,
              title: song.title,
              artistName: song.artistName,
              tempo: song.bpm!,
              genre: song.genre,
              decade: song.decade,
              durationSeconds: song.durationSeconds,
              danceability: song.danceability,
              runnability: song.runnability,
            ),
          );
    }

    // Filter to only BPMs needed by the run plan
    final songsByBpm = <int, List<BpmSong>>{};
    final allQueryBpms = <int>{};
    for (final segment in plan.segments) {
      final targetBpm = segment.targetBpm.round();
      final queries = BpmMatcher.bpmQueries(targetBpm);
      allQueryBpms.addAll(queries.keys);
    }

    for (final bpm in allQueryBpms) {
      // Include exact matches and songs within +/- 2 BPM
      final nearby = <BpmSong>[];
      for (var b = bpm - 2; b <= bpm + 2; b++) {
        if (allCuratedByBpm.containsKey(b)) {
          nearby.addAll(allCuratedByBpm[b]!);
        }
      }
      if (nearby.isNotEmpty) {
        songsByBpm[bpm] = nearby;
      }
    }

    return songsByBpm;
  }

  /// Removes a song at [index] and returns up to 3 replacement suggestions.
  ///
  /// Suggestions are drawn from the song pool for the same segment BPM,
  /// excluding songs already in the playlist. The removed song stays gone
  /// until the user picks a replacement or regenerates.
  List<PlaylistSong> removeSong(int index) {
    final playlist = state.playlist;
    if (playlist == null || index < 0 || index >= playlist.songs.length) {
      return [];
    }

    final removed = playlist.songs[index];
    final updatedSongs = List<PlaylistSong>.from(playlist.songs)
      ..removeAt(index);

    final updatedPlaylist = Playlist(
      id: playlist.id,
      songs: updatedSongs,
      runPlanName: playlist.runPlanName,
      totalDurationSeconds: playlist.totalDurationSeconds,
      createdAt: playlist.createdAt,
      distanceKm: playlist.distanceKm,
      paceMinPerKm: playlist.paceMinPerKm,
    );

    state = PlaylistGenerationState.loaded(
      updatedPlaylist,
      songPool: state.songPool,
      runPlan: state.runPlan,
      tasteProfile: state.tasteProfile,
    );

    return _findReplacements(removed, updatedSongs);
  }

  /// Inserts a replacement song at [index] in the current playlist.
  void insertSong(int index, PlaylistSong song) {
    final playlist = state.playlist;
    if (playlist == null) return;

    final updatedSongs = List<PlaylistSong>.from(playlist.songs)
      ..insert(index.clamp(0, playlist.songs.length), song);

    state = PlaylistGenerationState.loaded(
      Playlist(
        id: playlist.id,
        songs: updatedSongs,
        runPlanName: playlist.runPlanName,
        totalDurationSeconds: playlist.totalDurationSeconds,
        createdAt: playlist.createdAt,
        distanceKm: playlist.distanceKm,
        paceMinPerKm: playlist.paceMinPerKm,
      ),
      songPool: state.songPool,
      runPlan: state.runPlan,
      tasteProfile: state.tasteProfile,
    );
  }

  /// Finds up to 3 replacement candidates from the pool.
  List<PlaylistSong> _findReplacements(
    PlaylistSong removed,
    List<PlaylistSong> currentSongs,
  ) {
    final pool = state.songPool;
    if (pool.isEmpty) return [];

    // IDs of songs already in the playlist
    final usedKeys = currentSongs
        .map((s) =>
            '${s.artistName.toLowerCase()}|${s.title.toLowerCase()}')
        .toSet();

    // Find songs near the removed song's BPM
    final candidates = <BpmSong>[];
    for (var b = removed.bpm - 3; b <= removed.bpm + 3; b++) {
      if (pool.containsKey(b)) {
        candidates.addAll(pool[b]!);
      }
    }

    // Filter out songs already in the playlist
    final available = candidates.where((s) {
      final key =
          '${s.artistName.toLowerCase()}|${s.title.toLowerCase()}';
      return !usedKeys.contains(key);
    }).toList()
      ..shuffle();

    // Convert top 3 to PlaylistSong
    return available.take(3).map((s) {
      return PlaylistSong(
        title: s.title,
        artistName: s.artistName,
        bpm: s.tempo,
        matchType: s.matchType,
        segmentLabel: removed.segmentLabel,
        segmentIndex: removed.segmentIndex,
        spotifyUrl: SongLinkBuilder.spotifySearchUrl(s.title, s.artistName),
        youtubeUrl: SongLinkBuilder.youtubeMusicSearchUrl(
          s.title,
          s.artistName,
        ),
        runningQuality: removed.runningQuality,
      );
    }).toList();
  }

  /// Resets the state to idle.
  void clear() {
    state = const PlaylistGenerationState.idle();
  }
}

/// Provides [PlaylistGenerationNotifier] and the current
/// [PlaylistGenerationState].
///
/// Usage:
/// - `ref.watch(playlistGenerationProvider)` for state
/// - `ref.read(...notifier).generatePlaylist()` to trigger
/// - `ref.read(...notifier).clear()` to reset
final playlistGenerationProvider = StateNotifierProvider<
    PlaylistGenerationNotifier, PlaylistGenerationState>((ref) {
  final client = ref.watch(getSongBpmClientProvider);
  return PlaylistGenerationNotifier(client: client, ref: ref);
});
