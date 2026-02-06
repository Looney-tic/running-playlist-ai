import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/taste_profile/domain/taste_profile.dart';
import 'package:running_playlist_ai/features/taste_profile/providers/taste_profile_providers.dart';

/// Taste profile screen where users configure their running music preferences.
///
/// Accepts an optional [profileId] to edit an existing profile. When null,
/// creates a new profile.
class TasteProfileScreen extends ConsumerStatefulWidget {
  const TasteProfileScreen({this.profileId, super.key});

  /// ID of an existing profile to edit, or null for new.
  final String? profileId;

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
  final _selectedDecades = <MusicDecade>{};
  final _artistController = TextEditingController();
  final _dislikedArtistController = TextEditingController();
  final _nameController = TextEditingController();
  bool _initialized = false;

  /// The existing profile being edited, or null for new.
  TasteProfile? _existingProfile;

  @override
  void dispose() {
    _artistController.dispose();
    _dislikedArtistController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(tasteProfileLibraryProvider);
    final theme = Theme.of(context);

    // Sync local state from the profile being edited
    if (!_initialized && libraryState.profiles.isNotEmpty) {
      TasteProfile? profile;
      if (widget.profileId != null) {
        profile = libraryState.profiles
            .cast<TasteProfile?>()
            .firstWhere((p) => p!.id == widget.profileId, orElse: () => null);
      }

      if (profile != null) {
        _existingProfile = profile;
        _initialized = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _nameController.text = profile!.name ?? '';
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
            _selectedDecades
              ..clear()
              ..addAll(profile.decades);
          });
        });
      } else if (widget.profileId == null) {
        _initialized = true;
      }
    }

    final isEditing = _existingProfile != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Taste Profile' : 'New Taste Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // -- Profile name --
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Profile Name',
                hintText: 'e.g. "High Energy Mix"',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

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

            // -- Decade selection --
            Text('Decades', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Prefer songs from specific eras '
              '(${_selectedDecades.length} selected)',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: MusicDecade.values.map((decade) {
                final isSelected = _selectedDecades.contains(decade);
                return FilterChip(
                  label: Text(decade.displayName),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedDecades.add(decade);
                      } else {
                        _selectedDecades.remove(decade);
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
                isEditing ? 'Update Taste Profile' : 'Save Taste Profile',
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
    final name = _nameController.text.trim();
    final profile = TasteProfile(
      id: _existingProfile?.id,
      name: name.isNotEmpty ? name : null,
      genres: _selectedGenres.toList(),
      artists: List.of(_artists),
      energyLevel: _selectedEnergyLevel,
      vocalPreference: _selectedVocalPreference,
      tempoVarianceTolerance: _selectedTempoVarianceTolerance,
      dislikedArtists: List.of(_dislikedArtists),
      decades: _selectedDecades.toList(),
    );

    final notifier = ref.read(tasteProfileLibraryProvider.notifier);
    if (_existingProfile != null) {
      notifier.updateProfile(profile);
    } else {
      notifier.addProfile(profile);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Taste profile saved!')),
    );

    Navigator.of(context).pop();
  }
}
