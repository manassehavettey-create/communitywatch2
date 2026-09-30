import 'dart:convert';

import '../models/models.dart';

/// Pure JSON → domain mapping for API-Football v3 responses. Kept separate
/// from networking so it can be unit tested with recorded payloads.
abstract final class ApiFootballParser {
  static List<dynamic> response(String body) {
    final decoded = jsonDecode(body);
    final r = decoded is Map ? decoded['response'] : null;
    if (r is List) return r;
    if (r is Map) return [r];
    return const [];
  }

  static Map<String, dynamic>? responseObject(String body) {
    final decoded = jsonDecode(body);
    final r = decoded is Map ? decoded['response'] : null;
    return r is Map<String, dynamic> && r.isNotEmpty ? r : null;
  }

  // ── primitives ──────────────────────────────────────────────────────────
  static Map<String, dynamic> m(dynamic v) => v is Map<String, dynamic> ? v : const {};
  static List<dynamic> l(dynamic v) => v is List ? v : const [];

  static int? i(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse('$v'.replaceAll('%', '').trim());
  }

  static double? d(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse('$v'.replaceAll('%', '').trim());
  }

  static String? s(dynamic v) {
    if (v == null) return null;
    final str = '$v'.trim();
    return str.isEmpty ? null : str;
  }

  static DateTime? date(dynamic v) {
    final str = s(v);
    if (str == null) return null;
    return DateTime.tryParse(str)?.toLocal();
  }

  static TeamRef team(dynamic j) {
    final t = m(j);
    return TeamRef(id: i(t['id']) ?? 0, name: s(t['name']) ?? 'Unknown', logo: s(t['logo']));
  }

  static LeagueRef leagueRef(dynamic j, {Map<String, dynamic>? country}) {
    final x = m(j);
    return LeagueRef(
      id: i(x['id']) ?? 0,
      name: s(x['name']) ?? 'Competition',
      logo: s(x['logo']),
      country: s(x['country']) ?? s(country?['name']),
      flag: s(x['flag']) ?? s(country?['flag']),
      season: i(x['season']),
      round: s(x['round']),
    );
  }

  // ── fixtures ────────────────────────────────────────────────────────────
  static Match fixture(dynamic raw) {
    final f = m(raw);
    final fx = m(f['fixture']);
    final teams = m(f['teams']);
    final goals = m(f['goals']);
    final score = m(f['score']);
    final st = m(fx['status']);
    final venue = m(fx['venue']);
    final home = team(teams['home']);
    final away = team(teams['away']);
    ScorePair pair(dynamic v) => ScorePair(i(m(v)['home']), i(m(v)['away']));

    final lineups = f.containsKey('lineups') ? l(f['lineups']).map(lineup).toList() : null;
    var events = f.containsKey('events') ? l(f['events']).map(event).toList() : null;
    if (events != null && lineups != null && lineups.isNotEmpty) events = normaliseSubstitutions(events, lineups);

    return Match(
      id: i(fx['id']) ?? 0,
      league: leagueRef(f['league']),
      home: home,
      away: away,
      kickoff: date(fx['date']) ?? DateTime.fromMillisecondsSinceEpoch((i(fx['timestamp']) ?? 0) * 1000),
      status: MatchStatus(short: s(st['short']) ?? 'NS', long: s(st['long']) ?? '', elapsed: i(st['elapsed']), extra: i(st['extra'])),
      homeGoals: i(goals['home']),
      awayGoals: i(goals['away']),
      halftime: pair(score['halftime']),
      extratime: pair(score['extratime']),
      penalties: pair(score['penalty']),
      venue: s(venue['name']),
      city: s(venue['city']),
      referee: s(fx['referee']),
      homeWinner: m(teams['home'])['winner'] as bool?,
      awayWinner: m(teams['away'])['winner'] as bool?,
      events: events,
      lineups: lineups,
      stats: f.containsKey('statistics') ? stats(l(f['statistics']), home.id, players: f.containsKey('players') ? l(f['players']) : null) : null,
      players: f.containsKey('players') ? matchPlayers(l(f['players'])) : null,
    );
  }

