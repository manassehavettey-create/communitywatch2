import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/streaks.dart';
import '../../../core/providers.dart';
import '../data/entry_repository.dart';

class LogFilterController extends Notifier<EntryFilter> {
  @override
  EntryFilter build() => EntryFilter.none;

  void set(EntryFilter filter) => state = filter;
  void setQuery(String q) => state = state.copyWith(query: q);
  void clear() => state = EntryFilter(query: state.query);
}

final logFilterProvider =
    NotifierProvider<LogFilterController, EntryFilter>(LogFilterController.new);

final logEntriesProvider = StreamProvider<List<EntryView>>((ref) {
  final repo = ref.watch(entryRepositoryProvider);
  final filter = ref.watch(logFilterProvider);
  return repo.watchEntries(filter);
});

final todayEntriesProvider = StreamProvider<List<EntryView>>((ref) {
  final repo = ref.watch(entryRepositoryProvider);
  final today = ref.watch(todayProvider);
  return repo.watchEntries(EntryFilter(from: today, to: today));
});

final allTagsProvider = StreamProvider<List<TagCount>>((ref) {
  final repo = ref.watch(entryRepositoryProvider);
  return repo.watch(repo.tagCounts);
});

final logStreakProvider = StreamProvider<Streak>((ref) {
  final repo = ref.watch(entryRepositoryProvider);
  final today = ref.watch(todayProvider);
  return repo.watch(() async => Streaks.compute(await repo.entryDays(), today));
});

final entryProvider =
    FutureProvider.autoDispose.family<EntryView?, int>((ref, id) {
  return ref.watch(entryRepositoryProvider).getEntry(id);
});
