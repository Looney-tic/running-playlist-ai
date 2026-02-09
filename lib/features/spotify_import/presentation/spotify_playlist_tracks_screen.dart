import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/running_songs/domain/running_song.dart';
import 'package:running_playlist_ai/features/running_songs/providers/running_song_providers.dart';
import 'package:running_playlist_ai/features/song_feedback/domain/song_feedback.dart';
import 'package:running_playlist_ai/features/spotify_import/domain/spotify_playlist_service.dart';
import 'package:running_playlist_ai/features/spotify_import/providers/spotify_import_providers.dart';

/// Screen for browsing tracks in a Spotify playlist with multi-select import.
///
/// Displays tracks with checkboxes for selection. Already-imported tracks
/// are visually indicated with a green check and excluded from re-import.
/// A bottom bar shows the import button with the count of selected tracks.
class SpotifyPlaylistTracksScreen extends ConsumerStatefulWidget {
  const SpotifyPlaylistTracksScreen({
    required this.playlistId,
    this.playlistName,
    super.key,
  });

  /// Spotify playlist ID used to fetch tracks.
  final String playlistId;

  /// Display name for the app bar, if available.
  final String? playlistName;

  @override
  ConsumerState<SpotifyPlaylistTracksScreen> createState() =>
      _SpotifyPlaylistTracksScreenState();
}

class _SpotifyPlaylistTracksScreenState
    extends ConsumerState<SpotifyPlaylistTracksScreen> {
  List<SpotifyPlaylistTrack>? _tracks;
  bool _loading = true;
  String? _error;
  Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = ref.read(spotifyPlaylistServiceProvider);
      final tracks = await service.getPlaylistTracks(widget.playlistId);
      if (mounted) {
        setState(() {
          _tracks = tracks;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load tracks. Please try again.';
          _loading = false;
        });
      }
    }
  }

  /// Returns the set of indices for tracks already in "Songs I Run To".
  Set<int> _importedIndices(Map<String, RunningSong> songsMap) {
    final tracks = _tracks;
    if (tracks == null) return {};
    final imported = <int>{};
    for (var i = 0; i < tracks.length; i++) {
      final key = SongKey.normalize(tracks[i].artist, tracks[i].title);
      if (songsMap.containsKey(key)) {
        imported.add(i);
      }
    }
    return imported;
  }

  /// Count of selected tracks that are not already imported.
  int _importableCount(Set<int> imported) {
    return _selectedIndices.where((i) => !imported.contains(i)).length;
  }

  void _toggleSelectAll(Set<int> imported) {
    final tracks = _tracks;
    if (tracks == null) return;

    final selectableIndices = <int>{};
    for (var i = 0; i < tracks.length; i++) {
      if (!imported.contains(i)) {
        selectableIndices.add(i);
      }
    }

    setState(() {
      if (_selectedIndices.containsAll(selectableIndices)) {
        // Deselect all
        _selectedIndices = {};
      } else {
        // Select all non-imported
        _selectedIndices = Set<int>.from(selectableIndices);
      }
    });
  }

  Future<void> _importSelected(Set<int> imported) async {
    final tracks = _tracks;
    if (tracks == null) return;

    // Capture ref before async gap per project convention.
    final notifier = ref.read(runningSongProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    final runningSongs = <RunningSong>[];
    for (final index in _selectedIndices) {
      if (imported.contains(index)) continue;
      final track = tracks[index];
      final songKey = SongKey.normalize(track.artist, track.title);
      runningSongs.add(
        RunningSong(
          songKey: songKey,
          artist: track.artist,
          title: track.title,
          addedDate: DateTime.now(),
          source: RunningSongSource.spotify,
        ),
      );
    }

    if (runningSongs.isEmpty) return;

    final added = await notifier.addSongs(runningSongs);

    messenger.showSnackBar(
      SnackBar(
        content: Text('$added songs imported'),
        duration: const Duration(seconds: 2),
      ),
    );

    setState(() {
      _selectedIndices = {};
    });
  }

  @override
  Widget build(BuildContext context) {
    final songsMap = ref.watch(runningSongProvider);
    final imported = _importedIndices(songsMap);
    final importableCount = _importableCount(imported);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlistName ?? 'Playlist Tracks'),
        actions: [
          if (_tracks != null && _tracks!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'Select All / Deselect All',
              onPressed: () => _toggleSelectAll(imported),
            ),
        ],
      ),
      body: _buildBody(context, songsMap, imported),
      bottomNavigationBar: (_tracks != null && _tracks!.isNotEmpty)
          ? BottomAppBar(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: FilledButton(
                  onPressed: importableCount > 0
                      ? () => _importSelected(imported)
                      : null,
                  child: Text('Import $importableCount Songs'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(
    BuildContext context,
    Map<String, RunningSong> songsMap,
    Set<int> imported,
  ) {
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
                onPressed: _loadTracks,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final tracks = _tracks;
    if (tracks == null || tracks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No tracks in this playlist',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final isImported = imported.contains(index);
        final isSelected = _selectedIndices.contains(index);

        return _TrackItem(
          track: track,
          isImported: isImported,
          isSelected: isSelected || isImported,
          onChanged: isImported
              ? null
              : (value) {
                  setState(() {
                    if (value ?? false) {
                      _selectedIndices.add(index);
                    } else {
                      _selectedIndices.remove(index);
                    }
                  });
                },
        );
      },
    );
  }
}

/// Displays a single track with checkbox, artwork, title, and artist.
class _TrackItem extends StatelessWidget {
  const _TrackItem({
    required this.track,
    required this.isImported,
    required this.isSelected,
    required this.onChanged,
  });

  final SpotifyPlaylistTrack track;
  final bool isImported;
  final bool isSelected;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Checkbox(
        value: isSelected,
        onChanged: onChanged,
      ),
      title: Row(
        children: [
          _buildArtwork(theme),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
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
        ],
      ),
      trailing: isImported
          ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
          : null,
    );
  }

  Widget _buildArtwork(ThemeData theme) {
    if (track.imageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          track.imageUrl!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(theme),
        ),
      );
    }
    return _buildPlaceholder(theme);
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        Icons.music_note,
        color: theme.colorScheme.onSurfaceVariant,
        size: 20,
      ),
    );
  }

  String _buildSubtitle() {
    final parts = <String>[track.artist];
    if (track.durationMs != null) {
      final totalSeconds = track.durationMs! ~/ 1000;
      final minutes = totalSeconds ~/ 60;
      final seconds = totalSeconds % 60;
      parts.add('$minutes:${seconds.toString().padLeft(2, '0')}');
    }
    return parts.join(' \u2022 ');
  }
}
