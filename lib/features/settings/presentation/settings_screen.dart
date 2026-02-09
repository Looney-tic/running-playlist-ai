import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running_playlist_ai/features/spotify_auth/domain/spotify_auth_service.dart';
import 'package:running_playlist_ai/features/spotify_auth/providers/spotify_auth_providers.dart';

/// Application settings screen.
///
/// Provides user-facing controls for app configuration. Currently
/// includes a Spotify connection management section. Additional
/// settings sections can be added as children of the [ListView].
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: const [
          _SpotifySection(),
        ],
      ),
    );
  }
}

/// Spotify connection management section.
class _SpotifySection extends ConsumerWidget {
  const _SpotifySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(spotifyConnectionStatusSyncProvider);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              'Spotify',
              style: theme.textTheme.titleMedium,
            ),
          ),
          _SpotifyConnectionTile(status: status),
        ],
      ),
    );
  }
}

/// Tile displaying Spotify connection state with connect/disconnect actions.
class _SpotifyConnectionTile extends ConsumerWidget {
  const _SpotifyConnectionTile({required this.status});

  final SpotifyConnectionStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (status) {
      SpotifyConnectionStatus.disconnected => ListTile(
          leading: const Icon(Icons.music_note),
          title: const Text('Spotify'),
          subtitle: const Text('Not connected'),
          trailing: ElevatedButton(
            onPressed: () =>
                ref.read(spotifyAuthServiceProvider).connect(),
            child: const Text('Connect'),
          ),
        ),
      SpotifyConnectionStatus.connecting => const ListTile(
          leading: Icon(Icons.music_note),
          title: Text('Spotify'),
          subtitle: Text('Connecting...'),
          trailing: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
        ),
      SpotifyConnectionStatus.connected => ListTile(
          leading: const Icon(Icons.music_note, color: Colors.green),
          title: const Text('Spotify'),
          subtitle: const Text('Connected'),
          trailing: OutlinedButton(
            onPressed: () => _showDisconnectDialog(context, ref),
            child: const Text('Disconnect'),
          ),
        ),
      SpotifyConnectionStatus.error => ListTile(
          leading: const Icon(Icons.music_note, color: Colors.red),
          title: const Text('Spotify'),
          subtitle: const Text('Connection failed'),
          trailing: ElevatedButton(
            onPressed: () =>
                ref.read(spotifyAuthServiceProvider).connect(),
            child: const Text('Retry'),
          ),
        ),
    };
  }

  void _showDisconnectDialog(BuildContext context, WidgetRef ref) {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Disconnect Spotify?'),
        content: const Text(
          'You will need to reconnect to use Spotify features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(spotifyAuthServiceProvider).disconnect();
            },
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }
}
