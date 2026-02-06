import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:running_playlist_ai/features/run_plan/domain/run_plan.dart';
import 'package:running_playlist_ai/features/run_plan/providers/run_plan_providers.dart';

/// Screen listing all saved run plans with selection and delete.
///
/// Users can:
/// - Tap a plan to select it for playlist generation
/// - Swipe to delete a plan
/// - Tap the FAB to create a new plan
class RunPlanLibraryScreen extends ConsumerWidget {
  const RunPlanLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(runPlanLibraryProvider);
    final plans = libraryState.plans;
    final selectedId = libraryState.selectedPlan?.id;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('My Runs')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/run-plan'),
        child: const Icon(Icons.add),
      ),
      body: plans.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_run,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 16),
                    const Text(
                      'No saved runs',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your first run plan to get started.',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => context.push('/run-plan'),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Run'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: plans.length,
              itemBuilder: (context, index) {
                final plan = plans[index];
                final isSelected = plan.id == selectedId;
                return _RunPlanCard(
                  plan: plan,
                  isSelected: isSelected,
                  onTap: () => ref
                      .read(runPlanLibraryProvider.notifier)
                      .selectPlan(plan.id),
                  onDelete: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Run Plan'),
                        content: Text(
                          'Delete "${plan.name ?? 'this run plan'}"? This cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  Theme.of(ctx).colorScheme.error,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if ((confirmed ?? false) && context.mounted) {
                      await ref
                          .read(runPlanLibraryProvider.notifier)
                          .deletePlan(plan.id);
                    }
                  },
                  onGenerate: () {
                    ref
                        .read(runPlanLibraryProvider.notifier)
                        .selectPlan(plan.id);
                    context.push('/playlist?auto=true');
                  },
                );
              },
            ),
    );
  }
}

class _RunPlanCard extends StatelessWidget {
  const _RunPlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
    required this.onGenerate,
  });

  final RunPlan plan;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : theme.colorScheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Run type icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _iconForType(plan.type),
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              // Plan info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name ?? _defaultName(plan),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : null,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${plan.distanceKm.toStringAsFixed(1)} km'
                      '  \u00b7  '
                      '${formatDuration(plan.totalDurationSeconds)}'
                      '  \u00b7  '
                      '${plan.segments.length} segment'
                      '${plan.segments.length == 1 ? "" : "s"}',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Generate button
              IconButton(
                onPressed: onGenerate,
                icon: Icon(
                  Icons.play_circle_filled,
                  color: theme.colorScheme.primary,
                ),
                tooltip: 'Generate playlist',
              ),
              // Delete
              IconButton(
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                  size: 20,
                ),
                tooltip: 'Delete',
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(RunType type) {
    return switch (type) {
      RunType.steady => Icons.directions_run,
      RunType.warmUpCoolDown => Icons.whatshot_outlined,
      RunType.interval => Icons.timer,
    };
  }

  String _defaultName(RunPlan plan) {
    return switch (plan.type) {
      RunType.steady => 'Steady Run',
      RunType.warmUpCoolDown => 'Warm-up/Cool-down',
      RunType.interval => 'Interval Run',
    };
  }
}
