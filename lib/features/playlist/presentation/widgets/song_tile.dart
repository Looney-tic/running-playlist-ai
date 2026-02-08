import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_song.dart';
import 'package:running_playlist_ai/features/playlist/domain/playlist.dart';
import 'package:running_playlist_ai/features/song_feedback/domain/song_feedback.dart';
import 'package:running_playlist_ai/features/song_feedback/providers/song_feedback_providers.dart';
import 'package:url_launcher/url_launcher.dart';

/// Individual song tile with tap-to-open external link and feedback icons.
///
/// Shows song title, artist with match type label, BPM, and inline
/// like/dislike icons. Tapping the tile opens a bottom sheet with
/// Spotify/YouTube play options. Used by both the playlist screen
/// and the playlist history detail screen.
class SongTile extends ConsumerWidget {
  const SongTile({required this.song, this.index, super.key});

  final PlaylistSong song;

  /// 1-based song index within the full playlist (shown as track number).
  final int? index;

  /// Quality threshold for showing the star badge.
  /// Adjusted for max score 42 (was 12 for max 28).
  static const _starThreshold = 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final feedbackMap = ref.watch(songFeedbackProvider);
    final feedback = feedbackMap[song.lookupKey];
    // null = no feedback, true = liked, false = disliked
    final isLiked = feedback?.isLiked;
    final quality = song.runningQuality;
    final showStar = quality != null && quality >= _starThreshold;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: theme.colorScheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showPlayOptions(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Track number
              SizedBox(
                width: 28,
                child: Text(
                  index != null ? '$index' : '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Song info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (showStar) ...[
                          const Icon(Icons.star_rounded,
                              size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${song.artistName}${_matchLabel(song.matchType)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Feedback icons
              SizedBox(
                width: 64,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _feedbackIcon(
                      context: context,
                      icon: (isLiked ?? false)
                          ? Icons.thumb_up
                          : Icons.thumb_up_outlined,
                      color: (isLiked ?? false)
                          ? Colors.green
                          : theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5),
                      tooltip: 'Like',
                      onPressed: () => _onToggleLike(ref),
                      size: 18,
                    ),
                    _feedbackIcon(
                      context: context,
                      icon: isLiked == false
                          ? Icons.thumb_down
                          : Icons.thumb_down_outlined,
                      color: isLiked == false
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5),
                      tooltip: 'Dislike',
                      onPressed: () => _onToggleDislike(ref),
                      size: 18,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // BPM chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${song.bpm}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _matchLabel(BpmMatchType type) {
    switch (type) {
      case BpmMatchType.exact:
        return '';
      case BpmMatchType.halfTime:
        return '  \u00b7  half-time';
      case BpmMatchType.doubleTime:
        return '  \u00b7  double-time';
    }
  }

  Widget _feedbackIcon({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
    required double size,
  }) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        iconSize: size,
        icon: Icon(icon, color: color),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  void _onToggleLike(WidgetRef ref) {
    final notifier = ref.read(songFeedbackProvider.notifier);
    final key = song.lookupKey;
    final existing = notifier.getFeedback(key);

    if (existing != null && existing.isLiked) {
      // Already liked -- toggle off
      notifier.removeFeedback(key);
    } else {
      // Set to liked (overrides disliked if present)
      notifier.addFeedback(SongFeedback(
        songKey: key,
        isLiked: true,
        feedbackDate: DateTime.now(),
        songTitle: song.title,
        songArtist: song.artistName,
      ));
    }
  }

  void _onToggleDislike(WidgetRef ref) {
    final notifier = ref.read(songFeedbackProvider.notifier);
    final key = song.lookupKey;
    final existing = notifier.getFeedback(key);

    if (existing != null && !existing.isLiked) {
      // Already disliked -- toggle off
      notifier.removeFeedback(key);
    } else {
      // Set to disliked (overrides liked if present)
      notifier.addFeedback(SongFeedback(
        songKey: key,
        isLiked: false,
        feedbackDate: DateTime.now(),
        songTitle: song.title,
        songArtist: song.artistName,
      ));
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
