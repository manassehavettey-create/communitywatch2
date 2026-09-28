import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../core/haptics.dart';
import '../core/motion/motion.dart';
import '../core/theme/tokens.dart';

class _Tab {
  const _Tab(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

final _tabs = [
  _Tab('Home', PhosphorIconsRegular.house, PhosphorIconsFill.house),
  _Tab(
    'Bible',
    PhosphorIconsRegular.bookOpenText,
    PhosphorIconsFill.bookOpenText,
  ),
  _Tab(
    'Plans',
    PhosphorIconsRegular.calendarCheck,
    PhosphorIconsFill.calendarCheck,
  ),
  _Tab(
    'Prayer',
    PhosphorIconsRegular.handsPraying,
    PhosphorIconsFill.handsPraying,
  ),
  _Tab('Profile', PhosphorIconsRegular.user, PhosphorIconsFill.user),
];

/// Hosts the five primary tabs with the floating pill tab bar.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: FloatingTabBar(
        index: shell.currentIndex,
        onSelect: (i) {
          Haptics.select();
          shell.goBranch(i, initialLocation: i == shell.currentIndex);
        },
      ),
    );
  }
}

/// Ink pill with five icons; the active tab sits in a paper circle that
/// slides between positions.
class FloatingTabBar extends StatelessWidget {
  const FloatingTabBar({
    super.key,
    required this.index,
    required this.onSelect,
  });

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = Motion.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final barColor = p.isDark ? p.surface : p.ink;
    final iconColor = p.isDark ? p.ink : p.paper;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 12),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: barColor,
          borderRadius: Radii.pillAll,
          border: p.isDark ? Border.all(color: p.line) : null,
          boxShadow: floatingShadow(p),
        ),
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth / _tabs.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: m.slow,
                  curve: m.reduced ? Curves.linear : Curves.easeOutBack,
                  left: w * index + (w - 52) / 2,
                  top: 0,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: p.isDark ? p.tangerine : p.paper,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < _tabs.length; i++)
                      Expanded(
                        child: Semantics(
                          label: _tabs[i].label,
                          selected: i == index,
                          button: true,
                          child: InkResponse(
                            onTap: () => onSelect(i),
                            radius: 30,
                            child: SizedBox(
                              height: 52,
                              child: Center(
                                child: AnimatedSwitcher(
                                  duration: m.fast,
                                  child: Icon(
                                    i == index
                                        ? _tabs[i].activeIcon
                                        : _tabs[i].icon,
                                    key: ValueKey(i == index),
                                    size: 24,
                                    color: i == index
                                        ? const Color(0xFF141414)
                                        : iconColor.withValues(alpha: 0.72),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
