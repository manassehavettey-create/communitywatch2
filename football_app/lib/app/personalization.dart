import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/models.dart';
import 'favorites.dart';

/// Competitions shown first for users who haven't followed anything yet.
/// Ordering preference only — never used for rules or data.
const popularLeagueIds = [9001, 9002, 2, 39, 140, 135, 78, 61, 3, 848, 1, 4, 94, 88, 253, 71, 307, 203, 144, 179, 262, 128];

class Personalization {
  const Personalization({required this.teams, required this.players, required this.playerTeams, required this.leagues});
  final Set<int> teams;
  final Set<int> players;
  final Set<int> playerTeams;
  final Set<int> leagues;

  bool get isEmpty => teams.isEmpty && players.isEmpty && leagues.isEmpty;
  bool followsMatch(Match m) => teams.contains(m.home.id) || teams.contains(m.away.id) || playerTeams.contains(m.home.id) || playerTeams.contains(m.away.id);
  bool followsLeague(int id) => leagues.contains(id);

  /// Higher = more relevant. Drives Home and Matches ordering (spec §31, §35).
  int matchPriority(Match m) {
    var s = 0;
    if (teams.contains(m.home.id) || teams.contains(m.away.id)) s += 1000;
    if (playerTeams.contains(m.home.id) || playerTeams.contains(m.away.id)) s += 600;
    if (leagues.contains(m.league.id)) s += 400;
    s += leaguePopularity(m.league.id);
    if (m.status.isLive) s += 50;
    return s;
  }

  int leaguePriority(int leagueId) => (leagues.contains(leagueId) ? 1000 : 0) + leaguePopularity(leagueId);

  static int leaguePopularity(int id) {
    final i = popularLeagueIds.indexOf(id);
    return i < 0 ? 0 : 300 - i * 10;
  }
}

final personalizationProvider = Provider<Personalization>((ref) {
  final favs = ref.watch(activeFavoritesProvider);
  return Personalization(
    teams: {for (final f in favs) if (f.kind == FavKind.team) f.id},
    players: {for (final f in favs) if (f.kind == FavKind.player) f.id},
    playerTeams: {for (final f in favs) if (f.kind == FavKind.player && f.teamId != null) f.teamId!},
    leagues: {for (final f in favs) if (f.kind == FavKind.league) f.id},
  );
});
