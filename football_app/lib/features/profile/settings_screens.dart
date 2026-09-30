import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/env.dart';
import '../../app/favorites.dart';
import '../../app/providers.dart';
import '../../app/settings.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../home/home_screen.dart';
import '../notifications/live_watcher.dart';
import '../notifications/notification_service.dart';
import '../search/recent.dart';

class SettingsSectionScreen extends StatelessWidget {
  const SettingsSectionScreen({super.key, required this.section});
  final String section;

  @override
  Widget build(BuildContext context) {
    final (title, body) = switch (section) {
      'teams' => ('My teams', const _Follows(kind: FavKind.team)),
      'players' => ('My players', const _Follows(kind: FavKind.player)),
      'leagues' => ('My leagues', const _Follows(kind: FavKind.league)),
      'notifications' => ('Notifications', const _Notifications()),
      'appearance' => ('Appearance', const _Appearance()),
      'language' => ('Language', const _Language()),
      'data' => ('Data preferences', const _Data()),
      'about' => ('About', const _About()),
      'privacy' => ('Privacy', const _Privacy()),
      _ => ('Settings', const SizedBox()),
    };
    return Scaffold(appBar: AppBar(title: Text(title)), body: body);
  }
}

// ── Follows ────────────────────────────────────────────────────────────────

class _Follows extends ConsumerWidget {
  const _Follows({required this.kind});
  final FavKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final list = ref.watch(activeFavoritesProvider).where((f) => f.kind == kind).toList();
    final noun = switch (kind) { FavKind.team => 'teams', FavKind.player => 'players', FavKind.league => 'competitions' };
    if (list.isEmpty) {
      return EmptyState(art: EmptyArt.favorites, title: 'No $noun yet', message: 'Follow $noun to personalise Home, match ordering and alerts.', actionLabel: 'Find $noun', onAction: () => context.go('/search'));
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.sm),
        child: Text('Drag to reorder — the order is used on Home. Swipe to unfollow.', style: AppType.body(12.5, color: c.textMuted)),
      ),
      Expanded(
        child: ReorderableListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          itemCount: list.length,
          onReorderItem: (a, b) => ref.read(favoritesProvider.notifier).reorder(kind, a, b),
          itemBuilder: (_, i) {
            final f = list[i];
            return Dismissible(
              key: ValueKey(f.key),
              direction: DismissDirection.endToStart,
              background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: c.loss, borderRadius: Radii.lgAll), child: Icon(Icons.delete_outline_rounded, color: c.onAccent)),
              onDismissed: (_) => ref.read(favoritesProvider.notifier).remove(f.kind, f.id),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                  onTap: () => openFavorite(context, f),
                  child: Row(children: [
                    switch (f.kind) {
                      FavKind.team => TeamCrest(team: TeamRef(id: f.id, name: f.name, logo: f.image), size: 36),
                      FavKind.player => PlayerAvatar(name: f.name, photo: f.image, size: 36),
                      FavKind.league => LeagueLogo(league: LeagueRef(id: f.id, name: f.name, logo: f.image), size: 32),
                    },
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(f.name, style: context.text.titleSmall),
                        Text('${f.notifs.length} alert type${f.notifs.length == 1 ? '' : 's'} on', style: AppType.body(12.5, color: c.textMuted)),
                      ]),
                    ),
                    IconButton(icon: const Icon(Icons.notifications_none_rounded), tooltip: 'Alerts', onPressed: () => showEntityAlerts(context, f)),
                    const Icon(Icons.drag_handle_rounded),
                    const SizedBox(width: 8),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
      SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(Space.gutter), child: PillButton(label: 'Add $noun', icon: Icons.add_rounded, expand: true, onTap: () => context.go('/search')))),
    ]);
  }
}

/// Per-entity alert toggles.
void showEntityAlerts(BuildContext context, Favorite f) {
  showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => _EntityAlerts(fav: f));
}

class _EntityAlerts extends ConsumerWidget {
  const _EntityAlerts({required this.fav});
  final Favorite fav;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final f = ref.watch(favoritesProvider).firstWhere((x) => x.key == fav.key && x.demo == fav.demo, orElse: () => fav);
    final disabled = ref.watch(settingsProvider).disabledKinds;
    final group = switch (f.kind) { FavKind.team => NotifGroup.team, FavKind.player => NotifGroup.player, FavKind.league => NotifGroup.competition };
    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.sm), child: Text('Alerts for ${f.name}', style: context.text.headlineSmall)),
        for (final k in NotifKind.of(group))
          SwitchListTile(
            title: Text(k.label, style: AppType.body(15, color: disabled.contains(k) ? c.textFaint : c.text)),
            subtitle: disabled.contains(k) ? Text('Turned off for everything in Notifications', style: AppType.body(12, color: c.textFaint)) : null,
            value: f.notifs.contains(k),
            onChanged: (v) => ref.read(favoritesProvider.notifier).setNotif(f, k, v),
          ),
        const SizedBox(height: Space.md),
      ]),
    );
  }
}

