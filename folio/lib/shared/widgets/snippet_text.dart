import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../data/repositories/search_repository.dart';

/// Renders a search snippet, marking matched terms.
class SnippetText extends StatelessWidget {
  const SnippetText(this.snippet, {super.key, this.style, this.maxLines = 3});
  final String snippet;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final mark = (style ?? const TextStyle()).copyWith(
      backgroundColor: context.colors.lavender.withValues(alpha: 0.35),
      fontWeight: FontWeight.w700,
    );
    final spans = <TextSpan>[];
    var inMatch = false;
    final buf = StringBuffer();
    void flush() {
      if (buf.isEmpty) return;
      spans.add(TextSpan(text: buf.toString(), style: inMatch ? mark : null));
      buf.clear();
    }

    for (final ch in snippet.characters) {
      if (ch == kMatchStart) {
        flush();
        inMatch = true;
      } else if (ch == kMatchEnd) {
        flush();
        inMatch = false;
      } else {
        buf.write(ch);
      }
    }
    flush();
    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
