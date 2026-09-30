import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/favorites.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/settings.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/football_repository.dart';
import '../../data/models/models.dart';
import '../../domain/match_diff.dart';
import 'notification_service.dart';

class LoggedAlert {
  const LoggedAlert({required this.title, required this.body, this.route, required this.at});
  final String title;
  final String body;
  final String? route;
  final DateTime at;
  Map<String, dynamic> toJson() => {'t': title, 'b': body, 'r': route, 'at': at.millisecondsSinceEpoch};
  static LoggedAlert fromJson(dynamic j) => LoggedAlert(title: j['t'] ?? '', body: j['b'] ?? '', route: j['r'], at: DateTime.fromMillisecondsSinceEpoch((j['at'] as num).toInt()));
}

class AlertLog extends Notifier<List<LoggedAlert>> {
  @override
  List<LoggedAlert> build() => (ref.read(localStoreProvider).readList('notif_log') ?? const []).map(LoggedAlert.fromJson).toList();

  void add(LoggedAlert a) {
    state = [a, ...state].take(100).toList();
    ref.read(localStoreProvider).write('notif_log', state.map((e) => e.toJson()).toList());
  }

  void clear() {
    state = const [];
    ref.read(localStoreProvider).write('notif_log', const []);
  }
}

final alertLogProvider = NotifierProvider<AlertLog, List<LoggedAlert>>(AlertLog.new);

/// Watches followed matches and raises local notifications for the
/// categories the user enabled (spec §30). Cost-aware: it only polls while a
/// followed match is live or about to start, and reuses the live feed cache
/// shared with the UI.
class LiveWatcher {
  LiveWatcher(this.ref);
  final Ref ref;
  Timer? _timer;
  bool _disposed = false;
  final _last = <int, Match>{};
  final _lineupChecked = <int, DateTime>{};
  final _scheduled = <int>{};
  DateTime? _importantCheckedDay;
  late Set<String> _fired = {...(ref.read(localStoreProvider).readList('fired') ?? const []).map((e) => '$e')};

