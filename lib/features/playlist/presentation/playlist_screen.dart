import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_song.dart';
import 'package:running_playlist_ai/features/playlist/domain/playlist.dart';
import 'package:running_playlist_ai/features/playlist/providers/playlist_providers.dart';
import 'package:running_playlist_ai/features/run_plan/domain/run_plan.dart';
import 'package:running_playlist_ai/features/run_plan/providers/run_plan_providers.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen for generating and displaying a BPM-matched playlist.
///
/// States:
/// - No run plan: shows message directing user to create one
/// - Idle (with run plan): shows Generate button with run plan summary
/// - Loading: shows progress indicator
/// - Loaded: shows playlist grouped by segment with song cards
/// - Error: shows error message with retry button
class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final generationState = ref.watch(playlistGenerationProvider);
    final runPlan = ref.watch(runPlanNotifierProvider);

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
        onGoToRunPlan: () => context.push('/run-plan'),
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
        onRegenerate: () => ref
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
class _IdleView extends StatelessWidget {
  const _IdleView({required this.runPlan, required this.onGenerate});

  final RunPlan runPlan;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.queue_music, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              runPlan.name ?? 'Your Run Plan',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${runPlan.distanceKm.toStringAsFixed(1)} km '
              '${formatDuration(runPlan.totalDurationSeconds)} '
              '${runPlan.segments.length} '
              'segment${runPlan.segments.length == 1 ? "" : "s"}',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
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

/// Displays the generated playlist grouped by segment.
class _PlaylistView extends StatelessWidget {
  const _PlaylistView({required this.playlist, required this.onRegenerate});

  final Playlist playlist;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
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
                onPressed: onRegenerate,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Summary header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${playlist.songs.length} songs for your run',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onRegenerate,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Regenerate'),
              ),
            ],
          ),
        ),
        const Divider(),
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
                    _SegmentHeader(label: song.segmentLabel),
                  _SongTile(song: song),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Segment header row in the playlist list.
class _SegmentHeader extends StatelessWidget {
  const _SegmentHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Individual song tile with tap-to-open external link.
class _SongTile extends StatelessWidget {
  const _SongTile({required this.song});

  final PlaylistSong song;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${song.artistName}  ${_matchLabel(song.matchType)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '${song.bpm} BPM',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () => _showPlayOptions(context),
    );
  }

  String _matchLabel(BpmMatchType type) {
    switch (type) {
      case BpmMatchType.exact:
        return '';
      case BpmMatchType.halfTime:
        return '(half-time)';
      case BpmMatchType.doubleTime:
        return '(double-time)';
    }
  }

  void _showPlayOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${song.title} - ${song.artistName}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const Divider(height: 1),
            if (song.spotifyUrl != null)
              ListTile(
                leading: const Icon(Icons.music_note),
                title: const Text('Open in Spotify'),
                onTap: () {
                  Navigator.pop(context);
                  _launchUrl(context, song.spotifyUrl!);
                },
              ),
            if (song.youtubeUrl != null)
              ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: const Text('Open in YouTube Music'),
                onTap: () {
                  Navigator.pop(context);
                  _launchUrl(context, song.youtubeUrl!);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }
}