// ── Notifications ──────────────────────────────────────────────────────────

class _Notifications extends ConsumerWidget {
  const _Notifications();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(settingsProvider);
    final favs = ref.watch(activeFavoritesProvider);
    void setKind(NotifKind k, bool on) => ref.read(settingsProvider.notifier).update((x) => x.copyWith(disabledKinds: on ? ({...x.disabledKinds}..remove(k)) : {...x.disabledKinds, k}));

    Widget groupCard(String title, NotifGroup g) => Padding(
          padding: const EdgeInsets.only(bottom: Space.md),
          child: AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 4), child: Overline(title)),
              for (final k in NotifKind.of(g)) SwitchListTile(dense: true, title: Text(k.label, style: AppType.body(15, color: c.text)), value: !s.disabledKinds.contains(k), onChanged: s.notificationsEnabled ? (v) => setKind(k, v) : null),
            ]),
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, 60),
      children: [
        AppCard(
          child: Column(children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Match alerts', style: context.text.titleMedium),
              subtitle: Text('Local alerts for teams, players and competitions you follow', style: AppType.body(12.5, color: c.textMuted)),
              value: s.notificationsEnabled,
              onChanged: (v) async {
                ref.read(settingsProvider.notifier).update((x) => x.copyWith(notificationsEnabled: v));
                if (v) await NotificationService.instance.requestPermission();
              },
            ),
            const SizedBox(height: 6),
            Text('Alerts are generated on this device while the app is open or recently used; kick-off reminders are scheduled with your phone and fire even when the app is closed.', style: AppType.body(12, color: c.textFaint)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: PillButton(label: 'Allow on this device', primary: false, onTap: () async {
                final ok = await NotificationService.instance.requestPermission();
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Notifications allowed' : 'Permission not granted — check system settings')));
              })),
              const SizedBox(width: 10),
              Expanded(child: PillButton(label: 'Inbox', primary: false, icon: Icons.inbox_rounded, onTap: () => context.push('/notifications'))),
            ]),
          ]),
        ),
        const SizedBox(height: Space.lg),
        Text('Categories', style: context.text.headlineSmall),
        const SizedBox(height: Space.sm),
        groupCard('Teams', NotifGroup.team),
        groupCard('Players', NotifGroup.player),
        groupCard('Competitions', NotifGroup.competition),
        if (favs.isNotEmpty) ...[
          const SizedBox(height: Space.sm),
          Text('Per team, player & competition', style: context.text.headlineSmall),
          const SizedBox(height: Space.sm),
          for (final f in favs)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: switch (f.kind) {
                FavKind.team => TeamCrest(team: TeamRef(id: f.id, name: f.name, logo: f.image), size: 32),
                FavKind.player => PlayerAvatar(name: f.name, photo: f.image, size: 32),
                FavKind.league => LeagueLogo(league: LeagueRef(id: f.id, name: f.name, logo: f.image), size: 28),
              },
              title: Text(f.name, style: AppType.body(15, weight: 600, color: c.text)),
              subtitle: Text(f.notifs.map((k) => k.label).join(', '), style: AppType.body(12, color: c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showEntityAlerts(context, f),
            ),
        ],
      ],
    );
  }
}

// ── Appearance / language ──────────────────────────────────────────────────

