import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/phosphor_icons.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/pressable.dart';
import '../log/data/entry_repository.dart';
import '../skills/presentation/session_sheet.dart';
import '../timer/application/timer_providers.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(child: shell),
          Positioned(
            left: Space.gutter,
            right: Space.gutter,
            bottom: MediaQuery.paddingOf(context).bottom + 12,
            child: FloatingDock(
              index: shell.currentIndex,
              onSelect: (i) {
                ref.read(hapticsProvider).tap();
                shell.goBranch(i, initialLocation: i == shell.currentIndex);
              },
              onAdd: () => showQuickAdd(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _DockItem {
  const _DockItem(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

const _items = [
  _DockItem('Home', PhosphorIconsRegular.house, PhosphorIconsFill.house),
  _DockItem('Skills', PhosphorIconsRegular.squaresFour, PhosphorIconsFill.squaresFour),
  _DockItem('Log', PhosphorIconsRegular.notebook, PhosphorIconsFill.notebook),
  _DockItem('Insights', PhosphorIconsRegular.chartBar, PhosphorIconsFill.chartBar),
];

/// Dark floating navigation pill with a raised centre "+" button.
class FloatingDock extends StatelessWidget {
  const FloatingDock({
    super.key,
    required this.index,
    required this.onSelect,
    required this.onAdd,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final dockColor = dark ? Palette.darkCard : Palette.ink;
    Widget item(int i) {
      final it = _items[i];
      final selected = i == index;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: it.label,
          child: Pressable(
            onTap: () => onSelect(i),
            haptic: false,
            child: Center(
              child: AnimatedContainer(
                duration: Motion.medium,
                curve: Motion.spring,
                width: selected ? 52 : 44,
                height: selected ? 52 : 44,
                decoration: BoxDecoration(
                  color: selected ? Palette.white : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  selected ? it.activeIcon : it.icon,
                  size: 22,
                  color: selected
                      ? Palette.ink
                      : Palette.white.withValues(alpha: 0.72),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 84,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(Radii.dock)),
              boxShadow: Shadows.dock,
            ).copyWith(color: dockColor),
            child: Row(
              children: [
                item(0),
                item(1),
                const SizedBox(width: 64),
                item(2),
                item(3),
              ],
            ),
          ),
          Positioned(
            top: 0,
            child: Semantics(
              button: true,
              label: 'Add',
              child: Pressable(
                onTap: onAdd,
                scale: 0.9,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Palette.lime,
                    shape: BoxShape.circle,
                    border: Border.all(color: dockColor, width: 5),
                  ),
                  child: const Icon(
                    PhosphorIconsBold.plus,
                    color: Palette.ink,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The centre "+" sheet: timer, manual session, gratitude, win.
Future<void> showQuickAdd(BuildContext context) {
  return showAppSheet<void>(
    context,
    builder: (context) => const _QuickAddSheet(),
  );
}

class _QuickAddSheet extends ConsumerWidget {
  const _QuickAddSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = ref.watch(activeTimerProvider).value;
    final router = GoRouter.of(context);

    void go(String location) {
      Navigator.pop(context);
      router.push(location);
    }

    Widget tile(String title, String sub, IconData icon, Color color, VoidCallback onTap) {
      return Expanded(
        child: Pressable(
          onTap: onTap,
          semanticLabel: title,
          child: Container(
            height: 132,
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(color: color, borderRadius: Radii.cardR),
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Palette.ink,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const Spacer(),
                  Text(title, style: AppText.subtitle.copyWith(color: Palette.ink)),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(color: Palette.ink.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SheetScaffold(
      title: 'What would you like to log?',
      child: Column(
        children: [
          Row(
            children: [
              tile(
                running == null ? 'Start timer' : 'Open timer',
                running == null ? 'Track live' : 'Practising ${running.skill.name}',
                PhosphorIconsFill.timer,
                Palette.lime,
                () => go(Routes.timer()),
              ),
              const SizedBox(width: Space.sm),
              tile(
                'Log practice',
                'Add past time',
                PhosphorIconsFill.clockCounterClockwise,
                Palette.lavender,
                () {
                  Navigator.pop(context);
                  showSessionSheet(rootNavigatorKey.currentContext ?? context);
                },
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              tile(
                'Gratitude',
                "Something you're thankful for",
                PhosphorIconsFill.heart,
                Palette.butter,
                () => go(Routes.newEntry()),
              ),
              const SizedBox(width: Space.sm),
              tile(
                'A win',
                'Big or small, it counts',
                PhosphorIconsFill.trophy,
                Palette.blush,
                () => go(Routes.newEntry(type: EntryType.win)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
