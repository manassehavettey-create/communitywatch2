import 'dart:math' as math;

import '../../core/utils/format.dart';
import '../../core/utils/fuzzy.dart';
import '../football_repository.dart';
import '../models/models.dart';

/// DEBUG-ONLY demo provider. A deterministic, entirely fictional football
/// universe (no real clubs or players) whose live matches progress in real
/// time so every screen, animation and notification can be exercised without
/// an API key. Every response is tagged [Provenance.demo] and the UI shows a
/// DEMO badge. Never available in release builds (see `env.dart`).
class DemoRepository implements FootballRepository {
  DemoRepository({DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    final n = _clock();
    _anchor = DateTime(n.year, n.month, n.day, n.hour, n.minute);
    _build();
  }

  final DateTime Function() _clock;
  late final DateTime _anchor;
  static const season = 2026;

  @override
  String get providerName => 'Demo data';
  @override
  bool get isDemo => true;
  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
        xg: true,
        xa: true,
        momentum: true,
        shotMap: true,
        heatmap: true,
        passMap: true,
        touches: true,
        commentary: false,
        reportedTransfers: false,
        predictedLineups: false,
      );

  Fresh<T> _f<T>(T v) => Fresh(v, fetchedAt: _clock(), provenance: Provenance.demo);
  Future<Fresh<T>> _ok<T>(T v) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return _f(v);
  }

  // ── Universe ─────────────────────────────────────────────────────────────
  static const _l1Teams = [
    'Northbank FC', 'Riverside Athletic', 'Kingsport United', 'Harbour City', 'Ashford Rovers', 'Westmoor Town', 'Crown Park', 'Eastvale Wanderers', 'Millbrook FC', 'Redcastle',
    'Stonebridge', 'Oakfield Albion', 'Blackwater City', 'Highgate Forest', 'Lakeside United', 'Ironworks FC', 'Greenhill', 'Seaview Borough', 'Thornbury', 'Copperfield'
  ];
  static const _l2Teams = [
    'Real Marisol', 'Atlético Brisa', 'CD Solana', 'Deportivo Faro', 'Sporting Lumen', 'Unión Arenal', 'CF Mirador', 'Racing Alba', 'Club Olivar', 'Estrella Norte',
    'Villa Coral', 'Sierra CF', 'Puerto Azul', 'Valle Rojo', 'Costa Dorada', 'Atlético Pinar', 'CD Almena', 'Nube Blanca'
  ];
  static const _first = [
    'Leo', 'Mateo', 'Kai', 'Noah', 'Ilias', 'Tomas', 'Rafael', 'Jonas', 'Ethan', 'Luca', 'Aaron', 'Milan', 'Theo', 'Sami', 'Adrian', 'Kofi', 'Yann', 'Oscar', 'Emil', 'Nico',
    'Hugo', 'Dario', 'Ibrahim', 'Jules', 'Marco', 'Felix', 'Isak', 'Tariq', 'Bruno', 'Caleb', 'Victor', 'Andre', 'Elias', 'Ruben', 'Omar', 'Diego', 'Kian', 'Pedro', 'Lars', 'Mika'
  ];
  static const _last = [
    'Varga', 'Okafor', 'Lindqvist', 'Moreau', 'Castell', 'Brandt', 'Achterberg', 'Silvano', 'Nakamura', 'Oduya', 'Petrović', 'Harlow', 'Quintero', 'Asante', 'Kovács', 'Delacroix',
    'Ferreira', 'Mbeki', 'Holm', 'Ricci', 'Novak', 'Salas', 'Obi', 'Laurent', 'Duarte', 'Kessler', 'Yılmaz', 'Mensah', 'Rossetti', 'Dubois', 'Eriksen', 'Tavares', 'Vidal',
    'Kamara', 'Bergman', 'Almeida', 'Zeller', 'Costa', 'Wrightson', 'Fontaine', 'Adeyemi', 'Sørensen', 'Iglesias'
  ];
  static const _nations = ['Demo Land', 'Costa Verde', 'Nordhavn', 'Aurelia', 'Kestria', 'Montalba', 'Sahel Coast', 'Valdoria'];

  static const _leagueDefs = [
    (id: 9001, name: 'Premier Division', country: 'Demo Land', teams: _l1Teams, teamBase: 1000, currentMd: 8),
    (id: 9002, name: 'Liga Costa', country: 'Costa Verde', teams: _l2Teams, teamBase: 2000, currentMd: 7),
  ];

  final _teams = <int, TeamRef>{};
  final _teamLeague = <int, int>{};
  final _strength = <int, double>{};
  final _squads = <int, List<SquadPlayer>>{};
  final _playerTeam = <int, int>{};
  final _playerQuality = <int, double>{};
  final _matches = <int, Match>{}; // skeletons (no status)
  final _leagueRounds = <int, int>{};

  void _build() {
    for (final def in _leagueDefs) {
      final ids = <int>[];
      for (var i = 0; i < def.teams.length; i++) {
        final id = def.teamBase + i + 1;
        ids.add(id);
        _teams[id] = TeamRef(id: id, name: def.teams[i]);
        _teamLeague[id] = def.id;
        final r = math.Random(id);
        _strength[id] = 1.45 - i * 0.045 + r.nextDouble() * 0.2;
        _squads[id] = _makeSquad(id);
      }
      _schedule(def.id, def.name, def.country, ids, def.currentMd);
    }
  }

  List<SquadPlayer> _makeSquad(int teamId) {
    const shape = ['G', 'G', 'D', 'D', 'D', 'D', 'D', 'D', 'D', 'M', 'M', 'M', 'M', 'M', 'M', 'M', 'F', 'F', 'F', 'F', 'F', 'F'];
    const pos = {'G': 'Goalkeeper', 'D': 'Defender', 'M': 'Midfielder', 'F': 'Attacker'};
    final out = <SquadPlayer>[];
    final r = math.Random(teamId * 31);
    final used = <int>{};
    for (var i = 0; i < shape.length; i++) {
      final id = teamId * 100 + i + 1;
      final fn = _first[(id * 7 + i) % _first.length];
      final ln = _last[(id * 13 + teamId) % _last.length];
      var number = switch (shape[i]) { 'G' => i == 0 ? 1 : 13, 'D' => 2 + (i - 2), 'M' => 6 + (i - 9), _ => 9 + (i - 16) };
      while (!used.add(number)) {
        number += 10;
      }
      out.add(SquadPlayer(id: id, name: '$fn $ln', age: 18 + r.nextInt(17), number: number, position: pos[shape[i]]));
      _playerTeam[id] = teamId;
      _playerQuality[id] = 0.75 + r.nextDouble() * 0.5 + (i < 2 || (i >= 9 && i < 12) || (i >= 16 && i < 19) ? 0.15 : 0);
    }
    return out;
  }

  /// Circle-method round robin, anchored so the current matchday is today.
  void _schedule(int leagueId, String name, String country, List<int> teams, int currentMd) {
    final n = teams.length;
    final rot = [...teams];
    final rounds = <List<(int, int)>>[];
    for (var r = 0; r < n - 1; r++) {
      final pairs = <(int, int)>[];
      for (var i = 0; i < n ~/ 2; i++) {
        final a = rot[i], b = rot[n - 1 - i];
        pairs.add((r + i).isEven ? (a, b) : (b, a));
      }
      rounds.add(pairs);
      rot.insert(1, rot.removeLast());
    }
    final total = currentMd + 6;
    _leagueRounds[leagueId] = total;
    // Minute offsets (relative to app start) for today's fixtures, so the
    // demo always has finished, live, half-time and upcoming matches.
    final today = leagueId == 9001 ? [-200, -150, -73, -58, -30, -3, 20, 95, 180, 240] : [-120, -80, -45, -10, 40, 100, 160, 220, 300];
    for (var md = 1; md <= total; md++) {
      final pairs = rounds[(md - 1) % rounds.length];
      for (var i = 0; i < pairs.length; i++) {
        final id = (leagueId == 9001 ? 100000 : 200000) + md * 100 + i;
        DateTime kickoff;
        if (md == currentMd) {
          kickoff = _anchor.add(Duration(minutes: today[i % today.length]));
        } else {
          final day = dateOnly(_anchor).add(Duration(days: (md - currentMd) * 7 + (leagueId == 9002 ? 1 : 0)));
          kickoff = day.add(Duration(hours: 13 + (i % 4) * 2, minutes: i.isEven ? 0 : 30));
        }
        final (h, a) = pairs[i];
        _matches[id] = Match(
          id: id,
          league: LeagueRef(id: leagueId, name: name, country: country, season: season, round: 'Regular Season - $md'),
          home: _teams[h]!,
          away: _teams[a]!,
          kickoff: kickoff,
          status: const MatchStatus(short: 'NS'),
          venue: '${_teams[h]!.name.split(' ').first} Arena',
          city: country,
          referee: '${_first[(id) % _first.length]} ${_last[(id * 3) % _last.length]}',
        );
      }
    }
  }

  // ── Match simulation ─────────────────────────────────────────────────────
  final _scripts = <int, _Script>{};

  /// Match minute (1..94) for a real elapsed time since kickoff, or status.
  MatchStatus _statusFor(Match m) {
    final e = _clock().difference(m.kickoff).inSeconds / 60.0;
    if (e < 0) return const MatchStatus(short: 'NS', long: 'Not Started');
    if (e < 47) {
      final min = e.floor() + 1;
      return MatchStatus(short: '1H', long: 'First Half', elapsed: min > 45 ? 45 : min, extra: min > 45 ? min - 45 : null);
    }
    if (e < 62) return const MatchStatus(short: 'HT', long: 'Halftime', elapsed: 45);
    if (e < 111) {
      final min = 46 + (e - 62).floor();
      return MatchStatus(short: '2H', long: 'Second Half', elapsed: min > 90 ? 90 : min, extra: min > 90 ? min - 90 : null);
    }
    return const MatchStatus(short: 'FT', long: 'Match Finished', elapsed: 90);
  }

  /// Continuous timeline position: 45+2 → 47, 2nd half 46 → 48 …
  int _timeline(MatchStatus s) {
    if (s.isScheduled) return -1;
    if (s.short == 'HT') return 47;
    if (s.isFinished) return 999;
    final el = s.elapsed ?? 0;
    return s.short == '1H' ? el + (s.extra ?? 0) : el + 2 + (s.extra ?? 0);
  }

  _Script _script(Match m) => _scripts.putIfAbsent(m.id, () => _Script.generate(m, this));

  Match _materialise(Match base, {bool detail = false}) {
    final st = _statusFor(base);
    if (st.isScheduled) {
      final lineupsOut = detail && _clock().isAfter(base.kickoff.subtract(const Duration(minutes: 60)));
      return base.copyWith(status: st, events: const [], lineups: lineupsOut ? _script(base).lineups : const [], players: const []);
    }
    final s = _script(base);
    final t = _timeline(st);
    final events = s.events.where((e) => s.timelineOf(e) <= t).toList();
    final goals = events.where((e) => e.isGoal);
    int goalsFor(int teamId) => goals.where((e) => e.kind == EventKind.ownGoal ? e.teamId != teamId : e.teamId == teamId).length;
    final hg = goalsFor(base.home.id), ag = goalsFor(base.away.id);
    final htEvents = s.events.where((e) => s.timelineOf(e) <= 47 && e.isGoal);
    int htFor(int teamId) => htEvents.where((e) => e.kind == EventKind.ownGoal ? e.teamId != teamId : e.teamId == teamId).length;
    final pastHalf = t >= 47;
    var m = base.copyWith(
      status: st,
      homeGoals: hg,
      awayGoals: ag,
      halftime: pastHalf ? ScorePair(htFor(base.home.id), htFor(base.away.id)) : ScorePair.empty,
      homeWinner: st.isFinished ? (hg > ag ? true : (hg < ag ? false : null)) : null,
      awayWinner: st.isFinished ? (ag > hg ? true : (ag < hg ? false : null)) : null,
      events: events,
    );
    if (detail) {
      m = m.copyWith(lineups: s.lineups, stats: s.statsAt(t), players: s.playersAt(t, events));
    }
    return m;
  }

  List<Match> _all({bool Function(Match)? where}) => [
        for (final m in _matches.values)
          if (where == null || where(m)) _materialise(m),
      ];

  // ── Matches ──────────────────────────────────────────────────────────────
  @override
  Future<Fresh<List<Match>>> liveMatches({bool force = false}) => _ok(_all(where: (m) => _statusFor(m).isLive));

  @override
  Future<Fresh<List<Match>>> matchesOn(DateTime day, {bool force = false}) => _ok(_all(where: (m) => sameDay(m.kickoff, day))..sort((a, b) => a.kickoff.compareTo(b.kickoff)));

  @override
  Future<Fresh<Match>> match(int id, {bool force = false}) async {
    final base = _matches[id];
    if (base == null) throw const DataException(DataErrorKind.notFound, 'Match not found.');
    return _ok(_materialise(base, detail: true));
  }

  @override
  Future<Fresh<List<Match>>> matchesByIds(List<int> ids) => _ok([for (final id in ids) if (_matches[id] != null) _materialise(_matches[id]!, detail: true)]);

  @override
  Future<Fresh<MatchAnalytics?>> analytics(int matchId, {bool force = false}) async {
    final base = _matches[matchId];
    if (base == null) return _f(null);
    final st = _statusFor(base);
    if (st.isScheduled) return _f(null);
    return _ok(_script(base).analyticsAt(_timeline(st)));
  }

  @override
  Future<Fresh<List<Match>>> headToHead(int teamA, int teamB) async {
    final ta = _teams[teamA], tb = _teams[teamB];
    if (ta == null || tb == null) return _f(const []);
    final out = _all(where: (m) => m.involves(teamA) && m.involves(teamB)).where((m) => m.status.isFinished).toList();
    final r = math.Random(teamA * teamB);
    for (var i = 0; i < 6; i++) {
      final homeIsA = i.isEven;
      final hg = r.nextInt(4), ag = r.nextInt(3);
      out.add(Match(
        id: 900000 + i + (teamA + teamB) * 10,
        league: LeagueRef(id: _teamLeague[teamA]!, name: _leagueDefs.firstWhere((d) => d.id == _teamLeague[teamA]).name, season: season - 1 - i ~/ 2),
        home: homeIsA ? ta : tb,
        away: homeIsA ? tb : ta,
        kickoff: DateTime(season - 1 - i ~/ 2, i.isEven ? 11 : 3, 5 + i * 3, 16),
        status: const MatchStatus(short: 'FT', elapsed: 90),
        homeGoals: hg,
        awayGoals: ag,
        homeWinner: hg > ag ? true : (hg < ag ? false : null),
        awayWinner: ag > hg ? true : (ag < hg ? false : null),
        venue: '${(homeIsA ? ta : tb).name.split(' ').first} Arena',
      ));
    }
    out.sort((a, b) => b.kickoff.compareTo(a.kickoff));
    return _ok(out);
  }

  @override
  Future<Fresh<List<Injury>>> injuries(int matchId) async {
    final base = _matches[matchId];
    if (base == null) return _f(const []);
    final r = math.Random(matchId * 5);
    const reasons = ['Hamstring injury', 'Knee injury', 'Suspended', 'Illness', 'Ankle injury'];
    final out = <Injury>[];
    for (final t in [base.home, base.away]) {
      final squad = _squads[t.id]!;
      for (var i = 0; i < 1 + r.nextInt(2); i++) {
        final p = squad[18 + r.nextInt(4)];
        final reason = reasons[r.nextInt(reasons.length)];
        out.add(Injury(player: PlayerRef(id: p.id, name: p.name), teamId: t.id, type: r.nextBool() ? 'Missing Fixture' : 'Questionable', reason: reason));
      }
    }
    return _ok(out);
  }

  @override
  Future<Fresh<Prediction?>> prediction(int matchId) async {
    final base = _matches[matchId];
    if (base == null) return _f(null);
    final h = _strength[base.home.id]! * 1.1, a = _strength[base.away.id]!;
    final draw = 0.26;
    final ph = (1 - draw) * h / (h + a), pa = (1 - draw) * a / (h + a);
    return Fresh(
      Prediction(homePct: (ph * 100).roundToDouble(), drawPct: (draw * 100).roundToDouble(), awayPct: (pa * 100).roundToDouble(), advice: 'Double chance: ${ph > pa ? base.home.name : base.away.name} or draw', winnerName: ph > pa ? base.home.name : base.away.name),
      fetchedAt: _clock(),
      provenance: Provenance.demo,
    );
  }

  // ── Competitions ─────────────────────────────────────────────────────────
  LeagueInfo _leagueInfo(int id) {
    final d = _leagueDefs.firstWhere((x) => x.id == id);
    return LeagueInfo(
      ref: LeagueRef(id: d.id, name: d.name, country: d.country, season: season),
      type: 'League',
      seasons: [
        SeasonInfo(year: season - 1, start: DateTime(season - 1, 8, 8), end: DateTime(season, 5, 24)),
        SeasonInfo(year: season, start: DateTime(season, 8, 14), end: DateTime(season + 1, 5, 23), current: true),
      ],
    );
  }

  @override
  Future<Fresh<List<LeagueInfo>>> leagues() => _ok([for (final d in _leagueDefs) _leagueInfo(d.id)]);

  @override
  Future<Fresh<LeagueInfo?>> league(int id) => _ok(_leagueDefs.any((d) => d.id == id) ? _leagueInfo(id) : null);

  @override
  Future<Fresh<StandingsTable?>> standings(int leagueId, int season) async {
    if (!_leagueDefs.any((d) => d.id == leagueId) || season != DemoRepository.season) return _f(null);
    final finished = _all(where: (m) => m.league.id == leagueId).where((m) => m.status.isFinished).toList();
    final lastRound = finished.map((m) => _round(m)).fold(0, math.max);
    final now = _table(leagueId, finished);
    final before = _table(leagueId, finished.where((m) => _round(m) < lastRound).toList());
    final prevRank = {for (var i = 0; i < before.length; i++) before[i].team.id: i + 1};
    final rows = <StandingRow>[];
    for (var i = 0; i < now.length; i++) {
      final r = now[i];
      final rank = i + 1;
      final prev = prevRank[r.team.id] ?? rank;
      rows.add(StandingRow(
        rank: rank,
        team: r.team,
        points: r.points,
        played: r.played,
        win: r.win,
        draw: r.draw,
        lose: r.lose,
        goalsFor: r.goalsFor,
        goalsAgainst: r.goalsAgainst,
        goalDiff: r.goalDiff,
        form: r.form,
        description: _zone(leagueId, rank, now.length),
        trend: prev > rank ? Trend.up : (prev < rank ? Trend.down : Trend.same),
      ));
    }
    final lg = _leagueInfo(leagueId).ref;
    return _ok(StandingsTable(league: lg, season: season, groups: [StandingsGroup(null, rows)]));
  }

  int _round(Match m) => int.tryParse(m.league.round?.split(' - ').last ?? '') ?? 0;

  String? _zone(int leagueId, int rank, int n) {
    if (leagueId == 9001) {
      if (rank <= 4) return 'Promotion - Continental Cup (League phase)';
      if (rank == 5) return 'Promotion - Europa Trophy (League phase)';
      if (rank == 6) return 'Promotion - Conference Shield (Qualification)';
      if (rank > n - 3) return 'Relegation - First Division';
      return null;
    }
    if (rank <= 4) return 'Promotion - Continental Cup (League phase)';
    if (rank <= 6) return 'Promotion - Europa Trophy (League phase)';
    if (rank == n - 2) return 'Relegation play-off';
    if (rank > n - 2) return 'Relegation - Segunda Costa';
    return null;
  }

  List<StandingRow> _table(int leagueId, List<Match> finished) {
    final teams = _teams.values.where((t) => _teamLeague[t.id] == leagueId);
    final rows = <StandingRow>[];
    for (final t in teams) {
      final ms = finished.where((m) => m.involves(t.id)).toList()..sort((a, b) => a.kickoff.compareTo(b.kickoff));
      var w = 0, d = 0, l = 0, gf = 0, ga = 0;
      final form = StringBuffer();
      for (final m in ms) {
        final r = m.resultFor(t.id);
        if (r == 'W') w++;
        if (r == 'D') d++;
        if (r == 'L') l++;
        gf += (m.isHome(t.id) ? m.homeGoals : m.awayGoals) ?? 0;
        ga += (m.isHome(t.id) ? m.awayGoals : m.homeGoals) ?? 0;
      }
      for (final m in ms.reversed.take(5).toList().reversed) {
        form.write(m.resultFor(t.id) ?? '');
      }
      rows.add(StandingRow(rank: 0, team: t, points: w * 3 + d, played: ms.length, win: w, draw: d, lose: l, goalsFor: gf, goalsAgainst: ga, goalDiff: gf - ga, form: form.toString()));
    }
    rows.sort((a, b) {
      final c = b.points.compareTo(a.points);
      if (c != 0) return c;
      final g = b.goalDiff.compareTo(a.goalDiff);
      if (g != 0) return g;
      final f = b.goalsFor.compareTo(a.goalsFor);
      return f != 0 ? f : a.team.name.compareTo(b.team.name);
    });
    return rows;
  }

  @override
  Future<Fresh<List<Match>>> leagueMatches(int leagueId, int season) => _ok(_all(where: (m) => m.league.id == leagueId)..sort((a, b) => a.kickoff.compareTo(b.kickoff)));

  /// Season aggregates per player from finished matches.
  Map<int, PlayerStatLine> _seasonLines({int? leagueId, int? teamId}) {
    final acc = <int, List<PlayerStatLine>>{};
    for (final base in _matches.values) {
      if (leagueId != null && base.league.id != leagueId) continue;
      if (teamId != null && !base.involves(teamId)) continue;
      if (!_statusFor(base).isFinished) continue;
      final m = _materialise(base, detail: true);
      for (final p in m.players ?? const <PlayerMatchLine>[]) {
        if (teamId != null && p.teamId != teamId) continue;
        acc.putIfAbsent(p.player.id, () => []).add(p.stats);
      }
    }
    return acc.map((k, v) => MapEntry(k, PlayerStatLine.sum(v)));
  }

  PlayerWithSeasons _pws(int playerId, PlayerStatLine line, {int season = DemoRepository.season}) {
    final teamId = _playerTeam[playerId]!;
    final lg = _leagueInfo(_teamLeague[teamId]!).ref;
    return PlayerWithSeasons(_profile(playerId), [
      PlayerSeason(season: season, team: _teams[teamId]!, league: LeagueRef(id: lg.id, name: lg.name, country: lg.country, season: season), position: _profile(playerId).position, number: _sq(playerId).number, stats: line),
    ]);
  }

  @override
  Future<Fresh<List<PlayerWithSeasons>>> topScorers(int leagueId, int season) async {
    final lines = _seasonLines(leagueId: leagueId).entries.where((e) => (e.value.goals ?? 0) > 0).toList()
      ..sort((a, b) {
        final c = (b.value.goals ?? 0).compareTo(a.value.goals ?? 0);
        return c != 0 ? c : (b.value.assists ?? 0).compareTo(a.value.assists ?? 0);
      });
    return _ok(lines.take(20).map((e) => _pws(e.key, e.value)).toList());
  }

  @override
  Future<Fresh<List<PlayerWithSeasons>>> topAssists(int leagueId, int season) async {
    final lines = _seasonLines(leagueId: leagueId).entries.where((e) => (e.value.assists ?? 0) > 0).toList()
      ..sort((a, b) {
        final c = (b.value.assists ?? 0).compareTo(a.value.assists ?? 0);
        return c != 0 ? c : (b.value.goals ?? 0).compareTo(a.value.goals ?? 0);
      });
    return _ok(lines.take(20).map((e) => _pws(e.key, e.value)).toList());
  }

  @override
  Future<Fresh<List<TeamRef>>> leagueTeams(int leagueId, int season) => _ok(_teams.values.where((t) => _teamLeague[t.id] == leagueId).toList());

  // ── Teams ────────────────────────────────────────────────────────────────
  @override
  Future<Fresh<TeamInfo>> team(int id) async {
    final t = _teams[id];
    if (t == null) throw const DataException(DataErrorKind.notFound, 'Team not found.');
    final lg = _leagueInfo(_teamLeague[id]!).ref;
    return _ok(TeamInfo(ref: t, country: lg.country, founded: 1878 + (id * 7) % 120, venueName: '${t.name.split(' ').first} Arena', venueCity: lg.country, venueCapacity: 18000 + (id * 977) % 52000));
  }

  @override
  Future<Fresh<List<LeagueInfo>>> teamLeagues(int teamId) => _ok(_teamLeague[teamId] == null ? const [] : [_leagueInfo(_teamLeague[teamId]!)]);

  @override
  Future<Fresh<List<Match>>> teamMatches(int teamId, int season) => _ok(_all(where: (m) => m.involves(teamId))..sort((a, b) => a.kickoff.compareTo(b.kickoff)));

  @override
  Future<Fresh<TeamSeasonStats?>> teamStats(int teamId, int leagueId, int season) async {
    final ms = _all(where: (m) => m.involves(teamId) && m.league.id == leagueId).where((m) => m.status.isFinished).toList()..sort((a, b) => a.kickoff.compareTo(b.kickoff));
    if (ms.isEmpty) return _f(null);
    var w = 0, d = 0, l = 0, gfh = 0, gfa = 0, gah = 0, gaa = 0, cs = 0, fts = 0, y = 0, r = 0;
    var hw = 0, hd = 0, hl = 0, aw = 0, ad = 0, al = 0;
    final periods = <String, (int, int)>{};
    double poss = 0, shots = 0, xg = 0, acc = 0;
    var statN = 0;
    for (final base in ms) {
      final m = _materialise(_matches[base.id]!, detail: true);
      final home = m.isHome(teamId);
      final res = m.resultFor(teamId);
      final gf = (home ? m.homeGoals : m.awayGoals) ?? 0, ga = (home ? m.awayGoals : m.homeGoals) ?? 0;
      if (res == 'W') {
        w++;
        home ? hw++ : aw++;
      } else if (res == 'D') {
        d++;
        home ? hd++ : ad++;
      } else {
        l++;
        home ? hl++ : al++;
      }
      if (home) {
        gfh += gf;
        gah += ga;
      } else {
        gfa += gf;
        gaa += ga;
      }
      if (ga == 0) cs++;
      if (gf == 0) fts++;
      for (final e in m.events!.where((e) => e.teamId == teamId && e.isCard)) {
        final bucket = e.minute <= 15 ? '0-15' : e.minute <= 30 ? '16-30' : e.minute <= 45 ? '31-45' : e.minute <= 60 ? '46-60' : e.minute <= 75 ? '61-75' : '76-90';
        final cur = periods[bucket] ?? (0, 0);
        periods[bucket] = e.kind == EventKind.yellow ? (cur.$1 + 1, cur.$2) : (cur.$1, cur.$2 + 1);
        e.kind == EventKind.yellow ? y++ : r++;
      }
      final st = m.stats!;
      num? pick(StatKey k) => home ? st[k]?.home : st[k]?.away;
      poss += (pick(StatKey.possession) ?? 50).toDouble();
      shots += (pick(StatKey.shotsTotal) ?? 0).toDouble();
      xg += (pick(StatKey.xg) ?? 0).toDouble();
      acc += (pick(StatKey.passAccuracy) ?? 0).toDouble();
      statN++;
    }
    final form = ms.reversed.take(5).toList().reversed.map((m) => m.resultFor(teamId) ?? '').join();
    final lg = _leagueInfo(leagueId).ref;
    return _ok(TeamSeasonStats(
      league: lg,
      season: season,
      form: form,
      played: ms.length,
      wins: w,
      draws: d,
      losses: l,
      homeRecord: (hw, hd, hl),
      awayRecord: (aw, ad, al),
      goalsFor: gfh + gfa,
      goalsAgainst: gah + gaa,
      goalsForHome: gfh,
      goalsForAway: gfa,
      goalsAgainstHome: gah,
      goalsAgainstAway: gaa,
      cleanSheets: cs,
      failedToScore: fts,
      yellow: y,
      red: r,
      cardsByPeriod: periods,
      formations: [(_Script.formationFor(teamId), ms.length)],
      possession: poss / statN,
      shotsPerGame: shots / statN,
      xg: xg / statN,
      passAccuracy: acc / statN,
    ));
  }

  @override
  Future<Fresh<List<SquadPlayer>>> squad(int teamId) => _ok(_squads[teamId] ?? const []);

  List<Transfer> _transfersFor({int? teamId, int? playerId}) {
    final out = <Transfer>[];
    final teams = _teams.keys.toList();
    for (var i = 0; i < teams.length; i++) {
      final to = teams[i];
      final r = math.Random(to * 17);
      for (var k = 0; k < 2; k++) {
        final from = teams[(i + 3 + r.nextInt(teams.length - 4)) % teams.length];
        final p = _squads[to]![16 + (k * 3 + r.nextInt(3)) % 6];
        final fee = switch (r.nextInt(4)) { 0 => 'Loan', 1 => 'Free', _ => '€ ${4 + r.nextInt(40)}M' };
        final t = Transfer(
          player: PlayerRef(id: p.id, name: p.name),
          date: DateTime(season, 7 + r.nextInt(2), 1 + r.nextInt(28)),
          from: _teams[from]!,
          to: _teams[to]!,
          fee: fee,
          provenance: Provenance.demo,
        );
        if ((teamId == null || t.to.id == teamId || t.from.id == teamId) && (playerId == null || t.player.id == playerId)) out.add(t);
      }
    }
    out.sort((a, b) => b.date!.compareTo(a.date!));
    return out;
  }

  @override
  Future<Fresh<List<Transfer>>> teamTransfers(int teamId) => _ok(_transfersFor(teamId: teamId));

  // ── Players ──────────────────────────────────────────────────────────────
  SquadPlayer _sq(int id) => _squads[_playerTeam[id]]!.firstWhere((p) => p.id == id);

  PlayerProfile _profile(int id) {
    final sq = _sq(id);
    final team = _teams[_playerTeam[id]]!;
    final r = math.Random(id);
    final parts = sq.name.split(' ');
    return PlayerProfile(
      id: id,
      name: sq.name,
      firstname: parts.first,
      lastname: parts.last,
      age: sq.age,
      birthDate: DateTime(season - (sq.age ?? 25), 1 + r.nextInt(12), 1 + r.nextInt(28)),
      birthPlace: _nations[id % _nations.length],
      birthCountry: _nations[id % _nations.length],
      nationality: _nations[id % _nations.length],
      height: '${170 + r.nextInt(25)} cm',
      weight: '${65 + r.nextInt(22)} kg',
      position: sq.position,
      number: sq.number,
      injured: false,
      team: team,
    );
  }

  @override
  Future<Fresh<PlayerWithSeasons>> player(int id, int season) async {
    if (!_playerTeam.containsKey(id)) throw const DataException(DataErrorKind.notFound, 'Player not found.');
    if (season == DemoRepository.season) {
      final teamId = _playerTeam[id]!;
      final line = _seasonLines(teamId: teamId)[id] ?? const PlayerStatLine(appearances: 0, minutes: 0);
      return _ok(_pws(id, line));
    }
    // Earlier seasons: synthetic aggregate lines (demo only).
    final r = math.Random(id * 1000 + season);
    final q = _playerQuality[id]!;
    final group = positionGroupOf(_sq(id).position);
    final apps = 18 + r.nextInt(18);
    final mins = apps * (60 + r.nextInt(30));
    final goals = switch (group) { PositionGroup.forward => (q * 12 * r.nextDouble()).round() + 2, PositionGroup.midfielder => (q * 6 * r.nextDouble()).round(), _ => r.nextInt(3) };
    final assists = switch (group) { PositionGroup.midfielder => (q * 8 * r.nextDouble()).round() + 1, PositionGroup.forward => (q * 6 * r.nextDouble()).round(), _ => r.nextInt(3) };
    final career = (await playerCareer(id)).data;
    final entry = career.firstWhere((c) => c.seasons.contains(season), orElse: () => career.first);
    final line = PlayerStatLine(
      appearances: apps,
      lineups: apps - r.nextInt(5),
      minutes: mins,
      rating: 6.4 + q * 0.6 + r.nextDouble() * 0.5,
      goals: goals,
      assists: assists,
      shots: goals * 3 + r.nextInt(20),
      shotsOn: goals + r.nextInt(12),
      passes: apps * (25 + r.nextInt(30)),
      keyPasses: assists * 3 + r.nextInt(20),
      passAccuracy: 72 + r.nextDouble() * 18,
      tackles: apps * (group == PositionGroup.defender ? 2 : 1),
      interceptions: apps * (group == PositionGroup.defender ? 1 : 0) + r.nextInt(10),
      duels: apps * 8,
      duelsWon: apps * 4 + r.nextInt(20),
      dribbles: apps * 2,
      dribblesWon: apps + r.nextInt(10),
      yellow: r.nextInt(7),
      red: r.nextInt(10) == 0 ? 1 : 0,
      saves: group == PositionGroup.goalkeeper ? apps * 3 : null,
      conceded: group == PositionGroup.goalkeeper ? apps + r.nextInt(15) : null,
      xg: goals * (0.8 + r.nextDouble() * 0.4),
      xa: assists * (0.8 + r.nextDouble() * 0.4),
    );
    final lg = _leagueInfo(_teamLeague[entry.team.id] ?? 9001).ref;
    return _ok(PlayerWithSeasons(_profile(id), [
      PlayerSeason(season: season, team: entry.team, league: LeagueRef(id: lg.id, name: lg.name, country: lg.country, season: season), position: _sq(id).position, number: _sq(id).number, stats: line),
    ]));
  }

  @override
  Future<Fresh<List<int>>> playerSeasons(int id) async {
    final career = (await playerCareer(id)).data;
    return _ok({for (final c in career.where((c) => !c.isNational)) ...c.seasons}.toList()..sort());
  }

  @override
  Future<Fresh<List<CareerEntry>>> playerCareer(int id) async {
    final teamId = _playerTeam[id];
    if (teamId == null) return _f(const []);
    final r = math.Random(id * 3);
    final age = _sq(id).age ?? 24;
    final firstSeason = season - math.max(1, math.min(age - 18, 9));
    final clubs = <CareerEntry>[];
    var s = season;
    final spellNow = 1 + r.nextInt(3);
    clubs.add(CareerEntry(team: _teams[teamId]!, seasons: [for (var i = 0; i < spellNow && s >= firstSeason; i++) s--]));
    final all = _teams.keys.where((k) => k != teamId).toList();
    while (s >= firstSeason) {
      final t = _teams[all[r.nextInt(all.length)]]!;
      final len = 1 + r.nextInt(3);
      clubs.add(CareerEntry(team: t, seasons: [for (var i = 0; i < len && s >= firstSeason; i++) s--]));
    }
    final nat = _nations[id % _nations.length];
    if (_playerQuality[id]! > 1.05) {
      clubs.add(CareerEntry(team: TeamRef(id: 99000 + id % _nations.length, name: nat), seasons: [season, season - 1], isNational: true));
    }
    return _f(clubs);
  }

  @override
  Future<Fresh<List<Transfer>>> playerTransfers(int id) => _ok(_transfersFor(playerId: id));

  // ── Search ───────────────────────────────────────────────────────────────
  @override
  Future<Fresh<List<SearchHit>>> searchTeams(String query) => _ok(Fuzzy.rank(query, _teams.values, (t) => t.name)
      .map((t) => SearchHit(kind: SearchKind.team, id: t.id, title: t.name, subtitle: _leagueInfo(_teamLeague[t.id]!).ref.name))
      .toList());

  @override
  Future<Fresh<List<SearchHit>>> searchPlayers(String query) {
    final all = [for (final s in _squads.values) ...s];
    return _ok(Fuzzy.rank(query, all, (p) => p.name)
        .map((p) => SearchHit(kind: SearchKind.player, id: p.id, title: p.name, subtitle: '${p.position} · ${_teams[_playerTeam[p.id]]!.name}'))
        .toList());
  }
}

