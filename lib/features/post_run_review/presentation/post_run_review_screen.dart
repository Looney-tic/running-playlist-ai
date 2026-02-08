import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:running_playlist_ai/features/playlist/presentation/widgets/segment_header.dart';
import 'package:running_playlist_ai/features/playlist/presentation/widgets/song_tile.dart';
import 'package:running_playlist_ai/features/post_run_review/providers/post_run_review_providers.dart';

/// Dedicated review screen showing all songs from the most recent playlist.
///
/// Users can like or dislike each song via [SongTile] feedback buttons
/// (shared `songFeedbackProvider`). Tapping Done or Skip marks the playlist
/// as reviewed and navigates back to the home screen.
class PostRunReviewScreen extends ConsumerWidget {
  const PostRunReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = ref.watch(unreviewedPlaylistProvider);

    // Guard: if playlist becomes null (e.g. already reviewed), pop back.
    if (playlist == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Your Playlist'),
        actions: [
          TextButton(
            onPressed: () => _dismiss(context, ref),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'How did these songs feel during your run?',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: () => _dismiss(context, ref),
                icon: const Icon(Icons.check),
                label: const Text('Done'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Pops back first, then marks the playlist as reviewed.
  ///
  /// Pop before state change avoids the reactive rebuild pitfall where
  /// the screen tries to rebuild with a null playlist before navigation
  /// completes.
  void _dismiss(BuildContext context, WidgetRef ref) {
    final playlist = ref.read(unreviewedPlaylistProvider);
    context.pop();
    if (playlist?.id != null) {
      ref
          .read(postRunReviewProvider.notifier)
          .markReviewed(playlist!.id!);
    }
  }
}
