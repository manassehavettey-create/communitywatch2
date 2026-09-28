import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../utils/day_key.dart';
import '../utils/format.dart';
import 'pressable.dart';

/// Capsule date pills (Sun 22 · Mon 23 …) with an activity dot, as in the
/// "Daily challenge" reference.
class DayStrip extends StatelessWidget {
  const DayStrip({
    super.key,
    required this.days,
    required this.selected,
    required this.today,
    required this.hasActivity,
    required this.onSelect,
  });

  final List<DayKey> days;
  final DayKey selected;
  final DayKey today;
  final bool Function(DayKey) hasActivity;
  final ValueChanged<DayKey> onSelect;

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return Row(
      children: [
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: _pill(context, days[i], gl)),
        ],
      ],
    );
  }

  Widget _pill(BuildContext context, DayKey day, GLColors gl) {
    final isSelected = day == selected;
    final isFuture = day > today;
    final active = hasActivity(day);
    final fg = isSelected ? gl.onInverse : gl.text;
    final label = Fmt.weekdayShort(day);
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${Fmt.dayLabel(day, today)}${active ? ', has activity' : ''}',
      child: Pressable(
        onTap: isFuture ? null : () => onSelect(day),
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.standard,
          height: 76,
          decoration: BoxDecoration(
            color: isSelected ? gl.inverse : Colors.transparent,
            borderRadius: Radii.pillR,
            border: Border.all(
              color: isSelected ? gl.inverse : gl.hairline,
              width: 1.2,
            ),
          ),
          child: Opacity(
            opacity: isFuture ? 0.4 : 1,
            child: ExcludeSemantics(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedOpacity(
                    duration: Motion.fast,
                    opacity: active ? 1 : 0,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isSelected ? Palette.lime : gl.text,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: AppText.caption.copyWith(
                      color: fg.withValues(alpha: isSelected ? 0.8 : 0.6),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day % 100}',
                    style: AppText.subtitle.copyWith(color: fg, fontSize: 17),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
