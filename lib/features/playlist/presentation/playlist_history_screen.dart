import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:running_playlist_ai/features/playlist/domain/playlist.dart';
import 'package:running_playlist_ai/features/playlist/providers/playlist_history_providers.dart';

/// Screen showing a list of previously generated playlists.
///
/// Each entry shows the run plan name, date, distance, and pace.
/// Users can swipe to delete (with confirmation dialog) and tap to view
/// the full playlist in the detail screen.
class PlaylistHistoryScreen extends ConsumerWidget {
  const PlaylistHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Playlist History')),
      body: playlists.isEmpty
          ? const _EmptyHistoryView()
          : ListView.builder(
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                return Dismissible(
                  key: Key(playlist.id ?? index.toString()),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) => _confirmDelete(context),
                  onDismissed: (_) {
                    if (playlist.id != null) {
                      ref
                          .read(playlistHistoryProvider.notifier)
                          .deletePlaylist(playlist.id!);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Playlist deleted'),
                      ),
                    );
                  },
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child:
                        const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: ListTile(
                    title: Text(
                      playlist.runPlanName ?? 'Untitled Run',
                    ),
                    subtitle: Text(_formatSubtitle(playlist)),
                    trailing: Text(
                      '${playlist.songs.length} songs',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    onTap: () {
                      if (playlist.id != null) {
                        context.push(
                          '/playlist-history/${playlist.id}',
                        );
                      }
                    },
                  ),
                );
              },
            ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Playlist'),
        content: const Text(
          'Are you sure you want to delete this playlist?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatSubtitle(Playlist playlist) {
    final date = playlist.createdAt.toLocal();
    final dateStr = '${date.day}/${date.month}/${date.year}';
    final parts = <String>[dateStr];
    if (playlist.distanceKm != null) {
      parts.add('${playlist.distanceKm!.toStringAsFixed(1)} km');
    }
    if (playlist.paceMinPerKm != null) {
      final mins = playlist.paceMinPerKm!.floor();
      final secs =
          ((playlist.paceMinPerKm! - mins) * 60).round();
      parts.add("$mins'${secs.toString().padLeft(2, '0')}\"/km");
    }
    return parts.join(' - ');
  }
}

/// Shown when there are no saved playlists in history.
class _EmptyHistoryView extends StatelessWidget {
  const _EmptyHistoryView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No Playlists Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Generated playlists will appear here. '
              'Go generate your first playlist!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/playlist'),
              icon: const Icon(Icons.queue_music),
              label: const Text('Generate Playlist'),
            ),
          ],
        ),
      ),
    );
  }
}