  static MatchEvent event(dynamic raw) {
    final e = m(raw);
    final time = m(e['time']);
    final type = (s(e['type']) ?? '').toLowerCase();
    final detail = s(e['detail']) ?? '';
    final dl = detail.toLowerCase();
    final kind = switch (type) {
      'goal' when dl.contains('missed') => EventKind.missedPenalty,
      'goal' when dl.contains('own') => EventKind.ownGoal,
      'goal' when dl.contains('penalty') => EventKind.penaltyGoal,
      'goal' => EventKind.goal,
      'card' when dl.contains('second') => EventKind.secondYellow,
      'card' when dl.contains('red') => EventKind.red,
      'card' => EventKind.yellow,
      'subst' => EventKind.sub,
      'var' => EventKind.varDecision,
      _ => EventKind.other,
    };
    final player = m(e['player']);
    final assist = m(e['assist']);
    final isSub = kind == EventKind.sub;
    // API-Football: for substitutions `player` is the player going OFF and
    // `assist` the player coming ON. [normaliseSubstitutions] double-checks
    // against lineups when they are available.
    return MatchEvent(
      minute: i(time['elapsed']) ?? 0,
      extra: i(time['extra']),
      teamId: i(m(e['team'])['id']) ?? 0,
      kind: kind,
      playerId: isSub ? i(assist['id']) : i(player['id']),
      playerName: isSub ? s(assist['name']) : s(player['name']),
      relatedId: isSub ? i(player['id']) : i(assist['id']),
      relatedName: isSub ? s(player['name']) : s(assist['name']),
      detail: detail,
      comment: s(e['comments']),
    );
  }

  /// Ensure substitution events have the ON player as primary by checking
  /// which of the two appears among the starters.
  static List<MatchEvent> normaliseSubstitutions(List<MatchEvent> events, List<Lineup> lineups) {
    final starters = {for (final lu in lineups) ...lu.startXI.map((p) => p.id)};
    return [
      for (final e in events)
        if (e.kind == EventKind.sub && e.playerId != null && starters.contains(e.playerId) && !starters.contains(e.relatedId))
          MatchEvent(
            minute: e.minute,
            extra: e.extra,
            teamId: e.teamId,
            kind: e.kind,
            playerId: e.relatedId,
            playerName: e.relatedName,
            relatedId: e.playerId,
            relatedName: e.playerName,
            detail: e.detail,
            comment: e.comment,
          )
        else
          e,
    ];
  }

  static Lineup lineup(dynamic raw) {
    final x = m(raw);
    final t = m(x['team']);
    final colors = m(m(t['colors'])['player']);
    int? hex(dynamic v) {
      final str = s(v);
      if (str == null) return null;
      final n = int.tryParse(str, radix: 16);
      return n == null ? null : 0xFF000000 | n;
    }

    LineupPlayer lp(dynamic p) {
      final pl = m(m(p)['player']);
      final grid = s(pl['grid'])?.split(':');
      return LineupPlayer(
        id: i(pl['id']) ?? 0,
        name: s(pl['name']) ?? '',
        number: i(pl['number']),
        pos: s(pl['pos']),
        gridRow: grid != null && grid.length == 2 ? int.tryParse(grid[0]) : null,
        gridCol: grid != null && grid.length == 2 ? int.tryParse(grid[1]) : null,
      );
    }

    return Lineup(
      team: team(t),
      formation: s(x['formation']),
      startXI: l(x['startXI']).map(lp).toList(),
      substitutes: l(x['substitutes']).map(lp).toList(),
      coach: s(m(x['coach'])['name']),
      primaryColor: hex(colors['primary']),
      numberColor: hex(colors['number']),
    );
  }

