import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/favorites.dart';
import '../../app/personalization.dart';
import '../../app/providers.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../notifications/live_watcher.dart';
import '../shell/app_shell.dart';
import 'my_football.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dateOnly(DateTime.now());
    final dayAsync = ref.watch(dayMatchesProvider(today));
    final live = ref.watch(liveMatchesProvider);
    final p = ref.watch(personalizationProvider);
    final isDemo = ref.watch(repositoryProvider).isDemo;

    final liveList = [...?live.value?.data]..sort((a, b) => p.matchPriority(b).compareTo(p.matchPriority(a)));
    final todays = dayAsync.value?.data ?? const <Match>[];
    final upcoming = todays.where((m) => m.status.isScheduled).toList()
      ..sort((a, b) {
        final c = p.matchPriority(b).compareTo(p.matchPriority(a));
        return c != 0 ? c : a.kickoff.compareTo(b.kickoff);
      });
    final finished = todays.where((m) => m.status.isFinished).toList()..sort((a, b) => p.matchPriority(b).compareTo(p.matchPriority(a)));

    return RefreshIndicator(
      color: context.colors.onAccent,
      backgroundColor: context.colors.accent,
      onRefresh: () async {
        ref.invalidate(liveMatchesProvider);
        ref.invalidate(dayMatchesProvider(today));
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Header(isDemo: isDemo)),
          SliverToBoxAdapter(child: FreshnessBanner(fresh: live.value, live: true)),
          SliverToBoxAdapter(
            child: SectionHeader('Live now', trailing: liveList.isEmpty ? null : Padding(padding: const EdgeInsets.only(right: 8), child: LiveDot(color: context.colors.live)), action: 'All matches', onAction: () => context.go('/matches')),
          ),
          SliverToBoxAdapter(
            child: switch (live) {
              AsyncValue(hasValue: true) when liveList.isNotEmpty => _LiveCarousel(matches: liveList.take(12).toList()),
              AsyncValue(hasValue: true) => _NoLive(next: upcoming.isEmpty ? null : (upcoming.toList()..sort((a, b) => a.kickoff.compareTo(b.kickoff))).first),
              AsyncValue(:final error?) => ErrorState(error: error, compact: true, onRetry: () => ref.invalidate(liveMatchesProvider)),
              _ => const SizedBox(height: 210, child: SkeletonList(count: 1, height: 196)),
            },
          ),
          const SliverToBoxAdapter(child: MyFootballSection()),
          if (upcoming.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader(p.isEmpty ? 'Upcoming today' : 'Coming up for you', action: 'See all', onAction: () => context.go('/matches'))),
            _MatchList(matches: upcoming.take(p.isEmpty ? 5 : 6).toList(), scope: 'upcoming'),
          ],
          if (finished.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SectionHeader('Recent results')),
            _MatchList(matches: finished.take(5).toList(), scope: 'results', showLeague: true),
          ],
          if (dayAsync.isLoading && !dayAsync.hasValue) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: Space.xl), child: SkeletonList(count: 3))),
          const SliverToBoxAdapter(child: _Explore()),
          const SliverToBoxAdapter(child: SizedBox(height: navClearance)),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.isDemo});
  final bool isDemo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final g = greeting();
    final words = g.split(' ');
    final unread = ref.watch(alertLogProvider).where((a) => DateTime.now().difference(a.at) < const Duration(hours: 3)).length;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Overline(DateFormat('EEEE d MMMM').format(DateTime.now())),
                if (isDemo) ...[const SizedBox(width: 8), const ProvenanceTag(Provenance.demo, compact: true)],
              ]),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: '${words.first} ', style: AppType.display(34, color: c.text)),
                  TextSpan(text: words.skip(1).join(' '), style: AppType.display(34, color: c.accentInk, italic: true, weight: 700)),
                ]),
              ).animate().fadeIn(duration: Motion.slow).slideX(begin: -0.04, curve: Motion.emphasized),
            ]),
          ),
          Stack(clipBehavior: Clip.none, children: [
            CircleIconButton(icon: Icons.notifications_none_rounded, tooltip: 'Notifications', onTap: () => context.push('/notifications')),
            if (unread > 0)
              Positioned(
                right: 2,
                top: 2,
                child: Container(width: 10, height: 10, decoration: BoxDecoration(color: c.live, shape: BoxShape.circle, border: Border.all(color: c.bg, width: 2))).animate().scale(curve: Motion.spring),
              ),
          ]),
        ]),
      ),
    );
  }
}

