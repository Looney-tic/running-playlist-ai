import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/curated_songs/providers/curated_song_providers.dart';
import 'package:running_playlist_ai/features/song_feedback/providers/song_feedback_providers.dart';
import 'package:running_playlist_ai/features/taste_learning/data/taste_suggestion_preferences.dart';
import 'package:running_playlist_ai/features/taste_learning/domain/taste_pattern_analyzer.dart';
import 'package:running_playlist_ai/features/taste_learning/domain/taste_suggestion.dart';
import 'package:running_playlist_ai/features/taste_profile/domain/taste_profile.dart';
import 'package:running_playlist_ai/features/taste_profile/providers/taste_profile_providers.dart';

/// Manages taste learning suggestions backed by TastePatternAnalyzer.
///
/// Loads dismissed suggestions from SharedPreferences on construction,
/// runs the analyzer against current feedback and profile state,
/// and supports accept/dismiss operations that persist state and
/// re-analyze.
///
/// Follows the established Completer + ensureLoaded pattern from
/// [SongFeedbackNotifier] and PostRunReviewNotifier.
class TasteSuggestionNotifier extends StateNotifier<List<TasteSuggestion>> {
  TasteSuggestionNotifier({required this.ref}) : super([]) {
    _load();
    // Re-analyze when feedback or profile changes
    ref.listen(songFeedbackProvider, (_, __) => _reanalyze());
    ref.listen(tasteProfileLibraryProvider, (_, __) => _reanalyze());
  }

  /// Reference to the Riverpod container for reading other providers.
  final Ref ref;

  final Completer<void> _loadCompleter = Completer<void>();

  /// Dismissed suggestions: {suggestionId: evidenceCountAtDismissal}.
  Map<String, int> _dismissedSuggestions = {};

  /// Waits until the initial async load from preferences is complete.
  /// Safe to call multiple times -- returns immediately if already loaded.
  Future<void> ensureLoaded() => _loadCompleter.future;

  Future<void> _load() async {
    try {
      _dismissedSuggestions =
          await TasteSuggestionPreferences.loadDismissed();
      await _reanalyze();
    } finally {
      if (!_loadCompleter.isCompleted) _loadCompleter.complete();
    }
  }

  /// Re-runs the pattern analyzer against current feedback and profile state.
  Future<void> _reanalyze() async {
    final feedback = ref.read(songFeedbackProvider);
    final profileState = ref.read(tasteProfileLibraryProvider);
    final profile = profileState.selectedProfile;
    if (profile == null || feedback.isEmpty) {
      if (mounted) state = [];
      return;
    }

    // Load curated genre lookup (async provider, use cached value if ready)
    final genreLookupAsync = ref.read(curatedGenreLookupProvider);
    final genreLookup = genreLookupAsync.valueOrNull ?? {};

    final suggestions = TastePatternAnalyzer.analyze(
      feedback: feedback,
      curatedGenreLookup: genreLookup,
      activeProfile: profile,
      dismissedSuggestions: _dismissedSuggestions,
    );

    if (mounted) state = suggestions;
  }

  /// Accepts a suggestion: mutates the taste profile, adds to dismissed,
  /// and re-analyzes.
  ///
  /// - [SuggestionType.addGenre]: Adds the genre to the profile.
  /// - [SuggestionType.addArtist]: Adds the artist to favorites.
  /// - [SuggestionType.removeArtist]: Adds the artist to the disliked list.
  Future<void> acceptSuggestion(TasteSuggestion suggestion) async {
    final profileState = ref.read(tasteProfileLibraryProvider);
    final profile = profileState.selectedProfile;
    if (profile == null) return;

    final notifier = ref.read(tasteProfileLibraryProvider.notifier);

    switch (suggestion.type) {
      case SuggestionType.addGenre:
        final genre = RunningGenre.tryFromJson(suggestion.value);
        if (genre == null || profile.genres.contains(genre)) return;
        await notifier.updateProfile(
          profile.copyWith(genres: [...profile.genres, genre]),
        );
      case SuggestionType.addArtist:
        if (profile.artists.any(
            (a) => a.toLowerCase() == suggestion.value.toLowerCase())) return;
        await notifier.updateProfile(
          profile.copyWith(artists: [...profile.artists, suggestion.value]),
        );
      case SuggestionType.removeArtist:
        if (profile.dislikedArtists.any(
            (a) => a.toLowerCase() == suggestion.value.toLowerCase())) return;
        await notifier.updateProfile(
          profile.copyWith(
            dislikedArtists: [...profile.dislikedArtists, suggestion.value],
          ),
        );
    }

    // Add to dismissed so it doesn't reappear
    _dismissedSuggestions[suggestion.id] = suggestion.evidenceCount;
    await TasteSuggestionPreferences.saveDismissed(_dismissedSuggestions);
    await _reanalyze();
  }

  /// Dismisses a suggestion: stores the evidence count at dismissal time
  /// and re-analyzes (the suggestion will not reappear until evidence
  /// grows by +3).
  Future<void> dismissSuggestion(TasteSuggestion suggestion) async {
    _dismissedSuggestions[suggestion.id] = suggestion.evidenceCount;
    await TasteSuggestionPreferences.saveDismissed(_dismissedSuggestions);
    await _reanalyze();
  }
}

/// Provides reactive taste learning suggestions.
///
/// Watch the state for UI updates:
/// ```dart
/// final suggestions = ref.watch(tasteSuggestionProvider);
/// ```
///
/// Read the notifier for accept/dismiss operations:
/// ```dart
/// final notifier = ref.read(tasteSuggestionProvider.notifier);
/// await notifier.acceptSuggestion(suggestion);
/// ```
final tasteSuggestionProvider =
    StateNotifierProvider<TasteSuggestionNotifier, List<TasteSuggestion>>(
  (ref) => TasteSuggestionNotifier(ref: ref),
);