class _Appearance extends ConsumerWidget {
  const _Appearance();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(settingsProvider);
    Widget themeTile(ThemeMode m, String label, AppColors preview) => Expanded(
          child: Pressable(
            onTap: () => ref.read(settingsProvider.notifier).update((x) => x.copyWith(themeMode: m)),
            child: AnimatedContainer(
              duration: Motion.base,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(borderRadius: Radii.lgAll, border: Border.all(color: s.themeMode == m ? c.accent : c.hairline, width: s.themeMode == m ? 2 : 1)),
              child: Column(children: [
                Container(
                  height: 90,
                  decoration: BoxDecoration(color: preview.bg, borderRadius: Radii.mdAll),
                  padding: const EdgeInsets.all(8),
                  child: Column(children: [
                    Container(height: 26, decoration: BoxDecoration(color: preview.accent, borderRadius: Radii.smAll)),
                    const SizedBox(height: 6),
                    Container(height: 14, decoration: BoxDecoration(color: preview.surface2, borderRadius: Radii.smAll)),
                    const SizedBox(height: 6),
                    Container(height: 14, decoration: BoxDecoration(color: preview.surface2, borderRadius: Radii.smAll)),
                  ]),
                ),
                const SizedBox(height: 8),
                Text(label, style: AppType.body(13.5, weight: 600, color: c.text)),
              ]),
            ),
          ),
        );
    return ListView(padding: const EdgeInsets.all(Space.gutter), children: [
      Row(children: [
        themeTile(ThemeMode.dark, 'Dark', AppColors.dark),
        const SizedBox(width: 10),
        themeTile(ThemeMode.light, 'Light', AppColors.light),
        const SizedBox(width: 10),
        themeTile(ThemeMode.system, 'System', MediaQuery.platformBrightnessOf(context) == Brightness.dark ? AppColors.dark : AppColors.light),
      ]),
      const SizedBox(height: Space.lg),
      AppCard(
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Reduce motion', style: context.text.titleMedium),
          subtitle: Text('Simplifies goal celebrations, chart draw-ins and transitions', style: AppType.body(12.5, color: c.textMuted)),
          value: s.reduceMotion,
          onChanged: (v) => ref.read(settingsProvider.notifier).update((x) => x.copyWith(reduceMotion: v)),
        ),
      ),
    ]);
  }
}

class _Language extends StatelessWidget {
  const _Language();
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(padding: const EdgeInsets.all(Space.gutter), children: [
      AppCard(
        child: Row(children: [
          Expanded(child: Text('English', style: context.text.titleMedium)),
          Icon(Icons.check_circle_rounded, color: c.accentInk),
        ]),
      ),
      const SizedBox(height: Space.md),
      Text('Touchline is available in English. Team, player and competition names are shown as supplied by the data provider.', style: AppType.body(13, color: c.textMuted)),
    ]);
  }
}

// ── Data preferences ───────────────────────────────────────────────────────

class _Data extends ConsumerWidget {
  const _Data();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(settingsProvider);
    final repo = ref.watch(repositoryProvider);
    final budget = ref.watch(budgetStateProvider);
    final now = DateTime.now().year;
    return ListView(padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, 60), children: [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(repo.providerName, style: context.text.titleMedium)),
            if (repo.isDemo) const ProvenanceTag(Provenance.demo, compact: true) else Icon(Env.hasKey ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: Env.hasKey ? c.mint : c.loss),
          ]),
          const SizedBox(height: 6),
          Text(
            repo.isDemo
                ? 'Fictional demo data (debug builds only). Live matches progress in real time so every screen can be tried.'
                : Env.hasKey
                    ? 'API key configured at build time.'
                    : 'No API key. Build with --dart-define=API_FOOTBALL_KEY=your_key.',
            style: AppType.body(13, color: c.textMuted),
          ),
          if (!repo.isDemo && budget.remaining != null) ...[
            const SizedBox(height: 14),
            Row(children: [
              Text('Requests left today', style: AppType.body(13, color: c.text)),
              const Spacer(),
              Text('${budget.remaining}${budget.limit != null ? ' / ${budget.limit}' : ''}', style: AppType.numeric(15, color: c.text)),
            ]),
            const SizedBox(height: 8),
            if (budget.limit != null) ClipRRect(borderRadius: Radii.pillAll, child: LinearProgressIndicator(value: budget.remaining! / budget.limit!, minHeight: 6)),
            if (budget.paused) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Live polling is paused to keep a reserve for browsing. Quota resets at 00:00 UTC.', style: AppType.body(12, color: c.reported))),
          ],
        ]),
      ),
      if (Env.demoAllowed) ...[
        const SizedBox(height: Space.md),
        AppCard(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Demo data (debug only)', style: context.text.titleMedium),
            subtitle: Text(Env.hasKey ? 'Switch between the real API and fictional demo data' : 'Always on without an API key', style: AppType.body(12.5, color: c.textMuted)),
            value: s.useDemo,
            onChanged: Env.hasKey ? (v) => ref.read(settingsProvider.notifier).update((x) => x.copyWith(demoMode: v)) : null,
          ),
        ),
      ],
      const SizedBox(height: Space.md),
      AppCard(
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Data saver', style: context.text.titleMedium),
          subtitle: Text('Refresh live scores half as often', style: AppType.body(12.5, color: c.textMuted)),
          value: s.dataSaver,
          onChanged: (v) => ref.read(settingsProvider.notifier).update((x) => x.copyWith(dataSaver: v)),
        ),
      ),
      const SizedBox(height: Space.md),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Season', style: context.text.titleMedium),
          const SizedBox(height: 4),
          Text('Automatic uses each competition\'s current season. Free API plans may only cover older seasons — pick one here if you see a plan error.', style: AppType.body(12.5, color: c.textMuted)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChipPill(label: 'Automatic', selected: s.seasonOverride == null, onTap: () => ref.read(settingsProvider.notifier).update((x) => x.copyWith(clearSeason: true))),
            for (var y = now; y >= now - 5; y--) ChoiceChipPill(label: seasonLabel(y), selected: s.seasonOverride == y, onTap: () => ref.read(settingsProvider.notifier).update((x) => x.copyWith(seasonOverride: y))),
          ]),
        ]),
      ),
      const SizedBox(height: Space.md),
      AppCard(
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Offline cache', style: context.text.titleMedium),
              Text('${ref.watch(cacheStoreProvider).length} saved responses for offline use', style: AppType.body(12.5, color: c.textMuted)),
            ]),
          ),
          PillButton(label: 'Clear', primary: false, onTap: () async {
            await ref.read(cacheStoreProvider).clear();
            ref.invalidate(repositoryProvider);
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache cleared')));
          }),
        ]),
      ),
    ]);
  }
}

