import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/running_songs/domain/bpm_compatibility.dart';
import 'package:running_playlist_ai/features/running_songs/domain/running_song.dart';
import 'package:running_playlist_ai/features/running_songs/providers/running_song_providers.dart';
import 'package:running_playlist_ai/features/stride/providers/stride_providers.dart';

/// Screen displaying the user's "Songs I Run To" collection.
///
/// Shows a sorted list of saved running songs (most recently added first)
/// with remove actions, or an empty state when no songs have been added yet.
class RunningSongsScreen extends ConsumerWidget {
  const RunningSongsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsMap = ref.watch(runningSongProvider);

    if (songsMap.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Songs I Run To')),
        body: const _EmptyRunningSongsView(),
      );
    }

    final songs = songsMap.values.toList()
      ..sort((a, b) => b.addedDate.compareTo(a.addedDate));

    final cadence = ref.watch(strideNotifierProvider).cadence.round();

    return Scaffold(
      appBar: AppBar(title: const Text('Songs I Run To')),
      body: ListView.builder(
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          return _RunningSongCard(
            key: ValueKey(song.songKey),
            song: song,
            cadence: cadence,
            ref: ref,
          );
        },
      ),
    );
  }
}

/// Shown when the user has no songs in their running collection.
class _EmptyRunningSongsView extends StatelessWidget {
  const _EmptyRunningSongsView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Running Songs Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Add songs from your generated playlists to build your '
              'personal running music collection.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays a single running song entry with remove action and BPM chip.
class _RunningSongCard extends StatelessWidget {
  const _RunningSongCard({
    required this.song,
    required this.cadence,
    required this.ref,
    super.key,
  });

  final RunningSong song;
  final int cadence;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.music_note,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${song.artist} \u2022 '
                          '${_formatDate(song.addedDate)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (song.source !=
                          RunningSongSource.curated) ...[
                        const SizedBox(width: 8),
                        Text(
                          song.source.name[0].toUpperCase() +
                              song.source.name.substring(1),
                          style: theme.textTheme.labelSmall
                              ?.copyWith(
                            color: theme.colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (song.bpm != null) ...[
              const SizedBox(width: 8),
              _BpmChip(bpm: song.bpm!, cadence: cadence),
            ],
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 18,
                icon: const Icon(Icons.close),
                tooltip: 'Remove from Songs I Run To',
                onPressed: () {
                  ref
                      .read(runningSongProvider.notifier)
                      .removeSong(song.songKey);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Colored BPM chip showing compatibility with the user's cadence.
///
/// Green for exact/half/double-time match, amber for close (within 5%),
/// gray for no meaningful relationship.
class _BpmChip extends StatelessWidget {
  const _BpmChip({required this.bpm, required this.cadence});

  final int bpm;
  final int cadence;

  @override
  Widget build(BuildContext context) {
    final compatibility = bpmCompatibility(songBpm: bpm, cadence: cadence);

    final Color chipColor;
    switch (compatibility) {
      case BpmCompatibility.match:
        chipColor = Colors.green;
      case BpmCompatibility.close:
        chipColor = Colors.amber;
      case BpmCompatibility.none:
        chipColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: chipColor, size: 14),
          const SizedBox(width: 4),
          Text(
            '$bpm',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Formats a [DateTime] as dd/MM/yyyy.
String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