/// Full 94-minute script for one demo match; views are cut at the current
/// timeline position so live matches evolve over real time.
class _Script {
  _Script(this.match, this.lineups, this.events, this.shots, this.momentum, this.subOn, this.subOff, this.baseRates, this.possessionHome);

  final Match match;
  final List<Lineup> lineups;
  final List<MatchEvent> events;
  final List<(int, ShotEvent)> shots; // (timeline, shot)
  final List<MomentumPoint> momentum;
  final Map<int, int> subOn; // playerId → timeline
  final Map<int, int> subOff;
  final Map<int, double> baseRates;
  final double possessionHome;
  final Map<String, int> _tl = {};

  int timelineOf(MatchEvent e) => _tl[e.key] ?? e.minute;

  static const _formations = ['4-3-3', '4-2-3-1', '4-4-2', '3-5-2', '3-4-3'];
  static String formationFor(int teamId) => _formations[teamId % _formations.length];

  static _Script generate(Match m, DemoRepository repo) {
    final r = math.Random(m.id);
    final lineups = [_lineup(m.home, repo), _lineup(m.away, repo)];
    final sh = repo._strength[m.home.id]! * 1.08, sa = repo._strength[m.away.id]!;
    final possHome = (50 + (sh - sa) * 22 + (r.nextDouble() - 0.5) * 8).clamp(30.0, 72.0);

    final events = <MatchEvent>[];
    final shots = <(int, ShotEvent)>[];
    final tlMap = <String, int>{};
    int tlToMinute(int tl) => tl <= 47 ? math.min(tl, 45) : math.min(tl - 2, 90);
    int? tlExtra(int tl) => tl > 45 && tl <= 47 ? tl - 45 : (tl > 92 ? tl - 92 : null);

    void addEvent(MatchEvent e, int tl) {
      events.add(e);
      tlMap[e.key] = tl;
    }

    List<LineupPlayer> onPitch(int teamIdx) => lineups[teamIdx].startXI;

    // Shots and goals.
    for (var side = 0; side < 2; side++) {
      final team = side == 0 ? m.home : m.away;
      final str = side == 0 ? sh : sa;
      final nShots = (6 + str * 7 + r.nextInt(6)).round();
      final attackers = onPitch(side).where((p) => p.pos != 'G').toList();
      for (var i = 0; i < nShots; i++) {
        final tl = 2 + r.nextInt(92);
        final shooterPool = [...attackers.where((p) => p.pos == 'F'), ...attackers.where((p) => p.pos == 'F'), ...attackers.where((p) => p.pos == 'M'), ...attackers];
        final shooter = shooterPool[r.nextInt(shooterPool.length)];
        final inBox = r.nextDouble() < 0.62;
        final x = inBox ? 0.84 + r.nextDouble() * 0.14 : 0.66 + r.nextDouble() * 0.17;
        final y = inBox ? 0.3 + r.nextDouble() * 0.4 : 0.15 + r.nextDouble() * 0.7;
        final xg = (inBox ? 0.06 + (x - 0.84) * 3.2 * r.nextDouble() + (r.nextDouble() < 0.12 ? 0.35 : 0) : 0.02 + r.nextDouble() * 0.05).clamp(0.01, 0.8);
        final roll = r.nextDouble();
        final outcome = roll < xg * 1.05 ? ShotOutcome.goal : roll < 0.4 ? ShotOutcome.saved : roll < 0.62 ? ShotOutcome.blocked : roll < 0.66 ? ShotOutcome.post : ShotOutcome.missed;
        shots.add((tl, ShotEvent(minute: tlToMinute(tl), teamId: team.id, playerId: shooter.id, playerName: shooter.name, x: x, y: y, xg: double.parse(xg.toStringAsFixed(2)), outcome: outcome)));
        if (outcome == ShotOutcome.goal) {
          final mates = attackers.where((p) => p.id != shooter.id).toList();
          final assist = r.nextDouble() < 0.72 ? mates[r.nextInt(mates.length)] : null;
          final pen = r.nextDouble() < 0.08;
          addEvent(
            MatchEvent(minute: tlToMinute(tl), extra: tlExtra(tl), teamId: team.id, kind: pen ? EventKind.penaltyGoal : EventKind.goal, playerId: shooter.id, playerName: shooter.name, relatedId: pen ? null : assist?.id, relatedName: pen ? null : assist?.name, detail: pen ? 'Penalty' : 'Normal Goal'),
            tl,
          );
        }
      }
    }

    // Featured live match: guarantee a goal shortly after app start so the
    // celebration, notification and catch-up flows can be seen.
    if (m.id % 100 == 2 && m.league.id == 9001) {
      final st = repo._statusFor(m);
      final tl = repo._timeline(st) + 3;
      if (st.isLive && tl > 3 && tl < 94) {
        final scorer = lineups[0].startXI.lastWhere((p) => p.pos == 'F');
        final assist = lineups[0].startXI.firstWhere((p) => p.pos == 'M');
        shots.add((tl, ShotEvent(minute: tlToMinute(tl), teamId: m.home.id, playerId: scorer.id, playerName: scorer.name, x: 0.91, y: 0.46, xg: 0.41, outcome: ShotOutcome.goal)));
        addEvent(MatchEvent(minute: tlToMinute(tl), extra: tlExtra(tl), teamId: m.home.id, kind: EventKind.goal, playerId: scorer.id, playerName: scorer.name, relatedId: assist.id, relatedName: assist.name, detail: 'Normal Goal'), tl);
        final booked = lineups[1].startXI[3];
        addEvent(MatchEvent(minute: tlToMinute(tl + 2), extra: tlExtra(tl + 2), teamId: m.away.id, kind: EventKind.yellow, playerId: booked.id, playerName: booked.name, detail: 'Yellow Card', comment: 'Foul'), tl + 2);
      }
    }

    // Cards.
    for (var side = 0; side < 2; side++) {
      final team = side == 0 ? m.home : m.away;
      final xi = onPitch(side);
      final n = 1 + r.nextInt(4);
      final booked = <int>{};
      for (var i = 0; i < n; i++) {
        final p = xi[1 + r.nextInt(xi.length - 1)];
        final tl = 10 + r.nextInt(84);
        if (booked.contains(p.id)) {
          addEvent(MatchEvent(minute: tlToMinute(tl), extra: tlExtra(tl), teamId: team.id, kind: EventKind.secondYellow, playerId: p.id, playerName: p.name, detail: 'Second Yellow card'), tl);
        } else {
          booked.add(p.id);
          addEvent(MatchEvent(minute: tlToMinute(tl), extra: tlExtra(tl), teamId: team.id, kind: EventKind.yellow, playerId: p.id, playerName: p.name, detail: 'Yellow Card', comment: const ['Foul', 'Argument', 'Time wasting', 'Handball'][r.nextInt(4)]), tl);
        }
      }
      if (r.nextDouble() < 0.07) {
        final p = xi[1 + r.nextInt(4)];
        final tl = 30 + r.nextInt(60);
        addEvent(MatchEvent(minute: tlToMinute(tl), extra: tlExtra(tl), teamId: team.id, kind: EventKind.red, playerId: p.id, playerName: p.name, detail: 'Red Card', comment: 'Serious foul play'), tl);
      }
    }

    // Substitutions (two or three windows per team).
    final subOn = <int, int>{}, subOff = <int, int>{};
    for (var side = 0; side < 2; side++) {
      final team = side == 0 ? m.home : m.away;
      final lu = lineups[side];
      final outfield = lu.startXI.where((p) => p.pos != 'G').toList()..shuffle(r);
      final bench = lu.substitutes.where((p) => p.pos != 'G').toList()..shuffle(r);
      final windows = [58 + r.nextInt(8), 68 + r.nextInt(8), 80 + r.nextInt(8)];
      for (var i = 0; i < 5 && i < bench.length; i++) {
        final tl = windows[i ~/ 2];
        final off = outfield[i], on = bench[i];
        subOn[on.id] = tl;
        subOff[off.id] = tl;
        addEvent(MatchEvent(minute: tlToMinute(tl), extra: tlExtra(tl), teamId: team.id, kind: EventKind.sub, playerId: on.id, playerName: on.name, relatedId: off.id, relatedName: off.name, detail: 'Substitution ${i + 1}'), tl);
      }
    }

    // Momentum: smoothed pressure series biased to the stronger side with
    // spikes around shots.
    final mom = <MomentumPoint>[];
    var v = 0.0;
    for (var tl = 1; tl <= 94; tl++) {
      v = v * 0.7 + (sh - sa) * 18 + (r.nextDouble() - 0.5) * 60;
      for (final s in shots.where((s) => s.$1 == tl)) {
        v += (s.$2.teamId == m.home.id ? 1 : -1) * (30 + s.$2.xg! * 80);
      }
      mom.add(MomentumPoint(tl, v.clamp(-100, 100)));
    }

    final rates = <int, double>{for (final lu in lineups) for (final p in [...lu.startXI, ...lu.substitutes]) p.id: repo._playerQuality[p.id] ?? 1};
    final s = _Script(m, lineups, events..sort((a, b) => (tlMap[a.key] ?? 0).compareTo(tlMap[b.key] ?? 0)), shots..sort((a, b) => a.$1.compareTo(b.$1)), mom, subOn, subOff, rates, possHome);
    s._tl.addAll(tlMap);
    return s;
  }