// ── About / privacy ────────────────────────────────────────────────────────

class _About extends ConsumerWidget {
  const _About();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    Widget label(Provenance p, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 150, child: Align(alignment: Alignment.centerLeft, child: ProvenanceTag(p, compact: true))), Expanded(child: Text(text, style: AppType.body(13, color: c.textMuted)))]),
        );
    return ListView(padding: const EdgeInsets.all(Space.gutter), children: [
      Center(child: ClipRRect(borderRadius: Radii.xlAll, child: Image.asset('assets/branding/app_icon.png', width: 96, height: 96, errorBuilder: (_, _, _) => const SizedBox(width: 96, height: 96, child: FallbackArt())))),
      const SizedBox(height: Space.md),
      Center(child: Text('TOUCHLINE', style: AppType.display(26, width: 125, color: c.text))),
      Center(child: Text('Version 1.0.0', style: AppType.body(13, color: c.textMuted))),
      const SizedBox(height: Space.xl),
      Text('How to read our labels', style: context.text.titleMedium),
      const SizedBox(height: 8),
      label(Provenance.confirmed, 'Official data from the provider: results, events, official lineups, completed transfers.'),
      label(Provenance.reported, 'Reported but not official, such as injury doubts.'),
      label(Provenance.predicted, 'The provider\'s statistical predictions. Never shown as fact.'),
      label(Provenance.generated, 'Summaries Touchline writes from confirmed data, like "What just happened?".'),
      const SizedBox(height: Space.lg),
      Text('Data: ${ref.watch(repositoryProvider).providerName}. Team logos and player photos are supplied by the data provider.', style: AppType.body(13, color: c.textMuted)),
      const SizedBox(height: 8),
      Text('Typefaces: Archivo and Inter (SIL Open Font License).', style: AppType.body(13, color: c.textMuted)),
      const SizedBox(height: Space.md),
      TextButton(onPressed: () => showLicensePage(context: context, applicationName: 'Touchline'), child: const Text('Open-source licences')),
    ]);
  }
}

class _Privacy extends ConsumerWidget {
  const _Privacy();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    Widget p(String t) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(t, style: AppType.body(14.5, color: c.text, height: 1.5)));
    return ListView(padding: const EdgeInsets.all(Space.gutter), children: [
      p('Touchline has no accounts and no tracking. Your follows, alert settings, recently viewed items and cached match data are stored only on this device.'),
      p('To show football data the app sends requests to the data provider (API-Football) using the API key built into the app. Requests contain only what\'s needed — for example a match or team ID — and nothing about you.'),
      p('Notifications are generated locally on your device. No push server is involved.'),
      p('Sharing a graphic uses your phone\'s share sheet; nothing is uploaded by Touchline.'),
      const SizedBox(height: Space.md),
      PillButton(
        label: 'Delete all local data',
        primary: false,
        icon: Icons.delete_outline_rounded,
        onTap: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (d) => AlertDialog(
              title: const Text('Delete all local data?'),
              content: const Text('This removes your follows, settings, alert history and offline cache from this device.'),
              actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete'))],
            ),
          );
          if (ok != true) return;
          final store = ref.read(localStoreProvider);
          for (final k in ['favorites', 'recent', 'recent_demo', 'recent_queries', 'notif_log', 'fired', ...store.keysWithPrefix('seen:'), ...store.keysWithPrefix('ranks:')]) {
            await store.remove(k);
          }
          await ref.read(cacheStoreProvider).clear();
          ref.invalidate(favoritesProvider);
          ref.invalidate(recentProvider);
          ref.invalidate(alertLogProvider);
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Local data deleted')));
        },
      ),
    ]);
  }
}