class _LiveCarousel extends StatelessWidget {
  const _LiveCarousel({required this.matches});
  final List<Match> matches;

  @override
  Widget build(BuildContext context) {
    final w = (MediaQuery.sizeOf(context).width - Space.gutter * 2 - 24).clamp(260.0, 340.0);
    return SizedBox(
      height: 212,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        scrollDirection: Axis.horizontal,
        itemCount: matches.length,
        separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
        itemBuilder: (context, i) => LiveMatchCard(match: matches[i], featured: i == 0, width: w, scope: 'live')
            .animate(delay: Motion.staggerFor(i))
            .fadeIn(duration: Motion.slow)
            .slideX(begin: 0.12, curve: Motion.emphasized, duration: Motion.slow),
      ),
    );
  }
}

class _NoLive extends StatelessWidget {
  const _NoLive({this.next});
  final Match? next;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: AppCard(
        onTap: next == null ? null : () => openMatch(context, next!, scope: 'next'),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: c.surface2, shape: BoxShape.circle),
            child: Icon(Icons.schedule_rounded, color: c.textMuted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('No matches in play right now', style: context.text.titleMedium),
              const SizedBox(height: 2),
              Text(next == null ? 'Check the Matches tab for upcoming fixtures.' : 'Next: ${next!.home.name} vs ${next!.away.name} · ${kickoffTime(next!.kickoff)}',
                  style: AppType.body(13.5, color: c.textMuted), maxLines: 2),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _MatchList extends StatelessWidget {
  const _MatchList({required this.matches, required this.scope, this.showLeague = true});
  final List<Match> matches;
  final String scope;
  final bool showLeague;
  @override
  Widget build(BuildContext context) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        sliver: SliverList.separated(
          itemCount: matches.length,
          separatorBuilder: (_, _) => const SizedBox(height: Space.xs),
          itemBuilder: (_, i) => MatchRow(match: matches[i], scope: '$scope$i', showLeague: showLeague).animate(delay: Motion.staggerFor(i)).fadeIn(duration: Motion.base).slideY(begin: 0.15, curve: Motion.emphasized),
        ),
      );
}

class _Explore extends StatelessWidget {
  const _Explore();
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget tile(IconData icon, String title, String sub, String route, {bool accent = false}) => Expanded(
          child: AppCard(
            onTap: () => context.push(route),
            color: accent ? null : c.surface,
            gradient: accent ? LinearGradient(colors: [c.away, Color.lerp(c.away, c.bg, 0.35)!], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: accent ? c.onAccent : c.accentInk),
              const SizedBox(height: 18),
              Text(title, style: AppType.display(17, weight: 740, width: 104, color: accent ? c.onAccent : c.text)),
              const SizedBox(height: 2),
              Text(sub, style: AppType.body(12.5, color: accent ? c.onAccent.withValues(alpha: 0.7) : c.textMuted), maxLines: 2),
            ]),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, 0),
      child: Row(children: [
        tile(Icons.swap_horiz_rounded, 'Transfers', 'Confirmed moves for teams you follow', '/transfers', accent: true),
        const SizedBox(width: Space.sm),
        tile(Icons.compare_arrows_rounded, 'Compare', 'Put two players side by side', '/compare'),
      ]),
    );
  }
}

/// Open a followed entity.
void openFavorite(BuildContext context, Favorite f) => context.push(switch (f.kind) { FavKind.team => '/team/${f.id}', FavKind.player => '/player/${f.id}', FavKind.league => '/league/${f.id}' });
