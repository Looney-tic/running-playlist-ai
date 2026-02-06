import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:running_playlist_ai/features/onboarding/data/onboarding_preferences.dart';
import 'package:running_playlist_ai/features/onboarding/providers/onboarding_providers.dart';
import 'package:running_playlist_ai/features/run_plan/domain/run_plan_calculator.dart';
import 'package:running_playlist_ai/features/run_plan/providers/run_plan_providers.dart';
import 'package:running_playlist_ai/features/stride/domain/stride_calculator.dart';
import 'package:running_playlist_ai/features/taste_profile/domain/taste_profile.dart';
import 'package:running_playlist_ai/features/taste_profile/providers/taste_profile_providers.dart';

/// Multi-step onboarding flow for first-time users.
///
/// Steps:
///   0. Welcome — app intro with "Get Started" button
///   1. Genres — pick 1-5 running genres (defaults: pop, rock)
///   2. Pace & Distance — choose distance preset + pace (defaults: 5K, 5:30/km)
///   3. Finish — summary + "Generate My Playlist" button
///
/// Each step (1-2) has a "Skip" button that keeps defaults. On completion,
/// creates a TasteProfile and RunPlan, marks onboarding complete, and navigates
/// to the playlist screen with auto-generation.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  static const _totalSteps = 4;

  // -- Genre state (Step 1) --
  final _selectedGenres = <RunningGenre>{RunningGenre.pop, RunningGenre.rock};

  // -- Pace & Distance state (Step 2) --
  double _selectedDistance = 5;
  int _selectedDistancePreset = 0; // index into _distancePresets
  double _selectedPace = 5.5; // 5:30/km

  static const _distancePresets = [
    (label: '5K', value: 5.0),
    (label: '10K', value: 10.0),
    (label: 'Half', value: 21.1),
    (label: 'Marathon', value: 42.2),
  ];

  /// Pace options from 3:00 to 10:00 in 15-second increments.
  static final _paceOptions = [
    for (int min = 3; min <= 9; min++)
      for (int sec = 0; sec < 60; sec += 15) min + sec / 60.0,
    10.0,
  ];

  bool _isGenerating = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _nextStep() => _goToStep(_currentStep + 1);
  void _previousStep() => _goToStep(_currentStep - 1);

  /// Snaps a pace value to the nearest option in the dropdown list.
  double _snapToNearest(double pace) {
    return _paceOptions.reduce(
      (a, b) => (a - pace).abs() < (b - pace).abs() ? a : b,
    );
  }

  Future<void> _finishOnboarding() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);

    try {
      // 1. Create a TasteProfile with selected genres and sensible defaults.
      final profile = TasteProfile(
        name: 'My Taste',
        genres: _selectedGenres.toList(),
      );
      await ref
          .read(tasteProfileLibraryProvider.notifier)
          .addProfile(profile);

      // 2. Create a RunPlan using the selected distance and pace.
      final bpm = RunPlanCalculator.targetBpm(
        paceMinPerKm: _selectedPace,
      );
      final plan = RunPlanCalculator.createSteadyPlan(
        distanceKm: _selectedDistance,
        paceMinPerKm: _selectedPace,
        targetBpm: bpm,
        name: '${_selectedDistance}km run',
      );
      await ref.read(runPlanLibraryProvider.notifier).addPlan(plan);

      // 3. Mark onboarding complete.
      await OnboardingPreferences.markCompleted();
      if (!mounted) return;
      ref.read(onboardingCompletedProvider.notifier).state = true;

      // 4. Navigate to playlist with auto-generation.
      if (!mounted) return;
      context.go('/playlist?auto=true');
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // -- Step indicator --
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: LinearProgressIndicator(
                value: (_currentStep + 1) / _totalSteps,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Step ${_currentStep + 1} of $_totalSteps',
                style: theme.textTheme.bodySmall,
              ),
            ),

            // -- Pages --
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) =>
                    setState(() => _currentStep = index),
                children: [
                  _buildWelcomeStep(theme),
                  _buildGenreStep(theme),
                  _buildPaceDistanceStep(theme),
                  _buildFinishStep(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 0: Welcome
  // ---------------------------------------------------------------------------
  Widget _buildWelcomeStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.headphones,
            size: 80,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Running Playlist AI',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Create playlists that match your running rhythm',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          FilledButton.icon(
            onPressed: _nextStep,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Get Started'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1: Genres
  // ---------------------------------------------------------------------------
  Widget _buildGenreStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'What do you like to run to?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick 1-5 genres (${_selectedGenres.length}/5)',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
          const SizedBox(height: 32),
          Row(
            children: [
              TextButton(
                onPressed: _previousStep,
                child: const Text('Back'),
              ),
              const Spacer(),
              TextButton(
                onPressed: _nextStep,
                child: const Text('Skip'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _nextStep,
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2: Pace & Distance
  // ---------------------------------------------------------------------------
  Widget _buildPaceDistanceStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'How do you run?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set your typical distance and pace',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Distance presets
          Text('Distance', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: List.generate(_distancePresets.length, (index) {
              final preset = _distancePresets[index];
              return ChoiceChip(
                label: Text(preset.label),
                selected: _selectedDistancePreset == index,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedDistancePreset = index;
                      _selectedDistance = preset.value;
                    });
                  }
                },
              );
            }),
          ),
          const SizedBox(height: 24),

          // Pace dropdown
          Text('Pace', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          InputDecorator(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<double>(
                value: _snapToNearest(_selectedPace),
                isExpanded: true,
                items: _paceOptions
                    .map(
                      (pace) => DropdownMenuItem(
                        value: pace,
                        child: Text('${formatPace(pace)} min/km'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedPace = value);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              TextButton(
                onPressed: _previousStep,
                child: const Text('Back'),
              ),
              const Spacer(),
              TextButton(
                onPressed: _nextStep,
                child: const Text('Skip'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _nextStep,
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3: Finish & Generate
  // ---------------------------------------------------------------------------
  Widget _buildFinishStep(ThemeData theme) {
    final bpm = RunPlanCalculator.targetBpm(paceMinPerKm: _selectedPace);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ready to generate your first playlist!',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Selected genres summary
          Text('Your genres', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _selectedGenres.map((genre) {
              return Chip(label: Text(genre.displayName));
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Run info summary
          Text('Your run', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'Distance',
                    value: '$_selectedDistance km',
                  ),
                  _SummaryRow(
                    label: 'Pace',
                    value: '${formatPace(_selectedPace)} /km',
                  ),
                  _SummaryRow(
                    label: 'Target BPM',
                    value: '${bpm.round()} bpm',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          Row(
            children: [
              TextButton(
                onPressed: _isGenerating ? null : _previousStep,
                child: const Text('Back'),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _isGenerating ? null : _finishOnboarding,
            icon: _isGenerating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(
              _isGenerating ? 'Setting up...' : 'Generate My Playlist',
            ),
          ),
        ],
      ),
    );
  }
}

/// A single row showing a label-value pair in the summary card.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
