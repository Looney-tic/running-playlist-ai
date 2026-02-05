import 'package:flutter/material.dart';
import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_song.dart';
import 'package:running_playlist_ai/features/playlist/domain/playlist.dart';
import 'package:url_launcher/url_launcher.dart';

/// Individual song tile with tap-to-open external link.
///
/// Shows song title, artist with match type label, and BPM. Tapping opens
/// a bottom sheet with Spotify/YouTube play options. Used by both
/// the playlist screen and the playlist history detail screen.
class SongTile extends StatelessWidget {
  const SongTile({required this.song, super.key});

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
