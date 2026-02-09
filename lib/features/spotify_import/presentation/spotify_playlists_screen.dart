import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:running_playlist_ai/features/spotify_import/domain/spotify_playlist_service.dart';
import 'package:running_playlist_ai/features/spotify_import/providers/spotify_import_providers.dart';

/// Screen for browsing the user's Spotify playlists.
///
/// Displays a list of playlists with cover images, names, and track counts.
/// Tapping a playlist navigates to the tracks screen for
/// track selection and import.
class SpotifyPlaylistsScreen extends ConsumerStatefulWidget {
  const SpotifyPlaylistsScreen({super.key});

  @override
  ConsumerState<SpotifyPlaylistsScreen> createState() =>
      _SpotifyPlaylistsScreenState();
}

class _SpotifyPlaylistsScreenState
    extends ConsumerState<SpotifyPlaylistsScreen> {
  List<SpotifyPlaylistInfo>? _playlists;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = ref.read(spotifyPlaylistServiceProvider);
      final playlists = await service.getUserPlaylists();
      if (mounted) {
        setState(() {
          _playlists = playlists;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load playlists. Please try again.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Spotify Playlists'),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadPlaylists,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final playlists = _playlists;
    if (playlists == null || playlists.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No playlists found',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return _PlaylistCard(playlist: playlist);
      },
    );
  }
}

/// Displays a single Spotify playlist with cover image, name, and track count.
class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({required this.playlist});

  final SpotifyPlaylistInfo playlist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: theme.colorScheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          context.push(
            '/spotify-playlists/${playlist.id}?name=${Uri.encodeComponent(playlist.name)}',
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _buildCoverImage(theme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _buildSubtitle(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImage(ThemeData theme) {
    if (playlist.imageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          playlist.imageUrl!,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(theme),
        ),
      );
    }
    return _buildPlaceholder(theme);
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        Icons.queue_music,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  String _buildSubtitle() {
    final parts = <String>[];
    if (playlist.trackCount != null) {
      parts.add('${playlist.trackCount} tracks');
    }
    if (playlist.ownerName != null) {
      parts.add(playlist.ownerName!);
    }
    return parts.join(' \u2022 ');
  }
}
