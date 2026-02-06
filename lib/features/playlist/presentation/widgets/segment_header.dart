import 'package:flutter/material.dart';

/// Segment header row used in playlist song lists.
///
/// Shows the segment label (e.g. "Warm-up", "Sprint") as a styled
/// banner between groups of songs with a context-appropriate icon.
/// Used by both the playlist screen and the playlist history detail screen.
class SegmentHeader extends StatelessWidget {
  const SegmentHeader({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = _iconForSegment(label);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForSegment(String label) {
    final lower = label.toLowerCase();
    if (lower == 'warm-up') return Icons.whatshot_outlined;
    if (lower == 'cool-down') return Icons.ac_unit;
    if (lower.startsWith('rest')) return Icons.pause_circle_outline;
    if (lower.startsWith('work') || lower == 'sprint') {
      return Icons.flash_on;
    }
    return Icons.directions_run;
  }
}
