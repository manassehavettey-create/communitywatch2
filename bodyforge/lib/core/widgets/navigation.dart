import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../data/sync/sync_engine.dart';
import '../../domain/models/local_date.dart';
import '../motion/motion.dart';
import '../theme/bf_colors.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'icons.dart';
import 'motion_widgets.dart';

class NavItem {
  const NavItem(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

const kNavItems = [
  NavItem('Home', BfIcons.homeOutline, BfIcons.home),
  NavItem('Workout', BfIcons.workoutOutline, BfIcons.workout),
  NavItem('Progress', BfIcons.progressOutline, BfIcons.progress),
  NavItem('Nutrition', BfIcons.nutritionOutline, BfIcons.nutrition),
  NavItem('Profile', BfIcons.profileOutline, BfIcons.profile),
];

/// Floating pill navigation with circular items; the active item fills
/// lavender, grows and morphs from outline to filled icon.
class ForgeNavBar extends StatelessWidget {
  const ForgeNavBar({super.key, required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: Space.sm),
      child: Builder(builder: (context) {
        // Fit narrow phones (320–360 dp): tighten the margins and only show
        // the active label when there is room for it.
        final width = MediaQuery.sizeOf(context).width;
        final narrow = width < 380;
        final margin = narrow ? Space.sm : Space.gutter;
        final itemPad = narrow ? 11.0 : 14.0;
        final gap = narrow ? 4.0 : 6.0;
        const icon = 22.0;
        final fixed = 2 * margin + 16 + (kNavItems.length - 1) * (2 * itemPad + icon + gap) + 2 * (itemPad + 4) + icon + 6;
        final labelRoom = (width - fixed).clamp(0.0, 120.0);
        return Center(
          heightFactor: 1,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: margin),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.navBar,
              borderRadius: Radii.pillAll,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < kNavItems.length; i++)
                Padding(
                  padding: EdgeInsets.only(right: i == kNavItems.length - 1 ? 0 : gap),
                  child: _NavButton(
                    item: kNavItems[i],
                    active: i == index,
                    pad: itemPad,
                    labelRoom: labelRoom,
                    onTap: () => onTap(i),
                  ),
                ),
            ]),
          ),
        );
      }),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.active, required this.pad, required this.labelRoom, required this.onTap});
  final NavItem item;
  final bool active;
  final double pad;
  final double labelRoom;
  final VoidCallback onTap;

  static const _labelStyle = TextStyle(fontFamily: BfType.body, fontFamilyFallback: BfType.fallback, fontWeight: FontWeight.w800, fontSize: 13, color: BfPalette.ink);

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    final d = Motion.of(context, Motion.medium);
    final painter = TextPainter(
      text: TextSpan(text: item.label, style: _labelStyle),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final showLabel = active && painter.width <= labelRoom;
    painter.dispose();
    return Semantics(
      selected: active,
      button: true,
      label: item.label,
      child: Pressable(
        onTap: onTap,
        borderRadius: Radii.pillAll,
        scale: 0.88,
        child: AnimatedContainer(
          duration: d,
          curve: Motion.emphasized,
          height: 52,
          padding: EdgeInsets.symmetric(horizontal: active ? pad + 4 : pad),
          decoration: BoxDecoration(
            color: active ? c.secondary : Colors.white.withValues(alpha: c.isDark ? 0.06 : 0.10),
            borderRadius: Radii.pillAll,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            AnimatedSwitcher(
              duration: d,
              transitionBuilder: (w, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: w)),
              child: Icon(
                active ? item.activeIcon : item.icon,
                key: ValueKey(active),
                size: 22,
                color: active ? BfPalette.ink : Colors.white.withValues(alpha: 0.82),
              ),
            ),
            MotionSize(
              child: showLabel
                  ? Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(item.label, maxLines: 1, softWrap: false, style: _labelStyle),
                    )
                  : const SizedBox.shrink(),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Week strip (refs 1 & 3): weekday letters, dates, lime circle for today,
/// status dot underneath.
class DateStrip extends StatelessWidget {
  const DateStrip({super.key, required this.days, required this.today, this.statusColor, this.onTap});
  final List<LocalDate> days;
  final LocalDate today;
  final Color? Function(LocalDate d)? statusColor;
  final ValueChanged<LocalDate>? onTap;

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    final t = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < days.length; i++)
          Expanded(
            child: Pressable(
              onTap: onTap == null ? null : () => onTap!(days[i]),
              borderRadius: Radii.pillAll,
              child: Column(children: [
                Text(_letters[days[i].weekday - 1], style: t.labelSmall),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: Motion.of(context, Motion.medium),
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: days[i] == today ? c.primary : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Text('${days[i].day}',
                      style: BfType.number(15,
                          color: days[i] == today ? BfPalette.ink : (days[i].isAfter(today) ? c.textMuted : c.text),
                          weight: FontWeight.w700)),
                ),
                const SizedBox(height: 5),
                AnimatedContainer(
                  duration: Motion.of(context, Motion.medium),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: statusColor?.call(days[i]) ?? Colors.transparent, shape: BoxShape.circle),
                ),
              ]).animate(delay: Motion.stagger(i)).fadeIn(duration: Motion.of(context, Motion.medium)),
            ),
          ),
      ],
    );
  }
}

