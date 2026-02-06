import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/taste_profile/domain/taste_profile.dart';
import 'package:running_playlist_ai/features/taste_profile/providers/taste_profile_providers.dart';

/// Taste profile screen where users configure their running music preferences.
///
/// Three sections:
/// - **Genres:** FilterChip grid for selecting 1-5 preferred genres
/// - **Artists:** TextField + InputChip list for adding up to 10
///   favorite artists
/// - **Energy Level:** SegmentedButton for chill/balanced/intense preference
///
/// Preferences persist across app restarts via TasteProfilePreferences.
class TasteProfileScreen extends ConsumerStatefulWidget {
  const TasteProfileScreen({super.key});

  @override
  ConsumerState<TasteProfileScreen> createState() =>
      _TasteProfileScreenState();
}

class _TasteProfileScreenState extends ConsumerState<TasteProfileScreen> {
  final _selectedGenres = <RunningGenre>{};
  final _artists = <String>[];
  EnergyLevel _selectedEnergyLevel = EnergyLevel.balanced;
  VocalPreference _selectedVocalPreference = VocalPreference.noPreference;
  TempoVarianceTolerance _selectedTempoVarianceTolerance =
      TempoVarianceTolerance.moderate;
  final _dislikedArtists = <String>[];
  final _artistController = TextEditingController();
  final _dislikedArtistController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _artistController.dispose();
    _dislikedArtistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(tasteProfileNotifierProvider);
    final theme = Theme.of(context);

