import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:running_playlist_ai/features/post_run_review/providers/post_run_review_providers.dart';
import 'package:running_playlist_ai/features/run_plan/providers/run_plan_providers.dart';
import 'package:running_playlist_ai/features/stride/providers/stride_providers.dart';
import 'package:running_playlist_ai/features/taste_profile/providers/taste_profile_providers.dart';

/// Home hub screen with navigation to all app features.
///
/// Displays context-aware empty states based on whether a taste profile and
/// run plan exist. When both are configured, shows a quick-regenerate card
/// (with active profile name) and cadence nudge controls above the standard
/// navigation buttons.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runPlan = ref.watch(runPlanNotifierProvider);
    final tasteProfile = ref.watch(tasteProfileNotifierProvider);
    final strideState = ref.watch(strideNotifierProvider);
    final cadence = strideState.cadence.round();
    final theme = Theme.of(context);

    final unreviewedPlaylist = ref.watch(unreviewedPlaylistProvider);
    final hasProfile = tasteProfile != null;
    final hasPlan = runPlan != null;

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
              // Context-aware setup prompts
              if (!hasProfile)
                _SetupCard(
                  icon: Icons.music_note,
                  title: 'Set up your music taste',
                  subtitle: 'Tell us what genres you like to run to',
                  color: theme.colorScheme.secondaryContainer,
                  onTap: () => context.push('/taste-profile'),
                ),
              if (!hasPlan)
                _SetupCard(
                  icon: Icons.timer,
                  title: 'Create a run plan',
                  subtitle:
                      'Set your distance and pace for playlist matching',
                  color: theme.colorScheme.secondaryContainer,
                  onTap: () => context.push('/run-plan'),
                ),

              // Post-run review prompt
              if (unreviewedPlaylist != null)
                _SetupCard(
                  icon: Icons.rate_review,
                  title: 'Rate your last playlist',
                  subtitle: '${unreviewedPlaylist.songs.length} songs from '
                      '${unreviewedPlaylist.runPlanName ?? "your run"}',
                  color: theme.colorScheme.tertiaryContainer,
                  onTap: () => context.push('/post-run-review'),
                ),

              // Quick-regenerate and cadence nudge (shown when run plan exists)
              if (hasPlan) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.replay),
                      title: const Text('Regenerate Playlist'),
                      subtitle: Text(
                        '${runPlan.distanceKm.toStringAsFixed(1)}'
                        ' km at $cadence spm'
                        '${hasProfile ? '\nProfile: '
                            '${tasteProfile.name ?? "Unnamed"}' : ''}',
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
                onPressed: () => context.push('/my-runs'),
                icon: const Icon(Icons.timer),
                label: const Text('My Runs'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.push('/taste-profiles'),
                icon: const Icon(Icons.music_note),
                label: const Text('Taste Profiles'),
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
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.push('/song-feedback'),
                icon: const Icon(Icons.thumb_up_alt_outlined),
                label: const Text('Song Feedback'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable setup prompt card for missing profile or plan.
class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 8),
      child: Card(
        color: color,
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: onTap,
        ),
      ),
    );
  }
}