/// "Start workout >>>" swipe slider from the references. Also accepts a tap on
/// the thumb for accessibility.
class SwipeToStart extends StatefulWidget {
  const SwipeToStart({super.key, required this.label, required this.onComplete, this.color, this.thumbColor});
  final String label;
  final VoidCallback onComplete;
  final Color? color;
  final Color? thumbColor;

  @override
  State<SwipeToStart> createState() => _SwipeToStartState();
}

class _SwipeToStartState extends State<SwipeToStart> with SingleTickerProviderStateMixin {
  double _drag = 0;
  double _from = 0;
  bool _done = false;
  late final AnimationController _back = AnimationController(vsync: this, duration: Motion.medium)
    ..addListener(() => setState(() => _drag = _from * (1 - Motion.standard.transform(_back.value))));

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    Haptics.medium();
    widget.onComplete();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _drag = 0;
          _done = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    const h = 64.0;
    return LayoutBuilder(builder: (context, box) {
      final max = box.maxWidth - h;
      final frac = max <= 0 ? 0.0 : (_drag / max).clamp(0.0, 1.0);
      return Semantics(
        button: true,
        label: widget.label,
        onTap: _finish,
        child: Container(
          height: h,
          decoration: BoxDecoration(color: widget.color ?? BfPalette.ink, borderRadius: Radii.pillAll),
          child: Stack(alignment: Alignment.centerLeft, children: [
            // Label centred in the track to the right of the thumb.
            Padding(
              padding: const EdgeInsets.only(left: h - 4),
              child: Center(
                child: Opacity(
                opacity: 1 - frac,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(widget.label,
                      style: const TextStyle(fontFamily: BfType.body, fontFamilyFallback: BfType.fallback, fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
                  const SizedBox(width: 10),
                  _Chevrons(color: Colors.white.withValues(alpha: 0.8)),
                ]),
                ),
              ),
            ),
            Positioned(
              left: 4 + _drag.clamp(0, max),
              child: GestureDetector(
                onHorizontalDragUpdate: (d) => setState(() => _drag = (_drag + d.delta.dx).clamp(0, max)),
                onHorizontalDragEnd: (_) {
                  if (frac > 0.72) {
                    setState(() => _drag = max);
                    _finish();
                  } else {
                    _from = _drag;
                    _back.forward(from: 0);
                  }
                },
                onTap: _finish,
                child: Container(
                  width: h - 8,
                  height: h - 8,
                  decoration: BoxDecoration(color: widget.thumbColor ?? c.secondary, shape: BoxShape.circle),
                  child: const Icon(BfIcons.forward, color: BfPalette.ink),
                ),
              ),
            ),
          ]),
        ),
      );
    });
  }
}

class _Chevrons extends StatelessWidget {
  const _Chevrons({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < 3; i++)
        Icon(BfIcons.chevronRight, size: 18, color: color).animate(
          onPlay: (c) => reduced ? null : c.repeat(),
        ).fadeIn(delay: (i * 180).ms, duration: 500.ms).then().fadeOut(duration: 500.ms),
    ]);
  }
}

/// Animated sync status chip: offline / syncing / synced / on-device only.
class SyncBadge extends StatelessWidget {
  const SyncBadge({super.key, required this.status, this.onTap});
  final SyncStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    final (icon, label, color) = switch (status.phase) {
      SyncPhase.syncing => (BfIcons.sync, 'Syncing', c.secondary),
      SyncPhase.synced || SyncPhase.idle =>
        status.pending > 0 ? (BfIcons.sync, '${status.pending} pending', c.warning) : (BfIcons.cloud, 'Synced', c.success),
      SyncPhase.offline => (BfIcons.cloudOff, status.pending > 0 ? 'Offline · ${status.pending}' : 'Offline', c.textMuted),
      SyncPhase.error => (BfIcons.warning, 'Retrying', c.warning),
      SyncPhase.localOnly => (BfIcons.localOnly, 'On device', c.textMuted),
    };
    Widget ic = Icon(icon, size: 14, color: color);
    if (status.phase == SyncPhase.syncing && !Motion.reduced(context)) {
      ic = ic.animate(onPlay: (ctl) => ctl.repeat()).rotate(duration: 900.ms, begin: 0, end: -1);
    }
    return Pressable(
      onTap: onTap,
      borderRadius: Radii.pillAll,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.medium),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: Radii.pillAll),
        child: AnimatedSwitcher(
          duration: Motion.of(context, Motion.medium),
          child: Row(key: ValueKey(label), mainAxisSize: MainAxisSize.min, children: [
            ic,
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, letterSpacing: 0.2)),
          ]),
        ),
      ),
    );
  }
}