    // Sync local state from provider on first load (handles existing profile)
    if (!_initialized && profile != null) {
      _initialized = true;
      // Use addPostFrameCallback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _selectedGenres
            ..clear()
            ..addAll(profile.genres);
          _artists
            ..clear()
            ..addAll(profile.artists);
          _selectedEnergyLevel = profile.energyLevel;
          _selectedVocalPreference = profile.vocalPreference;
          _selectedTempoVarianceTolerance = profile.tempoVarianceTolerance;
          _dislikedArtists
            ..clear()
            ..addAll(profile.dislikedArtists);
        });
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Taste Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // -- Genre selection --
            Text('Running Genres', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Select 1-5 genres (${_selectedGenres.length}/5)',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: RunningGenre.values.map((genre) {
                final isSelected = _selectedGenres.contains(genre);
                return FilterChip(
                  label: Text(genre.displayName),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        if (_selectedGenres.length < 5) {
                          _selectedGenres.add(genre);
                        }
                      } else {
                        _selectedGenres.remove(genre);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // -- Artist input --
            Text('Favorite Artists', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Add up to 10 artists (${_artists.length}/10)',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (_artists.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _artists.map((artist) {
                  return InputChip(
                    label: Text(artist),
                    onDeleted: () {
                      setState(() => _artists.remove(artist));
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
            if (_artists.length < 10)
              TextField(
                controller: _artistController,
                decoration: const InputDecoration(
                  labelText: 'Add artist',
                  hintText: 'Type artist name and press enter',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: _addArtist,
              ),
            const SizedBox(height: 24),

            // -- Energy level selector --
            Text('Energy Level', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<EnergyLevel>(
              segments: const [
                ButtonSegment(
                  value: EnergyLevel.chill,
                  label: Text('Chill'),
                  icon: Icon(Icons.spa),
                ),
                ButtonSegment(
                  value: EnergyLevel.balanced,
                  label: Text('Balanced'),
                  icon: Icon(Icons.balance),
                ),
                ButtonSegment(
                  value: EnergyLevel.intense,
                  label: Text('Intense'),
                  icon: Icon(Icons.local_fire_department),
                ),
              ],
              selected: {_selectedEnergyLevel},
              onSelectionChanged: (selected) {
                setState(() => _selectedEnergyLevel = selected.first);
              },
            ),
            const SizedBox(height: 24),

            // -- Vocal Preference selector --
            Text('Vocal Preference', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<VocalPreference>(
              segments: const [
                ButtonSegment(
                  value: VocalPreference.noPreference,
                  label: Text('No Preference'),
                  icon: Icon(Icons.remove),
                ),
                ButtonSegment(
                  value: VocalPreference.preferVocals,
                  label: Text('Prefer Vocals'),
                  icon: Icon(Icons.mic),
                ),
                ButtonSegment(
                  value: VocalPreference.preferInstrumental,
                  label: Text('Instrumental'),
                  icon: Icon(Icons.music_off),
                ),
              ],
              selected: {_selectedVocalPreference},
              onSelectionChanged: (selected) {
                setState(() => _selectedVocalPreference = selected.first);
              },
            ),
            const SizedBox(height: 24),

            // -- Tempo Tolerance selector --
            Text('Tempo Matching', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<TempoVarianceTolerance>(
              segments: const [
                ButtonSegment(
                  value: TempoVarianceTolerance.strict,
                  label: Text('Strict'),
                  icon: Icon(Icons.gps_fixed),
                ),
                ButtonSegment(
                  value: TempoVarianceTolerance.moderate,
                  label: Text('Moderate'),
                  icon: Icon(Icons.adjust),
                ),
                ButtonSegment(
                  value: TempoVarianceTolerance.loose,
                  label: Text('Loose'),
                  icon: Icon(Icons.all_inclusive),
                ),
              ],
              selected: {_selectedTempoVarianceTolerance},
              onSelectionChanged: (selected) {
                setState(
                    () => _selectedTempoVarianceTolerance = selected.first);
              },
            ),
            const SizedBox(height: 24),

            // -- Disliked Artists input --
            Text('Disliked Artists', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Songs by these artists will be excluded (${_dislikedArtists.length}/10)',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (_dislikedArtists.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _dislikedArtists.map((artist) {
                  return InputChip(
                    label: Text(artist),
                    onDeleted: () {
                      setState(() => _dislikedArtists.remove(artist));
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
            if (_dislikedArtists.length < 10)
              TextField(
                controller: _dislikedArtistController,
                decoration: const InputDecoration(
                  labelText: 'Add disliked artist',
                  hintText: 'Type artist name and press enter',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: _addDislikedArtist,
              ),
            const SizedBox(height: 32),

            // -- Save button --
            ElevatedButton(
              onPressed: _selectedGenres.isNotEmpty ? _saveProfile : null,
              child: Text(
                profile != null
                    ? 'Update Taste Profile'
                    : 'Save Taste Profile',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addArtist(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    // Case-insensitive duplicate check
    final lowerTrimmed = trimmed.toLowerCase();
    if (_artists.any((a) => a.toLowerCase() == lowerTrimmed)) {
      _artistController.clear();
      return;
    }

    if (_artists.length < 10) {
      setState(() => _artists.add(trimmed));
      _artistController.clear();
    }
  }

  void _addDislikedArtist(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    // Case-insensitive duplicate check
    final lowerTrimmed = trimmed.toLowerCase();
    if (_dislikedArtists.any((a) => a.toLowerCase() == lowerTrimmed)) {
      _dislikedArtistController.clear();
      return;
    }

    if (_dislikedArtists.length < 10) {
      setState(() {
        _dislikedArtists.add(trimmed);
        // Mutual exclusivity: remove from favorites if present
        _artists.removeWhere((a) => a.toLowerCase() == lowerTrimmed);
      });
      _dislikedArtistController.clear();
    }
  }

  void _saveProfile() {
    final profile = TasteProfile(
      genres: _selectedGenres.toList(),
      artists: List.of(_artists),
      energyLevel: _selectedEnergyLevel,
      vocalPreference: _selectedVocalPreference,
      tempoVarianceTolerance: _selectedTempoVarianceTolerance,
      dislikedArtists: List.of(_dislikedArtists),
    );
    ref.read(tasteProfileNotifierProvider.notifier).setProfile(profile);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Taste profile saved!')),
    );
  }
}
