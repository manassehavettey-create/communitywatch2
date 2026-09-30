import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/models/models.dart';
import '../../domain/form.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

Color _hashColor(String s, AppColors c) {
  const palette = [Color(0xFF2E6B4F), Color(0xFF3B4B8F), Color(0xFF8F3B3B), Color(0xFF6B5A2E), Color(0xFF5A2E6B), Color(0xFF2E5F6B), Color(0xFF6B2E4B), Color(0xFF45522A)];
  return palette[s.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff) % palette.length];
}

String _initials(String name, {int max = 3}) {
  final t = TeamRef(id: 0, name: name).short;
  return t.length > max ? t.substring(0, max) : t;
}

/// Team crest from the provider, with a designed initials crest fallback.
class TeamCrest extends StatelessWidget {
  const TeamCrest({super.key, required this.team, this.size = 36, this.heroTag});
  final TeamRef team;
  final double size;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget fallback() => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [_hashColor(team.name, c), Color.lerp(_hashColor(team.name, c), Colors.black, 0.35)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: size * 0.04),
          ),
          child: Text(_initials(team.name), style: AppType.display(size * 0.3, weight: 800, width: 100, color: Colors.white)),
        );
    final child = SizedBox.square(
      dimension: size,
      child: team.logo == null
          ? fallback()
          : CachedNetworkImage(imageUrl: team.logo!, width: size, height: size, fit: BoxFit.contain, fadeInDuration: Motion.fast, placeholder: (_, _) => Opacity(opacity: 0.4, child: fallback()), errorWidget: (_, _, _) => fallback()),
    );
    return heroTag == null ? child : Hero(tag: heroTag!, child: child);
  }
}

class LeagueLogo extends StatelessWidget {
  const LeagueLogo({super.key, required this.league, this.size = 24});
  final LeagueRef league;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget fallback() => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.surface3, borderRadius: BorderRadius.circular(size * 0.3)),
          child: Text(_initials(league.name, max: 2), style: AppType.display(size * 0.36, color: c.text)),
        );
    if (league.logo == null) return fallback();
    return CachedNetworkImage(imageUrl: league.logo!, width: size, height: size, fit: BoxFit.contain, placeholder: (_, _) => fallback(), errorWidget: (_, _, _) => fallback());
  }
}

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, required this.name, this.photo, this.size = 40, this.ring, this.heroTag});
  final String name;
  final String? photo;
  final double size;
  final Color? ring;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget fallback() => Container(
          alignment: Alignment.center,
          color: c.surface3,
          child: Text(
            name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join(),
            style: AppType.display(size * 0.34, width: 100, color: c.textMuted),
          ),
        );
    final img = ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: photo == null
            ? fallback()
            : CachedNetworkImage(imageUrl: photo!, fit: BoxFit.cover, fadeInDuration: Motion.fast, placeholder: (_, _) => fallback(), errorWidget: (_, _, _) => fallback()),
      ),
    );
    final framed = ring == null
        ? img
        : Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring!, width: 2)), child: img);
    return heroTag == null ? framed : Hero(tag: heroTag!, child: framed);
  }
}

/// Pulsing live indicator. Static when the OS requests reduced motion.
class LiveDot extends StatefulWidget {
  const LiveDot({super.key, this.size = 8, this.color});
  final double size;
  final Color? color;
  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.colors.live;
    final s = widget.size;
    return SizedBox.square(
      dimension: s * 2.4,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Stack(alignment: Alignment.center, children: [
          Container(
            width: s + s * 1.4 * _c.value,
            height: s + s * 1.4 * _c.value,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.45 * (1 - _c.value))),
          ),
          Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        ]),
      ),
    );
  }
}

/// "LIVE 78'" pill.
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key, required this.label, this.onAccent = false});
  final String label;
  final bool onAccent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 3, 10, 3),
      decoration: BoxDecoration(color: onAccent ? c.onAccent : c.live.withValues(alpha: 0.14), borderRadius: Radii.pillAll),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        LiveDot(size: 6, color: c.live),
        Text(label, style: AppType.numeric(12.5, weight: 700, color: onAccent ? c.accent : c.live)),
      ]),
    );
  }
}

