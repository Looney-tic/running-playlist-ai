import 'package:flutter/material.dart';

/// Segment header row used in playlist song lists.
///
/// Shows the segment label (e.g. "Warm-up", "Sprint") as a full-width
/// banner between groups of songs. Used by both the playlist screen and
/// the playlist history detail screen.
class SegmentHeader extends StatelessWidget {
  const SegmentHeader({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
