import 'package:flutter/material.dart';

import '../../data/models/models.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'pressable.dart';

/// CONFIRMED / REPORTED / PREDICTED / APP-GENERATED / DEMO label (spec §41).
class ProvenanceTag extends StatelessWidget {
  const ProvenanceTag(this.provenance, {super.key, this.source, this.compact = false});
  final Provenance provenance;
  final String? source;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (label, color, icon) = switch (provenance) {
      Provenance.confirmed => ('CONFIRMED', c.mint, Icons.verified_rounded),
      Provenance.reported => ('REPORTED', c.reported, Icons.campaign_outlined),
      Provenance.predicted => ('PREDICTED', c.predicted, Icons.auto_graph_rounded),
      Provenance.generated => ('APP-GENERATED', c.generated, Icons.auto_awesome_outlined),
      Provenance.demo => ('DEMO DATA', c.accentInk, Icons.science_outlined),
    };
    return Semantics(
      label: '$label${source != null ? ', source $source' : ''}',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: Radii.pillAll, border: Border.all(color: color.withValues(alpha: 0.35))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: compact ? 10 : 12, color: color),
          const SizedBox(width: 4),
          Text(source == null ? label : '$label · $source', style: AppType.overline(color: color, size: compact ? 9.5 : 10.5)),
        ]),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction, this.trailing, this.padding = const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.sm)});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: padding,
      child: Row(children: [
        Expanded(child: Text(title, style: context.text.headlineSmall)),
        ?trailing,
        if (action != null)
          Pressable(
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Text(action!, style: AppType.body(13.5, weight: 600, color: c.textMuted)),
            ),
          ),
      ]),
    );
  }
}

/// Uppercase label (competition names, small section titles).
class Overline extends StatelessWidget {
  const Overline(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: AppType.overline(color: color ?? context.colors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis);
}

/// Inline "not provided" note for statistics the provider doesn't supply.
class NotProvided extends StatelessWidget {
  const NotProvided(this.what, {super.key, this.provider});
  final String what;
  final String? provider;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(children: [
      Icon(Icons.info_outline_rounded, size: 15, color: c.textFaint),
      const SizedBox(width: 8),
      Expanded(child: Text('$what — not provided${provider != null ? ' by $provider' : ''}', style: AppType.body(13, color: c.textFaint))),
    ]);
  }
}

class ChoiceChipPill extends StatelessWidget {
  const ChoiceChipPill({super.key, required this.label, required this.selected, required this.onTap, this.leading});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.emphasized,
        padding: EdgeInsets.fromLTRB(leading == null ? 14 : 6, 8, 14, 8),
        decoration: BoxDecoration(
          color: selected ? c.accent : c.surface2,
          borderRadius: Radii.pillAll,
          border: Border.all(color: selected ? c.accent : c.hairline),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          AnimatedDefaultTextStyle(
            duration: Motion.base,
            style: AppType.body(13.5, weight: 600, color: selected ? c.onAccent : c.text),
            child: Text(label),
          ),
        ]),
      ),
    );
  }
}

/// Pill tab bar with a sliding, resizing indicator (Match Center, League,
/// Team tabs). Built on [TabBar] so swipe, a11y and keyboard nav come free.
class PillTabBar extends StatelessWidget implements PreferredSizeWidget {
  const PillTabBar({super.key, required this.tabs, this.controller, this.padding = const EdgeInsets.symmetric(horizontal: Space.gutter)});
  final List<String> tabs;
  final TabController? controller;
  final EdgeInsetsGeometry padding;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 52,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: padding,
        labelPadding: const EdgeInsets.symmetric(horizontal: 16),
        dividerHeight: 0,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.symmetric(vertical: 8),
        indicator: BoxDecoration(color: c.accent, borderRadius: Radii.pillAll),
        labelColor: c.onAccent,
        unselectedLabelColor: c.textMuted,
        labelStyle: AppType.body(13.5, weight: 650),
        unselectedLabelStyle: AppType.body(13.5, weight: 550),
        tabs: [for (final t in tabs) Tab(text: t, height: 36)],
      ),
    );
  }
}
