import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/run_plan/domain/run_plan.dart';
import 'package:running_playlist_ai/features/run_plan/domain/run_plan_calculator.dart';
import 'package:running_playlist_ai/features/run_plan/providers/run_plan_providers.dart';
import 'package:running_playlist_ai/features/stride/domain/stride_calculator.dart';
import 'package:running_playlist_ai/features/stride/providers/stride_providers.dart';

/// Run plan screen where users configure distance, pace, and save a steady
/// run plan for playlist generation.
///
/// Displays real-time duration and target BPM calculations as the user
/// adjusts distance and pace inputs. Saved plans persist across sessions
/// via RunPlanPreferences.
class RunPlanScreen extends ConsumerStatefulWidget {
  const RunPlanScreen({super.key});

  @override
  ConsumerState<RunPlanScreen> createState() => _RunPlanScreenState();
}

class _RunPlanScreenState extends ConsumerState<RunPlanScreen> {
  double _selectedDistance = 0;
  double _selectedPace = 5.5;
  int? _selectedPresetIndex;
  final _customDistanceController = TextEditingController();

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
            // ── E: Current plan indicator ──────────────────────────
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

            // ── A: Distance selection ──────────────────────────────
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

            // ── B: Pace input ──────────────────────────────────────
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

            // ── C: Run summary card ────────────────────────────────
            if (_selectedDistance > 0) ...[
              _buildSummaryCard(strideState, theme),
              const SizedBox(height: 24),
            ],

            // ── D: Save button ─────────────────────────────────────
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

  Widget _buildSummaryCard(StrideState strideState, ThemeData theme) {
    final durationSec = RunPlanCalculator.durationSeconds(
      distanceKm: _selectedDistance,
      paceMinPerKm: _selectedPace,
    );
    final bpm = RunPlanCalculator.targetBpm(
      paceMinPerKm: _selectedPace,
      heightCm: strideState.heightCm,
      calibratedCadence: strideState.calibratedCadence,
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
              label: 'Target BPM',
              value: '${bpm.round()} bpm',
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

    final plan = RunPlanCalculator.createSteadyPlan(
      distanceKm: _selectedDistance,
      paceMinPerKm: _selectedPace,
      targetBpm: bpm,
    );

    ref.read(runPlanNotifierProvider.notifier).setPlan(plan);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Run plan saved!')),
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
