import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:running_playlist_ai/features/playlist/domain/playlist.dart';
import 'package:running_playlist_ai/features/playlist/presentation/widgets/segment_header.dart';
import 'package:running_playlist_ai/features/playlist/presentation/widgets/song_tile.dart';
import 'package:running_playlist_ai/features/playlist/providers/playlist_providers.dart';
import 'package:running_playlist_ai/features/playlist_freshness/domain/playlist_freshness.dart';
import 'package:running_playlist_ai/features/playlist_freshness/providers/playlist_freshness_providers.dart';
import 'package:running_playlist_ai/features/run_plan/domain/run_plan.dart';
import 'package:running_playlist_ai/features/run_plan/providers/run_plan_providers.dart';
import 'package:running_playlist_ai/features/stride/providers/stride_providers.dart';
import 'package:running_playlist_ai/features/taste_profile/domain/taste_profile.dart';
import 'package:running_playlist_ai/features/taste_profile/providers/taste_profile_providers.dart';

/// Screen for generating and displaying a BPM-matched playlist.
///
/// States:
/// - No run plan: shows message directing user to create one
/// - Idle (with run plan): shows Generate button with run plan summary
/// - Loading: shows progress indicator
/// - Loaded: shows playlist grouped by segment with song cards
/// - Error: shows error message with retry button
///
/// Supports [autoGenerate] to trigger playlist generation on mount
/// when navigated from the home screen quick-regenerate card.
class PlaylistScreen extends ConsumerStatefulWidget {
  const PlaylistScreen({this.autoGenerate = false, super.key});

  /// When true, automatically triggers playlist generation on mount
  /// if a run plan exists.
  final bool autoGenerate;

  @override
  ConsumerState<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends ConsumerState<PlaylistScreen> {
  bool _autoGenTriggered = false;

  @override
  Widget build(BuildContext context) {
    final generationState = ref.watch(playlistGenerationProvider);
    final runPlan = ref.watch(runPlanNotifierProvider);

    // Auto-generate: wait until the run plan is available (loaded async),
    // then trigger once.
    if (widget.autoGenerate &&
        !_autoGenTriggered &&
        runPlan != null &&
        !generationState.isLoading) {
      _autoGenTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(playlistGenerationProvider.notifier).generatePlaylist();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Playlist'),
        actions: [
          if (generationState.playlist != null)
            IconButton(
              onPressed: () =>
                  _copyPlaylist(context, generationState.playlist!),
              icon: const Icon(Icons.copy),
              tooltip: 'Copy playlist to clipboard',
            ),
        ],
      ),
      body: _buildBody(context, ref, generationState, runPlan),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    PlaylistGenerationState state,
    RunPlan? runPlan,
  ) {
    // No run plan saved
    if (runPlan == null && !state.isLoading && state.playlist == null) {
      return _NoRunPlanView(
        onGoToRunPlan: () => context.push('/my-runs'),
      );
    }

    // Loading
    if (state.isLoading) {
      return const _LoadingView();
    }

    // Error
    if (state.error != null) {
      return _ErrorView(
        error: state.error!,
        onRetry: () => ref
            .read(playlistGenerationProvider.notifier)
            .generatePlaylist(),
      );
    }

    // Loaded with playlist
    if (state.playlist != null) {
      return _PlaylistView(
        playlist: state.playlist!,
        onShuffle: () => ref
            .read(playlistGenerationProvider.notifier)
            .shufflePlaylist(),
        onGenerate: () => ref
            .read(playlistGenerationProvider.notifier)
            .generatePlaylist(),
      );
    }

    // Idle with run plan -- show generate prompt
    return _IdleView(
      runPlan: runPlan!,
      onGenerate: () => ref
          .read(playlistGenerationProvider.notifier)
          .generatePlaylist(),
    );
  }

  Future<void> _copyPlaylist(BuildContext context, Playlist playlist) async {
    await Clipboard.setData(ClipboardData(text: playlist.toClipboardText()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playlist copied to clipboard!')),
      );
    }
  }
}

/// Shown when the user has no saved run plan.
class _NoRunPlanView extends StatelessWidget {
  const _NoRunPlanView({required this.onGoToRunPlan});

