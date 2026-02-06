import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/taste_profile/data/taste_profile_preferences.dart';
import 'package:running_playlist_ai/features/taste_profile/domain/taste_profile.dart';

/// State holding all saved taste profiles and which one is selected.
class TasteProfileLibraryState {
  const TasteProfileLibraryState({
    this.profiles = const [],
    this.selectedId,
  });

  final List<TasteProfile> profiles;
  final String? selectedId;

  /// The currently selected profile, or null if none exists.
  TasteProfile? get selectedProfile {
    if (selectedId == null) {
      return profiles.isNotEmpty ? profiles.first : null;
    }
    return profiles
        .cast<TasteProfile?>()
        .firstWhere((p) => p!.id == selectedId, orElse: () => null);
  }
}

/// Manages the taste profile library: multiple saved profiles + selection.
class TasteProfileLibraryNotifier
    extends StateNotifier<TasteProfileLibraryState> {
  TasteProfileLibraryNotifier()
      : super(const TasteProfileLibraryState()) {
    _load();
  }

  Future<void> _load() async {
    final profiles = await TasteProfilePreferences.loadAll();
    final selectedId = await TasteProfilePreferences.loadSelectedId();
    state = TasteProfileLibraryState(
      profiles: profiles,
      selectedId: selectedId,
    );
  }

  /// Adds a new profile and selects it.
  Future<void> addProfile(TasteProfile profile) async {
    final updated = [...state.profiles, profile];
    state = TasteProfileLibraryState(
      profiles: updated,
      selectedId: profile.id,
    );
    await TasteProfilePreferences.saveAll(updated);
    await TasteProfilePreferences.saveSelectedId(profile.id);
  }

  /// Updates an existing profile in-place.
  Future<void> updateProfile(TasteProfile profile) async {
    final updated = state.profiles.map((p) {
      return p.id == profile.id ? profile : p;
    }).toList();
    state = TasteProfileLibraryState(
      profiles: updated,
      selectedId: state.selectedId,
    );
    await TasteProfilePreferences.saveAll(updated);
  }

  /// Selects a profile by ID.
  Future<void> selectProfile(String id) async {
    state = TasteProfileLibraryState(
      profiles: state.profiles,
      selectedId: id,
    );
    await TasteProfilePreferences.saveSelectedId(id);
  }

  /// Deletes a profile by ID. If it was selected, selects the first remaining.
  Future<void> deleteProfile(String id) async {
    final updated = state.profiles.where((p) => p.id != id).toList();
    final newSelectedId = state.selectedId == id
        ? (updated.isNotEmpty ? updated.first.id : null)
        : state.selectedId;
    state = TasteProfileLibraryState(
      profiles: updated,
      selectedId: newSelectedId,
    );
    await TasteProfilePreferences.saveAll(updated);
    await TasteProfilePreferences.saveSelectedId(newSelectedId);
  }
}

/// Provides the taste profile library (all saved profiles + selection).
final tasteProfileLibraryProvider = StateNotifierProvider<
    TasteProfileLibraryNotifier, TasteProfileLibraryState>(
  (ref) => TasteProfileLibraryNotifier(),
);

/// Convenience: provides the currently selected [TasteProfile?].
///
/// Backward compatible with existing code that reads the active taste profile.
final tasteProfileNotifierProvider = Provider<TasteProfile?>((ref) {
  return ref.watch(tasteProfileLibraryProvider).selectedProfile;
});
