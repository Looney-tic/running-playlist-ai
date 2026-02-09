import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/run_plan/domain/run_plan.dart';
import 'package:running_playlist_ai/features/run_plan/domain/run_plan_calculator.dart';
import 'package:running_playlist_ai/features/run_plan/providers/run_plan_providers.dart';
import 'package:running_playlist_ai/features/stride/domain/stride_calculator.dart';
import 'package:running_playlist_ai/features/stride/providers/stride_providers.dart';

/// Run plan screen where users configure distance, pace, run type, and save a
/// run plan for playlist generation.
///
/// Supports three run types:
/// - **Steady:** Single-pace run (original flow)
/// - **Warm-up/Cool-down:** Three segments with configurable warm-up and
///   cool-down durations
/// - **Intervals:** Warm-up, work/rest pairs, and cool-down with configurable
///   interval count, work duration, and rest duration
///
/// Displays real-time duration and target BPM calculations as the user
/// adjusts inputs. For structured runs, shows a per-segment BPM breakdown
/// with a colored timeline bar. Saved plans persist across sessions
/// via RunPlanPreferences.
class RunPlanScreen extends ConsumerStatefulWidget {
  const RunPlanScreen({super.key});

  @override
  ConsumerState<RunPlanScreen> createState() => _RunPlanScreenState();
}

class _RunPlanScreenState extends ConsumerState<RunPlanScreen> {
  double _selectedDistance = 5.0;
  double _selectedPace = 5.5;
  int? _selectedPresetIndex = 0;
  final _customDistanceController = TextEditingController();

  // Run type state
  RunType _selectedRunType = RunType.steady;

  // Warm-up/Cool-down state
  int _warmUpMinutes = 5;
  int _coolDownMinutes = 5;

  // Interval state
  int _intervalCount = 4;
  int _workSeconds = 120;
  int _restSeconds = 60;

  /// Pace options from 3:00 to 10:00 in 15-second increments.
  static final _paceOptions = [
    for (int min = 3; min <= 9; min++)
      for (int sec = 0; sec < 60; sec += 15) min + sec / 60.0,
    10.0,
  ];

  static const _distancePresets = [
    (label: '5K', value: 5.0),
    (label: '10K', value: 10.0),
    (label: 'Half', value: 21.1),
    (label: 'Marathon', value: 42.2),
  ];

  @override
  void dispose() {
    _customDistanceController.dispose();
    super.dispose();
  }

