import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Big editorial headline mixing heavy and light-italic Archivo, e.g.
/// "Activities *just for your taste*".
class DisplayTitle extends StatelessWidget {
  const DisplayTitle({
    super.key,
    required this.bold,
    this.italic,
    this.size = 40,
    this.color,
    this.italicFirst = false,
  });

  final String bold;
  final String? italic;
  final double size;
  final Color? color;
  final bool italicFirst;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.gl.text;
    final b = TextSpan(
      text: bold,
      style: AppText.display.copyWith(fontSize: size, color: c),
    );
    final i = italic == null
        ? null
        : TextSpan(
            text: italic,
            style: AppText.displayItalic.copyWith(fontSize: size, color: c),
          );
    return Semantics(
      header: true,
      child: Text.rich(
        TextSpan(
          children: [
            if (italicFirst && i != null) ...[i, const TextSpan(text: ' ')],
            b,
            if (!italicFirst && i != null) ...[const TextSpan(text: ' '), i],
          ],
        ),
      ),
    );
  }
}

/// Top of each tab: display title plus trailing circle buttons.
class TabHeader extends StatelessWidget {
  const TabHeader({
    super.key,
    required this.bold,
    this.italic,
    this.subtitle,
    this.actions = const [],
  });

  final String bold;
  final String? italic;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.gutter,
        MediaQuery.paddingOf(context).top + Space.md,
        Space.gutter,
        Space.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DisplayTitle(bold: bold, italic: italic),
                if (subtitle != null) ...[
                  const SizedBox(height: Space.xxs),
                  Text(subtitle!, style: context.text.bodyMedium?.copyWith(color: context.gl.muted)),
                ],
              ],
            ),
          ),
          for (final a in actions) ...[const SizedBox(width: Space.xs), a],
        ],
      ),
    );
  }
}
