import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/bpm_lookup/data/bpm_cache_preferences.dart';
import 'package:running_playlist_ai/features/bpm_lookup/data/getsongbpm_client.dart';
import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_matcher.dart';
import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_song.dart';
import 'package:running_playlist_ai/features/bpm_lookup/providers/bpm_lookup_providers.dart';
import 'package:running_playlist_ai/features/playlist/domain/playlist.dart';
import 'package:running_playlist_ai/features/playlist/domain/playlist_generator.dart';
import 'package:running_playlist_ai/features/run_plan/domain/run_plan.dart';
import 'package:running_playlist_ai/features/run_plan/providers/run_plan_providers.dart';
import 'package:running_playlist_ai/features/taste_profile/providers/taste_profile_providers.dart';

/// State for playlist generation.
class PlaylistGenerationState {
  const PlaylistGenerationState._({
    this.playlist,
    this.isLoading = false,
    this.error,
  });

  /// Initial idle state.
  const PlaylistGenerationState.idle() : this._();

  /// Loading state while fetching songs and generating.
  const PlaylistGenerationState.loading() : this._(isLoading: true);

  /// Loaded state with a generated playlist.
  PlaylistGenerationState.loaded(Playlist playlist)
      : this._(playlist: playlist);

  /// Error state with a user-facing message.
  const PlaylistGenerationState.error(String message) : this._(error: message);

  final Playlist? playlist;
  final bool isLoading;
  final String? error;
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

  /// Generates a playlist from the current run plan and taste profile.
  ///
  /// Reads RunPlan from [runPlanNotifierProvider] and TasteProfile from
  /// [tasteProfileNotifierProvider]. If no run plan is saved, produces an
  /// error state.
  Future<void> generatePlaylist() async {
    final runPlan = ref.read(runPlanNotifierProvider);
    if (runPlan == null) {
      state = const PlaylistGenerationState.error(
        'No run plan saved. Please create a run plan first.',
      );
      return;
    }

    final tasteProfile = ref.read(tasteProfileNotifierProvider);

    state = const PlaylistGenerationState.loading();

    try {
      final songsByBpm = await _fetchAllSongs(runPlan);

      final playlist = PlaylistGenerator.generate(
        runPlan: runPlan,
        tasteProfile: tasteProfile,
        songsByBpm: songsByBpm,
      );

      if (!mounted) return;
      state = PlaylistGenerationState.loaded(playlist);
    } on SocketException {
      if (!mounted) return;
      state = const PlaylistGenerationState.error(
        'No internet connection. Please check your network and try again.',
      );
    } on TimeoutException {
      if (!mounted) return;
      state = const PlaylistGenerationState.error(
        'Request timed out. Please try again.',
      );
    } on BpmApiException catch (e) {
      if (!mounted) return;
      state = PlaylistGenerationState.error(
        'Could not fetch songs: ${e.message}',
      );
    } on Exception {
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