  static const _statMap = {
    'ball possession': StatKey.possession,
    'expected_goals': StatKey.xg,
    'total shots': StatKey.shotsTotal,
    'shots on goal': StatKey.shotsOn,
    'shots off goal': StatKey.shotsOff,
    'blocked shots': StatKey.shotsBlocked,
    'shots insidebox': StatKey.shotsInside,
    'shots outsidebox': StatKey.shotsOutside,
    'fouls': StatKey.fouls,
    'corner kicks': StatKey.corners,
    'offsides': StatKey.offsides,
    'yellow cards': StatKey.yellow,
    'red cards': StatKey.red,
    'goalkeeper saves': StatKey.saves,
    'total passes': StatKey.passes,
    'passes accurate': StatKey.passesAccurate,
    'passes %': StatKey.passAccuracy,
    'goals_prevented': StatKey.goalsPrevented,
  };

  /// Team statistics. Advanced keys that the provider doesn't report at team
  /// level are filled with exact sums of official player statistics and
  /// flagged in [MatchStats.derivedKeys].
  static MatchStats? stats(List<dynamic> raw, int homeId, {List<dynamic>? players}) {
    if (raw.isEmpty) return null;
    final homeVals = <StatKey, num?>{};
    final awayVals = <StatKey, num?>{};
    final present = <StatKey>{};
    for (final t in raw) {
      final tm = m(t);
      final isHome = i(m(tm['team'])['id']) == homeId;
      for (final st in l(tm['statistics'])) {
        final key = _statMap[(s(m(st)['type']) ?? '').toLowerCase()];
        if (key == null) continue;
        present.add(key);
        final v = m(st)['value'];
        final n = key.unit == StatUnit.count ? i(v) : d(v);
        (isHome ? homeVals : awayVals)[key] = n;
      }
    }
    final values = <StatKey, StatPair>{};
    for (final k in present) {
      var h = homeVals[k];
      var a = awayVals[k];
      // The provider reports zero counts as null when the stat is tracked.
      if (k.unit == StatUnit.count) {
        h ??= 0;
        a ??= 0;
      }
      values[k] = StatPair(h, a);
    }

    final derived = <StatKey>{};
    if (players != null && players.isNotEmpty) {
      final lines = matchPlayers(players);
      void fill(StatKey k, int? Function(PlayerStatLine) f) {
        if (values[k] != null && !values[k]!.isEmpty) return;
        int? sum(bool home) {
          int? acc;
          for (final p in lines.where((p) => (p.teamId == homeId) == home)) {
            final v = f(p.stats);
            if (v != null) acc = (acc ?? 0) + v;
          }
          return acc;
        }

        final h = sum(true), a = sum(false);
        if (h == null && a == null) return;
        values[k] = StatPair(h ?? 0, a ?? 0);
        derived.add(k);
      }

      fill(StatKey.tackles, (s) => s.tackles);
      fill(StatKey.interceptions, (s) => s.interceptions);
      fill(StatKey.duelsWon, (s) => s.duelsWon);
      fill(StatKey.dribbles, (s) => s.dribblesWon);
      fill(StatKey.keyPasses, (s) => s.keyPasses);
    }
    return MatchStats(values, derivedKeys: derived);
  }

  static List<PlayerMatchLine> matchPlayers(List<dynamic> raw) {
    final out = <PlayerMatchLine>[];
    for (final t in raw) {
      final tm = m(t);
      final teamId = i(m(tm['team'])['id']) ?? 0;
      for (final p in l(tm['players'])) {
        final pm = m(p);
        final pl = m(pm['player']);
        final st = m(l(pm['statistics']).firstOrNull);
        final games = m(st['games']);
        final passes = m(st['passes']);
        final total = i(passes['total']);
        final acc = d(passes['accuracy']);
        // In match context `accuracy` is the number of accurate passes.
        final pct = (acc != null && total != null && total > 0 && acc <= total) ? acc / total * 100 : null;
        final minutes = i(games['minutes']);
        out.add(PlayerMatchLine(
          player: PlayerRef(id: i(pl['id']) ?? 0, name: s(pl['name']) ?? '', photo: s(pl['photo'])),
          teamId: teamId,
          number: i(games['number']),
          position: s(games['position']),
          captain: games['captain'] == true,
          substitute: games['substitute'] == true,
          stats: _statLine(st, appearances: (minutes ?? 0) > 0 ? 1 : 0, passAccuracy: pct),
        ));
      }
    }
    return out;
  }

