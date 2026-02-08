import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/song_feedback/domain/song_feedback.dart';
import 'package:running_playlist_ai/features/song_feedback/providers/song_feedback_providers.dart';

/// Centralized feedback management screen with tabbed liked/disliked views.
///
/// Users can browse all their song feedback, flip songs between liked and
/// disliked, or remove feedback entirely. Changes take immediate effect in
/// the next playlist generation because this screen reads and mutates the
/// same [songFeedbackProvider] used by the playlist generator.
class SongFeedbackLibraryScreen extends ConsumerWidget {
  const SongFeedbackLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedbackMap = ref.watch(songFeedbackProvider);
    final allFeedback = feedbackMap.values.toList();

    if (allFeedback.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Song Feedback')),
        body: const _EmptyFeedbackView(),
      );
    }

    final liked = allFeedback.where((f) => f.isLiked).toList()
      ..sort((a, b) => b.feedbackDate.compareTo(a.feedbackDate));
    final disliked = allFeedback.where((f) => !f.isLiked).toList()
      ..sort((a, b) => b.feedbackDate.compareTo(a.feedbackDate));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Song Feedback'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Liked (${liked.length})'),
              Tab(text: 'Disliked (${disliked.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _FeedbackListView(items: liked, ref: ref),
            _FeedbackListView(items: disliked, ref: ref),
          ],
        ),
      ),
    );
  }
}

/// Shown when the user has no song feedback at all.
class _EmptyFeedbackView extends StatelessWidget {
  const _EmptyFeedbackView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.thumbs_up_down, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Feedback Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Like or dislike songs in your playlists to build '
              'your feedback library.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders a list of feedback items, or an empty-tab message.
class _FeedbackListView extends StatelessWidget {
  const _FeedbackListView({
    required this.items,
    required this.ref,
  });

  final List<SongFeedback> items;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No songs in this category',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final feedback = items[index];
        return _FeedbackCard(
          key: ValueKey(feedback.songKey),
          feedback: feedback,
          onFlip: () => _onFlipFeedback(ref, feedback),
          onRemove: () => _onRemoveFeedback(ref, feedback),
        );
      },
    );
  }
}

/// Displays a single feedback entry with flip and remove actions.
class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.feedback,
    required this.onFlip,
    required this.onRemove,
    super.key,
  });

  final SongFeedback feedback;
  final VoidCallback onFlip;
  final VoidCallback onRemove;

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
              feedback.isLiked ? Icons.thumb_up : Icons.thumb_down,
              color: feedback.isLiked
                  ? Colors.green
                  : theme.colorScheme.error,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feedback.songTitle,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${feedback.songArtist} \u2022 '
                    '${_formatDate(feedback.feedbackDate)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 18,
                icon: Icon(
                  feedback.isLiked
                      ? Icons.thumb_down_outlined
                      : Icons.thumb_up_outlined,
                ),
                tooltip: feedback.isLiked
                    ? 'Change to dislike'
                    : 'Change to like',
                onPressed: onFlip,
              ),
            ),
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 18,
                icon: const Icon(Icons.close),
                tooltip: 'Remove feedback',
                onPressed: onRemove,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Flips feedback from liked to disliked (or vice versa) with a fresh
/// timestamp.
void _onFlipFeedback(WidgetRef ref, SongFeedback feedback) {
  ref.read(songFeedbackProvider.notifier).addFeedback(
        feedback.copyWith(
          isLiked: !feedback.isLiked,
          feedbackDate: DateTime.now(),
        ),
      );
}

/// Removes feedback entirely for the given song.
void _onRemoveFeedback(WidgetRef ref, SongFeedback feedback) {
  ref.read(songFeedbackProvider.notifier).removeFeedback(feedback.songKey);
}

/// Formats a [DateTime] as dd/MM/yyyy.
String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
