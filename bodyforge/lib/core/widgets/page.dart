import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/bf_colors.dart';
import '../theme/tokens.dart';
import 'components.dart';
import 'icons.dart';

/// Standard sub-page: round back button, centred title, optional actions,
/// scrollable body with the page gutter.
class BfPage extends StatelessWidget {
  const BfPage({
    super.key,
    required this.title,
    required this.children,
    this.actions = const [],
    this.bottom,
    this.padding = const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxxl),
    this.onRefresh,
    this.background,
    this.onBack,
  });

  final String title;
  final List<Widget> children;
  final List<Widget> actions;
  final Widget? bottom;
  final EdgeInsets padding;
  final Future<void> Function()? onRefresh;
  final Color? background;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    Widget list = ListView(
      padding: padding,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      children: children,
    );
    if (onRefresh != null) {
      list = RefreshIndicator(
        onRefresh: onRefresh!,
        color: BfPalette.ink,
        backgroundColor: context.bf.primary,
        child: list,
      );
    }
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          BfTopBar(title: title, actions: actions, onBack: onBack),
          Expanded(child: list),
        ]),
      ),
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.md),
              child: bottom!,
            ),
    );
  }
}

class BfTopBar extends StatelessWidget {
  const BfTopBar({super.key, required this.title, this.actions = const [], this.onBack, this.showBack = true});
  final String title;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xs),
      child: Row(children: [
        if (showBack)
          CircleIconButton(
            icon: BfIcons.back,
            tooltip: 'Back',
            onTap: onBack ?? () => context.canPop() ? context.pop() : context.go('/home'),
          )
        else
          const SizedBox(width: Sizes.iconButton),
        Expanded(
          child: Text(title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        if (actions.isEmpty) const SizedBox(width: Sizes.iconButton) else Row(mainAxisSize: MainAxisSize.min, children: actions),
      ]),
    );
  }
}
