import 'dart:async';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/bpm_lookup/data/bpm_cache_preferences.dart';
import 'package:running_playlist_ai/features/bpm_lookup/data/getsongbpm_client.dart';
import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_matcher.dart';
import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_song.dart';

/// State for a BPM lookup operation.
class BpmLookupState {
  const BpmLookupState({
    this.songs = const [],
    this.isLoading = false,
    this.error,
    this.targetBpm,
  });

  final List<BpmSong> songs;
  final bool isLoading;
  final String? error;
  final int? targetBpm;
}

/// Orchestrates BPM song lookup with cache-first strategy and error handling.
///
/// For a given target BPM, this notifier:
/// 1. Computes exact + half/double-time BPM values via [BpmMatcher]
/// 2. Checks [BpmCachePreferences] for each BPM value (cache-first)
/// 3. Falls back to [GetSongBpmClient] API on cache miss
/// 4. Saves API results to cache for future lookups
/// 5. Assigns the correct [BpmMatchType] to each song based on context
/// 6. Merges all results and updates state
class BpmLookupNotifier extends StateNotifier<BpmLookupState> {
  BpmLookupNotifier(this._client) : super(const BpmLookupState());

  final GetSongBpmClient _client;

  /// Looks up songs for the given [targetBpm].
  ///
  /// Uses cache-first strategy: checks local cache before hitting the API.
  /// Queries multiple BPM values (exact + half/double-time) and merges results.
  Future<void> lookupByBpm(int targetBpm) async {
    state = BpmLookupState(isLoading: true, targetBpm: targetBpm);

    try {
      // Determine which BPM values to query (exact + half + double)
      final queries = BpmMatcher.bpmQueries(targetBpm);
      final allSongs = <BpmSong>[];

      for (final entry in queries.entries) {
        final bpm = entry.key;
        final matchType = entry.value;

        // Cache-first: check local cache
        var songs = await BpmCachePreferences.load(bpm);

        if (songs == null) {
          // Cache miss: fetch from API
          songs = await _client.fetchSongsByBpm(bpm);
          // Save raw songs (without matchType) to cache
          await BpmCachePreferences.save(bpm, songs);
        }

        // Assign matchType based on relationship to target BPM
        final typed = songs.map((s) => s.withMatchType(matchType)).toList();
        allSongs.addAll(typed);
      }

      state = BpmLookupState(songs: allSongs, targetBpm: targetBpm);
    } on SocketException {
      state = BpmLookupState(
        error:
            'No internet connection. Please check your network and try again.',
        targetBpm: targetBpm,
      );
    } on TimeoutException {
      state = BpmLookupState(
        error: 'Request timed out. Please try again.',
        targetBpm: targetBpm,
      );
    } on BpmApiException catch (e) {
      state = BpmLookupState(
        error: 'Could not fetch songs: ${e.message}',
        targetBpm: targetBpm,
      );
    } on FormatException {
      state = BpmLookupState(
        error: 'Received unexpected data from the server.',
        targetBpm: targetBpm,
      );
    } catch (e) {
      state = BpmLookupState(
        error: 'An unexpected error occurred. Please try again.',
        targetBpm: targetBpm,
      );
    }
  }

  /// Clears the current lookup results.
  void clear() {
    state = const BpmLookupState();
  }
}

/// Provides a [GetSongBpmClient] configured with the API key from `.env`.
final getSongBpmClientProvider = Provider<GetSongBpmClient>((ref) {
  final apiKey = dotenv.env['GETSONGBPM_API_KEY'] ?? '';
  final client = GetSongBpmClient(apiKey: apiKey);
  ref.onDispose(client.dispose);
  return client;
});

/// Provides [BpmLookupNotifier] and the current [BpmLookupState].
///
/// Usage:
/// - `ref.watch(bpmLookupProvider)` to read the current state reactively
/// - `ref.read(bpmLookupProvider.notifier).lookupByBpm(170)` to trigger lookup
/// - `ref.read(bpmLookupProvider.notifier).clear()` to reset
final bpmLookupProvider =
    StateNotifierProvider<BpmLookupNotifier, BpmLookupState>((ref) {
  final client = ref.watch(getSongBpmClientProvider);
  return BpmLookupNotifier(client);
});