  static PlayerStatLine _statLine(Map<String, dynamic> st, {int? appearances, double? passAccuracy}) {
    final games = m(st['games']);
    final shots = m(st['shots']);
    final goals = m(st['goals']);
    final passes = m(st['passes']);
    final tackles = m(st['tackles']);
    final duels = m(st['duels']);
    final dribbles = m(st['dribbles']);
    final fouls = m(st['fouls']);
    final cards = m(st['cards']);
    final pen = m(st['penalty']);
    final yellowRed = i(cards['yellowred']);
    final red = i(cards['red']);
    return PlayerStatLine(
      appearances: appearances ?? i(games['appearences']) ?? i(games['appearances']),
      lineups: i(games['lineups']),
      minutes: i(games['minutes']),
      rating: d(games['rating']),
      goals: i(goals['total']),
      assists: i(goals['assists']),
      conceded: i(goals['conceded']),
      saves: i(goals['saves']),
      shots: i(shots['total']),
      shotsOn: i(shots['on']),
      passes: i(passes['total']),
      keyPasses: i(passes['key']),
      passAccuracy: passAccuracy,
      tackles: i(tackles['total']),
      interceptions: i(tackles['interceptions']),
      blocks: i(tackles['blocks']),
      duels: i(duels['total']),
      duelsWon: i(duels['won']),
      dribbles: i(dribbles['attempts']),
      dribblesWon: i(dribbles['success']),
      foulsDrawn: i(fouls['drawn']),
      foulsCommitted: i(fouls['committed']),
      yellow: i(cards['yellow']),
      red: (red == null && yellowRed == null) ? null : (red ?? 0) + (yellowRed ?? 0),
      penaltiesScored: i(pen['scored']),
      penaltiesMissed: i(pen['missed']),
    );
  }

  // ── players ─────────────────────────────────────────────────────────────
  static PlayerProfile profile(dynamic raw) {
    final p = m(raw);
    final birth = m(p['birth']);
    return PlayerProfile(
      id: i(p['id']) ?? 0,
      name: s(p['name']) ?? '',
      firstname: s(p['firstname']),
      lastname: s(p['lastname']),
      age: i(p['age']),
      birthDate: date(birth['date']),
      birthPlace: s(birth['place']),
      birthCountry: s(birth['country']),
      nationality: s(p['nationality']),
      height: s(p['height']),
      weight: s(p['weight']),
      photo: s(p['photo']),
      position: s(p['position']),
      number: i(p['number']),
      injured: p['injured'] as bool?,
    );
  }

  static PlayerWithSeasons playerWithSeasons(dynamic raw) {
    final x = m(raw);
    final seasons = <PlayerSeason>[];
    for (final st in l(x['statistics'])) {
      final sm = m(st);
      final games = m(sm['games']);
      final passes = m(sm['passes']);
      final league = leagueRef(sm['league']);
      seasons.add(PlayerSeason(
        season: league.season ?? 0,
        team: team(sm['team']),
        league: league,
        position: s(games['position']),
        number: i(games['number']),
        captain: games['captain'] == true,
        stats: _statLine(sm, passAccuracy: d(passes['accuracy'])),
      ));
    }
    var prof = profile(x['player']);
    if (seasons.isNotEmpty) {
      final main = ([...seasons]..sort((a, b) => (b.stats.appearances ?? 0).compareTo(a.stats.appearances ?? 0))).first;
      prof = prof.withSeasonInfo(position: main.position, number: main.number, team: main.team);
    }
    return PlayerWithSeasons(prof, seasons);
  }

