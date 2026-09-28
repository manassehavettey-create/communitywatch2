import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/bf_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/components.dart';
import '../../core/widgets/icons.dart';
import '../../core/widgets/motion_widgets.dart';
import '../../core/widgets/page.dart';
import '../../domain/catalog/exercises.dart';
import '../../domain/catalog/skill_paths.dart';
import '../exercise/exercise_figure.dart';

/// Skill tree for one path (spec §6): current level, next exercise and the
/// advanced goal, on an animated node map you can zoom and pan.
class SkillPathScreen extends ConsumerWidget {
  const SkillPathScreen({super.key, required this.pathId});
  final String pathId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = kPathById[pathId];
    if (path == null) return const BfPage(title: 'Skill path', children: [Text('Unknown path')]);
    final progress = ref.watch(progressProvider).value?[pathId];
    final filter = ref.watch(filterProvider);
    final t = Theme.of(context).textTheme;
    final c = context.bf;
    final current = progress?.nodeIndex ?? 0;
    final best = progress?.highestNode ?? current;
    final curEx = exerciseById(path.node(current).exerciseId);
    final nextEx = current + 1 < path.length ? exerciseById(path.node(current + 1).exerciseId) : null;
    final unit = curEx.isTimed ? 's' : '';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          BfTopBar(title: path.name),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Row(children: [
              Expanded(child: _Info(label: 'Current level', value: curEx.name, sub: progress == null ? '' : '${progress.sets} × ${progress.amount}$unit', color: c.secondary)),
              const SizedBox(width: Space.xs),
              Expanded(child: _Info(label: 'Next exercise', value: nextEx?.name ?? 'Mastered', sub: nextEx == null ? '' : 'Level ${current + 2}', color: c.primary)),
              const SizedBox(width: Space.xs),
              Expanded(child: _Info(label: 'Advanced goal', value: path.goalLabel, sub: 'Level ${path.length}', color: c.ember)),
            ]).enter(context),
          ),
          const SizedBox(height: Space.sm),
          Text('Pinch to zoom · tap a level', style: t.labelSmall),
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              const nodeGap = 132.0;
              final height = path.length * nodeGap + 120;
              return InteractiveViewer(
                minScale: 0.6,
                maxScale: 2.2,
                boundaryMargin: const EdgeInsets.all(80),
                constrained: false,
                child: SizedBox(
                  width: box.maxWidth,
                  height: height,
                  child: _NodeMap(
                    count: path.length,
                    gap: nodeGap,
                    width: box.maxWidth,
                    current: current,
                    best: best,
                    builder: (i, state) {
                      final node = path.node(i);
                      final ex = exerciseById(node.exerciseId);
                      final possible = filter.resolve(path, i)?.index == i;
                      return _Node(
                        name: ex.name,
                        level: i + 1,
                        state: state,
                        milestone: node.milestone || i == path.length - 1,
                        dim: !possible,
                        onTap: () => _showNode(context, path, i),
                      );
                    },
                  ),
                ),
              );
            }),
          ),
        ]),
      ),
    );
  }

  void _showNode(BuildContext context, SkillPath path, int i) {
    final node = path.node(i);
    final ex = exerciseById(node.exerciseId);
    showBfSheet(context, builder: (ctx) {
      final t = Theme.of(ctx).textTheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Overline('Level ${i + 1} of ${path.length}'),
          Text(ex.name, style: t.headlineMedium),
          const SizedBox(height: Space.md),
          Container(
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(color: ctx.bf.primary, borderRadius: Radii.card),
            child: ExerciseFigure(demo: ex.demo, color: BfPalette.ink),
          ),
          const SizedBox(height: Space.md),
          Text(ex.summary, style: t.bodyMedium),
          if (node.alternatives.isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            Text('Alternatives when space or furniture is limited: ${node.alternatives.map((a) => exerciseById(a).name).join(', ')}',
                style: t.bodySmall),
          ],
          const SizedBox(height: Space.lg),
          BfButton(
            label: 'How to do it',
            kind: BfButtonKind.ghost,
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/exercise/${ex.id}');
            },
          ),
        ]),
      );
    });
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value, required this.sub, required this.color});
  final String label;
  final String value;
  final String sub;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      height: 104,
      padding: const EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(color: color, borderRadius: Radii.tile),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: BfType.overline(BfPalette.ink.withValues(alpha: 0.6)).copyWith(fontSize: 9)),
        const Spacer(),
        Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(color: BfPalette.ink, height: 1.15)),
        if (sub.isNotEmpty) Text(sub, style: t.labelSmall?.copyWith(color: BfPalette.ink.withValues(alpha: 0.7))),
      ]),
    );
  }
}

enum NodeState { done, current, next, locked }

