import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:running_playlist_ai/features/run_plan/providers/run_plan_providers.dart';
import 'package:running_playlist_ai/features/stride/providers/stride_providers.dart';

/// Home hub screen with navigation to all app features.
///
/// When a run plan exists, displays a quick-regenerate card and cadence
/// nudge controls above the standard navigation buttons.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runPlan = ref.watch(runPlanNotifierProvider);
    final strideState = ref.watch(strideNotifierProvider);
    final cadence = strideState.cadence.round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Running Playlist AI'),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              // Quick-regenerate and cadence nudge (shown when run plan exists)
              if (runPlan != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.replay),
                      title: const Text('Regenerate Playlist'),
                      subtitle: Text(
                        '${runPlan.distanceKm.toStringAsFixed(1)}'
                        ' km at $cadence spm',
                      ),
                      onTap: () => context.push('/playlist?auto=true'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () => ref
                                .read(strideNotifierProvider.notifier)
                                .nudgeCadence(-3),
                            icon: const Icon(Icons.remove),
                            tooltip: '-3 spm',
                            iconSize: 20,
                          ),
                          IconButton(
                            onPressed: () => ref
                                .read(strideNotifierProvider.notifier)
                                .nudgeCadence(-1),
                            icon: const Icon(Icons.remove),
                            tooltip: '-1 spm',
                            iconSize: 16,
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '$cadence spm',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => ref
                                .read(strideNotifierProvider.notifier)
                                .nudgeCadence(1),
                            icon: const Icon(Icons.add),
                            tooltip: '+1 spm',
                            iconSize: 16,
                          ),
                          IconButton(
                            onPressed: () => ref
                                .read(strideNotifierProvider.notifier)
                                .nudgeCadence(3),
                            icon: const Icon(Icons.add),
                            tooltip: '+3 spm',
                            iconSize: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Navigation buttons
              const Text(
                'What would you like to do?',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.push('/stride'),
                icon: const Icon(Icons.directions_run),
                label: const Text('Stride Calculator'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.push('/run-plan'),
                icon: const Icon(Icons.timer),
                label: const Text('Plan Run'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.push('/taste-profile'),
                icon: const Icon(Icons.music_note),
                label: const Text('Taste Profile'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.push('/playlist'),
                icon: const Icon(Icons.queue_music),
                label: const Text('Generate Playlist'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.push('/playlist-history'),
                icon: const Icon(Icons.history),
                label: const Text('Playlist History'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
