import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/running_songs/domain/running_song.dart';
import 'package:running_playlist_ai/features/running_songs/providers/running_song_providers.dart';
import 'package:running_playlist_ai/features/song_feedback/domain/song_feedback.dart';
import 'package:running_playlist_ai/features/song_search/domain/song_search_service.dart';
import 'package:running_playlist_ai/features/song_search/presentation/highlight_match.dart';
import 'package:running_playlist_ai/features/song_search/providers/song_search_providers.dart';

/// Screen for searching the song catalog and adding results to
/// the user's "Songs I Run To" collection.
///
/// Uses Flutter's [Autocomplete] widget with a debounced search
/// callback and highlighted matching text in results.
class SongSearchScreen extends ConsumerStatefulWidget {
  const SongSearchScreen({super.key});

  @override
  ConsumerState<SongSearchScreen> createState() => _SongSearchScreenState();
}

class _SongSearchScreenState extends ConsumerState<SongSearchScreen> {
  _Debounceable<List<SongSearchResult>?, String>? _debouncedSearch;
  Iterable<SongSearchResult> _lastOptions = const [];

  @override
  Widget build(BuildContext context) {
    final searchServiceAsync = ref.watch(songSearchServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Search Songs')),
      body: searchServiceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to load song catalog: $error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (searchService) {
          _debouncedSearch ??= _debounce<List<SongSearchResult>?, String>(
            (String query) => searchService.search(query),
          );
          return _buildSearchBody(context);
        },
      ),
    );
  }

  Widget _buildSearchBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Autocomplete<SongSearchResult>(
        optionsBuilder: (TextEditingValue textEditingValue) async {
          final text = textEditingValue.text;
          _lastQuery = text;
          if (text.length < 2) {
            return const Iterable<SongSearchResult>.empty();
          }

          final results = await _debouncedSearch!(text);
          if (results == null) {
            return _lastOptions;
          }
          _lastOptions = results;
          return results;
        },
        displayStringForOption: (result) =>
            '${result.artist} - ${result.title}',
        fieldViewBuilder: (
          BuildContext context,
          TextEditingController controller,
          FocusNode focusNode,
          VoidCallback onFieldSubmitted,
        ) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search by song or artist...',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => onFieldSubmitted(),
          );
        },
        optionsViewBuilder: (
          BuildContext context,
          AutocompleteOnSelected<SongSearchResult> onSelected,
          Iterable<SongSearchResult> options,
        ) {
          final query = _lastQuery;

          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: options.length,
                  itemBuilder: (BuildContext context, int index) {
                    final option = options.elementAt(index);
                    return _SearchResultTile(
                      option: option,
                      query: query,
                      onSelected: onSelected,
                      ref: ref,
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Tracks the last query text set by the options builder,
  /// so the options view builder can use it for highlighting.
  String _lastQuery = '';
}

/// A single search result list tile with highlighted text and add action.
class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.option,
    required this.query,
    required this.onSelected,
    required this.ref,
  });

  final SongSearchResult option;
  final String query;
  final AutocompleteOnSelected<SongSearchResult> onSelected;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final songsMap = ref.read(runningSongProvider);
    final songKey = SongKey.normalize(option.artist, option.title);
    final alreadyAdded = songsMap.containsKey(songKey);

    return ListTile(
      leading: Icon(
        alreadyAdded ? Icons.check_circle : Icons.add_circle_outline,
        color: alreadyAdded
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: RichText(
        text: TextSpan(
          children: highlightMatches(
            option.title,
            query,
            theme.textTheme.titleSmall,
            theme.colorScheme.primary,
          ),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: RichText(
        text: TextSpan(
          children: highlightMatches(
            option.artist,
            query,
            theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            theme.colorScheme.primary,
          ),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: option.bpm != null
          ? Text(
              '${option.bpm} BPM',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      onTap: () {
        if (alreadyAdded) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Already in your collection'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          _addToRunningSongs(ref, option);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${option.title} added to Songs I Run To'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        // Select the option to populate the text field.
        onSelected(option);
      },
    );
  }

  void _addToRunningSongs(WidgetRef ref, SongSearchResult result) {
    final songKey = SongKey.normalize(result.artist, result.title);
    ref.read(runningSongProvider.notifier).addSong(
          RunningSong(
            songKey: songKey,
            artist: result.artist,
            title: result.title,
            addedDate: DateTime.now(),
            bpm: result.bpm,
            genre: result.genre,
          ),
        );
  }
}

// ---------------------------------------------------------------------------
// Debounce pattern from Flutter SDK Autocomplete documentation.
// Uses Timer + Completer for clean cancellation of stale requests.
// ---------------------------------------------------------------------------

typedef _Debounceable<S, T> = Future<S> Function(T parameter);

/// Creates a debounced version of [function] that delays invocation
/// by [duration] and cancels stale in-flight calls.
///
/// Returns `null` for cancelled (stale) calls so the caller can
/// fall back to cached results.
_Debounceable<S?, T> _debounce<S, T>(
  _Debounceable<S, T> function, {
  Duration duration = const Duration(milliseconds: 300),
}) {
  _DebounceTimer? timer;

  return (T parameter) async {
    timer?.cancel();
    timer = _DebounceTimer(duration);
    try {
      await timer!.future;
    } on _CancelException {
      return null;
    }
    return function(parameter);
  };
}

class _DebounceTimer {
  _DebounceTimer(Duration duration) {
    _timer = Timer(duration, _onComplete);
  }

  late final Timer _timer;
  final Completer<void> _completer = Completer<void>();

  Future<void> get future => _completer.future;

  void _onComplete() {
    _completer.complete();
  }

  void cancel() {
    _timer.cancel();
    _completer.completeError(_CancelException());
  }
}

class _CancelException implements Exception {}
