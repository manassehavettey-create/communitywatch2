import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/favorites.dart';
import '../../app/personalization.dart';
import '../../app/providers.dart';
import '../../app/settings.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../notifications/notification_service.dart';

/// Three steps: welcome → competitions → teams. Skippable at every step.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;

  Future<void> _finish({bool askAlerts = false}) async {
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(onboarded: true));
    if (askAlerts) await NotificationService.instance.requestPermission();
    if (mounted) context.go('/home');
  }

  void _next() => _pages.nextPage(duration: Motion.slow, curve: Motion.emphasized);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pages,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _page = i),
        children: [
          _Welcome(onStart: _next, onSkip: _finish),
          _PickLeagues(onNext: _next, onSkip: _finish),
          _PickTeams(onDone: () => _finish(askAlerts: true), onSkip: _finish),
        ],
      ),
      bottomNavigationBar: _page == 0
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < 3; i++)
                    AnimatedContainer(duration: Motion.base, margin: const EdgeInsets.all(3), width: i == _page ? 22 : 7, height: 7, decoration: BoxDecoration(color: i == _page ? context.colors.accent : context.colors.surface3, borderRadius: Radii.pillAll)),
                ]),
              ),
            ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onStart, required this.onSkip});
  final VoidCallback onStart;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(fit: StackFit.expand, children: [
      const ArtImage('assets/images/onboarding_hero.jpg', alignment: Alignment.topCenter).animate().fadeIn(duration: 900.ms).scale(begin: const Offset(1.08, 1.08), end: const Offset(1, 1), duration: 2400.ms, curve: Curves.easeOutCubic),
      DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0, 0.45, 0.72], colors: [Colors.transparent, c.bg.withValues(alpha: 0.2), c.bg])),
      ),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.gutter),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('TOUCHLINE', style: AppType.display(18, width: 125, color: Colors.white)),
              Text('.', style: AppType.display(18, color: c.accent)),
              const Spacer(),
              StampBadge(text: 'LIVE · STATS · LINEUPS · ', size: 78, color: c.accent, center: Icon(Icons.sports_soccer, color: c.onAccent, size: 24)),
            ]).animate().fadeIn(delay: 300.ms, duration: Motion.slow),
            const Spacer(),
            Text.rich(TextSpan(children: [
              TextSpan(text: 'Every match.\n', style: AppType.display(44, color: c.text, spacing: -1.4)),
              TextSpan(text: 'Every moment.', style: AppType.display(44, color: c.accent, italic: true, weight: 760, spacing: -1.4)),
            ])).animate().fadeIn(delay: 450.ms, duration: Motion.slow).slideY(begin: 0.2, curve: Motion.emphasized),
            const SizedBox(height: Space.md),
            Text('Live scores, momentum, lineups, player ratings and the story of every game — built around the football you follow.', style: AppType.body(16, color: c.textMuted, height: 1.45))
                .animate()
                .fadeIn(delay: 600.ms, duration: Motion.slow),
            const SizedBox(height: Space.xl),
            Row(children: [
              TextButton(onPressed: onSkip, child: Text('Skip', style: AppType.body(15, weight: 600, color: c.textMuted))),
              const Spacer(),
              PillButton(label: 'Get started', icon: Icons.arrow_forward_rounded, onTap: onStart),
            ]).animate().fadeIn(delay: 750.ms, duration: Motion.slow).slideY(begin: 0.3, curve: Motion.emphasized),
          ]),
        ),
      ),
    ]);
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.title, required this.accent, required this.sub, required this.child, required this.primary, required this.onPrimary, required this.onSkip});
  final String title;
  final String accent;
  final String sub;
  final Widget child;
  final String primary;
  final VoidCallback onPrimary;
  final VoidCallback onSkip;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: onSkip, child: Text('Skip', style: AppType.body(15, weight: 600, color: c.textMuted)))),
          Text.rich(TextSpan(children: [
            TextSpan(text: '$title ', style: AppType.display(32, color: c.text)),
            TextSpan(text: accent, style: AppType.display(32, color: c.accentInk, italic: true, weight: 720)),
          ])),
          const SizedBox(height: 8),
          Text(sub, style: AppType.body(15, color: c.textMuted)),
          const SizedBox(height: Space.lg),
          Expanded(child: child),
          Padding(padding: const EdgeInsets.symmetric(vertical: Space.md), child: PillButton(label: primary, expand: true, onTap: onPrimary)),
        ]),
      ),
    );
  }
}