  static Lineup _lineup(TeamRef team, DemoRepository repo) {
    final squad = repo._squads[team.id]!;
    final formation = formationFor(team.id);
    final lines = formation.split('-').map(int.parse).toList();
    final gk = squad.firstWhere((p) => p.group == PositionGroup.goalkeeper);
    final defs = squad.where((p) => p.group == PositionGroup.defender).toList();
    final mids = squad.where((p) => p.group == PositionGroup.midfielder).toList();
    final fwds = squad.where((p) => p.group == PositionGroup.forward).toList();
    final xi = <LineupPlayer>[LineupPlayer(id: gk.id, name: gk.name, number: gk.number, pos: 'G', gridRow: 1, gridCol: 1)];
    final pools = <List<SquadPlayer>>[];
    // Map formation rows to position pools: first row defenders, last row
    // forwards, middle rows midfielders.
    var d = 0, mi = 0, f = 0;
    for (var row = 0; row < lines.length; row++) {
      final pos = row == 0 ? 'D' : (row == lines.length - 1 ? 'F' : 'M');
      final pool = <SquadPlayer>[];
      for (var c = 0; c < lines[row]; c++) {
        final p = switch (pos) { 'D' => defs[d++ % defs.length], 'F' => fwds[f++ % fwds.length], _ => mids[mi++ % mids.length] };
        pool.add(p);
        xi.add(LineupPlayer(id: p.id, name: p.name, number: p.number, pos: pos, gridRow: row + 2, gridCol: c + 1));
      }
      pools.add(pool);
    }
    final used = xi.map((p) => p.id).toSet();
    final subs = squad.where((p) => !used.contains(p.id)).take(9).map((p) => LineupPlayer(id: p.id, name: p.name, number: p.number, pos: switch (p.group) {
          PositionGroup.goalkeeper => 'G',
          PositionGroup.defender => 'D',
          PositionGroup.midfielder => 'M',
          _ => 'F',
        })).toList();
    final c = [0xFFE4E7E5, 0xFF1F3A93, 0xFFC0392B, 0xFF0E7C61, 0xFFF1C40F, 0xFF6C3483, 0xFF1B1B1B, 0xFFE67E22][team.id % 8];
    return Lineup(team: team, formation: formation, startXI: xi, substitutes: subs, coach: '${DemoRepository._first[team.id % 40]} ${DemoRepository._last[(team.id * 5) % 43]}', primaryColor: c, numberColor: (c == 0xFFE4E7E5 || c == 0xFFF1C40F) ? 0xFF0A0C0B : 0xFFFFFFFF, provenance: Provenance.demo);
  }

