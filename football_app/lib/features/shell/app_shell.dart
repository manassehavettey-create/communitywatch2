import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/widgets.dart';
import '../notifications/live_watcher.dart';

class _NavItem {
  const _NavItem(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

const _items = [
  _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
  _NavItem(Icons.sports_soccer_outlined, Icons.sports_soccer, 'Matches'),
  _NavItem(Icons.emoji_events_outlined, Icons.emoji_events_rounded, 'Leagues'),
  _NavItem(Icons.search_rounded, Icons.search_rounded, 'Search'),
  _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
];

/// Five-tab shell with a floating pill navigation bar: the active tab
/// expands to reveal its label (visual language from the references).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the notification watcher alive while the app runs.
    ref.watch(liveWatcherProvider);
    return Scaffold(
      extendBody: true,
      body: Stack(children: [
        shell,
        const InAppAlertOverlay(),
      ]),
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
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom > 0 ? bottom : 14),
      child: ClipRRect(
        borderRadius: Radii.pillAll,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 66,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: (c.isDark ? c.surface2 : c.surface).withValues(alpha: c.isDark ? 0.82 : 0.9),
              borderRadius: Radii.pillAll,
              border: Border.all(color: c.hairline),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: c.isDark ? 0.35 : 0.08), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: Row(children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  flex: i == index ? 5 : 3,
                  child: Pressable(
                    haptic: false,
                    semanticLabel: _items[i].label,
                    onTap: () => onTap(i),
                    child: AnimatedContainer(
                      duration: Motion.slow,
                      curve: Motion.emphasized,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(color: i == index ? c.accent : Colors.transparent, borderRadius: Radii.pillAll),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(i == index ? _items[i].activeIcon : _items[i].icon, size: 22, color: i == index ? c.onAccent : c.textMuted),
                        Flexible(
                          child: AnimatedSize(
                            duration: Motion.slow,
                            curve: Motion.emphasized,
                            child: i == index
                                ? Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Text(_items[i].label, maxLines: 1, overflow: TextOverflow.fade, softWrap: false, style: AppType.body(13, weight: 650, color: c.onAccent)),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Bottom padding so scroll content clears the floating nav.
const navClearance = 110.0;

/// Pushes the Search tab (used by "Add" actions elsewhere).
void goSearch(BuildContext context) => context.go('/search');
