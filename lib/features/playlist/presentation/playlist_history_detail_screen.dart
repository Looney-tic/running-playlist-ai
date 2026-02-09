import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/playlist/domain/playlist.dart';
import 'package:running_playlist_ai/features/playlist/presentation/widgets/segment_header.dart';
import 'package:running_playlist_ai/features/playlist/presentation/widgets/song_tile.dart';
import 'package:running_playlist_ai/features/playlist/providers/playlist_history_providers.dart';
import 'package:running_playlist_ai/features/run_plan/domain/run_plan.dart';

/// Detail screen showing all tracks of a saved playlist from history.
///
/// Displays a summary header with date/distance/pace, followed by songs
/// grouped by segment using shared [SegmentHeader] and [SongTile] widgets.
class PlaylistHistoryDetailScreen extends ConsumerWidget {
  const PlaylistHistoryDetailScreen({
    required this.playlistId,
    super.key,
  });

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistHistoryProvider);
    final playlist =
        playlists.where((p) => p.id == playlistId).firstOrNull;

    if (playlist == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Playlist')),
        body: const Center(child: Text('Playlist not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.runPlanName ??
            (playlist.distanceKm != null
                ? '${playlist.distanceKm!.toStringAsFixed(1)} km Run'
                : 'Playlist')),
        actions: [
          IconButton(
            onPressed: () => _copyPlaylist(context, playlist),
            icon: const Icon(Icons.copy),
            tooltip: 'Copy playlist to clipboard',
          ),
        ],
      ),
      body: Column(
        children: [
          _PlaylistSummaryHeader(playlist: playlist),
          const Divider(),
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
                    SongTile(song: song),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyPlaylist(
    BuildContext context,
    Playlist playlist,
  ) async {
    await Clipboard.setData(
      ClipboardData(text: playlist.toClipboardText()),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Playlist copied to clipboard!'),
        ),
      );
    }
  }
}

/// Summary header showing song count, date, distance, pace, and duration.
class _PlaylistSummaryHeader extends StatelessWidget {
  const _PlaylistSummaryHeader({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final date = playlist.createdAt.toLocal();
    final dateStr =
        '${date.day}/${date.month}/${date.year} at '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${playlist.songs.length} songs',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _buildMetaLine(dateStr),
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  String _buildMetaLine(String dateStr) {
    final parts = <String>[dateStr];
    if (playlist.distanceKm != null) {
      parts.add(
        '${playlist.distanceKm!.toStringAsFixed(1)} km',
      );
    }
    if (playlist.paceMinPerKm != null) {
      final mins = playlist.paceMinPerKm!.floor();
      final secs =
          ((playlist.paceMinPerKm! - mins) * 60).round();
      parts.add(
        "$mins'${secs.toString().padLeft(2, '0')}\"/km",
      );
    }
    parts.add(formatDuration(playlist.totalDurationSeconds));
    return parts.join(' - ');
  }
}
