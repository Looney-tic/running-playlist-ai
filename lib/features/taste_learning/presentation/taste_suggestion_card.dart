import 'package:flutter/material.dart';
import 'package:running_playlist_ai/features/taste_learning/domain/taste_suggestion.dart';

/// Actionable card showing a taste profile suggestion detected from
/// the user's song feedback patterns.
///
/// Displays the suggestion text, evidence count, and type-specific icon
/// with Accept (high emphasis) and Dismiss (low emphasis) action buttons.
///
/// Uses `tertiaryContainer` color to distinguish from setup cards
/// (`secondaryContainer`) while matching the post-run review visual style.
class TasteSuggestionCard extends StatelessWidget {
  const TasteSuggestionCard({
    required this.suggestion,
    required this.onAccept,
    required this.onDismiss,
    super.key,
  });

  final TasteSuggestion suggestion;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 8),
      child: Card(
        color: theme.colorScheme.tertiaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                _iconForType(suggestion.type),
                color: theme.colorScheme.onTertiaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.displayText,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      'Based on ${suggestion.evidenceCount} songs',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onDismiss,
                child: const Text('Dismiss'),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: onAccept,
                child: const Text('Accept'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(SuggestionType type) {
    return switch (type) {
      SuggestionType.addGenre => Icons.library_music,
      SuggestionType.addArtist => Icons.person_add,
      SuggestionType.removeArtist => Icons.person_off,
    };
  }
}
