import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/taste_profile/data/taste_profile_preferences.dart';
import 'package:running_playlist_ai/features/taste_profile/domain/taste_profile.dart';

/// Manages the user's [TasteProfile] state and persistence.
///
/// Loads the saved profile from SharedPreferences on initialization.
/// Provides granular mutation methods that enforce business rules
/// (max 5 genres, max 10 artists, artist name validation).
///
/// Follows the same pattern as RunPlanNotifier.
class TasteProfileNotifier extends StateNotifier<TasteProfile?> {
  TasteProfileNotifier() : super(null) {
    _load();
  }

  /// Loads the saved taste profile from SharedPreferences.
  Future<void> _load() async {
    state = await TasteProfilePreferences.load();
  }

  /// Replaces the entire taste profile and persists it.
  Future<void> setProfile(TasteProfile profile) async {
    state = profile;
    await TasteProfilePreferences.save(profile);
  }

  /// Sets the selected genres (clamped to max 5).
  Future<void> setGenres(List<RunningGenre> genres) async {
    final clamped = genres.length > 5 ? genres.sublist(0, 5) : genres;
    final profile = (state ?? const TasteProfile()).copyWith(genres: clamped);
    state = profile;
    await TasteProfilePreferences.save(profile);
  }

  /// Adds an artist if valid (non-empty, not duplicate, under max 10).
  ///
  /// Returns true if the artist was added, false if rejected.
  Future<bool> addArtist(String artist) async {
    final trimmed = artist.trim();
    if (trimmed.isEmpty) return false;

    final current = state ?? const TasteProfile();
    if (current.artists.length >= 10) return false;

    // Case-insensitive duplicate check
    final lowerTrimmed = trimmed.toLowerCase();
    if (current.artists.any((a) => a.toLowerCase() == lowerTrimmed)) {
      return false;
    }

    final updated = current.copyWith(
      artists: [...current.artists, trimmed],
    );
    state = updated;
    await TasteProfilePreferences.save(updated);
    return true;
  }

  /// Removes an artist by exact string match.
  Future<void> removeArtist(String artist) async {
    final current = state;
    if (current == null) return;
    final updated = current.copyWith(
      artists: current.artists.where((a) => a != artist).toList(),
    );
    state = updated;
    await TasteProfilePreferences.save(updated);
  }

  /// Sets the energy level preference.
  Future<void> setEnergyLevel(EnergyLevel level) async {
    final profile =
        (state ?? const TasteProfile()).copyWith(energyLevel: level);
    state = profile;
    await TasteProfilePreferences.save(profile);
  }

  /// Clears the taste profile and removes it from storage.
  Future<void> clear() async {
    state = null;
    await TasteProfilePreferences.clear();
  }
}

/// Provides [TasteProfileNotifier] and the current [TasteProfile?]
/// to the widget tree.
///
/// Usage:
/// - `ref.watch(tasteProfileNotifierProvider)` to read
/// - `ref.read(...notifier).setGenres(genres)` to update
/// - `ref.read(...notifier).addArtist(name)` to add artist
/// - `ref.read(...notifier).setEnergyLevel(level)` to set energy
/// - `ref.read(...notifier).clear()` to remove the profile
final tasteProfileNotifierProvider =
    StateNotifierProvider<TasteProfileNotifier, TasteProfile?>(
  (ref) => TasteProfileNotifier(),
);