  final VoidCallback onGoToRunPlan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_run, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No Run Plan',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a run plan first to generate a playlist matched to '
              'your cadence.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onGoToRunPlan,
              icon: const Icon(Icons.timer),
              label: const Text('Create Run Plan'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown while the playlist is being generated.
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Finding songs for your run...',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Matching BPM to your cadence',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

/// Shown when generation fails.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when a run plan is saved but no playlist has been generated yet.
class _IdleView extends ConsumerWidget {
  const _IdleView({required this.runPlan, required this.onGenerate});

  final RunPlan runPlan;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.queue_music, size: 64, color: Colors.blue),
            const SizedBox(height: 24),
            // Selectors
            _RunPlanSelector(),
            const SizedBox(height: 8),
            _TasteProfileSelector(),
            const SizedBox(height: 8),
            _FreshnessToggle(),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Generate Playlist'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays the generated playlist grouped by segment with cadence nudge.
class _PlaylistView extends ConsumerWidget {
  const _PlaylistView({
    required this.playlist,
    required this.onShuffle,
    required this.onGenerate,
  });

  final Playlist playlist;
  final VoidCallback onShuffle;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strideState = ref.watch(strideNotifierProvider);
    final cadence = strideState.cadence.round();

    if (playlist.songs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.music_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No songs found',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'No songs matched your run plan BPM. Try adjusting your '
                'pace or taste profile.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onGenerate,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final starCount =
        playlist.songs.where((s) => (s.runningQuality ?? 0) >= 12).length;

    return Column(
      children: [
        // Summary header card
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primaryContainer,
                theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.queue_music_rounded,
                  size: 32, color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${playlist.songs.length} songs for your run',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$starCount top picks'
                      '  \u00b7  '
                      '${formatDuration(playlist.totalDurationSeconds)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: onShuffle,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Shuffle'),
              ),
            ],
          ),
        ),
        // Selectors + Generate
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(child: _RunPlanSelector()),
              const SizedBox(width: 8),
              Expanded(child: _TasteProfileSelector()),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: onGenerate,
                icon: const Icon(
                  Icons.play_arrow_rounded,
                  size: 18,
                ),
                label: const Text('Generate'),
              ),
            ],
          ),
        ),
        // Freshness mode toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _FreshnessToggle(),
        ),
        const SizedBox(height: 4),
        // Cadence nudge row
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => ref
                    .read(strideNotifierProvider.notifier)
                    .nudgeCadence(-3),
                icon: const Icon(Icons.keyboard_double_arrow_left),
                tooltip: '-3 spm',
                iconSize: 20,
              ),
              IconButton(
                onPressed: () => ref
                    .read(strideNotifierProvider.notifier)
                    .nudgeCadence(-1),
                icon: const Icon(Icons.chevron_left),
                tooltip: '-1 spm',
                iconSize: 20,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
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
                icon: const Icon(Icons.chevron_right),
                tooltip: '+1 spm',
                iconSize: 20,
              ),
              IconButton(
                onPressed: () => ref
                    .read(strideNotifierProvider.notifier)
                    .nudgeCadence(3),
                icon: const Icon(Icons.keyboard_double_arrow_right),
                tooltip: '+3 spm',
                iconSize: 20,
              ),
            ],
          ),
        ),
        // Song list grouped by segment
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: playlist.songs.length,
            itemBuilder: (context, index) {
              final song = playlist.songs[index];
              final showSegmentHeader = index == 0 ||
                  playlist.songs[index - 1].segmentLabel !=
                      song.segmentLabel;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showSegmentHeader)
                    SegmentHeader(label: song.segmentLabel),
                  Dismissible(
                    key: ValueKey('${song.title}-${song.artistName}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .errorContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context)
                            .colorScheme
                            .onErrorContainer,
                      ),
                    ),
                    onDismissed: (_) => _onSongDismissed(
                      context,
                      ref,
                      index,
                    ),
                    child: SongTile(song: song, index: index + 1),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _onSongDismissed(
    BuildContext context,
    WidgetRef ref,
    int index,
  ) {
    final suggestions = ref
        .read(playlistGenerationProvider.notifier)
        .removeSong(index);

    if (suggestions.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => _ReplacementSheet(
        suggestions: suggestions,
        onSelect: (replacement) {
          Navigator.pop(ctx);
          ref
              .read(playlistGenerationProvider.notifier)
              .insertSong(index, replacement);
        },
      ),
    );
  }
}

/// Tappable run plan selector row that opens a bottom sheet.
class _RunPlanSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(runPlanLibraryProvider);
    final selected = libraryState.selectedPlan;
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showRunPlanSheet(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.directions_run,
                size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selected != null
                    ? (selected.name ??
                        '${selected.distanceKm.toStringAsFixed(1)} km ${selected.type.name}')
                    : 'Select Run Plan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected != null
                      ? null
                      : theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.expand_more,
                size: 18, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  void _showRunPlanSheet(BuildContext context, WidgetRef ref) {
    final libraryState = ref.read(runPlanLibraryProvider);

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => _RunPlanSelectorSheet(
        plans: libraryState.plans,
        selectedId: libraryState.selectedPlan?.id,
        onSelect: (id) {
          Navigator.pop(ctx);
          ref.read(runPlanLibraryProvider.notifier).selectPlan(id);
        },
      ),
    );
  }
}

