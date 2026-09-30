import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings.dart';

enum FavKind { team, player, league }

class Favorite {
  const Favorite({required this.kind, required this.id, required this.name, this.image, this.subtitle, this.teamId, this.notifs = const {}, this.demo = false});
  final FavKind kind;
  final int id;
  final String name;
  final String? image;
  final String? subtitle;

  /// For players: their club, used for "My Football" and notifications.
  final int? teamId;
  final Set<NotifKind> notifs;

  /// Followed while demo data was active (kept separate from real follows).
  final bool demo;

  String get key => '${kind.name}:$id';

  static Set<NotifKind> defaultsFor(FavKind k) => switch (k) {
        FavKind.team => {NotifKind.matchStart, NotifKind.goals, NotifKind.halfTime, NotifKind.fullTime, NotifKind.redCards, NotifKind.lineups, NotifKind.importantEvents},
        FavKind.player => {NotifKind.playerGoal, NotifKind.playerAssist, NotifKind.playerStarting, NotifKind.playerRed},
        FavKind.league => {NotifKind.results, NotifKind.importantFixtures},
      };

  Favorite copyWith({Set<NotifKind>? notifs, String? name, String? image, int? teamId}) =>
      Favorite(kind: kind, id: id, name: name ?? this.name, image: image ?? this.image, subtitle: subtitle, teamId: teamId ?? this.teamId, notifs: notifs ?? this.notifs, demo: demo);

  Map<String, dynamic> toJson() => {'k': kind.name, 'id': id, 'n': name, 'img': image, 's': subtitle, 't': teamId, 'nt': notifs.map((e) => e.name).toList(), 'demo': demo};

  static Favorite? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final kind = FavKind.values.asNameMap()[raw['k']];
    if (kind == null) return null;
    return Favorite(
      kind: kind,
      id: (raw['id'] as num).toInt(),
      name: raw['n'] as String? ?? '',
      image: raw['img'] as String?,
      subtitle: raw['s'] as String?,
      teamId: (raw['t'] as num?)?.toInt(),
      notifs: {for (final n in (raw['nt'] as List? ?? const [])) if (NotifKind.values.asNameMap()[n] != null) NotifKind.values.asNameMap()[n]!},
      demo: raw['demo'] == true,
    );
  }
}

/// All follows. Visible follows are filtered to the active data source so
/// demo teams never mix with real ones.
class FavoritesNotifier extends Notifier<List<Favorite>> {
  @override
  List<Favorite> build() {
    final raw = ref.read(localStoreProvider).readList('favorites') ?? const [];
    return raw.map(Favorite.fromJson).whereType<Favorite>().toList();
  }

  bool get _demo => ref.read(settingsProvider).useDemo;

  List<Favorite> get active => state.where((f) => f.demo == _demo).toList();

  bool isFollowing(FavKind kind, int id) => state.any((f) => f.kind == kind && f.id == id && f.demo == _demo);

  void toggle(Favorite f) {
    if (isFollowing(f.kind, f.id)) {
      remove(f.kind, f.id);
    } else {
      add(f);
    }
  }

  void add(Favorite f) {
    final fav = Favorite(kind: f.kind, id: f.id, name: f.name, image: f.image, subtitle: f.subtitle, teamId: f.teamId, notifs: f.notifs.isEmpty ? Favorite.defaultsFor(f.kind) : f.notifs, demo: _demo);
    state = [...state.where((x) => !(x.kind == f.kind && x.id == f.id && x.demo == _demo)), fav];
    _save();
  }

  void remove(FavKind kind, int id) {
    state = state.where((x) => !(x.kind == kind && x.id == id && x.demo == _demo)).toList();
    _save();
  }

  void setNotif(Favorite f, NotifKind k, bool on) {
    state = [
      for (final x in state)
        if (x.key == f.key && x.demo == f.demo) x.copyWith(notifs: on ? {...x.notifs, k} : ({...x.notifs}..remove(k))) else x,
    ];
    _save();
  }

  void reorder(FavKind kind, int oldIndex, int newIndex) {
    final ofKind = active.where((f) => f.kind == kind).toList();
    final item = ofKind.removeAt(oldIndex);
    ofKind.insert(newIndex, item);
    final others = state.where((f) => !(f.kind == kind && f.demo == _demo)).toList();
    state = [...others, ...ofKind];
    _save();
  }

  void _save() => ref.read(localStoreProvider).write('favorites', state.map((f) => f.toJson()).toList());
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, List<Favorite>>(FavoritesNotifier.new);

/// Follows for the active data source only.
final activeFavoritesProvider = Provider<List<Favorite>>((ref) {
  final demo = ref.watch(settingsProvider.select((s) => s.useDemo));
  return ref.watch(favoritesProvider).where((f) => f.demo == demo).toList();
});

final followedTeamIdsProvider = Provider<Set<int>>((ref) => {
      for (final f in ref.watch(activeFavoritesProvider))
        if (f.kind == FavKind.team) f.id,
    });

final followedLeagueIdsProvider = Provider<Set<int>>((ref) => {
      for (final f in ref.watch(activeFavoritesProvider))
        if (f.kind == FavKind.league) f.id,
    });

final followedPlayerIdsProvider = Provider<Set<int>>((ref) => {
      for (final f in ref.watch(activeFavoritesProvider))
        if (f.kind == FavKind.player) f.id,
    });

/// Map of teamId → followed-player favourites (for notifications/My Football).
final followedPlayersByTeamProvider = Provider<Map<int, List<Favorite>>>((ref) {
  final out = <int, List<Favorite>>{};
  for (final f in ref.watch(activeFavoritesProvider).where((f) => f.kind == FavKind.player && f.teamId != null)) {
    out.putIfAbsent(f.teamId!, () => []).add(f);
  }
  return out;
});