  double _frac(int tl) => (tl >= 999 ? 94 : tl) / 94.0;

  MatchStats statsAt(int tl) {
    final f = _frac(tl);
    final visibleShots = shots.where((s) => s.$1 <= tl).map((s) => s.$2).toList();
    int count(int teamId, bool Function(ShotEvent) w) => visibleShots.where((s) => s.teamId == teamId && w(s)).length;
    double xg(int teamId) => visibleShots.where((s) => s.teamId == teamId).fold(0.0, (a, s) => a + (s.xg ?? 0));
    final h = match.home.id, a = match.away.id;
    final r = math.Random(match.id * 7);
    int scaled(double total) => (total * f).round();
    final passH = 380 + possessionHome * 5 + r.nextInt(60), passA = 380 + (100 - possessionHome) * 5 + r.nextInt(60);
    final accH = 76 + possessionHome / 8 + r.nextDouble() * 4, accA = 76 + (100 - possessionHome) / 8 + r.nextDouble() * 4;
    final cards = events.where((e) => timelineOf(e) <= tl);
    int cardsOf(int teamId, bool red) => cards.where((e) => e.teamId == teamId && (red ? e.isRed : e.kind == EventKind.yellow)).length;
    final drift = math.sin(tl / 9.0) * 3;
    return MatchStats({
      StatKey.possession: StatPair((possessionHome + drift).roundToDouble(), (100 - possessionHome - drift).roundToDouble()),
      StatKey.xg: StatPair(double.parse(xg(h).toStringAsFixed(2)), double.parse(xg(a).toStringAsFixed(2))),
      StatKey.shotsTotal: StatPair(count(h, (_) => true), count(a, (_) => true)),
      StatKey.shotsOn: StatPair(count(h, (s) => s.outcome == ShotOutcome.goal || s.outcome == ShotOutcome.saved), count(a, (s) => s.outcome == ShotOutcome.goal || s.outcome == ShotOutcome.saved)),
      StatKey.shotsOff: StatPair(count(h, (s) => s.outcome == ShotOutcome.missed || s.outcome == ShotOutcome.post), count(a, (s) => s.outcome == ShotOutcome.missed || s.outcome == ShotOutcome.post)),
      StatKey.shotsBlocked: StatPair(count(h, (s) => s.outcome == ShotOutcome.blocked), count(a, (s) => s.outcome == ShotOutcome.blocked)),
      StatKey.shotsInside: StatPair(count(h, (s) => s.x >= 0.84), count(a, (s) => s.x >= 0.84)),
      StatKey.shotsOutside: StatPair(count(h, (s) => s.x < 0.84), count(a, (s) => s.x < 0.84)),
      StatKey.bigChances: StatPair(count(h, (s) => (s.xg ?? 0) >= 0.3), count(a, (s) => (s.xg ?? 0) >= 0.3)),
      StatKey.corners: StatPair(scaled(3 + possessionHome / 12 + r.nextInt(3)), scaled(3 + (100 - possessionHome) / 12 + r.nextInt(3))),
      StatKey.fouls: StatPair(scaled(9 + r.nextInt(6).toDouble()), scaled(9 + r.nextInt(6).toDouble())),
      StatKey.offsides: StatPair(scaled(r.nextInt(4).toDouble()), scaled(r.nextInt(4).toDouble())),
      StatKey.passes: StatPair(scaled(passH), scaled(passA)),
      StatKey.passesAccurate: StatPair(scaled(passH * accH / 100), scaled(passA * accA / 100)),
      StatKey.passAccuracy: StatPair(accH.roundToDouble(), accA.roundToDouble()),
      StatKey.yellow: StatPair(cardsOf(h, false), cardsOf(a, false)),
      StatKey.red: StatPair(cardsOf(h, true), cardsOf(a, true)),
      StatKey.saves: StatPair(count(a, (s) => s.outcome == ShotOutcome.saved), count(h, (s) => s.outcome == ShotOutcome.saved)),
      StatKey.duelsWon: StatPair(scaled(44 + r.nextInt(14).toDouble()), scaled(44 + r.nextInt(14).toDouble())),
      StatKey.tackles: StatPair(scaled(14 + r.nextInt(8).toDouble()), scaled(14 + r.nextInt(8).toDouble())),
      StatKey.interceptions: StatPair(scaled(7 + r.nextInt(6).toDouble()), scaled(7 + r.nextInt(6).toDouble())),
      StatKey.crosses: StatPair(scaled(12 + r.nextInt(10).toDouble()), scaled(12 + r.nextInt(10).toDouble())),
      StatKey.dribbles: StatPair(scaled(6 + r.nextInt(8).toDouble()), scaled(6 + r.nextInt(8).toDouble())),
      StatKey.progressivePasses: StatPair(scaled(28 + possessionHome / 3), scaled(28 + (100 - possessionHome) / 3)),
    });
  }

