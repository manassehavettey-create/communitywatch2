/// Where a piece of information comes from. Every UI surface that shows
/// non-confirmed data must display the matching label (spec §41).
enum Provenance {
  /// Official data from the sports-data provider (results, official lineups…).
  confirmed,

  /// Reported by a source but not official (e.g. injury doubts, rumours).
  reported,

  /// A provider prediction (win probability, predicted lineup).
  predicted,

  /// Text/analysis produced by the app from confirmed data.
  generated,

  /// Debug-only demo data. Never shipped in release builds.
  demo,
}

class TeamRef {
  const TeamRef({required this.id, required this.name, this.logo});
  final int id;
  final String name;
  final String? logo;

  /// Three-letter-ish code for tight layouts.
  String get short {
    final words = name.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ0-9 ]'), '').split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return name;
    if (words.length == 1) return words.first.substring(0, words.first.length.clamp(0, 3)).toUpperCase();
    final meaningful = words.where((w) => !const {'FC', 'CF', 'AC', 'SC', 'AFC', 'SV', 'FK', 'CD', 'RC', 'US', 'AS', 'SS'}.contains(w.toUpperCase())).toList();
    final use = meaningful.isEmpty ? words : meaningful;
    if (use.length == 1) return use.first.substring(0, use.first.length.clamp(0, 3)).toUpperCase();
    return use.take(3).map((w) => w[0]).join().toUpperCase();
  }

  @override
  bool operator ==(Object other) => other is TeamRef && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class LeagueRef {
  const LeagueRef({required this.id, required this.name, this.logo, this.country, this.flag, this.season, this.round});
  final int id;
  final String name;
  final String? logo;
  final String? country;
  final String? flag;
  final int? season;
  final String? round;

  @override
  bool operator ==(Object other) => other is LeagueRef && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class PlayerRef {
  const PlayerRef({required this.id, required this.name, this.photo});
  final int id;
  final String name;
  final String? photo;
}

/// A value plus freshness metadata. `stale == true` means the network call
/// failed and this is the last known state (spec §42).
class Fresh<T> {
  const Fresh(this.data, {required this.fetchedAt, this.stale = false, this.provenance = Provenance.confirmed});
  final T data;
  final DateTime fetchedAt;
  final bool stale;
  final Provenance provenance;

  Fresh<R> map<R>(R Function(T) f) => Fresh(f(data), fetchedAt: fetchedAt, stale: stale, provenance: provenance);
}

enum DataErrorKind { network, rateLimited, plan, auth, notFound, server, unknown }

class DataException implements Exception {
  const DataException(this.kind, this.message);
  final DataErrorKind kind;
  final String message;

  /// Errors where serving last-known cached data is the right fallback.
  bool get allowsStaleFallback => kind == DataErrorKind.network || kind == DataErrorKind.rateLimited || kind == DataErrorKind.server;

  @override
  String toString() => 'DataException($kind): $message';
}

/// What the active provider can supply. The UI hides or labels features
/// accordingly rather than estimating (spec §39).
class ProviderCapabilities {
  const ProviderCapabilities({
    this.liveScores = true,
    this.events = true,
    this.lineups = true,
    this.matchStats = true,
    this.playerMatchStats = true,
    this.playerRatings = true,
    this.xg = false,
    this.xa = false,
    this.momentum = false,
    this.shotMap = false,
    this.heatmap = false,
    this.passMap = false,
    this.touches = false,
    this.commentary = false,
    this.confirmedTransfers = true,
    this.reportedTransfers = false,
    this.predictedLineups = false,
    this.injuries = true,
    this.predictions = true,
    this.news = false,
  });

  final bool liveScores;
  final bool events;
  final bool lineups;
  final bool matchStats;
  final bool playerMatchStats;
  final bool playerRatings;
  final bool xg;
  final bool xa;
  final bool momentum;
  final bool shotMap;
  final bool heatmap;
  final bool passMap;
  final bool touches;

  /// Provider-written text commentary. When false the Commentary tab shows an
  /// app-generated feed built from confirmed events, labelled as such.
  final bool commentary;
  final bool confirmedTransfers;
  final bool reportedTransfers;
  final bool predictedLineups;
  final bool injuries;
  final bool predictions;
  final bool news;

  bool get anyPitchData => shotMap || heatmap || passMap || touches;
}
