import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/models/models.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../utils/format.dart';
import 'pitch.dart';
import 'pressable.dart';

/// Shimmering skeleton block used while loading.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.height = 16, this.width, this.radius = Radii.sm});
  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final box = Container(height: height, width: width, decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(radius)));
    if (context.reduceMotion) return box;
    return box.animate(onPlay: (a) => a.repeat()).shimmer(duration: 1400.ms, color: c.surface3.withValues(alpha: 0.9));
  }
}

/// A list of card-shaped skeletons.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 4, this.height = 84, this.padding = const EdgeInsets.symmetric(horizontal: Space.gutter)});
  final int count;
  final double height;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Column(children: [
          for (var i = 0; i < count; i++) Padding(padding: const EdgeInsets.only(bottom: Space.sm), child: Skeleton(height: height, radius: Radii.lg)),
        ]),
      );
}

enum EmptyArt { favorites, matches, offline, search }

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.art, required this.title, required this.message, this.actionLabel, this.onAction, this.compact = false});
  final EmptyArt art;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  String? get _asset => switch (art) {
        EmptyArt.favorites => 'assets/images/empty_favorites.jpg',
        EmptyArt.matches => 'assets/images/empty_matches.jpg',
        EmptyArt.offline => 'assets/images/empty_offline.jpg',
        EmptyArt.search => null,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = compact ? 120.0 : 168.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xxl, vertical: Space.xl),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.xl),
          child: SizedBox.square(
            dimension: s,
            child: ShaderMask(
              shaderCallback: (r) => RadialGradient(colors: [Colors.white, Colors.white.withValues(alpha: 0)], stops: const [0.6, 1]).createShader(r),
              blendMode: BlendMode.dstIn,
              child: _asset == null ? const _SearchArt() : ArtImage(_asset!),
            ),
          ),
        ).animate().fadeIn(duration: Motion.slow).scale(begin: const Offset(0.92, 0.92), curve: Motion.spring, duration: Motion.slow),
        const SizedBox(height: Space.lg),
        Text(title, style: context.text.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: Space.xs),
        Text(message, style: AppType.body(14, color: c.textMuted), textAlign: TextAlign.center),
        if (actionLabel != null) ...[
          const SizedBox(height: Space.lg),
          PillButton(label: actionLabel!, onTap: onAction, primary: false),
        ],
      ]),
    );
  }
}

class _SearchArt extends StatelessWidget {
  const _SearchArt();
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(fit: StackFit.expand, children: [
      const FallbackArt(glow: Alignment(0, 0.2)),
      Center(child: Icon(Icons.search_rounded, size: 64, color: c.accent.withValues(alpha: 0.85))),
    ]);
  }
}

/// Maps provider errors to friendly, actionable states.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.onRetry, this.compact = false});
  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final e = error is DataException ? error as DataException : null;
    final (title, msg, action, go) = switch (e?.kind) {
      DataErrorKind.network => ('You\'re offline', 'We couldn\'t reach the data provider and there\'s no saved copy of this page yet.', 'Try again', null),
      DataErrorKind.rateLimited => ('Daily data limit reached', '${e!.message} Saved pages still work.', 'Data preferences', '/settings/data'),
      DataErrorKind.plan => ('Not included in your API plan', '${e!.message}\nYou can pick a covered season in Data Preferences.', 'Choose season', '/settings/data'),
      DataErrorKind.auth => ('API key needed', 'Run the app with --dart-define=API_FOOTBALL_KEY=… (see README). ${e!.message}', 'Data preferences', '/settings/data'),
      DataErrorKind.notFound => ('Nothing here yet', e!.message, null, null),
      _ => ('Something went wrong', e?.message ?? 'Please try again in a moment.', 'Try again', null),
    };
    return Center(
      child: EmptyState(
        compact: compact,
        art: e?.kind == DataErrorKind.notFound ? EmptyArt.matches : EmptyArt.offline,
        title: title,
        message: msg,
        actionLabel: action,
        onAction: go != null ? () => context.push(go) : onRetry,
      ),
    );
  }
}

/// Standard AsyncValue renderer: skeleton → content, keeping stale content
/// visible when a refresh fails.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.builder, this.loading, this.onRetry, this.compactError = false});
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final Widget? loading;
  final VoidCallback? onRetry;
  final bool compactError;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) {
      return AnimatedSwitcher(duration: Motion.base, child: KeyedSubtree(key: const ValueKey('data'), child: builder(value.requireValue)));
    }
    if (value.hasError) return ErrorState(error: value.error!, onRetry: onRetry, compact: compactError);
    return loading ?? const SkeletonList();
  }
}

/// Freshness notice (spec §42): last-known data, delayed updates or the
/// live-update pause that protects the API quota.
class FreshnessBanner extends ConsumerWidget {
  const FreshnessBanner({super.key, this.fresh, this.live = false, this.padding = const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 0)});
  final Fresh<Object?>? fresh;
  final bool live;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final paused = live && ref.watch(budgetStateProvider.select((b) => b.paused)) && !ref.watch(repositoryProvider).isDemo;
    final stale = fresh?.stale ?? false;
    if (!stale && !paused) return const SizedBox.shrink();
    final text = stale
        ? 'Showing the last update from ${ago(fresh!.fetchedAt)}. Live updates may be delayed.'
        : 'Live updates paused to protect today\'s API quota. Scores resume at 00:00 UTC.';
    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: c.reported.withValues(alpha: 0.12), borderRadius: Radii.mdAll, border: Border.all(color: c.reported.withValues(alpha: 0.3))),
        child: Row(children: [
          Icon(stale ? Icons.cloud_off_rounded : Icons.pause_circle_outline_rounded, size: 18, color: c.reported),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppType.body(13, color: c.text))),
        ]),
      ).animate().fadeIn(duration: Motion.base).slideY(begin: -0.2, curve: Motion.emphasized),
    );
  }
}
