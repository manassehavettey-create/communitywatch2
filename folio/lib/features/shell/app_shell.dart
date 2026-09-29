import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/icons.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/tokens.dart';

class _Tab {
  const _Tab(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

const _tabs = [
  _Tab('Home', PhosphorIconsRegular.house, PhosphorIconsFill.house),
  _Tab('Library', PhosphorIconsRegular.books, PhosphorIconsFill.books),
  _Tab('Search', PhosphorIconsRegular.magnifyingGlass, PhosphorIconsFill.magnifyingGlass),
  _Tab('Stats', PhosphorIconsRegular.chartBar, PhosphorIconsFill.chartBar),
  _Tab('Profile', PhosphorIconsRegular.user, PhosphorIconsFill.user),
];

/// Hosts the five tabs with a floating ink pill navigation bar.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: _FloatingNav(
        index: shell.currentIndex,
        onTap: (i) {
          HapticFeedback.selectionClick();
          shell.goBranch(i, initialLocation: i == shell.currentIndex);
        },
      ),
    );
  }
}

class _FloatingNav extends StatelessWidget {
  const _FloatingNav({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = Motion.of(context);
    final dark = context.brightness == Brightness.dark;
    // In dark mode the bar is a raised surface rather than an inverted pill.
    final barColor = dark ? c.surfaceMuted : c.ink;
    final activeBg = dark ? c.lime : c.paper;
    final activeFg = const Color(0xFF161514);
    final inactiveFg = dark ? c.inkMuted : c.onInk.withValues(alpha: 0.72);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: Space.x3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.x4),
        child: Container(
          height: 64,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: Radii.pillAll,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF161514).withValues(alpha: dark ? 0.4 : 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
            border: dark ? Border.all(color: c.hairline) : null,
          ),
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  flex: i == index ? 5 : 3,
                  child: Semantics(
                    selected: i == index,
                    button: true,
                    label: _tabs[i].label,
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: AnimatedContainer(
                        duration: m.base,
                        curve: Motion.curve,
                        decoration: BoxDecoration(
                          color: i == index ? activeBg : Colors.transparent,
                          borderRadius: Radii.pillAll,
                        ),
                        alignment: Alignment.center,
                        child: AnimatedSwitcher(
                          duration: m.fast,
                          child: i == index
                              ? Row(
                                  key: const ValueKey('on'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(_tabs[i].activeIcon, size: 20, color: activeFg),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        _tabs[i].label,
                                        maxLines: 1,
                                        overflow: TextOverflow.fade,
                                        softWrap: false,
                                        style: context.text.labelMedium?.copyWith(color: activeFg),
                                      ),
                                    ),
                                  ],
                                )
                              : Icon(_tabs[i].icon, key: const ValueKey('off'), size: 22, color: inactiveFg),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
