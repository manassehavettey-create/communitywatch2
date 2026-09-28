import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'pressable.dart';

/// "Today / Weekly / Monthly / Yearly" style selector: separate pills, the
/// selected one filled.
class SegmentedPills<T> extends StatelessWidget {
  const SegmentedPills({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.selectedColor,
    this.selectedForeground,
    this.expand = true,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final Color? selectedColor;
  final Color? selectedForeground;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    final children = [
      for (final v in values)
        _pill(
          context,
          v,
          v == selected,
          selectedColor ?? Palette.lime,
          selectedForeground ?? Palette.ink,
          gl,
        ),
    ];
    return Semantics(
      container: true,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: Space.xs),
            expand ? Expanded(child: children[i]) : children[i],
          ],
        ],
      ),
    );
  }

  Widget _pill(
    BuildContext context,
    T v,
    bool isSelected,
    Color selColor,
    Color selFg,
    GLColors gl,
  ) {
    return Semantics(
      selected: isSelected,
      button: true,
      label: labelOf(v),
      child: Pressable(
        onTap: isSelected ? null : () => onChanged(v),
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.standard,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? selColor : gl.surface,
            borderRadius: Radii.pillR,
            border: Border.all(color: isSelected ? selColor : gl.hairline),
          ),
          child: ExcludeSemantics(
            child: Text(
              labelOf(v),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: isSelected ? selFg : gl.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