  static SquadPlayer squadPlayer(dynamic raw) {
    final p = m(raw);
    return SquadPlayer(id: i(p['id']) ?? 0, name: s(p['name']) ?? '', age: i(p['age']), number: i(p['number']), position: s(p['position']), photo: s(p['photo']));
  }

  static List<Transfer> transfers(List<dynamic> raw) {
    final out = <Transfer>[];
    for (final x in raw) {
      final xm = m(x);
      final pl = m(xm['player']);
      for (final t in l(xm['transfers'])) {
        final tm = m(t);
        final teams = m(tm['teams']);
        final fee = s(tm['type']);
        out.add(Transfer(
          player: PlayerRef(id: i(pl['id']) ?? 0, name: s(pl['name']) ?? ''),
          date: date(tm['date']),
          from: team(teams['out']),
          to: team(teams['in']),
          fee: (fee == null || fee.toUpperCase() == 'N/A' || fee == '-') ? null : fee,
        ));
      }
    }
    out.sort((a, b) => (b.date ?? DateTime(1900)).compareTo(a.date ?? DateTime(1900)));
    return out;
  }

  // ── leagues & teams ─────────────────────────────────────────────────────
  static LeagueInfo leagueInfo(dynamic raw) {
    final x = m(raw);
    final country = m(x['country']);
    final lg = m(x['league']);
    return LeagueInfo(
      ref: leagueRef(lg, country: country),
      type: s(lg['type']) ?? 'League',
      seasons: [
        for (final se in l(x['seasons']))
          () {
            final sm = m(se);
            final cov = m(sm['coverage']);
            final fx = m(cov['fixtures']);
            bool b(dynamic v) => v == true;
            return SeasonInfo(
              year: i(sm['year']) ?? 0,
              start: date(sm['start']),
              end: date(sm['end']),
              current: sm['current'] == true,
              coverage: Coverage(
                events: b(fx['events']),
                lineups: b(fx['lineups']),
                fixtureStats: b(fx['statistics_fixtures']),
                playerStats: b(fx['statistics_players']),
                standings: b(cov['standings']),
                players: b(cov['players']),
                topScorers: b(cov['top_scorers']),
                topAssists: b(cov['top_assists']),
                injuries: b(cov['injuries']),
                predictions: b(cov['predictions']),
              ),
            );
          }(),
      ],
    );
  }

  static StandingsTable? standings(String body) {
    final r = response(body);
    if (r.isEmpty) return null;
    final lg = m(m(r.first)['league']);
    final ref = leagueRef(lg);
    final groups = <StandingsGroup>[];
    for (final g in l(lg['standings'])) {
      final rows = <StandingRow>[];
      for (final row in l(g)) {
        final rm = m(row);
        final all = m(rm['all']);
        final gl = m(all['goals']);
        rows.add(StandingRow(
          rank: i(rm['rank']) ?? 0,
          team: team(rm['team']),
          points: i(rm['points']) ?? 0,
          played: i(all['played']) ?? 0,
          win: i(all['win']) ?? 0,
          draw: i(all['draw']) ?? 0,
          lose: i(all['lose']) ?? 0,
          goalsFor: i(gl['for']) ?? 0,
          goalsAgainst: i(gl['against']) ?? 0,
          goalDiff: i(rm['goalsDiff']) ?? 0,
          form: s(rm['form']),
          description: s(rm['description']),
          group: s(rm['group']),
          trend: switch (s(rm['status'])) { 'up' => Trend.up, 'down' => Trend.down, _ => Trend.same },
        ));
      }
      if (rows.isNotEmpty) groups.add(StandingsGroup(rows.first.group, rows));
    }
    return StandingsTable(league: ref, season: ref.season ?? 0, groups: groups);
  }

