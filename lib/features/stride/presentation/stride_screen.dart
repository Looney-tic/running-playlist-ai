import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/stride/domain/stride_calculator.dart';
import 'package:running_playlist_ai/features/stride/providers/stride_providers.dart';

/// Full stride/cadence screen with pace input, height slider,
/// calibration flow, and real-time cadence display.
///
/// Uses [strideNotifierProvider] for reactive state management.
/// Cadence updates in real-time as the user adjusts pace or height.
/// Calibration overrides the formula-based estimate until cleared.
class StrideScreen extends ConsumerStatefulWidget {
  const StrideScreen({super.key});

  @override
  ConsumerState<StrideScreen> createState() => _StrideScreenState();
}

class _StrideScreenState extends ConsumerState<StrideScreen> {
  final _paceController = TextEditingController();
  final _stepsController = TextEditingController();
  final _paceFormKey = GlobalKey<FormState>();
  bool _useHeight = false;
  bool _showCalibration = false;

  @override
  void initState() {
    super.initState();
    // Initialize from current state after first frame so ref is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(strideNotifierProvider);
      _paceController.text = formatPace(state.paceMinPerKm);
      if (state.heightCm != null) {
        setState(() => _useHeight = true);
      }
      if (state.calibratedCadence != null) {
        setState(() => _showCalibration = true);
      }
    });
  }

  @override
  void dispose() {
    _paceController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(strideNotifierProvider);
    final notifier = ref.read(strideNotifierProvider.notifier);
    final theme = Theme.of(context);
    final isCalibrated = state.calibratedCadence != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stride Calculator'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Section A: Cadence Display ──────────────────────────
            _CadenceDisplay(
              cadence: state.cadence,
              isCalibrated: isCalibrated,
              onClearCalibration: () {
                notifier.clearCalibration();
                _stepsController.clear();
              },
            ),
            const SizedBox(height: 32),

            // ── Section B: Pace Input ───────────────────────────────
            _buildPaceSection(state, notifier, isCalibrated, theme),
            const SizedBox(height: 24),

            // ── Section C: Height Input ─────────────────────────────
            _buildHeightSection(state, notifier, isCalibrated, theme),
            const SizedBox(height: 24),

            // ── Section D: Calibration ──────────────────────────────
            _buildCalibrationSection(state, notifier, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildPaceSection(
    StrideState state,
    StrideNotifier notifier,
    bool isCalibrated,
    ThemeData theme,
  ) {
    return Opacity(
      opacity: isCalibrated ? 0.5 : 1.0,
      child: Form(
        key: _paceFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Target Pace', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _paceController,
              decoration: const InputDecoration(
                hintText: '5:30',
                suffixText: 'min/km',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.datetime,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d:]')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Enter a pace';
                }
                final pace = parsePace(value);
                if (pace == null) {
                  return 'Use M:SS format (e.g. 5:30)';
                }
                if (pace < 3.0 || pace > 10.0) {
                  return 'Pace must be between 3:00 and 10:00';
                }
                return null;
              },
              onChanged: (value) {
                final pace = parsePace(value);
                if (pace != null && pace >= 3.0 && pace <= 10.0) {
                  notifier.setPace(pace);
                }
              },
            ),
            if (isCalibrated)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Formula estimate would be '
                  '${StrideCalculator.calculateCadence(paceMinPerKm: state.paceMinPerKm, heightCm: state.heightCm).round()} spm',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeightSection(
    StrideState state,
    StrideNotifier notifier,
    bool isCalibrated,
    ThemeData theme,
  ) {
    return Opacity(
      opacity: isCalibrated ? 0.5 : 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Use height for better estimate'),
            value: _useHeight,
            onChanged: (value) {
              setState(() => _useHeight = value);
              if (!value) {
                notifier.setHeight(null);
              } else {
                notifier.setHeight(state.heightCm ?? 170);
              }
            },
          ),
          if (_useHeight) ...[
            Row(
              children: [
                Text(
                  '${(state.heightCm ?? 170).round()} cm',
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '(${_cmToFeetInches((state.heightCm ?? 170).round())})',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
            Slider(
              value: state.heightCm ?? 170,
              min: 140,
              max: 210,
              divisions: 70,
              label: '${(state.heightCm ?? 170).round()} cm',
              onChanged: (value) => notifier.setHeight(value),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalibrationSection(
    StrideState state,
    StrideNotifier notifier,
    ThemeData theme,
  ) {
    final isCalibrated = state.calibratedCadence != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Calibrate with real run'),
          trailing: Icon(
            _showCalibration
                ? Icons.expand_less
                : Icons.expand_more,
          ),
          onTap: () => setState(() => _showCalibration = !_showCalibration),
        ),
        if (_showCalibration) ...[
          Text(
            'Run at your target pace. Count every footstrike '
            '(both feet) for 30 seconds.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _stepsController,
            decoration: const InputDecoration(
              labelText: 'Steps counted in 30 seconds',
              hintText: 'e.g. 82',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton(
                onPressed: () {
                  final steps = int.tryParse(_stepsController.text);
                  if (steps == null || steps < 50 || steps > 120) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Enter a step count between 50 and 120 '
                          '(realistic for 30 seconds of running)',
                        ),
                      ),
                    );
                    return;
                  }
                  final cadence = steps * 2.0;
                  notifier.setCalibratedCadence(cadence);
                },
                child: const Text('Apply calibration'),
              ),
              const SizedBox(width: 12),
              if (isCalibrated)
                TextButton(
                  onPressed: () {
                    notifier.clearCalibration();
                    _stepsController.clear();
                  },
                  child: const Text('Clear calibration'),
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// Converts centimeters to a feet/inches string for display.
  static String _cmToFeetInches(int cm) {
    final totalInches = cm / 2.54;
    final feet = totalInches ~/ 12;
    final inches = (totalInches % 12).round();
    return "$feet'$inches\"";
  }
}

/// Prominent cadence display at the top of the screen.
class _CadenceDisplay extends StatelessWidget {
  const _CadenceDisplay({
    required this.cadence,
    required this.isCalibrated,
    this.onClearCalibration,
  });

  final double cadence;
  final bool isCalibrated;
  final VoidCallback? onClearCalibration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Text(
              '${cadence.round()} spm',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (isCalibrated)
              InputChip(
                label: const Text('Calibrated'),
                onDeleted: onClearCalibration,
                deleteIcon: const Icon(Icons.close, size: 18),
              )
            else
              Text(
                'Estimated from pace',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
