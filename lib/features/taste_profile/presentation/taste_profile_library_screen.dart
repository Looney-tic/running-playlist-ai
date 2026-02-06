import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:running_playlist_ai/features/taste_profile/domain/taste_profile.dart';
import 'package:running_playlist_ai/features/taste_profile/providers/taste_profile_providers.dart';

/// Screen listing all saved taste profiles with selection, edit, and delete.
class TasteProfileLibraryScreen extends ConsumerWidget {
  const TasteProfileLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(tasteProfileLibraryProvider);
    final profiles = libraryState.profiles;
    final selectedId = libraryState.selectedProfile?.id;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Taste Profiles')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/taste-profile'),
        child: const Icon(Icons.add),
      ),
      body: profiles.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.music_note,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 16),
                    const Text(
                      'No saved profiles',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your first taste profile to personalize playlists.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => context.push('/taste-profile'),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Profile'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: profiles.length,
              itemBuilder: (context, index) {
                final profile = profiles[index];
                final isSelected = profile.id == selectedId;
                return _TasteProfileCard(
                  profile: profile,
                  isSelected: isSelected,
                  onTap: () => ref
                      .read(tasteProfileLibraryProvider.notifier)
                      .selectProfile(profile.id),
                  onEdit: () =>
                      context.push('/taste-profile?id=${profile.id}'),
                  onDelete: () => ref
                      .read(tasteProfileLibraryProvider.notifier)
                      .deleteProfile(profile.id),
                );
              },
            ),
    );
  }
}

class _TasteProfileCard extends StatelessWidget {
  const _TasteProfileCard({
    required this.profile,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final TasteProfile profile;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final genreText = profile.genres.map((g) => g.displayName).join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : theme.colorScheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.music_note,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name ?? _defaultName(profile),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color:
                            isSelected ? theme.colorScheme.primary : null,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      genreText.isNotEmpty ? genreText : 'No genres',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: Icon(
                  Icons.edit_outlined,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                tooltip: 'Edit',
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                  size: 20,
                ),
                tooltip: 'Delete',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _defaultName(TasteProfile profile) {
    if (profile.genres.isNotEmpty) {
      return '${profile.genres.first.displayName} Mix';
    }
    return 'Taste Profile';
  }
}