class _PickLeagues extends ConsumerWidget {
  const _PickLeagues({required this.onNext, required this.onSkip});
  final VoidCallback onNext;
  final VoidCallback onSkip;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(leaguesCatalogProvider);
    ref.watch(favoritesProvider);
    final favs = ref.read(favoritesProvider.notifier);
    return _Step(
      title: 'Choose your',
      accent: 'competitions',
      sub: 'We\'ll put their matches, tables and alerts first.',
      primary: 'Continue',
      onPrimary: onNext,
      onSkip: onSkip,
      child: AsyncView(
        value: catalog,
        onRetry: () => ref.invalidate(leaguesCatalogProvider),
        builder: (fresh) {
          final byId = {for (final l in fresh.data) l.ref.id: l};
          final list = [...popularLeagueIds.map((id) => byId[id]).whereType<LeagueInfo>(), ...fresh.data.where((l) => !popularLeagueIds.contains(l.ref.id)).take(12)];
          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 180, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.25),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final l = list[i];
              final on = favs.isFollowing(FavKind.league, l.ref.id);
              final c = context.colors;
              return Pressable(
                onTap: () => favs.toggle(Favorite(kind: FavKind.league, id: l.ref.id, name: l.ref.name, image: l.ref.logo, subtitle: l.ref.country)),
                child: AnimatedContainer(
                  duration: Motion.base,
                  curve: Motion.emphasized,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: on ? c.accent : c.surface, borderRadius: Radii.xlAll, border: Border.all(color: on ? c.accent : c.hairline)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [LeagueLogo(league: l.ref, size: 30), const Spacer(), AnimatedSwitcher(duration: Motion.base, child: Icon(on ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded, key: ValueKey(on), color: on ? c.onAccent : c.textMuted))]),
                    const Spacer(),
                    Text(l.ref.name, style: AppType.body(14, weight: 650, color: on ? c.onAccent : c.text), maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(l.ref.country ?? '', style: AppType.body(12, color: on ? c.onAccent.withValues(alpha: 0.7) : c.textMuted), maxLines: 1),
                  ]),
                ),
              ).animate(delay: Motion.staggerFor(i)).fadeIn(duration: Motion.base).scale(begin: const Offset(0.94, 0.94), curve: Motion.spring);
            },
          );
        },
      ),
    );
  }
}

class _PickTeams extends ConsumerWidget {
  const _PickTeams({required this.onDone, required this.onSkip});
  final VoidCallback onDone;
  final VoidCallback onSkip;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final leagues = ref.watch(activeFavoritesProvider).where((f) => f.kind == FavKind.league).toList();
    ref.watch(favoritesProvider);
    final favs = ref.read(favoritesProvider.notifier);
    return _Step(
      title: 'Pick your',
      accent: 'teams',
      sub: 'Follow as many as you like — you can change this any time.',
      primary: 'Finish & enable alerts',
      onPrimary: onDone,
      onSkip: onSkip,
      child: leagues.isEmpty
          ? Center(child: Text('Choose a competition first, or skip and use Search later.', textAlign: TextAlign.center, style: AppType.body(14, color: c.textMuted)))
          : ListView(children: [
              for (final l in leagues) ...[
                Padding(padding: const EdgeInsets.only(top: 8, bottom: 8), child: Row(children: [LeagueLogo(league: LeagueRef(id: l.id, name: l.name, logo: l.image), size: 20), const SizedBox(width: 8), Text(l.name, style: context.text.titleSmall)])),
                Consumer(builder: (context, ref, _) {
                  final teams = ref.watch(leagueTeamsProvider(l.id));
                  return switch (teams) {
                    AsyncValue(:final value?) => Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final t in value.data)
                          ChoiceChipPill(
                            label: t.name,
                            selected: favs.isFollowing(FavKind.team, t.id),
                            leading: TeamCrest(team: t, size: 20),
                            onTap: () => favs.toggle(Favorite(kind: FavKind.team, id: t.id, name: t.name, image: t.logo, subtitle: l.name)),
                          ),
                      ]),
                    AsyncValue(:final error?) => ErrorState(error: error, compact: true),
                    _ => const Skeleton(height: 80),
                  };
                }),
              ],
            ]),
    );
  }
}
