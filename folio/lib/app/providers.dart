import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/database.dart';
import '../core/pdf/library_storage.dart';
import '../data/repositories/annotations_repository.dart';
import '../data/repositories/books_repository.dart';
import '../data/repositories/collections_repository.dart';
import '../data/repositories/position_repository.dart';
import '../data/repositories/search_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/stats_repository.dart';
import '../data/services/import_service.dart';
import '../data/services/indexing_service.dart';

/// Overridden in main() with the opened, encrypted database.
final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError());

/// Overridden in main() once the library folders exist.
final libraryStorageProvider = Provider<LibraryStorage>((ref) => throw UnimplementedError());

/// Settings loaded before the first frame; overridden in main().
final initialSettingsProvider = Provider<AppSettings>((ref) => const AppSettings());

final booksRepositoryProvider = Provider((ref) => BooksRepository(ref.watch(databaseProvider)));
final annotationsRepositoryProvider = Provider((ref) => AnnotationsRepository(ref.watch(databaseProvider)));
final searchRepositoryProvider = Provider((ref) => SearchRepository(ref.watch(databaseProvider)));
final positionRepositoryProvider = Provider((ref) => PositionRepository(ref.watch(databaseProvider)));
final collectionsRepositoryProvider = Provider((ref) => CollectionsRepository(ref.watch(databaseProvider)));
final statsRepositoryProvider = Provider((ref) => StatsRepository(ref.watch(databaseProvider)));
final settingsRepositoryProvider = Provider((ref) => SettingsRepository(ref.watch(databaseProvider)));

final indexingServiceProvider = Provider((ref) {
  final s = IndexingService(
    db: ref.watch(databaseProvider),
    books: ref.watch(booksRepositoryProvider),
    search: ref.watch(searchRepositoryProvider),
  );
  ref.onDispose(s.dispose);
  return s;
});

final importServiceProvider = Provider(
  (ref) => ImportService(
    books: ref.watch(booksRepositoryProvider),
    storage: ref.watch(libraryStorageProvider),
    indexer: ref.watch(indexingServiceProvider),
  ),
);

// ---------------------------------------------------------------- settings

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(initialSettingsProvider);

  Future<void> update(AppSettings Function(AppSettings s) change) async {
    state = change(state);
    await ref.read(settingsRepositoryProvider).save(state);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

// ------------------------------------------------------------------- books

final booksProvider = StreamProvider<List<Book>>((ref) => ref.watch(booksRepositoryProvider).watchAll());

final bookProvider = StreamProvider.autoDispose.family<Book?, int>(
  (ref, id) => ref.watch(booksRepositoryProvider).watchBook(id),
);

final bookCountsProvider = StreamProvider.autoDispose.family<AnnotationCounts, int>(
  (ref, id) => ref.watch(booksRepositoryProvider).watchCounts(id),
);

final positionProvider = StreamProvider.autoDispose.family<ReadingPosition?, int>(
  (ref, id) => ref.watch(positionRepositoryProvider).watch(id),
);

final statsProvider = StreamProvider<StatsSummary>((ref) => ref.watch(statsRepositoryProvider).watchSummary());

final collectionsProvider = StreamProvider<List<CollectionWithBooks>>(
  (ref) => ref.watch(collectionsRepositoryProvider).watchAll(),
);

final bookCollectionIdsProvider = StreamProvider.autoDispose.family<Set<int>, int>(
  (ref, id) => ref.watch(collectionsRepositoryProvider).watchCollectionIdsForBook(id),
);

/// Books currently shown as "continue reading": most recently opened,
/// unfinished.
final continueReadingProvider = Provider<Book?>((ref) {
  final books = ref.watch(booksProvider).value ?? const [];
  final reading = books.where((b) => b.lastOpenedAt != null && b.status != BookStatus.finished).toList()
    ..sort((a, b) => b.lastOpenedAt!.compareTo(a.lastOpenedAt!));
  return reading.isEmpty ? null : reading.first;
});

// ------------------------------------------------------------------ import

class ImportJob {
  const ImportJob({required this.id, required this.fileName, this.stage, this.result});
  final int id;
  final String fileName;
  final ImportStage? stage;
  final ImportResult? result;

  bool get isDone => result != null;

  ImportJob copyWith({ImportStage? stage, ImportResult? result}) =>
      ImportJob(id: id, fileName: fileName, stage: stage ?? this.stage, result: result ?? this.result);
}

/// Tracks imports in progress so the library can show skeleton cards and a
/// summary when a batch finishes.
class ImportController extends Notifier<List<ImportJob>> {
  int _nextId = 0;

  @override
  List<ImportJob> build() => const [];

  bool get isImporting => state.any((j) => !j.isDone);

  /// Imports files one after another (keeps memory flat for big batches).
  Future<List<ImportResult>> importAll(List<({String path, String name, bool temporary})> files) async {
    final jobs = [for (final f in files) ImportJob(id: _nextId++, fileName: f.name)];
    state = [...state.where((j) => !j.isDone), ...jobs];
    final results = <ImportResult>[];
    final service = ref.read(importServiceProvider);
    for (var i = 0; i < files.length; i++) {
      final job = jobs[i];
      final r = await service.importFile(
        files[i].path,
        files[i].name,
        onStage: (s) => _update(job.id, (j) => j.copyWith(stage: s)),
        moveSource: files[i].temporary,
      );
      results.add(r);
      _update(job.id, (j) => j.copyWith(result: r));
    }
    return results;
  }

  void _update(int id, ImportJob Function(ImportJob) f) {
    state = [for (final j in state) j.id == id ? f(j) : j];
  }

  void clearFinished() => state = state.where((j) => !j.isDone).toList();
}

final importControllerProvider = NotifierProvider<ImportController, List<ImportJob>>(ImportController.new);

/// True in debug builds only; gates the demo-data toggle.
const bool kAllowDemoData = kDebugMode;