  void start() => _schedule(const Duration(seconds: 4));
  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }

  void _schedule(Duration d) {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(d, () async {
      Duration next;
      try {
        next = await _tick();
      } catch (e) {
        debugPrint('LiveWatcher: $e');
        next = const Duration(minutes: 5);
      }
      _schedule(next);
    });
  }

  FootballRepository get _repo => ref.read(repositoryProvider);

  Future<Duration> _tick() async {
    final settings = ref.read(settingsProvider);
    final favs = ref.read(activeFavoritesProvider);
    final demo = _repo.isDemo;
    if (!settings.notificationsEnabled || favs.isEmpty) return const Duration(minutes: 10);

    final teams = {for (final f in favs.where((f) => f.kind == FavKind.team)) f.id};
    final playerTeams = {for (final f in favs.where((f) => f.kind == FavKind.player && f.teamId != null)) f.teamId!};
    final leagues = {for (final f in favs.where((f) => f.kind == FavKind.league)) f.id};
    bool relevant(Match m) => teams.contains(m.home.id) || teams.contains(m.away.id) || playerTeams.contains(m.home.id) || playerTeams.contains(m.away.id) || leagues.contains(m.league.id);

    final now = DateTime.now();
    final today = (await _repo.matchesOn(dateOnly(now))).data.where(relevant).toList();
    await _scheduleKickoffs(today, favs);
    await _importantFixtures(today, leagues);

    // Seed baselines only from list entries that can't be out of date
    // (a "not started" entry whose kick-off has passed would fire stale alerts).
    for (final m in today.where((m) => !(m.status.isScheduled && m.kickoff.isBefore(now)))) {
      _last.putIfAbsent(m.id, () => m);
    }
    final soon = today.where((m) => m.status.isScheduled && m.kickoff.difference(now) < const Duration(minutes: 70)).toList();
    final liveNow = today.any((m) => m.status.isLive) || _last.values.any((m) => m.status.isLive);
    if (soon.isEmpty && !liveNow) return demo ? const Duration(seconds: 30) : const Duration(minutes: 15);

    // Lineups for matches about to start (one detail call per 15 min).
    for (final m in soon) {
      final checked = _lineupChecked[m.id];
      if (checked != null && now.difference(checked) < Duration(minutes: demo ? 1 : 15)) continue;
      _lineupChecked[m.id] = now;
      final d = (await _repo.match(m.id)).data;
      _observe(d);
    }

    // Live feed (shared cache with the UI's live list).
    final live = (await _repo.liveMatches()).data.where(relevant).toList();
    final liveIds = {for (final m in live) m.id};
    for (final m in live) {
      _observe(m);
    }
    // Matches that dropped out of the live feed have finished: confirm once.
    for (final gone in _last.values.where((m) => m.status.isLive && !liveIds.contains(m.id)).toList()) {
      final d = (await _repo.match(gone.id)).data;
      _observe(d);
      if (d.status.isFinished && leagues.contains(d.league.id)) unawaited(_leagueUpdate(d.league.id));
    }
    final interval = demo ? const Duration(seconds: 8) : (ref.read(budgetProvider).liveInterval() ?? const Duration(minutes: 5));
    return interval;
  }

  void _observe(Match next) {
    final prev = _last[next.id];
    final merged = prev != null && next.lineups == null ? next.copyWith(lineups: prev.lineups) : next;
    _last[next.id] = merged;
    for (final ch in diffMatch(prev, merged)) {
      _dispatch(ch);
    }
  }

  void _dispatch(MatchChange ch) {
    if (_fired.contains(ch.key)) return;
    final alert = _alertFor(ch);
    if (alert == null) return;
    _fired.add(ch.key);
    if (_fired.length > 400) _fired = _fired.skip(_fired.length - 300).toSet();
    ref.read(localStoreProvider).write('fired', _fired.toList());
    NotificationService.instance.show(alert);
    ref.read(alertLogProvider.notifier).add(LoggedAlert(title: alert.title, body: alert.body, route: alert.route, at: DateTime.now()));
  }

  AppAlert? _alertFor(MatchChange ch) {
    final s = ref.read(settingsProvider);
    bool on(Favorite f, NotifKind k) => f.notifs.contains(k) && !s.disabledKinds.contains(k);
    final favs = ref.read(activeFavoritesProvider);
    final m = ch.match;
    final route = '/match/${m.id}';
    final id = ch.key.hashCode & 0x7fffffff;

    // Player-specific alerts first (more specific wording).
    for (final p in favs.where((f) => f.kind == FavKind.player)) {
      final e = ch.event;
      final (NotifKind? kind, String? title) = switch (ch.kind) {
        ChangeKind.goal when e?.playerId == p.id && e?.kind != EventKind.ownGoal => (NotifKind.playerGoal, '⚽ ${p.name} scores!'),
        ChangeKind.goal when e?.relatedId == p.id => (NotifKind.playerAssist, '🅰️ Assist for ${p.name}'),
        ChangeKind.substitution when e?.playerId == p.id || e?.relatedId == p.id => (NotifKind.playerSub, '🔄 ${p.name} ${e?.playerId == p.id ? 'comes on' : 'is substituted'}'),
        ChangeKind.redCard when e?.playerId == p.id => (NotifKind.playerRed, '🟥 ${p.name} sent off'),
        ChangeKind.lineups when (m.lineups ?? const <Lineup>[]).any((l) => l.startXI.any((x) => x.id == p.id)) => (NotifKind.playerStarting, '📋 ${p.name} starts'),
        _ => (null, null),
      };
      if (kind != null && on(p, kind)) {
        return AppAlert(id: id, title: title!, body: '${m.home.name} ${m.homeGoals ?? 0}–${m.awayGoals ?? 0} ${m.away.name}${e != null ? ' · ${e.minuteLabel}' : ''}', route: route, goal: ch.kind == ChangeKind.goal);
      }
    }

    final teamKind = switch (ch.kind) {
      ChangeKind.kickoff => NotifKind.matchStart,
      ChangeKind.goal => NotifKind.goals,
      ChangeKind.halftime || ChangeKind.secondHalf => NotifKind.halfTime,
      ChangeKind.fulltime => NotifKind.fullTime,
      ChangeKind.redCard => NotifKind.redCards,
      ChangeKind.lineups => NotifKind.lineups,
      ChangeKind.substitution => NotifKind.substitutions,
      ChangeKind.varDecision || ChangeKind.missedPenalty => NotifKind.importantEvents,
    };
    for (final t in favs.where((f) => f.kind == FavKind.team && m.involves(f.id))) {
      if (on(t, teamKind)) return AppAlert(id: id, title: ch.title, body: ch.body, route: route, goal: ch.kind == ChangeKind.goal);
    }
    if (ch.kind == ChangeKind.fulltime) {
      for (final l in favs.where((f) => f.kind == FavKind.league && f.id == m.league.id)) {
        if (on(l, NotifKind.results)) return AppAlert(id: id, title: ch.title, body: m.league.name, route: route);
      }
    }
    return null;
  }

  Future<void> _scheduleKickoffs(List<Match> today, List<Favorite> favs) async {
    final s = ref.read(settingsProvider);
    if (s.disabledKinds.contains(NotifKind.matchStart)) return;
    for (final m in today.where((m) => m.status.isScheduled)) {
      final wants = favs.any((f) => f.kind == FavKind.team && m.involves(f.id) && f.notifs.contains(NotifKind.matchStart));
      if (!wants || !_scheduled.add(m.id)) continue;
      await NotificationService.instance.scheduleAt(
        id: (m.id * 7) & 0x7fffffff,
        when: m.kickoff,
        title: 'Kick-off · ${m.home.name} vs ${m.away.name}',
        body: '${m.league.name} · ${kickoffTime(m.kickoff)}',
        route: '/match/${m.id}',
      );
    }
  }

  /// "Important fixtures" = today's matches in a followed competition between
  /// two teams in the provider's top six. Uses one standings call per league
  /// per day.
  Future<void> _importantFixtures(List<Match> today, Set<int> leagues) async {
    final s = ref.read(settingsProvider);
    final day = dateOnly(DateTime.now());
    if (_importantCheckedDay == day || leagues.isEmpty || s.disabledKinds.contains(NotifKind.importantFixtures)) return;
    _importantCheckedDay = day;
    final favs = ref.read(activeFavoritesProvider);
    for (final lid in leagues) {
      final fav = favs.firstWhere((f) => f.kind == FavKind.league && f.id == lid);
      if (!fav.notifs.contains(NotifKind.importantFixtures)) continue;
      final ms = today.where((m) => m.league.id == lid && m.status.isScheduled).toList();
      if (ms.isEmpty) continue;
      final season = ms.first.league.season;
      if (season == null) continue;
      final table = (await _repo.standings(lid, season)).data;
      if (table == null) continue;
      final top = {for (final g in table.groups) ...g.rows.where((r) => r.rank <= 6).map((r) => r.team.id)};
      for (final m in ms.where((m) => top.contains(m.home.id) && top.contains(m.away.id))) {
        final key = 'important:${m.id}';
        if (_fired.contains(key)) continue;
        _fired.add(key);
        final a = AppAlert(id: key.hashCode & 0x7fffffff, title: 'Big match today · ${m.home.name} vs ${m.away.name}', body: '${m.league.name} top-six clash · ${kickoffTime(m.kickoff)}', route: '/match/${m.id}');
        NotificationService.instance.show(a);
        ref.read(alertLogProvider.notifier).add(LoggedAlert(title: a.title, body: a.body, route: a.route, at: DateTime.now()));
      }
    }
  }

  /// "League updates": after a result in a followed competition, report a
  /// change of leader or a followed team's position change.
  Future<void> _leagueUpdate(int leagueId) async {
    final favs = ref.read(activeFavoritesProvider);
    final fav = favs.where((f) => f.kind == FavKind.league && f.id == leagueId).firstOrNull;
    if (fav == null || !fav.notifs.contains(NotifKind.leagueUpdates) || ref.read(settingsProvider).disabledKinds.contains(NotifKind.leagueUpdates)) return;
    final season = (await ref.read(leagueSeasonProvider(leagueId).future));
    final table = (await _repo.standings(leagueId, season)).data;
    if (table == null || table.groups.isEmpty) return;
    final store = ref.read(localStoreProvider);
    final prev = store.readMap('ranks:$leagueId') ?? const {};
    final rows = table.groups.first.rows;
    final followedTeams = {for (final f in favs.where((f) => f.kind == FavKind.team)) f.id};
    final lines = <String>[];
    final leader = rows.first;
    if (prev['leader'] != null && prev['leader'] != leader.team.id) lines.add('${leader.team.name} go top');
    for (final r in rows.where((r) => followedTeams.contains(r.team.id))) {
      final old = (prev['${r.team.id}'] as num?)?.toInt();
      if (old != null && old != r.rank) lines.add('${r.team.name} ${old > r.rank ? 'up' : 'down'} to ${ordinal(r.rank)}');
    }
    await store.write('ranks:$leagueId', {'leader': leader.team.id, for (final r in rows) '${r.team.id}': r.rank});
    if (lines.isEmpty) return;
    final a = AppAlert(id: (leagueId * 31 + DateTime.now().day) & 0x7fffffff, title: '${table.league.name} table update', body: lines.join(' · '), route: '/league/$leagueId');
    NotificationService.instance.show(a);
    ref.read(alertLogProvider.notifier).add(LoggedAlert(title: a.title, body: a.body, route: a.route, at: DateTime.now()));
  }
}

