import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/favorites.dart';
import '../../app/providers.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../shell/app_shell.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final favs = ref.watch(activeFavoritesProvider);
    final isDemo = ref.watch(repositoryProvider).isDemo;
    int count(FavKind k) => favs.where((f) => f.kind == k).length;

    Widget item(IconData icon, String title, String route, {String? value}) => Pressable(
          onTap: () => context.push(route),
          scale: 0.99,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(children: [
              Icon(icon, color: c.text, size: 22),
              const SizedBox(width: 14),
              Expanded(child: Text(title, style: AppType.body(15.5, weight: 560, color: c.text))),
              if (value != null) Text(value, style: AppType.body(13.5, color: c.textMuted)),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: c.textFaint),
            ]),
          ),
        );

    Widget group(List<Widget> children) => Container(
          margin: const EdgeInsets.only(bottom: Space.md),
          decoration: BoxDecoration(color: c.surface, borderRadius: Radii.xlAll),
          child: Column(children: [
            for (var i = 0; i < children.length; i++) ...[children[i], if (i < children.length - 1) Divider(indent: 52, color: c.hairline, height: 1)],
          ]),
        );

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(Space.gutter, MediaQuery.paddingOf(context).top + Space.md, Space.gutter, navClearance),
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Your', style: AppType.display(34, color: c.text)),
                Text('Touchline', style: AppType.display(34, color: c.accentInk, italic: true, weight: 700)),
              ]),
            ),
            StampBadge(text: 'MY FOOTBALL · MY FOOTBALL · ', size: 86, center: Icon(Icons.star_rounded, color: c.onAccent, size: 26)),
          ]).animate().fadeIn(duration: Motion.slow),
          const SizedBox(height: Space.lg),
          Row(children: [
            for (final (k, l) in [(FavKind.team, 'Teams'), (FavKind.player, 'Players'), (FavKind.league, 'Leagues')])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AppCard(
                    onTap: () => context.push('/settings/${l.toLowerCase()}'),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${count(k)}', style: AppType.numeric(30, color: c.text)),
                      Text(l, style: AppType.body(13, color: c.textMuted)),
                    ]),
                  ),
                ),
              ),
          ]),
          if (isDemo) ...[
            const SizedBox(height: Space.md),
            AppCard(
              onTap: () => context.push('/settings/data'),
              color: c.accent.withValues(alpha: 0.12),
              child: Row(children: [
                const ProvenanceTag(Provenance.demo, compact: true),
                const SizedBox(width: 10),
                Expanded(child: Text('Debug build showing fictional demo data. Add an API key to see real football.', style: AppType.body(13, color: c.text))),
              ]),
            ),
          ],
          const SizedBox(height: Space.lg),
          group([
            item(Icons.shield_outlined, 'My teams', '/settings/teams', value: '${count(FavKind.team)}'),
            item(Icons.person_outline_rounded, 'My players', '/settings/players', value: '${count(FavKind.player)}'),
            item(Icons.emoji_events_outlined, 'My leagues', '/settings/leagues', value: '${count(FavKind.league)}'),
          ]),
          group([
            item(Icons.notifications_none_rounded, 'Notifications', '/settings/notifications'),
            item(Icons.palette_outlined, 'Appearance', '/settings/appearance'),
            item(Icons.translate_rounded, 'Language', '/settings/language', value: 'English'),
            item(Icons.data_usage_rounded, 'Data preferences', '/settings/data'),
          ]),
          group([
            item(Icons.swap_horiz_rounded, 'Transfers', '/transfers'),
            item(Icons.compare_arrows_rounded, 'Compare players', '/compare'),
          ]),
          group([
            item(Icons.info_outline_rounded, 'About', '/settings/about'),
            item(Icons.lock_outline_rounded, 'Privacy', '/settings/privacy'),
          ]),
        ],
      ),
    );
  }
}