  List<PlayerMatchLine> playersAt(int tl, List<MatchEvent> visible) {
    final cap = tl >= 999 ? 94 : tl;
    final out = <PlayerMatchLine>[];
    final f = _frac(tl);
    for (var side = 0; side < 2; side++) {
      final lu = lineups[side];
      final captainId = lu.startXI[lu.startXI.length > 5 ? 5 : 0].id;
      for (final p in [...lu.startXI, ...lu.substitutes]) {
        final starter = lu.startXI.contains(p);
        final on = starter ? 0 : subOn[p.id];
        if (on == null || on > cap) {
          out.add(PlayerMatchLine(player: PlayerRef(id: p.id, name: p.name), teamId: lu.team.id, number: p.number, position: p.pos, substitute: !starter, stats: const PlayerStatLine(appearances: 0, minutes: 0)));
          continue;
        }
        final off = subOff[p.id];
        final end = (off != null && off <= cap) ? off : cap;
        final mins = math.max(1, ((end - on) * 90 / 94).round());
        final r = math.Random(p.id * 7 + match.id);
        final q = baseRates[p.id] ?? 1;
        final goals = visible.where((e) => e.isGoal && e.kind != EventKind.ownGoal && e.playerId == p.id).length;
        final assists = visible.where((e) => e.kind == EventKind.goal && e.relatedId == p.id).length;
        final myShots = shots.where((s) => s.$1 <= cap && s.$2.playerId == p.id).map((s) => s.$2).toList();
        final yellow = visible.where((e) => e.kind == EventKind.yellow && e.playerId == p.id).length;
        final red = visible.where((e) => e.isRed && e.playerId == p.id).length;
        final mf = mins / 90;
        final group = positionGroupOf(p.pos);
        final passes = ((group == PositionGroup.midfielder ? 55 : group == PositionGroup.defender ? 48 : group == PositionGroup.goalkeeper ? 28 : 24) * mf * (0.8 + r.nextDouble() * 0.4)).round();
        final acc = 70 + r.nextDouble() * 22;
        final saves = group == PositionGroup.goalkeeper ? shots.where((s) => s.$1 <= cap && s.$2.teamId != lu.team.id && s.$2.outcome == ShotOutcome.saved).length : null;
        final conceded = group == PositionGroup.goalkeeper ? visible.where((e) => e.isGoal && e.teamId != lu.team.id).length : null;
        final duels = (8 * mf + r.nextInt(6)).round();
        var rating = 6.2 + (q - 1) * 1.2 + r.nextDouble() * 0.6 + goals * 0.9 + assists * 0.6 - red * 1.5 - yellow * 0.1 + (saves ?? 0) * 0.15 - (conceded ?? 0) * 0.2;
        rating = rating.clamp(5.2, 9.8) * (0.9 + 0.1 * f) + 0.66 * (1 - f);
        out.add(PlayerMatchLine(
          player: PlayerRef(id: p.id, name: p.name),
          teamId: lu.team.id,
          number: p.number,
          position: p.pos,
          captain: p.id == captainId,
          substitute: !starter,
          stats: PlayerStatLine(
            appearances: 1,
            minutes: mins,
            rating: double.parse(rating.clamp(5.0, 10.0).toStringAsFixed(1)),
            goals: goals,
            assists: assists,
            shots: myShots.length,
            shotsOn: myShots.where((s) => s.outcome == ShotOutcome.goal || s.outcome == ShotOutcome.saved).length,
            passes: passes,
            keyPasses: (r.nextInt(3) * mf).round() + assists,
            passAccuracy: acc,
            tackles: ((group == PositionGroup.defender ? 3 : 1.4) * mf * r.nextDouble() * 2).round(),
            interceptions: ((group == PositionGroup.defender ? 2 : 0.6) * mf * r.nextDouble() * 2).round(),
            duels: duels,
            duelsWon: (duels * (0.35 + r.nextDouble() * 0.4)).round(),
            dribbles: ((group == PositionGroup.forward ? 4 : 1.5) * mf * r.nextDouble() * 2).round(),
            dribblesWon: ((group == PositionGroup.forward ? 2.4 : 0.8) * mf * r.nextDouble() * 2).round(),
            foulsCommitted: r.nextInt(3),
            foulsDrawn: r.nextInt(3),
            yellow: yellow,
            red: red,
            saves: saves,
            conceded: conceded,
            xg: double.parse(myShots.fold(0.0, (a, s) => a + (s.xg ?? 0)).toStringAsFixed(2)),
            xa: double.parse(shots.where((s) => s.$1 <= cap && s.$2.teamId == lu.team.id && s.$2.playerId != p.id).take(assists + r.nextInt(2)).fold(0.0, (a, s) => a + (s.$2.xg ?? 0) * 0.5).toStringAsFixed(2)),
          ),
        ));
      }
    }
    return out;
  }