/// Tappable taste profile selector row that opens a bottom sheet.
class _TasteProfileSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(tasteProfileLibraryProvider);
    final selected = libraryState.selectedProfile;
    final theme = Theme.of(context);

    String subtitle;
    if (selected != null) {
      subtitle = selected.name ??
          selected.genres.map((g) => g.displayName).take(2).join(', ');
    } else {
      subtitle = 'Select Taste Profile';
    }

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showTasteProfileSheet(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.music_note,
                size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected != null
                      ? null
                      : theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.expand_more,
                size: 18, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  void _showTasteProfileSheet(BuildContext context, WidgetRef ref) {
    final libraryState = ref.read(tasteProfileLibraryProvider);

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => _TasteProfileSelectorSheet(
        profiles: libraryState.profiles,
        selectedId: libraryState.selectedProfile?.id,
        onSelect: (id) {
          Navigator.pop(ctx);
          ref
              .read(tasteProfileLibraryProvider.notifier)
              .selectProfile(id);
        },
      ),
    );
  }
}

/// Bottom sheet for selecting a run plan.
class _RunPlanSelectorSheet extends StatelessWidget {
  const _RunPlanSelectorSheet({
    required this.plans,
    required this.selectedId,
    required this.onSelect,
  });

  final List<RunPlan> plans;
  final String? selectedId;
  final void Function(String id) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (plans.isEmpty) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('No Run Plans', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('Create a run plan first.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/my-runs');
                },
                child: const Text('Create Run Plan'),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Select Run Plan',
                style: theme.textTheme.titleMedium),
          ),
          const Divider(height: 1),
          ...plans.map((plan) {
            final isSelected = plan.id == selectedId;
            return ListTile(
              leading: Icon(
                Icons.directions_run,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(
                plan.name ?? '${plan.distanceKm.toStringAsFixed(1)} km run',
                style: TextStyle(
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? theme.colorScheme.primary : null,
                ),
              ),
              subtitle: Text(
                '${plan.distanceKm.toStringAsFixed(1)} km'
                '  \u00b7  '
                '${formatDuration(plan.totalDurationSeconds)}',
              ),
              trailing:
                  isSelected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
              onTap: () => onSelect(plan.id),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Bottom sheet for selecting a taste profile.
class _TasteProfileSelectorSheet extends StatelessWidget {
  const _TasteProfileSelectorSheet({
    required this.profiles,
    required this.selectedId,
    required this.onSelect,
  });

  final List<TasteProfile> profiles;
  final String? selectedId;
  final void Function(String id) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (profiles.isEmpty) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('No Taste Profiles', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('Create a taste profile first.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/taste-profiles');
                },
                child: const Text('Create Profile'),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Select Taste Profile',
                style: theme.textTheme.titleMedium),
          ),
          const Divider(height: 1),
          ...profiles.map((profile) {
            final isSelected = profile.id == selectedId;
            final genreText =
                profile.genres.map((g) => g.displayName).join(', ');
            return ListTile(
              leading: Icon(
                Icons.music_note,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(
                profile.name ?? genreText,
                style: TextStyle(
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? theme.colorScheme.primary : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: profile.name != null
                  ? Text(genreText,
                      maxLines: 1, overflow: TextOverflow.ellipsis)
                  : null,
              trailing:
                  isSelected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
              onTap: () => onSelect(profile.id),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Toggle between keep-it-fresh and optimize-for-taste modes.
///
/// Uses a Material 3 [SegmentedButton] for compact, consistent styling
/// with existing selector patterns. The selected mode persists via
/// SharedPreferences through [freshnessModeProvider].
class _FreshnessToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(freshnessModeProvider);

    return SegmentedButton<FreshnessMode>(
      segments: const [
        ButtonSegment(
          value: FreshnessMode.keepItFresh,
          label: Text('Keep it Fresh'),
          icon: Icon(Icons.auto_awesome),
        ),
        ButtonSegment(
          value: FreshnessMode.optimizeForTaste,
          label: Text('Best Taste'),
          icon: Icon(Icons.favorite),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selected) {
        ref.read(freshnessModeProvider.notifier).setMode(selected.first);
      },
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// Bottom sheet showing replacement suggestions after removing a song.
class _ReplacementSheet extends StatelessWidget {
  const _ReplacementSheet({
    required this.suggestions,
    required this.onSelect,
  });

  final List<PlaylistSong> suggestions;
  final void Function(PlaylistSong) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Replace with...',
              style: theme.textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          ...suggestions.map(
            (song) => ListTile(
              leading: Icon(
                Icons.music_note,
                color: theme.colorScheme.primary,
              ),
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(song.artistName),
              trailing: Text(
                '${song.bpm} BPM',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () => onSelect(song),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip'),
            ),
          ),
        ],
      ),
    );
  }
}
