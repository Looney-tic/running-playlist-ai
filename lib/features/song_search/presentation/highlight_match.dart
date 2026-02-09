import 'package:flutter/widgets.dart';

/// Builds a list of [TextSpan]s that highlight all occurrences of [query]
/// within [source] using bold weight and [highlightColor].
///
/// Matching is case-insensitive but the original casing of [source] is
/// preserved in the output spans. Returns a single unstyled span when
/// [query] is empty or has no matches.
///
/// Example:
/// ```dart
/// highlightMatches('Hello World', 'lo', baseStyle, Colors.blue)
/// // -> [TextSpan('Hel'), TextSpan('lo', bold+blue), TextSpan(' World')]
/// ```
List<TextSpan> highlightMatches(
  String source,
  String query,
  TextStyle? baseStyle,
  Color highlightColor,
) {
  if (query.isEmpty) {
    return [TextSpan(text: source, style: baseStyle)];
  }

  final lowerSource = source.toLowerCase();
  final lowerQuery = query.toLowerCase();
  final spans = <TextSpan>[];
  var start = 0;

  while (start < source.length) {
    final matchIndex = lowerSource.indexOf(lowerQuery, start);
    if (matchIndex == -1) {
      // No more matches -- add remaining text.
      spans.add(TextSpan(text: source.substring(start), style: baseStyle));
      break;
    }

    // Add non-matching segment before this match.
    if (matchIndex > start) {
      spans.add(
        TextSpan(text: source.substring(start, matchIndex), style: baseStyle),
      );
    }

    // Add the matching segment with highlight styling.
    spans.add(TextSpan(
      text: source.substring(matchIndex, matchIndex + lowerQuery.length),
      style: baseStyle?.copyWith(
            fontWeight: FontWeight.bold,
            color: highlightColor,
          ) ??
          TextStyle(fontWeight: FontWeight.bold, color: highlightColor),
    ));

    start = matchIndex + lowerQuery.length;
  }

  // Edge case: query matches at the very end, loop exits without trailing span.
  if (spans.isEmpty) {
    spans.add(TextSpan(text: source, style: baseStyle));
  }

  return spans;
}