final liveWatcherProvider = Provider<LiveWatcher>((ref) {
  ref.watch(repositoryProvider); // restart when the data source changes
  final w = LiveWatcher(ref)..start();
  ref.onDispose(w.dispose);
  return w;
});

/// Slide-down in-app banner for alerts raised while the app is open. Goals
/// get the accent treatment.
class InAppAlertOverlay extends StatefulWidget {
  const InAppAlertOverlay({super.key});
  @override
  State<InAppAlertOverlay> createState() => _InAppAlertOverlayState();
}

class _InAppAlertOverlayState extends State<InAppAlertOverlay> {
  AppAlert? _current;
  Timer? _hide;
  late final StreamSubscription<AppAlert> _sub;
  late final StreamSubscription<String> _taps;

  @override
  void initState() {
    super.initState();
    _sub = NotificationService.instance.alerts.stream.listen((a) {
      if (!mounted) return;
      if (a.goal) HapticFeedback.heavyImpact();
      setState(() => _current = a);
      _hide?.cancel();
      _hide = Timer(const Duration(seconds: 5), () => mounted ? setState(() => _current = null) : null);
    });
    _taps = NotificationService.instance.taps.stream.listen((route) => rootNavigatorKey.currentContext?.push(route));
  }

  @override
  void dispose() {
    _sub.cancel();
    _taps.cancel();
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = _current;
    return Positioned(
      left: 12,
      right: 12,
      top: MediaQuery.paddingOf(context).top + 8,
      child: AnimatedSwitcher(
        duration: Motion.slow,
        switchInCurve: Motion.spring,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) => SlideTransition(position: Tween(begin: const Offset(0, -1.2), end: Offset.zero).animate(anim), child: FadeTransition(opacity: anim, child: child)),
        child: a == null
            ? const SizedBox.shrink()
            : Dismissible(
                key: ValueKey(a.id),
                direction: DismissDirection.up,
                onDismissed: (_) => setState(() => _current = null),
                child: Pressable(
                  onTap: () {
                    setState(() => _current = null);
                    if (a.route != null) context.push(a.route!);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: a.goal ? c.accent : c.surface3,
                      borderRadius: Radii.lgAll,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 10))],
                    ),
                    child: Row(children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: a.goal ? c.onAccent : c.surface2),
                        child: Icon(a.goal ? Icons.sports_soccer : Icons.notifications_active_rounded, size: 20, color: a.goal ? c.accent : c.text),
                      ).animate(key: ValueKey(a.id)).rotate(begin: -0.25, duration: Motion.slow, curve: Motion.spring),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(a.title, style: AppType.body(14.5, weight: 700, color: a.goal ? c.onAccent : c.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(a.body, style: AppType.body(13, color: a.goal ? c.onAccent.withValues(alpha: 0.75) : c.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
      ),
    );
  }
}