/// Zig-zag map from the bottom (level 1) to the top (goal). Connecting
/// lines draw themselves in; the current node pulses.
class _NodeMap extends StatelessWidget {
  const _NodeMap({
    required this.count,
    required this.gap,
    required this.width,
    required this.current,
    required this.best,
    required this.builder,
  });
  final int count;
  final double gap;
  final double width;
  final int current;
  final int best;
  final Widget Function(int i, NodeState s) builder;

  Offset _pos(int i) {
    final x = width / 2 + math.sin(i * 1.15) * (width * 0.24);
    final y = 60 + (count - 1 - i) * gap + gap / 2;
    return Offset(x, y);
  }

  NodeState _state(int i) {
    if (i == current) return NodeState.current;
    if (i < current || i <= best) return NodeState.done;
    if (i == current + 1) return NodeState.next;
    return NodeState.locked;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    return Stack(children: [
      Positioned.fill(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Motion.of(context, const Duration(milliseconds: 1400)),
          curve: Motion.emphasized,
          builder: (_, v, _) => CustomPaint(
            painter: _PathPainter(
              points: [for (var i = 0; i < count; i++) _pos(i)],
              reached: math.max(current, best),
              progress: v,
              done: c.primary,
              pending: c.outline,
            ),
          ),
        ),
      ),
      for (var i = 0; i < count; i++)
        Positioned(
          left: _pos(i).dx - 60,
          top: _pos(i).dy - 44,
          width: 120,
          child: builder(i, _state(i)).animate(delay: Motion.stagger(count - 1 - i, base: 150.ms)).fadeIn(duration: Motion.of(context, Motion.medium)).scale(
                begin: const Offset(0.7, 0.7),
                end: const Offset(1, 1),
                curve: Motion.gentleSpring,
                duration: Motion.of(context, Motion.slow),
              ),
        ),
    ]);
  }
}

class _PathPainter extends CustomPainter {
  _PathPainter({required this.points, required this.reached, required this.progress, required this.done, required this.pending});
  final List<Offset> points;
  final int reached;
  final double progress;
  final Color done;
  final Color pending;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    Path build(int from, int to) {
      final p = Path()..moveTo(points[from].dx, points[from].dy);
      for (var i = from + 1; i <= to; i++) {
        final a = points[i - 1], b = points[i];
        final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
        p.quadraticBezierTo(a.dx, mid.dy, mid.dx, mid.dy);
        p.quadraticBezierTo(b.dx, mid.dy, b.dx, b.dy);
      }
      return p;
    }

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = pending;
    // Dashed pending path.
    final all = build(0, points.length - 1);
    for (final m in all.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + 10, m.length)), base);
        d += 20;
      }
    }
    if (reached <= 0) return;
    final donePath = build(0, reached);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = done;
    for (final m in donePath.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(_PathPainter o) => o.progress != progress || o.reached != reached;
}

class _Node extends StatelessWidget {
  const _Node({required this.name, required this.level, required this.state, required this.milestone, required this.dim, required this.onTap});
  final String name;
  final int level;
  final NodeState state;
  final bool milestone;
  final bool dim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.bf;
    final t = Theme.of(context).textTheme;
    final (bg, fg, icon) = switch (state) {
      NodeState.done => (c.primary, BfPalette.ink, BfIcons.check),
      NodeState.current => (c.secondary, BfPalette.ink, BfIcons.bolt),
      NodeState.next => (c.surfaceRaised, c.text, BfIcons.unlock),
      NodeState.locked => (c.surface, c.textFaint, BfIcons.lock),
    };
    final size = milestone ? 62.0 : 52.0;
    Widget circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: state == NodeState.locked ? c.outline : Colors.transparent, width: 2),
        boxShadow: state == NodeState.current ? [BoxShadow(color: c.secondary.withValues(alpha: 0.6), blurRadius: 24)] : null,
      ),
      child: Stack(alignment: Alignment.center, children: [
        Icon(icon, color: fg, size: size * 0.42),
        if (milestone && state == NodeState.locked)
          Positioned(right: 4, top: 4, child: Icon(BfIcons.star, size: 12, color: c.ember)),
      ]),
    );
    if (state == NodeState.current && !Motion.reduced(context)) {
      circle = Glow(color: c.secondary, radius: size * 0.9, child: circle);
    }
    return Pressable(
      onTap: onTap,
      borderRadius: Radii.tile,
      semanticLabel: 'Level $level: $name',
      child: Opacity(
        opacity: dim && state == NodeState.locked ? 0.55 : 1,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          circle,
          const SizedBox(height: 4),
          Text(name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
              style: t.labelSmall?.copyWith(color: state == NodeState.locked ? c.textFaint : c.text, letterSpacing: 0.2)),
        ]),
      ),
    );
  }
}
