import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/settings.dart';
import '../../data/models/models.dart';

/// Recently viewed teams/players/leagues. Feeds search suggestions and the
/// local fuzzy index (so typo-tolerant search works offline for anything the
/// user has seen).
class RecentNotifier extends Notifier<List<SearchHit>> {
  @override
  List<SearchHit> build() {
    final demo = ref.watch(settingsProvider.select((s) => s.useDemo));
    final raw = ref.read(localStoreProvider).readList(demo ? 'recent_demo' : 'recent') ?? const [];
    return [
      for (final r in raw)
        if (r is Map && SearchKind.values.asNameMap()[r['k']] != null)
          SearchHit(kind: SearchKind.values.asNameMap()[r['k']]!, id: (r['id'] as num).toInt(), title: r['t'] as String? ?? '', subtitle: r['s'] as String?, image: r['i'] as String?),
    ];
  }

  void add(SearchHit h) {
    if (state.isNotEmpty && state.first.kind == h.kind && state.first.id == h.id) return;
    state = [h, ...state.where((x) => !(x.kind == h.kind && x.id == h.id))].take(40).toList();
    final demo = ref.read(settingsProvider).useDemo;
    ref.read(localStoreProvider).write(demo ? 'recent_demo' : 'recent', [for (final x in state) {'k': x.kind.name, 'id': x.id, 't': x.title, 's': x.subtitle, 'i': x.image}]);
  }

  void clear() {
    state = const [];
    ref.read(localStoreProvider).write(ref.read(settingsProvider).useDemo ? 'recent_demo' : 'recent', const []);
  }
}

final recentProvider = NotifierProvider<RecentNotifier, List<SearchHit>>(RecentNotifier.new);

/// Record a viewed entity. Safe to call from build (deferred, idempotent).
void recordRecent(WidgetRef ref, SearchHit hit) {
  scheduleMicrotask(() {
    try {
      ref.read(recentProvider.notifier).add(hit);
    } catch (_) {}
  });
}