  static TeamInfo teamInfo(dynamic raw) {
    final x = m(raw);
    final t = m(x['team']);
    final v = m(x['venue']);
    return TeamInfo(
      ref: team(t),
      country: s(t['country']),
      founded: i(t['founded']),
      national: t['national'] == true,
      code: s(t['code']),
      venueName: s(v['name']),
      venueCity: s(v['city']),
      venueCapacity: i(v['capacity']),
      venueImage: s(v['image']),
    );
  }

  static TeamSeasonStats? teamStats(String body) {
    final r = responseObject(body);
    if (r == null) return null;
    final league = leagueRef(r['league']);
    final fx = m(r['fixtures']);
    int? tot(dynamic v) => i(m(v)['total']);
    (int, int, int)? rec(String side) {
      final w = i(m(fx['wins'])[side]), dr = i(m(fx['draws'])[side]), lo = i(m(fx['loses'])[side]);
      if (w == null || dr == null || lo == null) return null;
      return (w, dr, lo);
    }

    final goals = m(r['goals']);
    final gf = m(m(goals['for'])['total']);
    final ga = m(m(goals['against'])['total']);
    final cards = m(r['cards']);
    final periods = <String, (int, int)>{};
    int sumCards(Map<String, dynamic> c) {
      var t = 0;
      c.forEach((k, v) {
        final n = i(m(v)['total']) ?? 0;
        t += n;
      });
      return t;
    }

    final yellow = m(cards['yellow']);
    final red = m(cards['red']);
    for (final k in {...yellow.keys, ...red.keys}) {
      periods[k] = (i(m(yellow[k])['total']) ?? 0, i(m(red[k])['total']) ?? 0);
    }
    final biggest = m(r['biggest']);
    String? big(String kind) {
      final b = m(biggest[kind]);
      return s(b['home']) ?? s(b['away']);
    }

    return TeamSeasonStats(
      league: league,
      season: league.season ?? 0,
      form: s(r['form']),
      played: tot(fx['played']),
      wins: tot(fx['wins']),
      draws: tot(fx['draws']),
      losses: tot(fx['loses']),
      homeRecord: rec('home'),
      awayRecord: rec('away'),
      goalsFor: i(gf['total']),
      goalsAgainst: i(ga['total']),
      goalsForHome: i(gf['home']),
      goalsForAway: i(gf['away']),
      goalsAgainstHome: i(ga['home']),
      goalsAgainstAway: i(ga['away']),
      cleanSheets: tot(r['clean_sheet']),
      failedToScore: tot(r['failed_to_score']),
      yellow: yellow.isEmpty ? null : sumCards(yellow),
      red: red.isEmpty ? null : sumCards(red),
      cardsByPeriod: periods,
      formations: [for (final f in l(r['lineups'])) (s(m(f)['formation']) ?? '', i(m(f)['played']) ?? 0)],
      penaltiesScored: tot(m(m(r['penalty'])['scored'])),
      penaltiesMissed: tot(m(m(r['penalty'])['missed'])),
      biggestWin: big('wins'),
      biggestLoss: big('loses'),
    );
  }

  static Injury injury(dynamic raw) {
    final x = m(raw);
    final p = m(x['player']);
    return Injury(
      player: PlayerRef(id: i(p['id']) ?? 0, name: s(p['name']) ?? '', photo: s(p['photo'])),
      teamId: i(m(x['team'])['id']) ?? 0,
      type: s(p['type']) ?? 'Unavailable',
      reason: s(p['reason']) ?? '',
    );
  }

  static Prediction? prediction(String body) {
    final r = response(body);
    if (r.isEmpty) return null;
    final p = m(m(r.first)['predictions']);
    final pct = m(p['percent']);
    return Prediction(
      homePct: d(pct['home']),
      drawPct: d(pct['draw']),
      awayPct: d(pct['away']),
      advice: s(p['advice']),
      winnerName: s(m(p['winner'])['name']),
    );
  }
}