/// A score digit that rolls when it changes and briefly glows in the accent
/// colour — the "live-score update pulse".
class ScoreNumber extends StatelessWidget {
  const ScoreNumber({super.key, required this.value, required this.style, this.glow});
  final int? value;
  final TextStyle style;
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduce = context.reduceMotion;
    return AnimatedSwitcher(
      duration: reduce ? Duration.zero : Motion.slow,
      switchInCurve: Motion.spring,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) {
        final incoming = child.key == ValueKey(value);
        final offset = Tween(begin: Offset(0, incoming ? 0.6 : -0.6), end: Offset.zero).animate(anim);
        return ClipRect(child: SlideTransition(position: offset, child: FadeTransition(opacity: anim, child: child)));
      },
      child: TweenAnimationBuilder<double>(
        key: ValueKey(value),
        tween: Tween(begin: 1, end: 0),
        duration: const Duration(milliseconds: 1600),
        curve: Curves.easeOut,
        builder: (context, t, child) => Text(
          value?.toString() ?? '–',
          style: style.copyWith(
            color: Color.lerp(style.color, glow ?? c.accentInk, t * 0.9),
            shadows: t > 0.02 ? [Shadow(color: (glow ?? c.accent).withValues(alpha: 0.55 * t), blurRadius: 24 * t)] : null,
          ),
        ),
      ),
    );
  }
}

class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.rating, this.size = 13});
  final double? rating;
  final double size;

  static Color colorFor(double r, AppColors c) => r >= 8 ? c.accent : r >= 7 ? c.mint : r >= 6.2 ? c.yellowCard : c.loss;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = rating;
    if (r == null) return const SizedBox.shrink();
    final col = colorFor(r, c);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size * 0.45, vertical: size * 0.18),
      decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(size * 0.5)),
      child: Text(r.toStringAsFixed(1), style: AppType.numeric(size, weight: 750, color: c.onAccent)),
    );
  }
}

/// W D L pills with a staggered pop-in. Most recent result on the right.
class FormStrip extends StatelessWidget {
  const FormStrip({super.key, required this.results, this.size = 24, this.onTapIndex});
  final List<FormResult> results;
  final double size;
  final void Function(int index)? onTapIndex;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (results.isEmpty) return Text('No recent results', style: context.text.bodySmall);
    return Wrap(spacing: 5, runSpacing: 5, children: [
      for (var i = 0; i < results.length; i++)
        TweenAnimationBuilder<double>(
          tween: Tween(begin: context.reduceMotion ? 1 : 0, end: 1),
          duration: Motion.slow + Motion.staggerFor(i),
          curve: Interval(i / (results.length + 2), 1, curve: Motion.spring),
          builder: (_, t, child) => Transform.scale(scale: 0.6 + 0.4 * t, child: Opacity(opacity: t.clamp(0, 1), child: child)),
          child: GestureDetector(
            onTap: onTapIndex == null ? null : () => onTapIndex!(i),
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: switch (results[i]) { FormResult.win => c.win, FormResult.draw => c.surface3, FormResult.loss => c.loss },
                borderRadius: BorderRadius.circular(size * 0.32),
                border: i == results.length - 1 ? Border.all(color: c.text.withValues(alpha: 0.7), width: 1.5) : null,
              ),
              child: Text(results[i].letter, style: AppType.display(size * 0.46, width: 100, color: results[i] == FormResult.draw ? c.text : c.onAccent)),
            ),
          ),
        ),
    ]);
  }
}

class CardChip extends StatelessWidget {
  const CardChip({super.key, required this.red, this.size = 11});
  final bool red;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size * 0.72,
        height: size,
        decoration: BoxDecoration(color: red ? context.colors.redCard : context.colors.yellowCard, borderRadius: BorderRadius.circular(2)),
      );
}

/// Icon for an event kind, consistent across timeline, commentary, lineups.
class EventIcon extends StatelessWidget {
  const EventIcon({super.key, required this.kind, this.size = 18});
  final EventKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return switch (kind) {
      EventKind.goal || EventKind.penaltyGoal => Icon(Icons.sports_soccer, size: size, color: c.text),
      EventKind.ownGoal => Icon(Icons.sports_soccer, size: size, color: c.loss),
      EventKind.missedPenalty => Icon(Icons.block, size: size, color: c.loss),
      EventKind.yellow => CardChip(red: false, size: size * 0.8),
      EventKind.secondYellow => SizedBox(
          width: size,
          height: size * 0.8,
          child: Stack(children: [CardChip(red: false, size: size * 0.8), Positioned(left: size * 0.3, child: CardChip(red: true, size: size * 0.8))]),
        ),
      EventKind.red => CardChip(red: true, size: size * 0.8),
      EventKind.sub => Icon(Icons.swap_vert_rounded, size: size, color: c.mint),
      EventKind.varDecision => Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(border: Border.all(color: c.textMuted), borderRadius: BorderRadius.circular(3)),
          child: Text('VAR', style: AppType.body(size * 0.45, weight: 800, color: c.textMuted)),
        ),
      EventKind.other => Icon(Icons.circle, size: size * 0.4, color: c.textMuted),
    };
  }
}
