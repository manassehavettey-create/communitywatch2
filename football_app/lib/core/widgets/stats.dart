import 'package:flutter/material.dart';

import '../../data/models/models.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'pressable.dart';

String formatStat(num? v, StatUnit unit) {
  if (v == null) return '—';
  return switch (unit) {
    StatUnit.percent => '${v.round()}%',
    StatUnit.decimal => v.toStringAsFixed(2),
    StatUnit.count => v.round().toString(),
  };
}

/// Two-sided comparison bar: home grows left from the centre in lime, away
/// grows right in violet; the leader is full-strength, the other dimmed.
/// Bars draw in on first build and glide on updates.
class StatCompareRow extends StatelessWidget {
  const StatCompareRow({super.key, required this.label, required this.home, required this.away, required this.unit, this.onTap, this.note, this.homeColor, this.awayColor});
  final String label;
  final num? home;
  final num? away;
  final StatUnit unit;
  final VoidCallback? onTap;
  final String? note;
  final Color? homeColor;
  final Color? awayColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final h = (home ?? 0).toDouble(), a = (away ?? 0).toDouble();
    final total = unit == StatUnit.percent && h + a <= 100.5 ? 100.0 : (h + a == 0 ? 1.0 : h + a);
    final hc = homeColor ?? c.accent, ac = awayColor ?? c.away;
    final hLead = h >= a, aLead = a >= h;
    final valueStyle = AppType.numeric(16, weight: 760, color: c.text);
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Column(children: [
          Row(children: [
            SizedBox(width: 56, child: Text(formatStat(home, unit), style: valueStyle.copyWith(color: hLead ? c.text : c.textMuted))),
            Expanded(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Flexible(child: Text(label, style: AppType.body(13.5, weight: 560, color: c.textMuted), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
                if (onTap != null) ...[const SizedBox(width: 4), Icon(Icons.help_outline_rounded, size: 13, color: c.textFaint)],
              ]),
            ),
            SizedBox(width: 56, child: Text(formatStat(away, unit), textAlign: TextAlign.right, style: valueStyle.copyWith(color: aLead ? c.text : c.textMuted))),
          ]),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: context.reduceMotion ? Duration.zero : Motion.draw,
            curve: Motion.emphasized,
            builder: (context, t, _) => Row(children: [
              Expanded(child: _Bar(fraction: t * h / total, color: hLead ? hc : hc.withValues(alpha: 0.35), alignRight: true)),
              const SizedBox(width: 6),
              Expanded(child: _Bar(fraction: t * a / total, color: aLead ? ac : ac.withValues(alpha: 0.35), alignRight: false)),
            ]),
          ),
          if (note != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(note!, style: AppType.body(11.5, color: c.textFaint))),
        ]),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.color, required this.alignRight});
  final double fraction;
  final Color color;
  final bool alignRight;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 8,
      decoration: BoxDecoration(color: c.surface3, borderRadius: Radii.pillAll),
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: AnimatedFractionallySizedBox(
        duration: Motion.slow,
        curve: Motion.emphasized,
        widthFactor: (fraction * 2).clamp(0.0, 1.0),
        child: Container(decoration: BoxDecoration(color: color, borderRadius: Radii.pillAll)),
      ),
    );
  }
}

/// Possession as a single split capsule with big numbers.
class PossessionBar extends StatelessWidget {
  const PossessionBar({super.key, required this.home, required this.away, this.onTap});
  final double home;
  final double away;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = (home + away) == 0 ? 1 : home + away;
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Column(children: [
        Row(children: [
          Text('${home.round()}%', style: AppType.numeric(28, color: c.text)),
          Expanded(
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Possession', style: AppType.body(13.5, weight: 560, color: c.textMuted)),
              if (onTap != null) ...[const SizedBox(width: 4), Icon(Icons.help_outline_rounded, size: 13, color: c.textFaint)],
            ]),
          ),
          Text('${away.round()}%', style: AppType.numeric(28, color: c.text)),
        ]),
        const SizedBox(height: 10),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.5, end: home / total),
          duration: context.reduceMotion ? Duration.zero : Motion.draw,
          curve: Motion.emphasized,
          builder: (_, t, _) => ClipRRect(
            borderRadius: Radii.pillAll,
            child: SizedBox(
              height: 14,
              child: Row(children: [
                Expanded(flex: (t * 1000).round().clamp(1, 999), child: Container(color: c.accent)),
                const SizedBox(width: 3),
                Expanded(flex: ((1 - t) * 1000).round().clamp(1, 999), child: Container(color: c.away)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Big number tile used on player/team stat grids.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.sub, this.highlight = false});
  final String label;
  final String value;
  final String? sub;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: highlight ? c.accent : c.surface2, borderRadius: Radii.lgAll),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: AppType.body(12.5, weight: 560, color: highlight ? c.onAccent.withValues(alpha: 0.7) : c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: context.reduceMotion ? 1 : 0, end: 1),
            duration: Motion.slow,
            curve: Motion.emphasized,
            builder: (_, t, child) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child)),
            child: Text(value, style: AppType.numeric(26, color: highlight ? c.onAccent : c.text)),
          ),
        ),
        if (sub != null) Text(sub!, style: AppType.body(11.5, color: highlight ? c.onAccent.withValues(alpha: 0.7) : c.textFaint), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

/// Responsive grid of [StatTile]s.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.tiles, this.columns = 3});
  final List<Widget> tiles;
  final int columns;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final cols = box.maxWidth > 520 ? columns + 1 : columns;
        const gap = 10.0;
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [for (final t in tiles) SizedBox(width: w, height: 96, child: t)]);
      });
}