  /// Snaps a pace value to the nearest option in the dropdown list.
  double _snapToNearest(double pace) {
    return _paceOptions.reduce(
      (a, b) => (a - pace).abs() < (b - pace).abs() ? a : b,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPlan = ref.watch(runPlanNotifierProvider);
    final strideState = ref.watch(strideNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Run'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // -- E: Current plan indicator --
            if (currentPlan != null) ...[
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Current plan: ${currentPlan.distanceKm}km at '
                    '${formatPace(currentPlan.paceMinPerKm)}/km',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // -- A: Distance selection --
            Text('Distance', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: List.generate(_distancePresets.length, (index) {
                final preset = _distancePresets[index];
                return ChoiceChip(
                  label: Text(preset.label),
                  selected: _selectedPresetIndex == index,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedPresetIndex = index;
                        _selectedDistance = preset.value;
                        _customDistanceController.clear();
                      } else {
                        _selectedPresetIndex = null;
                        _selectedDistance = 0;
                      }
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customDistanceController,
              decoration: const InputDecoration(
                labelText: 'Custom (km)',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                final parsed = double.tryParse(value);
                setState(() {
                  if (parsed != null && parsed >= 0.1 && parsed <= 100) {
                    _selectedDistance = parsed;
                    _selectedPresetIndex = null;
                  } else if (value.isEmpty) {
                    // Only reset distance if no preset is selected
                    if (_selectedPresetIndex == null) {
                      _selectedDistance = 0;
                    }
                  }
                });
              },
            ),
            const SizedBox(height: 24),

            // -- B: Pace input --
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
            const SizedBox(height: 24),

            // -- F: Run type selector --
            Text('Run Type', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<RunType>(
              segments: const [
                ButtonSegment(
                  value: RunType.steady,
                  label: Text('Steady'),
                  icon: Icon(Icons.trending_flat),
                ),
                ButtonSegment(
                  value: RunType.warmUpCoolDown,
                  label: Text('Warm-up'),
                  icon: Icon(Icons.show_chart),
                ),
                ButtonSegment(
                  value: RunType.interval,
                  label: Text('Intervals'),
                  icon: Icon(Icons.stacked_bar_chart),
                ),
              ],
              selected: {_selectedRunType},
              onSelectionChanged: (selected) {
                setState(() => _selectedRunType = selected.first);
              },
            ),
            const SizedBox(height: 16),

            // -- G: Warm-Up/Cool-Down config --
            if (_selectedRunType == RunType.warmUpCoolDown) ...[
              _buildWarmUpCoolDownConfig(theme),
              const SizedBox(height: 16),
            ],

            // -- H: Interval config --
            if (_selectedRunType == RunType.interval) ...[
              _buildIntervalConfig(theme),
              const SizedBox(height: 16),
            ],

            // -- C: Run summary card --
            if (_selectedDistance > 0) ...[
              _buildSummaryCard(strideState, theme),
              const SizedBox(height: 24),
            ],

            // -- D: Save button --
            ElevatedButton(
              onPressed: _selectedDistance > 0
                  ? () => _savePlan(strideState)
                  : null,
              child: Text(
                currentPlan != null ? 'Update Run Plan' : 'Save Run Plan',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarmUpCoolDownConfig(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Warm-up/Cool-down Settings',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            _buildSliderRow(
              label: 'Warm-up Duration',
              value: '$_warmUpMinutes min',
              slider: Slider(
                value: _warmUpMinutes.toDouble(),
                min: 1,
                max: 15,
                divisions: 14,
                label: '$_warmUpMinutes min',
                onChanged: (v) =>
                    setState(() => _warmUpMinutes = v.round()),
              ),
            ),
            _buildSliderRow(
              label: 'Cool-down Duration',
              value: '$_coolDownMinutes min',
              slider: Slider(
                value: _coolDownMinutes.toDouble(),
                min: 1,
                max: 15,
                divisions: 14,
                label: '$_coolDownMinutes min',
                onChanged: (v) =>
                    setState(() => _coolDownMinutes = v.round()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntervalConfig(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Interval Settings', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            _buildSliderRow(
              label: 'Intervals',
              value: '$_intervalCount',
              slider: Slider(
                value: _intervalCount.toDouble(),
                min: 2,
                max: 20,
                divisions: 18,
                label: '$_intervalCount',
                onChanged: (v) =>
                    setState(() => _intervalCount = v.round()),
              ),
            ),
            _buildSliderRow(
              label: 'Work Duration',
              value: _formatSliderDuration(_workSeconds),
              slider: Slider(
                value: _workSeconds.toDouble(),
                min: 30,
                max: 600,
                divisions: 19,
                label: _formatSliderDuration(_workSeconds),
                onChanged: (v) =>
                    setState(() => _workSeconds = v.round()),
              ),
            ),
            _buildSliderRow(
              label: 'Rest Duration',
              value: _formatSliderDuration(_restSeconds),
              slider: Slider(
                value: _restSeconds.toDouble(),
                min: 15,
                max: 300,
                divisions: 19,
                label: _formatSliderDuration(_restSeconds),
                onChanged: (v) =>
                    setState(() => _restSeconds = v.round()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required String value,
    required Slider slider,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        slider,
      ],
    );
  }

  /// Formats seconds into a human-readable duration string for slider labels.
  String _formatSliderDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes == 0) return '${seconds}s';
    if (seconds == 0) return '${minutes}m';
    return '${minutes}m ${seconds}s';
  }

  Widget _buildSummaryCard(StrideState strideState, ThemeData theme) {
    final bpm = RunPlanCalculator.targetBpm(
      paceMinPerKm: _selectedPace,
      heightCm: strideState.heightCm,
      calibratedCadence: strideState.calibratedCadence,
    );

    // For structured run types, generate a preview plan to show segments
    if (_selectedRunType != RunType.steady) {
      final previewPlan = _buildPreviewPlan(bpm);
      return _buildStructuredSummaryCard(previewPlan, theme);
    }

    // Steady run: original summary card
    final durationSec = RunPlanCalculator.durationSeconds(
      distanceKm: _selectedDistance,
      paceMinPerKm: _selectedPace,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Run Summary', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            _SummaryRow(
              label: 'Distance',
              value: '$_selectedDistance km',
            ),
            _SummaryRow(
              label: 'Pace',
              value: '${formatPace(_selectedPace)} /km',
            ),
            _SummaryRow(
              label: 'Duration',
              value: formatDuration(durationSec),
            ),
            _SummaryRow(
              label: 'Target Cadence',
              value: '${bpm.round()} spm',
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a preview [RunPlan] based on the current run type configuration.
  RunPlan _buildPreviewPlan(double bpm) {
    if (_selectedRunType == RunType.warmUpCoolDown) {
      return RunPlanCalculator.createWarmUpCoolDownPlan(
        distanceKm: _selectedDistance,
        paceMinPerKm: _selectedPace,
        targetBpm: bpm,
        warmUpSeconds: _warmUpMinutes * 60,
        coolDownSeconds: _coolDownMinutes * 60,
      );
    }

    return RunPlanCalculator.createIntervalPlan(
      distanceKm: _selectedDistance,
      paceMinPerKm: _selectedPace,
      targetBpm: bpm,
      intervalCount: _intervalCount,
      workSeconds: _workSeconds,
      restSeconds: _restSeconds,
    );
  }

  /// Summary card for structured runs showing segment timeline and BPM
  /// breakdown.
  Widget _buildStructuredSummaryCard(RunPlan plan, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Run Summary', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            _SummaryRow(
              label: 'Distance',
              value: '$_selectedDistance km',
            ),
            _SummaryRow(
              label: 'Pace',
              value: '${formatPace(_selectedPace)} /km',
            ),
            _SummaryRow(
              label: 'Total Duration',
              value: formatDuration(plan.totalDurationSeconds),
            ),
            _SummaryRow(
              label: 'Segments',
              value: '${plan.segments.length}',
            ),
            const SizedBox(height: 16),

            // Segment timeline bar
            Text('Segment Timeline', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _SegmentTimeline(segments: plan.segments),
            const SizedBox(height: 12),

            // Per-segment BPM breakdown
            ...plan.segments.map(
              (segment) => _SummaryRow(
                label: segment.label ?? 'Segment',
                value: '${formatDuration(segment.durationSeconds)}'
                    ' - ${segment.targetBpm.round()} spm',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _savePlan(StrideState strideState) {
    final bpm = RunPlanCalculator.targetBpm(
      paceMinPerKm: _selectedPace,
      heightCm: strideState.heightCm,
      calibratedCadence: strideState.calibratedCadence,
    );

    final RunPlan plan;

    switch (_selectedRunType) {
      case RunType.steady:
        plan = RunPlanCalculator.createSteadyPlan(
          distanceKm: _selectedDistance,
          paceMinPerKm: _selectedPace,
          targetBpm: bpm,
        );
      case RunType.warmUpCoolDown:
        plan = RunPlanCalculator.createWarmUpCoolDownPlan(
          distanceKm: _selectedDistance,
          paceMinPerKm: _selectedPace,
          targetBpm: bpm,
          warmUpSeconds: _warmUpMinutes * 60,
          coolDownSeconds: _coolDownMinutes * 60,
        );
      case RunType.interval:
        plan = RunPlanCalculator.createIntervalPlan(
          distanceKm: _selectedDistance,
          paceMinPerKm: _selectedPace,
          targetBpm: bpm,
          intervalCount: _intervalCount,
          workSeconds: _workSeconds,
          restSeconds: _restSeconds,
        );
    }

    ref.read(runPlanLibraryProvider.notifier).addPlan(plan);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Run plan saved!')),
    );
  }
}

/// Colored timeline bar showing the relative duration of each segment.
///
/// Uses distinct colors for different segment types:
/// - Warm-up: amber
/// - Cool-down: blue
/// - Work: red/orange
/// - Rest: green
/// - Main: primary theme color
class _SegmentTimeline extends StatelessWidget {
  const _SegmentTimeline({required this.segments});

  final List<RunSegment> segments;

  Color _colorForSegment(RunSegment segment, ColorScheme colorScheme) {
    final label = segment.label?.toLowerCase() ?? '';
    if (label.contains('warm')) return Colors.amber;
    if (label.contains('cool')) return Colors.blue.shade300;
    if (label.contains('work')) return Colors.deepOrange;
    if (label.contains('rest')) return Colors.green.shade400;
    return colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final totalDuration =
        segments.fold<int>(0, (sum, s) => sum + s.durationSeconds);
    if (totalDuration == 0) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 24,
        child: Row(
          children: segments.map((segment) {
            final fraction = segment.durationSeconds / totalDuration;
            return Expanded(
              flex: (fraction * 1000).round(),
              child: Tooltip(
                message: '${segment.label ?? "Segment"}: '
                    '${formatDuration(segment.durationSeconds)}'
                    ' - ${segment.targetBpm.round()} spm',
                child: Container(
                  color: _colorForSegment(segment, colorScheme),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// A single row in the run summary card showing a label and value.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
  });

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