  MatchAnalytics analyticsAt(int tl) {
    final cap = tl >= 999 ? 94 : tl;
    final heat = <int, List<PitchPoint>>{};
    final touches = <int, List<PitchPoint>>{};
    final passes = <PassEvent>[];
    for (final lu in lineups) {
      final rows = lu.startXI.map((p) => p.gridRow ?? 1).fold(1, math.max);
      for (final p in [...lu.startXI, ...lu.substitutes]) {
        final starter = lu.startXI.contains(p);
        final on = starter ? 0 : subOn[p.id];
        if (on == null || on > cap) continue;
        final off = subOff[p.id];
        final end = (off != null && off <= cap) ? off : cap;
        final r = math.Random(p.id * 13 + match.id);
        // Anchor from formation grid; subs inherit a generic role spot.
        final row = p.gridRow ?? (p.pos == 'D' ? 2 : p.pos == 'F' ? rows : 3);
        final lineCount = lu.startXI.where((x) => x.gridRow == row).length;
        final col = p.gridCol ?? (1 + r.nextInt(math.max(1, lineCount)));
        final ax = row == 1 ? 0.06 : 0.18 + (row - 2) / math.max(1, rows - 1) * 0.6;
        final ay = lineCount <= 1 ? 0.5 : 0.12 + (col - 1) / (lineCount - 1) * 0.76;
        final n = ((end - on) * 0.9).round();
        final pts = <PitchPoint>[];
        for (var i = 0; i < n; i++) {
          double g() => (r.nextDouble() + r.nextDouble() + r.nextDouble() - 1.5) / 1.5;
          pts.add(PitchPoint((ax + g() * 0.16 + 0.05).clamp(0.01, 0.99), (ay + g() * 0.18).clamp(0.02, 0.98)));
        }
        heat[p.id] = pts;
        touches[p.id] = pts.where((_) => r.nextDouble() < 0.45).toList();
        for (var i = 0; i + 1 < pts.length && i < 40; i += 2) {
          final from = pts[i];
          final to = PitchPoint((from.x + 0.05 + r.nextDouble() * 0.2).clamp(0.02, 0.98), (from.y + (r.nextDouble() - 0.5) * 0.35).clamp(0.02, 0.98));
          passes.add(PassEvent(lu.team.id, p.id, from, to, r.nextDouble() < 0.82));
        }
      }
    }
    return MatchAnalytics(
      momentum: momentum.where((p) => p.minute <= cap).toList(),
      shots: shots.where((s) => s.$1 <= cap).map((s) => s.$2).toList(),
      heat: heat,
      touches: touches,
      passes: passes,
    );
  }
}
